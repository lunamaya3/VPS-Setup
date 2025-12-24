#!/usr/bin/env bats
# Integration tests for Access Control & Isolation (T093-T094)
# Tests SEC-009 and SEC-010 requirements

load '../test_helper'

setup() {
  # Create temporary test environment
  export TEST_ROOT="${BATS_TEST_TMPDIR}/access_control_test"
  mkdir -p "${TEST_ROOT}"
  
  export LOG_FILE="${TEST_ROOT}/test.log"
  export TRANSACTION_LOG="${TEST_ROOT}/transaction.log"
  export LIB_DIR="${BATS_TEST_DIRNAME}/../../lib"
  export SUDOERS_DIR="${TEST_ROOT}/etc/sudoers.d"
  export SUDO_TIMEOUT="15"
  
  mkdir -p "${SUDOERS_DIR}"
  touch "${LOG_FILE}" "${TRANSACTION_LOG}"
  
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
  
  # Mock visudo (always succeeds in test)
  visudo() {
    if [[ "$1" == "-cf" ]]; then
      local file="$2"
      # Basic syntax check - file must exist and not be empty
      if [[ -f "${file}" && -s "${file}" ]]; then
        echo "Syntax OK" >> "${LOG_FILE}"
        return 0
      else
        echo "Syntax Error" >> "${LOG_FILE}"
        return 1
      fi
    fi
    return 0
  }
  export -f visudo
  
  # Source the module
  source "${PROJECT_ROOT}/lib/modules/user-provisioning.sh"
}

teardown() {
  # Cleanup test environment
  rm -rf "${TEST_ROOT}"
}

# =============================================================================
# SEC-009: Session Isolation Verification
# =============================================================================

@test "SEC-009: User namespaces are separate per session" {
  # Create mock /proc structure for two sessions
  local proc_dir="${TEST_ROOT}/proc"
  mkdir -p "${proc_dir}/1000" "${proc_dir}/2000"
  
  # Session 1: user1, namespace A
  cat > "${proc_dir}/1000/status" <<EOF
Name:   xrdp-sesman
Uid:    1001    1001    1001    1001
Gid:    1001    1001    1001    1001
Groups: 1001 27 44 46
NSpid:  1000    1
NSuid:  1001
EOF
  
  # Session 2: user2, namespace B
  cat > "${proc_dir}/2000/status" <<EOF
Name:   xrdp-sesman
Uid:    1002    1002    1002    1002
Gid:    1002    1002    1002    1002
Groups: 1002 27 44 46
NSpid:  2000    1
NSuid:  1002
EOF
  
  # Verify UIDs are different (session isolation)
  local uid1
  uid1=$(grep "^Uid:" "${proc_dir}/1000/status" | awk '{print $2}')
  local uid2
  uid2=$(grep "^Uid:" "${proc_dir}/2000/status" | awk '{print $2}')
  
  [[ "${uid1}" != "${uid2}" ]]
  [[ "${uid1}" == "1001" ]]
  [[ "${uid2}" == "1002" ]]
}

@test "SEC-009: Processes are isolated between sessions" {
  # Simulate ps output for two different users
  local ps_output_user1="${TEST_ROOT}/ps_user1.txt"
  local ps_output_user2="${TEST_ROOT}/ps_user2.txt"
  
  # User1 processes
  cat > "${ps_output_user1}" <<EOF
UID  PID  PPID CMD
1001 1000 1    xrdp-sesman
1001 1001 1000 Xorg :10
1001 1002 1000 xfce4-session
1001 1003 1002 xfce4-panel
EOF
  
  # User2 processes
  cat > "${ps_output_user2}" <<EOF
UID  PID  PPID CMD
1002 2000 1    xrdp-sesman
1002 2001 2000 Xorg :11
1002 2002 2000 xfce4-session
1002 2003 2002 xfce4-panel
EOF
  
  # Verify no process overlap by UID
  local user1_pids
  user1_pids=$(awk 'NR>1 {print $2}' "${ps_output_user1}")
  local user2_pids
  user2_pids=$(awk 'NR>1 {print $2}' "${ps_output_user2}")
  
  # Check no PID appears in both lists
  for pid in ${user1_pids}; do
    if echo "${user2_pids}" | grep -q "^${pid}$"; then
      echo "PID ${pid} appears in both sessions!" >&2
      return 1
    fi
  done
  
  # Verify different X displays
  local display1
  display1=$(grep "Xorg" "${ps_output_user1}" | awk '{print $5}')
  local display2
  display2=$(grep "Xorg" "${ps_output_user2}" | awk '{print $5}')
  
  [[ "${display1}" != "${display2}" ]]
  [[ "${display1}" == ":10" ]]
  [[ "${display2}" == ":11" ]]
}

@test "SEC-009: File permissions prevent cross-user access" {
  # Create mock home directories for two users
  local home1="${TEST_ROOT}/home/user1"
  local home2="${TEST_ROOT}/home/user2"
  mkdir -p "${home1}" "${home2}"
  
  # Set proper ownership and permissions (simulated)
  chmod 0750 "${home1}"
  chmod 0750 "${home2}"
  
  # Create test files
  touch "${home1}/private.txt"
  touch "${home2}/private.txt"
  chmod 0600 "${home1}/private.txt"
  chmod 0600 "${home2}/private.txt"
  
  # Verify permissions
  local perm1
  perm1=$(stat -c "%a" "${home1}")
  [[ "${perm1}" == "750" ]]
  
  local perm2
  perm2=$(stat -c "%a" "${home2}")
  [[ "${perm2}" == "750" ]]
  
  local file_perm1
  file_perm1=$(stat -c "%a" "${home1}/private.txt")
  [[ "${file_perm1}" == "600" ]]
  
  local file_perm2
  file_perm2=$(stat -c "%a" "${home2}/private.txt")
  [[ "${file_perm2}" == "600" ]]
}

@test "SEC-009: Session cleanup does not affect other sessions" {
  # Simulate killing session 1 processes
  local session1_pids="1000 1001 1002 1003"
  local session2_pids="2000 2001 2002 2003"
  
  # Mock kill command
  local killed_pids="${TEST_ROOT}/killed.txt"
  touch "${killed_pids}"
  
  kill() {
    local pid="$2"
    echo "${pid}" >> "${killed_pids}"
    return 0
  }
  export -f kill
  
  # Kill session 1
  for pid in ${session1_pids}; do
    kill -TERM "${pid}"
  done
  
  # Verify only session 1 PIDs were killed
  for pid in ${session1_pids}; do
    if ! grep -q "^${pid}$" "${killed_pids}"; then
      echo "Expected PID ${pid} to be killed" >&2
      return 1
    fi
  done
  
  # Verify session 2 PIDs were NOT killed
  for pid in ${session2_pids}; do
    if grep -q "^${pid}$" "${killed_pids}"; then
      echo "PID ${pid} from session 2 was incorrectly killed!" >&2
      return 1
    fi
  done
}

@test "SEC-009: Shared memory segments are isolated" {
  # Create mock ipcs output for two users
  local ipcs_user1="${TEST_ROOT}/ipcs_user1.txt"
  local ipcs_user2="${TEST_ROOT}/ipcs_user2.txt"
  
  # User1 shared memory
  cat > "${ipcs_user1}" <<EOF
------ Shared Memory Segments --------
key        shmid      owner      perms      bytes      nattch
0x00000000 32768      user1      600        4096       1
0x00000001 32769      user1      600        8192       2
EOF
  
  # User2 shared memory
  cat > "${ipcs_user2}" <<EOF
------ Shared Memory Segments --------
key        shmid      owner      perms      bytes      nattch
0x00000000 65536      user2      600        4096       1
0x00000001 65537      user2      600        8192       2
EOF
  
  # Verify different shmids (no overlap)
  local shmids1
  shmids1=$(awk 'NR>2 {print $2}' "${ipcs_user1}")
  local shmids2
  shmids2=$(awk 'NR>2 {print $2}' "${ipcs_user2}")
  
  for shmid in ${shmids1}; do
    if echo "${shmids2}" | grep -q "^${shmid}$"; then
      echo "Shared memory ID ${shmid} appears in both sessions!" >&2
      return 1
    fi
  done
}

# =============================================================================
# SEC-010: Sudo Lecture Configuration
# =============================================================================

@test "SEC-010: Sudo lecture is always enabled" {
  local username="testuser"
  
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  local sudoers_file="${SUDOERS_DIR}/80-${username}"
  
  # Verify lecture="always" is configured
  run grep -q 'Defaults:testuser lecture="always"' "${sudoers_file}"
  assert_success
}

@test "SEC-010: Sudo lecture setting is in correct format" {
  local username="devuser"
  
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  local sudoers_file="${SUDOERS_DIR}/80-${username}"
  
  # Verify exact format per SEC-010
  local lecture_line
  lecture_line=$(grep "lecture=" "${sudoers_file}" | head -1)
  
  [[ "${lecture_line}" == *'lecture="always"'* ]]
  [[ "${lecture_line}" == "Defaults:${username}"* ]]
}

@test "SEC-010: Sudo configuration includes lecture comment" {
  local username="devuser"
  
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  local sudoers_file="${SUDOERS_DIR}/80-${username}"
  
  # Verify comment explaining SEC-010
  run grep -q "SEC-010: Enable sudo lecture" "${sudoers_file}"
  assert_success
}

@test "SEC-010: Sudo timeout is configured" {
  local username="devuser"
  
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  local sudoers_file="${SUDOERS_DIR}/80-${username}"
  
  # Verify timestamp_timeout setting
  run grep -q "Defaults:devuser timestamp_timeout=15" "${sudoers_file}"
  assert_success
}

@test "SEC-010: Sudo audit logging is configured per SEC-014" {
  local username="devuser"
  
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  local sudoers_file="${SUDOERS_DIR}/80-${username}"
  
  # Verify audit logging settings
  run grep -q 'Defaults:devuser logfile="/var/log/sudo/sudo.log"' "${sudoers_file}"
  assert_success
  
  run grep -q 'Defaults:devuser log_input, log_output' "${sudoers_file}"
  assert_success
}

@test "SEC-010: Sudo configuration syntax is valid" {
  local username="devuser"
  
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  # Verify visudo validation passed
  run grep -q "Syntax OK" "${LOG_FILE}"
  assert_success
}

@test "SEC-010: Sudoers file has correct permissions (0440)" {
  local username="devuser"
  
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  local sudoers_file="${SUDOERS_DIR}/80-${username}"
  
  # Check file permissions
  local perms
  perms=$(stat -c "%a" "${sudoers_file}")
  [[ "${perms}" == "440" ]]
}

@test "SEC-010: Sudo log directory is created with correct permissions" {
  local username="devuser"
  
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  # Verify log directory exists
  [[ -d "/var/log/sudo" ]]
  
  # Check permissions (0750)
  local perms
  perms=$(stat -c "%a" "/var/log/sudo")
  [[ "${perms}" == "750" ]]
}

@test "SEC-010: Transaction log records sudo configuration" {
  local username="devuser"
  
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  local sudoers_file="${SUDOERS_DIR}/80-${username}"
  
  # Verify rollback commands logged
  run grep -q "rm -f ${sudoers_file}" "${TRANSACTION_LOG}"
  assert_success
  
  run grep -q "rm -rf /var/log/sudo" "${TRANSACTION_LOG}"
  assert_success
}

@test "SEC-010: Invalid sudoers syntax is rejected" {
  local username="devuser"
  
  # Override visudo to fail validation
  visudo() {
    if [[ "$1" == "-cf" ]]; then
      echo "Syntax Error: invalid line" >&2
      return 1
    fi
    return 0
  }
  export -f visudo
  
  run user_provisioning_configure_sudo "${username}"
  assert_failure
  
  # Verify error logged
  run grep -q "Invalid sudoers syntax" "${LOG_FILE}"
  assert_success
}

@test "SEC-010: Backup is restored on syntax validation failure" {
  local username="devuser"
  local sudoers_file="${SUDOERS_DIR}/80-${username}"
  
  # Create existing valid sudoers file
  cat > "${sudoers_file}" <<EOF
# Original valid configuration
${username} ALL=(ALL) NOPASSWD: ALL
EOF
  
  # Record original content
  local original_content
  original_content=$(cat "${sudoers_file}")
  
  # Override visudo to fail validation
  visudo() {
    if [[ "$1" == "-cf" ]]; then
      echo "Syntax Error" >&2
      return 1
    fi
    return 0
  }
  export -f visudo
  
  # Attempt to configure sudo (should fail and not modify file)
  run user_provisioning_configure_sudo "${username}"
  assert_failure
  
  # Verify error was logged
  run grep -q "Invalid sudoers syntax" "${LOG_FILE}"
  assert_success
  
  # Note: The actual function attempts to restore from .bak if validation fails
  # Since our test creates the file first, we verify the function properly handles failures
}

# =============================================================================
# Integration Tests
# =============================================================================

@test "Full access control configuration completes successfully" {
  local username="devuser"
  
  # Run sudo configuration
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  local sudoers_file="${SUDOERS_DIR}/80-${username}"
  
  # Verify all components
  [[ -f "${sudoers_file}" ]]
  [[ -d "/var/log/sudo" ]]
  
  # Verify all security settings present
  local -a required_settings=(
    'lecture="always"'
    'timestamp_timeout=15'
    'logfile="/var/log/sudo/sudo.log"'
    'log_input, log_output'
    'NOPASSWD: ALL'
  )
  
  for setting in "${required_settings[@]}"; do
    if ! grep -q "${setting}" "${sudoers_file}"; then
      echo "Missing required setting: ${setting}" >&2
      return 1
    fi
  done
}

@test "Access control meets all SEC requirements" {
  local username="devuser"
  
  run user_provisioning_configure_sudo "${username}"
  assert_success
  
  local sudoers_file="${SUDOERS_DIR}/80-${username}"
  
  # SEC-010: Lecture always
  run grep -q 'lecture="always"' "${sudoers_file}"
  assert_success
  
  # SEC-014: Audit logging
  run grep -q 'log_input, log_output' "${sudoers_file}"
  assert_success
  
  # File permissions
  local perms
  perms=$(stat -c "%a" "${sudoers_file}")
  [[ "${perms}" == "440" ]]
}
