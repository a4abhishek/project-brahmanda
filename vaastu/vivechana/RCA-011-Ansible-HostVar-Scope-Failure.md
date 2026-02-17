# RCA-011: Ansible HostVar Scope & Search Path Failures ("The Double Invisibility")

- **Date of Incident:** 2026-02-07 (Initial), 2026-02-16 (Secondary)
- **Severity:** High (Blocked cluster bootstrap and node identity placement)
- **Status:** Resolved
- **Components:** Ansible, `xanmanning.k3s` role, `trozz.ansible_nebula` role, Dynamic Inventory, Nidhi (Vault)

## 1. The Incident (Ghatana)

This incident involves a **"Double Failure"** pattern in the Vyom cluster bootstrap process, where infrastructure was successfully provisioned but software configuration failed due to two distinct variable visibility issues.

- **Failure A (The Crash - Variable Scoping):** During the bootstrapping of the Vyom cluster, the Ansible playbook failed with a cryptic Python attribute error: `object of type 'HostVarsVars' has no attribute 'k3s_control_node'`. This occurred deep within the K3s role while it was attempting to generate the cluster inventory file.

- **Failure B (The Missing Identity - Search Paths):** After resolving the scoping issue and migrating Nebula certificates to per-host vaults, the playbook failed with: `'nebula_node_crt' is undefined`. Despite the encrypted `host_vars/<hostname>/vault.yml` files existing with valid content, Ansible could not find them.

- **Impact:** The K3s cluster could not be initialized. Control plane nodes failed to configure, worker nodes failed to join, and individual node identities (Nebula certificates) could not be placed.

- **Detection:**
  - Failure A: Reported during the `Ensure ansible_host is mapped to inventory_hostname` task of the `xanmanning.k3s` role.
  - Failure B: Reported during the `📜 Place Nebula Node Certificate` task in the playbook pre_tasks section.

## 2. The Timeline (Samaya-Sarni)

### Phase 1: The Scoping Failure (Feb 7)

1. **Initial Failure:** Playbook failed with `k3s-agent service not found` on worker nodes.
    - *Diagnosis:* The role was skipping installation on workers.
    - *Root Cause:* Variable Name Collision. We defined a variable `k3s_server` (our config dict) which collided with the role's internal group name variable `k3s_server` (default group name).

2. **Attempted Fix 1:** Explicitly mapped node types using `k3s_control_node` and `k3s_agent_node` variables passed to `include_role`.
    - *Result:* Still failed - workers installed `k3s.service` (server) instead of `k3s-agent.service`.
    - *Reason:* Variables in `include_role` vars block are not visible to the role's internal conditionals that determine server vs agent installation.

3. **Attempted Fix 2:** Moved role selection variables to play-level `vars:` block.

    ```yaml
    vars:
      k3s_control_node: "{{ inventory_hostname in groups['vyom_control_plane'] }}"
      k3s_agent_node: "{{ inventory_hostname in groups['vyom_workers'] }}"
    ```

    - *Result:* Same failure - workers still installed server instead of agent.
    - *Reason:* Play-level vars are not automatically promoted to `hostvars`, so when the role on Host A looks up `hostvars['HostB']['k3s_control_node']`, it's not found.

4. **Secondary Failure:** The playbook crashed with the `HostVarsVars` attribute error during cluster topology discovery.
    - *Error Message:* `'ansible.vars.hostvars.HostVarsVars object' has no attribute 'k3s_control_node'`
    - *Location:* During `Ensure ansible_host is mapped to inventory_hostname` task in role's pre-configuration phase.
    - *Context:* The role iterates over all hosts in `ansible_play_hosts` to build cluster inventory file for HA setup.

5. **Attempted Fix 3:** Added `set_fact` task in playbook tasks section (after role inclusion).
    - *Result:* Too late - the role had already executed with missing variables.
    - *Reason:* Facts must be set **before** the role runs, not after.

6. **Root Cause Discovery A:** Realized that variables passed to `include_role` are **local** to the host execution context. When Host A (Master) tried to look up Host B (Worker) in `hostvars['HostB']`, the `include_role` variables were invisible. The role needs to see these flags in `hostvars` to determine cluster topology.

7. **Partial Resolution:** Moved `set_fact` to `pre_tasks` section, before role inclusion. This promoted the variables to the global `hostvars` scope, making them visible across all hosts during role execution.

### Phase 2: The Search Path Failure (Feb 16)

1. **Hardening Decision:** Transitioned from shared group Nebula certificates to individual per-host identities. Created `host_vars/<hostname>/vault.yml` for each node containing `nebula_node_crt` and `nebula_node_key`.

2. **Bootstrap Attempt (Post-Fix):** After applying the `set_fact` fix, ran `make vyom` expecting success.
    - *Result:* Playbook failed with `'nebula_node_crt' is undefined`.
    - *Location:* During `📜 Place Nebula Node Certificate` task in pre_tasks.
    - *Context:* The task tried to reference `{{ nebula_node_crt }}` which should have been loaded from `host_vars/<hostname>/vault.yml`.

3. **Investigation:** Verified encrypted vault files existed and contained valid certificates:

    ```bash
    ls -la samsara/ansible/host_vars/vyom-control-plane-1/vault.yml  # Exists, 2493 bytes
    ansible-vault view host_vars/vyom-control-plane-1/vault.yml      # Shows valid nebula_node_crt
    ```

    - The files existed, were properly encrypted, and contained the correct variables.
    - Yet Ansible reported the variables as undefined during playbook execution.

4. **Root Cause Discovery B:** Realized that Ansible's automatic `host_vars` loading only works when the directory is:
    - Adjacent to the **inventory file**, OR
    - Adjacent to the **playbook file**

    Our modular structure had `inventory/`, `playbooks/`, and `host_vars/` as sibling directories:

    ```
    samsara/ansible/
    ├── inventory/dynamic_inventory.py  ← Inventory here
    ├── playbooks/02-bootstrap-vyom.yml ← Playbook here
    └── host_vars/vyom-control-plane-1/ ← host_vars is sibling, not child
    ```

    This violated Ansible's "Search Path Gravity" - it only auto-loads `host_vars` that are children of the inventory or playbook directory, not siblings.

5. **Final Resolution:** Explicitly linked host_vars in the playbook `vars_files` section:

    ```yaml
    vars_files:
      - "../host_vars/{{ inventory_hostname }}/vault.yml"
    ```

    This overrides the implicit search mechanism and directly loads the per-host vault regardless of directory structure.

## 3. The Root Cause (Mula Karana)

### Failure A: Variable Scoping ("The Invisible Variable")

- **The "Five Whys":**
    1. **Why did the playbook crash?** The role tried to read `hostvars[item].k3s_control_node` and found it missing.
    2. **Why was it missing?** We defined `k3s_control_node` in the `vars` section of `include_role`, then moved to play-level `vars`, both of which don't populate `hostvars`.
    3. **Why is that a problem?** Variables defined in `include_role` or play-level `vars` are not promoted to the global `hostvars` dictionary; they are only available in the local task context of the host running the role. Other hosts can't see them.
    4. **Why did the role need to read other hosts' vars?** The role iterates over `ansible_play_hosts` to build a cluster-wide inventory file (`inventory.txt`) used for HA clustering logic. It needs to know which nodes are control-plane and which are agents across the entire cluster.
    5. **Why did we use `include_role` vars originally?** We were trying to workaround a previous issue where the role failed to detect node types automatically due to a variable name collision (`k3s_server` config dict vs. `k3s_server` group name).

- **Technical Cause:** Ansible Scoping Rules. `hostvars` only contains:
    1. Inventory variables (from inventory files or dynamic inventory scripts).
    2. Facts gathered by `setup` module or explicitly set via `set_fact`.
    3. Group vars and host vars (from `group_vars/` and `host_vars/` directories).

    It does **not** contain:
  - Task-level variables passed to `include_role`.
  - Play-level `vars` (unless explicitly registered as facts).
  - Variables defined in role `defaults/` or `vars/` (scoped to that role only).

- **Why Workers Installed Server:** The `xanmanning.k3s` role's server vs. agent detection logic:
    1. Checks if `k3s_control_node: true` is set → Install server
    2. Checks if `k3s_agent_node: true` is set → Install agent
    3. **Fallback:** If neither is explicitly set, defaults to server mode

    Since our variables weren't in `hostvars`, the role saw neither flag and fell back to server installation on all nodes.

### Failure B: Search Path Mismatch ("The Missing Directory")

- **The "Five Whys":**
    1. **Why was `nebula_node_crt` undefined?** Ansible failed to load the `host_vars/<hostname>/vault.yml` file.
    2. **Why did it fail to load?** The `host_vars` directory was not in Ansible's automatic search path.
    3. **Why wasn't it in the search path?** Ansible only auto-loads `host_vars` relative to the **Inventory File** or the **Playbook File** locations.
    4. **Why didn't our structure match?** We use a modular structure where `inventory/`, `playbooks/`, and `host_vars/` are sibling directories - not the parent-child relationship Ansible expects.
    5. **Why does this matter?** Because the `host_vars` folder is a sibling (not a child) of the folders where Ansible expects them, the implicit search failed - a phenomenon we call **"Search Path Gravity"**.

- **Technical Cause:** Ansible Directory Search Logic. Ansible automatically searches for `host_vars` in these locations:
    1. `<inventory_dir>/host_vars/` - Where the inventory file or script lives
    2. `<playbook_dir>/host_vars/` - Where the playbook YAML file lives

    Our structure:

    ```
    samsara/ansible/
    ├── inventory/
    │   └── dynamic_inventory.py     ← Inventory location
    ├── playbooks/
    │   └── 02-bootstrap-vyom.yml    ← Playbook location
    └── host_vars/
        ├── vyom-control-plane-1/    ← Variables location (SIBLING, not child)
        ├── vyom-worker-1/
        └── vyom-worker-2/
    ```

    Ansible searched for:
  - `inventory/host_vars/` ❌ (doesn't exist)
  - `playbooks/host_vars/` ❌ (doesn't exist)

    But didn't find:
  - `../host_vars/` ❌ (sibling directory, outside search path)

- **Why Modular Structure?** The project follows a convention-based layout where:
  - `inventory/` contains dynamic inventory scripts
  - `playbooks/` contains task definitions
  - `host_vars/` and `group_vars/` contain variable hierarchies

    This separation improves maintainability but breaks Ansible's "search path gravity" assumption that variables live under inventory or playbook directories.

## 4. The Resolution (Samadhana)

### Solution A: Promote Runtime Variables to Facts (Scoping Fix)

- **How `set_fact` in `pre_tasks` Fixed It:**
  - `ansible.builtin.set_fact` promotes variables to `hostvars[hostname]` (globally accessible)
  - `pre_tasks` execute **before** roles, ensuring variables exist when role reads `hostvars`
  - The role's topology code (`hostvars[item].k3s_control_node`) now finds the values
  - Each host sees other hosts' role assignments during cluster setup

- **Implementation:**
    1. **Global Promotion:** Used `set_fact` in `pre_tasks` (before role inclusion) to define `k3s_control_node` and `k3s_agent_node` based on group membership:

        ```yaml
        pre_tasks:
          - name: 🏷️ Set K3s Role Facts (For hostvars Access)
            ansible.builtin.set_fact:
              k3s_control_node: "{{ inventory_hostname in groups['vyom_control_plane'] }}"
              k3s_agent_node: "{{ inventory_hostname in groups['vyom_workers'] }}"
        ```

        **Note:** Both `set_fact` and `ansible.builtin.set_fact` work identically - the latter is the FQCN (Fully Qualified Collection Name), recommended for modern Ansible.

    2. **Collision Avoidance:** Removed the play-level `k3s_server` variable definition that was colliding with the role's group name variable. The role now uses its own internal logic without interference.

    3. **Cleanup:** Removed the local variable definitions from the `include_role` block and play-level `vars` section, keeping only the K3s configuration parameters.

    4. **Verification:** Added debug task to confirm role assignment:

        ```yaml
        - name: 🐛 Debug K3s Role Assignment
          ansible.builtin.debug:
            msg: "{{ inventory_hostname }}: k3s_control_node={{ k3s_control_node }}, k3s_agent_node={{ k3s_agent_node }}"
        ```

- **Result:**
  - Control plane: `k3s_control_node=true`, `k3s_agent_node=false` → Installed `k3s.service` (server)
  - Workers: `k3s_control_node=false`, `k3s_agent_node=true` → Installed `k3s-agent.service` (agent)
  - Role successfully built cluster inventory with correct node types
  - Cluster topology correctly recognized across all nodes

### Solution B: Explicit Identity Mapping (Search Path Fix)

- **Why Explicit Loading Was Necessary:**
  - Ansible's implicit `host_vars` loading failed due to modular directory structure
  - The automatic search only looks in child directories of inventory/playbook locations
  - Our sibling directory structure violated this assumption

- **Implementation:**
    To overcome the search path mismatch while maintaining our modular structure, we explicitly include the host-specific vault in the playbook header:

    ```yaml
    vars_files:
      - ../group_vars/brahmanda/vault.yml
      - ../group_vars/vyom/vars.yml
      - ../group_vars/vyom/vault.yml
      - "../host_vars/{{ inventory_hostname }}/vault.yml"  # ← Explicit per-host vault loading
    ```

    **Key Points:**
  - The path `../host_vars/{{ inventory_hostname }}/vault.yml` is relative to the playbook location
  - `{{ inventory_hostname }}` resolves to the current host (e.g., `vyom-control-plane-1`)
  - This bypasses the implicit search mechanism entirely
  - Variables are loaded before any tasks/roles execute

- **Result:**
  - Nebula certificates (`nebula_node_crt`, `nebula_node_key`) successfully loaded for each host
  - Identity placement tasks completed without "undefined" errors
  - Each node received its unique Nebula mesh identity
  - Security hardening achieved (individual certificates vs. shared group certificate)

### Alternative Solutions Considered

1. **Move host_vars adjacent to inventory:**

    ```
    inventory/
    ├── dynamic_inventory.py
    └── host_vars/          # Would work, but breaks modularity
    ```

    - **Rejected:** Violates separation of concerns (mixing inventory scripts with data)

2. **Move host_vars adjacent to playbooks:**

    ```
    playbooks/
    ├── 02-bootstrap-vyom.yml
    └── host_vars/          # Would work, but limits reusability
    ```

    - **Rejected:** Host variables should be global to the ansible directory, not scoped to one playbook

3. **Use inventory plugin to inject variables:**
    - Modify `dynamic_inventory.py` to read host_vars and inject into `_meta.hostvars`
    - **Rejected:** Over-engineering; explicit `vars_files` is simpler and more maintainable

4. **Set ANSIBLE_INVENTORY in ansible.cfg:**
    - Point to parent directory: `inventory = ./`
    - **Rejected:** Would break existing dynamic inventory script reference

## 5. The Lessons & Prevention (Shiksha & Nivarana)

- **What did we learn?**

    **About Variable Scoping:**
    1. **Scope Matters:** When a role needs to "look sideways" (inspect other hosts via `hostvars`), you **must** use `set_fact` in `pre_tasks` or inventory variables. Local vars, play-level vars, and `include_role` vars are invisible to neighbors.
    2. **Namespace Hygiene:** Avoid naming your configuration variables (e.g., `k3s_server` dictionary) the same as role internal variables (e.g., the `k3s_server` group name). This causes subtle collision issues.
    3. **Explicit > Implicit (Roles):** Relying on role "magic" (auto-detection) is fragile. Explicitly defining node types via facts is more robust and makes intent clear.
    4. **Timing Matters:** Facts must be set in `pre_tasks`, not in regular `tasks` after the role runs. The role sees the state of `hostvars` at the moment it executes.

    **About Search Paths:**
    5. **Directory Gravity:** The location of the inventory file determines where Ansible looks for data. Ansible only auto-loads `host_vars` from directories that are **children** of the inventory or playbook directory, not siblings.
    6. **Explicit > Implicit (Paths):** In custom/modular project structures, do not rely on "Ansible Magic" for directory loading. Explicitly link variable files via `vars_files` to ensure they're loaded regardless of directory structure.
    7. **Modular Structure Trade-offs:** Separating `inventory/`, `playbooks/`, and variable directories improves organization but requires explicit path management. The convenience of implicit loading only works with flat/co-located structures.
    8. **Validation Technique:** When variables appear undefined despite files existing:
        - Check if files are encrypted: `head -n1 file.yml` (should show `$ANSIBLE_VAULT`)
        - Verify decryption works: `ansible-vault view file.yml`
        - Check directory relationship: Is `host_vars` a **child** or **sibling** of inventory/playbook?
        - Test explicit loading: Add to `vars_files` and rerun

    **General Debugging Patterns:**
    9. **Debugging Pattern:** When a role fails with "missing attribute" in `hostvars`, check:
        - Where the variable is defined (play, task, role vars?)
        - When it's set (before or after role execution?)
        - Whether it's promoted to `hostvars` (use `debug: var=hostvars[inventory_hostname]`)
    10. **"Undefined" ≠ Missing File:** If Ansible says a variable is undefined, the issue may not be that the file doesn't exist, but that Ansible isn't looking in the right place for it.

- **How to prevent it in future?**

    **For Variable Scoping:**
    1. **Audit Role Variables:** Before using a complex community role, check its `defaults/main.yml` for variable name collisions with your configuration dictionaries.
    2. **Prefer Facts for Cluster Logic:** Any logic that involves cluster topology (nodes knowing about other nodes) should use Facts set in `pre_tasks`.
    3. **Document Scoping Requirements:** If a playbook requires `hostvars` visibility, document this in comments with the reason why.
    4. **Test Idempotency:** Always run playbooks twice - the second run will catch issues where state isn't properly persisted in facts/inventory.

    **For Search Paths:**
    5. **Standardize vars_files Block:** Maintain a standardized `vars_files` block in all playbooks that includes explicit relative paths to all variable directories:
        ```yaml
        vars_files:
          - ../group_vars/<group>/vars.yml
          - ../group_vars/<group>/vault.yml
          - "../host_vars/{{ inventory_hostname }}/vault.yml"
        ```
    6. **Document Directory Structure:** Add a comment block at the top of playbooks explaining the directory structure and why explicit `vars_files` is needed.
    7. **Test with Minimal Inventory:** When debugging "undefined" errors, test with a simple static inventory to isolate whether the issue is search paths vs. dynamic inventory generation.
    8. **Consider Directory Consolidation (Future):** For the next major refactor, evaluate whether to consolidate `host_vars/` and `group_vars/` under `inventory/` or `playbooks/` to leverage implicit loading - but only if it doesn't sacrifice organizational clarity.

## 6. Action Items (Karya-Yojana)

- [x] Refactor `02-bootstrap-vyom.yml` to use `set_fact` in `pre_tasks` (Feb 7).
- [x] Add explicit `vars_files` entry for per-host vaults (Feb 16).
- [x] Verify cluster bootstrap (Srishti) with both fixes applied.
- [x] Document the double failure pattern (RCA-011).
- [ ] Standardize `vars_files` block across all playbooks (Future).
- [ ] Evaluate directory structure consolidation for next major refactor (Future).
