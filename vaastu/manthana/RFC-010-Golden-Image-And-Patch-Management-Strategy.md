# RFC-010: Golden Image & Patch Management Strategy

**Status:** Proposed<br>
**Date:** 2026-01-19

## 1. Context

[RFC-009](./RFC-009-Vyom-Provisioning-Strategy.md) established that we will use the "Proxmox Template Cloning" method to provision VMs for the `Vyom` compute layer. This method relies on a pre-existing "golden image" template.

However, RFC-009 specified a manual, one-time creation process for this template. A manually created template will quickly become stale, containing outdated packages with potential security vulnerabilities. Furthermore, there is no defined strategy for keeping the running VMs (cloned from this template) up-to-date.

This RFC proposes a comprehensive, automated strategy for both the initial creation and the ongoing patch management of our VM images, treating the golden image itself as an artifact of an Infrastructure as Code process.

## 2. Problem Statement

We need an automated and repeatable strategy that addresses two distinct lifecycle phases:

1.  **Image Creation:** How do we create a consistent, patched, and pre-configured "golden image" template in Proxmox without error-prone manual steps?
2.  **Ongoing Maintenance:** How do we apply critical security updates to live, running VMs that were created from the template, without requiring them to be destroyed and recreated?

## 3. Proposal: The "Bake and Update" Strategy

We will adopt a two-pronged strategy that combines building immutable "golden images" with a stateful patch management system for running instances.

### 3.1. Image Creation: "Baking" with Packer and Ansible

We will treat the VM template itself as a build artifact, created programmatically using **HashiCorp Packer**.

-   **New IaC Component:** A new directory, `samsara/packer/vyom/`, will be created to house the Packer configuration files.
-   **The Workflow:**
    1.  A Packer build is triggered (e.g., `packer build .`).
    2.  Packer automatically downloads a base Ubuntu Server ISO.
    3.  Packer creates a temporary VM in Proxmox and boots it from the ISO, answering any installation prompts automatically using a "preseed" or "autoinstall" file.
    4.  Once the base OS is installed, Packer's **Ansible provisioner** connects to the running VM.
    5.  It runs a dedicated Ansible playbook (`playbooks/bake-image.yml`) which performs the "good contamination":
        -   Installs `qemu-guest-agent` for better Proxmox integration.
        -   Installs common, universal tools (`htop`, `curl`, `wget`).
        -   Runs `apt update && apt upgrade` to apply all available security patches *at the time of the image build*.
    6.  After the Ansible playbook succeeds, Packer shuts down the VM, converts it into a Proxmox template (e.g., `ubuntu-2404-k3s-base-v1.0.0`), and cleans up the temporary build resources.

-   **Benefits:**
    -   **Fully Automated:** The entire "golden image" creation process is defined in code and is 100% repeatable.
    -   **Versioning:** The template name will include a version (`-v1.0.0`), allowing us to have multiple template versions and stage rollouts safely.
    -   **Reduced Ansible Time:** By pre-installing common packages, the Ansible run time for provisioning a *new K3s node* is reduced, as it doesn't have to perform these base setup tasks.

### 3.2. Ongoing Maintenance: Scheduled Patching with Ansible

For live VMs that are already running, we need a way to apply security patches without destroying them.

-   **Proposal:** We will create a dedicated Ansible playbook (`playbooks/maintenance-upgrade.yml`) and run it on a schedule using `cron`.
-   **Orchestration:** The `cron` job will be managed on the **`Brahmaloka-Runner`** VM, as this is our central orchestration point.
-   **The Playbook's Job:**
    1.  **Target:** The playbook will target all hosts in the `vyom` and `brahmaloka` groups.
    2.  **Action:** It will use the `ansible.builtin.apt` module to perform an upgrade. For Kubernetes nodes, it's crucial to avoid kernel upgrades that would require a reboot.
        ```yaml
        - name: Apply security updates without rebooting
          ansible.builtin.apt:
            upgrade: dist
            update_cache: yes
        ```
    3.  **Safety:** The playbook can be enhanced with logic to only perform upgrades at certain times or to perform rolling upgrades across the cluster to maintain availability.

## 4. Impact

-   **New Tool:** Introduces Packer into the project's technology stack.
-   **New IaC Directory:** `samsara/packer/vyom/` will be created.
-   **New Ansible Playbooks:** Requires `bake-image.yml` for Packer and `maintenance-upgrade.yml` for the cron job.
-   **Update to `001-Sarga.md`:** The manual instructions for creating a template will be replaced with instructions on how to install Packer and run the `packer build` command.
-   **Update to `003-Visarga.md`:** A new operational procedure for scheduling and managing the maintenance playbook will be added.
-   **Update to `RFC-009`:** A reference to this RFC will be added to clarify how the template prerequisite is fulfilled.

## 5. Conclusion

This "Bake and Update" strategy provides a complete, professional solution for the entire lifecycle of a virtual machine image.

1.  **Bake (Packer + Ansible):** We create versioned, patched, and fully reproducible "golden images" using Infrastructure as Code.
2.  **Update (Ansible + Cron):** We maintain the security posture of long-running VMs by applying patches in a controlled, stateful manner.

This approach treats the VM template not as a manual prerequisite, but as a version-controlled artifact, fully embracing the "Weapon of Detachment" philosophy.
