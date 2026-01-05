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

### **Core Hardware Specifications**

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

### **Vistara (The Expansion Roadmap)**

Brahmanda is designed to grow in discrete, logical iterations:

1. **Sthapana (Completion):** Max out the current node with a second 48GB module. **Crucial:** You must use the exact same model (**CT48G56C46S5**) to ensure matching CAS latency and clock speeds, reaching the total 96GB RAM target.
2. **Vistara (Horizontal Scale):** Add a secondary NUC node for compute high-availability or an **NVIDIA Jetson** for GPU/ML-accelerated workloads.
3. **Sanchaya (Collection):** Introduce a dedicated NAS (Network Attached Storage) or a multi-bay DAS to handle bulk backups and long-term data retention outside the NVMe pool.

### **Physical Siting (Power & Connectivity)**

- **Power:** The NUC must be connected to its **120W/150W Barrel Charger**, which is plugged into a **Smart Plug** (acting as a remote Kill Switch), and then into the wall outlet. Do NOT attempt to power the unit solely via a Monitor's Thunderbolt port.
- **Location:** The NUC must be placed near the **Primary Router**. One ethernet port is the single point of entry for the entire universe; it must have a high-quality Cat6 physical link to the gateway.

## **Phase 2: Sanghatana (Hardware Assembly)**

_Goal: Transform procured components into a unified, operational compute node._

### **Prerequisites**

Before starting assembly, ensure you have:

- All components from Phase 1 (NUC, RAM, NVMe SSD, Cat6 cable, Smart Plug)
- Clean, static-free workspace
- Small Phillips-head screwdriver (for NUC bottom panel)
- Flathead screwdriver (for chassis lock mechanism)
- Soft cloth or anti-static mat (optional but recommended)

### **Assembly Steps**

#### **Step 1: Unbox and Inventory Check**

1. **Unbox the NUC barebone kit**
2. **Verify contents:**
   - ASUS NUC 14 Pro Plus chassis
   - 120W/150W barrel charger with power cable
   - VESA mounting bracket (optional, not used for desk placement)
   - Quick start guide
3. **Verify other components:**
   - 48GB DDR5 SO-DIMM RAM module (CT48G56C46S5)
   - 2TB NVMe M.2 SSD (WD SN850X)
   - Cat6 ethernet cable
   - Smart Plug

#### **Step 2: Open the NUC Chassis**

1. **Place NUC bottom-side up** on soft cloth
2. **Locate the bottom panel screws** (typically 4 Phillips-head screws)
3. **Remove screws** and carefully lift the bottom panel
4. **Set panel and screws aside** in a safe location

> **💡 TIP:** Some NUC models have a sliding latch mechanism instead of screws. Consult the quick start guide if you don't see screws. If your NUC has a chassis lock (security slot with flathead screw), use a flathead screwdriver to unlock it before attempting to remove the bottom panel.

#### **Step 3: Install RAM Module**

1. **Locate the RAM slots** (two SO-DIMM slots stacked vertically)
2. **Use the BOTTOM slot** (closest to the PCB, labeled DIMM 1 or Slot A)
3. **Insert RAM module:**
   - Hold module by edges (avoid touching gold contacts)
   - Align notch on module with key in slot
   - Insert at 45-degree angle
   - Press down firmly until clips snap into place
4. **Verify:** Module should sit flush and locked by side clips

> **⚠️ CRITICAL:** Modern DDR5 has on-die termination (ODT), but BIOS expects Slot 0/A to be populated first. Using the bottom slot prevents boot issues.

**✅ Verification:** Gently try to pull the module up - it should not budge if properly seated.

#### **Step 4: Install NVMe SSD**

1. **Locate the M.2 slot** (usually near the RAM slots, labeled M.2 or NVMe)
2. **Remove the M.2 standoff screw** if pre-installed
3. **Insert NVMe SSD:**
   - Hold SSD by edges
   - Align notch on SSD with key in M.2 slot
   - Insert at 30-degree angle
   - Push down gently until SSD is parallel to motherboard
4. **Secure with standoff screw** - do NOT overtighten (finger-tight is sufficient)

> **💡 TIP:** The NUC supports PCIe Gen 4 speeds. Ensure the SSD is in the primary M.2 slot (some models have multiple slots with different speeds).

**✅ Verification:** SSD should be flat against the PCB, secured by the standoff screw, with no visible gap.

#### **Step 5: Close the Chassis**

1. **Inspect for loose components** or forgotten screws
2. **Replace the bottom panel** - align carefully
3. **Reinstall screws** - tighten in diagonal pattern (prevents warping)
4. **Lock chassis** (if equipped): Use flathead screwdriver to engage the chassis lock mechanism (typically a security slot near the panel edge)
5. **Flip NUC right-side up**

> **💡 TIP:** The chassis lock prevents unauthorized access to internal components. While optional for home use, it's good practice to engage it for security.

#### **Step 6: Connect Power and Network**

1. **Place NUC near your router** (within Cat6 cable reach)
2. **Connect ethernet:**
   - Plug Cat6 cable into NUC's ethernet port
   - Plug other end into router's LAN port
3. **Connect power chain:**
   - Plug barrel charger into NUC's power port
   - Plug barrel charger into Smart Plug
   - Plug Smart Plug into wall outlet
4. **Configure Smart Plug** (if needed):
   - Follow manufacturer's app setup
   - Name it "Brahmanda-NUC-Power" for easy identification
   - Test remote on/off capability

> **⚠️ WARNING:** Do NOT attempt to power the NUC via USB-C from a monitor's Thunderbolt port. The NUC requires dedicated 120W/150W power via barrel connector.

#### **Step 7: First Power-On Test**

1. **Press the power button** on the NUC front panel
2. **Observe:**
   - Power LED should illuminate (white or blue)
   - Fan should spin briefly
   - BIOS/UEFI POST screen should appear on connected monitor
3. **Expected behavior:**
   - "No bootable device" message (normal - no OS installed yet)
   - Access BIOS by pressing **F2** or **DEL** during boot
4. **In BIOS, verify:**
   - RAM recognized: Should show 48GB (or ~47.xGB accounting for system reserved)
   - SSD recognized: Should show WD SN850X 2TB (or similar)
   - Boot order: UEFI mode enabled, secure boot settings
5. **Power off** the NUC

**✅ Verification Checklist:**

- ✅ RAM detected at full capacity (48GB)
- ✅ NVMe SSD detected (2TB)
- ✅ Ethernet link established (check router's device list)
- ✅ Smart Plug remote control works
- ✅ No beeping or error codes during POST

### **Troubleshooting**

**No Power / No POST:**

- Verify barrel charger firmly connected at both ends
- Try different wall outlet (bypass Smart Plug temporarily)
- Check if NUC has a dedicated power switch on back panel

**RAM Not Detected:**

- Reseat RAM module (remove and reinstall)
- Ensure using bottom slot (Slot A/DIMM 1)
- Check for bent pins in RAM slot

**SSD Not Detected:**

- Reseat NVMe SSD
- Verify M.2 standoff screw not too tight (can damage PCB)
- Confirm SSD is PCIe NVMe (not SATA M.2)

**Ethernet No Link:**

- Check cable not damaged (crimp ends, kinks)
- Try different router port
- Verify router powered on

### **What's Next**

With hardware assembled and verified, you're ready to proceed to network reconnaissance and OS installation.

## **Phase 3: Purvanga (Preliminary Reconnaissance)**

_Goal: Reconnoiter the void, map the data, and forge the keys to the kingdom._

### **Anveshana (Gather Information)**

Run these commands on your **Windows host machine (PowerShell)** when connected to the same WiFi that the NUC box is going to be connected to.

> Do not gather this info from WSL, Docker, or VMs. These environments use virtual NAT bridges (172.x.x.x / 10.x.x.x) which are isolated from your physical router. You must use the native Host OS terminal.

#### **Step 1: Identify your Gateway and Subnet**

```bash
ipconfig /all
```

#### **Step 2: Verify the chosen Static IP for the NUC is unoccupied**

```bash
ping 192.168.68.200   # Expected result: "Request timed out"
```

**Document your discovered network values:**

From `ipconfig /all` output, record these values:

- **Gateway:** (Example: `192.168.68.1`)
- **Subnet Mask:** (Example: `255.255.240.0` = /20, provides 4096 IPs)
- **Chosen Static IP for Proxmox:** (Example: `192.168.68.200`)

> **IP Selection:** Always pick an IP in the higher range (e.g., .200–.250). Standard routers assign DHCP leases starting from the bottom (.2, .3, etc.). Staying high prevents future IP conflicts.

> **⚠️ Day 0 Temporary Configuration:** We use your existing router's network settings for initial Proxmox installation. Once Proxmox is running, we'll configure **proper network segmentation** with VLANs (documented in `002-Visarga.md`):
>
> - **VLAN 20:** `192.168.20.0/24` - Management (Proxmox host, 254 usable IPs)
> - **VLAN 30:** `192.168.30.0/24` - DMZ (K3s nodes, 254 usable IPs)
>
> This separates infrastructure from user devices and provides the recommended /24 subnet per layer.

## **Phase 4: Pramana (The Credentials)**

_Goal: Generate authentication credentials and cryptographic identities for all infrastructure components._

### **Step 1: AWS Credentials**

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
  - **Add Field → Text:** `AWS_ACCESS_KEY_ID` → Paste the Access Key ID from AWS
  - **Add Field → Password:** `AWS_SECRET_ACCESS_KEY` → Paste the Secret Access Key from AWS

  **Step 3:** Save the item. You can now close the AWS page.
  </details>

  **✅ Verification:** Run `op read "op://Project-Brahmanda/AWS-samsara-iac/AWS_ACCESS_KEY_ID"` in your terminal. It should print your Access Key ID.

  > **💡 TIP:** In 1Password, you can easily copy the secret reference path by clicking the **▼** (downward arrow) next to any field and selecting **"Copy Secret Reference"**. This gives you the exact `op://...` path to use in commands and scripts.

### **Step 2: Cloudflare Credentials**

Generate Cloudflare credentials for Terraform state and DNS management:

- **Create R2 Buckets:**

  - Log into Cloudflare Dashboard → Navigate to **R2 Object Storage**.
  - Create two buckets:
    1. `brahmanda-state` (holds Terraform state)
       - **Location:** Automatic (Hint: Asia Pacific (APAC) for lowest latency from India)
       - **Storage Class:** Standard
    2. `brahmanda-sanchaya-backups` (holds Longhorn snapshots)
       - **Location:** Automatic (Hint: Asia Pacific (APAC))
       - **Storage Class:** Standard
  - **Copy the Account ID:**
    - Click the account dropdown (↕️ icon) in the top-left corner → Select **Account Home**.
    - Next to your Account name, click the **⋮** (three vertical dots) → Select **Copy Account ID**.
    - Save this ID temporarily; you'll store it in 1Password in the next step.

  > **💡 TIP:** Both buckets use Standard storage to stay within R2's free tier (10GB storage, 1M Class A operations/month). Infrequent Access doesn't qualify for free tier. Once your backups exceed 10GB or you need cost optimization, consider migrating `brahmanda-sanchaya-backups` to Infrequent Access (~50% cheaper, but paid from first byte).

- **Create API Token:**

  - In Cloudflare Dashboard, go to **My Profile** → **API Tokens** → **Create Token**.
  - Click **Create Custom Token**.
  - **Token name:** `Brahmanda-Sanchay-Token`
  - **Permissions:** Click **Add** and configure:
    - First dropdown: Select **Account**
    - Second dropdown: Select **Workers R2 Storage**
    - Third dropdown: Select **Edit**
  - **Account Resources:**
    - First dropdown: Select **Include**
    - Second dropdown: Select your account (e.g., "Aarohini" or your Cloudflare account name)
  - Leave **IP Address Filtering** and **TTL** sections at defaults (optional).
  - Click **Continue to Summary**.
  - **Verify the summary shows:** `<Your-Account-Name> - Workers R2 Storage:Edit`
  - Click **Create Token**.
  - **CRITICAL:** The token is shown **only once**. Do not close the page until stored in 1Password.
  - Cloudflare will show a `curl` command to test the token—save this for verification.

  <details>
  <summary>1Password Storage Instructions</summary>

  **Step 1:** Open 1Password and navigate to the **"Project-Brahmanda"** vault.

  **Step 2:** Create a new **API Credential** item with these details:

  - **Title:** `Cloudflare-Sanchay-Token`
  - **Username:** (leave blank)
  - **Add Field → Password:** `CLOUDFLARE_API_TOKEN` → Paste the API token from Cloudflare
  - **Add Field → Text:** `CLOUDFLARE_ACCOUNT_ID` → Paste your Cloudflare Account ID (copied earlier)
  - **Add Field → Text:** `R2_ENDPOINT` → `https://<account-id>.r2.cloudflarestorage.com` (replace `<account-id>` with your actual Account ID)

  **Step 3:** Save the item. You can now close the Cloudflare page.
  </details>

  **✅ Verification:**

  1. Test the API token using the `curl` command provided by Cloudflare (it verifies the token works).
  2. Run `op read "op://Project-Brahmanda/Cloudflare-Sanchay-Token/CLOUDFLARE_API_TOKEN"` to confirm it's stored correctly in 1Password.

  > **💡 TIP:** Click the **▼** next to the field in 1Password and select **"Copy Secret Reference"** to get the exact path.

  > **💡 NOTE:** The `R2_ENDPOINT` field is stored as configuration for IaC tools. While it can be generated programmatically from the Account ID, storing it explicitly in 1Password is common practice—it makes Terraform/Ansible configurations more readable and reduces string interpolation errors.

### **Step 3: Kshitiz - Nebula Mesh Infrastructure**

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

This creates `ca.crt` (public) and `ca.key` (private). The `ca.key` will be encrypted in Ansible Vault during Phase 5.

**✅ Verification:** Run `ls -la ~/.nebula/`. You should see two files:

- `ca.crt` (Nebula CA certificate - public)
- `ca.key` (Nebula CA private key - **NEVER share this**)

**💡 Optional: Store in 1Password for Backup**

While this key will be encrypted in Ansible Vault (Phase 5), you can optionally store it in 1Password as a disaster recovery backup:

1. Open 1Password → Navigate to **"Project-Brahmanda"** vault.
2. Create a new **Secure Note** item:
   - **Title:** `Nebula-CA-Root-Key`
   - In the note field, paste the contents of `~/.nebula/ca.key` (the CA private key)
3. Add a field for the public certificate:
   - **Add Field → Text:** `ca.crt` → Paste the contents of `~/.nebula/ca.crt`
4. Save the item.

⚠️ **CRITICAL:** This is the root certificate authority for your entire Nebula mesh. If lost, the entire mesh must be rebuilt from scratch. The 1Password backup provides an additional recovery layer independent of Ansible Vault.

### **Step 4: Vyom - Cluster Infrastructure**

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

**💡 Optional: Store in 1Password for Backup**

While this key will be encrypted in Ansible Vault (Phase 5), you can optionally store it in 1Password as a disaster recovery backup:

1. Open 1Password → Navigate to **"Project-Brahmanda"** vault.
2. Create a new **SSH Key** item:
   - **Title:** `Vyom-Node-Key-Pair`
   - **Private Key field:** Paste the contents of `~/.ssh/id_brahmanda` (the private key)
3. Save the item.

1Password will automatically generate and display the public key and fingerprint from the private key. This provides an additional backup layer independent of Ansible Vault.

#### **K3s Cluster Tokens**

K3s tokens are automatically generated during cluster bootstrap phase. After successful K3s initialization:

1. Capture the tokens from the cluster.
2. Store them in Ansible Vault for disaster recovery (primary storage).
3. **Optionally**, back them up in 1Password:
   - Create a new **Secure Note** item titled `K3s-Cluster-Tokens`
   - Store the server token and agent token as separate fields
   - This provides an additional recovery layer if Ansible Vault password is lost

## **Phase 5: Adhisthana (The Foundation)**

_Goal: Secure all credentials in a structured, recoverable manner._

### **Understanding the Three-Layer Security Model**

We distribute secrets across three layers for resilience and security:

**Layer 1: 1Password (The Master Vault)**

- AWS Access Key ID and Secret Access Key ✅ (Already stored in Phase 4)
- Cloudflare API Token ✅ (Already stored in Phase 4)
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

### **Implementation Steps**

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
mkdir -p samsara/ansible/group_vars/brahmanda
mkdir -p samsara/ansible/group_vars/kshitiz
mkdir -p samsara/ansible/group_vars/vyom
```

#### **Step 4: Populate the Ansible Vault with Secrets**

Create the main vault file:

```bash
pushd samsara/ansible/group_vars/brahmanda
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

#### **Step 5: Encrypt the Vault (Tirodhana)**

Return to the repository root and encrypt the vault:

```bash
popd # Change current directory to project-brahmanda root
make tirodhana VAULT=brahmanda
```

This will:

1. Fetch the Ansible Vault Password from 1Password.
2. Encrypt `group_vars/brahmanda/vault.yml`.
3. The file is now safe to commit to Git.

**✅ Verification:** Run `cat samsara/ansible/group_vars/brahmanda/vault.yml`. You should see encrypted content starting with `$ANSIBLE_VAULT;1.1;AES256`.

#### **Step 6: Future Vault Management**

Use these commands to manage vaults:

- **Encrypt All Vaults (Tirodhana):** Encrypts all vault files (brahmanda, kshitiz, vyom).

  ```bash
  make tirodhana
  ```

  To encrypt a specific vault:

  ```bash
  make tirodhana VAULT=brahmanda
  make tirodhana VAULT=kshitiz
  make tirodhana VAULT=vyom
  ```

- **Decrypt All Vaults (Avirbhava):** Decrypts all vault files (use sparingly, for debugging only).

  ```bash
  make avirbhava
  ```

  To decrypt a specific vault:

  ```bash
  make avirbhava VAULT=brahmanda
  ```

- **Edit Vault (Samshodhana):** Opens a specific vault in your editor, decrypts in memory, re-encrypts on save. **Requires VAULT parameter.**

  ```bash
  make samshodhana VAULT=brahmanda
  ```

## **Phase 6: Pratistha (OS Consecration)**

_Goal: The "Touchless" installation of the Hypervisor using Infrastructure as Code._

### **The Philosophy: Repeatable and Transient**

This phase embodies the **Weapon of Detachment**. We create an `answer.toml` file (Infrastructure as Code for OS installation) that:

- Automates Proxmox installation without human interaction
- Can be stored in Git and versioned
- Enables destroying and recreating the exact same installation at will
- Makes hardware replacements trivial (new NUC = boot from USB, identical configuration)

**Important Scope Clarification:**

- **This phase installs:** Proxmox VE (the hypervisor operating system) on bare metal
- **This phase does NOT create:** Virtual machines, K3s clusters, or application services
- **Next phase (Samsara):** Uses Terraform to create VMs inside Proxmox, then Ansible to configure them

Think of it as a layered approach:

```
Phase 2 (Sanghatana): Hardware assembly → Operational compute node
Phase 6 (Pratistha):  answer.toml → Proxmox VE OS installed on NUC
Phase 7 (Samsara):    Terraform → VMs created inside Proxmox → Ansible → K3s cluster ready
Phase 8 (Srishti):    GitOps → K3s + Applications deployed
```

**What Gets Committed to Git:**

- ✅ `answer.toml` (template with placeholders/commented SSH keys)
- ✅ Terraform code, Ansible playbooks
- ❌ `answer.local.toml` (your actual config with SSH keys - gitignored)
- ❌ Proxmox VE ISO (1-2GB, available from official source)
- ❌ SSH private keys (store in 1Password)

### **Installation Steps**

#### **Step 1: Download Proxmox VE ISO**

1. Visit [Proxmox VE Downloads](https://www.proxmox.com/en/downloads/proxmox-virtual-environment)
2. Download **Proxmox VE 9.1-1 ISO Installer** (latest stable version)
3. Verify the checksum (optional but recommended for security)

> **💡 NOTE:** Do NOT commit the ISO file to Git. ISOs are ~2GB and would bloat the repository permanently. The answer.toml configuration is what gets committed - it enables downloading and installing from official sources with verifiable checksums.

#### **Step 2: Create Auto-Install Configuration Template (answer.toml)**

Create the template configuration file that will be committed to Git:

```bash
mkdir -p samsara/proxmox   # Run it from project-brahmanda repository root
cat > samsara/proxmox/answer.toml << 'EOF'
[global]
keyboard = "us"
country = "us"
fqdn = "proxmox.brahmanda.local"
mailto = "avskksyp@gmail.com"
timezone = "Asia/Kolkata"
root_password = "CHANGE_THIS_TEMPORARY_PASSWORD"

# SSH Public Keys (RECOMMENDED - provides passwordless authentication)
root_ssh_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-key-here"
]

[network]
source = "from-answer"
cidr = "192.168.68.200/20"  # Your Static IP/CIDR from Phase 3
gateway = "192.168.68.1"     # Your Gateway from Phase 3
dns = "8.8.8.8"

[disk-setup]
filesystem = "ext4"
disk_list = ["sda"]  # Proxmox will use entire first disk (your 2TB NVMe)
EOF
```

**Configuration Notes:**

- **mailto:** Real email for Proxmox notifications
- **cidr/gateway:** Values from Phase 3 network reconnaissance
- **fqdn:** `.local` suffix (management interface, stays permanent)
- **root_password:** Placeholder only - SSH keys used for actual access
- **root_ssh_keys:** Commented out in template, added in Step 3a

> **⚠️ FQDN Strategy (Proxmox Host vs Services):**
>
> **Proxmox Host FQDN:**
> - Uses `proxmox.brahmanda.local` **permanently** - this is a management interface
> - Accessed locally: `https://192.168.68.200:8006` (your home LAN)
> - Accessed remotely: `https://<nebula-ip>:8006` (via Nebula mesh, configured in Phase 7)
> - **No public DNS needed** - it's infrastructure, not a public service
>
> **VMs and Services (Phase 7+):**
> - VMs created inside Proxmox will have proper hostnames
> - K3s ingress will route public domains (e.g., `myapp.abhishek-kashyap.com`)
> - DNS records point to Lighthouse → Nebula mesh → K3s → Application
> - This is where your real domain gets configured, not at the Proxmox host level

#### **Step 3a: Generate Credentials & Create Local Config**

**Philosophy:** Defense-in-depth requires both SSH keys (primary) and a secure password (Web UI, console, installer requirement).

**1. Generate Secure Root Password:**

```bash
# Generate a cryptographically secure password (32 characters)
openssl rand -base64 24
```

Copy the output (e.g., `xK9mP2vQ8wL5nR7tY3hJ6bN4cV1a`)

**2. Generate SSH Key Pair:**

```bash
# Generate Ed25519 key (recommended - short and secure)
ssh-keygen -t ed25519 -C "proxmox-brahmanda-root" -f ~/.ssh/proxmox-brahmanda

# Display public key (copy this entire line)
cat ~/.ssh/proxmox-brahmanda.pub
```

**3. Store Credentials in 1Password:**

**3a. Store Root Password:**

- Open 1Password → Project-Brahmanda vault
- New Item → **Password** type
- Title: `Proxmox Brahmanda Root Password`
- Password field: Paste the generated password
- Add note: "Root password for Proxmox Web UI (https://192.168.68.200:8006) and console access"

**3b. Store SSH Private Key:**

- Open 1Password → Project-Brahmanda vault
- New Item → **SSH Key** type
- Title: `Proxmox Brahmanda Root SSH Key`
- Paste contents of `~/.ssh/proxmox-brahmanda` (private key)
- Add note: "Root SSH access to proxmox.brahmanda.local"

**4. Create Local Configuration:**

```bash
# Copy template to local file (gitignored)
cp samsara/proxmox/answer.toml samsara/proxmox/answer.local.toml

# Edit local config
code samsara/proxmox/answer.local.toml
```

**5. Update answer.local.toml with Real Credentials:**

Replace the placeholder password and uncomment SSH keys:

```toml
root_password = "xK9mP2vQ8wL5nR7tY3hJ6bN4cV1a"  # Your generated password

# SSH Public Keys (RECOMMENDED - provides passwordless authentication)
root_ssh_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGbPh... proxmox-brahmanda-root"
]
```

**✅ Verification:**

```bash
# Verify credentials stored in 1Password
op read "op://Project-Brahmanda/Proxmox Brahmanda Root Password/password"
op read "op://Project-Brahmanda/Proxmox Brahmanda Root SSH Key/private key"
```

**💡 TIP:** 1Password SSH agent can automatically provide the key when you SSH - no need to specify `-i` flag. Configure 1Password SSH agent if not already.

#### **Step 3b: Commit Template to Git (Weapon of Detachment)**

Commit only the template (no secrets):

```bash
# Commit template with placeholders
git add samsara/proxmox/answer.toml
git commit -m "feat(proxmox): add auto-install template with SSH key support"
git push
```

**Why this matters:**

- Template is versioned and reproducible
- Secrets stay in `answer.local.toml` (gitignored)
- Hardware failure? Generate new SSH key, update `.local`, boot from USB
- Aligns with "Infrastructure as Code" and "Weapon of Detachment"

**🔒 Security Check:**

```bash
# Verify template has no secrets
grep "CHANGE_THIS" samsara/proxmox/answer.toml  # Should find placeholder
grep "ssh-ed25519" samsara/proxmox/answer.toml   # Should be commented out

# Verify local config is gitignored
git status | grep answer.local.toml  # Should return nothing
```

#### **Step 4: Prepare Bootable USB with Auto-Install**

**Requirements:**

- USB drive (8GB minimum, will be erased)
- Proxmox VE ISO (from Step 1)
- `answer.local.toml` (your actual config with SSH key from Step 3a)

**Option A: Proxmox Auto-Install Assistant (Recommended)**

1. Download [Proxmox Auto-Install Assistant](https://www.proxmox.com/en/downloads/proxmox-virtual-environment/auto-install-assistant)
2. Run the assistant:
   - Select Proxmox ISO (Step 1)
   - Upload **`answer.local.toml`** (your actual config with SSH key)
   - Select USB drive
   - Click "Create Installation Medium"

**Option B: Manual Method (Linux/WSL)**

```bash
# Insert USB and identify device
lsblk  # Find your USB (e.g., /dev/sdb)

# Write ISO to USB (replace /dev/sdX with your device)
sudo dd if=~/Downloads/proxmox-ve_8.x-x.iso of=/dev/sdX bs=1M status=progress
sync

# Mount USB and add your LOCAL config
sudo mkdir -p /mnt/proxmox-usb
sudo mount /dev/sdX1 /mnt/proxmox-usb

# Copy LOCAL config as answer.toml (contains your SSH key)
sudo cp samsara/proxmox/answer.local.toml /mnt/proxmox-usb/answer.toml

# Unmount
sudo umount /mnt/proxmox-usb
```

**✅ Verification:**

```bash
# Verify answer.toml is on USB (with your SSH key)
sudo mount /dev/sdX1 /mnt/proxmox-usb
grep "ssh-ed25519" /mnt/proxmox-usb/answer.toml  # Should show your public key
sudo umount /mnt/proxmox-usb
```

#### **Step 5: Boot NUC and Install**

1. **Insert USB:** Plug the bootable USB into the NUC
2. **Power On:** Start the NUC
3. **Boot Menu:**
   - Press **F10** (or **ESC**/**DEL** depending on NUC model) during boot to enter Boot Menu
   - Select the USB drive
4. **Auto-Install:**
   - Proxmox installer detects `answer.toml`
   - Installation proceeds **automatically** without prompts
   - NUC will format the NVMe, install Proxmox, configure network, and reboot
5. **First Boot:**
   - Remove USB drive
   - NUC boots into Proxmox with IP `192.168.68.200` (or your configured IP)

**✅ Verification:** Open browser and visit `https://192.168.68.200:8006`. You should see the Proxmox login page.

#### **Step 6: Post-Installation Verification**

**SSH Access (Key-Based - No Password):**

```bash
# SSH using your private key
ssh -i ~/.ssh/proxmox-brahmanda root@192.168.68.200

# Or if using 1Password SSH agent (automatic)
ssh root@192.168.68.200

# Verify installation
pveversion          # Check Proxmox version
zpool status        # (If using ZFS) Check pool health
ip addr show        # Verify network config
hostname -f         # Should show proxmox.brahmanda.local
```

**Web UI Access:**

```
URL: https://192.168.68.200:8006
Username: root
Password: (retrieve from 1Password: "Proxmox Brahmanda Root Password")
```

**Or use 1Password CLI:**

```bash
# Copy password to clipboard
op read "op://Project-Brahmanda/Proxmox Brahmanda Root Password/password" | pbcopy  # macOS
op read "op://Project-Brahmanda/Proxmox Brahmanda Root Password/password" | clip     # Windows
```

**✅ Verification Checklist:**

- [ ] SSH key authentication works (no password prompt)
- [ ] Web UI accessible (accepts password from 1Password)
- [ ] Correct hostname (`proxmox.brahmanda.local`)
- [ ] Network connectivity (`ping 1.1.1.1`)
- [ ] Storage healthy (check Datacenter → Storage)

**Post-Install Tasks:**

```bash
# Add Proxmox host to your local /etc/hosts
echo "192.168.68.200  proxmox.brahmanda.local proxmox" | sudo tee -a /etc/hosts

# Optional: Test 1Password SSH agent integration
ssh-add -L  # Should list your key if 1Password agent is running
```

**🔒 Security Notes:**

- **SSH:** Primary access method using key-based authentication (no password prompt)
- **Web UI:** Requires password from 1Password (used for initial setup and administration)
- **Console:** Emergency access with password (physical access or out-of-band management)
- **Defense-in-Depth:** Both password and SSH key stored in 1Password for disaster recovery

---

### **Future Redeployment**

To recreate Proxmox installation (hardware replacement, testing, etc.):

1. Retrieve `answer.toml` from Git (`samsara/proxmox/answer.toml`)
2. Update network values if needed (new subnet, gateway)
3. Create bootable USB with updated `answer.toml`
4. Boot and let auto-install run
5. Result: Identical Proxmox installation in ~10 minutes

**This is the essence of "Asanga Shastra" - detachment through automation.**

> **Note:** This uses your existing network configuration discovered in Phase 3. After Proxmox is running, we'll reconfigure with VLANs (see `002-Visarga.md` for VLAN 20 Management and VLAN 30 DMZ setup).

### **What's Next After Proxmox Installation**

Once Proxmox VE is running, you have the **foundation** but not yet the **universe**:

**You have now:**

- ✅ Proxmox VE OS installed and accessible at `https://192.168.68.200:8006`
- ✅ Bare metal hypervisor ready to host virtual machines
- ✅ Infrastructure as Code for OS layer (answer.toml in Git)

**What's missing (automated in Phase 7):**

- ❌ Virtual machines (VMs) for K3s nodes
- ❌ Nebula mesh network configuration
- ❌ K3s Kubernetes cluster
- ❌ Longhorn storage, ArgoCD, observability stack

**Next Steps:**

1. **Phase 7 (Samsara):** Write Terraform configs in `samsara/terraform/vyom/` to create VMs
2. **Phase 7 (Samsara):** Write Ansible playbooks in `samsara/ansible/playbooks/` to configure VMs
3. **Phase 8 (Srishti):** Deploy K3s and applications via GitOps

This phased approach ensures each layer is testable and reproducible independently.

## **Phase 7: Samsara (The Cycle of Life)**

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
       AWS_ACCESS_KEY_ID: op://Project-Brahmanda/AWS-samsara-iac/AWS_ACCESS_KEY_ID
       AWS_SECRET_ACCESS_KEY: op://Project-Brahmanda/AWS-samsara-iac/AWS_SECRET_ACCESS_KEY
       CLOUDFLARE_API_TOKEN: op://Project-Brahmanda/Cloudflare-Sanchay-Token/CLOUDFLARE_API_TOKEN
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
      AWS_ACCESS_KEY_ID=op://Project-Brahmanda/AWS-samsara-iac/AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY=op://Project-Brahmanda/AWS-samsara-iac/AWS_SECRET_ACCESS_KEY
      CLOUDFLARE_API_TOKEN=op://Project-Brahmanda/Cloudflare-Sanchay-Token/CLOUDFLARE_API_TOKEN
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

## **Phase 8: Srishti (The Manifestation)**

_Goal: The Big Bang. Bringing the universe into existence._

We use the **Makefile** to invoke the creation.

1. **Invoke Creation:**
   ```bash
   make srishti
   ```
   _Action:_ This single command provisions Kshitiz (Edge) and Vyom (Compute), and bootstraps the Kubernetes cluster.

**Brahmanda is now Manifested.**
