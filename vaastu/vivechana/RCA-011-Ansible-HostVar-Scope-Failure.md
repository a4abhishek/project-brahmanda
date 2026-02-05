# RCA-011: Ansible HostVar Scope Failure ("The Invisible Variable")

- **Date of Incident:** 2026-02-07
- **Severity:** High (Blocked cluster bootstrap)
- **Status:** Resolved
- **Components:** Ansible, `xanmanning.k3s` role, Dynamic Inventory

## 1. The Incident (Ghatana)

- **Summary:** During the bootstrapping of the Vyom (Compute) cluster, the Ansible playbook failed with a cryptic Python attribute error: `object of type 'HostVarsVars' has no attribute 'k3s_control_node'`. This occurred deep within the K3s role while it was attempting to generate the cluster inventory file.
- **Impact:** The K3s cluster could not be initialized. The control plane node failed to configure, and worker nodes failed to join because they could not identify the master.
- **Detection:** The failure was reported in the Ansible stdout during the `Ensure ansible_host is mapped to inventory_hostname` task of the `xanmanning.k3s` role.

## 2. The Timeline (Samaya-Sarni)

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

6. **Root Cause Discovery:** Realized that variables passed to `include_role` are **local** to the host execution context. When Host A (Master) tried to look up Host B (Worker) in `hostvars['HostB']`, the `include_role` variables were invisible. The role needs to see these flags in `hostvars` to determine cluster topology.

7. **Resolution:** Moved `set_fact` to `pre_tasks` section, before role inclusion. This promoted the variables to the global `hostvars` scope, making them visible across all hosts during role execution.

## 3. The Root Cause (Mula Karana)

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

## 4. The Resolution (Samadhana)

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

## 5. The Lessons & Prevention (Shiksha & Nivarana)

- **What did we learn?**
    1. **Scope Matters:** When a role needs to "look sideways" (inspect other hosts via `hostvars`), you **must** use `set_fact` in `pre_tasks` or inventory variables. Local vars, play-level vars, and `include_role` vars are invisible to neighbors.
    2. **Namespace Hygiene:** Avoid naming your configuration variables (e.g., `k3s_server` dictionary) the same as role internal variables (e.g., the `k3s_server` group name). This causes subtle collision issues.
    3. **Explicit > Implicit:** Relying on role "magic" (auto-detection) is fragile. Explicitly defining node types via facts is more robust and makes intent clear.
    4. **Timing Matters:** Facts must be set in `pre_tasks`, not in regular `tasks` after the role runs. The role sees the state of `hostvars` at the moment it executes.
    5. **Debugging Pattern:** When a role fails with "missing attribute" in `hostvars`, check:
        - Where the variable is defined (play, task, role vars?)
        - When it's set (before or after role execution?)
        - Whether it's promoted to `hostvars` (use `debug: var=hostvars[inventory_hostname]`)

- **How to prevent it in future?**
    1. **Audit Role Variables:** Before using a complex community role, check its `defaults/main.yml` for variable name collisions with your configuration dictionaries.
    2. **Prefer Facts for Cluster Logic:** Any logic that involves cluster topology (nodes knowing about other nodes) should use Facts set in `pre_tasks`.
    3. **Document Scoping Requirements:** If a playbook requires `hostvars` visibility, document this in comments with the reason why.
    4. **Test Idempotency:** Always run playbooks twice - the second run will catch issues where state isn't properly persisted in facts/inventory.

## 6. Action Items (Karya-Yojana)

- [x] Refactor `02-bootstrap-vyom.yml` to use `set_fact`.
- [x] Verify cluster bootstrap (Srishti).
- [x] Document the incident (RCA).
