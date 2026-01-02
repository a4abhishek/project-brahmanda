# Sarga (Creation of Material Elements and Metaphysical Principles)

<p align="center">
न रूपमस्येह तथोपलभ्यते, नान्तो न चादिर्न च सम्प्रतिष्ठा | <br>
अश्वत्थमेनं सुविरूढमूल, मसङ्गशस्त्रेण दृढेन छित्त्वा ||

"The real form of this tree (of Brahmanda) is not perceived in this world... Having cut down this firmly rooted tree with the strong weapon of detachment..." (Bhagavad Gita 15.3)

</p>

## Introduction

This document is the definitive **Day 0 manual for Project Brahmanda**. It describes the transition from physical void to a fully manifested digital universe.

It serves as the immutable **Blueprint** for Project Brahmanda, written with the explicit understanding that all infrastructure is **transient**. We wield the **Weapon of Detachment**—Infrastructure as Code—to sever dependency on individual nodes, enabling us to replicate, destroy, and recreate the universe without hesitation or attachment.

## **Phase 0: Samidha (Before You Begin)**

Before starting the manifestation process, ensure you have:

### **Accounts & Access**

- **1Password Account:** You must have a 1Password account (individual or family plan). This will serve as the secure vault for all credentials.
- **AWS Account:** An active AWS account with billing enabled.
- **Cloudflare Account:** An active Cloudflare account with R2 storage access.
- **GitHub Account:** An active GitHub account where this repository will be hosted.

### **Software Requirements**

- **Operating System:** Windows 10/11, macOS, or Linux.
- **Terminal Access:** PowerShell (Windows), Terminal (macOS), or Bash (Linux).
- **Git:** Installed and configured with your GitHub credentials.
- **1Password CLI (`op`):** Install from [1Password Developer Docs](https://developer.1password.com/docs/cli/get-started/).

### **Skills Assumed**

- Basic command-line navigation (cd, ls/dir, running commands).
- Ability to copy-paste credentials securely.
- Understanding of what an IP address and subnet mask are.

## **Phase 1: Upadana (The Material Cause)**

_Goal: Procure high-performance, SRE-grade hardware. We prioritize specific component speeds to ensure Vyom is not bottlenecked at the storage or memory bus._

### **1\. Core Hardware Specifications**

| Component   | Specification                                   | Source                                                                                                                                                                                          | Price         |
| :---------- | :---------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------ |
| **Node**    | ASUS NUC 14 Pro Plus Kit Slim (NUC14RVSU5)      | [ITGadgets](https://itgadgetsonline.com/product/asus-nuc-14-pro-plus-kit-slim-nuc14rvsu5-mini-pc-barebone/)                                                                                     | ₹41,734       |
| **Memory**  | 48GB **DDR5 SO-DIMM** 5600Mhz (CT48G56C46S5)    | [NationalPC](https://nationalpc.in/laptop-memory/crucial-48gb-ddr5-5600mhz-so-dimm-ct48g56c46s5)                                                                                                | ₹41,300       |
| **Storage** | 2TB **NVMe M.2 Gen4** (SN850X \- 7300MB/s Read) | [Amazon](https://www.amazon.in/dp/B0B7CMZ3QH)                                                                                                                                                   | ₹25,600       |
| **Cable**   | Cat6 Snagless (Pure Bare Copper)                | [Amazon](https://www.amazon.in/dp/B0875SPZC8)                                                                                                                                                   | ₹1439         |
| **Switch**  | Smart Plug (16A - Remote Kill Switch)           | [Amazon](https://www.amazon.in/Wipro-Monitoring-Appliances-Microwave-Conditioners/dp/B08HN9Q2SZ/ref=sr_1_2_sspa?s=home-improvement&sr=1-2-spons&aref=BpzHKHMwVr&sp_csd=d2lkZ2V0TmFtZT1zcF9hdGY) | ₹1,000        |
| **Total**   | **Current Manifested Investment**               |                                                                                                                                                                                                 | **₹1,11,073** |

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

#### 1\. Identify your Gateway and Subnet

```bash
ipconfig /all
```

#### 2\. Verify the chosen Static IP for the NUC is unoccupied
```bash
ping 192.168.68.200   # Expected result: "Request timed out"
```

- **Target Gateway:** `192.168.68.1`
- **Subnet Mask:** `255.255.255.0` (CIDR: /24)
- **NUC Static IP:** `192.168.68.200`
  > Always pick an IP in the higher range (e.g., .200–.250). Standard routers typically assign DHCP leases to devices like phones and TVs starting from the bottom (.2, .3, etc.). Staying high prevents future "IP Conflict" errors.

## **Phase 3: Pramana (The Credentials)**

_Goal: Generate authentication credentials and cryptographic identities for all infrastructure components._

### **1\. AWS**

Generate AWS credentials that will be used by Terraform to provision Lightsail (Kshitiz):

- **Create IAM User:**

  - Name: `samsara-iac`
  - Permissions: `AmazonLightsailFullAccess` and it's dependencies

    <details>
    <summary>Complete list of permissions</summary>

    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "LightSailPermissions",
          "Effect": "Allow",
          "Action": [
            "lightsail:*",
            "iam:CreateServiceLinkedRole",
            "route53domains:ListDomains",
            "route53domains:ListOperations",
            "route53:GetHostedZone",
            "route53domains:UpdateDomainNameservers",
            "route53:DeleteHostedZone",
            "route53domains:GetDomainDetail",
            "iam:PutRolePolicy",
            "route53:ListHostedZonesByName",
            "route53domains:GetOperationDetail"
          ],
          "Resource": "*"
        }
      ]
    }
    ```

    </details>

- **Generate Access Keys:**

  - In the **AWS IAM Console**, navigate to **Users** → `samsara-iac` → **Security Credentials** tab.
  - Click **Create Access Key** → Choose **Application running outside AWS** → Click **Next** → Add description "Terraform Automation" → Click **Create Access Key**.
  - This will generate `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
  - **CRITICAL:** The Secret Access Key is shown **only once**. Do not close the page until stored in 1Password.

  <details>
  <summary>1Password Storage Instructions</summary>

  **Step 1:** Open 1Password and create a new vault named **"Project-Brahmanda"** if it doesn't exist.

  **Step 2:** Create a new **Login** item with these details:

  - **Title:** `AWS-samsara-iac`
  - **Username:** (leave blank or use your AWS account ID)
  - **Add Field → Section:** `Security Credentials`
  - **Add Field → Text:** `AWS_ACCESS_KEY_ID` → Paste the Access Key ID from AWS
  - **Add Field → Password:** `AWS_ACCESS_KEY_SECRET` → Paste the Secret Access Key from AWS

  **Step 3:** Save the item. You can now close the AWS page.
  </details>

  **✅ Verification:** Run `op read "op://Project-Brahmanda/AWS-samsara-iac/Security Credentials/AWS_ACCESS_KEY_ID"` in your terminal. It should print your Access Key ID.

  > **💡 TIP:** In 1Password, you can easily copy the secret reference path by clicking the **▼** (downward arrow) next to any field and selecting **"Copy Secret Reference"**. This gives you the exact `op://...` path to use in commands and scripts.

### **2\. Cloudflare**

Generate Cloudflare credentials for Terraform state and DNS management:

- **Create R2 Buckets:**

  - Log into Cloudflare Dashboard → Navigate to **R2 Object Storage**.
  - Create two buckets:
    1. `brahmanda-state` (holds Terraform state)
    2. `brahmanda-sanchaya-backups` (holds Longhorn snapshots)
  - Note the **Account ID** from the R2 page (you'll need this later).

- **Create API Token:**

  - In Cloudflare Dashboard, go to **My Profile** → **API Tokens** → **Create Token**.
  - Choose **Edit Cloudflare Workers** template OR create custom token with:
    - **Permissions:** `Account.Data Storage: Edit`
  - Click **Continue to Summary** → **Create Token**.
  - **Copy the token immediately** (it's shown only once).

  <details>
  <summary>1Password Storage Instructions</summary>

  **Step 1:** In 1Password, create a new **API Credential** item:

  - **Title:** `Cloudflare`
  - **Add Field → Password:** `api-token` → Paste the API token from Cloudflare
  - **Add Field → Text:** `account-id` → Paste your Cloudflare Account ID
  - **Add Field → Text:** `r2-endpoint` → `https://<account-id>.r2.cloudflarestorage.com` (replace `<account-id>`)

  **Step 2:** Save the item.
  </details>

  **✅ Verification:** Run `op read "op://Project-Brahmanda/Cloudflare/api-token"` to confirm it's stored correctly.

  > **💡 TIP:** Click the **▼** next to the field in 1Password and select **"Copy Secret Reference"** to get the exact path.

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

**✅ Verification:** Run `ls -la ~/.nebula/`. You should see two files:

- `ca.crt` (Nebula CA certificate - public)
- `ca.key` (Nebula CA private key - **NEVER share this**)

### **4\. Vyom - The cloud Infrastructure**

The compute cluster requires SSH access and K3s identity. Generate the foundational credentials.

#### **SSH Key-pair Generation for Nodes**

Generate the Ed25519 identity in WSL or Linux. This is your "Scepter" for all nodes.

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_brahmanda -C "abhishek@brahmanda"
```

**When prompted:**

- **Enter passphrase:** Press Enter (leave empty) for automation compatibility.
- **Enter same passphrase again:** Press Enter again.

**✅ Verification:** Run `ls -la ~/.ssh/id_brahmanda*`. You should see:

- `id_brahmanda` (private key)
- `id_brahmanda.pub` (public key)

#### **K3s Cluster Tokens**

K3s tokens are automatically generated during cluster bootstrap phase. After successful K3s initialization, capture the tokens and store them in Ansible Vault for disaster recovery.

## **Phase 4: Adhisthana (The Foundation)**

_Goal: Secure all credentials in a structured, recoverable manner._

### **Understanding the Three-Layer Security Model**

We distribute secrets across three layers for resilience and security:

**Layer 1: 1Password (The Master Vault)**

- AWS Access Key ID and Secret Access Key ✅ (Already stored in Phase 3)
- Cloudflare API Token ✅ (Already stored in Phase 3)
- Ansible Vault Password ⬅️ (You'll create this now)

**Layer 2: Ansible Vault (Encrypted in Git)**

- Nebula CA private key (`ca.key`)
- SSH private keys for nodes
- K3s cluster tokens (added later during cluster bootstrap)
- Longhorn R2 credentials

**Layer 3: GitHub Secrets (CI/CD Only)**

- `OP_SERVICE_ACCOUNT_TOKEN` (added later when setting up CI/CD)

### **Secret Flow (How They Connect)**

```text
GitHub Actions
    ↓ (uses OP_SERVICE_ACCOUNT_TOKEN)
1Password (Project-Brahmanda Vault)
    ↓ (fetches AWS, Cloudflare, Ansible Vault Password)
Terraform & Ansible
    ↓ (uses Ansible Vault Password to decrypt)
Ansible Vault Files
    ↓ (provides infrastructure secrets)
Provisioning
```

### **Step-by-Step Implementation**

#### **Step 1: Generate the Ansible Vault Password**

This password will encrypt all infrastructure secrets in Git.

```bash
# Generate a cryptographically secure password
openssl rand -base64 32
```

Copy the output (it will look like: `aBc123dEf456gHi789...`).

#### **Step 2: Store the Ansible Vault Password in 1Password**

1. Open 1Password → Navigate to the **"Project-Brahmanda"** vault.
2. Create a new **Password** item:
   - **Title:** `Ansible Vault - Samsara`
   - **Password field:** Paste the password you just generated.
3. Save the item.

**✅ Verification:** Run `op read "op://Project-Brahmanda/Ansible Vault - Samsara/password"` to confirm.

> **💡 TIP:** Use the **▼** → **"Copy Secret Reference"** feature in 1Password to easily get the secret path for any field.

#### **Step 3: Prepare the Ansible Vault Directory Structure**

```bash
cd samsara/ansible
mkdir -p group_vars/brahmanda
mkdir -p group_vars/kshitiz
mkdir -p group_vars/vyom
```

#### **Step 4: Populate the Ansible Vault with Secrets**

Create the main vault file:

```bash
cd group_vars/brahmanda
cat > vault.yml << 'EOF'
---
# Global Infrastructure Secrets

# Nebula CA Private Key
nebula_ca_key: |
EOF
```

Now append the Nebula CA key:

```bash
cat ~/.nebula/ca.key >> vault.yml
```

Add SSH private key:

```bash
cat >> vault.yml << 'EOF'

# SSH Private Key for Nodes
ssh_private_key: |
EOF
cat ~/.ssh/id_brahmanda >> vault.yml
```

**Important:** The file is currently in plain text. We'll encrypt it in the next step.

#### **Step 5: Encrypt the Vault (Gopana)**

Return to the repository root and encrypt the vault:

```bash
cd ~/path/to/project-brahmanda
make gopana
```

This will:

1. Fetch the Ansible Vault Password from 1Password.
2. Encrypt `group_vars/brahmanda/vault.yml`.
3. The file is now safe to commit to Git.

**✅ Verification:** Run `cat samsara/ansible/group_vars/brahmanda/vault.yml`. You should see encrypted content starting with `$ANSIBLE_VAULT;1.1;AES256`.

#### **Step 6: Future Vault Management**

Use these commands to manage the vault:

- **Edit Vault (Samshodhana):** Opens the vault in your editor, decrypts in memory, re-encrypts on save.

  ```bash
  make samshodhana
  ```

- **Decrypt Vault (Prakasha):** Decrypts to plain text (use sparingly, for debugging only).

  ```bash
  make prakasha
  ```

- **Re-encrypt Vault (Gopana):** Encrypts the vault after manual editing.
  ```bash
  make gopana
  ```

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
       AWS_ACCESS_KEY_ID: op://Project-Brahmanda/AWS-samsara-iac/Security Credentials/AWS_ACCESS_KEY_ID
       AWS_SECRET_ACCESS_KEY: op://Project-Brahmanda/AWS-samsara-iac/Security Credentials/AWS_ACCESS_KEY_SECRET
       CLOUDFLARE_API_TOKEN: op://Project-Brahmanda/Cloudflare/api-token
       ANSIBLE_VAULT_PASSWORD: op://Project-Brahmanda/Ansible Vault - Samsara/password
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
         AWS_ACCESS_KEY_ID=op://Project-Brahmanda/AWS-samsara-iac/Security Credentials/AWS_ACCESS_KEY_ID
         AWS_SECRET_ACCESS_KEY=op://Project-Brahmanda/AWS-samsara-iac/Security Credentials/AWS_ACCESS_KEY_SECRET
         CLOUDFLARE_API_TOKEN=op://Project-Brahmanda/Cloudflare/api-token
         ANSIBLE_VAULT_PASSWORD=op://Project-Brahmanda/Ansible Vault - Samsara/password
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
   _Action:_ This single command provisions Kshitiz (Edge) and Vyom (Compute), and bootstraps the Kubernetes cluster.

**Brahmanda is now Manifested.**
