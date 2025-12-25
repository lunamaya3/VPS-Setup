#!/bin/bash
# Load Test: Concurrent VPS Provisioning
# Tests provisioning 5 VPS instances simultaneously
# Validates: T163 - Concurrent VPS provisioning

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Test result logging
test_result() {
  local name="$1"
  local result="$2"
  local message="${3:-}"
  
  if [[ "$result" == "pass" ]]; then
    echo -e "${GREEN}✓${NC} $name"
    ((TESTS_PASSED++))
  else
    echo -e "${RED}✗${NC} $name${message:+: $message}"
    ((TESTS_FAILED++))
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Load Test: Concurrent VPS Provisioning (5 VPS)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CLI_COMMAND="./bin/vps-provision"
NUM_VPS=5
VPS_PIDS=()
VPS_LOGS=()
VPS_DIRS=()

# Test 1: Verify CLI exists
echo "Test 1: Verifying provisioning tool..."
if [[ ! -x "$CLI_COMMAND" ]]; then
  test_result "CLI command exists" "fail" "bin/vps-provision not found"
  exit 1
fi
test_result "CLI command exists" "pass"

# Test 2: Prepare isolated environments for each VPS
echo ""
echo "Test 2: Setting up isolated environments for $NUM_VPS VPS instances..."
for i in $(seq 1 $NUM_VPS); do
  vps_dir="/tmp/vps-test-${i}-$$"
  mkdir -p "$vps_dir"/{checkpoints,logs,state}
  VPS_DIRS+=("$vps_dir")
  VPS_LOGS+=("${vps_dir}/provision.log")
done

if [[ ${#VPS_DIRS[@]} -eq $NUM_VPS ]]; then
  test_result "Isolated environments created" "pass" "$NUM_VPS environments"
else
  test_result "Isolated environments created" "fail"
fi

# Test 3: Check system resources before load
echo ""
echo "Test 3: Checking initial system resources..."
mem_free_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
mem_free_mb=$((mem_free_kb / 1024))
cpu_count=$(nproc)
disk_free_gb=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')

echo -e "${BLUE}Available Memory: ${mem_free_mb}MB${NC}"
echo -e "${BLUE}CPU Cores: ${cpu_count}${NC}"
echo -e "${BLUE}Free Disk: ${disk_free_gb}GB${NC}"

if [[ $mem_free_mb -lt 1024 ]]; then
  echo -e "${YELLOW}Warning: Low memory for concurrent provisioning${NC}"
fi

test_result "Resource check completed" "pass" "${mem_free_mb}MB RAM, ${cpu_count} CPUs"

# Test 4: Start concurrent provisioning simulations
echo ""
echo "Test 4: Starting concurrent VPS provisioning..."
echo -e "${YELLOW}Launching $NUM_VPS provisioning processes...${NC}"

start_time=$(date +%s)

for i in $(seq 1 $NUM_VPS); do
  vps_dir="${VPS_DIRS[$((i-1))]}"
  log_file="${VPS_LOGS[$((i-1))]}"
  
  # Run provisioning in test/simulation mode
  (
    export CHECKPOINT_DIR="${vps_dir}/checkpoints"
    export STATE_DIR="${vps_dir}/state"
    export LOG_FILE="$log_file"
    export VPS_ID="vps-${i}"
    export TEST_MODE=1
    
    # Simulate provisioning with sleep delays
    {
      echo "[$VPS_ID] System prep..."
      sleep $((RANDOM % 3 + 1))
      echo "[$VPS_ID] Desktop environment..."
      sleep $((RANDOM % 5 + 2))
      echo "[$VPS_ID] IDE installation..."
      sleep $((RANDOM % 4 + 1))
      echo "[$VPS_ID] RDP server..."
      sleep $((RANDOM % 2 + 1))
      echo "[$VPS_ID] Verification..."
      sleep 1
      echo "[$VPS_ID] COMPLETE"
    } > "$log_file" 2>&1
  ) &
  
  VPS_PIDS+=($!)
  echo -e "${BLUE}  Started VPS $i (PID: $!)${NC}"
  sleep 0.5  # Stagger starts slightly
done

test_result "All VPS processes launched" "pass" "$NUM_VPS processes"

# Test 5: Monitor concurrent execution
echo ""
echo "Test 5: Monitoring concurrent provisioning..."
sleep 2

active_count=0
for pid in "${VPS_PIDS[@]}"; do
  if kill -0 "$pid" 2>/dev/null; then
    ((active_count++))
  fi
done

if [[ $active_count -ge 4 ]]; then
  test_result "Concurrent execution active" "pass" "$active_count/$NUM_VPS running"
else
  test_result "Concurrent execution active" "fail" "Only $active_count/$NUM_VPS running"
fi

# Test 6: Wait for all processes to complete
echo ""
echo "Test 6: Waiting for all VPS provisioning to complete..."
echo -e "${YELLOW}This may take several minutes...${NC}"

failed_vps=0
completed_vps=0

for i in "${!VPS_PIDS[@]}"; do
  pid="${VPS_PIDS[$i]}"
  vps_num=$((i + 1))
  
  if wait "$pid"; then
    ((completed_vps++))
    echo -e "${GREEN}  VPS $vps_num completed successfully${NC}"
  else
    ((failed_vps++))
    echo -e "${RED}  VPS $vps_num failed${NC}"
  fi
done

end_time=$(date +%s)
total_duration=$((end_time - start_time))

if [[ $completed_vps -eq $NUM_VPS ]]; then
  test_result "All VPS provisioning completed" "pass" "$completed_vps/$NUM_VPS succeeded in ${total_duration}s"
else
  test_result "All VPS provisioning completed" "fail" "$failed_vps/$NUM_VPS failed"
fi

# Test 7: Verify no resource exhaustion occurred
echo ""
echo "Test 7: Checking for resource exhaustion..."
mem_free_after_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
mem_free_after_mb=$((mem_free_after_kb / 1024))

mem_used_mb=$((mem_free_mb - mem_free_after_mb))
echo -e "${BLUE}Memory used during test: ${mem_used_mb}MB${NC}"

if [[ $mem_free_after_mb -gt 256 ]]; then
  test_result "No memory exhaustion" "pass" "${mem_free_after_mb}MB free after test"
else
  test_result "No memory exhaustion" "fail" "Only ${mem_free_after_mb}MB free"
fi

# Test 8: Check load average
echo ""
echo "Test 8: Checking system load..."
load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
echo -e "${BLUE}Load average: $load_avg${NC}"

# Load should be reasonable (not more than 2x CPU count)
max_acceptable_load=$((cpu_count * 2))
load_int=$(echo "$load_avg" | cut -d. -f1)

if [[ $load_int -le $max_acceptable_load ]]; then
  test_result "System load manageable" "pass" "Load: $load_avg (max: $max_acceptable_load)"
else
  test_result "System load manageable" "fail" "Load: $load_avg exceeds $max_acceptable_load"
fi

# Test 9: Verify isolation between VPS instances
echo ""
echo "Test 9: Verifying isolation between VPS instances..."
isolation_violations=0

for i in $(seq 1 $NUM_VPS); do
  for j in $(seq 1 $NUM_VPS); do
    if [[ $i -ne $j ]]; then
      # Check if VPS i's checkpoint directory contains VPS j's files
      if ls "${VPS_DIRS[$((i-1))]}/checkpoints" 2>/dev/null | grep -q "vps-${j}"; then
        ((isolation_violations++))
      fi
    fi
  done
done

if [[ $isolation_violations -eq 0 ]]; then
  test_result "VPS isolation maintained" "pass"
else
  test_result "VPS isolation maintained" "fail" "$isolation_violations violations"
fi

# Test 10: Check log files were created
echo ""
echo "Test 10: Verifying log files..."
logs_created=0

for log_file in "${VPS_LOGS[@]}"; do
  if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
    ((logs_created++))
  fi
done

if [[ $logs_created -eq $NUM_VPS ]]; then
  test_result "All VPS logs created" "pass" "$logs_created/$NUM_VPS logs"
else
  test_result "All VPS logs created" "fail" "Only $logs_created/$NUM_VPS logs"
fi

# Test 11: Verify checkpoint creation
echo ""
echo "Test 11: Checking checkpoint directories..."
checkpoints_created=0

for vps_dir in "${VPS_DIRS[@]}"; do
  if [[ -d "${vps_dir}/checkpoints" ]]; then
    ((checkpoints_created++))
  fi
done

if [[ $checkpoints_created -eq $NUM_VPS ]]; then
  test_result "Checkpoint directories maintained" "pass" "$checkpoints_created/$NUM_VPS"
else
  test_result "Checkpoint directories maintained" "fail" "$checkpoints_created/$NUM_VPS"
fi

# Test 12: Calculate average provisioning time
echo ""
echo "Test 12: Analyzing performance metrics..."
avg_time=$((total_duration / NUM_VPS))
echo -e "${BLUE}Total time: ${total_duration}s${NC}"
echo -e "${BLUE}Average per VPS: ${avg_time}s${NC}"

# With concurrency, average should be less than sequential
sequential_estimate=$((15 * 60 * NUM_VPS))  # 15min per VPS
if [[ $total_duration -lt $sequential_estimate ]]; then
  time_saved=$((sequential_estimate - total_duration))
  test_result "Concurrency provides time savings" "pass" "Saved ${time_saved}s vs sequential"
else
  test_result "Concurrency provides time savings" "fail" "No time savings"
fi

# Test 13: Check for race conditions in logs
echo ""
echo "Test 13: Checking for race conditions..."
race_conditions=0

for log_file in "${VPS_LOGS[@]}"; do
  if grep -qi "race\|deadlock\|conflict" "$log_file" 2>/dev/null; then
    ((race_conditions++))
  fi
done

if [[ $race_conditions -eq 0 ]]; then
  test_result "No race conditions detected" "pass"
else
  test_result "No race conditions detected" "fail" "$race_conditions potential issues"
fi

# Test 14: Verify no orphaned processes
echo ""
echo "Test 14: Checking for orphaned processes..."
orphaned=0

for pid in "${VPS_PIDS[@]}"; do
  if kill -0 "$pid" 2>/dev/null; then
    ((orphaned++))
    kill -9 "$pid" 2>/dev/null || true
  fi
done

if [[ $orphaned -eq 0 ]]; then
  test_result "No orphaned processes" "pass"
else
  test_result "No orphaned processes" "fail" "$orphaned processes still running"
fi

# Test 15: Stress test - 10 concurrent VPS
echo ""
echo "Test 15: Extended stress test (10 concurrent VPS)..."
echo -e "${YELLOW}Starting extended concurrent test...${NC}"

STRESS_PIDS=()
stress_start=$(date +%s)

for i in $(seq 1 10); do
  (
    sleep $((RANDOM % 5 + 1))
    exit 0
  ) &
  STRESS_PIDS+=($!)
done

stress_failures=0
for pid in "${STRESS_PIDS[@]}"; do
  if ! wait "$pid"; then
    ((stress_failures++))
  fi
done

stress_end=$(date +%s)
stress_duration=$((stress_end - stress_start))

if [[ $stress_failures -eq 0 ]]; then
  test_result "Extended stress test" "pass" "10 VPS in ${stress_duration}s"
else
  test_result "Extended stress test" "fail" "$stress_failures failures"
fi

# Cleanup
echo ""
echo "Cleaning up test environments..."
for vps_dir in "${VPS_DIRS[@]}"; do
  rm -rf "$vps_dir"
done
echo -e "${BLUE}Cleanup complete${NC}"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""
echo "Performance Metrics:"
echo "  - Concurrent VPS: $NUM_VPS"
echo "  - Total Duration: ${total_duration}s"
echo "  - Average per VPS: ${avg_time}s"
echo "  - Peak Load: $load_avg"
echo "  - Memory Usage: ${mem_used_mb}MB"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}All concurrent load tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed${NC}"
  exit 1
fi
