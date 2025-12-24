#!/usr/bin/env bats
# Integration tests for Network Security (T097)
# Tests SEC-011, SEC-012, and SEC-013 requirements

load '../test_helper'

setup() {
  # Create temporary test environment
  export TEST_ROOT="${BATS_TEST_TMPDIR}/network_security_test"
  mkdir -p "${TEST_ROOT}"
  
  export LOG_FILE="${TEST_ROOT}/test.log"
  export TRANSACTION_LOG="${TEST_ROOT}/transaction.log"
  export LIB_DIR="${BATS_TEST_DIRNAME}/../../lib"
  export FAIL2BAN_LOCAL="${TEST_ROOT}/etc/fail2ban/jail.local"
  export AUDIT_RULES_FILE="${TEST_ROOT}/etc/audit/rules.d/vps-provision.rules"
  
  mkdir -p "${TEST_ROOT}/etc/fail2ban/filter.d"
  mkdir -p "${TEST_ROOT}/etc/audit/rules.d"
  touch "${LOG_FILE}" "${TRANSACTION_LOG}"
  
  # Override module constants to use test paths
  export FAIL2BAN_LOCAL
  export AUDIT_RULES_FILE
  export CHECKPOINT_DIR="${TEST_ROOT}/checkpoints"
  mkdir -p "${CHECKPOINT_DIR}"  # Create checkpoint directory for tests
  
  # Unset sourcing guards to allow re-sourcing with our test CHECKPOINT_DIR
  # Note: Don't unset _PROGRESS_SH_LOADED or _LOGGER_SH_LOADED as they contain readonly variables
  unset _CHECKPOINT_SH_LOADED 2>/dev/null || true
  unset _FIREWALL_SH_LOADED 2>/dev/null || true
  unset _FAIL2BAN_SH_LOADED 2>/dev/null || true
  unset _TRANSACTION_SH_LOADED 2>/dev/null || true
  
  # Source modules - they will use our environment variables
  source "${PROJECT_ROOT}/lib/modules/firewall.sh"
  source "${PROJECT_ROOT}/lib/modules/fail2ban.sh"
  
  # NOW override/mock functions AFTER sourcing
  # This ensures our mocks take precedence over the sourced functions
  
  # Mock logging functions
  log_info() { echo "[INFO] $*" >> "${LOG_FILE}"; }
  log_error() { echo "[ERROR] $*" >> "${LOG_FILE}"; }
  log_warning() { echo "[WARNING] $*" >> "${LOG_FILE}"; }
  log_debug() { echo "[DEBUG] $*" >> "${LOG_FILE}"; }
  export -f log_info log_error log_warning log_debug
  
  # Mock transaction log function
  transaction_log() {
    local rollback="$1"
    echo "ROLLBACK|$(date -Iseconds)|${rollback}" >> "${TRANSACTION_LOG}"
  }
  export -f transaction_log
  
  # Mock progress function
  progress_update() { echo "[PROGRESS] $*" >> "${LOG_FILE}"; }
  export -f progress_update
  
  # Mock commands for firewall testing
  ufw() {
    echo "ufw $*" >> "${LOG_FILE}"
    case "$1" in
      "status")
        if [[ "$2" == "verbose" ]]; then
          cat <<EOF
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                  # SSH access
3389/tcp                   ALLOW IN    Anywhere                  # RDP access
22/tcp (v6)                ALLOW IN    Anywhere (v6)             # SSH access
3389/tcp (v6)              ALLOW IN    Anywhere (v6)             # RDP access
EOF
        else
          echo "Status: active"
        fi
        return 0
        ;;
      "--force")
        return 0
        ;;
      "allow")
        return 0
        ;;
      "delete")
        return 0
        ;;
      *)
        return 0
        ;;
    esac
  }
  export -f ufw
  
  # Mock systemctl
  systemctl() {
    echo "systemctl $*" >> "${LOG_FILE}"
    if [[ "$1" == "is-active" ]]; then
      return 0
    fi
    return 0
  }
  export -f systemctl
  
  # Mock fail2ban-client
  fail2ban-client() {
    echo "fail2ban-client $*" >> "${LOG_FILE}"
    if [[ "$1" == "status" && "$2" == "sshd" ]]; then
      cat <<EOF
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
|  \`- File list:        /var/log/auth.log
\`- Actions
   |- Currently banned: 0
   |- Total banned:     0
   \`- Banned IP list:
EOF
      return 0
    elif [[ "$1" == "status" && -z "$2" ]]; then
      echo "Status"
      echo "|- Number of jail: 3"
      echo "\`- Jail list: sshd, xrdp, xrdp-auth"
      return 0
    fi
    return 0
  }
  export -f fail2ban-client
  
  # Create checkpoints for prerequisites
  # (checkpoint functions are now from the sourced modules using CHECKPOINT_DIR)
  checkpoint_create "system-prep"
}

teardown() {
  # Cleanup test environment
  rm -rf "${TEST_ROOT}"
}

# =============================================================================
# SEC-011: Firewall Default DENY Policy
# =============================================================================

@test "SEC-011: UFW configured with default DENY incoming" {
  run firewall_configure_default_deny
  assert_success
  
  # Verify deny incoming logged
  run grep -q "ufw --force default deny incoming" "${LOG_FILE}"
  assert_success
}

@test "SEC-011: UFW allows outgoing traffic by default" {
  run firewall_configure_default_deny
  assert_success
  
  # Verify allow outgoing logged
  run grep -q "ufw --force default allow outgoing" "${LOG_FILE}"
  assert_success
}

@test "SEC-011: UFW denies routed traffic by default" {
  run firewall_configure_default_deny
  assert_success
  
  # Verify deny routed logged
  run grep -q "ufw --force default deny routed" "${LOG_FILE}"
  assert_success
}

@test "SEC-011: Firewall verification checks deny policy" {
  # Set up firewall status mock  
  run firewall_verify_configuration
  assert_success
}

@test "SEC-011: Transaction log records firewall reset command" {
  run firewall_configure_default_deny
  assert_success
  
  # Verify rollback command logged
  run grep -q "ufw --force reset" "${TRANSACTION_LOG}"
  assert_success
}

# =============================================================================
# SEC-012: Required Port Allowance
# =============================================================================

@test "SEC-012: SSH port 22 explicitly allowed" {
  run firewall_allow_required_ports
  assert_success
  
  # Verify SSH port allow logged
  run grep -q "ufw allow 22/tcp" "${LOG_FILE}"
  assert_success
}

@test "SEC-012: RDP port 3389 explicitly allowed" {
  run firewall_allow_required_ports
  assert_success
  
  # Verify RDP port allow logged
  run grep -q "ufw allow 3389/tcp" "${LOG_FILE}"
  assert_success
}

@test "SEC-012: Port rules include descriptive comments" {
  run firewall_allow_required_ports
  assert_success
  
  # Verify comments added (check log output since ufw mock logs the command)
  grep -q "comment" "${LOG_FILE}"
}

@test "SEC-012: Firewall verification checks SSH port" {
  run firewall_verify_configuration
  assert_success
}

@test "SEC-012: Firewall verification checks RDP port" {
  run firewall_verify_configuration
  assert_success
}

@test "SEC-012: Transaction log records port allow commands" {
  run firewall_allow_required_ports
  assert_success
  
  # Verify rollback commands logged
  run grep -q "ufw delete allow 22/tcp" "${TRANSACTION_LOG}"
  assert_success
  
  run grep -q "ufw delete allow 3389/tcp" "${TRANSACTION_LOG}"
  assert_success
}

# =============================================================================
# SEC-013: fail2ban Configuration
# =============================================================================

@test "SEC-013: fail2ban jail.local created with correct settings" {
  run fail2ban_configure
  assert_success
  
  # Verify configuration file created
  [[ -f "${FAIL2BAN_LOCAL}" ]]
  
  # Verify max retry = 5
  run grep -q "maxretry = 5" "${FAIL2BAN_LOCAL}"
  assert_success
  
  # Verify ban time = 600 seconds (10 minutes)
  run grep -q "bantime  = 600" "${FAIL2BAN_LOCAL}"
  assert_success
  
  # Verify find time = 600 seconds (10 minutes)
  run grep -q "findtime = 600" "${FAIL2BAN_LOCAL}"
  assert_success
}

@test "SEC-013: fail2ban monitors SSH logs" {
  run fail2ban_configure
  assert_success
  
  # Verify sshd jail enabled
  run grep -A 10 "^\[sshd\]" "${FAIL2BAN_LOCAL}"
  assert_success
  assert_output --partial "enabled = true"
  assert_output --partial "port    = 22"
  assert_output --partial "logpath = /var/log/auth.log"
}

@test "SEC-013: fail2ban monitors RDP logs" {
  run fail2ban_configure
  assert_success
  
  # Verify xrdp jail enabled
  run grep -A 10 "^\[xrdp\]" "${FAIL2BAN_LOCAL}"
  assert_success
  assert_output --partial "enabled = true"
  assert_output --partial "port    = 3389"
  assert_output --partial "logpath = /var/log/xrdp-sesman.log"
}

@test "SEC-013: fail2ban bans after 5 failed attempts" {
  run fail2ban_configure
  assert_success
  
  # Verify maxretry in both jails
  local sshd_maxretry
  sshd_maxretry=$(grep -A 10 "^\[sshd\]" "${FAIL2BAN_LOCAL}" | grep "^maxretry" | awk '{print $3}')
  [[ "${sshd_maxretry}" == "5" ]]
  
  local xrdp_maxretry
  xrdp_maxretry=$(grep -A 10 "^\[xrdp\]" "${FAIL2BAN_LOCAL}" | grep "^maxretry" | awk '{print $3}')
  [[ "${xrdp_maxretry}" == "5" ]]
}

@test "SEC-013: fail2ban ban period is 10 minutes (600 seconds)" {
  run fail2ban_configure
  assert_success
  
  # Verify bantime in both jails
  local sshd_bantime
  sshd_bantime=$(grep -A 10 "^\[sshd\]" "${FAIL2BAN_LOCAL}" | grep "^bantime" | awk '{print $3}')
  [[ "${sshd_bantime}" == "600" ]]
  
  local xrdp_bantime
  xrdp_bantime=$(grep -A 10 "^\[xrdp\]" "${FAIL2BAN_LOCAL}" | grep "^bantime" | awk '{print $3}')
  [[ "${xrdp_bantime}" == "600" ]]
}

@test "SEC-013: fail2ban failure window is 10 minutes (600 seconds)" {
  run fail2ban_configure
  assert_success
  
  # Verify findtime in both jails
  local sshd_findtime
  sshd_findtime=$(grep -A 10 "^\[sshd\]" "${FAIL2BAN_LOCAL}" | grep "^findtime" | awk '{print $3}')
  [[ "${sshd_findtime}" == "600" ]]
  
  local xrdp_findtime
  xrdp_findtime=$(grep -A 10 "^\[xrdp\]" "${FAIL2BAN_LOCAL}" | grep "^findtime" | awk '{print $3}')
  [[ "${xrdp_findtime}" == "600" ]]
}

@test "SEC-013: Custom xrdp filter created" {
  run fail2ban_configure
  assert_success
  
  # Verify xrdp filter file created
  [[ -f "${TEST_ROOT}/etc/fail2ban/filter.d/xrdp.conf" ]]
  
  # Verify filter has failregex
  run grep -q "failregex" "${TEST_ROOT}/etc/fail2ban/filter.d/xrdp.conf"
  assert_success
}

@test "SEC-013: fail2ban service enabled and started" {
  run fail2ban_enable
  assert_success
  
  # Verify systemctl commands logged
  run grep -qE "systemctl (restart|start) fail2ban" "${LOG_FILE}"
  assert_success
  
  run grep -q "systemctl enable fail2ban" "${LOG_FILE}"
  assert_success
}

@test "SEC-013: fail2ban verification checks service status" {
  run fail2ban_verify
  assert_success
  
  # Verify service check logged
  run grep -q "fail2ban-client status" "${LOG_FILE}"
  assert_success
}

@test "SEC-013: Transaction log records fail2ban configuration" {
  run fail2ban_configure
  assert_success
  
  # Verify rollback commands logged
  run grep -q "rm -f ${FAIL2BAN_LOCAL}" "${TRANSACTION_LOG}"
  assert_success
}

# =============================================================================
# Integration Tests
# =============================================================================

@test "Full firewall configuration completes successfully" {
  run firewall_execute
  assert_success
  
  # Verify checkpoint created (with .checkpoint extension)
  [[ -f "${CHECKPOINT_DIR}/firewall-config.checkpoint" ]]
  
  # Verify all steps logged
  run grep -q "Firewall configuration completed successfully" "${LOG_FILE}"
  assert_success
}

@test "Full fail2ban configuration completes successfully" {
  # Create firewall checkpoint first (prerequisite)
  checkpoint_create "firewall-config"
  
  run fail2ban_execute
  assert_success
  
  # Verify checkpoint created (with .checkpoint extension)
  [[ -f "${CHECKPOINT_DIR}/fail2ban-config.checkpoint" ]]
  
  # Verify all steps logged
  run grep -q "fail2ban configuration completed successfully" "${LOG_FILE}"
  assert_success
}

@test "Firewall and fail2ban work together" {
  # Configure firewall first
  run firewall_execute
  assert_success
  
  # Then configure fail2ban
  run fail2ban_execute
  assert_success
  
  # Verify both configured (with .checkpoint extension)
  [[ -f "${CHECKPOINT_DIR}/firewall-config.checkpoint" ]]
  [[ -f "${CHECKPOINT_DIR}/fail2ban-config.checkpoint" ]]
}

@test "Idempotency: Firewall skips if already configured" {
  # First run
  run firewall_execute
  assert_success
  
  # Second run should skip (checkpoint already exists)
  run firewall_execute
  assert_success
  run grep -q "Firewall already configured, skipping" "${LOG_FILE}"
  assert_success
}

@test "Idempotency: fail2ban skips if already configured" {
  # Create prerequisites
  checkpoint_create "firewall-config"
  
  # First run
  run fail2ban_execute
  assert_success
  
  # Second run should skip (checkpoint already exists)
  run fail2ban_execute
  assert_success
  run grep -q "fail2ban already configured, skipping" "${LOG_FILE}"
  assert_success
}
