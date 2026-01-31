# RCA-009: Virtual Disk Provisioning Mismatch ("Ghost Disk")

**Date:** 2026-01-31<br>
**Component:** Terraform Provisioning (Vyom & Brahmaloka)<br>
**Status:** Resolved

## 1. Summary

During the provisioning of `Brahmaloka` node, the VMs repeatedly failed with **"No space left on device"** during the package installation phase (Ansible), despite Terraform being configured to provision **64GB+** disks.

The root cause was a configuration mismatch between the **Source Template** (`prakriti-template`) and the **Terraform Resource**. The template used a `scsi0` disk, while Terraform defined a `virtio0` disk. This caused Proxmox to **attach a second empty 64GB disk** instead of resizing the primary boot disk, leaving the OS trapped in the template's original 3.5GB partition.

## 2. Timeline of Events

1.  **Symptom:** Ansible failed with `write error: No space left on device` during `apt install`.
2.  **Investigation (Filesystem):** Manual SSH revealed `/` mounted on `/dev/sda1` was 100% full (2.4GB used of 2.4GB).
3.  **Investigation (Block Devices):** `lsblk` showed two disks:
    *   `sda` (3.5GB): Active boot disk (Full).
    *   `vda` (64GB): Inactive, unpartitioned disk.
4.  **Diagnosis:** Terraform was creating `vda` (virtio) because it didn't match the existing `sda` (scsi) interface of the clone.
5.  **Fix:** Updated `main.tf` in both modules to use `interface = "scsi0"`.
6.  **Verification:** After destruction and re-creation, Terraform correctly resized the primary disk, and Ansible's `growpart` task expanded the filesystem to full capacity.

## 3. Root Cause

**Primary Cause:** **Interface Mismatch.**
*   **Template Config:** `scsi0` (Standard for Linux guests in Proxmox).
*   **Terraform Config:** `virtio0` (Specified in `main.tf`).
*   **Behavior:** When cloning, if the target resource specifies a disk on a *different* bus/id than the source, Proxmox adds it as a *new* device rather than modifying the existing one.

**Contributing Factor:** **Manual Template Creation.**
The `prakriti-template` was created manually (Phase 6 of Sarga). While documented, its hardware specifics (SCSI vs Virtio) were not strictly enforced or synced with the Terraform code, leading to drift.

## 4. Resolution

1.  **Code Correction:** Temporarily updated `samsara/terraform/brahmaloka/main.tf` and `samsara/terraform/vyom/main.tf` to target `interface = "scsi0"`.
2.  **Rescue Task:** Added a robust `growpart` + `resize2fs` task in Ansible to ensure the partition table is updated immediately after boot.
3.  **Dependency Fix:** Added `make` and `build-essential` to bootstrap packages (discovered during the fix validation).

## 5. Learnings (Nidaan)

*   **Trust `lsblk`, not `main.tf`:** Despite declarative resource provisioning (e.g. with Terraform), what you *think* you provisioned isn't always what *actually* gets provisioned. Always verify block devices inside the guest when storage issues arise.
*   **Clone Semantics:** Cloning is not just copying files; it's replicating hardware definition. Terraform resource definition must match the Source Template's hardware topology to modify it in-place.
*   **The "Ghost Disk" Pattern:** If a VM runs out of space despite having a "Large Disk" in config, check if it has *two* disks—one small (boot) and one large (empty).

## 6. Prevention & Future Improvements

**1. Automate Template Creation (Packer):**
The manual creation of `prakriti-template` introduces human error and opacity. We should implement **Packer** to build the template as code. This ensures:
*   We define the disk interface (SCSI/Virtio) in code.
*   We ensure `cloud-guest-utils` (growpart) is pre-installed.
*   We eliminate the manual "Phase 6" friction.

**2. Validation Checks:**
Add a "Pre-Flight" Ansible task that asserts `disk_size > 10GB` on the root mount point. If it fails, abort early with a clear message: "Root partition too small - Resize failed?".
