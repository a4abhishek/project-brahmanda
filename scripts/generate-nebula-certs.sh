#!/usr/bin/env bash
#
# generate-nebula-certs.sh - Nebula Certificate Generation & 1Password Storage
#
# This script generates Nebula mesh certificates for the Brahmanda infrastructure:
#   - Kshitiz Lighthouse (10.100.0.1/16) - Edge gateway and Nebula coordinator
#   - Vyom Control Plane nodes (10.100.1.210+) - K3s control plane with consistent IPs
#   - Vyom Worker nodes (continuing from control plane) - K3s workers
#
# All certificates are stored in 1Password with metadata (nebula_ip, vm_id, lan_ip).
# The script is idempotent - rerunning skips already-existing certificates.
#
# Usage:
#   ./generate-nebula-certs.sh \
#     [--control-plane-count 1] \
#     [--worker-count 2] \
#     [--skip-kshitiz] \
#     [--force]
#
# Examples:
#   # Generate lighthouse + 1 control plane + 2 workers (default)
#   ./generate-nebula-certs.sh
#
#   # Scale to 3 control planes and 5 workers
#   ./generate-nebula-certs.sh --control-plane-count 3 --worker-count 5
#
#   # Regenerate only Vyom nodes (skip lighthouse)
#   ./generate-nebula-certs.sh --skip-kshitiz
#
#   # Force cleanup of stale certificate files from interrupted runs
#   ./generate-nebula-certs.sh --force
#

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly NEBULA_VERSION="1.10.0"
readonly NEBULA_DIR="${HOME}/.nebula"
readonly OP_VAULT="Project-Brahmanda"
readonly VYOM_IP_START=210  # First Vyom node gets .210

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

CONTROL_PLANE_COUNT=1
WORKER_COUNT=2
SKIP_KSHITIZ=false
FORCE=false

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Print error message and exit
# Arguments:
#   $1 - Error message
die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Print info message
# Arguments:
#   $1 - Info message
info() {
  echo "$*"
}

# Print success message
# Arguments:
#   $1 - Success message
success() {
  echo "✅ $*"
}

# Print warning message
# Arguments:
#   $1 - Warning message
warn() {
  echo "⚠️  WARNING: $*"
}

# Check if command exists
# Arguments:
#   $1 - Command name
command_exists() {
  command -v "$1" &>/dev/null
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --control-plane-count)
        CONTROL_PLANE_COUNT="$2"
        shift 2
        ;;
      --worker-count)
        WORKER_COUNT="$2"
        shift 2
        ;;
      --skip-kshitiz)
        SKIP_KSHITIZ=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      -h|--help)
        cat <<EOF
Usage: $0 [OPTIONS]

Generate Nebula mesh certificates for Brahmanda infrastructure.

Options:
  --control-plane-count N    Number of control plane nodes (default: 1)
  --worker-count N           Number of worker nodes (default: 2)
  --skip-kshitiz             Skip Kshitiz lighthouse generation
  --force                    Force cleanup of stale certificate files
  -h, --help                 Show this help message

Examples:
  $0
  $0 --control-plane-count 3 --worker-count 5
  $0 --skip-kshitiz
  $0 --force  # Clean up stale files from interrupted runs

EOF
        exit 0
        ;;
      *)
        die "Unknown option: $1. Use --help for usage information."
        ;;
    esac
  done
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

# Check prerequisites (nebula-cert, 1Password CLI, authentication)
check_prerequisites() {
  info "Checking prerequisites..."

  # Check nebula-cert binary
  command_exists nebula-cert || \
    die "nebula-cert not found. Install from: https://github.com/slackhq/nebula/releases/tag/${NEBULA_VERSION}"

  # Verify nebula-cert version
  local installed_version
  installed_version=$(nebula-cert --version 2>&1 | grep -oP 'Version: \K[\d.]+' || echo "unknown")
  if [[ "${installed_version}" != "${NEBULA_VERSION}" ]]; then
    warn "nebula-cert version mismatch. Expected: ${NEBULA_VERSION}, Found: ${installed_version}"
    warn "Certificates generated with different versions may be incompatible (see RCA-007)"
  fi

  # Check 1Password CLI
  command_exists op || \
    die "1Password CLI (op) not found. Install from: https://developer.1password.com/docs/cli/get-started/"

  # Verify 1Password authentication
  op vault list &>/dev/null || \
    die "Not authenticated to 1Password. Run: eval \$(op signin)"

  # Create Nebula directory
  mkdir -p "${NEBULA_DIR}"

  success "Prerequisites verified"
}

# ============================================================================
# CERTIFICATE GENERATION FUNCTIONS
# ============================================================================

# Manage CA certificate (download from 1Password or generate new)
manage_ca_certificate() {
  info "Checking Nebula CA certificate..."

  if op item get "Nebula-CA-Root-Certificate" --vault "${OP_VAULT}" &>/dev/null; then
    info "CA certificate found in 1Password"

    # Download CA from 1Password if not in local directory
    if [[ ! -f "${NEBULA_DIR}/ca.crt" ]] || [[ ! -f "${NEBULA_DIR}/ca.key" ]]; then
      info "Downloading CA from 1Password..."
      op read "op://${OP_VAULT}/Nebula-CA-Root-Certificate/ca.crt" > "${NEBULA_DIR}/ca.crt"
      op read "op://${OP_VAULT}/Nebula-CA-Root-Certificate/ca.key" > "${NEBULA_DIR}/ca.key"
      chmod 600 "${NEBULA_DIR}/ca.key"
      success "CA downloaded from 1Password"
    else
      success "CA already exists locally"
    fi
  else
    info "Generating new Nebula CA certificate..."
    cd "${NEBULA_DIR}"
    nebula-cert ca -name "Brahmanda" -duration 87600h

    info "Storing CA in 1Password..."
    op item create \
      --category "Secure Note" \
      --title "Nebula-CA-Root-Certificate" \
      --vault "${OP_VAULT}" \
      "add more.ca\\.crt[text]=$(cat "${NEBULA_DIR}/ca.crt")" \
      "add more.ca\\.key[text]=$(cat "${NEBULA_DIR}/ca.key")" \
      >/dev/null

    success "CA generated and stored in 1Password"
  fi
}

# Generate Kshitiz Lighthouse certificate (10.100.0.1/16)
# This is the Nebula coordinator on the AWS Lightsail edge gateway
generate_kshitiz_lighthouse() {
  local node_name="kshitiz-lighthouse"
  local nebula_ip="10.100.0.1"
  local op_item_name="Nebula-Kshitiz-Lighthouse-Certificate"

  info "Generating Kshitiz Lighthouse certificate..."

  # Check if certificate already exists in 1Password
  if op item get "${op_item_name}" --vault "${OP_VAULT}" &>/dev/null; then
    success "  ⏭  Kshitiz Lighthouse (${nebula_ip}) - already exists in 1Password"
    return 0
  fi

  info "  🔐 Generating certificate for ${node_name} (${nebula_ip})..."
  cd "${NEBULA_DIR}"

  # Check for stale certificate files from interrupted runs
  if [[ -f "${node_name}.crt" ]] || [[ -f "${node_name}.key" ]]; then
    if [[ "${FORCE}" == "false" ]]; then
      die "Stale certificate files found: ${node_name}.crt/.key. This indicates a previous interrupted run. Inspect these files, then re-run with --force to clean up and proceed."
    fi
    warn "Removing stale certificate files (--force specified)"
    rm -f "${node_name}.crt" "${node_name}.key"
  fi

  nebula-cert sign \
    -name "${node_name}" \
    -ip "${nebula_ip}/16" \
    -groups "kshitiz" \
    -ca-crt ca.crt \
    -ca-key ca.key

  # Store in 1Password (cleanup on failure)
  if ! op item create \
    --category "Secure Note" \
    --title "${op_item_name}" \
    --vault "${OP_VAULT}" \
    "add more.${node_name}\\.crt[text]=$(cat "${NEBULA_DIR}/${node_name}.crt")" \
    "add more.${node_name}\\.key[text]=$(cat "${NEBULA_DIR}/${node_name}.key")" \
    "add more.nebula_ip[text]=${nebula_ip}" \
    "add more.lighthouse[text]=true" \
    >/dev/null 2>&1; then
    warn "  ⚠️  Failed to store certificate in 1Password"
    rm -f "${NEBULA_DIR}/${node_name}.crt" "${NEBULA_DIR}/${node_name}.key"
    die "Certificate storage failed. Ensure you have write access to 1Password vault '${OP_VAULT}'"
  fi

  # Clean up local certificates (now stored in 1Password)
  rm -f "${NEBULA_DIR}/${node_name}.crt" "${NEBULA_DIR}/${node_name}.key"

  success "  ✓ Kshitiz Lighthouse (${nebula_ip}) - generated and stored"
}

# Generate Vyom Control Plane certificates
# Starting at 10.100.1.210 (VM ID 210), incrementing by node index
# Arguments:
#   $1 - Number of control plane nodes
generate_vyom_control_planes() {
  local count=$1
  info "Generating Vyom Control Plane certificates (count: ${count})..."

  for i in $(seq 1 "${count}"); do
    local node_id=$((VYOM_IP_START + i - 1))
    local node_name="vyom-control-plane-${i}"
    local nebula_ip="10.100.1.${node_id}"
    local op_item_name="Nebula-Vyom-Control-Plane-${i}-Certificate"

    # Check if certificate already exists in 1Password
    if op item get "${op_item_name}" --vault "${OP_VAULT}" &>/dev/null; then
      success "  ⏭  Control Plane ${i} (${nebula_ip}) - already exists in 1Password"
      continue
    fi

    info "  🔐 Generating certificate for ${node_name} (${nebula_ip})..."
    cd "${NEBULA_DIR}"

    # Check for stale certificate files from interrupted runs
    if [[ -f "${node_name}.crt" ]] || [[ -f "${node_name}.key" ]]; then
      if [[ "${FORCE}" == "false" ]]; then
        die "Stale certificate files found: ${node_name}.crt/.key. This indicates a previous interrupted run. Inspect these files, then re-run with --force to clean up and proceed."
      fi
      warn "Removing stale certificate files (--force specified)"
      rm -f "${node_name}.crt" "${node_name}.key"
    fi

    nebula-cert sign \
      -name "${node_name}" \
      -ip "${nebula_ip}/16" \
      -groups "vyom,vyom-control-plane" \
      -ca-crt ca.crt \
      -ca-key ca.key

    # Store in 1Password (cleanup on failure)
    if ! op item create \
      --category "Secure Note" \
      --title "${op_item_name}" \
      --vault "${OP_VAULT}" \
      "add more.${node_name}\\.crt[text]=$(cat "${NEBULA_DIR}/${node_name}.crt")" \
      "add more.${node_name}\\.key[text]=$(cat "${NEBULA_DIR}/${node_name}.key")" \
      "add more.nebula_ip[text]=${nebula_ip}" \
      "add more.vm_id[text]=${node_id}" \
      "add more.lan_ip[text]=192.168.68.${node_id}" \
      >/dev/null 2>&1; then
      warn "  ⚠️  Failed to store certificate in 1Password"
      rm -f "${NEBULA_DIR}/${node_name}.crt" "${NEBULA_DIR}/${node_name}.key"
      die "Certificate storage failed. Ensure you have write access to 1Password vault '${OP_VAULT}'"
    fi

    # Clean up local certificates (now stored in 1Password)
    rm -f "${NEBULA_DIR}/${node_name}.crt" "${NEBULA_DIR}/${node_name}.key"

    success "  ✓ Control Plane ${i} (${nebula_ip}) - generated and stored"
  done
}

# Generate Vyom Worker certificates
# Continuing from control plane (e.g., 10.100.1.211 if 1 control plane)
# Arguments:
#   $1 - Number of worker nodes
#   $2 - Control plane count (to calculate starting IP)
generate_vyom_workers() {
  local count=$1
  local cp_count=$2
  local worker_start=$((VYOM_IP_START + cp_count))

  info "Generating Vyom Worker certificates (count: ${count})..."

  for i in $(seq 1 "${count}"); do
    local node_id=$((worker_start + i - 1))
    local node_name="vyom-worker-${i}"
    local nebula_ip="10.100.1.${node_id}"
    local op_item_name="Nebula-Vyom-Worker-${i}-Certificate"

    # Check if certificate already exists in 1Password
    if op item get "${op_item_name}" --vault "${OP_VAULT}" &>/dev/null; then
      success "  ⏭  Worker ${i} (${nebula_ip}) - already exists in 1Password"
      continue
    fi

    info "  🔐 Generating certificate for ${node_name} (${nebula_ip})..."
    cd "${NEBULA_DIR}"

    # Check for stale certificate files from interrupted runs
    if [[ -f "${node_name}.crt" ]] || [[ -f "${node_name}.key" ]]; then
      if [[ "${FORCE}" == "false" ]]; then
        die "Stale certificate files found: ${node_name}.crt/.key. This indicates a previous interrupted run. Inspect these files, then re-run with --force to clean up and proceed."
      fi
      warn "Removing stale certificate files (--force specified)"
      rm -f "${node_name}.crt" "${node_name}.key"
    fi

    nebula-cert sign \
      -name "${node_name}" \
      -ip "${nebula_ip}/16" \
      -groups "vyom,vyom-worker" \
      -ca-crt ca.crt \
      -ca-key ca.key

    # Store in 1Password (cleanup on failure)
    if ! op item create \
      --category "Secure Note" \
      --title "${op_item_name}" \
      --vault "${OP_VAULT}" \
      "add more.${node_name}\\.crt[text]=$(cat "${NEBULA_DIR}/${node_name}.crt")" \
      "add more.${node_name}\\.key[text]=$(cat "${NEBULA_DIR}/${node_name}.key")" \
      "add more.nebula_ip[text]=${nebula_ip}" \
      "add more.vm_id[text]=${node_id}" \
      "add more.lan_ip[text]=192.168.68.${node_id}" \
      >/dev/null 2>&1; then
      warn "  ⚠️  Failed to store certificate in 1Password"
      rm -f "${NEBULA_DIR}/${node_name}.crt" "${NEBULA_DIR}/${node_name}.key"
      die "Certificate storage failed. Ensure you have write access to 1Password vault '${OP_VAULT}'"
    fi

    # Clean up local certificates (now stored in 1Password)
    rm -f "${NEBULA_DIR}/${node_name}.crt" "${NEBULA_DIR}/${node_name}.key"

    success "  ✓ Worker ${i} (${nebula_ip}) - generated and stored"
  done
}

# Generate Ansible host_vars structure with vault templates
# Creates host_vars/<hostname>/vault.tpl.yml for each Vyom node
# Arguments:
#   $1 - Number of control plane nodes
#   $2 - Number of worker nodes
generate_host_vars() {
  local cp_count=$1
  local worker_count=$2
  local script_dir
  local ansible_dir

  # Get the absolute path to the script directory
  script_file="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
  script_dir="$(dirname "${script_file}")"
  ansible_dir="${script_dir}/../samsara/ansible"

  info "Generating Ansible host_vars structure..."

  # Create host_vars directory if it doesn't exist
  mkdir -p "${ansible_dir}/host_vars"

  # Generate control plane host_vars
  for i in $(seq 1 "${cp_count}"); do
    local hostname="vyom-control-plane-${i}"
    local host_dir="${ansible_dir}/host_vars/${hostname}"
    local vault_tpl="${host_dir}/vault.tpl.yml"

    # Skip if vault.tpl.yml already exists
    if [[ -f "${vault_tpl}" ]]; then
      success "  ⏭  ${hostname} - vault.tpl.yml already exists"
      continue
    fi

    # Create directory
    mkdir -p "${host_dir}"

    # Generate vault template
    cat > "${vault_tpl}" <<EOF
---
# Host-specific secrets for ${hostname}
# Generated by: make nebula-certs
# Processed by: make nidhi-tirodhana
#
# This template is resolved by inject-secrets.py BEFORE Ansible runs,
# so Ansible variables are NOT available here. Use static op:// references.

# Nebula Node Certificate (specific to this host)
nebula_node_crt: |
  op://Project-Brahmanda/Nebula-Vyom-Control-Plane-${i}-Certificate/add more/${hostname}.crt

nebula_node_key: |
  op://Project-Brahmanda/Nebula-Vyom-Control-Plane-${i}-Certificate/add more/${hostname}.key
EOF

    success "  ✓ ${hostname} - created vault.tpl.yml"
  done

  # Generate worker host_vars
  for i in $(seq 1 "${worker_count}"); do
    local hostname="vyom-worker-${i}"
    local host_dir="${ansible_dir}/host_vars/${hostname}"
    local vault_tpl="${host_dir}/vault.tpl.yml"

    # Skip if vault.tpl.yml already exists
    if [[ -f "${vault_tpl}" ]]; then
      success "  ⏭  ${hostname} - vault.tpl.yml already exists"
      continue
    fi

    # Create directory
    mkdir -p "${host_dir}"

    # Generate vault template
    cat > "${vault_tpl}" <<EOF
---
# Host-specific secrets for ${hostname}
# Generated by: make nebula-certs
# Processed by: make nidhi-tirodhana
#
# This template is resolved by inject-secrets.py BEFORE Ansible runs,
# so Ansible variables are NOT available here. Use static op:// references.

# Nebula Node Certificate (specific to this host)
nebula_node_crt: |
  op://Project-Brahmanda/Nebula-Vyom-Worker-${i}-Certificate/add more/${hostname}.crt

nebula_node_key: |
  op://Project-Brahmanda/Nebula-Vyom-Worker-${i}-Certificate/add more/${hostname}.key
EOF

    success "  ✓ ${hostname} - created vault.tpl.yml"
  done
}

# Print summary of generated certificates
print_summary() {
  echo ""
  success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  success "Nebula Certificate Generation Complete"
  success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if [[ "${SKIP_KSHITIZ}" == "false" ]]; then
    info "Kshitiz Lighthouse: 10.100.0.1"
  fi

  info "Control Plane Nodes: ${CONTROL_PLANE_COUNT}"
  if [[ "${CONTROL_PLANE_COUNT}" == "1" ]]; then
    info "  IP: 10.100.1.${VYOM_IP_START}"
  else
    info "  IP Range: 10.100.1.${VYOM_IP_START} - 10.100.1.$((VYOM_IP_START + CONTROL_PLANE_COUNT - 1))"
  fi

  info "Worker Nodes: ${WORKER_COUNT}"
  local worker_start=$((VYOM_IP_START + CONTROL_PLANE_COUNT))
  if [[ "${WORKER_COUNT}" == "1" ]]; then
    info "  IP: 10.100.1.${worker_start}"
  else
    info "  IP Range: 10.100.1.${worker_start} - 10.100.1.$((worker_start + WORKER_COUNT - 1))"
  fi

  echo ""
  info "NEXT STEPS:"
  info "  1. Verify host_vars structure: ls -la samsara/ansible/host_vars/"
  info "  2. Update Kshitiz vault if lighthouse was regenerated (kshitiz/vault.tpl.yml)"
  info "  3. Run: make nidhi-tirodhana (generates encrypted vaults for all hosts)"
  info "  4. Redeploy infrastructure:"
  info "     make pralaya-kshitiz && make kshitiz"
  info "     make pralaya-vyom && make vyom"
  info "     make maya"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
  parse_arguments "$@"
  check_prerequisites
  manage_ca_certificate

  # Generate Kshitiz Lighthouse (unless --skip-kshitiz)
  if [[ "${SKIP_KSHITIZ}" == "false" ]]; then
    generate_kshitiz_lighthouse
  fi

  # Generate Vyom certificates
  generate_vyom_control_planes "${CONTROL_PLANE_COUNT}"
  generate_vyom_workers "${WORKER_COUNT}" "${CONTROL_PLANE_COUNT}"

  # Generate Ansible host_vars structure
  generate_host_vars "${CONTROL_PLANE_COUNT}" "${WORKER_COUNT}"

  print_summary
}

main "$@"
