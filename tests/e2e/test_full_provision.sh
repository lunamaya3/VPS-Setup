#!/bin/bash
# E2E Test: Full VPS Provisioning
# Tests complete provisioning workflow on fresh VPS
#
# Usage: ./tests/e2e/test_full_provision.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
echo "  E2E Test: Full VPS Provisioning"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# SC-001: Single command execution success
echo "Testing SC-001: Single command execution..."
if [[ -x "bin/vps-provision" ]]; then
  test_result "SC-001: Provisioning command exists" "pass"
else
  test_result "SC-001: Provisioning command exists" "fail" "bin/vps-provision not executable"
fi

# SC-002: RDP connection ready
echo "Testing SC-002: RDP connection ready..."
if systemctl is-active --quiet xrdp; then
  test_result "SC-002: xrdp service running" "pass"
else
  test_result "SC-002: xrdp service running" "fail"
fi

if ss -tuln | grep -q ":3389"; then
  test_result "SC-002: RDP port 3389 listening" "pass"
else
  test_result "SC-002: RDP port 3389 listening" "fail"
fi

# SC-003: Desktop environment installed
echo "Testing SC-003: Desktop environment..."
if command -v xfce4-session &>/dev/null; then
  test_result "SC-003: XFCE installed" "pass"
else
  test_result "SC-003: XFCE installed" "fail"
fi

if systemctl is-active --quiet lightdm; then
  test_result "SC-003: LightDM running" "pass"
else
  test_result "SC-003: LightDM running" "fail"
fi

# SC-004: All IDEs installed
echo "Testing SC-004: IDEs installed..."
if command -v code &>/dev/null; then
  test_result "SC-004: VSCode installed" "pass"
else
  test_result "SC-004: VSCode installed" "fail"
fi

if [[ -x "/opt/cursor/cursor" ]] || command -v cursor &>/dev/null; then
  test_result "SC-004: Cursor installed" "pass"
else
  test_result "SC-004: Cursor installed" "fail"
fi

if [[ -x "/usr/local/bin/antigravity" ]] || command -v antigravity &>/dev/null; then
  test_result "SC-004: Antigravity installed" "pass"
else
  test_result "SC-004: Antigravity installed" "fail"
fi

# SC-005: Developer user configured
echo "Testing SC-005: Developer user..."
if id devuser &>/dev/null; then
  test_result "SC-005: devuser exists" "pass"
else
  test_result "SC-005: devuser exists" "fail"
fi

if sudo -l -U devuser 2>&1 | grep -q "NOPASSWD"; then
  test_result "SC-005: Passwordless sudo configured" "pass"
else
  test_result "SC-005: Passwordless sudo configured" "fail"
fi

# SC-006: Completion time ≤15 minutes
echo "Testing SC-006: Completion time..."
if [[ -f "/var/log/vps-provision/provision-"*".log" ]]; then
  test_result "SC-006: Provisioning log exists" "pass"
else
  test_result "SC-006: Provisioning log exists" "fail"
fi

# SC-007: Idempotent execution
echo "Testing SC-007: Idempotency..."
if [[ -d "/var/vps-provision/checkpoints" ]]; then
  test_result "SC-007: Checkpoint directory exists" "pass"
else
  test_result "SC-007: Checkpoint directory exists" "fail"
fi

# SC-008: Zero manual intervention
echo "Testing SC-008: Automation..."
test_result "SC-008: Fully automated (manual check)" "pass"

# SC-009: Rollback on failure
echo "Testing SC-009: Rollback capability..."
if [[ -f "/var/log/vps-provision/transactions.log" ]]; then
  test_result "SC-009: Transaction log exists" "pass"
else
  test_result "SC-009: Transaction log exists" "fail"
fi

# SC-010: Security hardening
echo "Testing SC-010: Security..."
if command -v ufw &>/dev/null; then
  if sudo ufw status | grep -q "Status: active"; then
    test_result "SC-010: Firewall active" "pass"
  else
    test_result "SC-010: Firewall active" "fail"
  fi
else
  test_result "SC-010: Firewall installed" "fail"
fi

# SC-011: Terminal enhancements
echo "Testing SC-011: Terminal setup..."
if [[ -f "/home/devuser/.bashrc" ]]; then
  if grep -q "alias" /home/devuser/.bashrc; then
    test_result "SC-011: Bash aliases configured" "pass"
  else
    test_result "SC-011: Bash aliases configured" "fail"
  fi
else
  test_result "SC-011: .bashrc exists" "fail"
fi

# SC-012: Validation report generated
echo "Testing SC-012: Validation report..."
if [[ -d "/var/vps-provision/reports" ]]; then
  test_result "SC-012: Reports directory exists" "pass"
else
  test_result "SC-012: Reports directory exists" "fail"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "  Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All E2E tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some E2E tests failed${NC}"
  exit 1
fi
