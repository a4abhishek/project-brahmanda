# **ADR-003: Hybrid Secret Management & Dynamic Discovery Strategy**

**Date:** 2026-01-11 (Amended from 2025-12-31)<br>
**Status:** Accepted

**Enhancements:**

- [manthana/RFC-003-Secret-Management.md](../manthana/RFC-003-Secret-Management.md)
- [manthana/RFC-006-Automated-Vault-Generation.md](../manthana/RFC-006-Automated-Vault-Generation.md)
- [manthana/RFC-007-Terraform-Secret-Management](../manthana/RFC-007-Terraform-Secret-Management.md)
- [manthana/RFC-008-Dynamic-Ansible-Inventory](../manthana/RFC-008-Dynamic-Ansible-Inventory.md)

## **Context**

Project Brahmanda faces two critical operational challenges regarding secrets and state:

1. **The Connectivity Paradox (Secrets):** We require 1Password as our Single Source of Truth (SSOT). However, relying solely on an online-only secret manager creates a deadlock: we cannot fetch keys to fix the network if the network itself is down (e.g., Lighthouse failure).
2. **The Data Island Problem (State):** Terraform knows the state of the universe (IP addresses, metadata), but Ansible, the responsible for configuring it, is blind to this state. Manual synchronization (copy-pasting IPs) is error-prone and violates the "Samsara" principle of automated lifecycles.

We need a strategy that unifies **Secret Management**, **Infrastructure Provisioning**, and **Configuration** into a single, automated, and resilient workflow.

## **Decision**

We will adopt a **Dual-Mode Hybrid Secret Management** model integrated with **State-Driven Dynamic Discovery**.

### **A. Provisioning Mode (Terraform \+ 1Password Provider)**

For infrastructure provisioning (AWS, Cloudflare, Proxmox), Terraform will use the **official 1Password Provider**. Secrets will be fetched declaratively during the plan and apply phases directly from the 1Password API. This eliminates the need for manual export of environment variables and prevents secret leakage in shell histories.

### **B. Configuration Mode (Ansible \+ Scoped Vaults)**

For node configuration (Nebula, K3s, Hardening), we will use **Ansible Vault** encrypted at rest in Git. These vaults are generated from templates that reference 1Password (the **Nidhi Framework**). This preserves the **"Asanga Shastra"** (Detachment) principle, allowing for offline disaster recovery.

### **C. Discovery Mode (Dynamic Inventory)**

To bridge the gap between Provisioning and Configuration, Ansible will use a **Dynamic Inventory Script**. This script reads the Terraform state files (stored in Cloudflare R2 or locally) to discover IPs and metadata, eliminating manual updates to static files.

### **D. Authentication Mode (The Temporary Scepter)**

To securely authenticate Ansible against the discovered hosts without storing private keys on disk, we will use the **Makefile** as an orchestrator to manage ephemeral key files.

## **Implementation**

The implementation follows the **Samsara Lifecycle**, moving from the authoritative source of truth to the final configured node in a secure, automated flow.

### **Layer 1: The Authoritative Source (1Password)**

All secrets - including API tokens, passwords, and the private keys for both SSH and Nebula - **MUST** originate and be managed within the **`Project-Brahmanda`** 1Password vault. This is the single source of truth (SSOT).

| Layer | Tool | Source | Use Case |
| :---- | :---- | :---- | :---- |
| **Authoritative** | 1Password | Project-Brahmanda Vault | SSOT for all keys, tokens, and passwords. |
| **Provisioning** | Terraform | onepassword Provider | Dynamic injection into AWS, Cloudflare, and Proxmox providers. |
| **Discovery** | Python Script | `terraform.tfstate` | Automated mapping of secrets to dynamic IPs. |
| **Configuration** | Ansible | Scoped `vault.yml` | Encrypted-in-Git secrets for mesh and cluster setup. |
| **CI/CD** | GitHub Actions | `OP_SERVICE_ACCOUNT_TOKEN` | The single bootstrap secret required to unlock the universe. |

#### Secrets Flow

```
       1Password (Project-Brahmanda Vault)
                 │
        ┌────────┴────────┐
        ▼                 ▼
   Terraform          Ansible Vault
 (Direct API)       (Template Generation)
        │                 │
        ▼                 ▼
  Provisioning       Configuration
(Cloud/VMs/IPs) ◄─── (Dynamic Discovery)
```

### **Layer 2: Provisioning (Terraform Integration)**

Terraform uses the `1Password/onepassword` provider to fetch credentials declaratively and in-memory at runtime. This prevents secrets from ever touching disk or shell history on the developer's machine.

Terraform configurations **MUST** use the `onepassword_item` data source for provider authentication. This ensures no secrets exist in `.tfvars` or shell history.

```hcl
# Example from: samsara/terraform/kshitiz/main.tf

# 1. Define the data source to fetch the 1Password item.
data "onepassword_item" "aws_credentials" {
  vault = "Project-Brahmanda"
  title = "AWS-samsara-iac"
}

# 2. Configure the provider using the fetched secret.
provider "aws" {
  access_key = data.onepassword_item.aws_credentials.username
  secret_key = data.onepassword_item.aws_credentials.password
}
```

### **Layer 3: Discovery (Dynamic Inventory)**

To solve the "Data Island" problem, Ansible uses an executable script as its inventory source.

- **Source File:** `samsara/ansible/inventory/dynamic_inventory.py`
- **Configuration (`ansible.cfg`):**

    ```ini
    [defaults]
    inventory = ./inventory/dynamic_inventory.py
    ```

- **Logic:** The Python script reads the `terraform.tfstate` file, finds the required resources, and prints a correctly formatted JSON inventory for Ansible to consume in-memory.

### **Layer 4: Authentication (The Ephemeral Key Pattern)**

To securely handle SSH authentication without hardcoding paths or creating long-lived key files on disk, the `Makefile` acts as a secure orchestrator.

1. **Materialize:** Before running Ansible, the `make` target reads the appropriate SSH private key from 1Password and writes it to a unique, temporary file (e.g., `/tmp/kshitiz_ssh_key_12345`).
2. **Secure:** It immediately runs `chmod 600` on the temporary file.
3. **Inject:** The `make` target calls `ansible-playbook`, passing the path to the temporary key file directly via the `--private-key` command-line flag.

    ```makefile
    # Example from Makefile 'kshitiz' target
    ansible-playbook playbooks/01-bootstrap-kshitiz.yml \
        --private-key="/tmp/kshitiz_ssh_key_12345" \
        ...
    ```

4. **Dissolve:** A `trap` in the `Makefile` guarantees the temporary key file is **deleted immediately** after the playbook execution completes, regardless of success or failure.

This pattern completely decouples Ansible's inventory from the authentication mechanism, as the key is provided imperatively by the orchestrator.

### **Layer 5: Configuration (The Nidhi Framework)**

For secrets that need to be placed *on the node* (e.g., Nebula certificates), we use the Nidhi (Treasure) framework. This provides offline resilience for Ansible.

1. **Template (`vault.tpl.yml`):** A template file defines the required secrets with `op://` references. This file is committed to Git and serves as documentation for the vault's structure.

    ```yaml
    # From: samsara/ansible/group_vars/kshitiz/vault.tpl.yml
    nebula_ca_crt: |
      op://Project-Brahmanda/Nebula-CA-Root-Certificate/ca.crt
    ```

2. **Generation (`make nidhi-tirodhana`):** The `make` target uses `op inject` to read the template, fetch secrets from 1Password, and generate a corresponding encrypted `vault.yml` file. This encrypted file is also committed to Git.
3. **Usage:** Ansible automatically decrypts and loads variables from `vault.yml` at runtime, using them in tasks (e.g., copying the `nebula_ca_crt` content to the remote server).

## **Workflow Visualization**

### **The "Srishti" Workflow (Local & CI/CD)**

```bash
# 1. Environment Setup (Inject 1Password Service Token)
export OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://Project-Brahmanda/Service-Account/token")

# 2. Invoke Creation
make srishti
```

**Under the Hood of `make srishti`:**

1. **Terraform Apply:**
    - Auth: Uses `onepassword` provider via `OP_SERVICE_ACCOUNT_TOKEN`.
    - Action: Provisions infrastructure.
    - Output: Writes state to R2 backend.
2. **Key Materialization (in `make kshitiz`):**
    - Action: `op read ... > /tmp/kshitiz_ssh_key_$$`.
    - Security: `chmod 600` on the temp file.
3. **Ansible Execution:**
    - Discovery: Calls `inventory_discovery.py` which reads the R2 state.
    - Auth: Receives path to temp key via `--private-key` flag from `make`.
    - Config: Decrypts Git-vaults for Nebula/K3s setup.
4. **Cleanup:**
    - Action: A `trap` in the `make` target ensures `rm /tmp/kshitiz_ssh_key_$$` is always executed.

## **Consequences**

### **Positive**

- ✅ **Zero Manual Sync:** IPs and metadata flow automatically from Terraform to Ansible.
- ✅ **Declarative Dependency:** Terraform explicitly declares its secret requirements.
- ✅ **Offline Resilience:** Ansible Vaults allow for node recovery even if 1Password is unreachable (using the Vault Password).
- ✅ **Security:** Private keys exist on disk only for the duration of the command (milliseconds to minutes).
- ✅ **Idempotency:** The entire chain can be re-run safely; discovery always reflects the current reality.

### **Negative**

- ⚠️ **Script Maintenance:** Requires maintaining the Python discovery script to handle Terraform schema changes.
- ⚠️ **Sync Requirement:** Developers must run `make nidhi-tirodhana` if secret templates (`vault.tpl.yml`) change.

## **Conclusion**

By combining the **1Password Terraform Provider** (Provisioning) with **Dynamic Inventory** (Discovery) and the **Nidhi Framework** (Configuration), we have closed the automation loop. The universe is now defined by its state, secured by its authoritative vault, and manifested through a fully automated pipeline where human error in credential or IP management is architecturally impossible.
