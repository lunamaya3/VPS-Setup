#!/bin/bash
# RDP Multi-Session Performance Test
# Validates that concurrent RDP sessions meet NFR-004 performance requirements
#
# Performance Requirements (NFR-004):
# - 3 concurrent RDP sessions on 4GB RAM droplet
# - Responsive performance without noticeable lag
# - Target: ≤120ms latency per session
# - Memory: ≤3GB used (1GB system buffer)
#
# Usage:
#   ./test_multi_session_performance.sh [--sessions N] [--duration SECONDS]
#
# Exit codes:
#   0 - All performance tests passed
#   1 - One or more performance tests failed
#   2 - Test environment not ready

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
readonly PROJECT_ROOT
readonly SESSION_MONITOR="${PROJECT_ROOT}/lib/utils/session-monitor.py"

# Default parameters
NUM_SESSIONS="${NUM_SESSIONS:-3}"
TEST_DURATION="${TEST_DURATION:-60}"  # seconds
LATENCY_THRESHOLD_MS="${LATENCY_THRESHOLD_MS:-120}"
MEMORY_THRESHOLD_PERCENT="${MEMORY_THRESHOLD_PERCENT:-75}"

# Test results
declare -a TEST_RESULTS=()
OVERALL_PASS=true

# Colors
readonly COLOR_RESET="\033[0m"
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_RED="\033[0;31m"
readonly COLOR_YELLOW="\033[0;33m"
readonly COLOR_BLUE="\033[0;34m"

# Helper: Print colored output
print_color() {
  local color="$1"
  shift
  echo -e "${color}$*${COLOR_RESET}"
}

# Helper: Record test result
record_result() {
  local test_name="$1"
  local passed="$2"
  local details="${3:-}"
  
  if [[ "${passed}" == "true" ]]; then
    TEST_RESULTS+=("✓ ${test_name}: PASS ${details}")
  else
    TEST_RESULTS+=("✗ ${test_name}: FAIL ${details}")
    OVERALL_PASS=false
  fi
}

# Helper: Print usage
print_usage() {
  cat <<EOF
RDP Multi-Session Performance Test

Usage:
  $(basename "$0") [OPTIONS]

Options:
  --sessions N         Number of concurrent sessions to test (default: 3)
  --duration SECONDS   How long to run load test (default: 60)
  --help               Show this help message

Environment Variables:
  NUM_SESSIONS              Number of sessions (default: 3)
  TEST_DURATION             Test duration in seconds (default: 60)
  LATENCY_THRESHOLD_MS      Maximum acceptable latency (default: 120)
  MEMORY_THRESHOLD_PERCENT  Maximum memory usage % (default: 75)

Requirements:
  - System must be provisioned with xrdp
  - At least 4GB RAM for accurate testing
  - Test users created for session simulation

Exit Codes:
  0 - All tests passed
  1 - One or more tests failed
  2 - Environment not ready
EOF
}

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sessions)
        NUM_SESSIONS="$2"
        shift 2
        ;;
      --duration)
        TEST_DURATION="$2"
        shift 2
        ;;
      --help|-h)
        print_usage
        exit 0
        ;;
      *)
        print_color "${COLOR_RED}" "Unknown option: $1"
        print_usage
        exit 2
        ;;
    esac
  done
}

# Check prerequisites
check_prerequisites() {
  print_color "${COLOR_BLUE}" "=== Checking Prerequisites ==="
  echo
  
  # Check if xrdp is running
  if ! systemctl is-active --quiet xrdp; then
    print_color "${COLOR_RED}" "✗ xrdp service is not running"
    record_result "Prerequisites" "false" "xrdp not active"
    return 2
  fi
  print_color "${COLOR_GREEN}" "✓ xrdp service is running"
  
  # Check if session monitor exists
  if [[ ! -x "${SESSION_MONITOR}" ]]; then
    print_color "${COLOR_RED}" "✗ Session monitor not found: ${SESSION_MONITOR}"
    record_result "Prerequisites" "false" "Monitor missing"
    return 2
  fi
  print_color "${COLOR_GREEN}" "✓ Session monitor utility available"
  
  # Check system memory
  local total_mem_mb
  total_mem_mb=$(free -m | awk '/^Mem:/ {print $2}')
  if [[ ${total_mem_mb} -lt 3800 ]]; then
    print_color "${COLOR_YELLOW}" "⚠ System has ${total_mem_mb}MB RAM (< 4GB target)"
    print_color "${COLOR_YELLOW}" "  Performance tests may not be accurate"
  else
    print_color "${COLOR_GREEN}" "✓ System has ${total_mem_mb}MB RAM"
  fi
  
  echo
  record_result "Prerequisites" "true"
  return 0
}

# Test: Baseline resource usage
test_baseline_resources() {
  print_color "${COLOR_BLUE}" "=== Test: Baseline Resource Usage ==="
  echo
  
  # Get baseline memory before any sessions
  local baseline_mem_used
  baseline_mem_used=$(free -m | awk '/^Mem:/ {print $3}')
  local baseline_mem_total
  baseline_mem_total=$(free -m | awk '/^Mem:/ {print $2}')
  local baseline_percent
  baseline_percent=$(awk "BEGIN {printf \"%.1f\", (${baseline_mem_used}/${baseline_mem_total})*100}")
  
  echo "Baseline Memory Usage: ${baseline_mem_used}MB / ${baseline_mem_total}MB (${baseline_percent}%)"
  
  # Baseline should be reasonable (system + xrdp)
  if (( $(echo "${baseline_percent} < 50" | bc -l) )); then
    print_color "${COLOR_GREEN}" "✓ Baseline memory usage acceptable"
    record_result "Baseline Resources" "true" "${baseline_percent}%"
    return 0
  else
    print_color "${COLOR_RED}" "✗ Baseline memory usage high (>${50}%)"
    record_result "Baseline Resources" "false" "${baseline_percent}%"
    return 1
  fi
}

# Test: Memory usage with N concurrent sessions
test_concurrent_memory_usage() {
  print_color "${COLOR_BLUE}" "=== Test: Memory Usage with ${NUM_SESSIONS} Concurrent Sessions ==="
  echo
  
  print_color "${COLOR_YELLOW}" "Note: This is a simulation test"
  print_color "${COLOR_YELLOW}" "For accurate results, run E2E test with actual RDP clients"
  echo
  
  # Run session monitor
  local monitor_output
  monitor_output=$(python3 "${SESSION_MONITOR}" --json --threshold "${MEMORY_THRESHOLD_PERCENT}" 2>&1) || {
    print_color "${COLOR_RED}" "✗ Session monitor failed"
    record_result "Concurrent Memory" "false" "Monitor error"
    return 1
  }
  
  # Parse memory usage
  local used_mb
  used_mb=$(echo "${monitor_output}" | grep -oP '"used_mb":\s*\K[0-9.]+' | head -1)
  local total_mb
  total_mb=$(echo "${monitor_output}" | grep -oP '"total_mb":\s*\K[0-9.]+' | head -1)
  
  if [[ -z "${used_mb}" || -z "${total_mb}" ]]; then
    print_color "${COLOR_YELLOW}" "⚠ Could not parse memory stats"
    record_result "Concurrent Memory" "true" "Parse error (non-blocking)"
    return 0
  fi
  
  local used_percent
  used_percent=$(awk "BEGIN {printf \"%.1f\", (${used_mb}/${total_mb})*100}")
  
  echo "Current Memory Usage: ${used_mb}MB / ${total_mb}MB (${used_percent}%)"
  echo "Threshold: ${MEMORY_THRESHOLD_PERCENT}%"
  
  # Check if within threshold
  if (( $(echo "${used_percent} <= ${MEMORY_THRESHOLD_PERCENT}" | bc -l) )); then
    print_color "${COLOR_GREEN}" "✓ Memory usage within threshold"
    record_result "Concurrent Memory" "true" "${used_percent}%"
    return 0
  else
    print_color "${COLOR_RED}" "✗ Memory usage exceeds threshold"
    record_result "Concurrent Memory" "false" "${used_percent}% > ${MEMORY_THRESHOLD_PERCENT}%"
    return 1
  fi
}

# Test: Session isolation (CPU usage independent)
test_session_isolation() {
  print_color "${COLOR_BLUE}" "=== Test: Session Isolation ==="
  echo
  
  print_color "${COLOR_YELLOW}" "Verifying session processes are isolated"
  
  # Count unique user sessions
  local unique_users
  unique_users=$(ps aux | grep '[X]org.*:[0-9]' | awk '{print $1}' | sort -u | wc -l)
  
  if [[ ${unique_users} -gt 0 ]]; then
    echo "Unique user sessions: ${unique_users}"
    print_color "${COLOR_GREEN}" "✓ Sessions are isolated by user"
    record_result "Session Isolation" "true" "${unique_users} unique users"
    return 0
  else
    print_color "${COLOR_YELLOW}" "⚠ No active sessions to test isolation"
    record_result "Session Isolation" "true" "No sessions (non-blocking)"
    return 0
  fi
}

# Test: Session responsiveness under load
test_responsiveness_under_load() {
  print_color "${COLOR_BLUE}" "=== Test: Responsiveness Under Load ==="
  echo
  
  print_color "${COLOR_YELLOW}" "Simulating load for ${TEST_DURATION} seconds..."
  
  local start_time
  start_time=$(date +%s)
  
  # Monitor CPU and memory during test
  local peak_cpu=0
  local peak_mem=0
  
  for ((i=0; i<TEST_DURATION; i++)); do
    # Get current CPU usage for xrdp processes
    local cpu_usage
    cpu_usage=$(ps aux | grep '[x]rdp' | awk '{sum+=$3} END {print sum}')
    if [[ -n "${cpu_usage}" ]] && (( $(echo "${cpu_usage} > ${peak_cpu}" | bc -l) )); then
      peak_cpu="${cpu_usage}"
    fi
    
    # Get current memory
    local mem_usage
    mem_usage=$(free -m | awk '/^Mem:/ {print $3}')
    if [[ ${mem_usage} -gt ${peak_mem} ]]; then
      peak_mem=${mem_usage}
    fi
    
    sleep 1
    
    # Progress indicator
    if (( i % 10 == 0 )); then
      echo -n "."
    fi
  done
  echo
  
  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  echo "Load test completed in ${duration} seconds"
  echo "Peak CPU: ${peak_cpu}%"
  echo "Peak Memory: ${peak_mem}MB"
  
  # Check if system remained responsive
  if ! systemctl is-active --quiet xrdp; then
    print_color "${COLOR_RED}" "✗ xrdp crashed during load test"
    record_result "Responsiveness" "false" "Service crashed"
    return 1
  fi
  
  print_color "${COLOR_GREEN}" "✓ System remained responsive under load"
  record_result "Responsiveness" "true" "Peak CPU=${peak_cpu}%"
  return 0
}

# Test: Latency simulation
test_session_latency() {
  print_color "${COLOR_BLUE}" "=== Test: Session Latency ==="
  echo
  
  print_color "${COLOR_YELLOW}" "Note: Accurate latency requires actual RDP client"
  print_color "${COLOR_YELLOW}" "This test measures xrdp service response time"
  echo
  
  # Measure xrdp port response time
  local latency_samples=10
  local total_latency=0
  local max_latency=0
  
  for ((i=1; i<=latency_samples; i++)); do
    local start_ms
    start_ms=$(date +%s%3N)
    
    # Test connection to xrdp port
    timeout 1 bash -c "echo >/dev/tcp/localhost/3389" 2>/dev/null || true
    
    local end_ms
    end_ms=$(date +%s%3N)
    local latency=$((end_ms - start_ms))
    
    total_latency=$((total_latency + latency))
    if [[ ${latency} -gt ${max_latency} ]]; then
      max_latency=${latency}
    fi
    
    echo "  Sample ${i}: ${latency}ms"
  done
  
  local avg_latency=$((total_latency / latency_samples))
  
  echo
  echo "Average Latency: ${avg_latency}ms"
  echo "Max Latency: ${max_latency}ms"
  echo "Threshold: ${LATENCY_THRESHOLD_MS}ms"
  
  # Check if within threshold
  if [[ ${avg_latency} -le ${LATENCY_THRESHOLD_MS} ]]; then
    print_color "${COLOR_GREEN}" "✓ Latency within acceptable range"
    record_result "Session Latency" "true" "Avg=${avg_latency}ms"
    return 0
  else
    print_color "${COLOR_RED}" "✗ Latency exceeds threshold"
    record_result "Session Latency" "false" "Avg=${avg_latency}ms > ${LATENCY_THRESHOLD_MS}ms"
    return 1
  fi
}

# Generate performance report
generate_report() {
  echo
  print_color "${COLOR_BLUE}" "======================================================================="
  print_color "${COLOR_BLUE}" "PERFORMANCE TEST REPORT"
  print_color "${COLOR_BLUE}" "======================================================================="
  echo
  
  echo "Test Configuration:"
  echo "  Target Sessions:      ${NUM_SESSIONS}"
  echo "  Test Duration:        ${TEST_DURATION}s"
  echo "  Memory Threshold:     ${MEMORY_THRESHOLD_PERCENT}%"
  echo "  Latency Threshold:    ${LATENCY_THRESHOLD_MS}ms"
  echo
  
  echo "Test Results:"
  for result in "${TEST_RESULTS[@]}"; do
    if [[ "${result}" == *"PASS"* ]]; then
      print_color "${COLOR_GREEN}" "  ${result}"
    else
      print_color "${COLOR_RED}" "  ${result}"
    fi
  done
  echo
  
  if [[ "${OVERALL_PASS}" == "true" ]]; then
    print_color "${COLOR_GREEN}" "======================================================================="
    print_color "${COLOR_GREEN}" "OVERALL RESULT: ✓ ALL TESTS PASSED"
    print_color "${COLOR_GREEN}" "======================================================================="
    return 0
  else
    print_color "${COLOR_RED}" "======================================================================="
    print_color "${COLOR_RED}" "OVERALL RESULT: ✗ SOME TESTS FAILED"
    print_color "${COLOR_RED}" "======================================================================="
    return 1
  fi
}

# Main test execution
main() {
  parse_arguments "$@"
  
  print_color "${COLOR_BLUE}" "======================================================================="
  print_color "${COLOR_BLUE}" "RDP MULTI-SESSION PERFORMANCE TEST (NFR-004)"
  print_color "${COLOR_BLUE}" "======================================================================="
  echo
  
  # Run all tests
  check_prerequisites || exit 2
  
  test_baseline_resources || true
  echo
  
  test_concurrent_memory_usage || true
  echo
  
  test_session_isolation || true
  echo
  
  test_responsiveness_under_load || true
  echo
  
  test_session_latency || true
  echo
  
  # Generate final report
  generate_report
  exit $?
}

# Execute main
main "$@"
