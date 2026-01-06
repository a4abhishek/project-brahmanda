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

### **Hardware Requirements (Beyond NUC Components)**

- **USB Drive:** 8GB minimum (will be used for bootable Proxmox installation media)
- **Wired USB Keyboard:** Required for BIOS configuration during OS installation
  - Bluetooth keyboards do NOT work during BIOS/boot (pre-OS environment)
  - Can borrow temporarily if you only have Bluetooth keyboards

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
| **Power Cord** | IEC C13 to Wall Plug (for NUC Power Brick)   | [Amazon](https://www.amazon.in/dp/B0FHHZCB6B?smid=AJ6SIZC8YQDZX&ref_=chk_typ_imgToDp)                                                                                                          | ₹294          |
| **Memory**  | 48GB **DDR5 SO-DIMM** 5600Mhz (CT48G56C46S5)    | [NationalPC](https://nationalpc.in/laptop-memory/crucial-48gb-ddr5-5600mhz-so-dimm-ct48g56c46s5)                                                                                                | ₹41,300       |
| **Storage** | 2TB **NVMe M.2 Gen4** (SN850X \- 7300MB/s Read) | [Amazon](https://www.amazon.in/dp/B0B7CMZ3QH)                                                                                                                                                   | ₹25,600       |
| **Cable**   | Cat6 Snagless (Pure Bare Copper)                | [Amazon](https://www.amazon.in/dp/B0875SPZC8)                                                                                                                                                   | ₹1439         |
| **Switch**  | Smart Plug (16A - Remote Kill Switch)           | [Amazon](https://www.amazon.in/Wipro-Monitoring-Appliances-Microwave-Conditioners/dp/B08HN9Q2SZ/ref=sr_1_2_sspa?s=home-improvement&sr=1-2-spons&aref=BpzHKHMwVr&sp_csd=d2lkZ2V0TmFtZT1zcF9hdGY) | ₹1,000        |
| **Total**   | **Current Manifested Investment**               |                                                                                                                                                                                                 | **₹1,11,367** |

> **HARDWARE NOTE:** The NUC requires SO-DIMM (Laptop form factor) and NOT standard Desktop DIMMs. To achieve the 96GB goal, we use single 48GB modules at 5600Mhz. The SSD must be PCIe Gen 4 to leverage the full 7000MB/s+ throughput required for K8s etcd stability.

> **⚠️ QUALIFIED VENDOR LIST (QVL) - IMPORTANT:**
> ASUS provides a [QVL for NUC 14 Kits](https://dlcdnets.asus.com/pub/ASUS/NUC/QVL/ASUS_NUC_Kits_Revel_NUC14RVx_QVL_v1.00.pdf) listing tested and certified memory/storage components. However:
>
> - **QVL is NOT exhaustive** - Components not listed may still work perfectly
> - **This project uses non-QVL hardware** - All components (RAM: CT48G56C46S5, SSD: WD SN850X) are NOT on the official QVL
> - **Real-world experience:** Non-QVL components often work without issues if specifications match (DDR5 SO-DIMM, PCIe Gen4 M.2)
> - **Risk assessment:** QVL provides guaranteed compatibility, but limits options and may increase cost
> - **What to watch for:** Boot failures, memory errors, or SSD not detected usually indicate genuine incompatibility (not just "not on QVL")
>̥
> **Recommendation:** If you have budget flexibility, use QVL-listed components for peace of mind. If sourcing from QVL is difficult or expensive (as in this deployment), prioritize matching specifications (form factor, interface, speed) and be prepared for potential compatibility issues (though uncommon with reputable brands).

> **⚠️ POWER CORD:** The ASUS NUC 14 Pro Plus barrel charger typically does **NOT** include a standard AC power cord (IEC C13 to wall plug). You may need to purchase one separately or reuse one from an old PC power supply. Verify your specific kit includes the power cord before assembly day.

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
- Flathead screwdriver Number 4 (for chassis lock mechanism)
- Soft cloth or anti-static mat (optional but recommended)

> **💡 NOTE:** USB drive and wired keyboard (mentioned in Phase 0) are NOT needed for hardware assembly. They will be required later in Phase 6 (OS Installation).

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

> **💡 TIP:** Some NUC models have a sliding latch mechanism instead of screws. Consult the quick start guide if you don't see screws. If your NUC has a chassis lock (security slot with flathead screw), use a Flathead screwdriver Number 4 to unlock it before attempting to remove the bottom panel.

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
   - **Multiple M.2 slots:** Your ASUS NUC 14 Pro Plus may have 3 M.2 slots
   - **Primary M.2 slot (M Key, PCIe Gen4):** Use this for your 2TB boot drive (closest to CPU, fastest)
   - **Secondary M.2 slots (M/B Key):** Reserve for future storage expansion → would appear as `nvme1n1`, `nvme2n1` in Linux
2. **Remove the M.2 standoff screw** if pre-installed
3. **Insert NVMe SSD:**
   - Hold SSD by edges
   - Align notch on SSD with key in M.2 slot
   - Insert at 30-degree angle into **primary slot**
   - Push down gently until SSD is parallel to motherboard
4. **Secure with standoff screw** - do NOT overtighten (finger-tight is sufficient)

> **💡 TIP:** Always install your boot drive in the **primary M.2 slot** (usually closest to CPU). This slot typically supports the fastest PCIe Gen 4 speeds and appears as `nvme0n1` in Linux. Secondary slots can be populated later for additional VM storage, Longhorn storage pools, or backup cache.

**✅ Verification:** SSD should be flat against the PCB, secured by the standoff screw, with no visible gap.

#### **Step 5: Close the Chassis**

1. **Inspect for loose components** or forgotten screws
2. **Replace the bottom panel** - align carefully
3. **Reinstall screws** - tighten in diagonal pattern (prevents warping)
4. **Lock chassis** (if equipped): Use Flathead screwdriver Number 4 to engage the chassis lock mechanism (typically a security slot near the panel edge)
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
   - Press **F2** or **DEL** during boot to access BIOS (if needed for verification)

> **💡 TIP:** If you want to access BIOS now for verification, you'll need a **wired USB keyboard** (see Phase 0 requirements). Bluetooth keyboards don't work during boot. However, **BIOS configuration is not required at this stage** - you can proceed to Phase 3 and configure BIOS later before OS installation (Phase 6).

**If accessing BIOS for verification:**

1. **In BIOS, verify:**
   - RAM recognized: Should show 48GB (or ~47.xGB accounting for system reserved)
   - SSD recognized: Should show WD SN850X 2TB (or similar)
   - Boot order: UEFI mode enabled, secure boot settings
2. **Power off** the NUC

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

### **AWS Credentials**

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

### **Cloudflare Credentials**

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

### **Kshitiz - Nebula Mesh Infrastructure**

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

**Generate Lighthouse Certificate:**

Now generate the certificate for the Kshitiz lighthouse node:

```bash
cd ~/.nebula
nebula-cert sign -name "kshitiz-lighthouse" -ip "10.42.0.1/16" -ca-crt ca.crt -ca-key ca.key
```

This creates:

- `kshitiz-lighthouse.crt` (lighthouse certificate)
- `kshitiz-lighthouse.key` (lighthouse private key)

**✅ Verification:** Run `ls -la ~/.nebula/`. You should now see four files:

- `ca.crt` - CA certificate (public, shared with all nodes)
- `ca.key` - CA private key (secure, used to sign node certificates)
- `kshitiz-lighthouse.crt` - Lighthouse certificate
- `kshitiz-lighthouse.key` - Lighthouse private key

💡 **TIP:** The IP `10.42.0.1` is the Nebula mesh IP for the lighthouse (not the AWS public IP). The `/16` means this node can communicate with the entire `10.42.0.0/16` network.

**💡 Optional: Store Certificates in 1Password for Backup**

While these certificates will be encrypted in Ansible Vault (Phase 5), you can optionally store them in 1Password as a disaster recovery backup:

**1. Store Nebula CA (Root Certificate Authority):**

1. Open 1Password → Navigate to **"Project-Brahmanda"** vault.
2. Create a new **Secure Note** item:
   - **Title:** `Nebula-CA-Root-Certificate`
3. Add text fields for both certificate and key:
   - **Add Field → Text:** `ca.crt` → Paste the contents of `~/.nebula/ca.crt`
   - **Add Field → Text:** `ca.key` → Paste the contents of `~/.nebula/ca.key` (the CA private key)
4. Save the item.

⚠️ **CRITICAL:** This is the root certificate authority for your entire Nebula mesh. If lost, the entire mesh must be rebuilt from scratch.

**2. Store Lighthouse Certificates:**

1. In 1Password, create a new **Secure Note** item:
   - **Title:** `Nebula-Kshitiz-Lighthouse-Certificate`
2. Add text fields for certificate, key, and metadata:
   - **Add Field → Text:** `kshitiz-lighthouse.crt` → Paste the contents of `~/.nebula/kshitiz-lighthouse.crt`
   - **Add Field → Text:** `kshitiz-lighthouse.key` → Paste the contents of `~/.nebula/kshitiz-lighthouse.key` (the lighthouse private key)
   - **Add Field → Text:** `nebula_ip` → Enter `10.42.0.1`
3. Save the item.

💡 **TIP:** Copy file contents to clipboard:

```bash
# macOS
cat ~/.nebula/kshitiz-lighthouse.key | pbcopy

# Linux/WSL
cat ~/.nebula/kshitiz-lighthouse.key | clip.exe
```

**✅ Verification:** Test that certificates are stored correctly:

```bash
# Verify CA certificate
op read "op://Project-Brahmanda/Nebula-CA-Root-Certificate/ca.crt"

# Verify CA private key
op read "op://Project-Brahmanda/Nebula-CA-Root-Certificate/ca.key"

# Verify Lighthouse certificate
op read "op://Project-Brahmanda/Nebula-Kshitiz-Lighthouse-Certificate/kshitiz-lighthouse.crt"

# Verify Lighthouse private key
op read "op://Project-Brahmanda/Nebula-Kshitiz-Lighthouse-Certificate/kshitiz-lighthouse.key"
```

The 1Password backup provides an additional recovery layer independent of Ansible Vault.

### **Vyom - Cluster Infrastructure**

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

#### **Step 1: Understand the Configuration Template (answer.toml)**

The `answer.toml` file is the Infrastructure as Code definition for Proxmox installation. It's already in the repository at `samsara/proxmox/answer.toml`.

> **💡 NOTE:** The Proxmox VE ISO (~2GB) is **downloaded automatically** by the `make pratistha` script (Step 4). You don't need to manually download it. The template is committed to Git, while your actual configuration (`answer.local.toml`) is generated automatically and gitignored.

#### **Step 2: Update Network Configuration in Template**

The template configuration file exists at `samsara/proxmox/answer.toml`. Update it with your network values from Phase 3:

```toml
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
disk_list = ["nvme0n1"]  # NVMe drives use nvme0n1, nvme1n1, etc. (NOT sda)
```

> **⚠️ CRITICAL - Disk Naming:** NVMe SSDs use the naming convention `nvme0n1`, `nvme1n1`, etc., **NOT** `sda`, `sdb`. If you have multiple M.2 slots on your NUC:
>
> - Primary slot (closest to CPU): Usually `nvme0n1`
> - Secondary slot: Usually `nvme1n1`
> - To verify: Boot the NUC with Proxmox USB, press `Ctrl+Alt+F2` during installation to access console, run `lsblk` to see all disks
> - Use the disk where you installed your 2TB SSD (should match the size)

**Update These Values:**

1. **mailto:** Your email for Proxmox notifications
2. **cidr:** Your Static IP/CIDR from Phase 3 (e.g., `192.168.68.200/20`)
3. **gateway:** Your Gateway IP from Phase 3 (e.g., `192.168.68.1`)
4. **disk_list:** Use `nvme0n1` for NVMe SSDs (default), or verify with `lsblk` if unsure

**Leave These As-Is (Auto-populated by make pratistha):**

- **fqdn:** `proxmox.brahmanda.local` (management interface)
- **root_password:** Placeholder - injected from 1Password during USB creation
- **root_ssh_keys:** Placeholder - injected from `~/.ssh/proxmox-brahmanda.pub` or auto-generated

> **⚠️ FQDN Strategy (Proxmox Host vs Services):**
>
> **Proxmox Host FQDN:**
>
> - Uses `proxmox.brahmanda.local` **permanently** - this is a management interface
> - Accessed locally: `https://192.168.68.200:8006` (your home LAN)
> - Accessed remotely: `https://<nebula-ip>:8006` (via Nebula mesh, configured in Phase 7)
> - **No public DNS needed** - it's infrastructure, not a public service
>
> **VMs and Services (Phase 7+):**
>
> - VMs created inside Proxmox will have proper hostnames
> - K3s ingress will route public domains (e.g., `myapp.abhishek-kashyap.com`)
> - DNS records point to Lighthouse → Nebula mesh → K3s → Application
> - This is where your real domain gets configured, not at the Proxmox host level

#### **Step 3: Generate and Store Credentials**

**Philosophy:** Defense-in-depth requires both SSH keys (primary) and a secure password (Web UI, console, emergency access). These credentials are stored in 1Password for reusability across reinstalls and disaster recovery.

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
- Add note: "Root password for Proxmox Web UI (<https://192.168.68.200:8006>) and console access"

**3b. Store SSH Private Key:**

- Open 1Password → Project-Brahmanda vault
- New Item → **SSH Key** type
- Title: `Proxmox Brahmanda Root SSH Key`
- Paste contents of `~/.ssh/proxmox-brahmanda` (private key)
- Add note: "Root SSH access to proxmox.brahmanda.local"

**✅ Verification:**

```bash
# Verify credentials stored in 1Password
op read "op://Project-Brahmanda/Proxmox Brahmanda Root Password/password"
op read "op://Project-Brahmanda/Proxmox Brahmanda Root SSH Key/private key"
```

**💡 TIP:** 1Password SSH agent can automatically provide the key when you SSH - no need to specify `-i` flag. Configure 1Password SSH agent if not already.

#### **Step 4: Prepare Bootable USB with Auto-Install**

**This is where automation takes over.** The `make pratistha` script handles everything:

- Downloads Proxmox ISO (with caching)
- Fetches credentials from 1Password
- Generates `answer.local.toml` with real credentials
- Creates bootable USB with auto-install configuration

**Requirements:**

- USB drive (8GB minimum, will be erased) - from Phase 0 hardware requirements
- 1Password CLI authenticated (`op` command working)
- Steps 2 and 3 completed (template updated, credentials stored)

> **⚠️ DATA LOSS WARNING:** The USB drive will be completely erased. Backup any important data before proceeding.

<details>
<summary>🔌 WSL2 USB Attachment (Windows Users Only)</summary>

WSL2 does not automatically mount USB drives. If you're running this from WSL on Windows, you must attach the USB using `usbipd` first.

**One-time setup (PowerShell as Administrator):**

```powershell
# Install usbipd-win
winget install usbipd

# IMPORTANT: Restart PowerShell after installation
# The 'usbipd' command won't be available until you close and reopen PowerShell
```

**After restarting PowerShell, attach USB to WSL:**

```powershell
# 1. List USB devices (PowerShell as Administrator)
usbipd list

# Output example:
# BUSID  VID:PID    DEVICE                                  STATE
# 2-13   0781:5595  USB Mass Storage Device                 Shared

# 2. Find your USB drive (look for "USB Mass Storage Device")
# Note the BUSID (e.g., 2-13 in the example above)

# 3. If STATE shows "Shared", skip to step 4
# If STATE shows "Not shared", bind the device first (one-time):
usbipd bind --busid 2-13

# 4. Attach to WSL
usbipd attach --wsl --busid 2-13

# 5. Load USB storage driver (WSL2 doesn't load it automatically)
wsl sudo modprobe usb-storage && sleep 2
```

**💡 TIP:** If you see a warning about USB filter 'USBPcap', you can ignore it or use `usbipd bind --force --busid 2-13` if binding fails.

**Verify in WSL:**

```bash
# In WSL, check if USB is now visible
lsblk

# You should now see a new device (e.g., /dev/sde)
# NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
# sde      8:64   1 232.9G  0 disk
# `-sde1   8:65   1 232.9G  0 part    <-- Your USB drive partition

# Use this device path with make pratistha
make pratistha USB_DEVICE=/dev/sde ...
```

**How to distinguish your USB from other disks:**

1. **RM column = 1:** Removable media flag (USB drives show `1`, WSL virtual disks show `0`)
2. **Device order:** Your USB will be `/dev/sde` or later (WSL always uses `sda`-`sdd` for Windows system volumes)
3. **Size matches:** The size should match your USB capacity (e.g., 14.9G, 29.8G, 58.6G, 232.9G)
4. **Timing:** Only appears after `modprobe usb-storage` and `usbipd attach`
5. **Cross-check with lsusb:** Correlate the vendor/model from `lsusb` (e.g., "SanDisk Corp.") with the device

**Example comparison:**

```bash
lsblk
# sda-sdd: RM=0 (not removable), WSL/Windows virtual disks
# sde:     RM=1 (removable), your physical USB drive ✓
```

**After USB creation, detach (PowerShell):**

```powershell
# Detach from WSL so Windows can access it
usbipd detach --busid 2-1
```

**💡 TIP:** The USB device path in WSL (e.g., `/dev/sde`) is different from the Windows drive letter (e.g., `D:`). Always use `lsblk` in WSL to identify the correct device after attachment.

**⚠️ CRITICAL:** The devices you see in WSL by default (`sda`, `sdb`, `sdc`, `sdd`) are virtual/Windows system volumes. Your physical USB will only appear after using `usbipd attach`.

</details>

**Automated Method (Recommended - Idempotent & Production-Grade)**

```bash
make pratistha ISO_VERSION=9.1-1 \
  ROOT_PASSWORD="$(op read 'op://Project-Brahmanda/Proxmox Brahmanda Root Password/password')" \
  SSH_KEY_PATH=~/.ssh/proxmox-brahmanda.pub \
  USB_DEVICE=/dev/sdX
```

This automates:

- ISO download with progress
- `answer.local.toml` generation
- Bootable USB creation
- SSH key validation (generates if missing)
- USB bootable detection (skips if already configured)
- USB remove/reinsert prompt for proper recognition

**Command used for this deployment:**

```bash
# Complete command with all options (actual command used for this deployment)
make pratistha ISO_VERSION=9.1-1 \
  ROOT_PASSWORD="$(op read 'op://Project-Brahmanda/Proxmox Brahmanda Root Password/password')" \
  SSH_KEY_PATH=~/.ssh/proxmox-brahmanda.pub \
  USB_DEVICE=/dev/sde \
  SKIP_DOWNLOAD=true \
  FORCE=true
```

<details>
<summary>💡 Practical Usage Examples:</summary>

```bash
# Example 1: First-time setup (auto-generate SSH keys if missing)
# Replace /dev/sdX with YOUR USB device from lsblk
lsblk  # Identify USB device
make pratistha \
  ROOT_PASSWORD="$(op read 'op://Project-Brahmanda/Proxmox Brahmanda Root Password/password')" \
  USB_DEVICE=/dev/sdX

# Example 2: Re-create USB with existing ISO (skip download)
make pratistha \
  ROOT_PASSWORD="$(op read 'op://Project-Brahmanda/Proxmox Brahmanda Root Password/password')" \
  SSH_KEY_PATH=~/.ssh/proxmox-brahmanda.pub \
  USB_DEVICE=/dev/sdX \
  SKIP_DOWNLOAD=true

# Example 3: Force regeneration even if USB is already bootable
make pratistha \
  ROOT_PASSWORD="$(op read 'op://Project-Brahmanda/Proxmox Brahmanda Root Password/password')" \
  USB_DEVICE=/dev/sdX \
  FORCE=true

# Example 4: Use different Proxmox version
make pratistha \
  ISO_VERSION=8.2-1 \
  ROOT_PASSWORD="$(op read 'op://Project-Brahmanda/Proxmox Brahmanda Root Password/password')" \
  USB_DEVICE=/dev/sdX

# Example 5: Password already in environment
export PROXMOX_ROOT_PASSWORD="$(op read 'op://Project-Brahmanda/Proxmox Brahmanda Root Password/password')"
make pratistha ROOT_PASSWORD="$PROXMOX_ROOT_PASSWORD" USB_DEVICE=/dev/sdX
```

</details>
<br>

**🔄 Smart USB Detection:**

The script automatically detects if your USB is already a bootable Proxmox auto-install medium (by checking for 4 partitions). If detected, it will skip recreation and show:

```
✅ USB device appears to be a Proxmox auto-install medium
   All steps complete - USB is ready for installation!
```

To force regeneration (e.g., to update with new SSH keys or password), use `FORCE=true`.

**⚠️ WARNING:** `make pratistha` will **ERASE ALL DATA** on the target USB device. Double-check the device path with `lsblk` before running.

<details>
<summary>Alternative Methods (For Reference Only - Use make pratistha Instead)</summary>

> **⚠️ NOTE:** These methods require manual `answer.local.toml` creation and are error-prone. The automated `make pratistha` approach (above) is strongly recommended as it handles credential injection, SSH key validation, and idempotent USB creation automatically.

**Alternate A: Proxmox Auto-Install Assistant (GUI)**

1. Download from [Proxmox Wiki - Automated Installation](https://pve.proxmox.com/wiki/Automated_Installation)
2. Manually create `answer.local.toml` with your credentials (see template in Step 2)
3. Run the assistant:
   - Select Proxmox ISO
   - Upload `answer.local.toml`
   - Select USB drive
   - Click "Create Installation Medium"

**Alternate B: Manual Method (Linux/WSL)**

```bash
# 1. Manually create answer.local.toml from template
cp samsara/proxmox/answer.toml samsara/proxmox/answer.local.toml
# Edit answer.local.toml: replace password, add SSH keys

# 2. Insert USB and identify device
lsblk  # Find your USB (e.g., /dev/sdX)

# 3. Write ISO to USB (replace /dev/sdX with your device)
sudo dd if=~/Downloads/proxmox-ve_9.1-1.iso of=/dev/sdX bs=1M status=progress
sync

# 4. Mount USB and add your config
sudo mkdir -p /mnt/proxmox-usb
sudo mount /dev/sdX1 /mnt/proxmox-usb

# 5. Copy config as answer.toml
sudo cp samsara/proxmox/answer.local.toml /mnt/proxmox-usb/answer.toml

# 6. Unmount
sudo umount /mnt/proxmox-usb
```

**Verification:**

```bash
# Verify answer.toml is on USB (with your SSH key)
sudo mount /dev/sdX1 /mnt/proxmox-usb
grep "ssh-ed25519" /mnt/proxmox-usb/answer.toml  # Should show your public key
sudo umount /mnt/proxmox-usb
```

</details>

**Important:** After USB creation completes, the script will prompt you to remove and reinsert the USB drive. This ensures your system properly recognizes the new partition table:

```
⚠️  IMPORTANT: Please remove and reinsert the USB drive now
   This ensures the system recognizes the new partition table

Have you removed and reinserted the USB? [y/N]:
```

After reinserting the USB:

1. **Verify USB:** Run `lsblk /dev/sdX` - you should see 4 partitions (sde1, sde2, sde3, sde4)

#### **Step 5: BIOS Configuration (Flexible Timing)**

**When to Configure:** BIOS settings can be adjusted **before OR after** Proxmox installation. Modern ASUS NUCs typically have virtualization enabled by default, so you can proceed with installation and configure BIOS later.

> **💡 TIP:** You will need a **wired USB keyboard** (from Phase 0 hardware requirements) for BIOS access. Bluetooth keyboards do not work during boot (pre-OS stage).

**Recommended Settings (Configure when convenient):**

1. **Enter BIOS:**
   - Power on NUC
   - Press **F2** (or **DEL**) immediately during boot

2. **Configure Available Settings:**

   **Security:**
   - Look for: `Security` → `Secure Boot`
   - Set to: **Disabled**
   - **Rationale:** Prevents kernel signature issues

   **Cooling:**
   - Look for: `Advanced` → `Fan Mode`
   - Set to: **Performance**
   - **Avoid:** "Quiet" mode
   - **Rationale:** Prevents thermal throttling during Kubernetes workloads

   **Power Management** (if available):
   - Look for: `Power, Performance, Cooliing` → `Secondary Power` → `After Power Failure`
   - Set to: **Power On** or **Last State**
   - **Rationale:** Auto-recovery after power outages

   **Virtualization** (verify only - usually pre-enabled):
   - Look for: `Advanced` → `CPU Configuration` or `Processor`
   - Verify **Intel VT-x**: **Enabled**
   - Verify **Intel VT-d**: **Enabled**
   - **Note:** Modern ASUS NUCs have these enabled by default
   - **If you can't find these options:** They're likely already enabled or hidden when active

3. **Save and Exit:**
   - Press **F10** to save changes

**✅ Post-Install Verification (Run after Proxmox is installed):**

```bash
# Verify virtualization is working
ssh root@192.168.68.200

# Check if VT-x/VT-d are enabled
egrep -c '(vmx|svm)' /proc/cpuinfo
# Expected: Number > 0 (shows CPU virtualization is active)

# Check IOMMU (VT-d) status
dmesg | grep -i iommu
# Expected: "DMAR: IOMMU enabled" or similar

# Exit
exit
```

**If virtualization verification fails:**

- Enter BIOS and search for "Virtualization Technology", "VT-x", "VT-d", "Intel Virtualization"
- These settings might be in different menus depending on BIOS version
- Consult ASUS NUC manual if you can't locate them

**🎯 Summary:** Secure Boot (disabled) and Fan Mode (Performance) are the most important settings you've already configured. Virtualization is likely already enabled. Power management is optional.

#### **Step 6: Boot from USB and Auto-Install**

> **💡 REMINDER:** Ensure your wired USB keyboard is connected before powering on. You'll need it to access the boot menu.

1. **Boot Menu:**
   - Insert the bootable USB drive (created in Step 4)
   - Power on the NUC
   - Press **F10** (or **ESC** depending on model) during boot to enter Boot Menu
   - Select the USB drive (should appear as "UEFI: USB Device" or similar)

2. **Auto-Install Process:**
   - Proxmox installer detects `answer.toml` automatically
   - Installation proceeds **without prompts**:
     - Formats NVMe SSD
     - Installs Proxmox VE
     - Configures network (192.168.68.200)
     - Installs SSH keys
     - Reboots automatically

3. **First Boot:**
   - Remove USB drive after installation completes
   - NUC boots into Proxmox with IP `192.168.68.200` (or your configured IP)

**✅ Verification:** Open browser and visit `https://192.168.68.200:8006`. You should see the Proxmox login page (accept the self-signed certificate warning).

**⏱️ Expected Duration:** 10-15 minutes from boot to login screen

#### **Step 7: Installation Verification & Samskara**

**What You'll See After Installation:**

After the auto-install completes and the NUC reboots, you'll see this at the console:

```
-----------------------------------------------------------------------------
Welcome to the Proxmox Virtual Environment. Please use your web browser to
 configure this server - connect to:
https://192.168.68.200:8006/
-----------------------------------------------------------------------------
proxmox login: _
```

**✅ This is normal!** You do NOT need to login at the console. This is the end of **Phase 6 (Pratistha - OS Installation)**.

**What This Means:**

- ✅ Proxmox VE is successfully installed and running
- ✅ You have a bare metal hypervisor ready to host virtual machines
- ✅ Infrastructure as Code for OS layer is complete (answer.toml in Git)

**What's Still Missing (Automated in Phase 7):**

- ⏳ Virtual machines (VMs) for K3s nodes
- ⏳ Nebula mesh network configuration
- ⏳ K3s Kubernetes cluster
- ⏳ Longhorn storage, ArgoCD, observability stack

**SSH Access (Key-Based - Recommended):**

Test SSH access from your workstation (not at the console):

```bash
# If using 1Password SSH agent (recommended - zero config)
ssh root@192.168.68.200

# Or manually specify the key
ssh -i ~/.ssh/proxmox-brahmanda root@192.168.68.200

# Verify installation
pveversion          # Check Proxmox version
zpool status        # (If using ZFS) Check pool health
ip addr show        # Verify network config
hostname -f         # Should show proxmox.brahmanda.local
```

**Web UI Access:**

Open browser to: `https://192.168.68.200:8006` (or your configured IP)

```
Username: root
Password: [Retrieve from 1Password: "Proxmox Brahmanda Root Password"]
```

**💡 TIP:** Use 1Password CLI to copy password directly:

```bash
op read "op://Project-Brahmanda/Proxmox Brahmanda Root Password/password" | pbcopy  # macOS
op read "op://Project-Brahmanda/Proxmox Brahmanda Root Password/password" | clip     # Windows/WSL
```

**📋 Subscription Notice (Normal - Not an Error)**

After logging in, you'll see this popup:

```
You do not have a valid subscription for this server.
Please visit www.proxmox.com to get a list of available options.
```

**This is completely normal!** You're using the free **Proxmox VE Community Edition** which is fully functional. This notice appears on every login but doesn't affect functionality.

**Options:**

- **Click "OK" each time** (recommended for production awareness)
- **Disable the popup** (optional - see below)

<details>
<summary>Optional: Disable Subscription Popup</summary>

If you prefer to disable the popup notification:

```bash
# SSH into Proxmox
ssh root@192.168.68.200

# Navigate to web toolkit directory
cd /usr/share/javascript/proxmox-widget-toolkit/

# Backup the original file
cp proxmoxlib.js proxmoxlib.js.bak

# Disable the subscription check popup
sed -i.bak '/No valid subscription/,/callback: function(btn)/s/Ext\.Msg\.show/void/' proxmoxlib.js

# Restart the web interface
systemctl restart pveproxy
```

**Note:** This modification is cosmetic only. It doesn't provide a subscription or bypass any limitations. The Community Edition remains fully functional.

After running these commands, refresh your browser - the subscription popup will no longer appear on login.

</details>

**✅ Verification Checklist:**

- [ ] SSH key authentication works (no password prompt)
- [ ] Web UI accessible (accepts password from 1Password)
- [ ] Correct hostname (`proxmox.brahmanda.local`)
- [ ] Network connectivity (`ping 1.1.1.1`)
- [ ] Storage healthy (check Datacenter → Storage)

**Post-Install Tasks:**

**1. Samskara (Purification/Refinement)**

The default Proxmox installation uses Enterprise repositories which require a paid subscription. **Samskara** refines the base installation into production-ready state.

**Automated Approach (Recommended):**

```bash
# Basic usage (disables subscription popup by default)
make samskara PROXMOX_HOST=192.168.68.200

# Keep subscription popup (for legal compliance if required)
make samskara PROXMOX_HOST=192.168.68.200 KEEP_POPUP=true

# Run script directly
scp scripts/samskara-proxmox.sh root@192.168.68.200:/tmp/
ssh root@192.168.68.200 "chmod +x /tmp/samskara-proxmox.sh && /tmp/samskara-proxmox.sh"
```

**What the script does:**

- ✅ Disables enterprise repositories (`pve-enterprise.list`, `ceph.list`)
- ✅ Enables community (no-subscription) repository
- ✅ Updates package lists (`apt-get update`)
- ✅ Upgrades all packages (`apt-get dist-upgrade`)
- ✅ Disables subscription popup (default, use `--keep-subscription-popup` to preserve)
- ✅ Idempotent: Safe to run multiple times (checks state, doesn't create duplicate backups)

**✅ Verification:** Run `ssh root@192.168.68.200 "apt-get update"` - you should see no errors about 401 Unauthorized.

<details>
<summary><strong>Manual Approach (Alternative)</strong></summary>̥

If you prefer manual configuration or need to troubleshoot:

```bash
# SSH into Proxmox
ssh root@192.168.68.200

# Disable enterprise repositories
mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.disabled
mv /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph.list.disabled

# Add community (no-subscription) repository
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Update package lists
apt-get update

# Upgrade packages (recommended)
apt-get dist-upgrade -y
```

**Why this is needed:** Without this, package updates will fail with "401 Unauthorized" errors because the enterprise repositories require authentication.
</details>

**2. Add Proxmox to Local Hosts File**

```bash
# On your workstation (not Proxmox host)
echo "192.168.68.200  proxmox.brahmanda.local proxmox" | sudo tee -a /etc/hosts
```

**3. Optional: Test 1Password SSH Agent**

```bash
ssh-add -L  # Should list your key if 1Password agent is running
```

**🔒 Security Notes:**

- **SSH:** Primary access method using key-based authentication (no password prompt)
- **Web UI:** Requires password from 1Password (used for initial setup and administration)
- **Console:** Emergency access with password (physical access or out-of-band management)
- **Defense-in-Depth:** Both password and SSH key stored in 1Password for disaster recovery

### **Troubleshooting Installation Issues**

**Error: "disk in 'disk-selection' not found"**

This means Proxmox cannot find the disk specified in `answer.toml`. Common causes:

1. **Wrong disk name:** NVMe drives use `nvme0n1`, `nvme1n1`, etc., NOT `sda`
   - **Fix:** Update `disk_list = ["nvme0n1"]` in `samsara/proxmox/answer.toml`
   - Recreate USB with `make pratistha` (it will regenerate `answer.local.toml`)

2. **Multiple M.2 slots - wrong slot specified:**
   - Your ASUS NUC may have multiple M.2 slots (M Key, B Key, or combo slots)
   - **To verify which disk to use:**
     1. Boot from Proxmox USB
     2. When installer starts, press **Ctrl+Alt+F2** to access console
     3. Login as `root` (no password)
     4. Run: `lsblk -o NAME,SIZE,TYPE,MOUNTPOINT`
     5. Identify your 2TB SSD (will show as `nvme0n1` or `nvme1n1` with ~2TB size)
     6. Press **Ctrl+Alt+F1** to return to installer
     7. Abort installation, update `answer.toml` with correct disk name
     8. Recreate USB and try again

3. **SSD not detected at all:**
   - Verify SSD is properly seated in M.2 slot (see Phase 2, Step 4)
   - Check BIOS shows the SSD (Phase 6, Step 5)
   - Ensure you're using the **primary M.2 slot** (closest to CPU, usually fastest)

**Multiple M.2 Slots Strategy:**

- **Primary slot (M Key):** Use this for your 2TB Proxmox boot drive (usually `nvme0n1`)
- **Secondary slots:** Can be used for additional storage in future expansion (VLAN storage, backup cache)
- **Tip:** Some NUC models have slots with different speeds (Gen4 vs Gen3) - check manual

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

1. **Phase 7 (Samsara):** Terraform provisions VMs inside Proxmox + Ansible configures them
2. **Phase 8 (Srishti):** GitOps deploys K3s cluster and applications

Each layer is independently testable and follows the **Weapon of Detachment** principle - destroy and recreate at will.

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
