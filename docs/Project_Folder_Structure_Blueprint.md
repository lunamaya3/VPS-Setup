# Project Folder Structure Blueprint

**Project**: VPS-Setup  
**Type**: Shell/Bash + Python Hybrid System  
**Purpose**: Automated VPS provisioning and configuration management  
**Last Updated**: 2025-12-25  
**Version**: 1.0.0

---

## 1. Structural Overview

### Project Identity

The VPS-Setup project is a **Shell-based provisioning system** with Python utility support, designed to transform fresh Debian 13 VPS instances into fully-functional developer workstations. The project follows a **modular architecture** with clear separation of concerns across infrastructure, business logic, and testing layers.

### Technology Stack Detected

| Technology | Evidence | Version/Details |
|------------|----------|----------------|
| **Bash/Shell** | Primary implementation language | Bash 5.0+ with `set -euo pipefail` strict mode |
| **Python** | Utility scripts and health checks | Python 3.9+ (`requirements.txt` present) |
| **BATS** | Testing framework | BATS Core 1.10.0 (Bash Automated Testing System) |
| **Make** | Build automation | GNU Make with parallel job support |
| **Git** | Version control | Standard Git workflow with hooks |

### Architectural Principles

1. **Layered Organization** (by technical responsibility)
   - **Core Infrastructure** (`lib/core/`): Cross-cutting concerns, reusable utilities
   - **Feature Modules** (`lib/modules/`): Business logic for specific provisioning tasks
   - **Data Models** (`lib/models/`): JSON schemas for state management
   - **Utilities** (`lib/utils/`): Python helpers for complex operations

2. **Not a Monorepo**: Single cohesive project with interdependent modules

3. **No Microservices**: Monolithic provisioning tool with modular internal structure

4. **Minimal Frontend**: Configuration-based desktop setup (XFCE), no web UI

---

## 2. Directory Visualization

````
vpsnew/                              # Project root
├── .agent/                          # AI agent configuration and workflows
│   └── workflows/                   # Workflow definitions (.md files)
├── .github/                         # GitHub workflows and templates
│   └── prompts/                     # Prompt engineering templates
├── bin/                             # Executable entry points
│   ├── vps-provision                # Main CLI command (641 LOC)
│   ├── preflight-check              # Pre-flight validation script
│   ├── session-manager.sh           # RDP session management
│   └── release.sh                   # Release automation
├── config/                          # Default configuration files
│   ├── default.conf                 # System-wide defaults
│   └── desktop/                     # Desktop environment configs
│       ├── terminalrc               # XFCE terminal settings
│       ├── xfce4-panel.xml          # Panel configuration
│       └── xsettings.xml            # Desktop settings
├── docs/                            # Comprehensive documentation
│   ├── README.md                    # Documentation index
│   ├── architecture.md              # System architecture (53KB)
│   ├── cli-usage.md                 # CLI reference
│   ├── module-api.md                # Module development guide
│   ├── performance.md               # Performance SLOs
│   ├── quickstart.md                # Quick start guide
│   ├── security.md                  # Security guidelines
│   ├── troubleshooting.md           # Common issues and solutions
│   └── phase9-ux-quick-reference.md # UX standards
├── etc/                             # System integration files
│   └── bash-completion.d/           # Shell completions
│       └── vps-provision            # Bash completion script
├── lib/                             # Core library code (40 items)
│   ├── core/                        # Infrastructure modules (14 files)
│   │   ├── logger.sh                # Logging system with severity levels
│   │   ├── config.sh                # Configuration management
│   │   ├── validator.sh             # Pre-flight validation
│   │   ├── checkpoint.sh            # Idempotency checkpoints
│   │   ├── transaction.sh           # Transactional operations
│   │   ├── rollback.sh              # Rollback mechanisms
│   │   ├── progress.sh              # Progress reporting
│   │   ├── state.sh                 # State management
│   │   ├── error-handler.sh         # Error handling utilities
│   │   ├── ux.sh                    # UX helpers (prompts, colors)
│   │   ├── sanitize.sh              # Input sanitization (SEC-018)
│   │   ├── services.sh              # Systemd service management
│   │   ├── lock.sh                  # File-based locking
│   │   └── file-ops.sh              # File operations
│   ├── modules/                     # Feature modules (16 files)
│   │   ├── system-prep.sh           # System preparation phase
│   │   ├── desktop-env.sh           # XFCE installation
│   │   ├── rdp-server.sh            # RDP server configuration
│   │   ├── user-provisioning.sh     # User creation and setup
│   │   ├── ide-vscode.sh            # VS Code installation
│   │   ├── ide-cursor.sh            # Cursor IDE installation
│   │   ├── ide-antigravity.sh       # Antigravity IDE installation
│   │   ├── parallel-ide-install.sh  # Parallel IDE installation orchestrator
│   │   ├── terminal-setup.sh        # Terminal enhancements
│   │   ├── dev-tools.sh             # Development tools
│   │   ├── firewall.sh              # Firewall configuration
│   │   ├── fail2ban.sh              # Intrusion prevention
│   │   ├── verification.sh          # Post-install validation
│   │   ├── audit-logging.sh         # Audit trail logging
│   │   ├── status-banner.sh         # System status display
│   │   └── summary-report.sh        # Final provisioning report
│   ├── models/                      # JSON schema definitions (3 files)
│   │   ├── checkpoint.schema.json   # Checkpoint data structure
│   │   ├── provisioning-session.schema.json  # Session metadata
│   │   └── transaction-log.schema.json       # Transaction records
│   └── utils/                       # Python utilities (7 files)
│       ├── health-check.py          # System health verification
│       ├── session-monitor.py       # RDP session monitoring
│       ├── credential-gen.py        # Secure credential generation
│       ├── package-manager.py       # Advanced package operations
│       ├── benchmark.sh             # Performance benchmarking
│       ├── performance-monitor.sh   # Real-time performance tracking
│       └── state-compare.sh         # State diff utility
├── specs/                           # Specification-driven development
│   └── 001-vps-dev-provision/       # Main feature spec (24 files)
│       └── *.md                     # Individual spec documents
├── tests/                           # Test suites (52 items)
│   ├── test_helper.bash             # Shared test utilities
│   ├── unit/                        # Unit tests (178 tests)
│   │   ├── test_checkpoint.bats     # Checkpoint system tests
│   │   ├── test_config.bats         # Configuration tests
│   │   ├── test_logger.bats         # Logger tests
│   │   ├── test_sanitize.bats       # Sanitization tests
│   │   ├── test_validator.bats      # Validation tests
│   │   ├── test_credential_gen.py   # Python credential tests
│   │   ├── test_health_check.py     # Python health check tests
│   │   └── test_session_monitor.py  # Python session tests
│   ├── integration/                 # Integration tests (29 files)
│   │   ├── test_complete_workflow.bats      # End-to-end workflows
│   │   ├── test_desktop_rdp.bats            # Desktop + RDP integration
│   │   ├── test_ide_install.bats            # IDE installation tests
│   │   ├── test_rollback.bats               # Rollback mechanism tests
│   │   ├── test_multi_session.bats          # Multi-user tests
│   │   ├── test_security_penetration.bats   # Security tests
│   │   └── ...                              # Additional integration tests
│   ├── contract/                    # Contract tests (3 files)
│   │   ├── test_cli_interface.bats          # CLI contract verification
│   │   ├── test_module_interfaces.bats      # Module API contracts
│   │   └── test_validation_interface.bats   # Validation contracts
│   └── e2e/                         # End-to-end tests (8 files)
│       ├── test_full_provision.sh           # Complete provisioning flow
│       ├── test_idempotent_rerun.sh         # Idempotency validation
│       ├── test_failure_rollback.sh         # Rollback scenarios
│       ├── test_multi_session.sh            # Concurrent sessions
│       └── ...                              # Performance and load tests
├── CHANGELOG.md                     # Version history (11KB)
├── CONTRIBUTING.md                  # Contribution guidelines (15KB)
├── Makefile                         # Build automation (311 LOC)
├── README.md                        # Project overview (30KB)
├── Technology_Stack_Blueprint.md    # Tech stack documentation (54KB)
├── exemplars.md                     # Code examples and patterns (24KB)
└── requirements.txt                 # Python dependencies (15 packages)
````

**Notes**:
- Generated folders excluded: `.venv/`, `.cache/`, `.pytest_cache/`, `.mypy_cache/`, `__pycache__/`
- Total unique directory count: 12 (excluding generated)
- Total file count: ~150+ source files
- Lines of Code (estimated): ~15,000+ lines of Shell + 2,000+ lines of Python

---

## 3. Key Directory Analysis

### `/bin` - Executable Entry Points

**Purpose**: Command-line interface and user-facing executables

| File | Purpose | Key Features |
|------|---------|--------------|
| `vps-provision` | Main CLI entry point | 641 LOC, argument parsing, dry-run mode, phase orchestration |
| `preflight-check` | Environment validation | Checks OS, disk, RAM, network before provisioning |
| `session-manager.sh` | RDP session management | Multi-user session handling, monitoring |
| `release.sh` | Release automation | Version bumping, changelog generation |

**Conventions**:
- No `.sh` extension (executable commands)
- Shebang: `#!/bin/bash`
- Strict mode: `set -euo pipefail`
- Must source required libraries from `lib/core/`

---

### `/lib/core` - Infrastructure & Cross-Cutting Concerns

**Purpose**: Reusable utilities that support all modules

| Module | Responsibility | Exported Functions |
|--------|----------------|-------------------|
| `logger.sh` | Structured logging | `log_debug()`, `log_info()`, `log_warning()`, `log_error()` |
| `config.sh` | Configuration mgmt | `config_load()`, `config_get()`, `config_set()` |
| `validator.sh` | Pre-flight validation | `validator_check_prerequisites()`, `validator_check_disk()` |
| `checkpoint.sh` | Idempotency | `checkpoint_exists()`, `checkpoint_save()`, `checkpoint_clear()` |
| `transaction.sh` | Atomic operations | `transaction_begin()`, `transaction_commit()`, `transaction_rollback()` |
| `rollback.sh` | Failure recovery | `rollback_register_action()`, `rollback_execute()` |
| `progress.sh` | Progress reporting | `progress_init()`, `progress_update()`, `progress_complete()` |
| `state.sh` | Session state | `state_init_session()`, `state_update_status()` |
| `sanitize.sh` | Input sanitization | `sanitize_username()`, `sanitize_path()` (Security: SEC-018) |

**Naming Convention**: All functions prefixed with module name (e.g., `logger_info`, `config_load`)

**Dependencies**: Core modules must have NO dependencies on feature modules

---

### `/lib/modules` - Feature Modules

**Purpose**: Business logic for specific provisioning phases

**Organizational Pattern**: One module per provisioning phase

| Phase | Module | Responsibility |
|-------|--------|----------------|
| 1 | `system-prep.sh` | System updates, base package installation |
| 2 | `desktop-env.sh` | XFCE desktop environment installation |
| 3 | `rdp-server.sh` | RDP server (xrdp) configuration on port 3389 |
| 4 | `user-provisioning.sh` | Developer user creation with sudo privileges |
| 5 | `ide-vscode.sh` | Visual Studio Code installation |
| 6 | `ide-cursor.sh` | Cursor IDE installation |
| 7 | `ide-antigravity.sh` | Antigravity IDE installation |
| 8 | `terminal-setup.sh` | Shell enhancements (oh-my-bash, themes) |
| 9 | `dev-tools.sh` | Development tools (git, build-essential, docker) |
| 10 | `verification.sh` | Post-install validation and health checks |

**Supporting Modules**:
- `parallel-ide-install.sh`: Orchestrates concurrent IDE installations
- `firewall.sh`: UFW firewall rules
- `fail2ban.sh`: Intrusion prevention
- `audit-logging.sh`: Security audit trails
- `status-banner.sh`: Login banner with system info
- `summary-report.sh`: Final provisioning summary

**Module Contract** (see `docs/module-api.md`):
```bash
# Required function pattern
module_name_install() {
  # 1. Check prerequisites
  # 2. Register rollback actions
  # 3. Execute installation
  # 4. Save checkpoint
  # 5. Verify installation
}
```

---

### `/lib/models` - Data Schemas

**Purpose**: JSON Schema definitions for structured data

**Files**:
1. `checkpoint.schema.json`: Checkpoint metadata structure
2. `provisioning-session.schema.json`: Session state schema
3. `transaction-log.schema.json`: Transaction history format

**Usage**: Validated by Python utilities before persistence

---

### `/lib/utils` - Python Utilities

**Purpose**: Complex operations better suited for Python

| Utility | Language | Purpose |
|---------|----------|---------|
| `health-check.py` | Python | System health verification (services, ports, processes) |
| `session-monitor.py` | Python | RDP session monitoring with `psutil` |
| `credential-gen.py` | Python | Cryptographically secure password generation |
| `package-manager.py` | Python | Advanced `apt` operations with dependency resolution |
| `benchmark.sh` | Bash | Performance benchmarking |
| `performance-monitor.sh` | Bash | Real-time resource monitoring |
| `state-compare.sh` | Bash | State diff between checkpoints |

**Testing**: Python utilities have corresponding tests in `tests/unit/test_*.py`

---

### `/tests` - Test Organization

**Test Pyramid**:

```
        E2E (8 tests)           ← Full provisioning flows (~15min)
      ↗                ↖
Integration (29 tests)           ← Module interactions (~2min)
  ↗                      ↖
Unit (178 tests)                 ← Function-level tests (<30s)
  ↗                        ↖
Contract (3 tests)               ← API interface validation (<1min)
```

**Directory Structure**:
- `test_helper.bash`: Shared BATS utilities (mocking, assertions)
- `unit/`: Fast, isolated tests for individual functions
- `integration/`: Tests for module interactions and workflows
- `contract/`: API contract verification for CLI and module interfaces
- `e2e/`: Full system tests requiring VPS environment

**Test Naming Convention**:
- BATS files: `test_<module>.bats`
- Python files: `test_<utility>.py`
- Test functions: `@test "module_function: behavior when condition"`

**Coverage Requirements**:
- Unit: ≥80% function coverage
- Integration: Critical paths
- E2E: Happy path + failure scenarios

---

### `/config` - Configuration Files

**Purpose**: Default configurations for desktop environment

**Structure**:
```
config/
├── default.conf           # System-wide defaults (sourced by config.sh)
└── desktop/               # Desktop environment configurations
    ├── terminalrc         # XFCE Terminal settings
    ├── xfce4-panel.xml    # Panel layout and plugins
    └── xsettings.xml      # Desktop theme and appearance
```

**Usage**: Copied to user home directories during provisioning

---

### `/docs` - Documentation

**Purpose**: Comprehensive technical documentation

| Document | Content | Size |
|----------|---------|------|
| `README.md` | Project overview, quick start | 30KB |
| `architecture.md` | System architecture, design decisions | 53KB |
| `cli-usage.md` | CLI reference and examples | 15KB |
| `module-api.md` | Module development guide | 17KB |
| `performance.md` | Performance SLOs and benchmarks | 9KB |
| `security.md` | Security guidelines and controls | 15KB |
| `troubleshooting.md` | Common issues and solutions | 14KB |
| `quickstart.md` | Quick start guide | 9KB |

**Maintenance**: Documentation updated with every architecture change

---

### `/specs` - Specification-Driven Development

**Purpose**: Detailed feature specifications before implementation

**Structure**:
```
specs/
└── 001-vps-dev-provision/      # Main feature specification
    ├── overview.md
    ├── requirements.md
    ├── architecture.md
    ├── security.md
    ├── testing-strategy.md
    └── ... (24 files total)
```

**Philosophy**: Write specs first, implement second (spec-driven development)

---

## 4. File Placement Patterns

### Configuration Files

| Type | Location | Example |
|------|----------|---------|
| System-wide defaults | `config/default.conf` | Log levels, paths, timeouts |
| Desktop configurations | `config/desktop/` | XFCE settings, themes |
| User-specific runtime | `/etc/vps-provision/` | Runtime settings (managed by tool) |
| Environment-specific | N/A | Single environment (Debian 13) |

### Business Logic

| Type | Location | Rationale |
|------|----------|-----------|
| Core utilities | `lib/core/` | No dependencies on business logic |
| Feature modules | `lib/modules/` | One module per provisioning phase |
| Python utilities | `lib/utils/` | Complex operations (package mgmt, monitoring) |
| Helper scripts | `bin/` | User-facing entry points |

### Interface Definitions

| Type | Location | Example |
|------|----------|---------|
| Module contracts | Documented in `docs/module-api.md` | Function signatures, return codes |
| JSON schemas | `lib/models/*.schema.json` | Data structure validation |

### Test Files

| Type | Location | Naming |
|------|----------|--------|
| Unit tests (BATS) | `tests/unit/test_<module>.bats` | Mirrors `lib/` structure |
| Unit tests (Python) | `tests/unit/test_<utility>.py` | Mirrors `lib/utils/` structure |
| Integration tests | `tests/integration/test_<feature>.bats` | Feature-based naming |
| Contract tests | `tests/contract/test_<interface>.bats` | Interface validation |
| E2E tests | `tests/e2e/test_<scenario>.sh` | Scenario-based naming |

### Documentation Files

| Type | Location | Naming |
|------|----------|--------|
| API documentation | `docs/module-api.md` | Markdown with code examples |
| Architecture | `docs/architecture.md` | Mermaid diagrams, decision records |
| User guides | `docs/quickstart.md`, `docs/cli-usage.md` | Step-by-step instructions |
| Troubleshooting | `docs/troubleshooting.md` | Problem-solution format |

---

## 5. Naming and Organization Conventions

### File Naming Patterns

| Type | Convention | Example |
|------|-----------|----------|
| Shell scripts (lib) | `kebab-case.sh` | `checkpoint.sh`, `error-handler.sh` |
| Shell scripts (bin) | `kebab-case` (no extension) | `vps-provision`, `preflight-check` |
| Python scripts | `snake_case.py` | `health_check.py`, `session_monitor.py` |
| BATS tests | `test_<module>.bats` | `test_logger.bats` |
| Python tests | `test_<utility>.py` | `test_credential_gen.py` |
| Documentation | `kebab-case.md` | `quickstart.md`, `module-api.md` |
| Configuration | `kebab-case.conf` or `.xml` | `default.conf`, `terminalrc` |

### Function Naming Patterns

| Type | Convention | Example |
|------|-----------|----------|
| Public functions | `module_verb_object()` | `logger_info()`, `checkpoint_save()` |
| Private functions | `_module_verb_object()` | `_config_validate_key()` |
| BATS tests | `@test "module_function: behavior when condition"` | `@test "logger_info: outputs formatted message"` |

**Namespace Prefix**: All public functions MUST use module prefix (enforced by code review)

### Folder Naming Patterns

| Type | Convention | Example |
|------|-----------|----------|
| Top-level | `lowercase` | `bin`, `lib`, `docs`, `tests` |
| Module categories | `lowercase` | `core`, `modules`, `utils`, `models` |
| Test categories | `lowercase` | `unit`, `integration`, `contract`, `e2e` |

### Variable Naming Patterns

| Scope | Convention | Example |
|-------|-----------|----------|
| Global/Exported | `UPPERCASE_SNAKE_CASE` | `PROJECT_ROOT`, `LOG_LEVEL` |
| Local variables | `lowercase_snake_case` | `session_id`, `phase_name` |
| Constants (readonly) | `readonly UPPER_CASE` | `readonly VERSION="1.0.0"` |

---

## 6. Navigation and Development Workflow

### Entry Points

| Goal | Start Here |
|------|-----------|
| Understand project | [README.md](file:///home/racoon/vpsnew/README.md) |
| Run provisioning | [bin/vps-provision](file:///home/racoon/vpsnew/bin/vps-provision) with `--help` |
| Architecture overview | [docs/architecture.md](file:///home/racoon/vpsnew/docs/architecture.md) |
| Develop new module | [docs/module-api.md](file:///home/racoon/vpsnew/docs/module-api.md) |
| Contribute code | [CONTRIBUTING.md](file:///home/racoon/vpsnew/CONTRIBUTING.md) |
| Run tests | [Makefile](file:///home/racoon/vpsnew/Makefile) → `make test` |

### Common Development Tasks

#### Adding a New Feature Module

1. **Create module**: `lib/modules/feature-name.sh`
2. **Implement contract**:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   # Source dependencies
   source "${LIB_DIR}/core/logger.sh"
   source "${LIB_DIR}/core/checkpoint.sh"
   
   feature_name_install() {
     local phase_name="feature-name"
     
     if checkpoint_exists "$phase_name"; then
       log_info "Phase already completed: $phase_name"
       return 0
     fi
     
     # Implementation
     
     checkpoint_save "$phase_name"
   }
   ```
3. **Add tests**: `tests/unit/test_feature_name.bats`
4. **Update documentation**: `docs/module-api.md`
5. **Register in CLI**: Add to `bin/vps-provision` phase list

#### Adding a New Test

1. **Unit test** (BATS):
   ```bash
   # tests/unit/test_my_module.bats
   #!/usr/bin/env bats
   load '../test_helper'
   
   setup() {
     common_setup
     source "${LIB_DIR}/modules/my-module.sh"
   }
   
   @test "my_module_function: expected behavior" {
     run my_module_function "input"
     assert_success
     assert_output "expected output"
   }
   ```

2. **Python test** (pytest):
   ```python
   # tests/unit/test_my_utility.py
   import pytest
   from lib.utils.my_utility import MyClass
   
   def test_my_function():
       result = MyClass().my_function("input")
       assert result == "expected"
   ```

#### Modifying Configuration

- **System defaults**: Edit `config/default.conf`
- **Desktop settings**: Modify files in `config/desktop/`
- **Runtime config**: Use `config_set()` from `lib/core/config.sh`

### Dependency Patterns

**Dependency Flow** (allowed directions):
```
bin/vps-provision
    ↓
lib/modules/*  →  lib/core/*  →  (No further dependencies)
    ↓                  ↓
lib/utils/*    →  lib/models/* (JSON schemas)
```

**Import Pattern**:
```bash
# Always source from ${PROJECT_ROOT} or ${LIB_DIR}
source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/config.sh"
```

**Forbidden**:
- Core modules MUST NOT depend on feature modules
- Feature modules MUST NOT have circular dependencies

---

## 7. Build and Output Organization

### Build Configuration

| File | Purpose |
|------|---------|
| [Makefile](file:///home/racoon/vpsnew/Makefile) | Build automation, test orchestration |
| `requirements.txt` | Python dependency specification |
| `.bats-version` | BATS framework version lock |

**Make Targets**:
```bash
make install          # Install dependencies (BATS, Python packages)
make test             # Run all tests (quick + slow)
make test-quick       # Fast checks (<30s): lint, format, spell-check
make test-slow        # Test suites: unit, integration, contract
make test-unit        # Unit tests only (178 tests)
make test-integration # Integration tests
make test-contract    # Contract tests
make test-python      # Python tests with coverage
make lint             # ShellCheck linting
make format           # Auto-format with shfmt
make clean            # Clean temporary files and logs
```

### Output Structure

| Output | Location | Purpose |
|--------|----------|---------|
| Logs | `/var/log/vps-provision/` | Provisioning execution logs |
| Checkpoints | `/var/lib/vps-provision/checkpoints/` | Idempotency state |
| Session state | `/var/lib/vps-provision/sessions/` | Session metadata |
| Test cache | `.cache/test/` | Cached test results (shellcheck, etc.) |

**Log Rotation**: Managed by `lib/core/logger.sh` (max 100MB total)

### Environment-Specific Builds

**Single Environment**: Debian 13 only
- No multi-environment support
- Target OS validated in pre-flight checks

---

## 8. Technology-Specific Organization

### Shell/Bash Project Structure

#### Script Organization

**Standard Header**:
```bash
#!/bin/bash
# Module: <Name>
# Purpose: <Brief description>
# Author: <Team/Individual>

set -euo pipefail  # Strict mode (always required)

# Source dependencies
source "${LIB_DIR}/core/logger.sh"
```

**Function Grouping**:
- Public functions first
- Private functions (prefixed with `_`) last
- Alphabetical order within groups

#### Linting and Formatting

- **ShellCheck**: Zero warnings policy (enforced in CI)
- **shfmt**: 2-space indents, `-ci` (case indent)
- **Allowed suppressions**: Document with `# shellcheck disable=SCXXXX # Reason`

**Example**:
```bash
# shellcheck disable=SC2034  # Variable used by sourcing script
EXPORTED_VAR="value"
```

#### Testing with BATS

**Test Structure**:
```bash
#!/usr/bin/env bats
load '../test_helper'

setup() {
  common_setup
  # Test-specific setup
}

teardown() {
  common_teardown
}

@test "module_function: description of behavior" {
  # Arrange
  local input="test"
  
  # Act
  run module_function "$input"
  
  # Assert
  assert_success
  assert_output "expected"
}
```

**Test Helpers** (`tests/test_helper.bash`):
- `common_setup()`: Initialize test environment
- `common_teardown()`: Clean up test artifacts
- `mock_command()`: Mock external commands
- `create_mock_file()`: Create test files

---

### Python Utility Structure

#### Code Organization

**Module Structure**:
```python
#!/usr/bin/env python3
"""Module docstring.

Detailed description of module purpose and usage.
"""

import sys
from typing import Optional

# Constants
DEFAULT_TIMEOUT = 30

# Classes
class MyClass:
    """Class docstring."""
    
    def __init__(self) -> None:
        """Initialize instance."""
        pass

# Main execution
if __name__ == "__main__":
    sys.exit(main())
```

#### Testing with pytest

**Test Organization**:
```python
# tests/unit/test_my_utility.py
import pytest
from lib.utils.my_utility import MyClass

def test_success_case():
    """Test description."""
    result = MyClass().my_method("input")
    assert result == "expected"

def test_exception_case():
    """Test error handling."""
    with pytest.raises(ValueError):
        MyClass().my_method(None)
```

**Coverage Requirements**: ≥80% line coverage (enforced in `make test-python`)

#### Linting and Formatting

- **flake8**: Max line length 120, ignore E203, W503
- **pylint**: Disable C0111 (missing docstring for simple functions)
- **black**: Auto-formatting
- **mypy**: Type checking with `--ignore-missing-imports`

---

## 9. Extension and Evolution

### Extension Points

#### Adding New Provisioning Phases

1. **Create module**: `lib/modules/new-phase.sh`
2. **Register in CLI**: Add to `VALID_PHASES` in `bin/vps-provision`
3. **Add phase duration**: Update `phase_durations` map in CLI
4. **Create tests**: `tests/unit/test_new_phase.bats`
5. **Document**: Update `docs/module-api.md`

**Template**:
```bash
#!/bin/bash
set -euo pipefail

source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"
source "${LIB_DIR}/core/rollback.sh"

new_phase_install() {
  local phase_name="new-phase"
  
  if checkpoint_exists "$phase_name"; then
    log_info "Phase completed: $phase_name"
    return 0
  fi
  
  log_info "Starting phase: $phase_name"
  
  # Register rollback actions
  rollback_register_action "cleanup_new_phase"
  
  # Implementation
  
  # Verification
  
  checkpoint_save "$phase_name"
  log_info "Completed phase: $phase_name"
}

cleanup_new_phase() {
  # Rollback logic
  :
}
```

#### Adding New Core Utilities

1. **Identify scope**: Does it belong in `core/`, `modules/`, or `utils/`?
2. **Create module**: Follow naming conventions
3. **Document exports**: Add to `docs/module-api.md`
4. **Write tests**: Aim for 100% coverage for core utilities
5. **Update imports**: Modules that need it should source the new utility

---

### Scalability Patterns

**Horizontal Scaling** (adding features):
- Add new modules in `lib/modules/`
- Register in phase orchestrator
- Tests scale with features

**Vertical Scaling** (complex features):
- Break down into sub-modules
- Use Python utilities for complex operations
- Maintain single-responsibility principle

**Code Splitting**:
- Large modules (>500 LOC) should be split into sub-modules
- Extract common patterns to `lib/core/`

---

### Refactoring Patterns

**Common Refactorings**:

1. **Extract Core Utility**:
   - When same code appears in 3+ modules
   - Move to `lib/core/<utility>.sh`
   - Update imports in affected modules

2. **Extract Python Utility**:
   - When shell becomes too complex (>50 LOC function)
   - Implement in `lib/utils/<utility>.py`
   - Call from shell with `python3 ${LIB_DIR}/utils/<utility>.py`

3. **Split Large Module**:
   - Create sub-directory: `lib/modules/<feature>/`
   - Split into `install.sh`, `configure.sh`, `verify.sh`
   - Main module sources sub-modules

---

## 10. Structure Templates

### New Feature Module Template

**Directory Structure**:
```
lib/modules/new-feature.sh         # Main module
tests/unit/test_new_feature.bats   # Unit tests
tests/integration/test_new_feature.bats  # Integration tests
docs/module-api.md                 # Update API docs
```

**Minimal Module**:
```bash
#!/bin/bash
# Feature: New Feature
# Phase: new-feature
# Dependencies: system-prep

set -euo pipefail

# Source dependencies
source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"
source "${LIB_DIR}/core/rollback.sh"
source "${LIB_DIR}/core/validator.sh"

# Module metadata
readonly NEW_FEATURE_PHASE="new-feature"

# Main installation function
new_feature_install() {
  local phase_name="${NEW_FEATURE_PHASE}"
  
  # 1. Check if already completed
  if checkpoint_exists "$phase_name"; then
    log_info "Phase already completed: $phase_name"
    return 0
  fi
  
  # 2. Validate prerequisites
  if ! _new_feature_validate; then
    log_error "Prerequisites not met for: $phase_name"
    return 1
  fi
  
  # 3. Register rollback handler
  rollback_register_action "_new_feature_rollback"
  
  # 4. Execute installation
  log_info "Starting installation: $phase_name"
  
  # TODO: Implementation
  
  # 5. Verify installation
  if ! _new_feature_verify; then
    log_error "Verification failed: $phase_name"
    return 1
  fi
  
  # 6. Save checkpoint
  checkpoint_save "$phase_name"
  log_info "Completed successfully: $phase_name"
  return 0
}

# Private: Validate prerequisites
_new_feature_validate() {
  # Check dependencies, packages, etc.
  return 0
}

# Private: Verify installation
_new_feature_verify() {
  # Verify feature works correctly
  return 0
}

# Private: Rollback handler
_new_feature_rollback() {
  log_info "Rolling back: ${NEW_FEATURE_PHASE}"
  # Cleanup actions
  return 0
}
```

---

### New Test Template (BATS)

**File**: `tests/unit/test_new_feature.bats`

```bash
#!/usr/bin/env bats
# Unit tests for new-feature module

load '../test_helper'

setup() {
  common_setup
  source "${LIB_DIR}/modules/new-feature.sh"
}

teardown() {
  common_teardown
}

@test "new_feature_install: succeeds with valid prerequisites" {
  # Arrange
  mock_command "required_tool" "success" 0
  
  # Act
  run new_feature_install
  
  # Assert
  assert_success
  assert_output --partial "Completed successfully"
}

@test "new_feature_install: fails when prerequisites missing" {
  # Arrange
  mock_command "required_tool" "" 1
  
  # Act
  run new_feature_install
  
  # Assert
  assert_failure
  assert_output --partial "Prerequisites not met"
}

@test "new_feature_install: idempotent when checkpoint exists" {
  # Arrange
  checkpoint_save "new-feature"
  
  # Act
  run new_feature_install
  
  # Assert
  assert_success
  assert_output --partial "already completed"
}
```

---

### New Python Utility Template

**File**: `lib/utils/new_utility.py`

```python
#!/usr/bin/env python3
"""New utility module.

Detailed description of utility purpose and usage.
"""

import argparse
import logging
import sys
from typing import Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)


class NewUtility:
    """Main utility class."""
    
    def __init__(self, config: Optional[dict] = None) -> None:
        """Initialize utility.
        
        Args:
            config: Optional configuration dictionary
        """
        self.config = config or {}
    
    def execute(self) -> int:
        """Execute utility logic.
        
        Returns:
            Exit code (0 for success)
        """
        try:
            # Implementation
            logger.info("Utility executed successfully")
            return 0
        except Exception as e:
            logger.error(f"Utility failed: {e}")
            return 1


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(description="New utility description")
    parser.add_argument(
        '--config',
        type=str,
        help='Path to configuration file'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )
    
    args = parser.parse_args()
    
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    utility = NewUtility()
    return utility.execute()


if __name__ == "__main__":
    sys.exit(main())
```

**Test File**: `tests/unit/test_new_utility.py`

```python
"""Unit tests for new_utility module."""

import pytest
from lib.utils.new_utility import NewUtility


def test_execute_success():
    """Test successful execution."""
    utility = NewUtility()
    result = utility.execute()
    assert result == 0


def test_execute_with_config():
    """Test execution with custom config."""
    config = {'key': 'value'}
    utility = NewUtility(config=config)
    assert utility.config == config
```

---

## 11. Structure Enforcement

### Validation Tools

| Tool | Purpose | Enforcement |
|------|---------|-------------|
| ShellCheck | Shell script linting | CI blocks on warnings |
| shfmt | Shell formatting | Pre-commit hook |
| flake8 | Python linting | CI blocks on errors |
| black | Python formatting | Pre-commit hook |
| pylint | Python quality | CI reports warnings |
| mypy | Python type checking | CI reports errors |
| codespell | Spell checking | CI reports warnings |
| BATS | Shell testing | CI blocks on failures |
| pytest | Python testing | CI blocks on failures |

### Build Checks

**Pre-commit Hooks** (`.git/hooks/pre-commit`):
- Run unit tests (<30s)
- Lint and format checks
- Spell check

**Pre-push Hooks** (`.git/hooks/pre-push`):
- Run unit + integration tests
- Secret scanning

**CI Pipeline** (GitHub Actions):
```yaml
- Lint shell scripts (shellcheck)
- Format check (shfmt)
- Lint Python (flake8, pylint)
- Format check Python (black)
- Type check Python (mypy)
- Spell check (codespell)
- Unit tests (BATS + pytest)
- Integration tests (BATS)
- Contract tests (BATS)
- Coverage report (pytest-cov)
```

### Linting Rules

**ShellCheck** (`.shellcheckrc` - if needed):
- Must pass with zero warnings
- Only documented suppressions allowed
- Security rules (SC2086, SC2046) enforced

**Python**:
- Max line length: 120
- Ignore: E203 (whitespace before ':'), W503 (line break before binary operator)
- Type hints required for public functions

---

### Documentation Practices

**Required Documentation**:
- Every public function: Inline comments with purpose, parameters, return values
- Every module: Header comment with purpose, dependencies
- Every architectural change: Update `docs/architecture.md`
- Every API change: Update `docs/module-api.md`

**ADR (Architecture Decision Records)**:
- Not currently stored in repo
- Should add: `docs/adr/` for major decisions

---

### Structure Evolution History

**Current Version**: 1.0.0

**Evolution**:
- Initial structure based on spec-driven development (specs/)
- Modular architecture with `lib/core`, `lib/modules` separation
- Test pyramid with BATS + pytest
- Python utilities added for complex operations

**Future Enhancements**:
- Consider ADR directory for decision tracking
- Potential split of `lib/modules/` into domain-based subdirectories if >20 modules
- Consider `lib/models/` expansion for additional schemas

---

## Maintaining This Blueprint

### When to Update

- **File moves**: Update directory visualization
- **New modules**: Add to Key Directory Analysis
- **New patterns**: Document in Naming Conventions
- **Architecture changes**: Update Structural Overview
- **New workflows**: Add to Navigation section

### Update Process

1. Make structural changes
2. Update this blueprint concurrently
3. Validate with `make test`
4. Commit blueprint with changes

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-25 | Initial blueprint generation |

---

**Last Generated**: 2025-12-25 06:10 UTC  
**Generator**: FRIDAY AI Assistant (Antigravity)  
**Blueprint Covers**: VPS-Setup Project v1.0.0  
**Next Review**: After significant structural changes or every quarter
