# RCA-004: Proxmox 9 Provider Incompatibility

- **Date of Incident:** 2026-01-22
- **Severity:** High (Blocked all VM provisioning)
- **Status:** Resolved
- **Components:** Terraform, Proxmox, `Telmate/proxmox` provider, `bpg/proxmox` provider

## 1. The Incident (Ghatana)

- **Summary:** After successfully setting up a Proxmox 9 host and the `prakriti-template`, executing `terraform plan` for the `vyom` module failed.
- **Impact:** It was impossible to provision the K3s cluster VMs (`vyom`), blocking progress on the project infrastructure.
- **Detection:** The `terraform plan` command failed with a persistent authorization error.

## 2. The Timeline (Samaya-Sarni)

1. **Initial Failure:** `terraform plan` failed with `permissions for user/token... are not sufficient, please provide also the following permissions that are missing: [VM.Monitor]`.
2. **Diagnosis:** Research revealed that the `VM.Monitor` permission was removed in Proxmox VE 9.x. The `Telmate/proxmox` v2.9.14 provider has a hardcoded requirement for this specific, now-deprecated permission string. ([proxmox-forum](https://forum.proxmox.com/threads/proxmox-9-terraform-provider-missing-vm-monitor-permission-but-it-doesnt-exist.170212/))
3. **Pivot:** We decided to switch to the modern, community-supported `bpg/proxmox` provider, which is actively maintained for Proxmox 9 compatibility.
4. **Resolution:** The Terraform configuration was rewritten to use the `bpg/proxmox` provider and its modern, structured HCL schema.

## 3. The Root Cause (Mula Karana)

- **The "Five Whys":**  (in this case 4 whys are sufficient 😅)
  1. **Why did Terraform fail to provision VMs?** Because `terraform plan` was failing.
  2. **Why did `terraform plan` fail?** Because the `Telmate/proxmox` provider required a `VM.Monitor` permission that does not exist in Proxmox 9.
  3. **Why did the provider require it?** Because the provider's permission checks were based on older versions of Proxmox and had not been updated for the breaking changes in Proxmox 9.
  4. **Why were we using that provider?** It was the previously established standard for the project, chosen before the upgrade to Proxmox 9.

- **Technical Cause:** Fundamental technical incompatibility between an outdated Terraform provider and a newer version of the target platform (Proxmox 9).

## 4. The Resolution (Samadhana)

The final, working solution involved migrating the `vyom` module to a modern provider:

1. **Provider Migration:** Changed the source in `versions.tf` to `bpg/proxmox`.
2. **HCL Schema Update:** Rewrote `main.tf` to use the `proxmox_virtual_environment_vm` resource type and its required nested block structure (e.g., `clone`, `cpu`, `disk`, `initialization`).

## 5. The Lessons & Prevention (Shiksha & Nivarana)

- **What did we learn?**
  1. **Verify Compatibility with Major Releases:** When upgrading core infrastructure components (like a hypervisor), verify that all dependent automation providers have been updated to support the new version's API and permission model.
  2. **Trust Specific Error Messages:** The provider's error message pointing to a specific missing permission was the key to identifying the version conflict.
  3. **Prioritize Active Forks:** In fast-moving ecosystems like Proxmox, active community forks (like `bpg/proxmox`) often provide better support for bleeding-edge releases than older, original providers.

- **How to prevent it in future?**
  1. Include a compatibility check of automation tools in the pre-upgrade checklist for major platform components.
  2. Monitor the community forums and issue trackers of key providers for known issues with new platform releases.

## 6. Action Items (Karya-Yojana)

- [x] Switch `vyom` module to use the `bpg/proxmox` provider.
- [x] Update HCL syntax to match the new provider's schema.
- [ ] **Future Task:** Re-evaluate the minimal set of permissions for the `samsara_iac` role to move back from the temporary `Administrator` role.
