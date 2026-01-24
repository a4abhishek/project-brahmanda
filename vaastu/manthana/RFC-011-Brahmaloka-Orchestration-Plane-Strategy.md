# **RFC-011: Brahmaloka (Orchestration Plane) Strategy**

**Status:** Accepted<br>
**Date:** 2026-01-19<br>
**Enhances:** [ADR-001: Hybrid Cloud Architecture](../vidhana/ADR-001-Homelab-Architecture.md)

---

## 1. Context

As we prepare to automate the provisioning of the `Vyom` (Compute) layer, we must define a robust and secure CI/CD strategy. The primary challenge is enabling an automated agent (like a GitHub Actions runner) to securely access the on-premise Proxmox API without creating architectural deadlocks or circular dependencies.

This RFC proposes the introduction of a new conceptual plane, **`Brahmaloka`**, to serve as the dedicated orchestration layer for the entire project.

## 2. The Problem: The Circular Dependency of a Shared Bastion

The strategy outlined in [RFC-009](./RFC-009-Vyom-Provisioning-Strategy.md) initially proposed using the `Kshitiz` (Edge) node as a CI/CD jump host. This approach has a critical flaw:

- **The Circular Dependency:** If a CI/CD pipeline running *from* Kshitiz needs to update or destroy the `vyom` Nebula nodes, or worse, the Kshitiz node itself, it would be altering the very infrastructure that provides its own connectivity. This could cause the pipeline to fail mid-operation, leaving the infrastructure in a broken, half-deployed state.

An automation pipeline cannot be dependent on the components it is tasked with managing. This violates the principles of reliability and detachment (*Asanga*).

## 3. Proposal: The `Brahmaloka` Orchestration Plane

We will introduce a new, fourth conceptual plane to our architecture: **`Brahmaloka`**, the abode of the creator.

- **Purpose:** This plane will house the dedicated, persistent automation engines (i.e., self-hosted GitHub Runners) that drive the `Samsara` cycle. It is the orchestrator from which the universe is manifested, configured, and maintained.
- **Implementation:** `Brahmaloka` will be realized as one or more lightweight virtual machines or LXC containers running on the Proxmox host, but managed independently from the `vyom` cluster.

### 3.1. The Primary CI/CD Runner (`Brahmaloka-Runner`)

This will be the main engine for our CI/CD pipeline.

- **Connectivity:**

    1. **Direct Physical Access:** It connects to the **Local Management Network (vmbr0)**. This allows it to talk to the Proxmox API (`192.168.68.200`) and SSH into Vyom nodes (`192.168.68.x`) directly via LAN.
    2. **Outbound Polling:** It functions as a standard GitHub Actions self-hosted runner, initiating outbound HTTPS connections to GitHub to poll for jobs.
    3. **No Mesh Dependency:** Crucially, for its primary CI/CD function, it will **not** depend on the Kshitiz-Vyom Nebula mesh. If the mesh is down, the Runner can still SSH in via LAN to fix it. This completely resolves the circular dependency issue.

- **Resource Allocation:** This runner is critical piece of infrastructure. It must be adequately provisioned to run `terraform` and `ansible` jobs. A recommended starting point is **2 vCPUs and 2-4 GB of RAM**.
- **Lifecycle Management:**
  - The `Brahmaloka-Runner` will be managed by its own dedicated IaC configuration in `samsara/terraform/brahmaloka/`.
  - Its initial creation will be a manual step documented in `001-Sarga.md`, but subsequent updates will be managed via code.

- **CI/CD Flow Diagram:**

  ```mermaid
  flowchart TB
   subgraph Samsara["Samsara"]
          GitHub("GitHub Actions")
          Developer(["Developer"])
    end
   subgraph subGraph1["Guest VMs"]
          BRunner("Brahmaloka-Runner VM")
          Vyom("Vyom Cluster VMs")
    end
   subgraph subGraph2["Brahmanda (On-Premise): Proxmox Hypervisor (NUC)"]
      direction LR
          subGraph1
          PVE_API("Proxmox API Service")
    end
      Developer -- "1. git push" --> GitHub
      GitHub -- "2. Job is Queued" --> JobsDB[("Workflow Jobs")]
      BRunner -- "3. Polls for jobs" --> GitHub
      BRunner -- "4. Runs terraform via API" --> PVE_API
      PVE_API -- "5. Creates/Configures" --> Vyom
      BRunner -- "6. Configures OS (Ansible)" --> Vyom

      style BRunner fill:#f9f,stroke:#333,stroke-width:2px
      style Vyom fill:#ccf,stroke:#333,stroke-width:2px
  ```

### 3.2. The Bastion-on-Demand (`Brahmaloka-Bastian`)

To provide secure, out-of-band manual access for debugging and emergencies, we will implement a security model we are naming the **"Dark Bastion" pattern**. The name derives from the fact that the bastion host is "dark" (powered off) by default, presenting zero attack surface until it is explicitly activated.

- **Implementation:** A separate, physical **Raspberry Pi**.
- **Connectivity:**
    1. It will be connected to the network.
    2. Its power source will be a **Smart Plug**.
- **Workflow:**

    1. **Default State:** The Raspberry Pi is **powered off**, presenting zero attack surface.
    2. **Activation:** Operator activates the Smart Plug via an Out-of-Band method (e.g., Vendor App/5G), independent of the Homelab's internal services.
    3. **Function:** Upon booting, the Pi will automatically start the Nebula client and join the mesh, providing an operator with a secure SSH entry point into the on-premise network.
    4. **Deactivation:** Once the debugging session is complete, operator turns off the Smart Plug, and the bastion goes dark again.

- **"Dark Bastion" Workflow Diagram:**

  ```mermaid
  graph TD
      A(Start: Bastion is Powered Off) --> B{"Operator needs emergency access"};
      B --> C["Operator uses OOB HomeAssistant to turn ON Smart Plug"];
      C --> D["Raspberry Pi (Bastion) boots up"];
      D --> E["Pi automatically connects to Nebula Mesh"];
      E --> F["Operator SSHes to internal hosts via Bastion"];
      F --> G["Operator is Debugging"];
      G --> H{"Debugging complete?"};
      H -- Yes --> I["Operator turns OFF Smart Plug"];
      I --> J[End: Bastion is Powered Off];
      H -- No --> G;

      style A fill:#f99,stroke:#333,stroke-width:2px;
      style I fill:#f99,stroke:#333,stroke-width:2px;
  ```

### 3.3. Automated Maintenance (Sthiti)

To balance security with stability, we will implement a **Tiered Update Strategy**:

1. **OS Layer (Security):** We will enable `unattended-upgrades` on all nodes, configured to install **security updates only** automatically. This ensures protection against critical vulnerabilities (e.g., kernel, OpenSSL) without manual intervention.
2. **Application Layer (Stability):** Critical infrastructure components (K3s, Nebula) will have their versions **strictly pinned** in Ansible variables. They will **NOT** be auto-upgraded. Upgrades will be deliberate, initiated by committing a version bump to Git.
3. **Rolling Reboot Playbook:** The scheduled `vyom-reboot.yml` playbook will **"manage rolling reboots"**. It will:
    - Check for the `/var/run/reboot-required` flag set by `unattended-upgrades`.
    - If found, safely **drain** the node to reschedule pods.
    - Reboot the node.
    - **Uncordon** the node to return it to service.

- **Automated Maintenance Flow Diagram:**

  ```mermaid
  graph TD
      subgraph "Brahmaloka VM"
          A(Cron Scheduler) -- "1. On schedule, executes..." --> B(Run maintenance);
      end;

      subgraph "Vyom Cluster"
          C(Vyom Nodes);
      end;

      B -- "2. Runs 'apt update' to Brahmaloka itself" --> B;
      B -- "3. Runs 'apt update' to" --> C;
      B --> D{"4. reboot-required flag set?"};
      E(5. Rolling Reboot Vyom Nodes) --> C;
      D -- Yes --> E;
      D -- No --> F;
      C --> F;
      F(6. Finished Maintainance);

      style A fill:#dafdc4,stroke:#333,stroke-width:2px;
      style F fill:#f99,stroke:#333,stroke-width:2px;
  ```

## 4. Impact

- **New Architectural Plane:** Introduces `Brahmaloka` as the orchestration layer. The `README.md` and high-level diagrams will need to be updated to reflect this fourth plane.
- **New Terraform Module:** A new directory, `samsara/terraform/brahmaloka/`, will be created to manage the runner's infrastructure.
- **New Ansible Configuration:** A corresponding `samsara/ansible/group_vars/brahmaloka/` and `playbooks/` for the runner will be created.
- **Updates to `001-Sarga.md`:** A new manual step will be added to describe the initial setup of the `Brahmaloka-Runner` VM and the Bastion Pi.
- **Updates to `002-Visarga.md`:** New operational procedures for using the Bastion-on-Demand and managing the automated maintenance will be added.

## 5. Conclusion

This RFC proposes a sophisticated, multi-faceted strategy for CI/CD orchestration and remote access. By introducing the `Brahmaloka` plane, we solve the critical circular dependency flaw and establish two distinct patterns for automation and manual intervention:

1. An **always-on, outbound-polling CI/CD runner** for pure automation (operating via physical LAN).
2. A **normally-off, on-demand bastion host** for secure manual access (operating via OOB Power).

This design significantly enhances the security, resilience, and professional quality of the Project Brahmanda architecture.
