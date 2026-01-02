# **RFC 004: Security Hardening Strategy**

Project Brahmanda exposes services to the internet via the Kshitiz gateway. We need a robust security posture that assumes breach ("Zero Trust") and limits blast radius.

## **1. Network Segmentation**

### **Option A: Physical Air-Gapping**

- **Description:** Use separate physical switches and routers for the Homelab.
- **Pros:** Ultimate isolation.
- **Cons:** High cost, physical space requirements, complex management.

### **Option B: Logical Segmentation (VLANs)**

- **Description:** Use 802.1Q VLANs on the existing router/switch to isolate traffic.
- **Pros:** Cost-effective (uses existing hardware), flexible.
- **Cons:** Misconfiguration can lead to leaks. Requires managed switch/router support.

### **Option C: Host-Based Firewalls Only**

- **Description:** Rely solely on `ufw` or `iptables` on the NUC.
- **Pros:** Simplest network setup.
- **Cons:** If the host OS is compromised, the network is wide open. No defense-in-depth.

**Recommendation:** **Option B (VLANs)**. It balances security and cost for a homelab.

## **2. Mesh Networking (The Overlay)**

### **Option A: Tailscale (SaaS)**

- **Description:** Managed Wireguard mesh.
- **Pros:** Extremely easy setup, great UI.
- **Cons:** Relies on a central coordination server controlled by a 3rd party. Identity is tied to Google/GitHub/Microsoft.

### **Option B: Nebula (Self-Hosted)**

- **Description:** Slack's open-source overlay network.
- **Pros:** Fully self-hosted (Lighthouse), cryptographic identity (certificates), granular firewall rules (groups). No 3rd party dependency.
- **Cons:** More complex setup (CA generation, config distribution).

### **Option C: Wireguard (Manual)**

- **Description:** Point-to-point VPN.
- **Pros:** Kernel-level performance, standard.
- **Cons:** N\*(N-1)/2 connections to manage. Static IPs required or complex dynamic DNS.

**Recommendation:** **Option B (Nebula)**. Aligns with the "Self-Sovereign" philosophy of Brahmanda.

## **3. Emergency Controls (The Kill Switch)**

### **Option A: Software Kill Switch**

- **Description:** Use a GitHub Action to invoke a host-level script (`systemctl stop networking`) to initiate shutdown and destroy the Lighthouse (Kshitiz) to cut off public access.
- **Pros:** Free, fast execution, can be automated.
- **Cons:** Useless if the system is unresponsive or if the attacker has root access to prevent it.

### **Option B: Remote Hardware Switch (Smart Plug)**

- **Description:** A 16A Smart Plug connected to the NUC's power supply, controllable via a separate cloud app.
- **Pros:** **Remote Hard Kill**. Works even if the OS is frozen or compromised.
- **Cons:** Can be disabled by an attacker if they gain access to the network. Hard shutdown risks filesystem corruption.

### **Option C: Physical Wall Switch**

- **Description:** The actual electrical switch on the wall.
- **Pros:** **Ultimate Fail-Safe**. Cannot be hacked remotely.
- **Cons:** Requires physical presence. Hard shutdown risks filesystem corruption.

**Recommendation:** **All of the above (Defense in Depth)**. We will implement a layered strategy: Software first, Smart Plug for remote emergencies, and Wall Switch for physical security.

## **4. Host Hardening**

### **Option A: Manual Hardening**

- **Description:** Running commands manually.
- **Pros:** None.
- **Cons:** Non-reproducible, prone to drift.

### **Option B: Immutable OS (Talos Linux)**

- **Description:** API-driven OS, no SSH, read-only filesystem.
- **Pros:** Maximum security.
- **Cons:** High learning curve, difficult to debug for "Day 1" learning.

### **Option C: Ansible Hardening (CIS Benchmarks)**

- **Description:** Automated application of security best practices (SSH config, Fail2Ban, UFW).
- **Pros:** Reproducible, standard Linux experience, customizable.
- **Cons:** State can drift if Ansible isn't run regularly.

**Recommendation:** **Option C (Ansible)**. Provides a good balance of security and manageability for a Proxmox/Ubuntu base.

### **Option B: Watchdog Timer**

- **Description:** Automated service monitoring traffic anomalies.
- **Pros:** Automated response.
- **Cons:** High risk of false positives shutting down the lab.

**Recommendation:** **Option A (Manual Script)** initially, evolving to Option B later.
