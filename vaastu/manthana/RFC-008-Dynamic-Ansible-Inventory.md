# **RFC-008: Dynamic Inventory & Authentication Strategy**

**Status:** Proposed<br>
**Date:** 2026-01-11 (Amended from 2026-01-09)<br>
**Enhances:** ADR-003: Hybrid Secret Management Strategy<br>

## **1\. Context**

Project Brahmanda faces a **"Data Island"** problem. Terraform knows the state of the universe (IP addresses, metadata), but Ansible, responsible for configuring it, is blind to this state until a human manually updates a static `hosts.yml` file.

Additionally, Ansible requires SSH authentication to these hosts. Since we strictly avoid storing private keys on disk (using 1Password instead), we need a secure mechanism to inject these credentials into Ansible at runtime.

## **2\. Problem Statement**

1. **Inventory Drift:** Manual copy-pasting of IPs from terraform output to hosts.yml is error-prone and breaks the "Samsara" automation cycle.
2. **Authentication Friction:** Ansible needs a private key file. Passing keys via environment variables is flaky in Ansible, and storing them permanently on disk violates our security posture.

## **3\. Inventory Strategy (Discovery)**

### **Option A: Terraform-Generated Static Inventory (Rejected)**

Terraform uses a `local_file` resource to render a `hosts.ini` template after creation.

* **Pros:** Simple, visual artifact.
* **Cons:** Tightly couples modules. If Terraform state changes (e.g., via a different machine), the local file might be stale.
* **Verdict:** Rejected. Creates "state drift" risk.

### **Option B: Ansible Native Cloud Plugins (Rejected)**

Using `aws_ec2` or `community.general.proxmox` inventory plugins to query APIs directly.

* **Pros:** "The Ansible Way."
* **Cons:** Requires Ansible to have its own set of Cloud Credentials (duplication). It ignores the "Plan" that Terraform just executed. It queries *reality*, which might differ from *intent* during convergence.
* **Verdict:** Rejected. Terraform State is our Single Source of Truth.

### **Option C: State-Driven Dynamic Discovery (Accepted)**

A custom script (`scripts/inventory_discovery.py`) parses the `terraform.tfstate` file (locally or from Cloudflare R2).

* **Workflow:** `ansible-playbook -i scripts/inventory_discovery.py ...`
* **Pros:**
  * **SSOT:** Reads exactly what Terraform just provisioned.
  * **Zero-Auth:** The script doesn't need AWS/Proxmox credentials, just read access to the State file.
* **Verdict:** **Accepted.** This aligns perfectly with the **"Asanga"** (Detachment) philosophy.

## **4\. Authentication Strategy (The Scepter)**

How do we securely pass the SSH Private Key from 1Password to Ansible?

### **Option A: SSH Agent Forwarding (Rejected)**

We load the key into the developer's local ssh-agent before running Ansible.

* **Pros:** Secure, in-memory only.
* **Cons:** Hard to replicate deterministically in CI/CD (GitHub Actions) without complex plugins. Fails if the agent socket isn't forwarded correctly in WSL.
* **Verdict:** Rejected for lack of portability.

### **Option B: Ephemeral Key File (Accepted)**

We use the Makefile as a wrapper to materialize the key briefly.

**The Workflow:**

1. **Materialize:** make fetches the key from 1Password \-\> writes to `/tmp/brahmanda_key`.
2. **Secure:** make runs chmod 600 `/tmp/brahmanda_key`.
3. **Execute:** make runs `ansible-playbook --private-key /tmp/brahmanda_key ....`
4. **Dissolve:** make ensures (trap) the key is deleted immediately after execution, regardless of success or failure.

* **Pros:**
  * **Deterministic:** Works identically on Mac, Linux, and GitHub Actions runners.
  * **Secure:** Key exists on disk for milliseconds/seconds, restricted to the user.
* **Verdict:** **Accepted.** This is the "Temporary Scepter."

## **5\. Implementation Plan**

### **Dynamic Inventory Script Specification**

The Python script must:

1. Locate the Terraform State (local .tfstate or R2 bucket).
2. Parse resources looking for `aws_lightsail_instance` (Kshitiz) and `proxmox_vm_qemu` (Vyom).
3. Map Terraform tags to Ansible groups.
   * Tag: Role=Lighthouse \-\> Group: kshitiz
   * Tag: Role=Worker \-\> Group: vyom
4. Output JSON in the standard Ansible Inventory format.

### **Makefile Integration**

The srishti command will be updated to orchestrate this flow.

```yaml
# Pseudo-code for the new Srishti flow
srishti:
    # 1. Provision
    terraform apply

    # 2. Authenticate (Get Key from 1Password)
    op read "op://.../private-key" > /tmp/brahmanda_key
    chmod 600 /tmp/brahmanda_key

    # 3. Configure (Dynamic Inventory + Ephemeral Key)
    ansible-playbook -i scripts/inventory.py hosts.yml --private-key /tmp/brahmanda_key

    # 4. Cleanup
    rm /tmp/brahmanda_key
```

## **6\. Conclusion**

By treating Terraform State as the map and the Ephemeral Key as the key, we close the loop on automation. The system requires no manual handoff between creation (Terraform) and configuration (Ansible).
