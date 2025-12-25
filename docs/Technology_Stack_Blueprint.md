# Technology Stack Blueprint - VPS Developer Workstation Provisioning

**Generated:** 2025-12-25  
**Project Version:** 1.0.0  
**Analysis Depth:** Implementation-Ready  
**Codebase Size:** ~15,000 lines of code

---

## Executive Summary

This is a **Bash-first, Python-supplemented** automation system that provisions Debian 13 VPS instances into fully-functional developer workstations. The architecture follows a modular, transaction-safe design with comprehensive testing, rollback capabilities, and real-time monitoring.

### Core Architecture Pattern
- **Primary Language:** Bash 5.1+ (shell scripting)
- **Utility Language:** Python 3.11+ (health checks, validation, utilities)
- **Testing Framework:** BATS (Bash Automated Testing System) 1.10.0+
- **Target Platform:** Debian 13 (Bookworm)
- **Deployment Model:** Single-command automation with idempotent execution

---

## 1. Technology Identification

### Primary Technology Stack

| Component | Technology | Version | License | Purpose |
|-----------|-----------|---------|---------|---------|
| **Operating System** | Debian Linux | 13 (Bookworm) | Free | Target OS for provisioning |
| **Shell** | GNU Bash | 5.1+ | GPL-3.0 | Primary scripting language |
| **Python Runtime** | Python | 3.11+ | PSF | Utility scripts and validation |
| **Desktop Environment** | XFCE | 4.18 | GPL-2.0 | Lightweight desktop |
| **RDP Server** | xrdp | Latest | Apache-2.0 | Remote desktop protocol |
| **Testing Framework** | BATS | 1.10.0+ | MIT | Bash testing |
| **Build System** | GNU Make | Latest | GPL-3.0 | Task automation |

### Development Stack Installed on Target VPS

| Tool | Version | Purpose |
|------|---------|---------|
| **VSCode** | Latest stable | Primary IDE |
| **Cursor** | Latest | AI-enhanced IDE |
| **Antigravity** | Latest | Alternative IDE |
| **Git** | Latest | Version control |
| **build-essential** | Latest | C/C++ compilation tools |
| **oh-my-bash** | Latest | Enhanced terminal |

---

## 2. Core Technologies Analysis

### Bash Stack (Primary)

#### Project Structure
```
bin/                          # CLI entry points
├── vps-provision            # Main entry point (CLI interface)
├── preflight-check          # Pre-execution validation
├── session-manager.sh       # Session state management
└── release.sh               # Release automation

lib/                          # Core libraries (modular architecture)
├── core/                    # Foundation libraries (14 modules)
│   ├── logger.sh           # Structured logging system
│   ├── checkpoint.sh       # Idempotency & resume capability
│   ├── transaction.sh      # Rollback transaction tracking
│   ├── rollback.sh         # Automatic rollback on failure
│   ├── progress.sh         # Real-time progress tracking
│   ├── state.sh            # State persistence
│   ├── error-handler.sh    # Error handling & recovery
│   ├── validator.sh        # Input & system validation
│   ├── config.sh           # Configuration management
│   ├── sanitize.sh         # Input sanitization (security)
│   ├── file-ops.sh         # Safe file operations
│   ├── services.sh         # Systemd service management
│   ├── ux.sh               # User experience utilities
│   └── lock.sh             # Concurrent access prevention
│
├── modules/                 # Feature implementation (16 modules)
│   ├── system-prep.sh      # Package updates & core dependencies
│   ├── desktop-env.sh      # XFCE installation & configuration
│   ├── rdp-server.sh       # xrdp setup & TLS encryption
│   ├── user-provisioning.sh # Developer user creation
│   ├── ide-vscode.sh       # VSCode installation
│   ├── ide-cursor.sh       # Cursor installation
│   ├── ide-antigravity.sh  # Antigravity installation
│   ├── parallel-ide-install.sh # Parallel IDE orchestration
│   ├── dev-tools.sh        # Git, build tools, etc.
│   ├── terminal-setup.sh   # oh-my-bash configuration
│   ├── firewall.sh         # UFW firewall rules
│   ├── fail2ban.sh         # Intrusion prevention
│   ├── audit-logging.sh    # System audit trail
│   ├── verification.sh     # Post-install validation
│   ├── summary-report.sh   # Completion summary
│   └── status-banner.sh    # System status display
│
└── utils/                   # Utility scripts
    ├── benchmark.sh        # Performance benchmarking
    ├── performance-monitor.sh # Resource monitoring
    └── state-compare.sh    # State comparison

config/                      # Configuration files
├── default.conf            # Default settings (225 config options)
└── desktop/                # Desktop customizations
    ├── terminalrc          # Terminal emulator config
    ├── xfce4-panel.xml     # XFCE panel layout
    └── xsettings.xml       # Desktop theme settings

tests/                       # Comprehensive test suite
├── unit/                   # Unit tests (178 tests)
├── integration/            # Integration tests
├── contract/               # API contract tests
└── e2e/                    # End-to-end tests
```

#### Bash Language Features & Patterns

**Shell Options Used:**
```bash
set -euo pipefail
# -e: Exit on error
# -u: Exit on undefined variable
# -o pipefail: Exit on pipeline failure
```

**Module Loading Pattern (Idempotent Sourcing):**
```bash
# Prevent double-sourcing
if [[ -n "${_MODULE_NAME_LOADED:-}" ]]; then
  return 0
fi
readonly _MODULE_NAME_LOADED=1
```

**Error Handling:**
```bash
trap 'error_handler $? "$BASH_COMMAND" "${BASH_SOURCE[0]}" "${LINENO}"' ERR
```

**Function Naming Convention:**
- Format: `module_action` (e.g., `checkpoint_exists`, `logger_info`)
- 247+ functions across core libraries
- Consistent verb-noun or noun-verb patterns

**Variables:**
- Global constants: `readonly UPPERCASE_WITH_UNDERSCORES`
- Local variables: `lowercase_with_underscores`
- Function parameters: Positional (`$1`, `$2`) with validation

**Arrays:**
```bash
# Array usage for phase management
SKIP_PHASES=()
ONLY_PHASES=()
```

#### Key Bash Patterns

**1. Transaction-Safe Operations:**
```bash
# Record action with rollback command
transaction_record "Installed package nginx" "apt-get remove -y nginx"
```

**2. Checkpoint-Based Idempotency:**
```bash
if checkpoint_exists "system-prep"; then
  log_info "System prep already completed"
  return 0
fi

# Perform work...

checkpoint_create "system-prep"
```

**3. Progress Tracking:**
```bash
progress_register_phase "system-prep" 15    # 15% weight
progress_start_phase "system-prep"
# ... work ...
progress_complete_phase "system-prep"
```

**4. Structured Logging:**
```bash
log_debug "Internal state: variable=$value"
log_info "Installing package: nginx"
log_warning "Retrying failed operation"
log_error "Critical operation failed"
```

**5. Input Sanitization (Security):**
```bash
username=$(sanitize_username "$raw_input")
filepath=$(sanitize_filepath "$user_path")
```

**6. Service Management:**
```bash
service_enable "xrdp"
service_status "xrdp"
service_restart "ssh"
```

---

### Python Stack (Supplementary)

#### Python Utilities (4 modules)

**1. Health Check System (`lib/utils/health-check.py`)**
```python
#!/usr/bin/env python3
"""
Post-installation validation of all components
Features:
  - System validation (OS, resources)
  - Service status checks (xrdp, lightdm)
  - IDE verification (VSCode, Cursor, Antigravity)
  - Output formats: text, JSON
"""

class HealthCheck:
    def run_command(self, cmd: List[str]) -> Tuple[bool, str, str]
    def check_system(self) -> Dict[str, Any]
    def check_service(self, service_name: str) -> Dict[str, Any]
    def check_desktop(self) -> Dict[str, Any]
    def check_rdp(self) -> Dict[str, Any]
    def check_ides(self) -> Dict[str, Any]
    def check_dev_tools(self) -> Dict[str, Any]
    def run_all_checks(self) -> List[Dict[str, Any]]
```

**2. Credential Generator (`lib/utils/credential-gen.py`)**
```python
"""
Cryptographically secure password generation
Uses secrets module (NOT random - security critical)
"""
import secrets
import string

def generate_password(length: int = 32) -> str:
    alphabet = string.ascii_letters + string.digits + string.punctuation
    return ''.join(secrets.choice(alphabet) for _ in range(length))
```

**3. Session Monitor (`lib/utils/session-monitor.py`)**
```python
"""
RDP session monitoring and management
Features:
  - Active session tracking
  - Resource usage per session
  - Session cleanup automation
"""
```

**4. Package Manager (`lib/utils/package-manager.py`)**
```python
"""
APT package management wrapper with retry logic
Features:
  - Parallel downloads (3 concurrent)
  - Automatic retry on network failures
  - Lock file handling
"""
```

#### Python Dependencies

```python
# requirements.txt
psutil>=5.9.0        # System monitoring (lock detection, resource tracking)
pytest>=7.4.0        # Testing framework
pytest-cov>=4.1.0    # Coverage reporting
pylint>=2.17.0       # Code linting
black>=23.0.0        # Code formatting (PEP 8)
mypy>=1.0.0          # Static type checking
flake8>=6.0.0        # Style guide enforcement
codespell>=2.2.0     # Spell checking
```

#### Python Patterns

**Type Hints (Comprehensive):**
```python
def run_command(self, cmd: List[str], check: bool = False) -> Tuple[bool, str, str]:
```

**Error Handling:**
```python
try:
    result = subprocess.run(cmd, capture_output=True, text=True, check=check)
    return (result.returncode == 0, result.stdout, result.stderr)
except subprocess.CalledProcessError as e:
    return (False, e.stdout, e.stderr)
```

**JSON Output Support:**
```python
def format_results(self, output_format: str) -> str:
    if output_format == "json":
        return json.dumps(self.results, indent=2)
    else:
        return self._format_text()
```

---

## 3. Implementation Patterns & Conventions

### Naming Conventions

#### File Naming
- **Shell scripts:** `kebab-case.sh` (e.g., `system-prep.sh`, `ide-vscode.sh`)
- **Python scripts:** `kebab-case.py` (e.g., `health-check.py`, `credential-gen.py`)
- **Executables:** No extension (e.g., `vps-provision`, `preflight-check`)
- **Config files:** `.conf` extension (e.g., `default.conf`)

#### Shell Naming
- **Functions:** `module_action` format
  - Core functions: `logger_info`, `checkpoint_create`, `transaction_record`
  - Module functions: `system_prep_execute`, `desktop_env_install`
- **Constants:** `UPPERCASE_WITH_UNDERSCORES`
- **Variables:** `lowercase_with_underscores`
- **Private functions:** Prefix with `_` (e.g., `_internal_helper`)

#### Python Naming (PEP 8)
- **Classes:** `PascalCase` (e.g., `HealthCheck`)
- **Functions:** `snake_case` (e.g., `run_command`, `check_system`)
- **Constants:** `UPPERCASE_WITH_UNDERSCORES`
- **Private methods:** Prefix with `_` (e.g., `_format_text`)

### Code Organization

#### Shell Module Structure
```bash
#!/bin/bash
# Module: <name>
# Purpose: <description>
# Dependencies: <list>

set -euo pipefail

# Prevent multiple sourcing
if [[ -n "${_MODULE_LOADED:-}" ]]; then
  return 0
fi
readonly _MODULE_LOADED=1

# Source dependencies
source "${LIB_DIR}/core/required-module.sh"

# Module constants
readonly MODULE_CONSTANT="value"

# Module variables
module_state=""

# Public API functions
module_public_function() {
  # Implementation
}

# Private helper functions
_module_internal_helper() {
  # Implementation
}

# Main execution function
module_execute() {
  # Entry point
}
```

#### Python Module Structure
```python
#!/usr/bin/env python3
"""
Module: <name>
Purpose: <description>

Usage:
    python3 module.py [options]

Options:
    --option VALUE    Description
"""

import argparse
from typing import Any, Dict, List

class ModuleName:
    """Main class for module functionality"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
    
    def public_method(self) -> Any:
        """Public API method with docstring"""
        pass
    
    def _private_helper(self) -> Any:
        """Internal helper method"""
        pass

def main():
    """CLI entry point"""
    parser = argparse.ArgumentParser(description="Module description")
    # Argument parsing
    args = parser.parse_args()
    # Execution

if __name__ == "__main__":
    main()
```

### Common Patterns

#### Error Handling (Shell)
```bash
# Global error handler
trap 'error_handler $? "$BASH_COMMAND" "${BASH_SOURCE[0]}" "${LINENO}"' ERR

# Validation before execution
if ! validator_check_root; then
  log_error "Must run as root"
  exit 1
fi

# Safe command execution with retry
retry_count=0
max_retries=3
while (( retry_count < max_retries )); do
  if command_with_potential_failure; then
    break
  fi
  ((retry_count++))
  sleep 2
done
```

#### Configuration Access
```bash
# Load configuration
config_load "/etc/vps-provision/default.conf"

# Access values
log_level=$(config_get "LOG_LEVEL" "INFO")
ide_list=$(config_get "IDES_TO_INSTALL" "vscode")
```

#### Authentication/Authorization
```bash
# Root check (required for system modifications)
if [[ $EUID -ne 0 ]]; then
  log_error "This script must be run as root"
  exit 1
fi

# User creation with secure password
password=$(python3 "${LIB_DIR}/utils/credential-gen.py" --length 32)
useradd -m -s /bin/bash -G "${USER_GROUPS}" "${username}"
echo "${username}:${password}" | chpasswd
```

#### Validation Strategies
```bash
# Pre-execution validation
validator_check_prerequisites() {
  validator_check_os "debian" "13"
  validator_check_ram "${MIN_RAM_GB}"
  validator_check_disk "${MIN_DISK_GB}"
  validator_check_network
}

# Input sanitization
username=$(sanitize_username "$user_input")  # Removes special chars
filepath=$(sanitize_filepath "$path_input")  # Prevents path traversal
```

---

## 4. Usage Examples

### API Implementation Examples

#### Module Entry Point Pattern
```bash
#!/bin/bash
# Standard module execution pattern

module_execute() {
  log_info "Starting module execution"
  
  # Check if already completed
  if checkpoint_exists "module-name"; then
    log_info "Module already completed (checkpoint found)"
    return 0
  fi
  
  # Progress tracking
  progress_start_phase "module-name"
  
  # Prerequisite validation
  module_check_prerequisites || return 1
  
  # Main work
  module_do_work || {
    log_error "Module execution failed"
    return 1
  }
  
  # Create checkpoint
  checkpoint_create "module-name"
  
  # Complete progress
  progress_complete_phase "module-name"
  
  log_info "Module execution completed"
}
```

#### Service Installation Pattern
```bash
# Package installation with transaction tracking
install_package() {
  local package_name=$1
  
  log_info "Installing ${package_name}"
  
  if apt-get install -y "${package_name}"; then
    transaction_record \
      "Installed package ${package_name}" \
      "apt-get remove -y ${package_name}"
    return 0
  else
    log_error "Failed to install ${package_name}"
    return 1
  fi
}
```

#### Configuration File Modification Pattern
```bash
# Safe configuration modification with backup
modify_config() {
  local config_file=$1
  local search_pattern=$2
  local replacement=$3
  
  # Create backup
  cp "${config_file}" "${config_file}.bak"
  transaction_record \
    "Modified ${config_file}" \
    "cp ${config_file}.bak ${config_file}"
  
  # Perform modification
  sed -i "s/${search_pattern}/${replacement}/g" "${config_file}"
}
```

### Data Access Examples

#### State Persistence
```bash
# Save state
state_save "provisioning_progress" "phase_3_complete"
state_save "installed_ides" "vscode cursor"

# Retrieve state
progress=$(state_get "provisioning_progress")
ides=$(state_get "installed_ides")

# Check state existence
if state_exists "desktop_installed"; then
  log_info "Desktop already installed"
fi
```

#### Checkpoint Management
```bash
# Create checkpoint
checkpoint_create "system-prep"
checkpoint_create "desktop-env"
checkpoint_create "ide-vscode"

# Check checkpoint
if checkpoint_exists "system-prep"; then
  echo "System prep completed"
fi

# List all checkpoints
checkpoint_list

# Clear checkpoints (force mode)
checkpoint_clear_all
```

### Service Layer Examples

#### Service Orchestration
```bash
# Multi-service startup
start_desktop_services() {
  log_info "Starting desktop services"
  
  service_enable "lightdm"
  service_start "lightdm"
  
  service_enable "xrdp"
  service_start "xrdp"
  
  # Wait for services to be ready
  sleep 5
  
  # Verify services are running
  if service_is_active "lightdm" && service_is_active "xrdp"; then
    log_info "Desktop services started successfully"
    return 0
  else
    log_error "Failed to start desktop services"
    return 1
  fi
}
```

#### Rollback Integration
```bash
# Automatic rollback on failure
provision_with_rollback() {
  # Enable automatic error handling
  trap 'rollback_execute' ERR
  
  # Execute provisioning
  system_prep_execute || return 1
  desktop_env_execute || return 1
  rdp_server_execute || return 1
  
  # Disable rollback on success
  trap - ERR
}
```

### CLI Examples

#### Main CLI Interface
```bash
# CLI argument parsing (bin/vps-provision)
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --resume)
      RESUME_MODE=true
      shift
      ;;
    --force)
      FORCE_MODE=true
      checkpoint_clear_all
      shift
      ;;
    --config)
      CUSTOM_CONFIG="$2"
      shift 2
      ;;
    --username)
      CUSTOM_USERNAME="$2"
      shift 2
      ;;
    --skip-phase)
      SKIP_PHASES+=("$2")
      shift 2
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done
```

---

## 5. Technology Stack Map

### Core Framework Usage

#### Bash Framework
- **Error Handling:** Global trap handler with automatic rollback
- **Module System:** Source-based with idempotent loading guards
- **Logging Framework:** Structured logging with levels (DEBUG, INFO, WARNING, ERROR)
- **Configuration:** Hierarchical config loading (defaults → system → user)
- **State Management:** File-based checkpoints and session state
- **Progress Tracking:** Weighted phase progress with ETA calculation

#### Python Framework
- **Standard Library:** subprocess, json, socket, argparse
- **Type System:** Type hints with mypy validation
- **Testing:** pytest with coverage reporting
- **Code Quality:** black (formatting), pylint (linting), flake8 (style)

### Integration Points

#### Shell ↔ Python Integration
```bash
# Python script execution from shell
password=$(python3 "${LIB_DIR}/utils/credential-gen.py" --length 32)
health_status=$(python3 "${LIB_DIR}/utils/health-check.py" --output json)
```

#### System Service Integration
```bash
# Systemd service management
systemctl enable xrdp
systemctl start xrdp
systemctl status xrdp

# Service verification
if systemctl is-active --quiet xrdp; then
  log_info "xrdp is running"
fi
```

#### Package Management Integration
```bash
# APT with transaction tracking
apt-get update
apt-get install -y package-name
transaction_record "Installed package-name" "apt-get remove -y package-name"
```

#### Desktop Environment Integration
```bash
# XFCE configuration
xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 32
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-path \
  -s "/usr/share/backgrounds/default.jpg"
```

### Development Tooling

#### Build System (Makefile)
```makefile
# Task automation
.PHONY: test test-unit test-integration lint format clean

test: test-quick test-slow
test-quick: lint format-check typecheck spell-check
test-slow: test-unit test-integration test-contract

install:           # Install dependencies
test:              # Run all tests
test-unit:         # 178 BATS unit tests
test-integration:  # Integration tests
test-contract:     # API contract tests
test-python:       # pytest with coverage
lint:              # shellcheck, pylint, flake8
format:            # shfmt, black
clean:             # Remove temporary files
```

#### Code Analysis
- **Shell:** shellcheck (static analysis), shfmt (formatting)
- **Python:** pylint (linting), flake8 (style), mypy (type checking)
- **Spell Check:** codespell (code and documentation)
- **Secret Scanning:** Regex pattern matching for hardcoded credentials

#### Testing Framework (BATS)
```bash
# tests/unit/test_logger.bats
@test "log_info outputs correctly" {
  run log_info "Test message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test message" ]]
}

@test "log_error sets exit code" {
  run log_error "Error message"
  [ "$status" -ne 0 ]
}
```

#### Git Hooks
```bash
# .git/hooks/pre-commit
#!/bin/bash
make lint-shell
make lint-python
make spell-check
make check-secrets

# .git/hooks/pre-push
#!/bin/bash
make test-unit
make test-contract
```

### Infrastructure

#### Deployment Target
- **Platform:** Digital Ocean VPS (or any Debian 13 server)
- **Minimum Requirements:**
  - 2GB RAM
  - 25GB Disk
  - 1 vCPU
  - Network connectivity

#### Directory Structure (Post-Installation)
```
/opt/vps-provision/          # Installation base
/var/log/vps-provision/      # Logs
  ├── provision.log          # Main log
  └── transactions.log       # Rollback log
/var/vps-provision/          # State directory
  ├── checkpoints/           # Idempotency markers
  ├── sessions/              # Active sessions
  └── backups/               # Configuration backups
/tmp/vps-provision/          # Temporary files
/etc/vps-provision/          # System configuration
  └── default.conf           # Configuration overrides
```

#### Monitoring & Logging
- **Log Aggregation:** File-based logging to `/var/log/vps-provision/`
- **Log Format:** Timestamped with level indicators
- **Log Rotation:** System logrotate integration
- **Resource Monitoring:** Real-time CPU, memory, disk tracking (10s interval)
- **Performance Benchmarking:** CPU, disk I/O, network speed tests

---

## 6. Technology-Specific Implementation Details

### Bash Implementation Patterns

#### Dependency Injection Pattern
```bash
# Module dependencies sourced at top
source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"
source "${LIB_DIR}/core/transaction.sh"

# Functions receive dependencies via parameters or globals
process_installation() {
  local package_name=$1
  local log_level=${LOG_LEVEL:-INFO}
  
  log_info "Processing ${package_name}"
  checkpoint_create "${package_name}"
}
```

#### Command Patterns
```bash
# Safe command execution with error handling
execute_safely() {
  local command=$1
  
  if eval "${command}"; then
    log_info "Command succeeded: ${command}"
    return 0
  else
    log_error "Command failed: ${command}"
    return 1
  fi
}

# Retry pattern
retry_with_backoff() {
  local max_attempts=3
  local attempt=1
  local delay=2
  
  while (( attempt <= max_attempts )); do
    if "$@"; then
      return 0
    fi
    log_warning "Attempt ${attempt}/${max_attempts} failed, retrying..."
    sleep "${delay}"
    delay=$((delay * 2))
    ((attempt++))
  done
  
  return 1
}
```

#### Parallel Execution
```bash
# Parallel IDE installation
install_ides_parallel() {
  local pids=()
  
  # Start installations in background
  ide_vscode_install &
  pids+=($!)
  
  ide_cursor_install &
  pids+=($!)
  
  ide_antigravity_install &
  pids+=($!)
  
  # Wait for all to complete
  local failed=0
  for pid in "${pids[@]}"; do
    if ! wait "${pid}"; then
      ((failed++))
    fi
  done
  
  return "${failed}"
}
```

#### Language Features Used
- **Parameter Expansion:** `${var:-default}`, `${var#prefix}`, `${var%.suffix}`
- **Arrays:** `declare -a array=()`, `${array[@]}`
- **Associative Arrays:** `declare -A map=()`, `${map[key]}`
- **Command Substitution:** `$(command)`, `` `command` ``
- **Process Substitution:** `<(command)`, `>(command)`
- **Arithmetic:** `$((expression))`, `((expression))`
- **Conditionals:** `[[ condition ]]` (preferred over `[ condition ]`)
- **Case Statements:** Multi-way branching for CLI parsing
- **Functions:** Named functions with local variables
- **Traps:** Signal and error handling
- **Here Documents:** Multi-line strings

### Python Implementation Patterns

#### Class Structure
```python
class HealthCheck:
    """Post-installation validation checks"""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.results: List[Dict[str, Any]] = []
    
    def run_command(self, cmd: List[str]) -> Tuple[bool, str, str]:
        """Execute command and return results"""
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
        
        return check
```

#### Type Hints (Comprehensive)
```python
from typing import Any, Dict, List, Tuple, Optional

def format_results(
    results: List[Dict[str, Any]],
    output_format: str = "text"
) -> str:
    """Format validation results"""
    pass

def run_check(
    check_name: str,
    command: List[str],
    expected_output: Optional[str] = None
) -> Tuple[bool, str]:
    """Execute validation check"""
    pass
```

#### Error Handling
```python
# Specific exception handling
try:
    result = subprocess.run(cmd, check=True, capture_output=True)
except subprocess.CalledProcessError as e:
    log_error(f"Command failed: {e.cmd}")
    return False
except FileNotFoundError:
    log_error(f"Command not found: {cmd[0]}")
    return False
except Exception as e:
    log_error(f"Unexpected error: {str(e)}")
    return False
```

---

## 7. Blueprint for New Code Implementation

### File/Class Templates

#### New Shell Module Template
```bash
#!/bin/bash
# Module: [module-name]
# Purpose: [Brief description]
# Dependencies: [List required core modules]
#
# Usage:
#   source lib/modules/[module-name].sh
#   [module_name]_execute

set -euo pipefail

# Prevent multiple sourcing
if [[ -n "${_[MODULE_NAME]_SH_LOADED:-}" ]]; then
  return 0
fi
readonly _[MODULE_NAME]_SH_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${SCRIPT_DIR}")"
source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"
source "${LIB_DIR}/core/transaction.sh"
source "${LIB_DIR}/core/progress.sh"

# Module constants
readonly [MODULE]_CHECKPOINT="[checkpoint-name]"

# Module functions
[module]_check_prerequisites() {
  log_debug "Checking prerequisites for [module]"
  
  # Add prerequisite checks
  
  return 0
}

[module]_install() {
  log_info "Installing [component]"
  
  # Add installation logic
  
  transaction_record "Installed [component]" "rollback command"
}

[module]_configure() {
  log_info "Configuring [component]"
  
  # Add configuration logic
  
  transaction_record "Configured [component]" "rollback command"
}

[module]_verify() {
  log_info "Verifying [component] installation"
  
  # Add verification logic
  
  return 0
}

# Main entry point
[module]_execute() {
  log_info "Starting [module] execution"
  
  if checkpoint_exists "${[MODULE]_CHECKPOINT}"; then
    log_info "[Module] already completed (checkpoint found)"
    return 0
  fi
  
  progress_start_phase "[module]"
  
  [module]_check_prerequisites || return 1
  [module]_install || return 1
  [module]_configure || return 1
  [module]_verify || return 1
  
  checkpoint_create "${[MODULE]_CHECKPOINT}"
  progress_complete_phase "[module]"
  
  log_info "[Module] execution completed successfully"
}
```

#### New Python Utility Template
```python
#!/usr/bin/env python3
"""
Module: [module-name]
Purpose: [Brief description]

Usage:
    python3 [module-name].py [OPTIONS]

Options:
    --option VALUE    Description of option
    --verbose         Enable verbose output
"""

import argparse
import sys
from typing import Any, Dict, List, Optional

class [ModuleName]:
    """[Brief class description]"""
    
    def __init__(self, verbose: bool = False):
        """Initialize module"""
        self.verbose = verbose
    
    def run(self) -> bool:
        """Main execution method"""
        try:
            # Implementation
            return True
        except Exception as e:
            print(f"Error: {str(e)}", file=sys.stderr)
            return False

def main() -> int:
    """CLI entry point"""
    parser = argparse.ArgumentParser(
        description="[Module description]"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    
    args = parser.parse_args()
    
    module = [ModuleName](verbose=args.verbose)
    success = module.run()
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
```

### Implementation Checklist

#### Adding a New Provisioning Phase
- [ ] Create module file in `lib/modules/[phase-name].sh`
- [ ] Follow module template structure
- [ ] Implement `[phase]_execute()` entry point
- [ ] Add checkpoint creation at completion
- [ ] Record all state changes with `transaction_record`
- [ ] Add rollback commands for all changes
- [ ] Register phase in `bin/vps-provision` main function
- [ ] Add phase weight for progress tracking
- [ ] Create unit tests in `tests/unit/test_[phase].bats`
- [ ] Create integration test in `tests/integration/test_[phase].bats`
- [ ] Update documentation in `README.md`
- [ ] Add configuration options to `config/default.conf`

#### Adding a New Python Utility
- [ ] Create utility file in `lib/utils/[utility-name].py`
- [ ] Follow Python module template
- [ ] Add type hints to all functions
- [ ] Add comprehensive docstrings
- [ ] Implement CLI interface with argparse
- [ ] Add unit tests using pytest
- [ ] Update `requirements.txt` if new dependencies needed
- [ ] Add to Makefile test targets
- [ ] Document in `README.md`

### Integration Points

#### Shell → Python Integration
```bash
# Execute Python utility from shell
result=$(python3 "${LIB_DIR}/utils/utility-name.py" --option value)
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
  log_info "Utility succeeded: ${result}"
else
  log_error "Utility failed with code ${exit_code}"
fi
```

#### Adding New Configuration Option
1. Add to `config/default.conf`:
```bash
# New Feature Configuration
NEW_FEATURE_ENABLED=true
NEW_FEATURE_OPTION="value"
```

2. Access in code:
```bash
source "${LIB_DIR}/core/config.sh"
config_load

if [[ "$(config_get 'NEW_FEATURE_ENABLED')" == "true" ]]; then
  option=$(config_get "NEW_FEATURE_OPTION")
  # Use option
fi
```

### Testing Requirements

#### Unit Test Template (BATS)
```bash
#!/usr/bin/env bats
# Unit tests for [module-name]

load '../test_helper'

setup() {
  source "${LIB_DIR}/modules/[module-name].sh"
}

@test "[module]: function executes successfully" {
  run [module]_function
  [ "$status" -eq 0 ]
  [[ "$output" =~ "expected output" ]]
}

@test "[module]: handles error conditions" {
  run [module]_function "invalid_input"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "error" ]]
}
```

#### Integration Test Template
```bash
@test "Complete [phase] workflow" {
  # Setup test environment
  
  # Execute phase
  run [phase]_execute
  
  # Verify success
  [ "$status" -eq 0 ]
  
  # Verify checkpoint created
  [ -f "/var/vps-provision/checkpoints/[phase]" ]
  
  # Verify state changes
  # Add specific verifications
}
```

---

## 8. Technology Relationship Diagrams

### Stack Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CLI Entry Point                          │
│                    bin/vps-provision                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Core Libraries                            │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐  │
│  │ Logger   │Checkpoint│Transaction│ Progress │ Config  │  │
│  ├──────────┼──────────┼──────────┼──────────┼──────────┤  │
│  │Validator │Sanitize  │ Services │ State    │Rollback │  │
│  └──────────┴──────────┴──────────┴──────────┴──────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Provisioning Modules                        │
│  ┌──────────────┬──────────────┬──────────────┬─────────┐  │
│  │ System Prep  │ Desktop Env  │  RDP Server  │  User   │  │
│  ├──────────────┼──────────────┼──────────────┼─────────┤  │
│  │   VSCode     │   Cursor     │ Antigravity  │Dev Tools│  │
│  ├──────────────┼──────────────┼──────────────┼─────────┤  │
│  │  Firewall    │  Fail2ban    │ Verification │Summary  │  │
│  └──────────────┴──────────────┴──────────────┴─────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Python Utilities                           │
│  ┌──────────────┬──────────────┬──────────────────────────┐│
│  │ Health Check │Credential Gen│   Session Monitor        ││
│  └──────────────┴──────────────┴──────────────────────────┘│
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    System Services                           │
│  ┌──────────────┬──────────────┬──────────────────────────┐│
│  │   Systemd    │   XFCE       │     xrdp                 ││
│  ├──────────────┼──────────────┼──────────────────────────┤│
│  │   LightDM    │    UFW       │   fail2ban               ││
│  └──────────────┴──────────────┴──────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Component Relationships

```
┌──────────────┐
│vps-provision │──────┐
└──────────────┘      │
                      ▼
               ┌────────────┐
               │ Config     │
               └────────────┘
                      │
    ┌─────────────────┼─────────────────┐
    ▼                 ▼                 ▼
┌─────────┐     ┌──────────┐     ┌──────────┐
│ Logger  │◄────┤Checkpoint│◄────┤Transaction│
└─────────┘     └──────────┘     └──────────┘
    │                 │                 │
    └─────────────────┼─────────────────┘
                      ▼
               ┌────────────┐
               │  Modules   │
               └────────────┘
                      │
    ┌─────────────────┼─────────────────┐
    ▼                 ▼                 ▼
┌─────────┐     ┌──────────┐     ┌──────────┐
│System   │     │Desktop   │     │RDP       │
│Prep     │     │Env       │     │Server    │
└─────────┘     └──────────┘     └──────────┘
    │                 │                 │
    └─────────────────┴─────────────────┘
                      │
                      ▼
               ┌────────────┐
               │Verification│
               └────────────┘
```

### Data Flow Diagram

```
User Input (CLI)
    │
    ▼
┌─────────────────┐
│ Argument Parsing│
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Config Loading  │──► default.conf
└─────────────────┘    system.conf
    │                  user.conf
    ▼
┌─────────────────┐
│  Validation     │──► Prerequisites Check
└─────────────────┘
    │
    ▼
┌─────────────────┐
│Checkpoint Check │──► Resume or Start Fresh
└─────────────────┘
    │
    ▼
┌─────────────────┐
│Phase Execution  │
│  (Sequential)   │
└─────────────────┘
    │
    ├──► Transaction Log ──► transactions.log
    ├──► Progress Log ──────► provision.log
    ├──► State Files ──────► checkpoints/
    └──► System Changes ───► APT, systemd, files
         │
         ▼
    ┌─────────────────┐
    │  Verification   │──► Health Check (Python)
    └─────────────────┘
         │
         ▼
    ┌─────────────────┐
    │Summary Report   │──► Console + Log
    └─────────────────┘
```

---

## 9. Technology Decision Context

### Why Bash as Primary Language?

**Rationale:**
- **Direct system access:** Bash provides direct access to system commands, package managers, and configuration files without wrapper libraries
- **Zero additional runtime:** No need to install interpreters or frameworks on target system
- **Shell integration:** Natural integration with systemd, apt, and Linux system utilities
- **Deployment simplicity:** Single executable with source-able modules
- **System administration tradition:** Standard tool for DevOps automation

**Trade-offs:**
- More verbose than Python for complex logic
- Limited data structure support (arrays only)
- Type safety requires manual validation
- Error handling is more explicit and verbose

### Why Python for Utilities?

**Rationale:**
- **Structured data handling:** JSON parsing, complex data validation
- **Type safety:** Type hints with mypy provide compile-time checks
- **Security:** `secrets` module for cryptographic operations
- **Testing:** pytest provides robust testing framework
- **Cross-platform:** Python utilities can run on non-Linux systems for development

**Not used for:**
- Core provisioning logic (Bash handles system commands better)
- Main orchestration (keeps execution simple and transparent)

### Why BATS for Testing?

**Rationale:**
- **Shell-native:** Tests bash scripts in their native environment
- **No translation layer:** Direct testing of shell functions
- **Simple syntax:** Easy to write and maintain tests
- **Fast execution:** No interpreter overhead

**Alternatives considered:**
- shunit2: Less active development
- Python testing shell scripts: Added complexity and translation layer

### Architecture Decisions

#### Modular Design
**Decision:** Split functionality into small, focused modules rather than monolithic script

**Benefits:**
- Easier testing (unit tests per module)
- Clear boundaries and responsibilities
- Reusable components
- Parallel development possible

#### Transaction-Based Rollback
**Decision:** Record all state changes for automatic rollback on failure

**Benefits:**
- Safety: Failed provisioning doesn't leave system in inconsistent state
- Debugging: Transaction log provides clear audit trail
- User confidence: Failures are non-destructive

**Implementation cost:**
- Every state change requires rollback command
- ~5-10% performance overhead for logging

#### Checkpoint-Based Idempotency
**Decision:** File-based checkpoints for phase completion tracking

**Benefits:**
- Resume capability after interruption
- Fast re-runs (skip completed phases)
- Clear progress indication
- Simple implementation (file existence check)

**Alternative considered:**
- Database-based state: Overkill for single-machine tool
- No checkpointing: User risk on failure

### Technology Constraints

#### Debian 13 Only
**Constraint:** Tool only supports Debian 13 (Bookworm)

**Reason:**
- Package names differ across distributions
- Systemd service configurations vary
- Desktop environment packages differ
- Testing/validation workload multiplied per distro

**Future consideration:** Ubuntu support via distro detection

#### Root Required
**Constraint:** Must run as root user

**Reason:**
- System package installation requires root
- User creation requires root
- Service management requires root
- Firewall configuration requires root

**Security mitigation:**
- Input sanitization prevents injection
- No remote execution capabilities
- All actions logged for audit

### Upgrade Paths

#### Python Version
- **Current:** Python 3.11+
- **Compatibility:** Code uses type hints, requires 3.9+
- **Upgrade path:** Compatible with Python 3.12, 3.13
- **Migration strategy:** Update requirements.txt, test with new version

#### Bash Version
- **Current:** Bash 5.1+
- **Features used:** Arrays, associative arrays, regex matching
- **Upgrade path:** Compatible with Bash 5.2+
- **Migration strategy:** Minimal impact (stable API)

#### BATS Version
- **Current:** 1.10.0
- **Compatibility:** Test syntax has been stable
- **Upgrade path:** Follow upstream releases
- **Migration strategy:** Test suite regression testing

---

## 10. Configuration Management

### Configuration Hierarchy

1. **Default Configuration** (`config/default.conf`) - 225 options
2. **System Configuration** (`/etc/vps-provision/default.conf`) - Optional overrides
3. **User Configuration** (`~/.vps-provision.conf`) - User-specific overrides
4. **CLI Arguments** - Highest priority

### Key Configuration Categories

#### User Management (4 options)
- `DEVELOPER_USERNAME` - Username to create
- `USER_GROUPS` - Groups for developer user
- `FORCE_PASSWORD_CHANGE` - Force password change on first login
- `PASSWORD_POLICY` - Password complexity requirements

#### Desktop Environment (3 options)
- `DESKTOP_ENVIRONMENT` - Desktop to install (xfce4)
- `DISPLAY_MANAGER` - Display manager (lightdm)
- `ENABLE_DESKTOP_CUSTOMIZATION` - Apply custom theme

#### RDP Configuration (5 options)
- `RDP_PORT` - Port number (default 3389)
- `RDP_MAX_SESSIONS` - Concurrent session limit (50)
- `SESSION_TIMEOUT` - Idle timeout (3600s)
- `KILL_DISCONNECTED_SESSIONS` - Cleanup behavior
- `TLS_ENCRYPTION_LEVEL` - Encryption strength (high/medium/low)

#### IDE Selection (3 options)
- `IDES_TO_INSTALL` - Space-separated list (vscode cursor antigravity)
- `INSTALL_VSCODE_EXTENSIONS` - Auto-install extensions
- `VSCODE_EXTENSIONS` - Extension list

#### Security (7 options)
- `ENABLE_FIREWALL` - UFW firewall
- `SSH_PORT` - SSH port number
- `INSTALL_FAIL2BAN` - Intrusion prevention
- `FAIL2BAN_BANTIME` - Ban duration
- `FAIL2BAN_MAXRETRY` - Max login attempts
- `DISABLE_ROOT_SSH` - Disable root login
- `DISABLE_SSH_PASSWORD_AUTH` - Key-only auth

#### Performance (5 options)
- `PARALLEL_IDE_INSTALL` - Concurrent IDE installation
- `RESOURCE_MONITOR_INTERVAL` - Monitoring frequency (10s)
- `MEM_WARNING_THRESHOLD_MB` - Memory alert level (500MB)
- `DISK_WARNING_THRESHOLD_GB` - Disk alert level (5GB)
- `APT_PARALLEL_DOWNLOADS` - Concurrent package downloads (3)

#### Logging (6 options)
- `LOG_LEVEL` - Verbosity (DEBUG/INFO/WARNING/ERROR)
- `LOG_FILE` - Main log location
- `ENABLE_COLORS` - Colored output
- `ENABLE_PROGRESS` - Progress indicators
- `ENABLE_TRANSACTION_LOG` - Rollback logging
- `TRANSACTION_LOG` - Transaction log location

---

## 11. Development Workflow

### Getting Started
```bash
# Clone repository
git clone <repository-url>
cd vpsnew

# Install development dependencies
make install

# Run tests
make test

# Run linting
make lint

# Format code
make format
```

### Test Execution
```bash
# All tests (comprehensive)
make test               # ~2-3 minutes

# Quick validation (<30s)
make test-quick        # Linting, formatting, type checking

# Unit tests only
make test-unit         # 178 BATS tests

# Integration tests
make test-integration

# Contract tests (API validation)
make test-contract

# Python tests with coverage
make test-python

# End-to-end (requires VPS)
make test-e2e
```

### Code Quality
```bash
# Shell linting
make lint-shell        # shellcheck

# Python linting
make lint-python       # pylint + flake8

# Type checking
make typecheck-python  # mypy

# Spell checking
make spell-check       # codespell

# Secret scanning
make check-secrets     # Pattern matching
```

---

## 12. Performance Characteristics

### Provisioning Performance

| Metric | Target | Typical | Notes |
|--------|--------|---------|-------|
| **Full Provision** | ≤15 min | 13-15 min | 4GB RAM / 2 vCPU |
| **Idempotent Re-run** | ≤5 min | 3-5 min | Checkpoint-based skip |
| **System Prep** | ~3 min | 2-4 min | Package updates |
| **Desktop Install** | ~4 min | 3-5 min | XFCE + LightDM |
| **IDE Install (Parallel)** | ~3 min | 2-4 min | 3 concurrent |
| **IDE Install (Sequential)** | ~6 min | 5-7 min | If parallelization disabled |

### Performance Optimizations

1. **Parallel IDE Installation** (saves ~3 minutes)
   - VSCode, Cursor, Antigravity install concurrently
   - Enabled via `PARALLEL_IDE_INSTALL=true`

2. **APT Pipelining** (saves ~1-2 minutes)
   - 3 concurrent downloads: `APT_PARALLEL_DOWNLOADS=3`
   - HTTP pipelining enabled

3. **Checkpoint Caching** (enables fast re-runs)
   - File-based checkpoints (lightweight)
   - Sub-second checkpoint checks

4. **Resource Monitoring** (minimal overhead)
   - 10-second intervals
   - ~1-2% CPU overhead

---

## 13. Security Features

### Input Sanitization
```bash
# lib/core/sanitize.sh
sanitize_username()    # Alphanumeric only
sanitize_filepath()    # Prevent path traversal
sanitize_port()        # Valid port range
sanitize_ip()          # Valid IP format
```

### Secret Management
```python
# lib/utils/credential-gen.py
# Uses secrets module (cryptographically secure)
password = secrets.token_urlsafe(32)
```

### Hardening Measures
- SSH: Key-based auth, root login disabled
- Firewall: UFW with minimal open ports (22, 3389)
- Fail2ban: Intrusion prevention (max 5 attempts)
- TLS: Encrypted RDP connections
- Audit Logging: System-wide audit trail
- User Permissions: Non-root user for desktop access

---

## 14. Known Limitations & Future Enhancements

### Current Limitations
1. **Debian 13 Only** - No multi-distro support
2. **Root Required** - Cannot run as regular user
3. **Serial Phase Execution** - Phases execute sequentially (except IDE installs)
4. **File-Based State** - No database for state management
5. **Single Target** - Cannot provision multiple VPS simultaneously

### Planned Enhancements
1. **Ubuntu Support** - Distro detection and adaptation
2. **Configuration Profiles** - Predefined configurations (minimal, standard, full)
3. **Plugin System** - Custom phase plugins
4. **Remote Execution** - Provision from local machine to remote VPS
5. **Web UI** - Browser-based monitoring and control

---

## 15. Deployment & Operations

### Installation
```bash
# 1. Copy to target VPS
scp -r vpsnew/ root@<vps-ip>:/opt/

# 2. Execute provisioning
cd /opt/vpsnew
./bin/vps-provision

# 3. Monitor progress (separate terminal)
tail -f /var/log/vps-provision/provision.log
```

### Monitoring During Execution
- **Real-time Progress:** Console progress bar with ETA
- **Resource Monitoring:** CPU, memory, disk every 10 seconds
- **Log Files:**
  - `/var/log/vps-provision/provision.log` - Main log
  - `/var/log/vps-provision/transactions.log` - Rollback log

### Post-Installation
```bash
# Verify installation
python3 lib/utils/health-check.py

# Check status
bin/vps-provision --status

# RDP connection
xfreerdp /u:devuser /v:<vps-ip>:3389
```

---

## 16. Code Metrics

### Repository Statistics

| Metric | Count |
|--------|-------|
| **Total Lines of Code** | ~15,000 |
| **Shell Scripts** | 30+ files |
| **Python Scripts** | 4 files |
| **Core Libraries** | 14 modules |
| **Provisioning Modules** | 16 modules |
| **Functions (Shell)** | 247+ |
| **Unit Tests** | 178 tests |
| **Integration Tests** | 20+ tests |
| **Configuration Options** | 225 options |

### Code Coverage (Target)
- **Core Libraries:** 90%+ coverage
- **Provisioning Modules:** 80%+ coverage
- **Python Utilities:** 85%+ coverage

---

## 17. Documentation

### Available Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| **README** | `README.md` | Getting started, features, usage |
| **Specification** | `specs/001-vps-dev-provision/spec.md` | EARS requirements |
| **Implementation Plan** | `specs/001-vps-dev-provision/plan.md` | Detailed implementation |
| **Checklists** | `specs/001-vps-dev-provision/checklists/` | Validation checklists |
| **Contracts** | `specs/001-vps-dev-provision/contracts/` | API contracts (JSON) |
| **Changelog** | `CHANGELOG.md` | Version history |
| **Contributing** | `CONTRIBUTING.md` | Development guidelines |

---

## Conclusion

This blueprint provides a **comprehensive reference** for understanding and extending the VPS Developer Workstation Provisioning tool. The technology stack emphasizes **simplicity**, **safety**, and **automation** through a Bash-first architecture with Python utilities for complex operations.

### Key Takeaways

1. **Modular Architecture:** 14 core libraries + 16 provisioning modules
2. **Transaction Safety:** Automatic rollback on failure
3. **Idempotent Execution:** Checkpoint-based resume capability
4. **Comprehensive Testing:** 200+ tests (BATS + pytest)
5. **Production-Ready:** Real-time monitoring, logging, validation

### For New Developers

- Start by reading `README.md` and `specs/001-vps-dev-provision/spec.md`
- Review core libraries in `lib/core/` to understand foundational patterns
- Examine existing modules in `lib/modules/` for implementation examples
- Use provided templates when adding new functionality
- Run tests frequently: `make test-quick` for fast validation

### For AI Code Generation

This blueprint provides **implementation-ready** context for generating code that follows established patterns, naming conventions, and architectural decisions. Use module templates and examples as starting points for new functionality.

---

**Blueprint Generated:** 2025-12-25  
**Tool:** Technology Stack Blueprint Generator  
**Target:** GitHub Copilot AI-Assisted Development
