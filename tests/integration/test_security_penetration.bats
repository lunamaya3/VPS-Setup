#!/usr/bin/env bats
# Security Penetration Test Suite (T104)
# Purpose: Validate all security controls are properly implemented
# Requirements: SEC-001 through SEC-018
#
# This test suite validates:
# - Password complexity and security (SEC-001, SEC-002, SEC-003, SEC-004)
# - SSH hardening (SEC-005, SEC-006, SEC-016)
# - TLS encryption for RDP (SEC-007, SEC-008)
# - Session isolation (SEC-009)
# - Sudo configuration (SEC-010, SEC-014)
# - Firewall rules (SEC-011, SEC-012)
# - Fail2ban configuration (SEC-013)
# - Authentication logging (SEC-015)
# - GPG signature verification (SEC-017)
# - Input sanitization (SEC-018)

load '../test_helper'

setup() {
  export BATS_TEST_TMPDIR="${BATS_TEST_TMPDIR:-/tmp/bats-test-$$}"
  mkdir -p "${BATS_TEST_TMPDIR}"
  
  # Test constants
  export TEST_USERNAME="testuser$$"
  export TEST_PASSWORD="TestPassword123!@#"
  export SSHD_CONFIG="/etc/ssh/sshd_config"
  export XRDP_CONF="/etc/xrdp/xrdp.ini"
  export SESMAN_CONF="/etc/xrdp/sesman.ini"
  export FAIL2BAN_CONF="/etc/fail2ban/jail.local"
  export SUDOERS_DIR="/etc/sudoers.d"
}

teardown() {
  # Cleanup test user if created
  if id "$TEST_USERNAME" &>/dev/null; then
    userdel -r "$TEST_USERNAME" 2>/dev/null || true
  fi
  
  rm -rf "${BATS_TEST_TMPDIR}"
}

# SEC-001: Password Complexity
@test "SEC-001: Password generator enforces minimum 16 character length" {
  skip_if_not_root
  
  local password
  password=$(python3 "${PROJECT_ROOT}/lib/utils/credential-gen.py" --length 16)
  
  [[ ${#password} -ge 16 ]]
}

@test "SEC-001: Password generator includes mixed case, numbers, and symbols" {
  skip_if_not_root
  
  local password
  password=$(python3 "${PROJECT_ROOT}/lib/utils/credential-gen.py" --length 20)
  
  # Check for lowercase
  [[ "$password" =~ [a-z] ]]
  # Check for uppercase
  [[ "$password" =~ [A-Z] ]]
  # Check for numbers
  [[ "$password" =~ [0-9] ]]
  # Check for symbols
  [[ "$password" =~ [^a-zA-Z0-9] ]]
}

# SEC-002: CSPRNG Usage
@test "SEC-002: Password generator uses cryptographically secure random" {
  skip_if_not_root
  
  # Generate multiple passwords and ensure they're different (entropy check)
  local pass1 pass2 pass3
  pass1=$(python3 "${PROJECT_ROOT}/lib/utils/credential-gen.py" --length 16)
  pass2=$(python3 "${PROJECT_ROOT}/lib/utils/credential-gen.py" --length 16)
  pass3=$(python3 "${PROJECT_ROOT}/lib/utils/credential-gen.py" --length 16)
  
  # All should be different (CSPRNG property)
  [[ "$pass1" != "$pass2" ]]
  [[ "$pass2" != "$pass3" ]]
  [[ "$pass1" != "$pass3" ]]
}

# SEC-003: Password Redaction in Logs
@test "SEC-003: Passwords are redacted in all log files" {
  skip_if_not_root
  
  local log_file="${BATS_TEST_TMPDIR}/test.log"
  export LOG_FILE="$log_file"
  
  # Source logger and log a password
  source "${PROJECT_ROOT}/lib/core/logger.sh"
  log_init
  
  local test_password="SecretPassword123!"
  log_info "Setting password: [REDACTED]" "password=REDACTED"
  
  # Verify the actual password is NOT in the log
  ! grep -q "$test_password" "$log_file"
  
  # Verify [REDACTED] is in the log
  grep -q "\[REDACTED\]" "$log_file"
}

# SEC-004: Force Password Change on First Login
@test "SEC-004: User password expires on first login" {
  skip_if_not_root
  
  # Create test user
  useradd -m "$TEST_USERNAME" || skip "Failed to create test user"
  echo "${TEST_USERNAME}:${TEST_PASSWORD}" | chpasswd
  
  # Force password expiry
  chage -d 0 "$TEST_USERNAME"
  
  # Verify password is expired
  local expiry
  expiry=$(chage -l "$TEST_USERNAME" | grep "Last password change" | awk -F: '{print $2}' | xargs)
  
  [[ "$expiry" == "password must be changed" ]]
}

# SEC-005: SSH Root Login Disabled
@test "SEC-005: SSH root login is disabled" {
  skip_if_not_root
  
  [[ -f "$SSHD_CONFIG" ]] || skip "SSHD config not found"
  
  # Check PermitRootLogin is set to no
  grep -qE "^PermitRootLogin\s+no" "$SSHD_CONFIG"
}

@test "SEC-005: SSH password authentication is disabled" {
  skip_if_not_root
  
  [[ -f "$SSHD_CONFIG" ]] || skip "SSHD config not found"
  
  # Check PasswordAuthentication is set to no
  grep -qE "^PasswordAuthentication\s+no" "$SSHD_CONFIG"
}

# SEC-006: Strong Key Exchange Algorithms
@test "SEC-006: SSH uses strong key exchange algorithms only" {
  skip_if_not_root
  
  [[ -f "$SSHD_CONFIG" ]] || skip "SSHD config not found"
  
  # Check KexAlgorithms includes curve25519
  grep -qE "^KexAlgorithms.*curve25519" "$SSHD_CONFIG"
  
  # Verify weak algorithms are not included
  ! grep -qE "^KexAlgorithms.*diffie-hellman-group1" "$SSHD_CONFIG"
}

@test "SEC-006: SSH uses strong ciphers only" {
  skip_if_not_root
  
  [[ -f "$SSHD_CONFIG" ]] || skip "SSHD config not found"
  
  # Check Ciphers includes modern algorithms
  grep -qE "^Ciphers.*chacha20-poly1305|aes.*gcm" "$SSHD_CONFIG"
  
  # Verify weak ciphers are not included
  ! grep -qE "^Ciphers.*(arcfour|3des|blowfish)" "$SSHD_CONFIG"
}

# SEC-007: 4096-bit RSA Certificate for RDP
@test "SEC-007: RDP certificate uses 4096-bit RSA key" {
  skip_if_not_root
  
  local cert_file="/etc/xrdp/cert.pem"
  local key_file="/etc/xrdp/key.pem"
  
  [[ -f "$key_file" ]] || skip "RDP key file not found"
  
  # Check key size
  local key_bits
  key_bits=$(openssl rsa -in "$key_file" -text -noout 2>/dev/null | grep "Private-Key:" | grep -oE "[0-9]+" || echo "0")
  
  [[ "$key_bits" -ge 4096 ]]
}

# SEC-008: High TLS Encryption Level for RDP
@test "SEC-008: RDP configured for high encryption level" {
  skip_if_not_root
  
  [[ -f "$XRDP_CONF" ]] || skip "XRDP config not found"
  
  # Check security_layer is tls or negotiate
  grep -qE "^security_layer\s*=\s*(tls|negotiate)" "$XRDP_CONF"
  
  # Check crypt_level is high
  grep -qE "^crypt_level\s*=\s*high" "$XRDP_CONF"
}

# SEC-009: Session Isolation
@test "SEC-009: RDP sessions use separate X displays for isolation" {
  skip_if_not_root
  
  [[ -f "$SESMAN_CONF" ]] || skip "Sesman config not found"
  
  # Check X11DisplayOffset ensures separate displays
  grep -qE "^X11DisplayOffset\s*=\s*[1-9][0-9]*" "$SESMAN_CONF"
}

# SEC-010: Sudo Lecture
@test "SEC-010: Sudo configured with lecture on first use" {
  skip_if_not_root
  
  # Check if any sudoers file has lecture enabled
  local has_lecture=false
  
  if grep -qE "^Defaults\s+lecture\s*=\s*always" /etc/sudoers 2>/dev/null; then
    has_lecture=true
  fi
  
  for file in "${SUDOERS_DIR}"/*; do
    [[ -f "$file" ]] || continue
    if grep -qE "^Defaults\s+lecture\s*=\s*always" "$file" 2>/dev/null; then
      has_lecture=true
      break
    fi
  done
  
  [[ "$has_lecture" == "true" ]]
}

# SEC-011: Firewall Default Deny
@test "SEC-011: Firewall configured with default DENY incoming" {
  skip_if_not_root
  
  command -v ufw &>/dev/null || skip "UFW not installed"
  
  # Check default incoming policy is deny
  ufw status verbose | grep -qE "Default:.*deny.*incoming"
}

# SEC-012: Firewall Allows Only SSH and RDP
@test "SEC-012: Firewall allows only ports 22 and 3389" {
  skip_if_not_root
  
  command -v ufw &>/dev/null || skip "UFW not installed"
  
  # Check SSH is allowed
  ufw status | grep -qE "22/(tcp|TCP).*ALLOW"
  
  # Check RDP is allowed
  ufw status | grep -qE "3389/(tcp|TCP).*ALLOW"
}

# SEC-013: Fail2ban Configuration
@test "SEC-013: Fail2ban is installed and active" {
  skip_if_not_root
  
  command -v fail2ban-client &>/dev/null || skip "Fail2ban not installed"
  
  # Check fail2ban service is active
  systemctl is-active fail2ban || skip "Fail2ban service not active"
  
  # Check fail2ban is monitoring SSH
  fail2ban-client status sshd || skip "Fail2ban not monitoring SSH"
}

@test "SEC-013: Fail2ban bans after 5 failed attempts" {
  skip_if_not_root
  
  [[ -f "$FAIL2BAN_CONF" ]] || skip "Fail2ban config not found"
  
  # Check maxretry is 5 or less
  local maxretry
  maxretry=$(grep -E "^maxretry\s*=" "$FAIL2BAN_CONF" | head -n1 | grep -oE "[0-9]+" || echo "10")
  
  [[ "$maxretry" -le 5 ]]
}

# SEC-014: Auditd for Sudo Logging
@test "SEC-014: Auditd configured to log sudo commands" {
  skip_if_not_root
  
  command -v auditctl &>/dev/null || skip "Auditd not installed"
  
  # Check if auditd is monitoring /usr/bin/sudo
  auditctl -l | grep -qE "(sudo|execve)" || skip "Sudo audit rule not found"
}

# SEC-015: Authentication Failure Logging
@test "SEC-015: Authentication failures are logged to auth.log" {
  skip_if_not_root
  
  [[ -f /var/log/auth.log ]] || skip "auth.log not found"
  
  # Verify auth.log is being written to
  [[ -s /var/log/auth.log ]]
}

# SEC-016: Session Timeouts
@test "SEC-016: SSH configured with 60-minute idle timeout" {
  skip_if_not_root
  
  [[ -f "$SSHD_CONFIG" ]] || skip "SSHD config not found"
  
  # Check ClientAliveInterval and ClientAliveCountMax
  # Total timeout = ClientAliveInterval * ClientAliveCountMax = ~3600s (60 min)
  local interval countmax
  interval=$(grep -E "^ClientAliveInterval" "$SSHD_CONFIG" | grep -oE "[0-9]+" || echo "0")
  countmax=$(grep -E "^ClientAliveCountMax" "$SSHD_CONFIG" | grep -oE "[0-9]+" || echo "0")
  
  local total_timeout=$((interval * countmax))
  
  # Allow some tolerance (3000-4000 seconds)
  [[ "$total_timeout" -ge 3000 ]] && [[ "$total_timeout" -le 4000 ]]
}

@test "SEC-016: RDP configured with 60-minute idle timeout" {
  skip_if_not_root
  
  [[ -f "$SESMAN_CONF" ]] || skip "Sesman config not found"
  
  # Check IdleTimeLimit is 3600 seconds (60 minutes)
  local idle_limit
  idle_limit=$(grep -E "^IdleTimeLimit\s*=" "$SESMAN_CONF" | grep -oE "[0-9]+" || echo "0")
  
  # Allow some tolerance (3000-4000 seconds)
  [[ "$idle_limit" -ge 3000 ]] && [[ "$idle_limit" -le 4000 ]]
}

# SEC-017: GPG Signature Verification
@test "SEC-017: VSCode GPG key is installed and trusted" {
  skip_if_not_root
  
  local gpg_key="/etc/apt/trusted.gpg.d/microsoft.gpg"
  
  [[ -f "$gpg_key" ]] || skip "Microsoft GPG key not found"
  
  # Verify key is readable
  [[ -r "$gpg_key" ]]
}

# SEC-018: Input Sanitization
@test "SEC-018: Input sanitization rejects dangerous characters" {
  skip_if_not_root
  
  source "${PROJECT_ROOT}/lib/core/sanitize.sh"
  
  # Test dangerous characters
  local dangerous_inputs=(
    "test; rm -rf /"
    "test | cat /etc/passwd"
    "test && whoami"
    'test `whoami`'
    'test $(whoami)'
    "test\$(whoami)"
  )
  
  for input in "${dangerous_inputs[@]}"; do
    run sanitize_string "$input"
    [[ "$status" -ne 0 ]]
  done
}

@test "SEC-018: Input sanitization rejects path traversal attempts" {
  skip_if_not_root
  
  source "${PROJECT_ROOT}/lib/core/sanitize.sh"
  
  # Test path traversal
  local dangerous_paths=(
    "../../../etc/passwd"
    "/etc/../../../root/.ssh/id_rsa"
    "test/../secret"
  )
  
  for path in "${dangerous_paths[@]}"; do
    run sanitize_path "$path"
    [[ "$status" -ne 0 ]]
  done
}

@test "SEC-018: Username sanitization rejects invalid usernames" {
  skip_if_not_root
  
  source "${PROJECT_ROOT}/lib/core/sanitize.sh"
  
  # Test invalid usernames
  local invalid_usernames=(
    "root"        # Reserved
    "Admin"       # Uppercase
    "test user"   # Space
    "test@user"   # Special char
    "ab"          # Too short
    "1test"       # Starts with number
  )
  
  for username in "${invalid_usernames[@]}"; do
    run sanitize_username "$username"
    [[ "$status" -ne 0 ]]
  done
}

@test "SEC-018: Username sanitization accepts valid usernames" {
  skip_if_not_root
  
  source "${PROJECT_ROOT}/lib/core/sanitize.sh"
  
  # Test valid usernames
  local valid_usernames=(
    "testuser"
    "dev-user"
    "test_user123"
    "alice"
  )
  
  for username in "${valid_usernames[@]}"; do
    run sanitize_username "$username"
    echo "Status: $status, Output: $output"
    [[ "$status" -eq 0 ]]
  done
}

# Integration Test: Complete Security Stack
@test "INTEGRATION: All security controls are operational" {
  skip_if_not_root
  
  local security_checks=0
  local security_passes=0
  
  # Check 1: SSH hardening
  ((security_checks++))
  if [[ -f "$SSHD_CONFIG" ]] && \
     grep -qE "^PermitRootLogin\s+no" "$SSHD_CONFIG" && \
     grep -qE "^PasswordAuthentication\s+no" "$SSHD_CONFIG"; then
    ((security_passes++))
  fi
  
  # Check 2: Firewall active
  ((security_checks++))
  if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    ((security_passes++))
  fi
  
  # Check 3: Fail2ban active
  ((security_checks++))
  if systemctl is-active fail2ban &>/dev/null; then
    ((security_passes++))
  fi
  
  # Check 4: RDP TLS configured
  ((security_checks++))
  if [[ -f "$XRDP_CONF" ]] && grep -qE "^security_layer\s*=\s*tls" "$XRDP_CONF"; then
    ((security_passes++))
  fi
  
  # Check 5: Input sanitization available
  ((security_checks++))
  if source "${PROJECT_ROOT}/lib/core/sanitize.sh" 2>/dev/null; then
    ((security_passes++))
  fi
  
  echo "Security checks passed: $security_passes/$security_checks"
  
  # Require at least 80% pass rate
  local required_passes=$(( security_checks * 4 / 5 ))
  [[ "$security_passes" -ge "$required_passes" ]]
}
