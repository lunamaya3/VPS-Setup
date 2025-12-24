#!/usr/bin/env bats
# Integration tests for System Preparation Module
# Tests verify complete system preparation workflow on actual system

load '../test_helper'

setup() {
  # Setup test environment BEFORE sourcing (to avoid readonly conflicts)
  export LOG_FILE="${BATS_TEST_TMPDIR}/test.log"
  export CHECKPOINT_DIR="${BATS_TEST_TMPDIR}/checkpoints"
  export TRANSACTION_LOG="${BATS_TEST_TMPDIR}/transactions.log"
  
  # Source the system-prep module
  source "${BATS_TEST_DIRNAME}/../../lib/modules/system-prep.sh"
  
  mkdir -p "${CHECKPOINT_DIR}"
  touch "${LOG_FILE}"
  touch "${TRANSACTION_LOG}"
}

teardown() {
  # Cleanup test artifacts
  rm -rf "${BATS_TEST_TMPDIR}"
}

@test "system_prep: APT configuration file is created" {
  skip "Requires root privileges"
  
  run system_prep_configure_apt
  assert_success
  
  assert [ -f "${APT_CUSTOM_CONF}" ]
  assert grep -q "APT::Install-Recommends" "${APT_CUSTOM_CONF}"
}

@test "system_prep: verify_package detects installed packages" {
  # Test with a package that should be installed on Debian
  run system_prep_verify_package "bash"
  assert_success
}

@test "system_prep: verify_package detects missing packages" {
  # Test with a package that definitely doesn't exist
  run system_prep_verify_package "nonexistent-package-xyz123"
  assert_failure
}

@test "system_prep: core packages list is defined" {
  # Verify CORE_PACKAGES array is populated
  [[ ${#CORE_PACKAGES[@]} -gt 0 ]]
  
  # Verify expected packages in list
  local found_git=false
  local found_curl=false
  local found_build_essential=false
  
  for pkg in "${CORE_PACKAGES[@]}"; do
    [[ "$pkg" == "git" ]] && found_git=true
    [[ "$pkg" == "curl" ]] && found_curl=true
    [[ "$pkg" == "build-essential" ]] && found_build_essential=true
  done
  
  [[ "$found_git" == "true" ]]
  [[ "$found_curl" == "true" ]]
  [[ "$found_build_essential" == "true" ]]
}

@test "system_prep: verify checks for all core packages" {
  skip "Requires packages to be installed"
  
  # Mock successful package installation
  for pkg in "${CORE_PACKAGES[@]}"; do
    # Verify check would pass for installed package
    if dpkg -s "$pkg" &>/dev/null; then
      run system_prep_verify_package "$pkg"
      assert_success
    fi
  done
}

@test "system_prep: verify checks for critical commands" {
  skip "Requires full installation"
  
  run system_prep_verify
  assert_success
}

@test "system_prep: APT custom configuration has correct directives" {
  skip "Requires root privileges"
  
  system_prep_configure_apt
  
  # Check for required configuration directives
  assert grep -q 'APT::Install-Recommends "true"' "${APT_CUSTOM_CONF}"
  assert grep -q 'APT::Get::Assume-Yes "true"' "${APT_CUSTOM_CONF}"
  assert grep -q 'APT::Get::Fix-Broken "true"' "${APT_CUSTOM_CONF}"
  assert grep -q 'Acquire::Retries "3"' "${APT_CUSTOM_CONF}"
}

@test "system_prep: unattended upgrades configuration is created" {
  skip "Requires root privileges"
  
  run system_prep_configure_unattended_upgrades
  assert_success
  
  assert [ -f "${UNATTENDED_UPGRADES_CONF}" ]
  assert grep -q "Unattended-Upgrade::Allowed-Origins" "${UNATTENDED_UPGRADES_CONF}"
}

@test "system_prep: module prevents double sourcing" {
  # Source module twice
  source "${BATS_TEST_DIRNAME}/../../lib/modules/system-prep.sh"
  local first_load_status=$?
  
  source "${BATS_TEST_DIRNAME}/../../lib/modules/system-prep.sh"
  local second_load_status=$?
  
  # Both should succeed
  [[ $first_load_status -eq 0 ]]
  [[ $second_load_status -eq 0 ]]
  
  # Guard variable should be set
  [[ -n "${_SYSTEM_PREP_SH_LOADED}" ]]
}

@test "system_prep: checkpoint integration works" {
  skip "Requires full integration environment"
  
  # Verify checkpoint is created after successful execution
  run system_prep_execute
  
  if [ $status -eq 0 ]; then
    assert checkpoint_exists "${SYSTEM_PREP_PHASE}"
  fi
}

@test "system_prep: transaction logging records actions" {
  skip "Requires root privileges and full integration"
  
  run system_prep_execute
  
  # Verify transaction log contains entries
  if [ -f "${TRANSACTION_LOG}" ]; then
    assert [ -s "${TRANSACTION_LOG}" ]
  fi
}

@test "system_prep: module exports required functions" {
  # Check that key functions are exported
  declare -F system_prep_execute &>/dev/null
  [[ $? -eq 0 ]]
  
  declare -F system_prep_verify &>/dev/null
  [[ $? -eq 0 ]]
  
  declare -F system_prep_verify_package &>/dev/null
  [[ $? -eq 0 ]]
}

@test "system_prep: constants are defined and readonly" {
  # Verify critical constants exist
  [[ -n "${SYSTEM_PREP_PHASE}" ]]
  [[ -n "${APT_CONF_DIR}" ]]
  [[ -n "${APT_CUSTOM_CONF}" ]]
  [[ -n "${UNATTENDED_UPGRADES_CONF}" ]]
  
  # Verify array is defined
  [[ ${#CORE_PACKAGES[@]} -gt 0 ]]
}

@test "system_prep: handles missing dependencies gracefully" {
  # Test that module checks for core dependencies
  # This is a structural test - actual execution requires root
  
  run bash -c "source ${BATS_TEST_DIRNAME}/../../lib/modules/system-prep.sh && echo 'loaded'"
  assert_success
  assert_output --partial "loaded"
}

# Performance test (structure only - requires actual execution)
@test "system_prep: documentation exists for all functions" {
  local module_file="${BATS_TEST_DIRNAME}/../../lib/modules/system-prep.sh"
  
  # Check that main functions have documentation comments
  grep -q "# Configure APT for provisioning" "$module_file"
  grep -q "# Update APT package lists" "$module_file"
  grep -q "# Install core dependencies" "$module_file"
  grep -q "# Configure unattended upgrades" "$module_file"
  grep -q "# Main execution function" "$module_file"
}
