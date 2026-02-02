# RCA-010: Kshitiz SSH Lockout ("The One-Shot Failure")

- **Date of Incident:** 2026-02-01
- **Severity:** High (Persistent lockout after initial success)
- **Status:** Resolved
- **Components:** Ansible, AWS Lightsail, SSHD

## 1. The Incident (Ghatana)

- **Summary:** The bootstrapping of the Kshitiz (Edge) layer exhibited a "One-Shot" failure pattern. The first run on a fresh instance succeeded perfectly. However, all subsequent runs (idempotency checks) failed with `Permission denied (publickey)`, effectively locking the operator out of the instance.
- **Impact:** Inability to re-run Ansible for configuration management or maintenance. Required total destruction of the instance to recover access.
- **Detection:** `make kshitiz` failed on the second run with SSH timeout/permission denied errors, despite no changes to keys or configuration.

## 2. The Timeline (Samaya-Sarni)

1. **Run 1 (Success):** `make kshitiz` provisioned a fresh Lightsail instance and ran the Ansible playbook. All tasks, including "Harden SSH Server", completed successfully.
2. **Run 2 (Failure):** Immediately running `make kshitiz` again resulted in `Permission denied (publickey)`.
3. **Investigation 1 (Keys):** Suspected Terraform state mismatch or stale keys. Tainted resources, verified 1Password keys. No issues found.
4. **Investigation 2 (Firewall):** Suspected Terraform destroying/recreating firewall rules might be blocking port 22. Verified port was open (Connection Refused vs Permission Denied).
5. **Investigation 3 (Local Agent):** Suspected local SSH agent offering too many keys, hitting `MaxAuthTries`. Added `-o IdentitiesOnly=yes` to `ansible.cfg`. Failure persisted.
6. **Root Cause Discovery:** Reviewed the "Harden SSH Server" task logs from Run 1. Noticed `UsePAM no`.
7. **Resolution:** Reverted to `UsePAM yes` and recreated the instance. Access persisted across multiple runs.

## 3. The Root Cause (Mula Karana)

- **The "Five Whys":**
  1. **Why did Run 2 fail?** SSHD rejected the valid private key.
  2. **Why was it rejected?** The SSH session initialization failed internally on the server.
  3. **Why did it fail internally?** Because the `UsePAM no` setting in `sshd_config` (applied in Run 1) disabled the Pluggable Authentication Modules required by the Ubuntu Lightsail image for session setup.
  4. **Why did we disable PAM?** We applied a generic "Hardening" checklist without verifying compatibility with the specific cloud image constraints.
  5. **Why did Run 1 succeed?** The SSHD configuration changes (including disabling PAM) only take effect *after* the service restarts. The existing connection (Run 1) remained active until completion.

- **Technical Cause:** On AWS Lightsail Ubuntu images, the SSH daemon relies on PAM for account and session management even when using public key authentication. Setting `UsePAM no` breaks this dependency, causing the daemon to close the connection immediately after authentication seems to succeed, which the client interprets as `Permission denied`.

## 4. The Resolution (Samadhana)

- **Immediate Fix:**
    1. Modified `samsara/ansible/playbooks/tasks/harden_ssh.yml` to set `UsePAM yes`.
    2. Destroyed the "bricked" instance by running `make pralaya-kshitiz`.
    3. Re-ran `make kshitiz` to provision a clean instance with the correct configuration.

## 5. The Lessons & Prevention (Shiksha & Nivarana)

- **What did we learn?**
  1. **"Works Once" is a Trap:** If a system works on creation but fails on update, suspect the configuration applied during creation (e.g., firewall, SSHD config, network interface changes).
  2. **Cloud Image Specifics:** Generic security baselines (CIS, DISA) often conflict with Cloud Provider defaults (Lightsail, EC2). Always validate hardening steps on the specific target platform.
  3. **PAM is Critical:** `UsePAM no` is rarely the right choice on modern Linux systems unless you are building a specialized appliance.

- **How to prevent it in future?**
  1. **Idempotency Testing:** Always verify a playbook by running it *twice* immediately after development.
  2. **Safe Hardening:** Use `validate: sshd -t -f %s` (which we did, but it checks syntax, not logic/runtime dependencies).

## 6. Action Items (Karya-Yojana)

- [x] Correct `harden_ssh.yml` to enable PAM.
- [x] Verify multiple consecutive runs of `make kshitiz`.
- [x] Document the incident (RCA).
