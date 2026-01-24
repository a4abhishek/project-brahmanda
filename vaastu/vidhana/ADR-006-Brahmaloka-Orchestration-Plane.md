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
