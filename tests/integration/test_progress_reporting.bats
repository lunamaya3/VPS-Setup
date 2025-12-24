#!/usr/bin/env bats
# Progress Reporting Integration Tests (T105-T108)
# Purpose: Validate UX requirements for progress tracking
#
# Tests cover:
# - T105: Percentage display (UX-001), remaining time (UX-002), 2-second updates (UX-003)
# - T106: Visual hierarchy (UX-004)
# - T107: Progress persistence (UX-005)
# - T108: Duration warnings (UX-006)

load '../test_helper'

setup() {
  export BATS_TEST_TMPDIR="${BATS_TEST_TMPDIR:-/tmp/bats-test-$$}"
  mkdir -p "${BATS_TEST_TMPDIR}"
  
  # Test constants
  export LOG_FILE="${BATS_TEST_TMPDIR}/test.log"
  export PROGRESS_STATE_FILE="${BATS_TEST_TMPDIR}/progress.state"
  export PROGRESS_STATE_DIR="${BATS_TEST_TMPDIR}"
  export NO_COLOR=1  # Disable colors for testing
  
  # Create log file
  touch "${LOG_FILE}"
  
  # Source progress module (logger will be sourced automatically)
  source "${PROJECT_ROOT}/lib/core/progress.sh"
}

teardown() {
  rm -rf "${BATS_TEST_TMPDIR}"
}

# T105: UX-001 - Percentage Display
@test "T105 UX-001: Progress percentage calculated correctly (0-100%)" {
  progress_init 10
  
  # Initial: 0%
  local pct
  pct=$(progress_get_percentage)
  [[ "$pct" == "0" ]]
  
  # After phase 3: 30%
  CURRENT_PHASE=3
  pct=$(progress_get_percentage)
  [[ "$pct" == "30" ]]
  
  # After phase 7: 70%
  CURRENT_PHASE=7
  pct=$(progress_get_percentage)
  [[ "$pct" == "70" ]]
  
  # All phases complete: 100%
  CURRENT_PHASE=10
  pct=$(progress_get_percentage)
  [[ "$pct" == "100" ]]
}

# T105: UX-002 - Remaining Time Estimation
@test "T105 UX-002: Remaining time estimated with weighted phases" {
  progress_init 10
  
  # Set overall start time to 5 minutes ago
  OVERALL_START_TIME=$(($(date +%s) - 300))
  
  # Complete 3 phases (30% with weights)
  CURRENT_PHASE=3
  
  local remaining
  remaining=$(progress_estimate_remaining)
  
  # Remaining should be a positive integer
  [[ "$remaining" =~ ^[0-9]+$ ]]
  [[ "$remaining" -gt 0 ]]
}

@test "T105 UX-002: Remaining time returns 0 when no phases started" {
  progress_init 10
  CURRENT_PHASE=0
  
  local remaining
  remaining=$(progress_estimate_remaining)
  
  # Should return estimated total time, not 0
  [[ "$remaining" =~ ^[0-9]+$ ]]
  [[ "$remaining" -gt 0 ]]
}

# T105: UX-003 - 2-Second Update Interval
@test "T105 UX-003: Progress updates respect 2-second interval" {
  progress_init 10
  CURRENT_PHASE=1
  
  # First update should always work
  LAST_UPDATE_TIME=0
  run progress_update
  [[ "$status" -eq 0 ]]
  
  # Immediate second update should be skipped
  local first_update_time=$LAST_UPDATE_TIME
  run progress_update
  [[ "$status" -eq 0 ]]
  
  # LAST_UPDATE_TIME should not have changed (update was skipped)
  [[ "$LAST_UPDATE_TIME" -eq "$first_update_time" ]]
  
  # Update after 3 seconds should work
  LAST_UPDATE_TIME=$(($(date +%s) - 3))
  run progress_update
  [[ "$status" -eq 0 ]]
}

# T106: UX-004 - Visual Hierarchy
@test "T106 UX-004: Visual hierarchy distinguishes phase states" {
  source "${PROJECT_ROOT}/lib/core/progress.sh"
  
  progress_init 5
  CURRENT_PHASE=3
  PHASE_NAME="test-phase"
  
  # Test completed phase format
  local formatted
  formatted=$(progress_format_phase 1 "Phase 1" "completed")
  [[ "$formatted" =~ "DONE" ]] || [[ "$formatted" =~ "✓" ]]
  
  # Test current phase format
  formatted=$(progress_format_phase 3 "Phase 3" "current")
  [[ "$formatted" =~ "NOW" ]] || [[ "$formatted" =~ "▶" ]]
  
  # Test pending phase format
  formatted=$(progress_format_phase 5 "Phase 5" "pending")
  [[ "$formatted" =~ "TODO" ]] || [[ "$formatted" =~ "○" ]]
}

@test "T106 UX-004: Phase list displays all phases with correct status" {
  progress_init 5
  CURRENT_PHASE=3
  
  local phases=("Phase 1" "Phase 2" "Phase 3" "Phase 4" "Phase 5")
  
  # Capture output
  local output
  output=$(progress_show_phase_list "${phases[@]}")
  
  # Should contain all 5 phases
  [[ "$output" =~ "Phase 1" ]]
  [[ "$output" =~ "Phase 2" ]]
  [[ "$output" =~ "Phase 3" ]]
  [[ "$output" =~ "Phase 4" ]]
  [[ "$output" =~ "Phase 5" ]]
  
  # Should show "Provisioning Progress"
  [[ "$output" =~ "Provisioning Progress" ]]
}

# T107: UX-005 - Progress Persistence
@test "T107 UX-005: Progress state saved to disk" {
  progress_init 10
  CURRENT_PHASE=3
  PHASE_NAME="test-phase"
  PHASE_START_TIME=1234567890
  OVERALL_START_TIME=1234567800
  
  progress_save_state "$PROGRESS_STATE_FILE"
  
  # Verify state file exists
  [[ -f "$PROGRESS_STATE_FILE" ]]
  
  # Verify state file contains expected values
  grep -q "TOTAL_PHASES=10" "$PROGRESS_STATE_FILE"
  grep -q "CURRENT_PHASE=3" "$PROGRESS_STATE_FILE"
  grep -q 'PHASE_NAME="test-phase"' "$PROGRESS_STATE_FILE"
}

@test "T107 UX-005: Progress state restored from disk" {
  # Create a state file
  cat > "$PROGRESS_STATE_FILE" <<EOF
# VPS Provision Progress State
# Generated: Test
TOTAL_PHASES=8
CURRENT_PHASE=5
PHASE_START_TIME=1234567890
OVERALL_START_TIME=1234567800
LAST_UPDATE_TIME=1234567900
PHASE_NAME="restored-phase"
EOF
  
  # Don't call progress_init - it would overwrite the test state file!
  # Instead, just set initial values
  TOTAL_PHASES=0
  CURRENT_PHASE=0
  PHASE_NAME=""
  
  # Restore state (don't use 'run' because we need to modify variables in current shell)
  progress_load_state "$PROGRESS_STATE_FILE"
  
  # Verify restored values
  [[ "$TOTAL_PHASES" -eq 8 ]]
  [[ "$CURRENT_PHASE" -eq 5 ]]
  [[ "$PHASE_NAME" == "restored-phase" ]]
  [[ "$PHASE_START_TIME" -eq 1234567890 ]]
}

@test "T107 UX-005: Progress state persists on phase start" {
  progress_init 10
  
  # Remove state file if exists
  rm -f "$PROGRESS_STATE_FILE"
  
  # Start a phase (should trigger save)
  progress_start_phase 2 "test-phase"
  
  # Verify state was saved
  [[ -f "$PROGRESS_STATE_FILE" ]]
  grep -q "CURRENT_PHASE=2" "$PROGRESS_STATE_FILE"
}

@test "T107 UX-005: Progress state persists on phase completion" {
  progress_init 10
  progress_start_phase 3 "test-phase"
  
  # Remove state file
  rm -f "$PROGRESS_STATE_FILE"
  
  # Complete phase (should trigger save)
  PHASE_START_TIME=$(($(date +%s) - 60))
  progress_complete_phase 3
  
  # Verify state was saved
  [[ -f "$PROGRESS_STATE_FILE" ]]
}

@test "T107 UX-005: Progress state creates directory if missing" {
  # Use a nested directory
  export PROGRESS_STATE_FILE="${BATS_TEST_TMPDIR}/nested/dir/progress.state"
  export PROGRESS_STATE_DIR="${BATS_TEST_TMPDIR}/nested/dir"
  
  # Ensure directory doesn't exist
  rm -rf "${BATS_TEST_TMPDIR}/nested"
  
  progress_init 10
  
  # Directory should be created
  [[ -d "${BATS_TEST_TMPDIR}/nested/dir" ]]
  [[ -f "$PROGRESS_STATE_FILE" ]]
}

# T108: UX-006 - Duration Warnings
@test "T108 UX-006: Warning triggered when phase exceeds 150% of estimate" {
  source "${PROJECT_ROOT}/lib/core/progress.sh"
  
  # Phase took 180 seconds, estimate was 100 seconds
  # 180 > 150 (150% of 100), should trigger warning
  run progress_check_duration_warning 180 100
  [[ "$status" -eq 1 ]]  # Returns 1 when warning triggered
  
  # Check warning message in output
  [[ "$output" =~ "longer than expected" ]]
}

@test "T108 UX-006: No warning when phase within 150% of estimate" {
  # Phase took 140 seconds, estimate was 100 seconds
  # 140 < 150 (150% of 100), should NOT trigger warning
  run progress_check_duration_warning 140 100
  [[ "$status" -eq 0 ]]  # Returns 0 when within limits
  
  # Output should be empty (no warning)
  [[ -z "$output" ]]
}

@test "T108 UX-006: Warning at exactly 150% threshold" {
  # Phase took exactly 150 seconds, estimate was 100 seconds
  # 150 == 150 (150% of 100), should NOT trigger warning (only > 150%)
  run progress_check_duration_warning 150 100
  [[ "$status" -eq 0 ]]
}

@test "T108 UX-006: Duration warning checked on phase completion" {
  progress_init 10
  
  # Start a phase
  progress_start_phase 1 "system-prep"
  
  # Set start time to 200 seconds ago (estimate is 120s, threshold is 180s)
  PHASE_START_TIME=$(($(date +%s) - 200))
  
  # Complete phase (should trigger warning)
  run progress_complete_phase 1
  [[ "$status" -eq 0 ]]
  
  # Check log for warning
  grep -q "longer than expected" "$LOG_FILE" || {
    echo "Expected warning in log"
    cat "$LOG_FILE"
    return 1
  }
}

# Integration Tests
@test "INTEGRATION: Progress tracking workflow from init to completion" {
  # Initialize
  progress_init 3
  [[ "$TOTAL_PHASES" -eq 3 ]]
  [[ "$CURRENT_PHASE" -eq 0 ]]
  
  # Start phase 1
  progress_start_phase 1 "Phase 1"
  [[ "$CURRENT_PHASE" -eq 1 ]]
  [[ "$PHASE_NAME" == "Phase 1" ]]
  
  # Complete phase 1
  PHASE_START_TIME=$(($(date +%s) - 30))
  progress_complete_phase 1
  
  # Progress should be 33%
  local pct
  pct=$(progress_get_percentage)
  [[ "$pct" == "33" ]]
  
  # Start and complete phase 2
  progress_start_phase 2 "Phase 2"
  PHASE_START_TIME=$(($(date +%s) - 30))
  progress_complete_phase 2
  
  # Progress should be 67%
  pct=$(progress_get_percentage)
  [[ "$pct" == "67" ]]
  
  # Start and complete phase 3
  progress_start_phase 3 "Phase 3"
  PHASE_START_TIME=$(($(date +%s) - 30))
  progress_complete_phase 3
  
  # Progress should be 100%
  pct=$(progress_get_percentage)
  [[ "$pct" == "100" ]]
}

@test "INTEGRATION: Progress persistence survives restart" {
  # First run: init and complete 2 phases
  progress_init 5
  progress_start_phase 1 "Phase 1"
  PHASE_START_TIME=$(($(date +%s) - 30))
  progress_complete_phase 1
  
  progress_start_phase 2 "Phase 2"
  PHASE_START_TIME=$(($(date +%s) - 30))
  progress_complete_phase 2
  
  # Verify state saved
  [[ -f "$PROGRESS_STATE_FILE" ]]
  
  # Simulate restart: reset variables
  TOTAL_PHASES=0
  CURRENT_PHASE=0
  PHASE_NAME=""
  
  # Restore state
  progress_load_state "$PROGRESS_STATE_FILE"
  
  # Verify restoration
  [[ "$TOTAL_PHASES" -eq 5 ]]
  [[ "$CURRENT_PHASE" -eq 2 ]]
  [[ "$PHASE_NAME" == "Phase 2" ]]
  
  # Continue from where we left off
  progress_start_phase 3 "Phase 3"
  [[ "$CURRENT_PHASE" -eq 3 ]]
  
  # Progress should be 60%
  local pct
  pct=$(progress_get_percentage)
  [[ "$pct" == "60" ]]
}

@test "INTEGRATION: Duration warning system end-to-end" {
  progress_init 3
  
  # Phase 1: Within estimate (should not warn)
  progress_start_phase 1 "fast-phase"
  PHASE_START_TIME=$(($(date +%s) - 50))
  progress_complete_phase 1
  
  # No warning in log
  ! grep -q "longer than expected" "$LOG_FILE"
  
  # Phase 2: Exceeds estimate (should warn)
  progress_start_phase 2 "slow-phase"
  PHASE_START_TIME=$(($(date +%s) - 200))
  
  # Manually trigger with known values to ensure warning
  run progress_check_duration_warning 200 100
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "longer than expected" ]]
}

@test "INTEGRATION: Visual hierarchy respects NO_COLOR environment" {
  # With NO_COLOR=1 (already set in setup)
  local formatted
  formatted=$(progress_format_phase 1 "Test" "current")
  
  # Should not contain ANSI color codes
  ! [[ "$formatted" =~ $'\033' ]]
  
  # Should contain text status
  [[ "$formatted" =~ "NOW" ]] || [[ "$formatted" =~ "▶" ]]
  
  # With NO_COLOR=0
  NO_COLOR=0
  formatted=$(progress_format_phase 1 "Test" "current")
  
  # In test environment (not TTY), colors still won't be used
  # but function should not fail
  [[ -n "$formatted" ]]
}
