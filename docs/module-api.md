# Module API Documentation

> **Status**: Complete | **Version**: 1.0.0  
> **Last Updated**: Phase 12 | **Audience**: Module Developers, Contributors

## Overview

This document defines the standard API for provisioning modules in the VPS provisioning tool. All modules in `lib/modules/` MUST follow this interface to ensure consistency, testability, and compatibility with the orchestration system.

## Module Interface Contract

### Required Functions

Every provisioning module MUST implement these functions:

#### 1. `module_execute()`

**Purpose**: Main entry point for module execution

**Signature**:

```bash
module_execute() -> int
```

**Requirements**:

- MUST check for existing checkpoint before doing work
- MUST create checkpoint on successful completion
- MUST record transactions for all state changes
- MUST return 0 on success, non-zero on failure
- MUST NOT proceed if prerequisites not met

**Example**:

```bash
module_execute() {
  # Check if already completed
  if checkpoint_exists "module-name"; then
    log_info "Module already completed (checkpoint found)"
    return 0
  fi

  # Check prerequisites
  if ! module_check_prerequisites; then
    log_error "Prerequisites not met"
    return 1
  fi

  # Do work
  module_do_work || return 1

  # Verify and checkpoint
  module_verify || return 1
  checkpoint_create "module-name"

  log_info "Module completed successfully"
  return 0
}
```

#### 2. `module_check_prerequisites()`

**Purpose**: Validate that all dependencies are met before execution

**Signature**:

```bash
module_check_prerequisites() -> int
```

**Requirements**:

- MUST check for required checkpoints from dependency modules
- MUST validate required commands/binaries exist
- MUST check for required files/directories
- MUST validate system resources (memory, disk space)
- MUST return 0 if all prerequisites met, non-zero otherwise
- MUST log specific missing prerequisite on failure

**Example**:

```bash
module_check_prerequisites() {
  # Check dependency checkpoint
  if ! checkpoint_exists "system-prep"; then
    log_error "System prep not completed"
    return 1
  fi

  # Check required commands
  if ! command -v apt-get &>/dev/null; then
    log_error "apt-get not available"
    return 1
  fi

  # Check disk space
  local disk_free_gb=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
  if [[ $disk_free_gb -lt 5 ]]; then
    log_error "Insufficient disk space: ${disk_free_gb}GB free (need 5GB)"
    return 1
  fi

  return 0
}
```

### Optional Functions

#### 3. `module_verify()`

**Purpose**: Post-installation validation specific to this module

**Signature**:

```bash
module_verify() -> int
```

**Use When**:

- Installing packages that need version/presence validation
- Starting services that need health checks
- Creating files/directories that need existence checks
- Configuring settings that need correctness validation

**Example**:

```bash
module_verify() {
  # Check binary exists
  if ! command -v vscode &>/dev/null; then
    log_error "VSCode binary not found"
    return 1
  fi

  # Check desktop file
  if [[ ! -f /usr/share/applications/vscode.desktop ]]; then
    log_error "VSCode desktop launcher missing"
    return 1
  fi

  # Check version
  local version=$(vscode --version | head -1)
  log_info "VSCode version: $version"

  return 0
}
```

#### 4. `module_rollback()`

**Purpose**: Custom rollback logic beyond standard transaction rollback

**Signature**:

```bash
module_rollback() -> int
```

**Use When**:

- Complex state changes that need multi-step cleanup
- External resources (files, users, services) that need careful removal
- Order-dependent cleanup operations

**Example**:

```bash
module_rollback() {
  log_info "Rolling back module changes"

  # Stop services first
  if systemctl is-active --quiet xrdp; then
    systemctl stop xrdp
    systemctl disable xrdp
  fi

  # Remove packages
  apt-get remove -y xrdp xrdp-pulseaudio-installer

  # Remove config files
  rm -rf /etc/xrdp

  # Remove checkpoint
  checkpoint_remove "rdp-server"

  return 0
}
```

## Module Header Template

Every module MUST start with this header:

```bash
#!/bin/bash
# Module: <module-name>
# Description: <one-line description>
# Dependencies: <comma-separated list of prerequisite modules>
# Checkpoint: <checkpoint-name>

set -euo pipefail

# Prevent double-sourcing
if [[ -n "${_MODULE_<NAME>_LOADED:-}" ]]; then
  return 0
fi
readonly _MODULE_<NAME>_LOADED=1

# Source dependencies
source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"
source "${LIB_DIR}/core/transaction.sh"
# Add other dependencies as needed
```

## Checkpoint Naming Convention

Checkpoint names MUST follow these rules:

1. **Use kebab-case**: `system-prep`, `ide-vscode`, `rdp-server`
2. **Be descriptive**: Clearly indicate what phase is complete
3. **Be unique**: No two modules share the same checkpoint name
4. **Be consistent**: Same name used in checkpoint_create, checkpoint_exists, checkpoint_remove

**Examples**:

- ✅ `system-prep` - System preparation complete
- ✅ `desktop-install` - Desktop environment installed
- ✅ `ide-vscode` - VSCode installation complete
- ❌ `vscode` - Too vague
- ❌ `install_vscode` - Wrong case
- ❌ `vscode-1` - Version in checkpoint name

## Transaction Recording

Modules MUST record transactions for all state changes:

### What to Record

Record transactions for:

- ✅ Package installations: `apt-get install -y <package>`
- ✅ File modifications: Backup file before modifying
- ✅ User/group creation: `useradd`, `groupadd`
- ✅ Service state changes: `systemctl enable/start`
- ✅ Repository additions: GPG keys, sources.list entries
- ✅ Configuration changes: Any file in /etc

### How to Record

```bash
# Package installation
apt-get install -y nginx
transaction_record "Installed nginx" "apt-get remove -y nginx"

# File modification (create backup first)
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
transaction_record "Modified sshd_config" "cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config"

# User creation
useradd -m -s /bin/bash devuser
transaction_record "Created user devuser" "userdel -r devuser"

# Service enable
systemctl enable xrdp
systemctl start xrdp
transaction_record "Enabled xrdp service" "systemctl disable xrdp && systemctl stop xrdp"

# Repository addition
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/ms.gpg
transaction_record "Added Microsoft GPG key" "rm -f /usr/share/keyrings/ms.gpg"
```

## Error Handling

### Use Error Handler

All modules benefit from the global error handler:

```bash
# Automatic rollback on any error
trap 'error_handler $? "$BASH_COMMAND" "${BASH_SOURCE[0]}" "${LINENO}"' ERR
```

### Report Errors Clearly

```bash
# Bad
if ! some_command; then
  return 1
fi

# Good
if ! some_command; then
  log_error "Failed to execute some_command"
  log_error "This may be due to network connectivity or missing dependencies"
  return 1
fi
```

### Use Error Codes

Standard error codes from `lib/core/error-handler.sh`:

- `1` - General error
- `2` - Missing prerequisite
- `3` - Validation failure
- `100` - Network error
- `101` - Disk space error
- `102` - Memory error
- `103` - Permission error

```bash
if [[ $disk_free_gb -lt 5 ]]; then
  log_error "Insufficient disk space"
  return 101
fi
```

## Progress Reporting

Modules should report progress for long operations:

```bash
module_execute() {
  progress_start "Installing XFCE desktop"

  # Phase 1
  progress_update 10 "Updating package cache"
  apt-get update

  # Phase 2
  progress_update 30 "Installing XFCE core"
  apt-get install -y xfce4

  # Phase 3
  progress_update 60 "Installing XFCE plugins"
  apt-get install -y xfce4-goodies

  # Phase 4
  progress_update 90 "Configuring desktop"
  configure_xfce_settings

  progress_complete "Desktop installation complete"
}
```

## Logging Guidelines

### Log Levels

Use appropriate log levels:

```bash
log_debug "Internal variable: $var_name"          # Development only
log_info "Installing VSCode version 1.85.1"       # User-visible progress
log_warning "Retrying download (attempt 2/3)"     # Recoverable issues
log_error "Failed to install critical package"    # Fatal errors
```

### Redact Sensitive Data

NEVER log passwords, keys, or tokens:

```bash
# Bad
log_info "Generated password: $password"

# Good
log_info "Generated secure password: [REDACTED]"
```

### Be Concise

```bash
# Bad
log_info "Now we are going to start the process of installing the Visual Studio Code editor which will take approximately 2-3 minutes"

# Good
log_info "Installing Visual Studio Code..."
```

## Testing Requirements

### Unit Tests

Every module MUST have unit tests in `tests/unit/`:

```bash
# tests/unit/test_module_name.bats

@test "module: check_prerequisites succeeds with valid state" {
  # Setup
  mock_checkpoint_exists() { return 0; }
  mock_command() { return 0; }

  # Execute
  run module_check_prerequisites

  # Assert
  [ "$status" -eq 0 ]
}

@test "module: check_prerequisites fails without dependency" {
  mock_checkpoint_exists() { return 1; }

  run module_check_prerequisites

  [ "$status" -eq 1 ]
  [[ "$output" =~ "Prerequisites not met" ]]
}
```

### Integration Tests

Modules MUST have integration tests in `tests/integration/`:

```bash
# tests/integration/test_module_name.bats

@test "module: executes successfully on fresh system" {
  # Setup
  setup_test_environment

  # Execute
  run module_execute

  # Assert
  [ "$status" -eq 0 ]
  checkpoint_exists "module-name"
  verify_installation
}
```

## Parallel Execution Support

Modules that can run in parallel MUST:

1. **Declare parallelism**: Mark with `[P]` in tasks.md
2. **Avoid shared state**: No writes to same files/directories
3. **Use unique checkpoints**: No checkpoint name collisions
4. **Be idempotent**: Safe if run multiple times simultaneously

**Example Parallel-Safe Module**:

```bash
ide_vscode_execute() {
  # Each IDE has unique checkpoint
  if checkpoint_exists "ide-vscode"; then
    return 0
  fi

  # Unique repository file
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > \
    /etc/apt/sources.list.d/vscode.list

  # Unique GPG keyring
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor > /usr/share/keyrings/vscode.gpg

  # Install with unique package name
  apt-get install -y code

  # Unique checkpoint
  checkpoint_create "ide-vscode"
}
```

## Module Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│ 1. check_prerequisites()                                │
│    ├─ Check dependency checkpoints                      │
│    ├─ Validate required commands                        │
│    └─ Check system resources                            │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 2. execute()                                             │
│    ├─ Check existing checkpoint                         │
│    ├─ Perform provisioning work                         │
│    ├─ Record all transactions                           │
│    └─ Update progress                                   │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 3. verify()                                              │
│    ├─ Check installation success                        │
│    ├─ Validate service health                           │
│    └─ Test basic functionality                          │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 4. checkpoint_create()                                   │
│    └─ Mark phase as complete                            │
└─────────────────────────────────────────────────────────┘

On Error:
┌─────────────────────────────────────────────────────────┐
│ error_handler()                                          │
│    ├─ Log error with context                            │
│    ├─ Trigger rollback_execute()                        │
│    └─ Exit with non-zero code                           │
└─────────────────────────────────────────────────────────┘
```

## Module Examples

### Minimal Module

```bash
#!/bin/bash
# Module: example
# Description: Example minimal module
# Dependencies: system-prep
# Checkpoint: example

set -euo pipefail

if [[ -n "${_MODULE_EXAMPLE_LOADED:-}" ]]; then return 0; fi
readonly _MODULE_EXAMPLE_LOADED=1

source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"

example_check_prerequisites() {
  checkpoint_exists "system-prep" || return 1
  return 0
}

example_execute() {
  if checkpoint_exists "example"; then
    log_info "Example already completed"
    return 0
  fi

  if ! example_check_prerequisites; then
    log_error "Prerequisites not met"
    return 1
  fi

  log_info "Executing example module"
  # Do work here

  checkpoint_create "example"
  return 0
}
```

### Complex Module with Phases

```bash
#!/bin/bash
# Module: complex-example
# Description: Complex module with multiple phases
# Dependencies: system-prep, desktop-env
# Checkpoint: complex-example

set -euo pipefail

if [[ -n "${_MODULE_COMPLEX_EXAMPLE_LOADED:-}" ]]; then return 0; fi
readonly _MODULE_COMPLEX_EXAMPLE_LOADED=1

source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"
source "${LIB_DIR}/core/transaction.sh"
source "${LIB_DIR}/core/progress.sh"

complex_check_prerequisites() {
  checkpoint_exists "system-prep" || return 1
  checkpoint_exists "desktop-env" || return 1
  command -v apt-get &>/dev/null || return 1
  return 0
}

complex_phase1() {
  progress_update 20 "Phase 1: Repository setup"
  wget -qO- https://example.com/key.asc | gpg --dearmor > /usr/share/keyrings/example.gpg
  transaction_record "Added repository key" "rm -f /usr/share/keyrings/example.gpg"

  echo "deb [signed-by=/usr/share/keyrings/example.gpg] https://example.com/repo stable main" > \
    /etc/apt/sources.list.d/example.list
  transaction_record "Added repository" "rm -f /etc/apt/sources.list.d/example.list"

  apt-get update
}

complex_phase2() {
  progress_update 50 "Phase 2: Package installation"
  apt-get install -y example-package
  transaction_record "Installed example-package" "apt-get remove -y example-package"
}

complex_phase3() {
  progress_update 80 "Phase 3: Configuration"
  cp /etc/example/config.default /etc/example/config
  transaction_record "Created config" "rm -f /etc/example/config"

  sed -i 's/port=8080/port=8888/' /etc/example/config
}

complex_verify() {
  command -v example-binary &>/dev/null || return 1
  [[ -f /etc/example/config ]] || return 1
  systemctl is-active --quiet example-service || return 1
  return 0
}

complex_execute() {
  if checkpoint_exists "complex-example"; then
    log_info "Complex example already completed"
    return 0
  fi

  if ! complex_check_prerequisites; then
    log_error "Prerequisites not met"
    return 1
  fi

  progress_start "Complex Example Installation"

  complex_phase1 || return 1
  complex_phase2 || return 1
  complex_phase3 || return 1

  progress_update 90 "Verifying installation"
  if ! complex_verify; then
    log_error "Verification failed"
    return 1
  fi

  checkpoint_create "complex-example"
  progress_complete "Complex example installed successfully"
  return 0
}
```

## Summary

**Key Takeaways**:

1. ✅ Implement required functions: `execute()`, `check_prerequisites()`
2. ✅ Use checkpoints for idempotency
3. ✅ Record transactions for rollback safety
4. ✅ Report progress for long operations
5. ✅ Validate inputs and outputs thoroughly
6. ✅ Test with unit and integration tests
7. ✅ Follow naming conventions and error codes
8. ✅ Log appropriately with correct levels
9. ✅ Handle errors gracefully with clear messages
10. ✅ Document dependencies and checkpoints

**Reference Modules**:

- Simple: `lib/modules/dev-tools.sh`
- Complex: `lib/modules/desktop-env.sh`
- Parallel-safe: `lib/modules/ide-vscode.sh`

For questions or clarifications, see [docs/troubleshooting.md](troubleshooting.md) or open an issue.
