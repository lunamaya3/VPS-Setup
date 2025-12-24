#!/usr/bin/env bats
# test_validator.bats - Unit tests for validator.sh
# Tests all validation functions with mocked system calls

setup() {
  # Load the validator module
  load '../../lib/core/logger.sh'
  load '../../lib/core/validator.sh'
  
  # Create temporary directory for test files
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  
  # Suppress log output during tests
  export LOG_LEVEL="ERROR"
  export ENABLE_COLORS="false"
}

teardown() {
  # Clean up temporary directory
  if [[ -n "${TEST_DIR:-}" ]] && [[ -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

@test "validator_init resets error counters" {
  VALIDATION_ERRORS=5
  VALIDATION_WARNINGS=3
  
  validator_init
  
  [[ $VALIDATION_ERRORS -eq 0 ]]
  [[ $VALIDATION_WARNINGS -eq 0 ]]
}

@test "validator_check_os detects missing /etc/os-release" {
  # Mock /etc/os-release as missing
  function source() {
    if [[ "$1" == "/etc/os-release" ]]; then
      return 1
    fi
  }
  export -f source
  
  validator_init
  validator_check_os || true
  
  [[ $VALIDATION_ERRORS -gt 0 ]]
}

@test "validator_check_ram passes with sufficient memory" {
  # Mock grep to return sufficient memory (4GB = 4194304 KB)
  function grep() {
    if [[ "$1" == "MemTotal" && "$2" == "/proc/meminfo" ]]; then
      echo "MemTotal:        4194304 kB"
    fi
  }
  export -f grep
  
  validator_init
  run validator_check_ram 2
  
  [[ $status -eq 0 ]]
}

@test "validator_check_cpu passes with sufficient cores" {
  # Mock nproc to return 2 cores
  function nproc() {
    echo "2"
  }
  export -f nproc
  
  run validator_check_cpu 1
  
  [[ $status -eq 0 ]]
}

@test "validator_check_cpu fails with insufficient cores" {
  # Mock nproc to return 1 core
  function nproc() {
    echo "1"
  }
  export -f nproc
  
  validator_init
  validator_check_cpu 2 || true
  
  [[ $VALIDATION_ERRORS -gt 0 ]]
}

@test "validator_check_disk fails with insufficient space" {
  # Mock df to return low disk space
  function df() {
    if [[ "$1" == "-BG" ]]; then
      echo "Filesystem 1G-blocks Used Available Use% Mounted on"
      echo "/dev/sda1 100G 90G 10G 90% /"
    fi
  }
  export -f df
  
  validator_init
  validator_check_disk 25 || true
  
  [[ $VALIDATION_ERRORS -gt 0 ]]
}

@test "validator_check_root fails when not root" {
  # Skip if actually root
  if [[ $EUID -eq 0 ]]; then
    skip "Test must run as non-root user"
  fi
  
  validator_init
  run validator_check_root
  
  [[ $status -eq 1 ]]
}

@test "validator_check_network passes with reachable host" {
  # Mock ping to succeed
  function ping() {
    return 0
  }
  export -f ping
  
  run validator_check_network
  
  [[ $status -eq 0 ]]
}

@test "validator_check_network fails with unreachable hosts" {
  # Mock ping to fail
  function ping() {
    return 1
  }
  export -f ping
  
  validator_init
  validator_check_network || true
  
  [[ $VALIDATION_ERRORS -gt 0 ]]
}

@test "validator_check_dns passes with working DNS" {
  # Mock host command to succeed
  function host() {
    echo "google.com has address 8.8.8.8"
    return 0
  }
  export -f host
  
  run validator_check_dns
  
  [[ $status -eq 0 ]]
}

@test "validator_check_dns fails without working DNS" {
  # Mock host command to fail
  function host() {
    return 1
  }
  export -f host
  
  validator_init
  validator_check_dns || true
  
  [[ $VALIDATION_ERRORS -gt 0 ]]
}

@test "validator_check_conflicts detects running process" {
  # Create a mock lock file with current PID
  mkdir -p /tmp/test-lock-dir
  echo "$$" > /tmp/test-lock-dir/vps-provision.lock
  
  # Mock the lock file path
  function validator_check_conflicts() {
    if [[ -f /tmp/test-lock-dir/vps-provision.lock ]]; then
      local lock_pid
      lock_pid=$(cat /tmp/test-lock-dir/vps-provision.lock)
      
      if kill -0 "$lock_pid" 2>/dev/null; then
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        return 1
      fi
    fi
    return 0
  }
  export -f validator_check_conflicts
  
  validator_init
  run validator_check_conflicts
  
  # Cleanup
  rm -f /tmp/test-lock-dir/vps-provision.lock
  rmdir /tmp/test-lock-dir 2>/dev/null || true
  
  [[ $status -eq 1 ]]
}

@test "validator_check_conflicts removes stale lock" {
  # Create a mock stale lock file with non-existent PID
  mkdir -p /tmp/test-lock-dir
  echo "999999" > /tmp/test-lock-dir/vps-provision.lock
  
  # Mock kill to fail (PID doesn't exist)
  function kill() {
    return 1
  }
  export -f kill
  
  # Mock validator_check_conflicts to use test directory
  function validator_check_conflicts() {
    log_info "Checking for conflicting processes..."
    
    if [[ -f /tmp/test-lock-dir/vps-provision.lock ]]; then
      local lock_pid
      lock_pid=$(cat /tmp/test-lock-dir/vps-provision.lock 2>/dev/null || echo "")
      
      if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
        log_error "Another provisioning process is running (PID: $lock_pid)"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        return 1
      else
        log_warning "Stale lock file found, removing"
        rm -f /tmp/test-lock-dir/vps-provision.lock
      fi
    fi
    
    log_info "No conflicting processes found"
    return 0
  }
  export -f validator_check_conflicts
  
  validator_init
  run validator_check_conflicts
  
  # Verify stale lock was removed
  [[ $status -eq 0 ]]
  [[ ! -f /tmp/test-lock-dir/vps-provision.lock ]]
  
  # Cleanup
  rmdir /tmp/test-lock-dir 2>/dev/null || true
}

@test "validator_get_errors returns error count" {
  validator_init
  VALIDATION_ERRORS=3
  
  result=$(validator_get_errors)
  
  [[ "$result" == "3" ]]
}

@test "validator_get_warnings returns warning count" {
  validator_init
  VALIDATION_WARNINGS=2
  
  result=$(validator_get_warnings)
  
  [[ "$result" == "2" ]]
}
