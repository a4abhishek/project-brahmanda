# **ADR-003: Hybrid Secret Management Strategy**

**Date:** 2026-01-08 (Amended from 2025-12-31)
**Status:** Accepted

## **Context**

Project Brahmanda requires the management of highly sensitive credentials (Nebula CA keys, SSH private keys, Cloud API tokens). Since the infrastructure spans multiple environments (MacBook, Windows/WSL, CI/CD pipelines) and manages the network layer itself, relying solely on an online-only secret manager creates a **"Connectivity Paradox"**: you cannot fetch the keys to fix the network if the network itself is down.

We need a strategy that provides:

1. **Single Source of Truth (SSOT):** 1Password as the authoritative hub.
2. **Declarative Provisioning:** Terraform must explicitly declare its secret dependencies.
3. **Offline Resilience:** Ansible must be able to configure nodes even during a "Lighthouse" outage.

For detailed rationale, see:

- [manthana/RFC-003-Secret-Management.md](../manthana/RFC-003-Secret-Management.md) - Hybrid model foundation
- [manthana/RFC-006-Automated-Vault-Generation.md](../manthana/RFC-006-Automated-Vault-Generation.md) - Secret enhancement for Ansible
- [manthana/RFC-007-Terraform-Secret-Management](../manthana/RFC-007-Terraform-Secret-Management.md) - Secret enhancement for Terraform

## **Decision**

We will adopt a **Dual-Mode Hybrid Secret Management** model.

### **1\. Provisioning Mode (Terraform \+ 1Password Provider)**

For infrastructure provisioning (AWS, Cloudflare, Proxmox), Terraform will use the **official 1Password Provider**. Secrets will be fetched declaratively during the plan and apply phases. This eliminates the need for manual export of environment variables and prevents secret leakage in shell histories.

### **2\. Configuration Mode (Ansible \+ Scoped Vaults)**

For node configuration (Nebula, K3s, Hardening), we will use **Ansible Vault** encrypted at rest in Git. These vaults are generated from templates that reference 1Password. This preserves the **"Asanga Shastra"** (Detachment) principle, allowing for offline disaster recovery.

## **Implementation**

### **1\. Secret Distribution Strategy**

| Layer | Tool | Source | Use Case |
| :---- | :---- | :---- | :---- |
| **Authoritative** | 1Password | Project-Brahmanda Vault | SSOT for all keys, tokens, and passwords. |
| **Provisioning** | Terraform | onepassword Provider | Dynamic injection into AWS, Cloudflare, and Proxmox providers. |
| **Configuration** | Ansible | Scoped vault.yml | Encrypted-in-Git secrets for mesh and cluster setup. |
| **CI/CD** | GitHub Actions | OP\_SERVICE\_ACCOUNT\_TOKEN | The single bootstrap secret required to unlock the universe. |

### **2\. Secret Flow Architecture**

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
(Cloud/VMs/IPs)     (Mesh/K3s/Secrets)
```

### **3\. Terraform Integration (RFC-007)**

Terraform configurations **MUST** use the onepassword\_item data source.

\# Example: samsara/terraform/kshitiz/main.tf

data "onepassword\_item" "aws\_creds" {
  vault \= "Project-Brahmanda"
  title \= "AWS-samsara-iac"
}

provider "aws" {
  access\_key \= data.onepassword\_item.aws\_creds.username
  secret\_key \= data.onepassword\_item.aws\_creds.password
}

### **4\. Ansible Vault Management (Nidhi Framework)**

We use the **Nidhi** (Treasure) framework to manage Ansible secrets. Vaults are artifacts generated from templates.

- Nidhi-Tirodhana (Concealment): make nidhi-tirodhana
  Generates encrypted vault.yml from vault.tpl.yml by resolving op:// references.
- Nidhi-Avirbhava (Manifestation): make nidhi-avirbhava
  Decrypts vaults for emergency manual inspection.
- Samshodhana (Refinement): make samshodhana
  Securely edits a vault in-memory.

### **5\. 1Password Vault Items**

The **"Project-Brahmanda"** vault must contain:

1. **AWS-samsara-iac:** Login item (Access Key/Secret).
2. **Cloudflare:** API Credential (Token/Account ID).
3. **Ansible Vault \- Samsara:** Password for Git-encrypted files.
4. **Infrastructure SSH Keys:** Private/Public keys for node access.

## **Local & CI/CD Workflow**

### **Local Development**

Before running any automation, ensure the Service Account token is active:

export OP\_SERVICE\_ACCOUNT\_TOKEN=$(op read "op://Project-Brahmanda/Service-Account/token")
make srishti

### **GitHub Actions**

The pipeline uses the 1Password Load Secrets action to bridge the gap.

\- name: Load Secrets
  uses: 1password/load-secrets-action@v1
  with:
    export-env: true
  env:
    OP\_SERVICE\_ACCOUNT\_TOKEN: ${{ secrets.OP\_SERVICE\_ACCOUNT\_TOKEN }}
    ANSIBLE\_VAULT\_PASSWORD: op://Project-Brahmanda/Ansible Vault \- Samsara/password

## **Consequences**

### **Positive**

- ✅ **Declarative Dependency:** Terraform code now explicitly shows what secrets it requires.
- ✅ **Security:** No plaintext secrets exist in shell environments or .tfvars files.
- ✅ **Offline Resilience:** Ansible Vaults in Git allow for recovery even if 1Password is unreachable (provided the Vault Password is known).
- ✅ **Zero-Trust:** The repository can be public; all sensitive material is encrypted or referenced via op:// URIs.

### **Negative**

- ⚠️ **Provider Overhead:** Adds a dependency on the 1Password/onepassword Terraform provider.
- ⚠️ **Sync Requirement:** Developers must remember to run make nidhi-tirodhana if templates are changed.

## **Conclusion**

By integrating the 1Password Terraform Provider, we close the gap between provisioning and configuration. We have achieved a state where our code is declarative, our secrets are central, and our infrastructure is truly **detached** (Asanga) yet **recoverable**.
