#!/usr/bin/env bats
# Contract Tests: CLI Interface
# Validates all CLI flags and options per contracts/cli-interface.json
#
# These tests verify the command-line interface contract without executing
# provisioning logic. They test argument parsing, validation, help output,
# and error handling.

load '../test_helper'

# Setup/teardown
setup() {
  # Store original directory
  ORIGINAL_DIR="$(pwd)"
  
  # Navigate to project root
  cd "${BATS_TEST_DIRNAME}/../.." || exit 1
  
  # Set up test environment
  export PROJECT_ROOT="$(pwd)"
  export CLI_COMMAND="${PROJECT_ROOT}/bin/vps-provision"
  
  # Ensure CLI exists and is executable
  [[ -x "${CLI_COMMAND}" ]]
}

teardown() {
  cd "${ORIGINAL_DIR}" || true
}

# Test: --help flag
@test "CLI: --help displays help message" {
  run "${CLI_COMMAND}" --help
  
  assert_success
  assert_output --partial "VPS Developer Workstation Provisioning Tool"
  assert_output --partial "USAGE:"
  assert_output --partial "OPTIONS:"
  assert_output --partial "EXAMPLES:"
  assert_output --partial "EXIT CODES:"
}

@test "CLI: -h short flag displays help message" {
  run "${CLI_COMMAND}" -h
  
  assert_success
  assert_output --partial "VPS Developer Workstation Provisioning Tool"
}

# Test: --version flag
@test "CLI: --version displays version information" {
  run "${CLI_COMMAND}" --version
  
  assert_success
  assert_output --regexp "vps-provision version [0-9]+\.[0-9]+\.[0-9]+"
}

@test "CLI: -v short flag displays version information" {
  run "${CLI_COMMAND}" -v
  
  assert_success
  assert_output --regexp "vps-provision version [0-9]+\.[0-9]+\.[0-9]+"
}

# Test: Unknown option handling
@test "CLI: Unknown option produces error" {
  run "${CLI_COMMAND}" --unknown-option
  
  assert_failure
  assert_output --partial "Unknown option"
  assert_line --partial "vps-provision --help"
}

# Test: --config flag
@test "CLI: --config requires argument" {
  run "${CLI_COMMAND}" --config
  
  assert_failure
  assert_output --partial "Option --config requires an argument"
}

@test "CLI: --config with non-existent file produces error" {
  run "${CLI_COMMAND}" --config /nonexistent/path/config.conf
  
  assert_failure
  assert_output --partial "Configuration file not found"
}

# Test: --log-level flag
@test "CLI: --log-level requires argument" {
  run "${CLI_COMMAND}" --log-level
  
  assert_failure
  assert_output --partial "Option --log-level requires an argument"
}

@test "CLI: --log-level with invalid value produces error" {
  run "${CLI_COMMAND}" --log-level INVALID
  
  assert_failure
  assert_output --partial "Invalid log level"
}

@test "CLI: --log-level accepts valid values" {
  for level in DEBUG INFO WARNING ERROR; do
    # Can't fully test without running as root, but validate parsing
    # This will fail on prerequisites check, not argument validation
    run "${CLI_COMMAND}" --log-level "${level}" --help
    assert_success
  done
}

# Test: --username flag
@test "CLI: --username requires argument" {
  run "${CLI_COMMAND}" --username
  
  assert_failure
  assert_output --partial "Option --username requires an argument"
}

@test "CLI: --username validates format" {
  # Invalid: starts with number
  run "${CLI_COMMAND}" --username 123user
  
  assert_failure
  assert_output --partial "Invalid username format"
  
  # Invalid: too short
  run "${CLI_COMMAND}" --username ab
  
  assert_failure
  assert_output --partial "Invalid username format"
  
  # Invalid: contains uppercase
  run "${CLI_COMMAND}" --username UserName
  
  assert_failure
  assert_output --partial "Invalid username format"
}

# Test: --output-format flag
@test "CLI: --output-format requires argument" {
  run "${CLI_COMMAND}" --output-format
  
  assert_failure
  assert_output --partial "Option --output-format requires an argument"
}

@test "CLI: --output-format validates choices" {
  run "${CLI_COMMAND}" --output-format invalid
  
  assert_failure
  assert_output --partial "Invalid output format"
}

# Test: --skip-phase flag
@test "CLI: --skip-phase requires argument" {
  run "${CLI_COMMAND}" --skip-phase
  
  assert_failure
  assert_output --partial "Option --skip-phase requires an argument"
}

@test "CLI: --skip-phase can be specified multiple times" {
  # This will fail on root check, not argument parsing
  run "${CLI_COMMAND}" --skip-phase system-prep --skip-phase desktop-install --help
  
  assert_success
}

# Test: --only-phase flag
@test "CLI: --only-phase requires argument" {
  run "${CLI_COMMAND}" --only-phase
  
  assert_failure
  assert_output --partial "Option --only-phase requires an argument"
}

@test "CLI: --skip-phase and --only-phase conflict" {
  run "${CLI_COMMAND}" --skip-phase system-prep --only-phase desktop-install
  
  assert_failure
  assert_output --partial "cannot be used together"
}

# Test: --resume and --force conflict
@test "CLI: --resume and --force conflict" {
  run "${CLI_COMMAND}" --resume --force
  
  assert_failure
  assert_output --partial "cannot be used together"
}

# Test: Boolean flags
@test "CLI: --dry-run is accepted" {
  run "${CLI_COMMAND}" --dry-run --help
  
  assert_success
}

@test "CLI: --skip-validation is accepted" {
  run "${CLI_COMMAND}" --skip-validation --help
  
  assert_success
}

@test "CLI: --no-color is accepted" {
  run "${CLI_COMMAND}" --no-color --help
  
  assert_success
}

@test "CLI: --resume is accepted" {
  run "${CLI_COMMAND}" --resume --help
  
  assert_success
}

@test "CLI: --force is accepted" {
  run "${CLI_COMMAND}" --force --help
  
  assert_success
}

# Test: Root privilege check
@test "CLI: Non-root execution produces permission error" {
  skip "Cannot test root check in user context"
  
  # This test would need to run as non-root user
  # When implemented:
  # run sudo -u nobody "${CLI_COMMAND}"
  # assert_failure 6
  # assert_output --partial "must be run as root"
}

# Test: Required commands check
@test "CLI: Help works even without full prerequisites" {
  # Help should work without checking full prerequisites
  run "${CLI_COMMAND}" --help
  
  assert_success
}

# Test: Argument combinations
@test "CLI: Multiple valid arguments can be combined" {
  run "${CLI_COMMAND}" --log-level DEBUG --username testuser --output-format json --help
  
  assert_success
}

# Test: Exit code documentation
@test "CLI: Help documents all exit codes" {
  run "${CLI_COMMAND}" --help
  
  assert_success
  assert_output --partial "0    SUCCESS"
  assert_output --partial "1    VALIDATION_FAILED"
  assert_output --partial "2    PROVISIONING_FAILED"
  assert_output --partial "3    ROLLBACK_FAILED"
  assert_output --partial "4    VERIFICATION_FAILED"
  assert_output --partial "5    CONFIG_ERROR"
  assert_output --partial "6    PERMISSION_DENIED"
}

# Test: Phase names documentation
@test "CLI: Help documents all valid phases" {
  run "${CLI_COMMAND}" --help
  
  assert_success
  assert_output --partial "VALID PHASES:"
  assert_output --partial "system-prep"
  assert_output --partial "desktop-install"
  assert_output --partial "rdp-config"
  assert_output --partial "user-creation"
  assert_output --partial "ide-vscode"
  assert_output --partial "ide-cursor"
  assert_output --partial "ide-antigravity"
  assert_output --partial "terminal-setup"
  assert_output --partial "dev-tools"
  assert_output --partial "verification"
}

# Test: Examples documentation
@test "CLI: Help includes usage examples" {
  run "${CLI_COMMAND}" --help
  
  assert_success
  assert_output --partial "EXAMPLES:"
  assert_output --partial "vps-provision"
  assert_output --partial "vps-provision --dry-run"
  assert_output --partial "vps-provision --resume"
}

# Test: Environment variables documentation
@test "CLI: Help documents environment variables" {
  run "${CLI_COMMAND}" --help
  
  assert_success
  assert_output --partial "ENVIRONMENT VARIABLES:"
  assert_output --partial "VPS_PROVISION_CONFIG"
  assert_output --partial "VPS_PROVISION_LOG_DIR"
  assert_output --partial "VPS_PROVISION_NO_COLOR"
}

# Test: Prerequisites documentation
@test "CLI: Help documents prerequisites" {
  run "${CLI_COMMAND}" --help
  
  assert_success
  assert_output --partial "PREREQUISITES:"
  assert_output --partial "root"
  assert_output --partial "Debian 13"
  assert_output --partial "2GB RAM"
}
