#!/bin/bash
# State Comparison Utility
# Generates system fingerprint and compares against baseline for consistency verification
#
# Used for User Story 4 (T067): Verify multiple VPS provisions yield identical environments
#
# Usage:
#   state-compare.sh generate <output-file>   # Generate system fingerprint
#   state-compare.sh compare <file1> <file2>  # Compare two fingerprints
#   state-compare.sh baseline <file>          # Set baseline fingerprint
#   state-compare.sh verify <current-file>    # Compare against baseline
#
# Fingerprint includes:
#   - Package versions (all installed packages)
#   - Configuration file checksums (key system configs)
#   - Service status (all systemd services)
#   - User accounts and groups
#   - File permissions on critical paths
#   - IDE installation status and versions
#   - Network configuration

set -euo pipefail

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${SCRIPT_DIR}")"

# Source dependencies
# shellcheck disable=SC1091
# shellcheck disable=SC1091
source "${LIB_DIR}/core/logger.sh"

# Constants
readonly BASELINE_FILE="${STATE_COMPARISON_BASELINE:-/var/vps-provision/baseline-fingerprint.txt}"
readonly TEMP_DIR="${TMPDIR:-/tmp}/state-compare-$$"

# Critical configuration files to checksum
readonly -a CONFIG_FILES=(
  "/etc/apt/apt.conf.d/99vps-provision"
  "/etc/apt/apt.conf.d/50unattended-upgrades"
  "/etc/lightdm/lightdm.conf"
  "/etc/xrdp/xrdp.ini"
  "/etc/xrdp/sesman.ini"
  "/etc/ssh/sshd_config"
  "/etc/sudoers.d/devuser"
  "/etc/ufw/ufw.conf"
  "/etc/systemd/system.conf"
)

# Critical paths to check permissions
readonly -a CRITICAL_PATHS=(
  "/home/devuser"
  "/opt/vscode"
  "/opt/cursor"
  "/opt/antigravity"
  "/var/log/vps-provision"
  "/var/vps-provision"
)

# Cleanup on exit
cleanup() {
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# Create temp directory
mkdir -p "${TEMP_DIR}"

# Show usage
show_usage() {
  cat <<'EOF'
State Comparison Utility - System Fingerprint Generation and Comparison

USAGE:
    state-compare.sh <command> [arguments]

COMMANDS:
    generate <output-file>       Generate system fingerprint to file
    compare <file1> <file2>      Compare two fingerprint files
    baseline <file>              Set system baseline fingerprint
    verify [current-file]        Compare current state against baseline
    help                         Show this help message

EXAMPLES:
    # Generate fingerprint
    state-compare.sh generate /tmp/system-state.txt
    
    # Set baseline after first provision
    state-compare.sh baseline /tmp/system-state.txt
    
    # Verify current state matches baseline
    state-compare.sh verify
    
    # Compare two fingerprints
    state-compare.sh compare vps1-state.txt vps2-state.txt

EXIT CODES:
    0    Success (states match, if comparing)
    1    States differ (if comparing)
    2    Command failed
    3    Invalid arguments

EOF
}

# Generate package list fingerprint
generate_package_fingerprint() {
  echo "=== PACKAGE FINGERPRINT ==="
  echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo ""
  
  echo "--- Installed Packages ---"
  dpkg -l | grep '^ii' | awk '{print $2 " " $3}' | sort
  echo ""
  
  echo "--- Package Count ---"
  dpkg -l | grep -c '^ii'
  echo ""
}

# Generate configuration fingerprint
generate_config_fingerprint() {
  echo "=== CONFIGURATION FINGERPRINT ==="
  echo ""
  
  for config_file in "${CONFIG_FILES[@]}"; do
    if [[ -f "${config_file}" ]]; then
      local checksum
      checksum=$(sha256sum "${config_file}" | awk '{print $1}')
      echo "${config_file}: ${checksum}"
    else
      echo "${config_file}: NOT_FOUND"
    fi
  done
  echo ""
}

# Generate service status fingerprint
generate_service_fingerprint() {
  echo "=== SERVICE STATUS FINGERPRINT ==="
  echo ""
  
  # Key services for VPS provisioning
  local -a key_services=(
    "ssh"
    "xrdp"
    "lightdm"
    "ufw"
    "systemd-resolved"
    "unattended-upgrades"
  )
  
  for service in "${key_services[@]}"; do
    if systemctl list-unit-files | grep -q "^${service}\.service"; then
      local status
      status=$(systemctl is-active "${service}" 2>/dev/null || echo "inactive")
      local enabled
      enabled=$(systemctl is-enabled "${service}" 2>/dev/null || echo "disabled")
      echo "${service}: status=${status}, enabled=${enabled}"
    else
      echo "${service}: NOT_INSTALLED"
    fi
  done
  echo ""
}

# Generate user/group fingerprint
generate_user_fingerprint() {
  echo "=== USER/GROUP FINGERPRINT ==="
  echo ""
  
  echo "--- Users (UID >= 1000) ---"
  awk -F: '$3 >= 1000 && $3 < 65534 {print $1 ":" $3 ":" $4 ":" $6 ":" $7}' /etc/passwd | sort
  echo ""
  
  echo "--- Groups (GID >= 1000) ---"
  awk -F: '$3 >= 1000 && $3 < 65534 {print $1 ":" $3}' /etc/group | sort
  echo ""
  
  echo "--- Developer User Groups ---"
  if id devuser &>/dev/null; then
    groups devuser
  else
    echo "devuser: NOT_FOUND"
  fi
  echo ""
}

# Generate permissions fingerprint
generate_permissions_fingerprint() {
  echo "=== PERMISSIONS FINGERPRINT ==="
  echo ""
  
  for path in "${CRITICAL_PATHS[@]}"; do
    if [[ -e "${path}" ]]; then
      local perms owner group
      perms=$(stat -c '%a' "${path}" 2>/dev/null || echo "UNKNOWN")
      owner=$(stat -c '%U' "${path}" 2>/dev/null || echo "UNKNOWN")
      group=$(stat -c '%G' "${path}" 2>/dev/null || echo "UNKNOWN")
      echo "${path}: perms=${perms}, owner=${owner}, group=${group}"
    else
      echo "${path}: NOT_FOUND"
    fi
  done
  echo ""
}

# Generate IDE fingerprint
generate_ide_fingerprint() {
  echo "=== IDE INSTALLATION FINGERPRINT ==="
  echo ""
  
  # VSCode
  if command -v code &>/dev/null; then
    local version
    version=$(code --version 2>/dev/null | head -1 || echo "UNKNOWN")
    local location
    location=$(command -v code)
    echo "vscode: version=${version}, location=${location}"
  else
    echo "vscode: NOT_INSTALLED"
  fi
  
  # Cursor
  if command -v cursor &>/dev/null; then
    local location
    location=$(command -v cursor)
    echo "cursor: location=${location}"
  else
    echo "cursor: NOT_INSTALLED"
  fi
  
  # Antigravity
  if command -v antigravity &>/dev/null; then
    local location
    location=$(command -v antigravity)
    echo "antigravity: location=${location}"
  elif [[ -f /opt/antigravity/antigravity ]]; then
    echo "antigravity: location=/opt/antigravity/antigravity"
  else
    echo "antigravity: NOT_INSTALLED"
  fi
  echo ""
}

# Generate network fingerprint
generate_network_fingerprint() {
  echo "=== NETWORK CONFIGURATION FINGERPRINT ==="
  echo ""
  
  echo "--- Hostname ---"
  hostname
  echo ""
  
  echo "--- Network Interfaces ---"
  ip -4 addr show | grep -E "inet " | awk '{print $2}' | sort
  echo ""
  
  echo "--- Listening Ports ---"
  ss -tlnp | grep LISTEN | awk '{print $4}' | sort -u
  echo ""
  
  echo "--- Firewall Status ---"
  if command -v ufw &>/dev/null; then
    ufw status 2>/dev/null | head -5 || echo "UFW: Error getting status"
  else
    echo "UFW: NOT_INSTALLED"
  fi
  echo ""
}

# Generate system info fingerprint
generate_system_info() {
  echo "=== SYSTEM INFORMATION ==="
  echo ""
  
  echo "--- OS Version ---"
# shellcheck disable=SC2002
  cat /etc/os-release | grep -E "^(NAME|VERSION)" | sort
  echo ""
  
  echo "--- Kernel Version ---"
  uname -r
  echo ""
  
  echo "--- CPU Info ---"
  grep -E "^(model name|cpu cores)" /proc/cpuinfo | head -2
  echo ""
  
  echo "--- Memory ---"
  free -h | grep Mem
  echo ""
  
  echo "--- Disk Space ---"
  df -h / | tail -1
  echo ""
}

# Generate complete system fingerprint
cmd_generate() {
  local output_file="$1"
  
  if [[ -z "${output_file}" ]]; then
    log_error "Output file not specified"
    return 3
  fi
  
  log_info "Generating system fingerprint..."
  
  {
    echo "######################################################################"
    echo "# VPS PROVISIONING SYSTEM FINGERPRINT"
    echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "# Hostname: $(hostname)"
    echo "######################################################################"
    echo ""
    
    generate_system_info
    generate_package_fingerprint
    generate_config_fingerprint
    generate_service_fingerprint
    generate_user_fingerprint
    generate_permissions_fingerprint
    generate_ide_fingerprint
    generate_network_fingerprint
    
    echo "######################################################################"
    echo "# END OF FINGERPRINT"
    echo "######################################################################"
  } > "${output_file}"
  
  log_info "System fingerprint saved to: ${output_file}"
  
  local line_count
  line_count=$(wc -l < "${output_file}")
  log_info "Fingerprint contains ${line_count} lines"
  
  return 0
}

# Compare two fingerprint files
cmd_compare() {
  local file1="$1"
  local file2="$2"
  
  if [[ -z "${file1}" || -z "${file2}" ]]; then
    log_error "Two files required for comparison"
    return 3
  fi
  
  if [[ ! -f "${file1}" ]]; then
    log_error "File not found: ${file1}"
    return 2
  fi
  
  if [[ ! -f "${file2}" ]]; then
    log_error "File not found: ${file2}"
    return 2
  fi
  
  log_info "Comparing fingerprints..."
  log_info "  File 1: ${file1}"
  log_info "  File 2: ${file2}"
  
  # Filter out timestamps and hostnames for comparison
  local filtered1="${TEMP_DIR}/filtered1.txt"
  local filtered2="${TEMP_DIR}/filtered2.txt"
  
  grep -v -E "^(# Generated:|# Hostname:)" "${file1}" > "${filtered1}"
  grep -v -E "^(# Generated:|# Hostname:)" "${file2}" > "${filtered2}"
  
  # Compare filtered files
  if diff -u "${filtered1}" "${filtered2}" > "${TEMP_DIR}/diff.txt"; then
    log_info "✓ Fingerprints match - systems are identical"
    return 0
  else
    log_warning "✗ Fingerprints differ - systems have differences"
    echo ""
    echo "Differences found:"
    cat "${TEMP_DIR}/diff.txt"
    return 1
  fi
}

# Set baseline fingerprint
cmd_baseline() {
  local source_file="$1"
  
  if [[ -z "${source_file}" ]]; then
    log_error "Source file not specified"
    return 3
  fi
  
  if [[ ! -f "${source_file}" ]]; then
    log_error "Source file not found: ${source_file}"
    return 2
  fi
  
  # Ensure baseline directory exists
  local baseline_dir
  baseline_dir=$(dirname "${BASELINE_FILE}")
  mkdir -p "${baseline_dir}"
  
  # Copy to baseline location
  cp "${source_file}" "${BASELINE_FILE}"
  
  log_info "Baseline fingerprint set: ${BASELINE_FILE}"
  
  return 0
}

# Verify current state against baseline
cmd_verify() {
  local current_file="${1:-${TEMP_DIR}/current-state.txt}"
  
  if [[ ! -f "${BASELINE_FILE}" ]]; then
    log_error "Baseline fingerprint not found: ${BASELINE_FILE}"
    log_error "Set baseline first with: state-compare.sh baseline <file>"
    return 2
  fi
  
  # Generate current state if not provided
  if [[ ! -f "${current_file}" ]]; then
    log_info "Generating current system state..."
    cmd_generate "${current_file}"
  fi
  
  # Compare against baseline
  log_info "Verifying against baseline..."
  cmd_compare "${BASELINE_FILE}" "${current_file}"
  
  return $?
}

# Main command dispatcher
main() {
  local command="${1:-help}"
  shift || true
  
  case "${command}" in
    generate)
      cmd_generate "$@"
      ;;
    compare)
      cmd_compare "$@"
      ;;
    baseline)
      cmd_baseline "$@"
      ;;
    verify)
      cmd_verify "$@"
      ;;
    help|--help|-h)
      show_usage
      exit 0
      ;;
    *)
      log_error "Unknown command: ${command}"
      show_usage
      exit 3
      ;;
  esac
}

# Execute main function
main "$@"
