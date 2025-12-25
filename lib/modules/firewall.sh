#!/bin/bash
# Firewall Module
# Configures UFW (Uncomplicated Firewall) for network security
# Implements SEC-011 and SEC-012 requirements
#
# Usage:
#   source lib/modules/firewall.sh
#   firewall_execute
#
# Dependencies:
#   - lib/core/logger.sh
#   - lib/core/checkpoint.sh
#   - lib/core/transaction.sh
#   - lib/core/progress.sh

set -euo pipefail

# Prevent multiple sourcing
if [[ -n "${_FIREWALL_SH_LOADED:-}" ]]; then
  return 0
fi
readonly _FIREWALL_SH_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${SCRIPT_DIR}")"
# shellcheck disable=SC1091
source "${LIB_DIR}/core/logger.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/core/checkpoint.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/core/transaction.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/core/progress.sh"

# Module constants
readonly FIREWALL_PHASE="${FIREWALL_PHASE:-firewall-config}"
: "${SSH_PORT:=22}"  # Set default if not already set
: "${RDP_PORT:=3389}"  # Set default if not already set

# firewall_check_prerequisites
# Validates system is ready for firewall configuration
#
# Returns:
#   0 - Prerequisites met
#   1 - Prerequisites failed
firewall_check_prerequisites() {
  log_info "Checking firewall prerequisites"

  # Verify system-prep phase completed
  if ! checkpoint_exists "system-prep"; then
    log_error "System preparation must be completed before firewall configuration"
    return 1
  fi

  log_info "Prerequisites check passed"
  return 0
}

# firewall_install_ufw
# Installs UFW firewall package
#
# Returns:
#   0 - Installation successful
#   1 - Installation failed
firewall_install_ufw() {
  log_info "Installing UFW firewall"
  progress_update "Installing firewall" 10

  # Check if already installed
  if command -v ufw &>/dev/null; then
    log_info "UFW already installed"
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive

  if ! apt-get install -y ufw 2>&1 | tee -a "${LOG_FILE}"; then
    log_error "Failed to install UFW"
    return 1
  fi

  transaction_log "apt-get remove -y ufw"

  # Verify installation
  if ! command -v ufw &>/dev/null; then
    log_error "UFW installation verification failed"
    return 1
  fi

  log_info "UFW installed successfully"
  return 0
}

# firewall_configure_default_deny
# Configures UFW to deny all incoming traffic by default (SEC-011)
#
# Returns:
#   0 - Configuration successful
#   1 - Configuration failed
firewall_configure_default_deny() {
  log_info "Configuring default DENY policy (SEC-011)"
  progress_update "Configuring firewall policy" 30

  # Set default policies
  if ! ufw --force default deny incoming 2>&1 | tee -a "${LOG_FILE}"; then
    log_error "Failed to set default deny incoming policy"
    return 1
  fi

  if ! ufw --force default allow outgoing 2>&1 | tee -a "${LOG_FILE}"; then
    log_error "Failed to set default allow outgoing policy"
    return 1
  fi

  if ! ufw --force default deny routed 2>&1 | tee -a "${LOG_FILE}"; then
    log_error "Failed to set default deny routed policy"
    return 1
  fi

  transaction_log "ufw --force reset"

  log_info "Default DENY policy configured successfully"
  return 0
}

# firewall_allow_required_ports
# Allows SSH and RDP ports through firewall (SEC-012)
#
# Returns:
#   0 - Configuration successful
#   1 - Configuration failed
firewall_allow_required_ports() {
  log_info "Allowing required ports: SSH (${SSH_PORT}), RDP (${RDP_PORT}) (SEC-012)"
  progress_update "Configuring firewall rules" 50

  # Allow SSH port
  if ! ufw allow "${SSH_PORT}/tcp" comment 'SSH access' 2>&1 | tee -a "${LOG_FILE}"; then
    log_error "Failed to allow SSH port ${SSH_PORT}"
    return 1
  fi

  transaction_log "ufw delete allow ${SSH_PORT}/tcp"

  # Allow RDP port
  if ! ufw allow "${RDP_PORT}/tcp" comment 'RDP access' 2>&1 | tee -a "${LOG_FILE}"; then
    log_error "Failed to allow RDP port ${RDP_PORT}"
    return 1
  fi

  transaction_log "ufw delete allow ${RDP_PORT}/tcp"

  log_info "Required ports configured successfully"
  return 0
}

# firewall_enable
# Enables UFW firewall
#
# Returns:
#   0 - Enable successful
#   1 - Enable failed
firewall_enable() {
  log_info "Enabling UFW firewall"
  progress_update "Enabling firewall" 70

  # Enable firewall (--force skips confirmation prompt)
  if ! ufw --force enable 2>&1 | tee -a "${LOG_FILE}"; then
    log_error "Failed to enable UFW"
    return 1
  fi

  # Enable UFW service to start on boot
  if ! systemctl enable ufw 2>&1 | tee -a "${LOG_FILE}"; then
    log_warning "Failed to enable UFW service on boot (non-critical)"
  fi

  transaction_log "ufw --force disable && systemctl disable ufw"

  log_info "UFW firewall enabled successfully"
  return 0
}

# firewall_verify_configuration
# Verifies firewall configuration
#
# Returns:
#   0 - Verification successful
#   1 - Verification failed
firewall_verify_configuration() {
  log_info "Verifying firewall configuration"
  progress_update "Verifying firewall" 90

  # Check UFW status
  local status
  status=$(ufw status verbose 2>&1)

  if ! echo "${status}" | grep -q "Status: active"; then
    log_error "UFW is not active"
    return 1
  fi

  # Verify default deny policy
  if ! echo "${status}" | grep -q "Default: deny (incoming)"; then
    log_error "Default incoming policy is not deny"
    return 1
  fi

  # Verify SSH port allowed
  if ! echo "${status}" | grep -qE "${SSH_PORT}/tcp.*ALLOW"; then
    log_error "SSH port ${SSH_PORT} is not allowed"
    return 1
  fi

  # Verify RDP port allowed
  if ! echo "${status}" | grep -qE "${RDP_PORT}/tcp.*ALLOW"; then
    log_error "RDP port ${RDP_PORT} is not allowed"
    return 1
  fi

  log_info "Firewall configuration verified successfully"
  log_info "Active firewall rules:"
  ufw status numbered | tee -a "${LOG_FILE}"

  return 0
}

# firewall_execute
# Main execution function for firewall module
#
# Returns:
#   0 - Execution successful
#   1 - Execution failed
firewall_execute() {
  log_info "Starting firewall configuration"

  # Check for existing checkpoint
  if checkpoint_exists "$FIREWALL_PHASE"; then
    log_info "Firewall already configured, skipping"
    return 0
  fi

  # Check prerequisites
  if ! firewall_check_prerequisites; then
    return 1
  fi

  # Install UFW
  if ! firewall_install_ufw; then
    return 1
  fi

  # Configure default deny
  if ! firewall_configure_default_deny; then
    return 1
  fi

  # Allow required ports
  if ! firewall_allow_required_ports; then
    return 1
  fi

  # Enable firewall
  if ! firewall_enable; then
    return 1
  fi

  # Verify configuration
  if ! firewall_verify_configuration; then
    return 1
  fi

  # Create checkpoint
  checkpoint_create "$FIREWALL_PHASE"

  progress_update "Firewall configuration complete" 100
  log_info "Firewall configuration completed successfully"

  return 0
}
