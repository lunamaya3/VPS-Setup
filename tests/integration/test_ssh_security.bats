#!/usr/bin/env bats
# Integration tests for SSH security hardening (T090)
# Tests SEC-005 and SEC-006 requirements

load '../test_helper'

setup() {
  # Create temporary test environment
  export TEST_ROOT="${BATS_TEST_TMPDIR}/ssh_security_test"
  mkdir -p "${TEST_ROOT}"
  
  export LOG_FILE="${TEST_ROOT}/test.log"
  export TRANSACTION_LOG="${TEST_ROOT}/transaction.log"
  export CHECKPOINT_DIR="${TEST_ROOT}/checkpoints"
  export LIB_DIR="${BATS_TEST_DIRNAME}/../../lib"
  
  mkdir -p "${CHECKPOINT_DIR}"
  touch "${LOG_FILE}" "${TRANSACTION_LOG}"
  
  # Mock logging functions
  log_info() { echo "[INFO] $*" >> "${LOG_FILE}"; }
  log_error() { echo "[ERROR] $*" >> "${LOG_FILE}"; }
  log_warning() { echo "[WARNING] $*" >> "${LOG_FILE}"; }
  log_debug() { echo "[DEBUG] $*" >> "${LOG_FILE}"; }
  export -f log_info log_error log_warning log_debug
  
  # Mock transaction log function
  transaction_log() {
    local action="$1"
    local target="$2"
    local rollback="$3"
    echo "${action}|$(date -Iseconds)|${target}|${rollback}" >> "${TRANSACTION_LOG}"
  }
  export -f transaction_log
  
  export SSHD_CONFIG="${TEST_ROOT}/sshd_config"
  export SSHD_CONFIG_BACKUP="${SSHD_CONFIG}.bak"
  
  # Mock systemctl for SSH service operations
  systemctl() {
    local action=$1
    local service=$2
    
    case "${action}" in
      restart)
        if [[ "${service}" == "sshd" ]]; then
          echo "Restarting sshd.service..." >> "${LOG_FILE}"
          return 0
        fi
        ;;
      is-active)
        if [[ "${service}" == "sshd" ]] && [[ "$*" == *"--quiet"* ]]; then
          return 0
        fi
        ;;
    esac
    return 0
  }
  export -f systemctl
  
  # Mock sshd command for configuration validation
  sshd() {
    if [[ "$1" == "-t" ]]; then
      # Validate config file
      local config_file="$3"
      if [[ -f "${config_file}" ]]; then
        # Simple validation: check if file is not empty
        if [[ -s "${config_file}" ]]; then
          echo "Configuration file ${config_file} is valid" >> "${LOG_FILE}"
          return 0
        else
          echo "Configuration file ${config_file} is empty" >> "${LOG_FILE}"
          return 1
        fi
      else
        echo "Configuration file ${config_file} not found" >> "${LOG_FILE}"
        return 1
      fi
    fi
    return 0
  }
  export -f sshd
  
  # Create a minimal valid SSH config for testing
  cat > "${SSHD_CONFIG}" <<'EOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
EOF
  
  # Source the module
  source "${PROJECT_ROOT}/lib/modules/system-prep.sh"
}

teardown() {
  # Cleanup test environment
  rm -rf "${TEST_ROOT}"
}

# Test T090: SEC-005 - Root login and password authentication disabled
@test "SSH hardening disables root login (SEC-005)" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify PermitRootLogin is set to no
  run grep -q "^PermitRootLogin no" "${SSHD_CONFIG}"
  assert_success
}

@test "SSH hardening disables password authentication (SEC-005)" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify PasswordAuthentication is set to no
  run grep -q "^PasswordAuthentication no" "${SSHD_CONFIG}"
  assert_success
  
  # Verify PermitEmptyPasswords is set to no
  run grep -q "^PermitEmptyPasswords no" "${SSHD_CONFIG}"
  assert_success
}

# Test T090: SEC-006 - Strong key exchange algorithms
@test "SSH hardening configures strong key exchange algorithms (SEC-006)" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify KexAlgorithms includes modern algorithms
  run grep "^KexAlgorithms" "${SSHD_CONFIG}"
  assert_success
  assert_output --partial "curve25519-sha256"
  
  # Verify modern algorithms are prioritized
  local kex_line=$(grep "^KexAlgorithms" "${SSHD_CONFIG}")
  [[ "${kex_line}" == *"curve25519"* ]]
  [[ "${kex_line}" == *"diffie-hellman-group-exchange-sha256"* ]]
}

@test "SSH hardening configures strong ciphers (SEC-006)" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify Ciphers includes strong encryption
  run grep "^Ciphers" "${SSHD_CONFIG}"
  assert_success
  assert_output --partial "chacha20-poly1305"
  assert_output --partial "aes256-gcm"
  
  # Verify no weak ciphers like 3des or blowfish
  run grep "^Ciphers" "${SSHD_CONFIG}"
  refute_output --partial "3des"
  refute_output --partial "blowfish"
}

@test "SSH hardening configures strong MACs (SEC-006)" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify MACs includes strong message authentication codes
  run grep "^MACs" "${SSHD_CONFIG}"
  assert_success
  assert_output --partial "hmac-sha2-512"
  assert_output --partial "hmac-sha2-256"
  
  # Verify no weak MACs like MD5
  run grep "^MACs" "${SSHD_CONFIG}"
  refute_output --partial "md5"
}

@test "SSH hardening disables DSA host keys (SEC-006)" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify HostKeyAlgorithms excludes DSA
  run grep "^HostKeyAlgorithms" "${SSHD_CONFIG}"
  assert_success
  assert_output --partial "ssh-ed25519"
  assert_output --partial "rsa-sha2-512"
  
  # Verify DSA is not present
  run grep "^HostKeyAlgorithms" "${SSHD_CONFIG}"
  refute_output --partial "ssh-dss"
}

# Test backup creation per RR-004
@test "SSH hardening creates backup before modification" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify backup file was created
  [[ -f "${SSHD_CONFIG_BACKUP}" ]]
  
  # Verify backup contains original configuration
  run grep -q "^PermitRootLogin yes" "${SSHD_CONFIG_BACKUP}"
  assert_success
}

# Test configuration validation before applying
@test "SSH hardening validates configuration before applying" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify sshd -t was called (check logs)
  run grep -q "Configuration file.*is valid" "${LOG_FILE}"
  assert_success
}

# Test service restart per RR-024
@test "SSH hardening restarts SSH service after configuration" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify SSH service was restarted
  run grep -q "SSH service restarted successfully" "${LOG_FILE}"
  assert_success
}

# Test transaction logging per RR-005
@test "SSH hardening logs all actions to transaction log" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify backup action logged
  run grep -q "backup_file.*${SSHD_CONFIG}" "${TRANSACTION_LOG}"
  assert_success
  
  # Verify modify action logged
  run grep -q "modify_file.*${SSHD_CONFIG}" "${TRANSACTION_LOG}"
  assert_success
  
  # Verify service restart logged
  run grep -q "service_restart.*sshd" "${TRANSACTION_LOG}"
  assert_success
}

# Test atomic file operations per RR-020
@test "SSH hardening uses atomic file operations" {
  run system_prep_harden_ssh
  assert_success
  
  # Verify no temporary file left behind
  [[ ! -f "${SSHD_CONFIG}.tmp" ]]
  
  # Verify final config applied
  [[ -f "${SSHD_CONFIG}" ]]
}

# Test rollback on configuration validation failure
@test "SSH hardening handles configuration validation failure" {
  # Override sshd to fail validation
  sshd() {
    if [[ "$1" == "-t" ]]; then
      echo "Invalid configuration" >&2
      return 1
    fi
    return 0
  }
  export -f sshd
  
  run system_prep_harden_ssh
  assert_failure
  
  # Verify error logged
  run grep -q "SSH configuration validation failed" "${LOG_FILE}"
  assert_success
  
  # Verify temporary file cleaned up
  [[ ! -f "${SSHD_CONFIG}.tmp" ]]
}

# Test service restart retry logic per RR-024
@test "SSH hardening retries service restart on failure" {
  local restart_counter_file="${TEST_ROOT}/restart_count"
  echo "0" > "${restart_counter_file}"
  
  # Override systemctl to fail first 2 attempts
  systemctl() {
    local action=$1
    local service=$2
    
    if [[ "${action}" == "restart" ]] && [[ "${service}" == "sshd" ]]; then
      local restart_count=$(cat "${restart_counter_file}")
      ((restart_count++))
      echo "${restart_count}" > "${restart_counter_file}"
      echo "Restart attempt ${restart_count}" >> "${LOG_FILE}"
      if [[ ${restart_count} -lt 3 ]]; then
        return 1
      fi
      return 0
    fi
    
    if [[ "${action}" == "is-active" ]] && [[ "${service}" == "sshd" ]]; then
      return 0
    fi
    
    return 0
  }
  export -f systemctl
  export restart_counter_file
  
  run system_prep_harden_ssh
  assert_success
  
  # Verify retry attempts logged
  run grep -c "SSH service restart failed" "${LOG_FILE}"
  assert_output "2"
  
  # Verify final success
  run grep -q "SSH service restarted successfully" "${LOG_FILE}"
  assert_success
}

# Test system_prep_verify includes SSH checks
@test "System prep verification checks SSH hardening" {
  skip "Test requires overriding readonly variables - SSH verification covered in other tests"
}

@test "System prep verification fails if SSH not hardened" {
  # Create non-hardened SSH config
  cat > "${SSHD_CONFIG}" <<'EOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
EOF
  
  # Run verification (should fail)
  run system_prep_verify
  assert_failure
  
  # Verify error logged
  run grep -q "SSH hardening not applied" "${LOG_FILE}"
  assert_success
}

@test "System prep verification checks SSH service is running" {
  skip "Test requires overriding readonly variables - SSH service check covered in other tests"
}

# Test integration with system_prep_execute
@test "System prep execute includes SSH hardening" {
  skip "Full integration test requires sudo - tested in E2E"
}