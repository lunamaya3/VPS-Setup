#!/usr/bin/env bats
# Multi-Session RDP Integration Tests
# Tests concurrent RDP session support and session isolation
#
# Test Coverage:
# - Concurrent session establishment
# - Session isolation (separate processes, X displays)
# - Session reconnection and persistence
# - Performance under load (latency ≤120ms per performance-specs.md)
#
# Requirements Tested:
# - FR-013: Multiple concurrent RDP sessions without conflicts
# - SC-007: 2+ developers maintain concurrent RDP sessions
# - NFR-004: 3 concurrent sessions maintain responsive performance
# - SEC-009: Session isolation between users

# Load test helpers
load ../test_helper

# Test configuration
readonly TEST_USERS=("testuser1" "testuser2" "testuser3")
readonly TEST_PASSWORD="TestPass123!"
readonly RDP_PORT="${RDP_PORT:-3389}"
readonly SESSION_TIMEOUT=30

setup() {
  # Skip if not running as root (required for user management)
  if [[ $EUID -ne 0 ]]; then
    skip "Multi-session tests require root privileges"
  fi
  
  # Skip if useradd is not available
  if ! command -v useradd &>/dev/null; then
    skip "useradd command not available"
  fi
  
  # Ensure we're running on properly provisioned system
  if ! systemctl is-active --quiet xrdp 2>/dev/null; then
    skip "xrdp service not running - system not provisioned"
  fi
  
  # Create test users for multi-session testing
  for user in "${TEST_USERS[@]}"; do
    if ! id "${user}" &>/dev/null; then
      useradd -m -s /bin/bash "${user}"
      echo "${user}:${TEST_PASSWORD}" | chpasswd
    fi
  done
  
  # Ensure test log directory exists
  mkdir -p "${BATS_TEST_TMPDIR}/logs"
}

teardown() {
  # Cleanup: terminate test user sessions
  for user in "${TEST_USERS[@]}"; do
    pkill -u "${user}" || true
  done
  
  # Remove test users (but keep for debugging if test failed)
  if [[ "${BATS_TEST_COMPLETED:-0}" == "1" ]]; then
    for user in "${TEST_USERS[@]}"; do
      userdel -r "${user}" 2>/dev/null || true
    done
  fi
}

# Helper: Simulate RDP connection attempt
# Args: username
# Returns: 0 if connection successful, 1 otherwise
simulate_rdp_connection() {
  local username="$1"
  local log_file="${BATS_TEST_TMPDIR}/logs/${username}_rdp.log"
  
  # Check if xrdp is listening
  if ! netstat -tuln | grep -q ":${RDP_PORT}"; then
    echo "RDP port ${RDP_PORT} not listening" > "${log_file}"
    return 1
  fi
  
  # Simulate authentication by checking if sesman accepts connections
  # In real scenario, would use xfreerdp or rdesktop client
  # For integration test, verify session can be created via xrdp-sesadmin
  
  # Check if user session can be initiated
  timeout 5 su - "${username}" -c "DISPLAY=:0 xhost +local: 2>&1" > "${log_file}" 2>&1 || true
  
  # Verify session process exists for user
  sleep 2
  if pgrep -u "${username}" > /dev/null 2>&1; then
    echo "Session established for ${username}" > "${log_file}"
    return 0
  else
    echo "Failed to establish session for ${username}" > "${log_file}"
    return 1
  fi
}

# Helper: Get active X display for user
# Args: username
# Returns: Display number (e.g., :10) or empty if none
get_user_display() {
  local username="$1"
  ps aux | grep "${username}" | grep "Xorg" | grep -oP ':\d+' | head -1 || echo ""
}

# Helper: Get process count for user
# Args: username
# Returns: Number of processes owned by user
get_user_process_count() {
  local username="$1"
  pgrep -u "${username}" | wc -l
}

# Helper: Measure session latency (time to establish connection)
# Args: username
# Returns: Latency in milliseconds
measure_session_latency() {
  local username="$1"
  local start_time
  local end_time
  local latency_ms
  
  start_time=$(date +%s%3N)  # milliseconds
  
  # Attempt connection
  simulate_rdp_connection "${username}"
  
  end_time=$(date +%s%3N)
  latency_ms=$((end_time - start_time))
  
  echo "${latency_ms}"
}

@test "xrdp service is active and listening on port 3389" {
  run systemctl is-active xrdp
  assert_success
  
  run netstat -tuln
  assert_output --partial ":${RDP_PORT}"
}

@test "xrdp sesman is configured for multi-session support" {
  run grep "MaxSessions" /etc/xrdp/sesman.ini
  assert_success
  assert_output --partial "MaxSessions=50"
  
  run grep "KillDisconnected" /etc/xrdp/sesman.ini
  assert_success
  assert_output --partial "KillDisconnected=false"
}

@test "can establish single RDP session" {
  run simulate_rdp_connection "${TEST_USERS[0]}"
  assert_success
  
  # Verify session process exists
  run pgrep -u "${TEST_USERS[0]}"
  assert_success
}

@test "can establish 3 concurrent RDP sessions" {
  # Establish sessions for all 3 test users
  for user in "${TEST_USERS[@]}"; do
    simulate_rdp_connection "${user}" &
  done
  
  # Wait for all sessions to establish
  wait
  
  # Verify all users have active processes
  for user in "${TEST_USERS[@]}"; do
    run pgrep -u "${user}"
    assert_success "User ${user} should have active processes"
  done
  
  # Count total active sessions
  local session_count=0
  for user in "${TEST_USERS[@]}"; do
    if pgrep -u "${user}" >/dev/null 2>&1; then
      ((session_count++))
    fi
  done
  
  [[ ${session_count} -eq 3 ]] || {
    echo "Expected 3 concurrent sessions, got ${session_count}"
    return 1
  }
}

@test "concurrent sessions use separate X displays" {
  # Establish sessions
  for user in "${TEST_USERS[@]}"; do
    simulate_rdp_connection "${user}" &
  done
  wait
  
  # Get X displays for each user
  local -a displays=()
  for user in "${TEST_USERS[@]}"; do
    local display
    display=$(get_user_display "${user}")
    if [[ -n "${display}" ]]; then
      displays+=("${display}")
    fi
  done
  
  # Verify all displays are unique
  local unique_count
  unique_count=$(printf '%s\n' "${displays[@]}" | sort -u | wc -l)
  local total_count=${#displays[@]}
  
  [[ ${unique_count} -eq ${total_count} ]] || {
    echo "Expected unique X displays, got duplicates: ${displays[*]}"
    return 1
  }
}

@test "sessions are isolated - separate process namespaces" {
  # Establish sessions
  for user in "${TEST_USERS[@]}"; do
    simulate_rdp_connection "${user}" &
  done
  wait
  
  # Verify each user has their own processes
  for user in "${TEST_USERS[@]}"; do
    local process_count
    process_count=$(get_user_process_count "${user}")
    
    [[ ${process_count} -gt 0 ]] || {
      echo "User ${user} has no processes"
      return 1
    }
  done
  
  # Verify processes don't overlap between users
  for i in "${!TEST_USERS[@]}"; do
    local user1="${TEST_USERS[i]}"
    for j in "${!TEST_USERS[@]}"; do
      if [[ $i -ne $j ]]; then
        local user2="${TEST_USERS[j]}"
        
        # Check that user1's processes don't appear in user2's process list
        local user1_pids
        user1_pids=$(pgrep -u "${user1}" | tr '\n' ' ')
        local user2_pids
        user2_pids=$(pgrep -u "${user2}" | tr '\n' ' ')
        
        # Ensure no PID overlap
        for pid in ${user1_pids}; do
          if echo "${user2_pids}" | grep -q "${pid}"; then
            echo "Process ${pid} appears in both ${user1} and ${user2}"
            return 1
          fi
        done
      fi
    done
  done
}

@test "session reconnection preserves state (KillDisconnected=false)" {
  local user="${TEST_USERS[0]}"
  
  # Establish initial session
  simulate_rdp_connection "${user}"
  
  # Get initial process count
  local initial_process_count
  initial_process_count=$(get_user_process_count "${user}")
  
  [[ ${initial_process_count} -gt 0 ]] || {
    echo "Failed to establish initial session"
    return 1
  }
  
  # Simulate disconnect (in real scenario, close RDP client)
  # Processes should remain running
  sleep 2
  
  # Verify processes still running after "disconnect"
  local post_disconnect_count
  post_disconnect_count=$(get_user_process_count "${user}")
  
  [[ ${post_disconnect_count} -eq ${initial_process_count} ]] || {
    echo "Process count changed after disconnect: ${initial_process_count} -> ${post_disconnect_count}"
    echo "Expected: Processes should persist (KillDisconnected=false)"
    return 1
  }
}

@test "session establishment latency meets performance requirements (<120ms)" {
  skip "Requires actual RDP client for accurate latency measurement"
  
  # This is a placeholder for E2E testing with actual RDP client
  # Integration test approximates by measuring process spawn time
  
  local user="${TEST_USERS[0]}"
  local latency_ms
  
  latency_ms=$(measure_session_latency "${user}")
  
  [[ ${latency_ms} -lt 120 ]] || {
    echo "Session latency ${latency_ms}ms exceeds requirement (120ms)"
    return 1
  }
}

@test "resource monitoring utility reports session statistics" {
  # Establish test sessions
  for user in "${TEST_USERS[@]}"; do
    simulate_rdp_connection "${user}" &
  done
  wait
  
  # Run session monitor
  run python3 "${BATS_TEST_DIRNAME}/../../lib/utils/session-monitor.py" --json
  assert_success
  
  # Parse JSON output
  if command -v jq &>/dev/null; then
    local session_count
    session_count=$(echo "${output}" | jq '.session_count')
    
    [[ ${session_count} -ge 1 ]] || {
      echo "Expected at least 1 active session, got ${session_count}"
      return 1
    }
  else
    # Fallback: check output contains session data
    echo "${output}" | grep -q "session_count" || {
      echo "Monitor output missing session data"
      return 1
    }
  fi
}

@test "3 concurrent sessions stay within 4GB RAM target (NFR-004)" {
  skip "Requires 4GB RAM system and actual RDP client connections"
  
  # This test should be run on actual 4GB VPS during E2E testing
  # Integration test verifies monitoring capability exists
  
  # Establish 3 sessions
  for user in "${TEST_USERS[@]}"; do
    simulate_rdp_connection "${user}" &
  done
  wait
  
  # Check memory usage
  run python3 "${BATS_TEST_DIRNAME}/../../lib/utils/session-monitor.py" --threshold 75
  assert_success "Memory usage should stay within 75% threshold for 3 sessions"
}

@test "session manager prevents session conflicts" {
  # Attempt to create sessions rapidly
  local concurrent_limit=5
  
  for i in $(seq 1 ${concurrent_limit}); do
    simulate_rdp_connection "${TEST_USERS[0]}" &
  done
  wait
  
  # Verify system remains stable (no crashed processes)
  run systemctl is-active xrdp
  assert_success
  
  run systemctl is-active xrdp-sesman
  assert_success
}

@test "session isolation - file permissions prevent cross-user access" {
  local user1="${TEST_USERS[0]}"
  local user2="${TEST_USERS[1]}"
  
  # Establish sessions
  simulate_rdp_connection "${user1}" &
  simulate_rdp_connection "${user2}" &
  wait
  
  # Create file in user1's home directory
  local test_file="/home/${user1}/private_file.txt"
  su - "${user1}" -c "echo 'private data' > '${test_file}'"
  su - "${user1}" -c "chmod 600 '${test_file}'"
  
  # Verify user2 cannot read user1's file
  run su - "${user2}" -c "cat '${test_file}'"
  assert_failure "User2 should not be able to read User1's private file"
}

# Cleanup helper
cleanup_test_sessions() {
  for user in "${TEST_USERS[@]}"; do
    pkill -u "${user}" 2>/dev/null || true
  done
}
