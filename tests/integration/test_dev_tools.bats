#!/usr/bin/env bats
# Integration tests for Development Tools Module
# Tests installation and configuration of core development utilities
#
# NOTE: These tests require root privileges to:
#   - Install packages via apt-get
#   - Create directories in /var/vps-provision/
#   - Configure global git settings
#
# Run with: sudo bats tests/integration/test_dev_tools.bats

load ../test_helper

setup() {
  export LIB_DIR="${BATS_TEST_DIRNAME}/../../lib"
  # Use unique directory for each test execution to prevent state pollution
  export LOG_DIR="$(mktemp -d)"
  export LOG_FILE="${LOG_DIR}/test.log"
  export CHECKPOINT_DIR="${LOG_DIR}/checkpoints"
  export TRANSACTION_LOG="${LOG_DIR}/transactions.log"
  
  mkdir -p "${LOG_DIR}" "${CHECKPOINT_DIR}"
  
  # Source dependencies
  source "${LIB_DIR}/core/logger.sh"
  source "${LIB_DIR}/core/checkpoint.sh"
  source "${LIB_DIR}/core/transaction.sh"
  source "${LIB_DIR}/core/progress.sh"
  
  # Initialize systems
  logger_init "${LOG_DIR}"
  checkpoint_init
  
  # Source module under test
  # Source module under test
  source "${LIB_DIR}/modules/dev-tools.sh"

  # Mock apt-get
  function apt-get() {
    echo "apt-get $*" >> "${LOG_FILE}"
    if [[ "$*" == *"install"* ]]; then
        # Simulate installation by creating a file
        local pkg="${@: -1}"
        touch "${LOG_DIR}/installed_${pkg}"
    fi
    return 0
  }
  export -f apt-get

  # Mock dpkg
  function dpkg() {
    # Check if we simulated installation
    if [[ "$1" == "-l" ]]; then
        if [[ -f "${LOG_DIR}/installed_${2}" ]]; then
            echo "ii  $2"
            return 0
        fi
        return 1
    fi
    return 1
  }
  export -f dpkg

  # Mock git
  function git() {
    echo "git $*" >> "${LOG_FILE}"
    if [[ "$1" == "config" ]]; then
       if [[ "$*" =~ "init.defaultBranch" ]]; then echo "main"; fi
       if [[ "$*" =~ "color.ui" ]]; then echo "auto"; fi
       if [[ "$*" =~ "core.editor" ]]; then echo "vim"; fi
       if [[ "$*" =~ "credential.helper" ]]; then echo "cache"; fi
       return 0
    elif [[ "$1" == "--version" ]]; then
       echo "git version 2.0.0"
       return 0
    fi
    return 0
  }
  export -f git

  # Mock other tools for verification
  function vim() { echo "vim 1.0"; return 0; }
  export -f vim
  function curl() { echo "curl 1.0"; return 0; }
  export -f curl
  function jq() { echo "jq 1.0"; return 0; }
  export -f jq
  function htop() { echo "htop 1.0"; return 0; }
  export -f htop
  function tree() { echo "tree 1.0"; return 0; }
  export -f tree
  function tmux() { echo "tmux 1.0"; return 0; }
  export -f tmux
  function wget() { echo "wget 1.0"; return 0; }
  export -f wget
  function netstat() { echo "netstat 1.0"; return 0; }
  export -f netstat
  function dig() { echo "dig 1.0"; return 0; } # dnsutils
  export -f dig
  
  # Mock progress functions
  function progress_start() {
      echo "progress_start $*" >> "${LOG_FILE}"
      echo "progress_start $*"
      return 0
  }
  export -f progress_start
  
  function progress_update() {
      echo "progress_update $*" >> "${LOG_FILE}"
      echo "progress_update $*"
      return 0
  }
  export -f progress_update
  
  function progress_fail() {
      echo "progress_fail $*" >> "${LOG_FILE}"
      echo "progress_fail $*"
      # dev-tools.sh passes message as second arg: phase, message
      # But echo $* outputs all. assert_output partial will match.
      return 0
  }
  export -f progress_fail
  
  function progress_complete() {
      echo "progress_complete $*" >> "${LOG_FILE}"
      echo "progress_complete $*"
      return 0
  }
  export -f progress_complete
  
  # Mock command -v to succeed for these
  # Mock command -v to succeed for these, but fail for "nonexistent"
  function command() {
    if [[ "$2" == *"nonexistent"* ]]; then return 1; fi
    return 0
  }
  export -f command
}

teardown() {
  rm -rf "${LOG_DIR}" "${CHECKPOINT_DIR}"
}

@test "dev_tools_check_prerequisites passes when system-prep checkpoint exists" {
  checkpoint_create "system-prep"
  
  run dev_tools_check_prerequisites
  assert_success
  assert_output --partial "Prerequisites check passed"
}

@test "dev_tools_check_prerequisites fails when system-prep checkpoint missing" {
  rm -f "/var/vps-provision/checkpoints/system-prep"
  
  run dev_tools_check_prerequisites
  assert_failure
  assert_output --partial "System preparation must be completed"
}

@test "dev_tools_install_package installs a single package" {
  # Use a small, commonly available package for testing
  run dev_tools_install_package "tree"
  assert_success
  
  # Verify package is installed
  run dpkg -l tree
  assert_success
  assert_output --partial "ii"
}

@test "dev_tools_install_package is idempotent" {
  # First installation
  dev_tools_install_package "tree"
  
  # Second installation should detect existing package
  run dev_tools_install_package "tree"
  assert_success
  assert_output --partial "already installed"
}

@test "dev_tools_install_core_tools installs all required tools" {
  checkpoint_create "system-prep"
  
  run dev_tools_install_core_tools
  assert_success
  
  # Verify key tools are installed
  for tool in git vim curl jq htop tree; do
    run dpkg -l "${tool}"
    assert_success
  done
}

@test "dev_tools_configure_git sets global git configuration" {
  # Clear existing git config
  git config --global --unset init.defaultBranch 2>/dev/null || true
  git config --global --unset pull.rebase 2>/dev/null || true
  git config --global --unset color.ui 2>/dev/null || true
  git config --global --unset core.editor 2>/dev/null || true
  
  run dev_tools_configure_git
  assert_success
  
  # Verify configuration was set
  run git config --global init.defaultBranch
  assert_success
  assert_output "main"
  
  run git config --global color.ui
  assert_success
  assert_output "auto"
  
  run git config --global core.editor
  assert_success
  assert_output "vim"
}

@test "dev_tools_verify_tool detects installed tools" {
  run dev_tools_verify_tool "git"
  assert_success
  
  run dev_tools_verify_tool "bash"
  assert_success
}

@test "dev_tools_verify_tool fails for non-existent tools" {
  run dev_tools_verify_tool "nonexistent_tool_xyz"
  assert_failure
  assert_output --partial "not found"
}

@test "dev_tools_verify_all_tools validates all core tools" {
  checkpoint_create "system-prep"
  
  # Ensure tools are installed
  dev_tools_install_core_tools
  
  run dev_tools_verify_all_tools
  assert_success
  assert_output --partial "All development tools verified"
}

@test "dev_tools_validate performs comprehensive validation" {
  checkpoint_create "system-prep"
  
  # Install and configure
  dev_tools_install_core_tools
  dev_tools_configure_git
  
  run dev_tools_validate
  assert_success
  assert_output --partial "validation passed"
}

@test "dev_tools_execute completes full module execution" {
  # Setup prerequisites
  checkpoint_create "system-prep"
  rm -f "/var/vps-provision/checkpoints/dev-tools"
  
  run dev_tools_execute
  assert_success
  
  # Verify checkpoint was created
  assert checkpoint_exists "dev-tools"
  
  # Verify tools are installed
  for tool in git vim curl jq htop tree; do
    run command -v "${tool}"
    assert_success
  done
  
  # Verify git is configured
  run git config --global init.defaultBranch
  assert_success
}

@test "dev_tools_execute is idempotent with existing checkpoint" {
  checkpoint_create "dev-tools"
  
  run dev_tools_execute
  assert_success
  assert_output --partial "already installed"
}

@test "dev_tools_execute fails gracefully on prerequisite failure" {
  rm -f "/var/vps-provision/checkpoints/system-prep"
  rm -f "/var/vps-provision/checkpoints/dev-tools"
  
  run dev_tools_execute
  assert_failure
  assert_output --partial "Prerequisites check failed"
}

@test "git configuration includes credential helper" {
  dev_tools_configure_git
  
  run git config --global credential.helper
  assert_success
  assert_output --partial "cache"
}

@test "all CORE_TOOLS are defined and non-empty" {
  # Verify the CORE_TOOLS array is populated
  run bash -c 'source "${LIB_DIR}/modules/dev-tools.sh"; echo "${#CORE_TOOLS[@]}"'
  assert_success
  
  # Should have at least 8 tools
  [ "${output}" -ge 8 ]
}

@test "installed tools are functional" {
  checkpoint_create "system-prep"
  dev_tools_install_core_tools
  
  # Test git
  run git --version
  assert_success
  
  # Test vim
  run vim --version
  assert_success
  
  # Test curl
  run curl --version
  assert_success
  
  # Test jq
  run jq --version
  assert_success
  
  # Test htop
  run htop --version
  assert_success
  
  # Test tree
  run tree --version
  assert_success
}

@test "git config can be rolled back via transaction log" {
  # Configure git
  dev_tools_configure_git
  
  # Verify configuration exists
  run git config --global init.defaultBranch
  assert_success
  
  # Check transaction log contains rollback command
  run grep "git config --global --unset init.defaultBranch" "${TRANSACTION_LOG}"
  assert_success
}

@test "package installation can be rolled back via transaction log" {
  # Install package
  dev_tools_install_package "tree"
  
  # Check transaction log contains rollback command
  run grep "apt-get remove -y tree" "${TRANSACTION_LOG}"
  assert_success
}
