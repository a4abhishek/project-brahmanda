# **ADR-006: Brahmaloka (Orchestration Plane) Strategy**

Date: 2026-01-22<br>
Status: Accepted<br>
Enhances: ADR-001: Hybrid Cloud Architecture<br>
Related RFC: RFC-011: Brahmaloka Strategy

## 1. Context

Project Brahmanda requires a robust mechanism for automated infrastructure provisioning (Terraform) and configuration management (Ansible). The initial design—running automation from the Kshitiz edge node introduced a critical **Circular Dependency** - The automation pipeline depended on the very mesh network it was responsible for maintaining. A failure in the mesh could lock out the automation required to fix it.

Additionally, we need a secure, out-of-band method for human operators to access the on-premise network during emergencies without exposing persistent attack surfaces (like open SSH ports) to the internet.

## 2. Decision

We will establish a fourth architectural plane, **Brahmaloka** (The Abode of the Creator), dedicated exclusively to orchestration and emergency access. This plane exists **outside** the failure domain of the compute cluster (Vyom) and the mesh (Nebula).

It consists of two distinct components:

1. **Brahmaloka-Runner:** An always-on, self-hosted GitHub Actions runner VM for automation.
2. **Brahmaloka-Bastion:** A physical "Dark Bastion" (Raspberry Pi) for emergency human access.

## 3. Implementation

### A. The Brahmaloka-Runner (CI/CD Automation)

This VM serves as the persistent engine for the Samsara cycle.

* **Platform:** Proxmox VM (running on the NUC, but logically distinct from the K3s cluster).
* **Specifications:**
  * **CPU:** 2 vCPUs
  * **RAM:** 4 GB
  * **Disk:** 32 GB (Ubuntu Server 24.04 LTS, cloned from prakriti-template)
* **Networking:**
  * Interface: **Physical LAN (vmbr0)**.
  * **Crucial:** It does **NOT** use the Nebula mesh for its primary function. It communicates directly with the Proxmox API (192.168.68.200) and Vyom nodes (192.168.68.x) over the local network.
  * **Why:** This breaks the circular dependency. If the mesh is down, the runner can still reach the nodes to re-provision it.
* **Software Stack:**
  * github-runner: Configured as a systemd service.
  * terraform: For provisioning.
  * ansible: For configuration.
  * op (1Password CLI): For secret injection.
* **Security:**
  * **Traffic:** Outbound-only connection to GitHub (HTTPS long-polling). No inbound ports required.
  * **Secrets:** Service Account credentials (`OP_SERVICE_ACCOUNT_TOKEN`) are injected via GitHub Secrets.

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

### B. The Dark Bastion (Emergency Access)

To provide secure human access without a persistent footprint, we implement the **"Dark Bastion"** pattern.

* **Hardware:** Raspberry Pi (Model 4 or 5).
* **Power:** Connected to a **Smart Plug** controllable via a separate, out-of-band cloud service (e.g., Tuya/Wipro app on 4G/5G).
* **Network:** Hardwired Ethernet to the home router.
* **Configuration:**
  * Auto-starts Nebula on boot.
  * Configured as a standard Nebula node.
  * SSHD enabled, accessible only via the Nebula interface.
* **The "Dark" Workflow:**
  1. **Normal State:** Smart plug is **OFF**. The bastion is physically powered down. Attack surface is zero.
  2. **Emergency:** Operator turns the smart plug **ON** via the vendor app.
  3. **Boot:** The Pi boots, connects to the internet, and establishes the Nebula tunnel.
  4. **Access:** Operator SSHes into the Pi's Nebula IP. From there, they can jump to any local node.
  5. **Termination:** Operator turns the smart plug **OFF**. The bastion goes dark.

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

### C. Automated Maintenance (Sthiti)

To ensure Vyom and Brahmaloka remain secure without sacrificing stability, we implement a **Tiered Update Strategy**:

* **OS Layer (Security):**
  * **Mechanism:** `unattended-upgrades` package installed on all nodes.
  * **Configuration:** Enabled for **security updates only**.
  * **Goal:** Zero-touch patching of critical vulnerabilities (kernel, OpenSSL).
* **Application Layer (Stability):**
  * **Mechanism:** Ansible variables (`k3s_version`, `nebula_version`).
  * **Configuration:** **Strictly Pinned**. No auto-updates.
  * **Goal:** Deterministic state. Upgrades are initiated only by committing a version bump to Git.
* **Maintenance Playbook (`rolling-reboot.yml`):**
  * **Trigger:** Weekly cron job on Brahmaloka-Runner.
  * **Scope:** Checks for `/var/run/reboot-required` on all nodes.
  * **Action:** If reboot is required:
        1. **Cordon & Drain** the node (evict pods safely).
        2. **Reboot**.
        3. **Uncordon** the node (return to service).
  * **Constraint:** The Proxmox Host itself is excluded from automatic reboots.

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

### D. Identity Separation (Security)

To prevent Lateral Privilege Escalation, we enforce strict identity separation:

* **Incoming Access (to Brahmaloka):** MUST use a dedicated **`Brahmaloka-Key`**.
* **Outgoing Access (from Brahmaloka to Vyom):** Uses the **`Prakriti-Master-Key`** (injected ephemerally at runtime).
* **Rationale:** If Brahmaloka accepted the `Prakriti-Master-Key` for login, a compromise of that key (used widely for cluster management) would allow Lateral Movement into the Brahmaloka Node. From there, an attacker could access the 1Password Service Account Token and compromise the entire vault. Therefore, access to the Brahmaloka must be guarded by a strictly separate credential.

## 4. Lifecycle Management

* **Directory Structure:** The infrastructure for the runner is defined in samsara/terraform/brahmaloka/.
* **Bootstrap (Day 0):** The initial creation of the Runner VM is a manual step documented in [001-Sarga.md](../001-Sarga.md). Once active, it can manage its own updates via Terraform.

## 5. Consequences

### Positive

* ✅ **Resilience:** Automation is decoupled from the infrastructure it manages.
* ✅ **Security:** Emergency access has zero persistent attack surface.
* ✅ **Observability:** All infrastructure changes are driven by git commits processed by the runner.

### Negative

* ⚠️ **Resource Cost:** Consumes additional resources (VM overhead \+ physical Raspberry Pi).
* ⚠️ **Maintenance:** The runner itself is a "Pet" that needs to be maintained (mitigated by the automated maintenance playbook).
