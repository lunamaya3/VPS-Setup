# Project Workflow Analysis Blueprint - VPS Developer Workstation Provisioning

**Generated:** 2025-12-25  
**Project Version:** 1.0.0  
**Analysis Type:** Implementation-Ready Workflow Documentation  
**Project Type:** CLI Automation Tool (Bash + Python)  
**Architecture Pattern:** Modular + Transaction-Safe + Idempotent

---

## Executive Summary

This blueprint documents 5 representative end-to-end workflows that serve as implementation templates for the VPS Developer Workstation Provisioning system. The project follows a CLI-driven automation pattern where `bin/vps-provision` orchestrates multiple provisioning modules through a checkpoint-based, transaction-safe framework.

### Technology Stack

- **Primary Language**: Bash 5.1+ (shell scripting for system automation)
- **Utility Language**: Python 3.11+ (health checks, validation, credential generation)
- **Testing**: BATS 1.10.0+ (Bash Automated Testing System)
- **Target Platform**: Debian 13 (Bookworm) VPS
- **Architecture**: Modular library system with 14 core modules + 16 provisioning modules

---

## Workflow 1: Complete VPS Provisioning

### Overview

**Name**: End-to-End VPS Provisioning Workflow  
**Business Purpose**: Transform fresh Debian 13 VPS into fully-functional developer workstation  
**Triggering Action**: User executes `./bin/vps-provision` as root on fresh VPS  
**Duration**: ≤15 minutes on 4GB/2vCPU droplet  
**Success Criteria**: RDP-accessible desktop with VSCode, Cursor, and Antigravity installed

### Entry Point Implementation

**File**: `bin/vps-provision` (640 lines)  
**Function**: `main()`

**Complete Execution Flow**:

```bash
main() -> 
  parse_arguments() ->
  logger_set_level() ->
  show_banner() ->
  check_prerequisites() ->
    validator_check_root()
    validator_check_os()
    validator_check_ram()
    validator_check_disk()
    validator_check_network()
  config_load_default() | config_load(custom_path) ->
  checkpoint_init() ->
  ux_init() ->
  state_init_session() ->
  validator_check_all() ->
  [If DRY_RUN: show_dry_run_plan() -> exit]
  [If FORCE_MODE: checkpoint_handle_force_mode()]
  provision_execute() ->  # (Would be implemented in Phase 3)
    system_prep_execute()
    desktop_env_execute()
    rdp_server_execute()
    user_provisioning_execute()
    parallel_ide_install_execute()
    terminal_setup_execute()
    dev_tools_execute()
    verification_execute()
  state_update_status("COMPLETED")
}
```

### Data Flow

```
User CLI Input (arguments)
    ↓
Configuration Loading (default.conf → system → user → CLI)
    ↓
Validation (prerequisites check)
    ↓
Session Initialization (/var/vps-provision/sessions/)
    ↓
Checkpoint System (/var/vps-provision/checkpoints/)
    ↓
Module Execution (sequential phases)
    ├→ Transaction Log (/var/log/vps-provision/transactions.log)
    ├→ Main Log (/var/log/vps-provision/provision.log)
    ├→ Progress Updates (real-time console)
    └→ State Updates (session files)
    ↓
Verification (Python health-check.py)
    ↓
Final Status Update
    ↓
Exit (0=success, non-zero=failure)
```

### Prerequisites Validation

**File**: `lib/core/validator.sh`

**Functions**:
- `validator_check_root()` - Verify running as root (EUID=0)
- `validator_check_os()` - Verify Debian 13 via /etc/os-release
- `validator_check_ram()` - Verify ≥2GB RAM via /proc/meminfo
- `validator_check_disk()` - Verify ≥25GB free space via df
- `validator_check_network()` - Verify connectivity via ping test

---

## Workflow 2: Module Execution Pattern

### Overview

**Name**: Standard Module Execution Workflow  
**Business Purpose**: Execute a single provisioning phase with checkpoint-based idempotency  
**Triggering Action**: Called by main orchestrator or executed standalone  
**Example Module**: `lib/modules/system-prep.sh`

### Module Structure Template

```bash
#!/bin/bash
set -euo pipefail

# Prevent double-sourcing
if [[ -n "${_SYSTEM_PREP_SH_LOADED:-}" ]]; then
  return 0
fi
readonly _SYSTEM_PREP_SH_LOADED=1

# Source dependencies
LIB_DIR="$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"
source "${LIB_DIR}/core/transaction.sh"
source "${LIB_DIR}/core/progress.sh"

# Module constants
readonly MODULE_CHECKPOINT="system-prep"

# Module functions
module_check_prerequisites() {
  log_debug "Checking prerequisites..."
  # Validation logic
  return 0
}

module_install() {
  log_info "Installing components..."
  # Installation logic
  transaction_record "Installed X" "apt-get remove -y X"
}

module_configure() {
  log_info "Configuring components..."
  # Configuration logic
  transaction_record "Modified /etc/config" "cp /etc/config.bak /etc/config"
}

module_verify() {
  log_info "Verifying installation..."
  # Verification logic
  return 0
}

# Main entry point
module_execute() {
  log_info "Starting module execution"
  
  # Check if already completed
  if checkpoint_exists "${MODULE_CHECKPOINT}"; then
    log_info "Module already completed (checkpoint found)"
    return 0
  fi
  
  # Start checkpoint
  checkpoint_start "${MODULE_CHECKPOINT}"
  
  # Execute phases
  module_check_prerequisites || return 1
  module_install || return 1
  module_configure || return 1
  module_verify || return 1
  
  # Create checkpoint
  checkpoint_create "${MODULE_CHECKPOINT}"
  
  log_info "Module execution completed"
}
```

### Checkpoint-Based Idempotency

**File**: `lib/core/checkpoint.sh`

**Key Functions**:

```bash
# Create checkpoint marker
checkpoint_create() {
  local checkpoint_name="$1"
  local checkpoint_file="${CHECKPOINT_DIR}/${checkpoint_name}.checkpoint"
  
  cat > "$checkpoint_file" <<EOF
CHECKPOINT_NAME="$checkpoint_name"
CREATED_AT="$(date -Iseconds)"
CREATED_BY="$(whoami)"
PID="$$"
EOF
  
  chmod 640 "$checkpoint_file"
  log_debug "Checkpoint created: $checkpoint_name"
}

# Check if checkpoint exists
checkpoint_exists() {
  local checkpoint_name="$1"
  local checkpoint_file="${CHECKPOINT_DIR}/${checkpoint_name}.checkpoint"
  
  if [[ -f "$checkpoint_file" ]]; then
    log_debug "Checkpoint exists: $checkpoint_name"
    return 0
  fi
  
  return 1
}

# Clear all checkpoints (force mode)
checkpoint_clear_all() {
  rm -f "${CHECKPOINT_DIR}"/*.checkpoint
  log_info "All checkpoints cleared"
}
```

### Transaction Recording for Rollback

**File**: `lib/core/transaction.sh`

```bash
# Record action with rollback command
transaction_record() {
  local action_description="$1"
  local rollback_command="$2"
  local timestamp=$(date -Iseconds)
  
  echo "${timestamp}|${action_description}|${rollback_command}" >> "${TRANSACTION_LOG}"
  
  log_debug "Transaction recorded: ${action_description}"
}

# Example usage in module
apt-get install -y nginx
transaction_record "Installed nginx" "apt-get remove -y nginx"

cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
sed -i 's/80/8080/g' /etc/nginx/nginx.conf
transaction_record "Modified nginx.conf" "cp /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf"
```

---

## Workflow 3: Error Handling & Rollback

### Overview

**Name**: Automatic Rollback on Failure  
**Business Purpose**: Restore system to clean state when provisioning fails  
**Triggering Action**: Any error during provisioning execution  
**Recovery Time**: ≤5 minutes for complete rollback

### Error Handler Implementation

**File**: `lib/core/error-handler.sh`

```bash
# Global error handler (trap ERR)
error_handler() {
  local exit_code="$1"
  local failed_command="$2"
  local source_file="$3"
  local line_number="$4"
  
  log_error "Command failed with exit code ${exit_code}"
  log_error "Failed command: ${failed_command}"
  log_error "Location: ${source_file}:${line_number}"
  
  # Log stack trace
  log_error "Stack trace:"
  local frame=0
  while caller $frame; do
    ((frame++))
  done | while read line func file; do
    log_error "  at ${func} (${file}:${line})"
  done
  
  # Trigger rollback if enabled
  if [[ "${AUTO_ROLLBACK:-true}" == "true" ]]; then
    log_warning "Initiating automatic rollback..."
    rollback_execute
  fi
  
  # Update session status
  state_update_status "FAILED"
  
  exit "${exit_code}"
}

# Set trap in main script
trap 'error_handler $? "$BASH_COMMAND" "${BASH_SOURCE[0]}" "${LINENO}"' ERR
```

### Rollback Implementation

**File**: `lib/core/rollback.sh`

```bash
rollback_execute() {
  log_info "Starting rollback process..."
  
  if [[ ! -f "${TRANSACTION_LOG}" ]]; then
    log_warning "No transaction log found - nothing to roll back"
    return 0
  fi
  
  local rollback_count=0
  local failed_count=0
  
  # Read transactions in reverse order (LIFO)
  tac "${TRANSACTION_LOG}" | while IFS='|' read -r timestamp description command; do
    log_info "Rolling back: ${description}"
    
    if eval "${command}" 2>&1 | tee -a "${LOG_FILE}"; then
      ((rollback_count++))
      log_info "✓ Rolled back: ${description}"
    else
      ((failed_count++))
      log_warning "✗ Rollback failed: ${description}"
    fi
  done
  
  log_info "Rollback complete: ${rollback_count} successful, ${failed_count} failed"
  
  # Clear checkpoints after rollback
  checkpoint_clear_all
  
  return 0
}
```

### Error Recovery Flow

```
Error Occurs (command fails, exit code ≠ 0)
    ↓
Trap Triggered (ERR signal)
    ↓
error_handler() Invoked
    ↓
Log Error Details (command, location, stack trace)
    ↓
Check AUTO_ROLLBACK Flag
    ↓
[If true] → rollback_execute()
    ↓
Read Transaction Log (reverse order)
    ↓
Execute Rollback Commands (LIFO order)
    ↓
Clear Checkpoints
    ↓
Update Session Status ("FAILED")
    ↓
Exit with Original Error Code
```

---

## Workflow 4: Post-Installation Validation

### Overview

**Name**: Health Check & Verification  
**Business Purpose**: Validate all components installed correctly before declaring success  
**Triggering Action**: Executed at end of provisioning or manually via CLI  
**Duration**: ≤60 seconds

### Validation Entry Point

**File**: `lib/modules/verification.sh`

```bash
verification_execute() {
  log_info "Starting post-installation verification..."
  
  if checkpoint_exists "verification"; then
    log_info "Verification already completed"
    return 0
  fi
  
  checkpoint_start "verification"
  
  # Run Python health check
  if python3 "${LIB_DIR}/utils/health-check.py" --output json > /tmp/health-results.json; then
    log_info "Health check passed"
  else
    log_error "Health check failed"
    cat /tmp/health-results.json
    return 1
  fi
  
  # Verify critical services
  verification_check_services || return 1
  
  # Verify user account
  verification_check_user || return 1
  
  # Verify IDEs
  verification_check_ides || return 1
  
  checkpoint_create "verification"
  log_info "Verification completed successfully"
}
```

### Python Health Check

**File**: `lib/utils/health-check.py`

```python
#!/usr/bin/env python3
"""
Post-installation health check for VPS provisioning.
Validates system components, services, and installations.
"""

import subprocess
import json
import sys
from typing import Dict, List, Any

class HealthCheck:
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.results: List[Dict[str, Any]] = []
    
    def run_command(self, cmd: List[str]) -> tuple[bool, str, str]:
        """Execute command and return (success, stdout, stderr)"""
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            return (result.returncode == 0, result.stdout, result.stderr)
        except Exception as e:
            return (False, "", str(e))
    
    def check_system(self) -> Dict[str, Any]:
        """Validate system configuration"""
        check = {
            "name": "System Configuration",
            "category": "system",
            "status": "pass",
            "message": "System meets requirements",
            "details": {}
        }
        
        # Check OS
        success, stdout, _ = self.run_command(["lsb_release", "-d"])
        if success and "Debian" in stdout:
            check["details"]["os"] = "Debian 13 (Bookworm)"
        else:
            check["status"] = "fail"
            check["message"] = "Not running Debian 13"
        
        # Check RAM
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    mem_kb = int(line.split()[1])
                    mem_gb = mem_kb / 1024 / 1024
                    check["details"]["ram_gb"] = f"{mem_gb:.1f}"
                    break
        
        return check
    
    def check_service(self, service_name: str) -> Dict[str, Any]:
        """Check if systemd service is running"""
        success, _, _ = self.run_command(["systemctl", "is-active", service_name])
        
        return {
            "name": f"Service: {service_name}",
            "category": "service",
            "status": "pass" if success else "fail",
            "message": f"{service_name} is {'running' if success else 'not running'}",
            "details": {"service": service_name}
        }
    
    def check_desktop(self) -> Dict[str, Any]:
        """Validate desktop environment installation"""
        check = {
            "name": "Desktop Environment",
            "category": "desktop",
            "status": "pass",
            "message": "Desktop environment installed",
            "details": {}
        }
        
        # Check XFCE
        success, _, _ = self.run_command(["which", "xfce4-session"])
        if not success:
            check["status"] = "fail"
            check["message"] = "XFCE not found"
        
        return check
    
    def check_rdp(self) -> Dict[str, Any]:
        """Validate RDP server configuration"""
        return self.check_service("xrdp")
    
    def check_ides(self) -> Dict[str, Any]:
        """Validate IDE installations"""
        check = {
            "name": "IDE Installations",
            "category": "ides",
            "status": "pass",
            "message": "All IDEs installed",
            "details": {}
        }
        
        ides = {
            "vscode": ["code", "--version"],
            "cursor": ["cursor", "--version"],
            "antigravity": ["antigravity", "--version"]
        }
        
        for ide_name, cmd in ides.items():
            success, stdout, _ = self.run_command(cmd)
            check["details"][ide_name] = "installed" if success else "not found"
            if not success:
                check["status"] = "warn"
                check["message"] = "Some IDEs missing"
        
        return check
    
    def run_all_checks(self) -> List[Dict[str, Any]]:
        """Execute all health checks"""
        self.results = [
            self.check_system(),
            self.check_service("lightdm"),
            self.check_rdp(),
            self.check_desktop(),
            self.check_ides()
        ]
        return self.results
    
    def format_results(self, output_format: str = "text") -> str:
        """Format results as text or JSON"""
        if output_format == "json":
            return json.dumps(self.results, indent=2)
        else:
            lines = ["Health Check Results:", "=" * 60]
            for result in self.results:
                status_symbol = "✓" if result["status"] == "pass" else "✗"
                lines.append(f"{status_symbol} {result['name']}: {result['message']}")
            return "\n".join(lines)

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="VPS Provisioning Health Check")
    parser.add_argument("--output", choices=["text", "json"], default="text")
    parser.add_argument("--verbose", action="store_true")
    
    args = parser.parse_args()
    
    checker = HealthCheck(verbose=args.verbose)
    checker.run_all_checks()
    
    print(checker.format_results(args.output))
    
    # Exit with error if any checks failed
    failed = sum(1 for r in checker.results if r["status"] == "fail")
    sys.exit(1 if failed > 0 else 0)

if __name__ == "__main__":
    main()
```

---

## Workflow 5: Development Workflow (Contributing)

### Overview

**Name**: Feature Development & Testing Workflow  
**Business Purpose**: Guide contributors through the development process  
**Triggering Action**: Developer wants to add a new feature or fix a bug  
**Phases**: Research → Design → Implement → Test → Document → PR

### Development Workflow Steps

#### 1. Create Feature Branch

```bash
git checkout main
git pull upstream main
git checkout -b feature/new-provisioning-module
```

#### 2. Follow Spec-Driven Workflow

```bash
# Create specification
vim specs/002-new-feature/spec.md

# Generate plan
make spec-plan SPEC=002-new-feature

# Generate tasks
make spec-tasks SPEC=002-new-feature
```

#### 3. Implement Changes

**Module Template** (`lib/modules/new-module.sh`):

```bash
#!/bin/bash
set -euo pipefail

if [[ -n "${_NEW_MODULE_LOADED:-}" ]]; then
  return 0
fi
readonly _NEW_MODULE_LOADED=1

LIB_DIR="$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"
source "${LIB_DIR}/core/transaction.sh"

readonly MODULE_CHECKPOINT="new-module"

new_module_execute() {
  if checkpoint_exists "${MODULE_CHECKPOINT}"; then
    return 0
  fi
  
  checkpoint_start "${MODULE_CHECKPOINT}"
  
  # Implementation here
  
  checkpoint_create "${MODULE_CHECKPOINT}"
}
```

#### 4. Write Tests

**Unit Test** (`tests/unit/test_new_module.bats`):

```bash
#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "${LIB_DIR}/modules/new-module.sh"
}

@test "new_module: executes successfully" {
  run new_module_execute
  [ "$status" -eq 0 ]
}

@test "new_module: is idempotent" {
  run new_module_execute
  run new_module_execute
  [ "$status" -eq 0 ]
  [[ "$output" =~ "already completed" ]]
}
```

#### 5. Run Tests & Linting

```bash
# Quick validation (<30s)
make test-quick

# Full test suite
make test

# Individual test categories
make test-unit
make test-integration
make test-contract

# Code quality
make lint
make format
```

#### 6. Commit Changes

```bash
git add .
git commit -m "feat: Add new provisioning module

- Implement new-module functionality
- Add unit and integration tests
- Update documentation

Resolves #123"
```

#### 7. Push and Create PR

```bash
git push origin feature/new-provisioning-module

# Create PR on GitHub with:
# - Clear description
# - Link to issue
# - Test results
# - Screenshots/demos if applicable
```

### Git Hooks (Automated Quality Gates)

**File**: `.git/hooks/pre-commit`

```bash
#!/bin/bash
# Runs automatically before each commit

set -uo pipefail

echo "Running pre-commit checks..."

# 1. Shellcheck on modified .sh files
SHELL_FILES=$(git diff --cached --name-only --diff-filter=ACMR "*.sh")
if [[ -n "$SHELL_FILES" ]]; then
  echo "$SHELL_FILES" | while read -r file; do
    if ! shellcheck -S warning "$file"; then
      echo "❌ Shellcheck failed for $file"
      exit 1
    fi
  done
fi

# 2. Python linting on modified .py files
PYTHON_FILES=$(git diff --cached --name-only --diff-filter=ACMR "*.py")
if [[ -n "$PYTHON_FILES" ]]; then
  if ! pylint $PYTHON_FILES; then
    echo "❌ Pylint failed"
    exit 1
  fi
fi

# 3. Secret scanning
if git diff --cached | grep -E "(password|secret|api[_-]?key)" -i; then
  echo "⚠️  Warning: Potential secrets detected in commit"
  read -p "Continue anyway? (y/N) " -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# 4. File permissions check
FILES_WITH_SECRETS=$(git diff --cached --name-only | grep -E "\.env|\.conf")
if [[ -n "$FILES_WITH_SECRETS" ]]; then
  echo "$FILES_WITH_SECRETS" | while read -r file; do
    if [[ -f "$file" && $(stat -c %a "$file") != "600" ]]; then
      echo "⚠️  Warning: $file has incorrect permissions (should be 600)"
    fi
  done
fi

echo "✓ Pre-commit checks passed"
exit 0
```

---

## Naming Conventions

### Shell Naming Standards

**Functions**:
```bash
# Module-specific functions (snake_case with module prefix)
system_prep_execute()
desktop_env_install()
rdp_server_configure()
ide_vscode_verify()

# Core library functions (snake_case with domain prefix)
checkpoint_create()
logger_info()
validator_check_ram()
transaction_record()

# Private functions (underscore prefix)
_internal_helper()
_parse_config_line()
```

**Variables**:
```bash
# Local variables (lowercase with underscores)
local file_path="/path/to/file"
local user_name="devuser"
local retry_count=0

# Constants/environment variables (UPPERCASE with underscores)
readonly CHECKPOINT_DIR="/var/vps-provision/checkpoints"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"
readonly MIN_RAM_GB=2
```

**Files**:
```bash
# Shell scripts (kebab-case.sh)
system-prep.sh
desktop-env.sh
ide-vscode.sh

# Executables (no extension, kebab-case)
vps-provision
preflight-check
session-manager

# Configuration (kebab-case.conf)
default.conf
custom-settings.conf
```

### Python Naming Standards (PEP 8)

**Classes**:
```python
# PascalCase
class HealthCheck:
class ConfigValidator:
class SessionManager:
```

**Functions/Methods**:
```python
# snake_case
def run_command():
def check_system():
def format_results():
```

**Constants**:
```python
# UPPERCASE_WITH_UNDERSCORES
MAX_RETRIES = 3
DEFAULT_TIMEOUT = 30
LOG_FORMAT = "%(asctime)s - %(message)s"
```

**Files**:
```python
# kebab-case.py
health-check.py
credential-gen.py
session-monitor.py
```

---

## Implementation Templates

### Template 1: New Provisioning Module

**File**: `lib/modules/template-module.sh`

```bash
#!/bin/bash
# Module: [module-name]
# Purpose: [Brief description]
# Dependencies: [List required core modules]

set -euo pipefail

# Prevent multiple sourcing
if [[ -n "${_TEMPLATE_MODULE_LOADED:-}" ]]; then
  return 0
fi
readonly _TEMPLATE_MODULE_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${SCRIPT_DIR}")"
source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"
source "${LIB_DIR}/core/transaction.sh"
source "${LIB_DIR}/core/progress.sh"

# Module constants
readonly MODULE_CHECKPOINT="template-module"

# Module functions
template_module_check_prerequisites() {
  log_debug "Checking prerequisites for template module"
  
  # Add prerequisite checks here
  
  return 0
}

template_module_install() {
  log_info "Installing template module components"
  
  # Add installation logic here
  # Example:
  # apt-get install -y package-name
  # transaction_record "Installed package-name" "apt-get remove -y package-name"
  
  return 0
}

template_module_configure() {
  log_info "Configuring template module"
  
  # Add configuration logic here
  # Example:
  # cp /etc/config /etc/config.bak
  # sed -i 's/old/new/g' /etc/config
  # transaction_record "Modified /etc/config" "cp /etc/config.bak /etc/config"
  
  return 0
}

template_module_verify() {
  log_info "Verifying template module installation"
  
  # Add verification logic here
  # Example:
  # command -v installed_binary &>/dev/null
  
  return 0
}

# Main entry point
template_module_execute() {
  log_info "Starting template module execution"
  
  if checkpoint_exists "${MODULE_CHECKPOINT}"; then
    log_info "Template module already completed (checkpoint found)"
    return 0
  fi
  
  checkpoint_start "${MODULE_CHECKPOINT}"
  
  template_module_check_prerequisites || return 1
  template_module_install || return 1
  template_module_configure || return 1
  template_module_verify || return 1
  
  checkpoint_create "${MODULE_CHECKPOINT}"
  
  log_info "Template module execution completed successfully"
}
```

### Template 2: Python Utility Script

**File**: `lib/utils/template-util.py`

```python
#!/usr/bin/env python3
"""
Module: [utility-name]
Purpose: [Brief description]

Usage:
    python3 template-util.py [OPTIONS]

Options:
    --option VALUE    Description of option
    --verbose         Enable verbose output
"""

import argparse
import sys
from typing import Any, Dict, List, Optional

class TemplateUtility:
    """[Brief class description]"""
    
    def __init__(self, verbose: bool = False):
        """Initialize utility"""
        self.verbose = verbose
    
    def run(self) -> bool:
        """Main execution method"""
        try:
            # Implementation here
            return True
        except Exception as e:
            print(f"Error: {str(e)}", file=sys.stderr)
            return False

def main() -> int:
    """CLI entry point"""
    parser = argparse.ArgumentParser(
        description="[Utility description]"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    
    args = parser.parse_args()
    
    utility = TemplateUtility(verbose=args.verbose)
    success = utility.run()
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
```

### Template 3: BATS Unit Test

**File**: `tests/unit/test_template.bats`

```bash
#!/usr/bin/env bats
# Unit tests for template module

load '../test_helper'

setup() {
  # Source the module under test
  source "${LIB_DIR}/modules/template-module.sh"
  
  # Set up test environment
  export TEST_MODE=1
  export LOG_LEVEL=DEBUG
}

teardown() {
  # Clean up after each test
  rm -f /tmp/test-*
}

@test "template_module: check_prerequisites succeeds" {
  run template_module_check_prerequisites
  [ "$status" -eq 0 ]
}

@test "template_module: execute completes successfully" {
  run template_module_execute
  [ "$status" -eq 0 ]
  [[ "$output" =~ "completed successfully" ]]
}

@test "template_module: is idempotent" {
  # First execution
  run template_module_execute
  [ "$status" -eq 0 ]
  
  # Second execution should detect checkpoint
  run template_module_execute
  [ "$status" -eq 0 ]
  [[ "$output" =~ "already completed" ]]
}

@test "template_module: handles errors gracefully" {
  # Simulate error condition
  export FORCE_ERROR=1
  
  run template_module_execute
  [ "$status" -ne 0 ]
  [[ "$output" =~ "error" ]]
}
```

---

## Technology-Specific Patterns

### Bash Implementation Patterns

#### Pattern 1: Safe Command Execution

```bash
# Pattern: Execute with retry logic
execute_with_retry() {
  local command="$1"
  local max_attempts="${2:-3}"
  local delay="${3:-2}"
  local attempt=1
  
  while (( attempt <= max_attempts )); do
    if eval "${command}"; then
      log_info "Command succeeded on attempt ${attempt}"
      return 0
    fi
    
    log_warning "Attempt ${attempt}/${max_attempts} failed"
    
    if (( attempt < max_attempts )); then
      sleep "${delay}"
      delay=$((delay * 2))  # Exponential backoff
    fi
    
    ((attempt++))
  done
  
  log_error "Command failed after ${max_attempts} attempts"
  return 1
}

# Usage
execute_with_retry "apt-get update" 3 2
```

#### Pattern 2: Parallel Execution

```bash
# Pattern: Run tasks in parallel
parallel_execute() {
  local -a tasks=("$@")
  local -a pids=()
  
  # Start all tasks in background
  for task in "${tasks[@]}"; do
    ${task} &
    pids+=($!)
  done
  
  # Wait for all to complete
  local failed=0
  for pid in "${pids[@]}"; do
    if ! wait "${pid}"; then
      ((failed++))
    fi
  done
  
  return "${failed}"
}

# Usage
parallel_execute   "ide_vscode_install"   "ide_cursor_install"   "ide_antigravity_install"
```

#### Pattern 3: Configuration Management

```bash
# Pattern: Hierarchical configuration loading
config_load_hierarchy() {
  local default_config="${PROJECT_ROOT}/config/default.conf"
  local system_config="/etc/vps-provision/default.conf"
  local user_config="${HOME}/.vps-provision.conf"
  
  # Load in order of precedence (later overrides earlier)
  [[ -f "${default_config}" ]] && source "${default_config}"
  [[ -f "${system_config}" ]] && source "${system_config}"
  [[ -f "${user_config}" ]] && source "${user_config}"
  
  # CLI arguments override all (handled separately)
}
```

### Python Implementation Patterns

#### Pattern 1: Command Execution with Error Handling

```python
import subprocess
from typing import Tuple

def run_command(cmd: List[str], check: bool = False) -> Tuple[bool, str, str]:
    """Execute command and return (success, stdout, stderr)"""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=check,
            timeout=30
        )
        return (result.returncode == 0, result.stdout, result.stderr)
    except subprocess.TimeoutExpired:
        return (False, "", "Command timed out")
    except subprocess.CalledProcessError as e:
        return (False, e.stdout, e.stderr)
    except Exception as e:
        return (False, "", str(e))
```

#### Pattern 2: Structured Output

```python
import json
from typing import Any, Dict

def format_output(data: Dict[str, Any], format_type: str = "text") -> str:
    """Format data as text or JSON"""
    if format_type == "json":
        return json.dumps(data, indent=2)
    else:
        lines = []
        for key, value in data.items():
            lines.append(f"{key}: {value}")
        return "\n".join(lines)
```

---

## Implementation Guidelines

### Step-by-Step Process for New Features

1. **Start with Specification**:
   - Create `specs/NNN-feature-name/spec.md`
   - Define user stories, requirements, and acceptance criteria
   - Run `/speckit.plan` to generate plan and research
   - Run `/speckit.tasks` to generate task breakdown

2. **Implement Core Logic**:
   - Create module in `lib/modules/feature-name.sh`
   - Follow module template structure
   - Implement `feature_execute()` as main entry point
   - Add checkpoints for idempotency
   - Record transactions for rollback

3. **Add Testing**:
   - Create unit tests in `tests/unit/test_feature.bats`
   - Create integration tests in `tests/integration/test_feature.bats`
   - Run `make test-unit` and `make test-integration`
   - Ensure ≥80% coverage for critical paths

4. **Integrate with Main Flow**:
   - Add module import to `bin/vps-provision`
   - Register phase in provisioning sequence
   - Add to dry-run plan display
   - Update progress weights

5. **Document Changes**:
   - Update `README.md` if user-facing changes
   - Add inline comments for complex logic
   - Update `CHANGELOG.md` with changes
   - Create migration guide if breaking changes

### Common Pitfalls to Avoid

1. **Missing Checkpoint Creation**:
   - ❌ Forgetting `checkpoint_create()` causes re-execution
   - ✅ Always create checkpoint after successful completion

2. **Incomplete Transaction Recording**:
   - ❌ Not recording rollback commands leaves broken state
   - ✅ Record every state-changing operation

3. **Insufficient Error Handling**:
   - ❌ Silent failures make debugging impossible
   - ✅ Use `set -euo pipefail` and check all command results

4. **Breaking Idempotency**:
   - ❌ Commands that fail on re-run break idempotency
   - ✅ Check if already completed before executing

5. **Hardcoded Paths/Values**:
   - ❌ Hardcoding makes code inflexible
   - ✅ Use configuration variables and constants

### Extension Mechanisms

#### Plugin Architecture (Future Enhancement)

```bash
# Pattern: Pluggable module discovery
discover_modules() {
  local module_dir="${LIB_DIR}/modules"
  local -a modules=()
  
  for file in "${module_dir}"/*.sh; do
    if [[ -f "$file" ]]; then
      local module_name=$(basename "$file" .sh)
      modules+=("${module_name}")
    fi
  done
  
  echo "${modules[@]}"
}

# Execute all discovered modules
for module in $(discover_modules); do
  source "${LIB_DIR}/modules/${module}.sh"
  ${module}_execute
done
```

#### Configuration-Driven Features

```bash
# Pattern: Enable/disable features via configuration
if [[ "${INSTALL_VSCODE:-true}" == "true" ]]; then
  ide_vscode_execute
fi

if [[ "${ENABLE_FIREWALL:-true}" == "true" ]]; then
  firewall_execute
fi

if [[ "${PARALLEL_IDE_INSTALL:-false}" == "true" ]]; then
  parallel_ide_install_execute
else
  ide_vscode_execute
  ide_cursor_execute
  ide_antigravity_execute
fi
```

---

## Sequence Diagrams

### Main Provisioning Sequence

```
User                   vps-provision              Core Libraries            Modules
  |                           |                           |                    |
  |--./vps-provision--------->|                           |                    |
  |                           |--parse_arguments()------->|                    |
  |                           |<--------------------------|                    |
  |                           |--validator_check_all()--->|                    |
  |                           |<--------------------------|                    |
  |                           |--config_load_default()--->|                    |
  |                           |<--------------------------|                    |
  |                           |--checkpoint_init()------->|                    |
  |                           |<--------------------------|                    |
  |                           |--state_init_session()---->|                    |
  |                           |<--------------------------|                    |
  |                           |                           |                    |
  |                           |--system_prep_execute()---------------->|       |
  |                           |                           |            |       |
  |                           |                           |<--checkpoint_exists|
  |                           |                           |----------->|       |
  |                           |                           |<-----------|       |
  |                           |                           |            |--install()
  |                           |                           |<--transaction_record()
  |                           |                           |<--checkpoint_create()
  |                           |<----------------------------------------|       |
  |                           |                           |                    |
  |                           |--desktop_env_execute()----------------->|      |
  |                           |<----------------------------------------|      |
  |                           |                           |                    |
  |                           |--verification_execute()---------------->|      |
  |                           |                           |<--health-check.py  |
  |                           |<----------------------------------------|      |
  |                           |                           |                    |
  |                           |--state_update_status("COMPLETED")----->|       |
  |<--exit 0------------------|                           |                    |
```

### Error & Rollback Sequence

```
Module                 Error Handler            Rollback System        File System
  |                           |                           |                    |
  |--command fails (exit≠0)-->|                           |                    |
  |                           |--error_handler()          |                    |
  |                           |                           |                    |
  |                           |--log_error()              |                    |
  |                           |--log_stack_trace()        |                    |
  |                           |                           |                    |
  |                           |--rollback_execute()------>|                    |
  |                           |                           |--read(transactions.log)
  |                           |                           |<-------------------|
  |                           |                           |--execute_rollback_cmds()
  |                           |                           |--checkpoint_clear_all()
  |                           |                           |-------------------->|
  |                           |<--------------------------|                    |
  |                           |                           |                    |
  |                           |--state_update_status("FAILED")                 |
  |                           |--exit(error_code)         |                    |
```

---

## Conclusion

This blueprint provides **5 comprehensive workflows** that serve as implementation templates for the VPS Developer Workstation Provisioning system. Each workflow demonstrates:

- **Clear entry points** with complete function signatures
- **Step-by-step execution flow** with error handling
- **Data access patterns** via file-based persistence
- **Service layer integration** through modular design
- **Testing approaches** with BATS and pytest
- **Naming conventions** across Bash and Python
- **Reusable templates** for rapid feature development

### Key Takeaways for Developers

1. **Follow the Module Template**: All provisioning phases use the same structure
2. **Always Use Checkpoints**: Enables idempotency and resume capability
3. **Record All Transactions**: Critical for rollback on failure
4. **Test at Multiple Levels**: Unit → Integration → Contract → E2E
5. **Document Your Changes**: Update specs, code comments, and README

### For AI Code Generation

This blueprint provides **implementation-ready patterns** for:
- Creating new provisioning modules
- Adding validation checks
- Implementing rollback logic
- Writing comprehensive tests
- Following project conventions

Use the templates and examples as starting points for generating code that follows established patterns and maintains consistency with the existing codebase.

---

**Blueprint Generated:** 2025-12-25  
**Total Workflows Documented:** 5  
**Total Code Examples:** 25+  
**Target Audience:** Developers & GitHub Copilot AI
