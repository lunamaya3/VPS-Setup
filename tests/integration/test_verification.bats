#!/usr/bin/env bats
# Integration tests for verification module

load '../test_helper'

setup() {
  # Source the verification module
  source "${PROJECT_ROOT}/lib/modules/verification.sh"
}

@test "verification_check_services: validates required services" {
  # This test requires services to be running - skip in CI
  skip "Requires running services"
  
  run verification_check_services
  [ "$status" -eq 0 ]
}

@test "verification_check_ides: detects installed IDEs" {
  # This test requires IDEs to be installed - skip in CI
  skip "Requires installed IDEs"
  
  run verification_check_ides
  [ "$status" -eq 0 ]
}

@test "verification_check_ports: validates network ports" {
  # This test requires ports to be open - skip in CI
  skip "Requires configured network"
  
  run verification_check_ports
  [ "$status" -eq 0 ]
}

@test "verification_check_permissions: validates file permissions" {
  # This test requires specific files - skip in CI
  skip "Requires provisioned system"
  
  run verification_check_permissions
  [ "$status" -eq 0 ]
}

@test "verification_check_configurations: validates config files" {
  # This test requires config files - skip in CI
  skip "Requires provisioned system"
  
  run verification_check_configurations
  [ "$status" -eq 0 ]
}

@test "verification_execute: runs all verification checks" {
  # This test requires full system - skip in CI
  skip "Requires fully provisioned system"
  
  run verification_execute
  [ "$status" -eq 0 ]
}

@test "verification module exports required functions" {
  # Check that functions are exported
  declare -F verification_check_services
  declare -F verification_check_ides
  declare -F verification_check_ports
  declare -F verification_check_permissions
  declare -F verification_check_configurations
  declare -F verification_execute
}
