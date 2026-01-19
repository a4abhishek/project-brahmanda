# **RFC-008: Dynamic Inventory & Authentication Strategy**

**Status:** Accepteed<br>
**Date:** 2026-01-12 (Amended from 2026-01-11)<br>
**Enhances:** ADR-003: Hybrid Secret Management Strategy<br>

## **1\. Context**

Project Brahmanda faces a **"Data Island"** problem. Terraform knows the state of the universe (IP addresses, metadata), but Ansible, responsible for configuring it, is blind to this state until a human manually updates a static `hosts.yml` file.

Additionally, Ansible requires SSH authentication to these hosts. Since we strictly avoid storing private keys on disk (using 1Password instead), we need a secure mechanism to inject these credentials into Ansible at runtime.

## **2\. Problem Statement**

1. **Inventory Drift:** Manual copy-pasting of IPs from terraform output to hosts.yml is error-prone and breaks the "Samsara" automation cycle.
2. **Authentication Friction:** Ansible needs a private key file. Passing keys via environment variables is flaky in Ansible, and storing them permanently on disk violates our security posture.
3. **Security Coupling (New):** Allowing configuration scripts to parse the raw Terraform State file grants them excessive privilege. The state file may contain sensitive data (initial passwords, keys) that the inventory script does not need.

## **3\. Inventory Strategy (Discovery)**

### **Option A: Terraform-Generated Static Inventory (Rejected)**

Terraform uses a `local_file` resource to render a `hosts.ini` template after creation.

* **Pros:** Simple, visual artifact.
* **Cons:** Tightly couples modules. If Terraform state changes (e.g., via a different machine), the local file might be stale.
* **Verdict:** Rejected. Creates "state drift" risk if the file is edited or deleted manually.

### **Option B: Ansible Native Cloud Plugins (Rejected)**

Using `aws_ec2` or `community.general.proxmox` inventory plugins to query APIs directly.

* **Pros:** "The Ansible Way."
* **Cons:** Requires Ansible to have its own set of Cloud Credentials (duplication). It ignores the "Plan" that Terraform just executed. It queries *reality*, which might differ from *intent* during convergence.
* **Verdict:** Rejected. Terraform State is our Single Source of Truth; querying APIs ignores the specific "Plan" we just executed.

### **Option C: State-Driven Dynamic Discovery (Superseded)**

A custom script parses the raw `terraform.tfstate` file (locally or from Cloudflare R2).

* **Pros:** SSOT (Single Source of Truth).
* **Cons:** **Security Risk.** The script requires read access to the entire state file, violating the **Principle of Least Privilege**. It is also tightly coupled to the internal structure of Terraform state, which may change.
* **Verdict:** **Superseded** by Option D.

### **Option D: The Terraform Manifest Adapter (Accepted)**

Terraform explicitly exports a sanitized, purpose-built JSON file (manifest.json) containing *only* the public interface information (IPs, Hostnames, Roles) required by downstream tools.

* **Workflow:**
  1. **Terraform:** A `local_file` resource uses `jsonencode()` to write `samsara/inventory/manifest.json` after a successful apply.
  2. **Ansible:** The dynamic inventory script reads *only* this `manifest.json`.
* **Pros:**
  * **Security (Least Privilege):** The inventory script never sees sensitive state data.
  * **Decoupling:** The script relies on a stable, defined JSON schema (the "Adapter"), not the complex internal Terraform state structure.
  * **Artifact-Based:** The `manifest.json` becomes a build artifact of the Provisioning phase, clearly handing off responsibility to the Configuration phase.
* **Verdict:** **Accepted.** This pattern provides the cleanest architectural boundary between Srishti (Creation) and Samsara (Configuration).

## **4\. Authentication Strategy (The Scepter)**

How do we securely pass the SSH Private Key from 1Password to Ansible?

### **Option A: SSH Agent Forwarding (Rejected)**

We load the key into the developer's local ssh-agent before running Ansible.

* **Pros:** Secure, in-memory only.
* **Cons:** Hard to replicate deterministically in CI/CD (GitHub Actions) without complex plugins. Fails if the agent socket isn't forwarded correctly in WSL.
* **Verdict:** Rejected for lack of determinism in CI/CD.

### **Option B: Ephemeral Key File (Accepted)**

We use the Makefile as a wrapper to materialize the key briefly.

**The Workflow:**

1. **Materialize:** make fetches the key from 1Password \-\> writes to `/tmp/brahmanda_key`.
2. **Secure:** make runs `chmod 600 /tmp/brahmanda_key`.
3. **Execute:** make runs `ansible-playbook --private-key /tmp/brahmanda_key ...`
4. **Dissolve:** make ensures (trap) the key is deleted immediately after execution, regardless of success or failure.

* **Pros:**
  * **Deterministic:** Works identically on Mac, Linux, and GitHub Actions runners.
  * **Secure:** Key exists on disk for milliseconds/seconds, restricted to the user.
* **Verdict:** **Accepted.** This is the "Temporary Scepter."

## **5\. Implementation Plan**

### **The Manifest Adapter Specification**

Terraform will output a file at `samsara/inventory/manifest.json` with the following schema:

```json
{
  "kshitiz": {
    "public_ip": "1.2.3.4",
    "private_ip": "10.100.0.1",
    "role": "lighthouse"
  },
  "vyom": [
    {
      "name": "node-01",
      "ip": "192.168.68.200",
      "role": "control-plane"
    }
  ]
}
```

### **Dynamic Inventory Script Specification**

The Python script (`scripts/inventory_discovery.py`) will:

1. Read `samsara/inventory/manifest.json`.
2. Map the JSON keys to Ansible Groups (kshitiz, vyom).
3. Output the standard Ansible JSON inventory format.

### **Makefile Integration**

The srishti command orchestrates the flow:

```yaml
# Pseudo-code for the new Srishti flow
srishti:
    # 1. Provision & Generate Manifest
    terraform apply

    # 2. Authenticate (Get Key from 1Password)
    op read "op://.../private-key" > /tmp/brahmanda_key
    chmod 600 /tmp/brahmanda_key

    # 3. Configure (Read Manifest + Use Ephemeral Key)
    ansible-playbook -i scripts/inventory_discovery.py site.yml --private-key /tmp/brahmanda_key

    # 4. Cleanup
    rm /tmp/brahmanda_key
```

### **Phase 2: Decoupled CI/CD Architecture (Future)**

To prepare for a professional CI/CD pipeline, the "single manifest" approach will be evolved to a fully artifact-based workflow. This decouples the tools from the source code layout.

1. **Neutral Artifact Directory:** A dedicated, Git-ignored directory (e.g., `.cache/manifests`) will be established to act as a "mailbox" between CI jobs.

2. **Terraform as Producer:** Each Terraform module (`kshitiz`, `vyom`) will be responsible for producing its own uniquely named manifest file in the artifact directory.
    * `terraform apply` in the `kshitiz` module creates `.cache/manifests/kshitiz.manifest.json`.
    * `terraform apply` in the `vyom` module creates `.cache/manifests/vyom.manifest.json`.

3. **Ansible as Consumer:** The dynamic inventory script will be enhanced:
    * It will no longer have a hardcoded path to the manifest.
    * It will read a directory path from an environment variable (e.g., `BRAHMANDA_MANIFEST_PATH`).
    * It will scan this directory for all `*.json` files and merge them to build the final inventory.

4. **CI/CD Workflow:**
    * **Stage 1 (Provision):** Run Terraform jobs, which save their respective `*.manifest.json` files as pipeline artifacts.
    * **Stage 2 (Configure):** Start an Ansible job, download all manifest artifacts into a local directory, set the `BRAHMANDA_MANIFEST_PATH` variable to point to this directory, and then execute the playbook.

This phased approach allows for initial implementation simplicity while paving a clear, robust path toward a scalable and decoupled automation architecture.

## **6\. Conclusion**

We have refined our approach from "State Parsing" to the **"Manifest Adapter"** pattern. This churn (*Manthana*) has resulted in a superior architecture that respects security boundaries and creates a clear, stable contract between Terraform and Ansible.
