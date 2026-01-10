# RCA-002: Ansible Configuration & Secret Injection Failures

**Date:** January 10, 2026
**Status:** Resolved
**Components:** Ansible, Makefile, 1Password CLI, WSL

## 1. Invalid 1Password References in Comments

### Problem

`op inject` failed with errors such as:
`invalid secret reference 'op://': too few '/': secret references should have at least vault, item and field specified`.

### Root Cause

**Global Pattern Matching:** The `op inject` command scans the entire input file for the `op://` prefix, including text inside comments. Our `vault.tpl.yml` contained headers with example references (e.g., `# This template uses 1Password secret references (op://)`). `op inject` attempted to resolve these partial or illustrative strings as active secrets, leading to validation failures.

### Solution

**Selective Resolution:** By replacing `op inject` with the `inject-secrets.py` script, we moved to a YAML-aware approach. The script only processes strings that are actual **YAML values**. Because the YAML parser ignores comments, these illustrative strings are no longer processed, preventing resolution errors.

## 2. Ansible Configuration Ignored in WSL

### Problem

When running Ansible commands (e.g., `ansible kshitiz -m ping`) from the Windows Subsystem for Linux (WSL), the command failed to detect any hosts.

```
[WARNING]: Ansible is being run in a world writable directory ... ignoring it as an ansible.cfg source.
[WARNING]: provided hosts list is empty
```

### Root Cause

**World-Writable Permissions:** The project directory is located on a Windows mount (`/mnt/c/...`). By default, WSL mounts Windows drives with 777 permissions (world-writable). Ansible considers this a security risk because a malicious user could modify `ansible.cfg` to inject dangerous settings. Consequently, Ansible silently ignored the local configuration file and fell back to defaults, failing to find the inventory.

### Solution

**Explicit Configuration Path:**
We bypassed the security check by explicitly setting the `ANSIBLE_CONFIG` environment variable in the `Makefile`.

```makefile
# Makefile
export ANSIBLE_CONFIG := $(CURDIR)/samsara/ansible/ansible.cfg
ANSIBLE_ENV := ANSIBLE_CONFIG=$(ANSIBLE_CONFIG)

# Usage in targets
target:
    $(ANSIBLE_ENV) ansible-playbook ...
```

This forces Ansible to use the specified configuration file regardless of directory permissions.

---

## 2. Invalid YAML from `op inject`

### Problem

The `make nidhi-tirodhana` command, intended to generate an encrypted Ansible Vault, produced invalid YAML. The error occurred during the parsing of the generated `vault.yml` file.

```
Syntax Error while loading YAML.
could not find expected ':'
```

### Root Cause

**Naive Text Injection:** The original workflow used `op inject` to replace references (e.g., `op://...`) with secrets.

1. **Multiline Secrets:** Secrets like SSH private keys and Certificates span multiple lines.
2. **Indentation Mismatch:** `op inject` inserts the raw secret text exactly where the token is found. For YAML, subsequent lines of a multiline string must be indented relative to the parent key. `op inject` does not handle this indentation, causing the second line of the key to appear as a new (invalid) YAML token at the root level.

**Example of failure:**

```yaml
# vault.tpl.yml
key: op://vault/item/field

# Generated (Invalid)
key: -----BEGIN PRIVATE KEY-----
MII...  <-- This line breaks YAML because it has no indentation
```

### Solution

**Scripted Injection with PyYAML:**
We replaced `op inject` with a custom Python script (`scripts/inject-secrets.py`) that understands YAML structure.

1. **Logic:** The script parses the template as YAML, finds value strings starting with `op://`, fetches the secret using `op read`, and then inserts the value back into the data structure.
2. **Output:** It dumps the data using `PyYAML`, which automatically handles multiline strings by using Block Scalars (`|`) and correct indentation.

**New Workflow:**

```makefile
# Makefile
nidhi-tirodhana: install-python-requirements
    .venv/bin/python3 scripts/inject-secrets.py input.tpl.yml output.tmp.yml
    ansible-vault encrypt output.tmp.yml ...
```

This ensures that `vault.yml` is always syntactically valid, regardless of the secret's content.
