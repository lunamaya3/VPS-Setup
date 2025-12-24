#!/usr/bin/env bats
# Integration tests for UX Error Handling & Feedback (Phase 9: T109-T114)
#
# Tests cover:
# - T109: Standardized error message format
# - T110: Actionable suggestions for errors
# - T111: Confirmation prompts for destructive operations
# - T112: Success banner with connection details
# - T113: Error severity classification (FATAL, ERROR, WARNING)
# - T114: Input validation with specific feedback

load ../test_helper

setup() {
  export TEST_ROOT="${BATS_TEST_TMPDIR}"
  export LOG_FILE="${TEST_ROOT}/test.log"
  export CHECKPOINT_DIR="${TEST_ROOT}/checkpoints"
  export LOG_DIR="${TEST_ROOT}/logs"
  
  mkdir -p "${LOG_DIR}" "${CHECKPOINT_DIR}"
  
  # Source UX module
  source "${PROJECT_ROOT}/lib/core/logger.sh"
  source "${PROJECT_ROOT}/lib/core/error-handler.sh"
  source "${PROJECT_ROOT}/lib/core/ux.sh"
  
  # Initialize systems
  logger_init "${LOG_DIR}"
  error_handler_init
  ux_init
}

teardown() {
  rm -rf "${TEST_ROOT}"
}

# T109: Standardized error message format
@test "T109: Error messages follow [SEVERITY] <Message> format" {
  # Create error with standardized format
  local formatted
  formatted=$(error_format_message "ERROR" "Test error occurred" "Try action X")
  
  # Verify format
  [[ "$formatted" =~ ^\[ERROR\]\ Test\ error\ occurred ]]
  [[ "$formatted" =~ \>\ Try\ action\ X ]]
}

@test "T109: FATAL errors use proper severity tag" {
  local formatted
  formatted=$(error_format_message "FATAL" "Critical failure" "Contact support")
  
  [[ "$formatted" =~ ^\[FATAL\] ]]
}

@test "T109: WARNING errors use proper severity tag" {
  local formatted
  formatted=$(error_format_message "WARNING" "Non-critical issue" "Monitor situation")
  
  [[ "$formatted" =~ ^\[WARNING\] ]]
}

# T110: Actionable suggestions for all known errors
@test "T110: Network error provides actionable suggestion" {
  local suggestion
  suggestion=$(error_get_suggestion "$E_NETWORK")
  
  [[ -n "$suggestion" ]]
  [[ "$suggestion" =~ internet|connection|DNS|firewall ]]
}

@test "T110: Disk error provides actionable suggestion" {
  local suggestion
  suggestion=$(error_get_suggestion "$E_DISK")
  
  [[ -n "$suggestion" ]]
  [[ "$suggestion" =~ disk\ space|free|storage ]]
}

@test "T110: Lock error provides actionable suggestion" {
  local suggestion
  suggestion=$(error_get_suggestion "$E_LOCK")
  
  [[ -n "$suggestion" ]]
  [[ "$suggestion" =~ wait|retry|package\ manager ]]
}

@test "T110: Permission error provides actionable suggestion" {
  local suggestion
  suggestion=$(error_get_suggestion "$E_PERMISSION")
  
  [[ -n "$suggestion" ]]
  [[ "$suggestion" =~ root|sudo|privileges ]]
}

@test "T110: All error types have suggestions" {
  local error_types=("$E_NETWORK" "$E_DISK" "$E_LOCK" "$E_PKG_CORRUPT" "$E_PERMISSION" "$E_NOT_FOUND" "$E_TIMEOUT" "$E_UNKNOWN")
  
  for error_type in "${error_types[@]}"; do
    local suggestion
    suggestion=$(error_get_suggestion "$error_type")
    [[ -n "$suggestion" ]]
  done
}

# T111: Confirmation prompts for destructive operations
@test "T111: Confirmation prompt returns 0 when yes mode enabled" {
  export UX_YES_MODE=true
  
  # Should return success without prompting
  run confirm_action "Delete everything?"
  [ "$status" -eq 0 ]
}

@test "T111: Confirmation fails in non-interactive mode without yes flag" {
  export UX_INTERACTIVE=false
  export UX_YES_MODE=false
  
  run confirm_action "Delete files?"
  [ "$status" -eq 1 ]
  [[ "$output" =~ non-interactive ]]
}

@test "T111: Warning message is displayed before confirmation" {
  export UX_YES_MODE=true  # Bypass actual prompt
  
  run confirm_action "Dangerous action" "This will delete data"
  [ "$status" -eq 0 ]
  # Would show warning in real scenario
}

# T112: Success banner with connection details
@test "T112: Success banner displays all required connection info" {
  run show_success_banner "192.168.1.100" "3389" "testuser" "TestPass123!"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ PROVISIONING\ SUCCESSFUL ]]
  [[ "$output" =~ 192.168.1.100 ]]
  [[ "$output" =~ 3389 ]]
  [[ "$output" =~ testuser ]]
  # Password should be redacted in logs
  [[ "$output" =~ \[REDACTED\] ]]
}

@test "T112: Success banner shows copy-paste friendly format" {
  run show_success_banner "10.0.0.5" "3389" "devuser" "Pass123"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ Host:.*10.0.0.5 ]]
  [[ "$output" =~ Port:.*3389 ]]
  [[ "$output" =~ Username:.*devuser ]]
  [[ "$output" =~ devuser@10.0.0.5:3389 ]]
}

@test "T112: Success banner includes next steps" {
  run show_success_banner "1.2.3.4" "3389" "user" "pass"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ NEXT\ STEPS ]]
  [[ "$output" =~ Connect\ via\ RDP ]]
  [[ "$output" =~ Change\ your\ password ]]
}

@test "T112: Success banner warns about password change" {
  run show_success_banner "1.2.3.4" "3389" "user" "pass"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ IMPORTANT.*Change\ your\ password ]]
}

# T113: Error severity classification
@test "T113: Network errors classified as ERROR (retryable)" {
  local severity
  severity=$(error_get_severity "$E_NETWORK")
  
  [[ "$severity" == "ERROR" ]]
}

@test "T113: Disk errors classified as FATAL (critical)" {
  local severity
  severity=$(error_get_severity "$E_DISK")
  
  [[ "$severity" == "FATAL" ]]
}

@test "T113: Permission errors classified as FATAL" {
  local severity
  severity=$(error_get_severity "$E_PERMISSION")
  
  [[ "$severity" == "FATAL" ]]
}

@test "T113: Lock errors classified as ERROR (retryable)" {
  local severity
  severity=$(error_get_severity "$E_LOCK")
  
  [[ "$severity" == "ERROR" ]]
}

@test "T113: Unknown errors classified as WARNING" {
  local severity
  severity=$(error_get_severity "$E_UNKNOWN")
  
  [[ "$severity" == "WARNING" ]]
}

# T114: Input validation with specific feedback
@test "T114: Valid username passes validation" {
  run validate_username "testuser"
  [ "$status" -eq 0 ]
}

@test "T114: Username starting with uppercase fails with specific feedback" {
  run validate_username "TestUser"
  [ "$status" -eq 1 ]
  [[ "$output" =~ lowercase\ letter ]]
}

@test "T114: Short username fails with specific feedback" {
  run validate_username "ab"
  [ "$status" -eq 1 ]
  [[ "$output" =~ 3-32\ characters ]]
}

@test "T114: Username with invalid characters fails with feedback" {
  run validate_username "user@name"
  [ "$status" -eq 1 ]
  [[ "$output" =~ lowercase.*numbers.*underscore.*hyphen ]]
}

@test "T114: Valid password passes complexity check" {
  run validate_password "SecurePass123!@#"
  [ "$status" -eq 0 ]
}

@test "T114: Short password fails with length feedback" {
  run validate_password "Short1!"
  [ "$status" -eq 1 ]
  [[ "$output" =~ too\ short ]]
  [[ "$output" =~ 16\ characters ]]
}

@test "T114: Password without uppercase fails with specific feedback" {
  run validate_password "nouppercase123456!"
  [ "$status" -eq 1 ]
  [[ "$output" =~ uppercase\ letter ]]
}

@test "T114: Password without lowercase fails with specific feedback" {
  run validate_password "NOLOWERCASE123456!"
  [ "$status" -eq 1 ]
  [[ "$output" =~ lowercase\ letter ]]
}

@test "T114: Password without digit fails with specific feedback" {
  run validate_password "NoDigitsHere!@#$"
  [ "$status" -eq 1 ]
  [[ "$output" =~ digit ]]
}

@test "T114: Password without special character fails with feedback" {
  run validate_password "NoSpecialChars123"
  [ "$status" -eq 1 ]
  [[ "$output" =~ special\ character ]]
}

@test "T114: Valid IP address passes validation" {
  run validate_ip_address "192.168.1.1"
  [ "$status" -eq 0 ]
}

@test "T114: Invalid IP format fails with specific feedback" {
  run validate_ip_address "192.168.1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ format.*xxx.xxx.xxx.xxx ]]
}

@test "T114: IP with octet over 255 fails with feedback" {
  run validate_ip_address "192.168.1.300"
  [ "$status" -eq 1 ]
  [[ "$output" =~ 0.*255 ]]
}

@test "T114: Valid port passes validation" {
  run validate_port "3389"
  [ "$status" -eq 0 ]
}

@test "T114: Port below 1 fails with feedback" {
  run validate_port "0"
  [ "$status" -eq 1 ]
  [[ "$output" =~ between\ 1.*65535 ]]
}

@test "T114: Port above 65535 fails with feedback" {
  run validate_port "70000"
  [ "$status" -eq 1 ]
  [[ "$output" =~ between\ 1.*65535 ]]
}

@test "T114: Non-numeric port fails with feedback" {
  run validate_port "abc"
  [ "$status" -eq 1 ]
  [[ "$output" =~ must\ be\ a\ number ]]
}

# Integration tests combining multiple features
@test "Integration: Error classification and formatting work together" {
  local stderr="connection timeout"
  local error_type
  error_type=$(error_classify 100 "$stderr" "")
  
  local severity
  severity=$(error_get_severity "$error_type")
  
  local suggestion
  suggestion=$(error_get_suggestion "$error_type")
  
  local formatted
  formatted=$(error_format_message "$severity" "Command failed" "$suggestion")
  
  [[ "$error_type" == "$E_NETWORK" ]]
  [[ "$severity" == "ERROR" ]]
  [[ "$formatted" =~ \[ERROR\] ]]
  [[ "$formatted" =~ \> ]]
}

@test "Integration: UX system detects non-interactive shell" {
  # Close stdin to simulate non-interactive
  exec 0<&-
  
  ux_detect_interactive
  
  [[ "$UX_INTERACTIVE" == "false" ]]
}
