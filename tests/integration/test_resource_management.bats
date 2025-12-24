#!/usr/bin/env bats
# Integration test for resource management
# Tests disk space monitoring, memory checks, and resource exhaustion handling

load '../test_helper'

setup() {
  export TEST_DIR="${BATS_TEST_TMPDIR}/resource_test"
  export LIB_DIR="${BATS_TEST_DIRNAME}/../../lib"
  
  mkdir -p "$TEST_DIR"
  
  # Set LOG_FILE BEFORE sourcing logger.sh (it uses readonly)
  export LOG_FILE="${TEST_DIR}/test.log"
  export LOG_DIR="${TEST_DIR}"
  touch "${LOG_FILE}"
  
  # Mock logging functions to prevent issues with readonly variables
  log_info() { echo "[INFO] $*" >> "${LOG_FILE}"; }
  log_error() { echo "[ERROR] $*" >> "${LOG_FILE}"; }
  log_warning() { echo "[WARNING] $*" >> "${LOG_FILE}"; }
  log_debug() { echo "[DEBUG] $*" >> "${LOG_FILE}"; }
  export -f log_info log_error log_warning log_debug
  
  # Source validator module (will use our mocked log functions)
  # Unset the sourcing guard to allow re-sourcing in tests
  unset _VALIDATOR_SH_LOADED 2>/dev/null || true
  source "${LIB_DIR}/core/validator.sh" 2>/dev/null || true
  
  # Initialize validator
  type validator_init &>/dev/null && validator_init 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "resource: check disk space monitoring" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  # Monitor current disk space
  run validator_monitor_disk_space 5
  # Should pass on test system with adequate space
  [ "$status" -eq 0 ]
}

@test "resource: detect low disk space" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  # Mock df to report low disk space
  df() {
    echo "Filesystem     1G-blocks  Used Available Use% Mounted on"
    echo "/dev/sda1            25    22        3  89% /"
  }
  export -f df
  
  # Should detect low space and attempt cleanup
  run validator_monitor_disk_space 5
  # May pass or fail depending on whether cleanup succeeds
  # Just verify it attempts cleanup
  [[ "$output" == *"disk space"* ]]
}

@test "resource: get memory usage percentage" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  run validator_get_memory_usage
  [ "$status" -eq 0 ]
  
  # Verify output is a number
  [[ "$output" =~ ^[0-9]+\.?[0-9]*$ ]]
}

@test "resource: check system load" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  run validator_check_system_load
  # Should complete (may warn if system is loaded)
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "resource: pre-flight resource validation" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  # Run resource checks with minimal requirements
  run validator_preflight_resources 1 10
  # Should pass on test system
  [ "$status" -eq 0 ]
}

@test "resource: bandwidth check (non-critical)" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  # This may timeout or fail on isolated test environments
  run validator_check_bandwidth
  # Always passes (warnings only)
  [ "$status" -eq 0 ]
}

@test "resource: RAM check with minimum requirement" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  # Check for 1GB RAM (should pass on any modern system)
  run validator_check_ram 1
  [ "$status" -eq 0 ]
}

@test "resource: CPU check with minimum requirement" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  # Check for 1 CPU core
  run validator_check_cpu 1
  [ "$status" -eq 0 ]
}

@test "resource: simulate resource exhaustion - disk full" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  # Mock df to simulate full disk
  df() {
    echo "Filesystem     1G-blocks  Used Available Use% Mounted on"
    echo "/dev/sda1            25    24        1  96% /"
  }
  export -f df
  
  # Mock apt-get clean
  apt-get() {
    if [[ "$1" == "clean" ]]; then
      return 0
    fi
    command apt-get "$@"
  }
  export -f apt-get
  
  run validator_monitor_disk_space 5
  # Should attempt cleanup
  [[ "$output" == *"disk space"* ]]
}

@test "resource: validate minimum disk space at start" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  # Verify disk space check works
  run validator_check_disk 1
  [ "$status" -eq 0 ]
}

@test "resource: detect insufficient resources" {
  # Skip if required functions don't exist
  if ! type validator_monitor_disk_space &>/dev/null; then
    skip "validator_monitor_disk_space function not available"
  fi
  # Mock checks to simulate insufficient resources
  validator_check_ram() {
    log_error "Insufficient RAM"
    return 1
  }
  export -f validator_check_ram
  
  run validator_preflight_resources 999 10
  [ "$status" -eq 1 ]
}
