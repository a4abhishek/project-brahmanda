# **RFC 006: Automated Ansible Vault Generation from 1Password**

**Status:** Proposed
**Date:** 2026-01-07
**Supersedes:** Enhances RFC-003 (Hybrid Secret Management)

---

## **Context**

RFC-003 established the hybrid secret management pattern: 1Password stores the Ansible Vault password, and Ansible Vault encrypts infrastructure secrets in Git. However, the current workflow has operational friction:

### **Current Manual Workflow:**

1. Generate secret in 1Password (e.g., SSH key, Nebula certificate)
2. Copy secret value to clipboard
3. Open `vault.yml` in editor
4. Decrypt with: `ansible-vault decrypt group_vars/kshitiz/vault.yml --vault-password-file=scripts/get-vault-password.sh`
5. Paste secret value into YAML
6. Re-encrypt with: `ansible-vault encrypt group_vars/kshitiz/vault.yml --vault-password-file=scripts/get-vault-password.sh`
7. Commit to Git

### **Problems with Manual Approach:**

1. **Error-Prone:** Copy-paste mistakes (trailing newlines, clipboard corruption)
2. **Tedious:** 6+ manual steps per secret change
3. **Security Risk:** Temporary plaintext `vault.yml` on disk during editing
4. **Inconsistency:** No guarantee vault matches 1Password (drift over time)
5. **Secret Rotation Friction:** High manual effort discourages regular key rotation
6. **No Audit Trail:** Can't easily see what changed between vault versions

### **The Single Source of Truth Problem:**

Currently, we claim "1Password is the source of truth" but in practice, Ansible Vault becomes a **fork** of 1Password data. When a secret changes in 1Password, the vault must be manually synchronized. This violates the DRY (Don't Repeat Yourself) principle.

---

## **Scope**

### **Current (Phase 1):**

- Automate generation of Ansible Vault files from 1Password templates
- Implement Makefile targets for vault regeneration
- Support three vault scopes: `brahmanda`, `kshitiz`, `vyom`
- Maintain backward compatibility with existing vault structure

### **Future (Out of Scope for Now):**

- Dynamic secret injection at runtime (no vault files at all)
- Vault file versioning/diffing tools
- Automatic commit generation for the vault update in the PRs if vault template is updated
- Automatic CI/CD vault regeneration on 1Password changes
- Secret rotation automation

---

## **Proposal: Template-Based Vault Generation**

### **Architecture**

```
┌───────────────────────────────────────────────────────────────┐
│                         1Password                             │
│                  (Single Source of Truth)                     │
│   ┌──────────────────┐  ┌──────────────────┐                  │
│   │ AWS Credentials  │  │ SSH Keys         │                  │
│   │ Nebula Certs     │  │ K3s Tokens       │                  │
│   └──────────────────┘  └──────────────────┘                  │
└───────────────────────────────────────────────────────────────┘
                            │
                            │ op inject
                            ▼
┌────────────────────────────────────────────────────────────────┐
│                   vault.tpl.yml (Templates)                    │
│              Committed to Git (Unencrypted)                    │
│   ┌──────────────────────────────────────────────────┐         │
│   │ ssh_private_key: |                               │         │
│   │   op://Project-Brahmanda/SSH-Key/private key     │         │
│   │                                                  │         │
│   │ nebula_ca_key: |                                 │         │
│   │   op://Project-Brahmanda/Nebula-CA/ca.key        │         │
│   └──────────────────────────────────────────────────┘         │
└────────────────────────────────────────────────────────────────┘
                            │
                            │ make nidhi
                            ▼
┌────────────────────────────────────────────────────────────────┐
│                   vault.yml (Encrypted Vaults)                 │
│              Committed to Git (Ansible Encrypted)              │
│   ┌──────────────────────────────────────────────────┐         │
│   │ $ANSIBLE_VAULT;1.1;AES256                        │         │
│   │ 66386439653...encrypted...blob...here            │         │
│   └──────────────────────────────────────────────────┘         │
└────────────────────────────────────────────────────────────────┘
```

### **Workflow:**

1. **Developer updates secret in 1Password** (e.g., rotates SSH key)
2. **Run:** `make nidhi-tirodhana` (or `make nidhi-tirodhana VAULT=kshitiz`)
3. **Behind the scenes:**
   - `op inject` reads `vault.yml.tpl` and replaces `op://...` references with actual secrets
   - `ansible-vault encrypt` encrypts the plaintext output
   - Result: `vault.yml` is updated with new secret, encrypted, ready to commit
4. **Commit:** `git add group_vars/*/vault.yml && git commit -m "chore: rotate SSH keys"`

---

## **Implementation Details**

### **1. File Structure**

```
samsara/ansible/group_vars/
├── brahmanda/
│   ├── vars.yml             # Non-secret variables (committed plaintext)
│   ├── vault.yml.tpl        # Template with op:// refs (committed, unencrypted)
│   └── vault.yml            # Encrypted vault (committed, encrypted)
├── kshitiz/
│   ├── vars.yml
│   ├── vault.yml.tpl
│   └── vault.yml
└── vyom/
    ├── vars.yml
    ├── vault.yml.tpl
    └── vault.yml
```

### **2. Template Example** (`kshitiz/vault.yml.tpl`)

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

### **3. Makefile Targets**

**Sanskrit Terminology:**

- **nidhi-tirodhana** (निधि-तिरोधान) - "treasury concealment" - Generate and encrypt vaults from 1Password
- **nidhi-nikasha** (निधि-निकष) - "treasury touchstone test" - Verify vault integrity

**Integrates with existing targets:**

- **nidhi-avirbhava** (निधि-अविर्भाव) - "treasury manifestation" - Decrypt vaults
- **samshodhana** (संशोधन) - "editing" - Modify specific vault manually

```makefile
.PHONY: nidhi-tirodhana
nidhi-tirodhana: ## Generate all Ansible vaults from 1Password templates (निधि-तिरोधान - treasury concealment)
 @echo "🔐 Generating Ansible vaults from 1Password templates..."
 @for vault_dir in samsara/ansible/group_vars/*/; do \
  if [ -f "$$vault_dir/vault.yml.tpl" ]; then \
   vault_name=$$(basename "$$vault_dir"); \
   echo "  → Processing $$vault_name..."; \
         op inject -i "$$vault_dir/vault.tpl.yml" -o "$$vault_dir/vault.tmp.yml" && \
   ansible-vault encrypt "$$vault_dir/vault.yml.tmp" \
    --vault-password-file=scripts/get-vault-password.sh \
    --output="$$vault_dir/vault.yml" && \
   rm "$$vault_dir/vault.yml.tmp" && \
   echo "  ✅ $$vault_name vault encrypted"; \
  fi; \
 done
 @echo "✅ All vaults generated and encrypted successfully"

.PHONY: generate-vault
generate-vault: ## Generate single vault (Usage: make generate-vault VAULT=kshitiz)
 @if [ -z "$(VAULT)" ]; then \
  echo "❌ Error: VAULT parameter required"; \
  echo "Usage: make generate-vault VAULT=kshitiz|vyom|brahmanda"; \
  exit 1; \
 fi
 @echo "🔐 Generating $(VAULT) vault from 1Password..."
 @vault_dir="samsara/ansible/group_vars/$(VAULT)"; \
 if [ ! -f "$$vault_dir/vault.yml.tpl" ]; then \
  echo "❌ Template not found: $$vault_dir/vault.yml.tpl"; \
  exit 1; \
 fi; \
   op inject -i "$$vault_dir/vault.tpl.yml" -o "$$vault_dir/vault.tmp.yml" && \
 ansible-vault encrypt "$$vault_dir/vault.yml.tmp" \
  --vault-password-file=scripts/get-vault-password.sh \
  --output="$$vault_dir/vault.yml" && \
 rm "$$vault_dir/vault.yml.tmp" && \
 echo "✅ $(VAULT) vault encrypted successfully"

.PHONY: verify-vaults
verify-vaults: ## Verify all vaults can be decrypted
 @echo "🔍 Verifying Ansible vaults..."
 @for vault_file in samsara/ansible/group_vars/*/vault.yml; do \
  vault_name=$$(basename $$(dirname "$$vault_file")); \
  echo "  → Checking $$vault_name..."; \
  ansible-vault view "$$vault_file" \
   --vault-password-file=scripts/get-vault-password.sh > /dev/null && \
  echo "  ✅ $$vault_name vault valid"; \
 done
 @echo "✅ All vaults verified successfully"
```

### **4. Integration with Existing Targets**

The `nidhi-tirodhana` target is the primary vault generation command:

```makefile
.PHONY: nidhi-tirodhana
nidhi-tirodhana: ## Treasury Concealment (generates and encrypts from 1Password)
	@echo "💎🔒 Nidhi-Tirodhana: Generating and securing treasure repositories..."
---

## **Alternatives Considered**

### **Alternative 1: Runtime Secret Injection (op run)**

**Approach:** Don't store secrets in vault at all. Inject at runtime via `op run -- ansible-playbook`.

**Pros:**

- No vault files in Git (cleaner)
- Always up-to-date with 1Password
- No manual regeneration step

**Cons:**

- ❌ **Breaks offline recovery** (violates RFC-003 "Connectivity Paradox")
- ❌ Requires internet connection for every Ansible run
- ❌ Increases latency (API calls per secret)
- ❌ Complex templating in playbooks (`{{ lookup('env', 'OP_REF') }}`)

**Decision:** Rejected - Offline capability is a core requirement.

---

### **Alternative 2: Git Pre-Commit Hook Regeneration**

**Approach:** Automatically regenerate vaults on every commit via pre-commit hook.

**Pros:**

- Never forget to regenerate
- Always in sync

**Cons:**

- ❌ Slow commits (1Password API calls)
- ❌ Commits fail if no internet
- ❌ Unexpected vault changes in commits
- ❌ Difficult to review actual changes

**Decision:** Rejected - Explicit regeneration is better for control and auditability.

---

### **Alternative 3: Keep Manual Process**

**Approach:** Continue current manual decrypt/edit/encrypt workflow.

**Pros:**

- No new tooling
- Simple to understand

**Cons:**

- ❌ Error-prone (already experienced copy-paste issues)
- ❌ Security risk (plaintext on disk)
- ❌ Time-consuming (discourages secret rotation)
- ❌ No single source of truth (drift over time)

**Decision:** Rejected - Automation significantly improves security and operational efficiency.

---

## **Consequences**

### **Positive:**

✅ **Single Source of Truth:** 1Password is authoritative, vaults are generated artifacts
✅ **Security:** No plaintext secrets on disk during editing
✅ **Idempotency:** Can regenerate vaults anytime with same results
✅ **Auditability:** Template shows structure, Git shows when vaults changed
✅ **Secret Rotation:** Trivial to rotate (update 1Password → `make nidhi-tirodhana` → commit)
✅ **Reduced Errors:** Eliminates copy-paste mistakes
✅ **Offline Recovery:** Still works (vaults in Git, only need vault password)
✅ **Developer Experience:** One command vs 6+ manual steps

### **Negative:**

⚠️ **Learning Curve:** Developers must learn template syntax and `op inject`
⚠️ **Template Maintenance:** Must keep templates in sync with playbook requirements
⚠️ **1Password Dependency:** If 1Password is down, can't regenerate (but existing vaults still work)
⚠️ **Git History:** Vault files change whenever regenerated (even if secrets unchanged)

### **Mitigations:**

- **Documentation:** Update Sarga Phase 5 with clear workflow examples
- **Verification Target:** `make nidhi-nikasha` ensures treasuries are intact
- **Makefile Help:** `make help` shows usage for all targets
- **Idempotent by Design:** Regenerating with same 1Password data produces identical encrypted output (Ansible Vault is deterministic with same input)

---

## **Migration Path**

### **Phase 1: Create Templates (Manual)**

1. Decrypt existing vaults: `ansible-vault decrypt group_vars/*/vault.yml`
2. Replace secret values with `op://` references
3. Save as `vault.yml.tpl`
4. Test: `make nidhi-tirodhana VAULT=kshitiz`
5. Verify: `make nidhi-nikasha` or `ansible-vault view group_vars/kshitiz/vault.yml`
6. Commit templates to Git

### **Phase 2: Update Documentation**

1. Update `vaastu/001-Sarga.md` Phase 5 (Adhisthana) to use templates
2. Create learning document: `vaastu/Learning-1Password-Secret-References.md`
3. Update `samsara/ansible/README.md` with new workflow

### **Phase 3: Integration**

1. Update `Makefile` with new targets
2. Update `.gitignore` to exclude `*.yml.tmp` temporary files
3. Test in CI/CD pipeline

---

## **Open Questions**

1. **Should we add `make samanvaya-nidhi` (समन्वय-निधि - "synchronize treasures")** to detect drift between 1Password and committed vaults?
   - Proposed: Generate vault to temp file, compare with committed version, warn if different

2. **Should templates be mandatory or optional?**
   - Proposed: Optional - keep supporting manual vault editing for flexibility

3. **How to handle multi-line secrets in templates?**
   - Answer: Use YAML literal block style (`|`) - already shown in examples above

4. **Should we version-control templates or treat them as documentation?**
   - Proposed: **Yes, commit templates** - They serve as documentation of vault structure

---

## **References**

- [RFC-003: Hybrid Secret Management](./RFC-003-Secret-Management.md)
- [ADR-003: Secret Management Implementation](../vidhana/ADR-003-secret-management.md)
- [1Password CLI - Secret References](https://developer.1password.com/docs/cli/secret-references/)
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

---

## **Conclusion**

This proposal enhances the existing hybrid secret management strategy (RFC-003) by automating vault generation from 1Password templates. It maintains offline recovery capability while eliminating manual errors and establishing 1Password as the true single source of truth.

**Recommendation:** Accept and implement in phases. Start with Kshitiz vault as proof of concept.
