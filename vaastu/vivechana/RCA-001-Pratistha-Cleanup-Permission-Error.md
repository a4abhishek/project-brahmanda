# RCA-001: Pratistha Cleanup Permission Error

**Date:** January 5, 2026  
**Severity:** Medium (script fails, but USB creation succeeded)  
**Status:** Resolved

## Incident Summary

The `make pratistha` command failed at the cleanup stage with:
```
rm: cannot remove '/tmp/proxmox-auto-9.1-1.iso': Operation not permitted
make: *** [Makefile:176: pratistha] Error 1
```

This occurred even though the USB drive was successfully created and written.

## Context

The `pratistha-proxmox.sh` script creates a bootable Proxmox USB drive through these steps:
1. Validate inputs and prerequisites
2. Generate answer file with secrets
3. Create auto-install ISO using `proxmox-auto-install-assistant`
4. Write ISO to USB device
5. Verify USB device
6. **Cleanup temporary files** ← Failed here

## What Went Wrong

### Root Cause

The temporary ISO file was created by `proxmox-auto-install-assistant` running with `sudo`:
```bash
sudo proxmox-auto-install-assistant prepare-iso \
  "$ISO_PATH" \
  --fetch-from iso \
  --answer-file "$OUTPUT_FILE" \
  --output "$TMP_ISO"
```

This caused the file `/tmp/proxmox-auto-9.1-1.iso` to be owned by `root`.

The cleanup function attempted to remove this file without `sudo`:
```bash
cleanup_temp_files() {
  info "Cleaning up..."
  rm -f "$TMP_ISO"  # ← Fails: Operation not permitted
}
```

Since the file was root-owned, a regular `rm` command failed with "Operation not permitted".

### Why It Wasn't Caught Earlier

- The script worked correctly for file creation and USB writing (both used `sudo`)
- Cleanup was an afterthought and wasn't tested thoroughly
- The `-f` flag on `rm` suppressed some errors but not permission errors for existing files
- The script used `set -e`, so the failed `rm` command caused script exit

## Impact

**User Impact:**
- Script reported failure even though USB creation succeeded
- Temporary ISO file left behind in `/tmp/` (minor - would be cleaned on reboot)
- User had to investigate false-negative failure

**System Impact:**
- None (USB was successfully created)
- Minor disk space usage until reboot

## Solution

### Immediate Fix

Modified `cleanup_temp_files()` to use `sudo` for removing root-owned files:

```bash
# Cleanup temporary files
cleanup_temp_files() {
  info "Cleaning up..."
  
  # ISO was created with sudo, so need sudo to remove it
  if [[ -f "$TMP_ISO" ]]; then
    sudo rm -f "$TMP_ISO"
  fi
}
```

**Why this works:**
- Checks if file exists before attempting removal
- Uses `sudo` to match the privilege level used during creation
- Gracefully handles case where file doesn't exist (no error)

### Verification

```bash
# Before fix
$ make pratistha ...
rm: cannot remove '/tmp/proxmox-auto-9.1-1.iso': Operation not permitted
make: *** [Makefile:176: pratistha] Error 1

# After fix
$ make pratistha ...
✅ SUCCESS: Pratistha complete!
```

## Prevention

### Pattern Identified

**General Rule:** When creating files with elevated privileges, cleanup must also use elevated privileges.

**Apply to:**
- Any script that uses `sudo` to create files in temporary locations
- Any script with a cleanup function that removes sudo-created files

### Improvements Made

1. **Explicit sudo in cleanup:** Don't rely on `-f` flag to suppress permission errors
2. **Existence check:** Verify file exists before attempting removal
3. **Comment explanation:** Document why sudo is needed for future maintainers

### Related Code Review Needed

Check other scripts for similar patterns:
- `initialize-linux.sh` - Downloads and installs .deb with sudo
- `initialize-macos.sh` - Creates files with sudo in /usr/local/bin

**Action:** Review whether these scripts have cleanup functions that might face similar issues.

## Lessons Learned

1. **Test the entire flow:** Don't just test the "happy path" - test cleanup and error paths too
2. **Match privilege levels:** If you create with `sudo`, clean up with `sudo`
3. **Explicit is better than implicit:** Don't rely on flags like `-f` to hide permission issues
4. **Check file existence:** Before operations on files that might not exist
5. **Early detection:** The pre-commit hook catches syntax errors, but logic errors require runtime testing

## References

- Script: [scripts/pratistha-proxmox.sh](../../scripts/pratistha-proxmox.sh)
- Fix Commit: (to be added when committed)
- Related Pattern: "Privilege Escalation Must Be Consistent" in Learning-Bash-Script-Patterns.md

---

**Resolution Time:** 5 minutes  
**Fix Applied:** January 5, 2026  
**Verified:** Yes
