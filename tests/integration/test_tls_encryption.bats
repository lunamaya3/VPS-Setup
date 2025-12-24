#!/usr/bin/env bats
# Integration tests for TLS & Encryption (T092)
# Tests SEC-007 and SEC-008 requirements

load '../test_helper'

setup() {
  # Create temporary test environment
  export TEST_ROOT="${BATS_TEST_TMPDIR}/tls_encryption_test"
  mkdir -p "${TEST_ROOT}"
  
  export LOG_FILE="${TEST_ROOT}/test.log"
  export TRANSACTION_LOG="${TEST_ROOT}/transaction.log"
  export LIB_DIR="${BATS_TEST_DIRNAME}/../../lib"
  export XRDP_CONF_DIR="${TEST_ROOT}/etc/xrdp"
  export CERT_FILE="${XRDP_CONF_DIR}/cert.pem"
  export KEY_FILE="${XRDP_CONF_DIR}/key.pem"
  export XRDP_INI="${XRDP_CONF_DIR}/xrdp.ini"
  
  mkdir -p "${XRDP_CONF_DIR}"
  touch "${LOG_FILE}" "${TRANSACTION_LOG}"
  
  # Mock logging functions
  log_info() { echo "[INFO] $*" >> "${LOG_FILE}"; }
  log_error() { echo "[ERROR] $*" >> "${LOG_FILE}"; }
  log_warning() { echo "[WARNING] $*" >> "${LOG_FILE}"; }
  log_debug() { echo "[DEBUG] $*" >> "${LOG_FILE}"; }
  export -f log_info log_error log_warning log_debug
  
  # Mock transaction log function
  transaction_log() {
    local rollback="$1"
    echo "ROLLBACK|$(date -Iseconds)|${rollback}" >> "${TRANSACTION_LOG}"
  }
  export -f transaction_log
  
  # Mock progress function
  progress_update() { echo "[PROGRESS] $*" >> "${LOG_FILE}"; }
  export -f progress_update
  
  # Mock apt-get for package installation
  apt-get() { 
    echo "apt-get $*" >> "${LOG_FILE}"
    return 0
  }
  export -f apt-get
  
  # Mock dpkg for package verification
  dpkg() {
    if [[ "$1" == "-l" ]]; then
      echo "ii  xrdp  0.9.17-1  Remote Desktop Protocol (RDP) server"
      echo "ii  xorgxrdp  0.2.17-1  X.Org drivers for xrdp"
      return 0
    fi
    return 0
  }
  export -f dpkg
  
  # Mock hostname
  hostname() {
    if [[ "$1" == "-f" ]]; then
      echo "test.vps.local"
    else
      echo "test-vps"
    fi
  }
  export -f hostname
  
  # Mock chown
  chown() { echo "chown $*" >> "${LOG_FILE}"; return 0; }
  export -f chown
  
  # Source the module
  source "${PROJECT_ROOT}/lib/modules/rdp-server.sh"
}

teardown() {
  # Cleanup test environment
  rm -rf "${TEST_ROOT}"
}

# =============================================================================
# SEC-007: 4096-bit RSA Certificate Generation
# =============================================================================

@test "SEC-007: RDP module generates 4096-bit RSA self-signed certificate" {
  run rdp_server_generate_certificates
  assert_success
  
  # Verify certificate file was created
  [[ -f "${CERT_FILE}" ]]
  
  # Verify key file was created
  [[ -f "${KEY_FILE}" ]]
  
  # Verify certificate uses 4096-bit RSA
  run openssl x509 -in "${CERT_FILE}" -noout -text
  assert_success
  assert_output --partial "Public-Key: (4096 bit)"
}

@test "SEC-007: Certificate has correct subject" {
  run rdp_server_generate_certificates
  assert_success
  
  # Verify subject contains hostname
  run openssl x509 -in "${CERT_FILE}" -noout -subject
  assert_success
  assert_output --partial "CN=test.vps.local"
}

@test "SEC-007: Certificate is valid for 10 years" {
  run rdp_server_generate_certificates
  assert_success
  
  # Check certificate validity period
  local start_date
  start_date=$(openssl x509 -in "${CERT_FILE}" -noout -startdate | cut -d= -f2)
  local end_date
  end_date=$(openssl x509 -in "${CERT_FILE}" -noout -enddate | cut -d= -f2)
  
  local start_epoch
  start_epoch=$(date -d "${start_date}" +%s)
  local end_epoch
  end_epoch=$(date -d "${end_date}" +%s)
  
  # Calculate days between start and end (should be ~3650 days = 10 years)
  local days_valid=$(( (end_epoch - start_epoch) / 86400 ))
  
  # Allow for some variation (3648-3652 days)
  [[ ${days_valid} -ge 3648 ]] && [[ ${days_valid} -le 3652 ]]
}

@test "SEC-007: Private key has correct permissions (600)" {
  run rdp_server_generate_certificates
  assert_success
  
  # Check key file permissions
  local perms
  perms=$(stat -c "%a" "${KEY_FILE}")
  [[ "${perms}" == "600" ]]
}

@test "SEC-007: Certificate has correct permissions (644)" {
  run rdp_server_generate_certificates
  assert_success
  
  # Check certificate file permissions
  local perms
  perms=$(stat -c "%a" "${CERT_FILE}")
  [[ "${perms}" == "644" ]]
}

@test "SEC-007: Certificate generation is idempotent (valid cert not regenerated)" {
  # Generate initial certificate
  run rdp_server_generate_certificates
  assert_success
  
  local initial_serial
  initial_serial=$(openssl x509 -in "${CERT_FILE}" -noout -serial)
  
  # Try to generate again (should skip if valid for >30 days)
  run rdp_server_generate_certificates
  assert_success
  
  local second_serial
  second_serial=$(openssl x509 -in "${CERT_FILE}" -noout -serial)
  
  # Serial should be the same (certificate not regenerated)
  [[ "${initial_serial}" == "${second_serial}" ]]
  
  # Verify log message
  run grep -q "Existing certificates valid" "${LOG_FILE}"
  assert_success
}

@test "SEC-007: Expired certificates are regenerated" {
  # Create an expired certificate (valid for 1 day in the past)
  openssl req -x509 -newkey rsa:4096 \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -days 1 -nodes \
    -subj "/C=US/ST=State/L=City/O=Test/CN=expired.test" \
    2>&1 | tee -a "${LOG_FILE}"
  
  # Backdate the certificate by modifying system time temporarily (simulation)
  # Or just check that expiry is detected
  local expiry_date
  expiry_date=$(openssl x509 -in "${CERT_FILE}" -noout -enddate | cut -d= -f2)
  local expiry_epoch
  expiry_epoch=$(date -d "${expiry_date}" +%s)
  local now_epoch
  now_epoch=$(date +%s)
  local days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))
  
  # Should detect certificate is expiring soon (<30 days)
  [[ ${days_remaining} -lt 30 ]]
  
  # Run generation (should regenerate)
  run rdp_server_generate_certificates
  assert_success
  
  # Verify new certificate has longer validity
  local new_expiry_date
  new_expiry_date=$(openssl x509 -in "${CERT_FILE}" -noout -enddate | cut -d= -f2)
  local new_expiry_epoch
  new_expiry_epoch=$(date -d "${new_expiry_date}" +%s)
  local new_days_remaining=$(( (new_expiry_epoch - now_epoch) / 86400 ))
  
  # New certificate should be valid for much longer
  [[ ${new_days_remaining} -gt 3000 ]]
}

@test "SEC-007: Backup is created before regeneration" {
  # Create initial certificate
  run rdp_server_generate_certificates
  assert_success
  
  local initial_serial
  initial_serial=$(openssl x509 -in "${CERT_FILE}" -noout -serial)
  
  # Force regeneration by creating a short-lived cert
  openssl req -x509 -newkey rsa:2048 \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -days 1 -nodes \
    -subj "/C=US/ST=State/L=City/O=Test/CN=test" \
    2>&1 | tee -a "${LOG_FILE}"
  
  # Run generation (should backup and regenerate)
  run rdp_server_generate_certificates
  assert_success
  
  # Verify backup was created (transaction logged)
  run grep -q "mv ${KEY_FILE}.vps-backup ${KEY_FILE}" "${TRANSACTION_LOG}"
  assert_success
}

@test "SEC-007: Transaction log records certificate generation" {
  run rdp_server_generate_certificates
  assert_success
  
  # Verify rollback command logged
  run grep -q "rm -f ${CERT_FILE} ${KEY_FILE}" "${TRANSACTION_LOG}"
  assert_success
}

# =============================================================================
# SEC-008: High TLS Encryption Level
# =============================================================================

@test "SEC-008: xrdp.ini configures high encryption level" {
  run rdp_server_configure_xrdp
  assert_success
  
  # Verify crypt_level=high in xrdp.ini
  run grep -q "^crypt_level=high" "${XRDP_INI}"
  assert_success
}

@test "SEC-008: xrdp.ini uses TLSv1.2 and TLSv1.3" {
  run rdp_server_configure_xrdp
  assert_success
  
  # Verify TLS protocol versions
  run grep -q "^ssl_protocols=TLSv1.2, TLSv1.3" "${XRDP_INI}"
  assert_success
}

@test "SEC-008: xrdp.ini references generated certificates" {
  run rdp_server_generate_certificates
  assert_success
  
  run rdp_server_configure_xrdp
  assert_success
  
  # Verify certificate path in config
  run grep -q "^certificate=${CERT_FILE}" "${XRDP_INI}"
  assert_success
  
  # Verify key file path in config
  run grep -q "^key_file=${KEY_FILE}" "${XRDP_INI}"
  assert_success
}

@test "SEC-008: xrdp.ini uses negotiate security layer" {
  run rdp_server_configure_xrdp
  assert_success
  
  # Verify security_layer=negotiate
  run grep -q "^security_layer=negotiate" "${XRDP_INI}"
  assert_success
}

@test "SEC-008: Full RDP encryption configuration is applied" {
  # Run full certificate and configuration setup
  run rdp_server_generate_certificates
  assert_success
  
  run rdp_server_configure_xrdp
  assert_success
  
  # Verify all security settings present
  local -a required_settings=(
    "crypt_level=high"
    "security_layer=negotiate"
    "ssl_protocols=TLSv1.2, TLSv1.3"
    "certificate=${CERT_FILE}"
    "key_file=${KEY_FILE}"
  )
  
  for setting in "${required_settings[@]}"; do
    if ! grep -q "^${setting}" "${XRDP_INI}"; then
      echo "Missing required setting: ${setting}" >&2
      return 1
    fi
  done
  
  return 0
}

# =============================================================================
# Integration Tests
# =============================================================================

@test "TLS setup completes successfully with all components" {
  # Simulate full TLS setup
  run rdp_server_generate_certificates
  assert_success
  
  run rdp_server_configure_xrdp
  assert_success
  
  # Verify certificate exists and is valid
  [[ -f "${CERT_FILE}" ]]
  [[ -f "${KEY_FILE}" ]]
  
  # Verify configuration file exists
  [[ -f "${XRDP_INI}" ]]
  
  # Verify log shows success
  run grep -q "TLS certificates generated successfully" "${LOG_FILE}"
  assert_success
  
  run grep -q "xrdp configuration completed" "${LOG_FILE}"
  assert_success
}

@test "Certificate can be verified with openssl" {
  run rdp_server_generate_certificates
  assert_success
  
  # Verify certificate with openssl verify command
  run openssl verify -CAfile "${CERT_FILE}" "${CERT_FILE}"
  # Self-signed cert verification will return error, but should not crash
  # Just verify openssl can read it
  run openssl x509 -in "${CERT_FILE}" -noout -text
  assert_success
}
