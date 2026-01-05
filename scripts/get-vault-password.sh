#!/usr/bin/env bash
#
# get-vault-password.sh - Retrieve Ansible Vault password from 1Password
#
# This script is called by ansible-vault as a password source.
# Usage: ansible-vault ... --vault-password-file=scripts/get-vault-password.sh
#

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly VAULT_REF="op://Project-Brahmanda/Ansible Vault - Samsara/password"

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Retrieve and output password (no additional output allowed)
op read "$VAULT_REF" 2>/dev/null || {
  echo "ERROR: Failed to retrieve Ansible Vault password from 1Password" >&2
  echo "ERROR: Ensure 1Password CLI is authenticated: eval \$(op signin)" >&2
  exit 1
}
