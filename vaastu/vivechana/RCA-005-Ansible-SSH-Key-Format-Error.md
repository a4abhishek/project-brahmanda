# RCA-005: Ansible SSH "Invalid Format" Error for 1Password Key

- **Date of Incident:** 2026-01-22
- **Severity:** High (Blocked all Ansible configuration)
- **Status:** Resolved
- **Components:** Ansible, Makefile, 1Password CLI, SSH

## 1. The Incident (Ghatana)

- **Summary:** After successfully provisioning the `vyom` VMs with Terraform, the `make vyom` target failed when attempting to run the Ansible playbook. All hosts were reported as `UNREACHABLE`.
- **Impact:** Ansible could not connect to any of the newly created VMs, preventing the K3s cluster bootstrap and all subsequent configuration.
- **Detection:** The `ansible-playbook` command failed with a clear error message for each host:

  ```
  fatal: [vyom-control-plane-1]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: ... Load key \"/tmp/prakriti_master_key_12345\": invalid format\r\n... Permission denied (publickey).", "unreachable": true}
  ```

## 2. The Root Cause (Mula Karana)

- **The "Five Whys":**
  1. **Why did Ansible fail?** The SSH connection was denied.
  2. **Why was it denied?** The SSH client refused to use the provided private key, citing an "invalid format".
  3. **Why was the format invalid?** The temporary key file began with `-----BEGIN PRIVATE KEY-----` (a generic PEM format) instead of the expected `-----BEGIN OPENSSH PRIVATE KEY-----`.
  4. **Why did the file have the wrong format?** Because the `Makefile` command `op read "op://.../private key"` retrieves a default, generic PEM-encoded version of the key from 1Password, not the original OpenSSH format.
  5. **Why was this default format used?** Because of a lack of awareness of how 1Password handles different SSH key formats and how to request a specific one via the CLI.

- **The confusion** There was a confusing discrepancy in presentation: the 1Password UI (Desktop/Web) often displays the key in its original or a standard working format, leading the operator to believe the stored data is correct. However, the `op read` command defaults to the standardized PKCS#8 PEM format, creating a mismatch between what is "seen" in the UI and what is "received" by the script.

- **Technical Cause:** The 1Password CLI, when reading a standard `SSH_KEY` item's `private key` field, defaults to returning a PKCS#8 PEM-encoded key. This happens because 1Password standardizes keys stored in this specific structured field. In contrast, keys stored as file attachments or in unstructured notes retain their original format. The OpenSSH client, especially with modern key types like `ed25519`, is strict and expects the newer, specific OpenSSH key format. This mismatch caused the client to reject the standardized PEM key.

## 3. The Resolution (Samadhana)

- **Immediate Fix:** The `op read` command in the `Makefile`'s `vyom` target was modified. By inspecting the full JSON output of the 1Password item (`op item get ...`), we discovered that the CLI can serve the key in different formats on demand.

The reference was changed to explicitly request the `openssh` format using a query parameter:

**Original (Incorrect):**

```makefile
op read "op://Project-Brahmanda/Prakriti Master Key/private key" > "$$KEY_FILE"
```

**Corrected:**

```makefile
op read "op://Project-Brahmanda/Prakriti Master Key/private key?ssh-format=openssh" > "$$KEY_FILE"
```

This command forces the 1Password CLI to return the key with the correct `-----BEGIN OPENSSH PRIVATE KEY-----` header, which the SSH client accepts.

## 4. The Lessons & Prevention (Shiksha & Nivarana)

- **What did we learn?**
  1. **Secret Format is as Important as Content:** A credential can be correct in value but incorrect in its encoding or format, leading to cryptic failures.
  2. **1Password CLI has powerful features:** The CLI is not just a simple key-value store. It understands the types of its data and can provide format conversions on the fly (e.g., `?ssh-format=openssh`).
  3. **"Invalid format" from SSH is a key format issue, not a corruption issue.** This error points directly to a mismatch in the header/footer lines of the key file.
  4. When in doubt, inspect the full object. Using `op item get ... --format json` was the key to discovering the available `ssh_formats` and their correct reference URIs.

- **How to prevent it in future?**<br>
When materializing SSH keys from any secret manager for use with an SSH client, always verify that the output format is the specific OpenSSH format, not a generic PEM format.

## 5. Action Items (Karya-Yojana)

- [x] Update `Makefile` `vyom` target to use the `?ssh-format=openssh` parameter.
- [x] Review `kshitiz` target in `Makefile` to ensure it also uses the correct SSH key format retrieval method.
- [x] Add a note to `ADR-003-secret-management.md` about the `ssh-format` requirement when using the "Ephemeral Key" pattern with SSH keys.
