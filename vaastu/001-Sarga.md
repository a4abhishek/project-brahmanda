# Sarga (Creation of Material Elements and Metaphysical Principles)

<p align="center">
न रूपमस्येह तथोपलभ्यते, नान्तो न चादिर्न च सम्प्रतिष्ठा | <br>
अश्वत्थमेनं सुविरूढमूल, मसङ्गशस्त्रेण दृढेन छित्त्वा ||

"The real form of this tree (of Brahmanda) is not perceived in this world... Having cut down this firmly rooted tree with the strong weapon of detachment..." (Bhagavad Gita 15.3)

</p>

## Introduction

This document is the definitive **Day 0 manual for Project Brahmanda**. It describes the transition from physical void to a fully manifested digital universe.

It serves as the immutable **Blueprint** for Project Brahmanda, written with the explicit understanding that all infrastructure is **transient**. We wield the **Weapon of Detachment**—Infrastructure as Code—to sever dependency on individual nodes, enabling us to replicate, destroy, and recreate the universe without hesitation or attachment.

## **Phase 1: Upadana (The Material Cause)**

_Goal: Procure high-performance, SRE-grade hardware. We prioritize specific component speeds to ensure Vyom is not bottlenecked at the storage or memory bus._

### **1\. Core Hardware Specifications**

| Component   | Specification                                   | Source                                                                                                      | Price         |
| :---------- | :---------------------------------------------- | :---------------------------------------------------------------------------------------------------------- | :------------ |
| **Node**    | ASUS NUC 14 Pro Plus Kit Slim (NUC14RVSU5)      | [ITGadgets](https://itgadgetsonline.com/product/asus-nuc-14-pro-plus-kit-slim-nuc14rvsu5-mini-pc-barebone/) | ₹41,734       |
| **Memory**  | 48GB **DDR5 SO-DIMM** 5600Mhz (CT48G56C46S5)    | [NationalPC](https://nationalpc.in/laptop-memory/crucial-48gb-ddr5-5600mhz-so-dimm-ct48g56c46s5)            | ₹41,300       |
| **Storage** | 2TB **NVMe M.2 Gen4** (SN850X \- 7300MB/s Read) | [Amazon](https://www.amazon.in/dp/B0B7CMZ3QH)                                                               | ₹25,600       |
| **Cable**   | Cat6 Snagless (Pure Bare Copper)                | [Amazon](https://www.amazon.in/dp/B0875SPZC8)                                                               | ₹1439         |
| **Switch**  | Smart Plug (16A - Remote Kill Switch)           | [Amazon](https://www.amazon.in/Wipro-Monitoring-Appliances-Microwave-Conditioners/dp/B08HN9Q2SZ/ref=sr_1_2_sspa?s=home-improvement&sr=1-2-spons&aref=BpzHKHMwVr&sp_csd=d2lkZ2V0TmFtZT1zcF9hdGY)                                                          | ₹1,000       |
| **Total**   | **Current Manifested Investment**               |                                                                                                             | **₹1,11,073** |

> HARDWARE NOTE: The NUC requires SO-DIMM (Laptop form factor) and NOT standard Desktop DIMMs. To achieve the 96GB goal, we use single 48GB modules at 5600Mhz. The SSD must be PCIe Gen 4 to leverage the full 7000MB/s+ throughput required for K8s etcd stability.

> RAM SLOT SELECTION: The NUC motherboard has two slots stacked vertically. For a single-module configuration, always use the BOTTOM slot (the one closest to the PCB). This is typically labeled DIMM 1 or Slot A. While signal termination was a concern with older DDR3/DDR4 RAM, modern DDR5 modules (like the CT48G56C46S5) have on-die termination (ODT) built-in, eliminating this issue. However, most motherboard BIOS/firmware expects Slot 0/A to be populated first, and some systems may fail to boot or require BIOS updates if only Slot 1 is populated.

### **2\. Vistara (The Expansion Roadmap)**

Brahmanda is designed to grow in discrete, logical iterations:

1. **Sthapana (Completion):** Max out the current node with a second 48GB module. **Crucial:** You must use the exact same model (**CT48G56C46S5**) to ensure matching CAS latency and clock speeds, reaching the total 96GB RAM target.
2. **Vistara (Horizontal Scale):** Add a secondary NUC node for compute high-availability or an **NVIDIA Jetson** for GPU/ML-accelerated workloads.
3. **Sanchaya (Collection):** Introduce a dedicated NAS (Network Attached Storage) or a multi-bay DAS to handle bulk backups and long-term data retention outside the NVMe pool.

### **3\. Physical Siting (Power & Connectivity)**

- **Power:** The NUC must be connected to its **120W/150W Barrel Charger**, which is plugged into a **Smart Plug** (acting as a remote Kill Switch), and then into the wall outlet. Do NOT attempt to power the unit solely via a Monitor's Thunderbolt port.
- **Location:** The NUC must be placed near the **Primary Router**. One ethernet port is the single point of entry for the entire universe; it must have a high-quality Cat6 physical link to the gateway.

## **Phase 2: Purvanga (Preliminary Reconnaissance)**

_Goal: Reconnoiter the void, map the data, and forge the keys to the kingdom._

### **1\. Anveshana (Gather Information)**

Run these commands on your **Windows host machine (PowerShell)** when connected to the same WiFi that the NUC box is going to be connected to.

> Do not gather this info from WSL, Docker, or VMs. These environments use virtual NAT bridges (172.x.x.x / 10.x.x.x) which are isolated from your physical router. You must use the native Host OS terminal.

\# 1\. Identify your Gateway and Subnet

```bash
ipconfig /all
```

\# 2\. Verify the chosen Static IP for the NUC is unoccupied
\# Expected result: "Request timed out"
`ping 192.168.68.200`

- **Target Gateway:** `192.168.68.1`
- **Subnet Mask:** `255.255.255.0` (CIDR: /24)
- **NUC Static IP:** `192.168.68.200`
  > Always pick an IP in the higher range (e.g., .200–.250). Standard routers typically assign DHCP leases to devices like phones and TVs starting from the bottom (.2, .3, etc.). Staying high prevents future "IP Conflict" errors.

## **Phase 3: Samidha (Preparation)**

_Goal: Setup cloud identities and generate credentials._

### **1\. AWS**

Generate AWS credentials that will be used by Terraform to provision Lightsail (Kshitiz):

- **Create IAM User:**

  - Name: `samsara-iac`
  - Permissions: `AmazonLightsailFullAccess`

- **Generate Access Keys:**
  - In AWS IAM console, create an access key for `samsara-iac`
  - This generates: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
  - **Store immediately in 1Password**

### **2\. Cloudflare**

Generate Cloudflare credentials for Terraform state and DNS management:

- **Create R2 Bucket:**

  - Name: `brahmanda-state` (holds Terraform state)
  - Name: `brahmanda-sanchaya-backups` (holds Longhorn snapshots)
  - Note the endpoint URL and bucket region

- **Create API Token:**
  - Permissions: `Account.Data Storage: Edit`
  - **Store immediately in 1Password** (Phase 4)
  - Also note: R2 API Token (access key + secret key for S3-compatible access)
  - **Store R2 credentials in 1Password** (Phase 4) for Longhorn storage

### **3\. Kshitiz - Nebula Mesh Infrastructure**

The Lighthouse requires a secure overlay network. Generate the foundational credentials:

#### **Nebula CA Certificate Generation (The Lighthouse Foundation)**

Generate the Nebula Certificate Authority (CA) locally. This is **required before any node deployment** and works independently of cloud infrastructure.

**Install Nebula (if not already installed):**

```bash
# On macOS
brew install nebula

# On Linux/WSL
wget https://github.com/slackhq/nebula/releases/download/v1.8.1/nebula-linux-amd64.tar.gz
tar xzf nebula-linux-amd64.tar.gz
sudo mv nebula nebula-cert /usr/local/bin/
```

**Generate the CA certificate:**

```bash
mkdir -p ~/.nebula
cd ~/.nebula
nebula-cert ca -name "Brahmanda" -duration 87600h
```

This creates `ca.crt` (public) and `ca.key` (private). The `ca.key` will be encrypted in Ansible Vault during Phase 4.

### **4\. Vyom - The cloud Infrastructure**

The compute cluster requires SSH access and K3s identity. Generate the foundational credentials.

#### **SSH Key-pair Generation for Nodes**

Generate the Ed25519 identity in WSL or Linux. This is your "Scepter" for all nodes.

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_brahmanda -C "abhishek@brahmanda"
```

#### **K3s Cluster Tokens**

K3s tokens are automatically generated during cluster bootstrap phase. After successful K3s initialization, capture the tokens and store them in Ansible Vault for disaster recovery.

## **Phase 4: Adhisthana (The Foundation)**

_Goal: Security is the foundation for good infrastructure. Ensure highest security by distribute secrets across the three-layer model._

### **Secret Storage Strategy**

**1Password (The Master Vault):**

- AWS Access Key ID and Secret Access Key
- Cloudflare API Token
- Ansible Vault Password (the master key)

**Ansible Vault (Encrypted in Git):**

- Nebula CA private key (ca.key)
- SSH private keys for nodes
- K3s cluster tokens
- Longhorn R2 credentials (access-key-id, secret-access-key, endpoint)

**GitHub Secrets (CI/CD Access):**

- `OP_SERVICE_ACCOUNT_TOKEN` (the only secret stored here)

### **How They Connect**

```
GitHub Actions
    ↓ (uses OP_SERVICE_ACCOUNT_TOKEN)
1Password
    ↓ (fetches AWS, Cloudflare, Ansible Vault Password)
Terraform & Ansible
    ↓ (uses Ansible Vault Password to decrypt)
Ansible Vault Files
    ↓ (provides infrastructure secrets)
Provisioning
```

### **Implementation Steps**

1. **1Password Setup:**

   - Create items for AWS credentials (access-key-id, secret-access-key)
   - Create item for Cloudflare API token
   - Create item for Ansible Vault Password
   - Create 1Password Service Account for GitHub integration

2. **Vault Consecration:**
   - Navigate to `samsara/ansible/group_vars/brahmanda/`
   - Populate `vault.yml` with infrastructure secrets (Nebula CA, SSH keys, K3s tokens)
   - **Encrypt (Gopana):** Run `make gopana` to encrypt the file using the password from 1Password.
   - **Edit (Samshodhana):** To make changes later, run `make samshodhana`.
   - **Decrypt (Prakasha):** If you need to view the raw file, run `make prakasha`.

## **Phase 5: Sarga (OS Consecration)**

_Goal: The "Touchless" installation of the Hypervisor._

1. **The Flavour:** Proxmox VE 8.x.
2. **The Method:** Use the **Proxmox Auto-Install Assistant**.
3. **The Metadata:** Prepare answer.toml with:
   - **IP:** 192.168.68.200/24
   - **Gateway:** 192.168.68.1
4. **The Act:** Boot from the "Baked" ISO. The NUC will format, install, and reboot into the network automatically.

## **Phase 6: Samsara (The Cycle of Life)**

_Goal: Running the automation from GitHub Actions._

### **GitHub Configuration**

1. **Store the 1Password Service Account Token:**

   - Add `OP_SERVICE_ACCOUNT_TOKEN` to GitHub Repository Secrets
   - This is the ONLY secret stored in GitHub

2. **Configure Workflow to Use 1Password:**
    ```yaml
    - name: Load secrets from 1Password
      uses: 1password/load-secrets-action@v1
      with:
        export-env: true
      env:
        OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        AWS_ACCESS_KEY_ID: op://Private/AWS-samsara-iac/access-key-id
        AWS_SECRET_ACCESS_KEY: op://Private/AWS-samsara-iac/secret-access-key
        CLOUDFLARE_API_TOKEN: op://Private/Cloudflare/api-token
        ANSIBLE_VAULT_PASSWORD: op://Private/Ansible Vault - Samsara/password
    ```

    **Alternative (Stricter Approach):** For principle of least privilege, use `export-env: false` with explicit exports to prevent `OP_SERVICE_ACCOUNT_TOKEN` from being exposed to subsequent steps:
    ```yaml
    - name: Load secrets from 1Password
      uses: 1password/load-secrets-action@v1
      env:
        OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
      with:
        export-env: false
        export: |
          AWS_ACCESS_KEY_ID=op://Private/AWS-samsara-iac/access-key-id
          AWS_SECRET_ACCESS_KEY=op://Private/AWS-samsara-iac/secret-access-key
          CLOUDFLARE_API_TOKEN=op://Private/Cloudflare/api-token
          ANSIBLE_VAULT_PASSWORD=op://Private/Ansible Vault - Samsara/password
    ```

### **Execution Flow**

1. **Trigger:** Push to main branch
2. **GitHub Actions:**
   - Fetches secrets from 1Password using service account
   - Exports AWS and Cloudflare credentials for Terraform
   - Exports Ansible Vault Password for playbook decryption
3. **Terraform:** Provisions Lightsail (Kshitiz) and Proxmox VMs (Vyom)
4. **Ansible:** Decrypts vault files and configures infrastructure

## **Phase 7: Srishti (The Manifestation)**

_Goal: The Big Bang. Bringing the universe into existence._

We use the **Makefile** to invoke the creation.

1. **Invoke Creation:**
   ```bash
   make srishti
   ```
   *Action:* This single command provisions Kshitiz (Edge) and Vyom (Compute), and bootstraps the Kubernetes cluster.

**Brahmanda is now Manifested.**
