# **ADR-003: Hybrid Secret Management Strategy**

Date: 2026-01-07 (Amended from 2025-12-31)
Status: Accepted

## **Context**

Project Brahmanda requires the management of highly sensitive credentials (Nebula CA keys, SSH private keys, Cloud API tokens). Since the infrastructure spans multiple environments (MacBook, Windows/WSL, CI/CD pipelines) and manages the network layer itself, relying solely on an online-only secret manager creates a "Connectivity Paradox".

For detailed rationale, see:

- [manthana/RFC-003-Secret-Management.md](../manthana/RFC-003-Secret-Management.md) - Hybrid model foundation
- [manthana/RFC-006-Automated-Vault-Generation.md](../manthana/RFC-006-Automated-Vault-Generation.md) - Automation enhancement

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
│   │   │   ├── vault.tpl.yml  # Template with op:// references
│   │   │   ├── vault.yml      # Encrypted vault (generated)
│   │   │   └── vars.yml
│   │   ├── kshitiz/      # Edge Layer Secrets (Lighthouse)
│   │   │   ├── vault.tpl.yml
│   │   │   └── vault.yml
│   │   └── vyom/         # Compute Layer Secrets (K3s Tokens, Longhorn)
│   │       ├── vault.tpl.yml
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

### **5. Vault Management**

**Automated Vault Generation (Recommended - RFC-006):**

Vault files are **generated** from templates stored in `group_vars/*/vault.tpl.yml`. Templates contain `op://` secret references that are resolved from 1Password.

**Sanskrit Terminology:**

- **Nidhi** (निधि) - "treasure repository" - Generate vaults from 1Password
- **Pariksha-Nidhi** (परीक्षा-निधि) - "examine treasures" - Verify vault integrity
- **Tirodhana** (तिरोधान) - "concealment" - Encrypt vaults
- **Avirbhava** (अविर्भाव) - "manifestation" - Decrypt vaults
- **Samshodhana** (संशोधन) - "editing" - Modify vaults

**Commands:**

- **Generate All Vaults (Nidhi-Tirodhana):** Regenerate vaults from 1Password templates.

  ```bash
  make nidhi-tirodhana
  ```

  This reads all `vault.tpl.yml` files, resolves `op://` references, and creates encrypted `vault.yml` files.

- **Generate Single Vault:** Generate one specific vault.

  ```bash
  make nidhi-tirodhana VAULT=kshitiz  # or vyom, brahmanda
  ```

- **Verify Vaults (Nidhi-Nikasha):** Ensure all vaults can be decrypted.

  ```bash
  make nidhi-nikasha
  ```

- **Decrypt Vaults (Nidhi-Avirbhava):** For emergency manual inspection.

  ```bash
  make nidhi-avirbhava  # Decrypts all vaults
  make nidhi-avirbhava VAULT=kshitiz  # Decrypt specific vault
  ```

- **Edit (Samshodhana):** Securely edit vault file (decrypts in-memory, re-encrypts on save).

  ```bash
  make samshodhana
  ```

**Template Example** (`kshitiz/vault.tpl.yml`):

```yaml
---
# Kshitiz Ansible Vault
# Generated from: make nidhi-tirodhana VAULT=kshitiz
# DO NOT EDIT vault.yml DIRECTLY - Edit this template and regenerate

# SSH Private Key for Kshitiz Lightsail
ssh_private_key: |
  op://Project-Brahmanda/Kshitiz-Lighthouse-SSH-Key/private key

# Nebula Lighthouse Certificates
nebula_lighthouse_crt: |
  op://Project-Brahmanda/Nebula-Kshitiz-Lighthouse-Certificate/kshitiz-lighthouse.crt

nebula_lighthouse_key: |
  op://Project-Brahmanda/Nebula-Kshitiz-Lighthouse-Certificate/kshitiz-lighthouse.key
```

**Workflow:**

1. Update secret in 1Password (e.g., rotate SSH key)
2. Run `make nidhi-tirodhana` to regenerate vaults from templates
3. Commit encrypted `vault.yml` files to Git
4. 1Password remains the single source of truth

**Manual Vault Editing (Legacy):**

For backward compatibility, direct vault editing is still supported but discouraged. Always prefer template-based generation.

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

### **Positive:**

- Full offline recovery capability (vaults in Git, only need vault password)
- Secrets are version-controlled with code
- Zero-trust regarding code storage (repo can be public, secrets remain encrypted)
- **Single source of truth:** 1Password is authoritative, vaults are generated artifacts
- **Reduced errors:** Template-based generation eliminates copy-paste mistakes
- **Easy secret rotation:** Update 1Password → `make nidhi-tirodhana` → commit
- **Auditability:** Templates show structure, Git history shows when vaults changed

### **Negative:**

- High friction if the Vault Password is lost (data unrecoverable)
- Template maintenance required (keep templates in sync with playbook needs)
- Learning curve for `op inject` and template syntax
