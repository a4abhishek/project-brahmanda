# **SRE Homelab Setup Runbook (Project Brahmanda)**

न रूपमस्येह तथोपलभ्यते
नान्तो न चादिर्न च सम्प्रतिष्ठा | <br>
अश्वत्थमेनं सुविरूढमूल
मसङ्गशस्त्रेण दृढेन छित्त्वा ||

(Bhagavad Gita 15.3)

"The real form of this tree (of Brahmanda) is not perceived in this world... Having cut down this firmly rooted tree with the strong weapon of detachment..."

The SRE Vidhana: This document serves as the immutable Blueprint for **Project Brahmanda**. It is written with the understanding that the infrastructure itself is **Transient**. We use the **Weapon of Detachment** aka Infrastructure as Code to sever ties with individual nodes.

**This document ensures that we can replicate, destroy, and recreate the "Brahmanda" without hesitation.**

## **Phase 0: The Vault & Secrets (Day \-1)**

*Goal: Initialize the Hybrid Secret Management system before writing any code.*

1. **1Password Setup (The Master Key):**

   *Open 1Password (Desktop App).
   * Create a new **Password Item** named `Project-Brahmanda--Samsara-Automation-System--Ansible-Vault`.
   *Generate a random, high-entropy password (30+ characters, symbols enabled).
   * Save the item.
   * *Why?* This password will decrypt your entire infrastructure. It lives only in 1Password.

1. **Local Repository Setup:**

   *In your terminal, navigate to samsara/ansible/group\_vars/all/.
   * Create a dummy file: echo "test\_secret: hello\_world" \> vault.yml.
   ***Encrypt it:**
     \# This reads the password directly from 1Password via CLI
     ansible-vault encrypt vault.yml \--vault-password-file \<(op read "op://Private/Project-Brahmanda--Samsara-Automation-System--Ansible-Vault/password")
   * *Verification:* cat vault.yml should now show a binary blob starting with $ANSIBLE\_VAULT.

1. **GitHub Setup (For CI/CD):**

   * Go to your GitHub Repository \-\> **Settings** \-\> **Secrets and variables** \-\> **Actions**.
   * Click **New repository secret**.
   ***Name:** ANSIBLE\_VAULT\_PASSWORD
   * **Value:** Paste the 30+ char password you generated in Step 1\.
   * *Why?* This allows your GitHub Actions "Robot" to decrypt the vault and run playbooks without knowing your 1Password login.

## **Phase 1: The Cloud Gateway (Kshitiz)**

*Goal: Establish the "Lighthouse" to guide traffic home.*

1. **Provision Lightsail:**

   * Deploy a $5.00 OS-only instance (Ubuntu 24.04) in **Singapore** (for 1TB BW).
   * Attach a **Static IP** immediately via Terraform.
   * **Firewall Rules:** Allow UDP/4242 (Nebula) and TCP/22 (SSH \- restricted to your IP). Deny everything else.

1. **Install Nebula (The Lighthouse):**

   * Generate a Certificate Authority (CA) locally: nebula-cert ca \-name "Project Brahmanda".
   * **Secure the Key:** Move ca.key into your vault.yml (encrypted) using ansible-vault edit vault.yml. **Delete the plain text key.**
   *Sign a certificate for the lighthouse: nebula-cert sign \-name "lighthouse" \-ip "10.100.0.1/24".
   * Run nebula with am\_lighthouse: true.

## **Phase 2: The Hypervisor (Vyom Host)**

*Goal: Turn the NUC into a bare-metal data center.*

1. **BIOS Prep:**

   * Disable Secure Boot.
   * Set "Power Loss" setting to "Last State" (auto-boot after power cut).

1. **Install Proxmox VE:**

   ***Automated Method:** Insert the USB drive with the custom ISO (baked with answer.toml).
   * **Manual Method:**
     ***Filesystem:** Select **LVM-Thin** (EXT4).
     * **Network:** Set a static IP (e.g., 192.168.1.100).

1. **Networking Setup (The "DMZ"):**

   *Create a generic Linux Bridge (vmbr1) in Proxmox *without* a physical port attached.
   * *Result:* VMs on vmbr1 can talk to each other but CANNOT reach your home router or the internet unless you explicitly route them via a gateway VM.

## **Phase 3: The Kubernetes Cluster (Vyom Cluster)**

*Goal: A scalable container platform.*

1. **VM Provisioning (Terraform):**

   * Run terraform apply to create 3 VMs (Ubuntu Server) on Proxmox:
     * k8s-master (4GB RAM, 2 vCPU)
     * k8s-worker-1 (16GB RAM, 4 vCPU)
     * k8s-worker-2 (16GB RAM, 4 vCPU)

1. **Install K3s (Ansible):**

   *Run the playbook: ansible-playbook setup\_k8s.yml \--vault-password-file \<(op read "op://Private/Ansible Vault \- Samsara/password")
   * *Under the hood:*
     * Ansible installs Nebula on all nodes using the CA key decrypted from the vault.
     * Nodes connect to the Lighthouse (Kshitiz).
     * K3s is installed using the Nebula interface (10.100.x.x).

## **Phase 4: Public Access**

1. **Ingress:** Deploy **Ingress NGINX** or **Traefik** on K3s.

2. **Routing:** On the Lightsail box (Kshitiz), use iptables to forward ports 80/443 *through the Nebula tunnel* to your K3s Ingress IP.
