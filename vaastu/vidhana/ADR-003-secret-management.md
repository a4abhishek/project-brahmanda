# **ADR-003: Hybrid Secret Management Strategy**

Date: 2025-12-31
Status: Accepted

## **Context**

Project Brahmanda requires the management of highly sensitive credentials (Nebula CA keys, SSH private keys, Cloud API tokens). Since the infrastructure spans multiple environments (MacBook, Windows/WSL, CI/CD pipelines) and manages the network layer itself, relying solely on an online-only secret manager creates a "Connectivity Paradox".

For a detailed discussion and rationale, please see [manthana/RFC-003-Secret-Management.md](../manthana/RFC-003-Secret-Management.md).

## **Decision**

We will adopt a **Hybrid Secret Management** model combining **Ansible Vault** and **1Password**.

### **1. The Storage Layer (Ansible Vault)**

- All infrastructure secrets (SSH keys, API tokens, Certificates) **MUST** be stored encrypted at rest within the Git repository using **Ansible Vault**.
- Secrets **MUST** be scoped by domain using the "Scoped Files, Single Key" pattern:
  - `group_vars/brahmanda/vault.yml`: Global secrets (Nebula CA).
  - `group_vars/kshitiz/vault.yml`: Edge secrets.
  - `group_vars/vyom/vault.yml`: Compute secrets.

### **2. The Access Layer (1Password)**

- The **Ansible Vault Password** and cloud provider root credentials **MUST** be stored in a dedicated 1Password Vault named **"Project-Brahmanda"**.
- They **MUST NOT** be stored in the user's "Private" vault to ensure isolation and least-privilege access for Service Accounts.
- The Vault Password **MUST NEVER** be committed to Git in plain text.

## **Implementation**

### **1. Secret Distribution Strategy**

Secrets are distributed across three layers for security and operational efficiency:

**1Password Vault (Project-Brahmanda):**
- AWS Access Key ID and Secret Access Key
- Cloudflare API Token
- Ansible Vault Password (the master key to decrypt all Ansible Vaults)

**Ansible Vault (Encrypted in Git):**
- Nebula CA private key (`ca.key`)
- SSH private keys for nodes
- K3s cluster tokens
- Longhorn R2 credentials (access-key-id, secret-access-key, endpoint)

**GitHub Secrets:**
- `OP_SERVICE_ACCOUNT_TOKEN` (the **only** secret stored here)

### **2. Secret Flow Architecture**

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

### **3. Directory Structure**

```text
samsara/
├── ansible/
│   ├── group_vars/
│   │   ├── brahmanda/    # Global Secrets (Nebula CA, Admin Passwords)
│   │   │   ├── vault.yml
│   │   │   └── vars.yml
│   │   ├── kshitiz/      # Edge Layer Secrets (Lighthouse)
│   │   │   └── vault.yml
│   │   └── vyom/         # Compute Layer Secrets (K3s Tokens, Longhorn)
│   │       └── vault.yml
```

### **4. 1Password Setup**

Create the following items in the **"Project-Brahmanda"** vault:

1. **AWS Credentials:**
   - Type: Login or API Credential
   - Item Name: `AWS-samsara-iac`
   - Fields:
     - `Security Credentials/AWS_ACCESS_KEY_ID`
     - `Security Credentials/AWS_ACCESS_KEY_SECRET`

2. **Cloudflare API Token:**
   - Type: API Credential
   - Item Name: `Cloudflare`
   - Field: `api-token`

3. **Ansible Vault Password:**
   - Type: Password
   - Item Name: `Ansible Vault - Samsara`
   - Field: `password`

4. **1Password Service Account:**
   - Create a Service Account with access **scoped only** to the "Project-Brahmanda" vault.
   - Copy the `OP_SERVICE_ACCOUNT_TOKEN` and store it in GitHub Repository Secrets.

### **5. Vault Management Commands**

Use the provided Makefile targets to manage Ansible Vault files:

- **Encrypt (Tirodhana):** Encrypt the vault file after editing.
  ```bash
  make tirodhana
  ```

- **Decrypt (Avirbhava):** Decrypt the vault file for viewing (use sparingly).
  ```bash
  make avirbhava
  ```

- **Edit (Samshodhana):** Securely edit the vault file (decrypts in-memory, re-encrypts on save).
  ```bash
  make samshodhana
  ```

All commands automatically fetch the Ansible Vault Password from 1Password using:
```bash
op read "op://Project-Brahmanda/Ansible Vault - Samsara/password"
```

### **6. Local Development Workflow**

**Option A: Manual Entry (Offline Mode)**
```bash
ansible-playbook setup.yml --ask-vault-pass
```

**Option B: Automated (Online Mode using 1Password CLI)**
```bash
ansible-playbook setup.yml --vault-password-file <(op read "op://Project-Brahmanda/Ansible Vault - Samsara/password")
```

### **7. GitHub Actions Configuration**

**Step 1: Store the Service Account Token**
- Add `OP_SERVICE_ACCOUNT_TOKEN` to GitHub Repository Secrets.

**Step 2: Configure Workflow**

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

- name: Run Ansible Playbook
  run: |
    echo "$ANSIBLE_VAULT_PASSWORD" > .vault_pass
    ansible-playbook site.yml --vault-password-file .vault_pass
    rm .vault_pass
  env:
    ANSIBLE_VAULT_PASSWORD: ${{ env.ANSIBLE_VAULT_PASSWORD }}
```

## **Consequences**

- **Positive:** Full offline recovery capability. Secrets are version-controlled with code. Zero-trust regarding where the code is stored.
- **Negative:** High friction if the Vault Password is lost.
