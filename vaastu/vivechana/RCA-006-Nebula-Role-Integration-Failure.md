# RCA-007: Nebula Ansible Role Integration Failure

- **Date of Incident:** 2026-01-22
- **Severity:** Medium (Blocked configuration, required role replacement)
- **Status:** Resolved
- **Components:** Ansible, `utkuozdemir.nebula` role, `trozz.ansible_nebula` role

## 1. The Incident (Ghatana)

- **Summary:** During the bootstrapping of the `vyom` cluster, we attempted to use the `utkuozdemir.nebula` Ansible role to install and configure the Nebula mesh. We faced persistent logic failures when trying to use pre-generated certificates instead of letting the role generate them.
- **Impact:** Significant time lost debugging Ansible errors; inability to complete the `vyom` bootstrap using the initial role.
- **Context:** Bootstrapping *Vyom* (Compute) nodes with pre-generated certificates stored in *Nidhi* (Ansible Vault).
- **Conflict:** The role is designed with an "All-in-One" mindset (where it manages the CA and generates certs). It struggled to accept an "External Identity" pattern where certificates are injected purely via variables, leading to a cascade of logic failures.

## 2. The Timeline of Errors & Fixes (Samaya-Sarni)

### 1. The Delegation Failure

- **The Error:**

  ```text
  FAILED! => {"msg": "Empty hostname produced from delegate_to: \"{{ nebula_ca_host }}\""}
  ```

- **Context:** We set `nebula_ca_manage: false` to disable CA generation.

- **The Issue:** Despite the boolean flag, the role still attempted to reference `{{ nebula_ca_host }}` in a `delegate_to` task (likely a `wait_for` check). Since we didn't define a CA host (because we are the CA), the variable was empty/undefined, crashing the Jinja2 templating.
- **The Pivot:** We attempted to define a dummy host.

### 2. The Localhost Sudo Trap

- **The Attempt:** Set `nebula_ca_host: localhost`.
- **The Error:**

  ```text
  fatal: [vyom-worker-1 -> localhost]: FAILED! => {"msg": "sudo: a password is required"}
  ```

- **The Issue:** `delegate_to: localhost` executes the task on the Ansible Controller (my Laptop/WSL). The task required `become: true` (root), but your local user requires a sudo password, causing the failure.

- **The Fix:** **"Delegate to Self"**. We set `nebula_ca_host: "{{ inventory_hostname }}"`. This forced the task to run on the remote node itself (where we already have root access), bypassing local permission issues.

### 3. The Phantom Key Timeout

- **The Error:**

  ```text
  fatal: [vyom-worker-1]: FAILED! => {"msg": "Timeout when waiting for file /etc/nebula/ca.key"}
  ```

- **The Issue:** Even with delegation fixed, the role has a hard logic gate: *If `nebula_ca_host` is defined, verify the CA Private Key exists on that host.*

- **The Conflict:** We strictly adhere to **Asanga** (Detachment/Security). We do not want the CA Private Key (`ca.key`) to exist on worker nodes. The role refused to proceed without seeing this file.
- **The Fix:** **"The Dummy Artifact"**. We overrode the path variable `nebula_ca_key_file: "/bin/sh"`. This tricked the role's `stat` check into passing (because `/bin/sh` exists) without actually exposing a private key.

### 4. The Invalid PEM Block (The Root Cause)

- **The Error:**

  ```text
  stderr: "Error: error while parsing ca-key: input did not contain a valid PEM encoded block"
  cmd: ["/usr/local/bin/nebula-cert", "sign", ... "-ca-key", "/bin/sh"]
  ```

- **The Issue:** The role logic fell through to the **"Sign Certificate"** task. Why? Because the variables for the node certificates (`nebula_cert` / `nebula_key`) were empty or undefined in the specific way the role checked for them.

- **The Mechanism:**
  1. Role checks: *Do I have a cert for this node?* (No, variable mapping was seemingly insufficient).
  2. Role decides: *I must generate one.*
  3. Role executes: `nebula-cert sign`.
  4. Role uses: The CA Key path we provided.
  5. **Crash:** It tried to use `/bin/sh` as a cryptographic private key to sign the certificate.

## 3. The Root Cause (Mula Karana)

The friction stems from the role's internal logic flow. The role natively expects variables named `nebula_cert` and `nebula_key`. If these are not populated in the exact scope the role expects, it defaults to generation logic.

**The Learning:**
When overriding an "opinionated" Ansible role to act in a "dumb" mode (just copy files), you must ensure **every** condition that triggers "smart" behavior (like generation) is negated. In this case, simply setting `ca_manage: false` was insufficient; we had to explicitly provide the *result* (the certs) to stop the *process* (the generation).

## 4. The Resolution (Samadhana)

- **Role Replacement:** We replaced `utkuozdemir.nebula` with `trozz.ansible_nebula`.
- **Why this worked:** The new role has a simpler scope. It does not attempt to manage a CA. It simply takes the certificate paths as variables (`pki.cert`, `pki.key`) and configures the service. This aligned perfectly with our strategy of pre-placing certificates via Ansible Vault.

## 5. The Lessons & Prevention (Shiksha & Nivarana)

- **What did we learn?**
  1. **Don't Fight the Tool:** If you have to write more hacks (fake hosts, dummy files pointing to `/bin/sh`) than actual configuration to make a tool work, it's the wrong tool.
  2. **Opinionated vs. Flexible:** Highly opinionated "magic" roles are great when you follow their happy path, but painful when you deviate. Simpler, "dumb" roles are often better for complex, custom architectures.
  3. **Evaluate Logic Flow:** When selecting an Ansible role, check if it assumes it owns the entire lifecycle of a resource (creation + config) or just the configuration. For "Asanga" patterns, we prefer configuration-only roles.

- **How to prevent it in future?**
  1. Prioritize roles that explicitly support "bring your own certs/config" modes without side effects.
  2. Be willing to pivot faster. If a role requires subverting its own logic to work (e.g., pointing it to `/bin/sh` as a key), it's time to switch.

## 6. Action Items (Karya-Yojana)

- [x] Replace `utkuozdemir.nebula` with `trozz.ansible_nebula` in `Makefile` and Playbook.
- [x] Document the logic conflict in this RCA.
