#!/bin/bash
# Fail2ban Module
# Configures fail2ban for intrusion prevention
# Implements SEC-013 requirement
#
# Usage:
#   source lib/modules/fail2ban.sh
#   fail2ban_execute
#
# Dependencies:
#   - lib/core/logger.sh
#   - lib/core/checkpoint.sh
#   - lib/core/transaction.sh
#   - lib/core/progress.sh

set -euo pipefail

# Prevent multiple sourcing
if [[ -n "${_FAIL2BAN_SH_LOADED:-}" ]]; then
  return 0
fi
readonly _FAIL2BAN_SH_LOADED=1

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
readonly FAIL2BAN_PHASE="${FAIL2BAN_PHASE:-fail2ban-config}"
# Allow override for testing
FAIL2BAN_LOCAL="${FAIL2BAN_LOCAL:-/etc/fail2ban/jail.local}"
readonly MAX_RETRY="${MAX_RETRY:-5}"
readonly BAN_TIME="${BAN_TIME:-600}"
readonly FIND_TIME="${FIND_TIME:-600}"

# fail2ban_check_prerequisites
# Validates system is ready for fail2ban configuration
#
# Returns:
#   0 - Prerequisites met
#   1 - Prerequisites failed
fail2ban_check_prerequisites() {
  log_info "Checking fail2ban prerequisites"

  # Verify firewall is configured
  if ! checkpoint_exists "firewall-config"; then
    log_error "Firewall must be configured before fail2ban"
    return 1
  fi

  log_info "Prerequisites check passed"
  return 0
}

# fail2ban_install
# Installs fail2ban package
#
# Returns:
#   0 - Installation successful
#   1 - Installation failed
fail2ban_install() {
  log_info "Installing fail2ban"
  progress_update "Installing fail2ban" 10

  # Check if already installed
  if command -v fail2ban-client &>/dev/null; then
    log_info "fail2ban already installed"
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive

  if ! apt-get install -y fail2ban 2>&1 | tee -a "${LOG_FILE}"; then
    log_error "Failed to install fail2ban"
    return 1
  fi

  transaction_log "apt-get remove -y fail2ban"

  # Verify installation
  if ! command -v fail2ban-client &>/dev/null; then
    log_error "fail2ban installation verification failed"
    return 1
  fi

  log_info "fail2ban installed successfully"
  return 0
}

# fail2ban_configure
# Configures fail2ban for SSH and RDP monitoring (SEC-013)
#
# Returns:
#   0 - Configuration successful
#   1 - Configuration failed
fail2ban_configure() {
  log_info "Configuring fail2ban (SEC-013)"
  progress_update "Configuring fail2ban" 40

  # Backup existing configuration if present
  if [[ -f "${FAIL2BAN_LOCAL}" ]]; then
    transaction_log "mv ${FAIL2BAN_LOCAL}.vps-backup ${FAIL2BAN_LOCAL}"
    cp "${FAIL2BAN_LOCAL}" "${FAIL2BAN_LOCAL}.vps-backup"
  fi

  # Create jail.local configuration
  # SEC-013: Ban after 5 failed attempts within 10 minutes
  cat >"${FAIL2BAN_LOCAL}" <<EOF
# VPS-PROVISION CONFIGURED fail2ban jail.local
# SEC-013: Monitor SSH and RDP logs, ban IPs after 5 failed attempts in 10 minutes

[DEFAULT]
# Ban settings
bantime  = ${BAN_TIME}
findtime = ${FIND_TIME}
maxretry = ${MAX_RETRY}

# Email notifications (disabled by default)
destemail = root@localhost
sendername = Fail2Ban
mta = sendmail
action = %(action_)s

[sshd]
enabled = true
port    = 22
logpath = /var/log/auth.log
backend = systemd
maxretry = ${MAX_RETRY}
findtime = ${FIND_TIME}
bantime  = ${BAN_TIME}

[xrdp]
enabled = true
port    = 3389
logpath = /var/log/xrdp-sesman.log
backend = auto
maxretry = ${MAX_RETRY}
findtime = ${FIND_TIME}
bantime  = ${BAN_TIME}
# Custom filter for xrdp
filter = xrdp

[xrdp-auth]
enabled = true
port    = 3389
logpath = /var/log/xrdp.log
backend = auto
maxretry = ${MAX_RETRY}
findtime = ${FIND_TIME}
bantime  = ${BAN_TIME}
filter = xrdp-auth
EOF

  transaction_log "rm -f ${FAIL2BAN_LOCAL}"

  # Create custom xrdp filter if it doesn't exist
  local xrdp_filter="${TEST_ROOT:-}/etc/fail2ban/filter.d/xrdp.conf"
  # Ensure directory exists
  mkdir -p "$(dirname "${xrdp_filter}")"

  if [[ ! -f "${xrdp_filter}" ]]; then
    cat >"${xrdp_filter}" <<'EOF'
# Fail2ban filter for xrdp authentication failures
[Definition]
failregex = ^.*pam_authenticate failed.*from <HOST>.*$
            ^.*pam_unix\(xrdp-sesman:auth\): authentication failure.*rhost=<HOST>.*$
            ^.*pam_unix\(xrdp-sesman:auth\): check pass; user unknown.*rhost=<HOST>.*$
ignoreregex =
EOF
    transaction_log "rm -f ${xrdp_filter}"
  fi

  # Create custom xrdp-auth filter
  local xrdp_auth_filter="${TEST_ROOT:-}/etc/fail2ban/filter.d/xrdp-auth.conf"
  # Ensure directory exists
  mkdir -p "$(dirname "${xrdp_auth_filter}")"

  if [[ ! -f "${xrdp_auth_filter}" ]]; then
    cat >"${xrdp_auth_filter}" <<'EOF'
# Fail2ban filter for xrdp login failures
[Definition]
failregex = ^\[\d+\] \[\w+\] xrdp_wm_log_msg: login failed for display \d+ from <HOST>$
            ^xrdp-sesman\.log:.*LOGIN FAILED.*from <HOST>$
ignoreregex =
EOF
    transaction_log "rm -f ${xrdp_auth_filter}"
  fi

  log_info "fail2ban configured successfully"
  return 0
}

# fail2ban_enable
# Enables and starts fail2ban service
#
# Returns:
#   0 - Enable successful
#   1 - Enable failed
fail2ban_enable() {
  log_info "Enabling fail2ban service"
  progress_update "Enabling fail2ban" 70

  # Reload fail2ban to pick up new configuration
  if systemctl is-active --quiet fail2ban; then
    if ! systemctl restart fail2ban 2>&1 | tee -a "${LOG_FILE}"; then
      log_error "Failed to restart fail2ban"
      return 1
    fi
  else
    if ! systemctl start fail2ban 2>&1 | tee -a "${LOG_FILE}"; then
      log_error "Failed to start fail2ban"
      return 1
    fi
  fi

  # Enable on boot
  if ! systemctl enable fail2ban 2>&1 | tee -a "${LOG_FILE}"; then
    log_warning "Failed to enable fail2ban on boot (non-critical)"
  fi

  transaction_log "systemctl stop fail2ban && systemctl disable fail2ban"

  log_info "fail2ban service enabled successfully"
  return 0
}

# fail2ban_verify
# Verifies fail2ban is running and monitoring
#
# Returns:
#   0 - Verification successful
#   1 - Verification failed
fail2ban_verify() {
  log_info "Verifying fail2ban configuration"
  progress_update "Verifying fail2ban" 90

  # Check service status
  if ! systemctl is-active --quiet fail2ban; then
    log_error "fail2ban service is not running"
    return 1
  fi

  # Wait for fail2ban to initialize
  sleep 2

  # Check if sshd jail is active
  if ! fail2ban-client status sshd &>/dev/null; then
    log_warning "sshd jail not active yet, may need time to initialize"
  else
    log_info "sshd jail active: $(fail2ban-client status sshd | grep 'Currently banned')"
  fi

  # Check if xrdp jail is active
  if ! fail2ban-client status xrdp &>/dev/null; then
    log_warning "xrdp jail not active (may activate when xrdp generates logs)"
  else
    log_info "xrdp jail active: $(fail2ban-client status xrdp | grep 'Currently banned')"
  fi

  # List all active jails
  log_info "Active fail2ban jails:"
  fail2ban-client status | tee -a "${LOG_FILE}"

  log_info "fail2ban configuration verified successfully"
  return 0
}

# fail2ban_execute
# Main execution function for fail2ban module
#
# Returns:
#   0 - Execution successful
#   1 - Execution failed
fail2ban_execute() {
  log_info "Starting fail2ban configuration"

  # Check for existing checkpoint
  if checkpoint_exists "$FAIL2BAN_PHASE"; then
    log_info "fail2ban already configured, skipping"
    return 0
  fi

  # Check prerequisites
  if ! fail2ban_check_prerequisites; then
    return 1
  fi

  # Install fail2ban
  if ! fail2ban_install; then
    return 1
  fi

  # Configure fail2ban
  if ! fail2ban_configure; then
    return 1
  fi

  # Enable fail2ban
  if ! fail2ban_enable; then
    return 1
  fi

  # Verify configuration
  if ! fail2ban_verify; then
    return 1
  fi

  # Create checkpoint
  checkpoint_create "$FAIL2BAN_PHASE"

  progress_update "fail2ban configuration complete" 100
  log_info "fail2ban configuration completed successfully"

  return 0
}
