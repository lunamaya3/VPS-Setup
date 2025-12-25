# GitHub Copilot Instructions - VPS Provisioning System

## Priority Guidelines

When generating code for this repository:

1. **Version Compatibility**: Always respect the exact versions of Bash 5.2+ and Python 3.13+ used in this project
2. **Context Files**: Prioritize patterns and standards defined in the `.github/instructions/` directory
3. **Codebase Patterns**: When context files don't provide specific guidance, scan the codebase for established patterns
4. **Architectural Consistency**: Maintain the three-layer modular architecture (Core, Modules, Utilities)
5. **Code Quality**: Prioritize maintainability, security, testability, and performance in all generated code

## Technology Version Detection

Before generating code, adhere to these exact technology versions:

### Language Versions

- **Bash**: 5.2.37+ (GNU bash)
  - Use `set -euo pipefail` in all scripts
  - Never use features beyond Bash 5.2
  - Always use `[[` for conditional tests (not `[`)
  - Prefer `${VAR}` over `$VAR` for variable expansion

- **Python**: 3.13.5
  - Use type hints for all function parameters and return values
  - Use `secrets` module (never `random`) for password generation
  - Follow PEP 8 style guide strictly
  - Use f-strings for string formatting
  - Never use deprecated features from Python 3.12 or earlier

### Framework & Tool Versions

- **BATS (Bash Automated Testing System)**: 1.10.0+
  - Use `setup()` and `teardown()` functions for test isolation
  - Always set `TEST_DIR`, `LOG_DIR`, and `LOG_FILE` BEFORE sourcing modules
  - Source modules with `2>/dev/null || true` to suppress readonly warnings in tests

- **Testing Frameworks**:
  - pytest: 7.4.0+ (Python testing)
  - pytest-cov: 4.1.0+ (Coverage reporting)
  
- **Code Quality Tools**:
  - shellcheck: Latest (Bash linting)
  - pylint: 2.17.0+ (Python linting)
  - black: 23.0.0+ (Python formatting)
  - mypy: 1.0.0+ (Python type checking)

### Library Versions

Key Python dependencies from `requirements.txt`:
- psutil: 5.9.0+ (Process monitoring for lock detection)

## Context Files

Prioritize the following instruction files in `.github/instructions/` directory (when applicable):

- **friday-persona.instructions.md**: Action-first AI assistant behavior (talk less, do more)
- **spec-driven-workflow-v1.instructions.md**: Specification-driven development workflow
- **security-and-owasp.instructions.md**: Security best practices and OWASP guidelines
- **self-explanatory-code-commenting.instructions.md**: Comment only when necessary
- **performance-optimization.instructions.md**: Performance optimization patterns
- **shell.instructions.md**: Shell scripting conventions
- **python.instructions.md**: Python coding standards

## Codebase Scanning Instructions

When context files don't provide specific guidance, analyze these exemplar files:

### Core Library Patterns
- **Module Loading Guard**: `lib/core/logger.sh` (lines 7-11)
- **Transaction Recording**: `lib/core/transaction.sh`
- **Checkpoint System**: `lib/core/checkpoint.sh`
- **Error Handling**: `lib/core/error-handler.sh`

### Module Development Patterns
- **Complete Module Template**: `lib/modules/system-prep.sh`
  - Shows proper dependency sourcing
  - Demonstrates checkpoint usage
  - Includes transaction recording
  - Uses proper logging levels

### Python Utility Patterns
- **Health Check Utility**: `lib/utils/health-check.py`
  - Type hints on all functions
  - Google-style docstrings
  - Tri-state result pattern (pass/fail/error)
  - JSON output support

### Testing Patterns
- **BATS Unit Tests**: `tests/unit/test_logger.bats`
  - Proper setup/teardown with temporary directories
  - Variable initialization before sourcing modules
  - Suppressing readonly warnings in test environment

### CLI Patterns
- **Main Entry Point**: `bin/vps-provision`
  - Argument parsing and validation
  - Phase orchestration
  - Progress reporting

## Architectural Patterns

This project uses a **three-layer modular architecture**:

### Layer 1: Core Library (`lib/core/`)
Foundation libraries providing:
- **logger.sh**: Structured logging (DEBUG/INFO/WARNING/ERROR)
- **checkpoint.sh**: Idempotency via checkpoint markers
- **transaction.sh**: Transaction recording for rollback
- **rollback.sh**: LIFO rollback execution
- **progress.sh**: Real-time progress with ETA
- **validator.sh**: System validation
- **sanitize.sh**: Input sanitization
- **error-handler.sh**: Centralized error handling
- **config.sh**: Configuration management
- **state.sh**: State persistence
- **services.sh**: Service management
- **file-ops.sh**: Safe file operations

**Rules for Core Library:**
- Never add business logic here
- Functions must be pure and testable in isolation
- All functions must support both test and production environments
- Use readonly variables ONLY when not in test environment

### Layer 2: Module Layer (`lib/modules/`)
Business logic modules for provisioning phases:
- **system-prep.sh**: System updates, APT optimization
- **desktop-env.sh**: XFCE desktop installation
- **rdp-server.sh**: xrdp configuration
- **user-provisioning.sh**: Developer user creation
- **ide-*.sh**: IDE installations (VSCode, Cursor, Antigravity)
- **parallel-ide-install.sh**: Parallel IDE installer
- **terminal-setup.sh**: oh-my-bash configuration
- **verification.sh**: Post-install health checks

**Module Pattern (MANDATORY):**
\`\`\`bash
#!/bin/bash
# Module description and purpose

set -euo pipefail

# Prevent multiple sourcing
if [[ -n "\${_MODULE_NAME_SH_LOADED:-}" ]]; then
  return 0
fi
readonly _MODULE_NAME_SH_LOADED=1

# Source dependencies
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="\$(dirname "\${SCRIPT_DIR}")"
source "\${LIB_DIR}/core/logger.sh"
source "\${LIB_DIR}/core/checkpoint.sh"
source "\${LIB_DIR}/core/transaction.sh"

# Module implementation...

module_name_execute() {
  # Check checkpoint
  if checkpoint_exists "module-name"; then
    log_info "Module already executed, skipping..."
    return 0
  fi
  
  # Do work...
  transaction_record "Action description" "rollback_command"
  
  # Create checkpoint
  checkpoint_create "module-name"
}
\`\`\`

### Layer 3: Utility Layer (`lib/utils/`)
Python utilities for complex operations:
- **credential-gen.py**: Cryptographically secure password generation
- **health-check.py**: System health validator (JSON output)
- **session-monitor.py**: RDP session monitoring
- **package-manager.py**: Advanced APT operations

**Python Utility Pattern (MANDATORY):**
\`\`\`python
#!/usr/bin/env python3
"""
Module docstring with usage, options, and purpose
"""

import argparse
from typing import Any, Dict, List, Tuple

class UtilityName:
    """Class docstring"""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
    
    def method_name(self, param: str) -> Dict[str, Any]:
        """
        Method description
        
        Args:
            param: Parameter description
            
        Returns:
            Dictionary with result
        """
        pass
\`\`\`

## Code Quality Standards

### Maintainability

- **Naming Conventions**:
  - Bash functions: `snake_case` (e.g., `system_prep_configure_apt`)
  - Bash constants: `SCREAMING_SNAKE_CASE` (e.g., `LOG_LEVEL_DEBUG`)
  - Python functions: `snake_case` (e.g., `check_os_version`)
  - Python classes: `PascalCase` (e.g., `HealthCheck`)

- **Function Responsibilities**:
  - Keep functions focused on single responsibilities
  - Maximum function length: 50 lines
  - Extract complex logic into helper functions

- **Code Organization**:
  - Group related functionality together
  - Use clear section comments for major blocks
  - Maintain consistent file structure across modules

### Performance

- **Bash Performance**:
  - Use `read -r` for reading input
  - Avoid subshells in loops
  - Use built-in string operations over external tools
  - Cache expensive operations in variables

- **Python Performance**:
  - Use list comprehensions over map/filter
  - Avoid repeated `subprocess` calls
  - Use generators for large data sets

- **System Performance**:
  - Parallel IDE installation (3 concurrent by default)
  - APT parallel downloads (3 concurrent)
  - HTTP pipelining for package downloads

### Security

- **Input Sanitization**:
  - All user inputs must pass through `sanitize.sh`
  - Use `sanitize_username` for usernames
  - Use `sanitize_filepath` for file paths
  - Never trust external input

- **Credential Handling**:
  - Never log passwords or sensitive data
  - Use `[REDACTED]` placeholders in logs
  - Use `secrets` module in Python (never `random`)
  - Store credentials in secure locations only

- **Command Execution**:
  - Always quote variables in bash: `"\${VAR}"`
  - Use arrays for command arguments
  - Validate all paths before file operations
  - Use absolute paths for critical operations

### Testability

- **Unit Testing**:
  - All core library functions must have unit tests
  - Tests must work with temporary directories
  - Mock external dependencies
  - Aim for ≥90% coverage on core libraries

- **Integration Testing**:
  - Test module interactions
  - Test network error handling
  - Test idempotency (re-run safety)
  - Aim for ≥70% coverage on modules

- **Test Structure (BATS)**:
\`\`\`bash
setup() {
  export TEST_DIR="\${BATS_TEST_TMPDIR}/test_name_\$\$"
  export LOG_DIR="\${TEST_DIR}/logs"
  export LOG_FILE="\${LOG_DIR}/test.log"  # MUST set BEFORE sourcing
  mkdir -p "\${LOG_DIR}"
  
  source "\${PROJECT_ROOT}/lib/core/logger.sh" 2>/dev/null || true
}

teardown() {
  if [[ -n "\${TEST_DIR:-}" ]] && [[ -d "\${TEST_DIR}" ]]; then
    rm -rf "\${TEST_DIR}"
  fi
}

@test "descriptive test name" {
  # Arrange
  # Act
  run some_command
  # Assert
  assert_success
  [[ "\$output" =~ "expected" ]]
}
\`\`\`

## Documentation Requirements

### Standard Documentation Level

- **Function Headers (Bash)**:
\`\`\`bash
# Function description
# Args:
#   \$1 - First parameter description
#   \$2 - Second parameter description
# Returns:
#   0 on success, 1 on failure
# Example:
#   system_prep_configure_apt
function_name() {
  # Implementation
}
\`\`\`

- **Function Docstrings (Python)**:
\`\`\`python
def function_name(param1: str, param2: int) -> Dict[str, Any]:
    """
    Brief function description.
    
    Detailed explanation of what the function does and when to use it.
    
    Args:
        param1: Description of first parameter
        param2: Description of second parameter
        
    Returns:
        Dictionary containing result with keys:
            - key1: Description of key1
            - key2: Description of key2
            
    Raises:
        ValueError: When param1 is invalid
        RuntimeError: When operation fails
        
    Example:
        >>> result = function_name("test", 42)
        >>> print(result['key1'])
    """
    pass
\`\`\`

- **Module Headers**:
  - Purpose and responsibility
  - Dependencies
  - Usage examples
  - Configuration options

- **Inline Comments**:
  - Explain WHY, not WHAT
  - Document non-obvious logic
  - Reference requirements or specs
  - Never state the obvious

## Testing Approach

### Unit Testing

- **Test File Naming**: `test_<module_name>.bats` or `test_<module_name>.py`
- **Test Isolation**: Each test uses temporary directories
- **Test Independence**: Tests don't depend on execution order
- **Test Coverage**: Aim for ≥90% on core libraries

**Example BATS Unit Test**:
\`\`\`bash
@test "logger_init creates log directory and files" {
  logger_init "\$LOG_DIR"
  
  [[ -d "\$LOG_DIR" ]]
  [[ -f "\$LOG_FILE" ]]
  [[ -f "\$TRANSACTION_LOG" ]]
}
\`\`\`

### Integration Testing

- **Network Handling**: Test retry logic and timeouts
- **Module Interactions**: Test phase dependencies
- **Idempotency**: Test re-run safety
- **Error Recovery**: Test rollback mechanisms

### End-to-End Testing

- **Full Provisioning**: Test complete workflow on fresh VPS
- **Performance**: Validate ≤15 min provisioning time
- **Validation**: Verify all components are functional
- **RDP Access**: Test remote desktop connectivity

## Technology-Specific Guidelines

### Bash Guidelines

- **Strict Mode**: Always use `set -euo pipefail`
- **Error Handling**: Use trap for cleanup and rollback
- **Quoting**: Always quote variables: `"\${VAR}"`
- **Arrays**: Use arrays for lists, not space-separated strings
- **Subshells**: Avoid in loops, use process substitution instead
- **Portability**: Target Bash 5.2+, avoid bashisms when possible

**Bash Patterns to Follow**:
\`\`\`bash
# Good: Using arrays
files=("file1.txt" "file2.txt" "file3.txt")
for file in "\${files[@]}"; do
  process "\$file"
done

# Good: Proper error handling
if ! command; then
  log_error "Command failed"
  return 1
fi

# Good: Command substitution
result=\$(command)

# Good: Process substitution for loops
while IFS= read -r line; do
  process "\$line"
done < <(generate_lines)
\`\`\`

**Bash Anti-Patterns to Avoid**:
\`\`\`bash
# Bad: Unquoted variables
for file in \$files; do  # DON'T DO THIS

# Bad: Backticks
result=\`command\`  # USE \$() INSTEAD

# Bad: Word splitting
files="file1 file2 file3"  # USE ARRAYS

# Bad: Missing error checks
command  # CHECK RETURN CODE
\`\`\`

### Python Guidelines

- **Type Hints**: Required for all function parameters and return values
- **Docstrings**: Google-style docstrings for all public functions
- **Error Handling**: Use try-except with specific exceptions
- **Imports**: Group by standard library, third-party, local
- **String Formatting**: Use f-strings for Python 3.6+

**Python Patterns to Follow**:
\`\`\`python
# Good: Type hints and docstring
def process_data(input_file: str, verbose: bool = False) -> Dict[str, Any]:
    """
    Process data from input file.
    
    Args:
        input_file: Path to input file
        verbose: Enable verbose output
        
    Returns:
        Dictionary with processed results
    """
    pass

# Good: Specific exception handling
try:
    result = risky_operation()
except ValueError as e:
    log_error(f"Invalid value: {e}")
    raise
except IOError as e:
    log_error(f"IO error: {e}")
    return {}

# Good: F-strings
message = f"Processing {count} items in {duration:.2f} seconds"
\`\`\`

### Configuration Management

- **Default Configuration**: `config/default.conf`
- **User Configuration**: `/etc/vps-provision/default.conf` or `~/.vps-provision.conf`
- **Configuration Format**: Bash-compatible key=value pairs
- **Validation**: All config values must be validated before use

**Configuration Pattern**:
\`\`\`bash
# Load configuration
source "\${CONFIG_DIR}/default.conf"

# Override with user config if exists
if [[ -f /etc/vps-provision/default.conf ]]; then
  source /etc/vps-provision/default.conf
fi

# Validate critical values
if [[ -z "\${DEVELOPER_USERNAME:-}" ]]; then
  log_error "DEVELOPER_USERNAME not set"
  return 1
fi
\`\`\`

## General Best Practices

### Logging Standards

- **Log Levels**:
  - DEBUG: Detailed internal state for debugging
  - INFO: User-visible progress and milestones
  - WARNING: Recoverable issues or degraded functionality
  - ERROR: Fatal errors that prevent completion

**Logging Pattern**:
\`\`\`bash
log_debug "Variable value: \${var}"
log_info "Installing package: nginx"
log_warning "Retrying failed download (attempt 2/3)"
log_error "Failed to install critical package"
\`\`\`

### Transaction & Rollback Pattern

Every state-changing operation must be recorded:

\`\`\`bash
# Record before making changes
transaction_record "Installed nginx" "apt-get remove -y nginx"
transaction_record "Modified /etc/ssh/sshd_config" \\
  "cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config"

# Make the actual change
apt-get install -y nginx
\`\`\`

### Checkpoint Pattern

Every module phase uses checkpoints for idempotency:

\`\`\`bash
function module_execute() {
  # Check if already completed
  if checkpoint_exists "module-phase"; then
    log_info "Phase already completed, skipping..."
    return 0
  fi
  
  # Execute work...
  
  # Mark complete only after success
  checkpoint_create "module-phase"
}
\`\`\`

### Error Handling Pattern

All modules must handle errors gracefully:

\`\`\`bash
# Set error trap
trap 'error_handler \$? "\$BASH_COMMAND" "\${BASH_SOURCE[0]}" "\${LINENO}"' ERR

# Explicit error reporting
if ! critical_operation; then
  error_report "Critical operation failed" "CRITICAL_OP_FAILURE"
  return 1
fi
\`\`\`

## Version Control Guidelines

- **Semantic Versioning**: Use MAJOR.MINOR.PATCH format
- **Changelog**: Update CHANGELOG.md for all user-facing changes
- **Commit Messages**: Use conventional commit format
  - `feat:` for new features
  - `fix:` for bug fixes
  - `docs:` for documentation changes
  - `test:` for test additions/changes
  - `refactor:` for code restructuring
  - `perf:` for performance improvements

## Project-Specific Guidance

### When Adding New Modules

1. Create in `lib/modules/your-module.sh`
2. Follow the module pattern exactly (see Module Layer section)
3. Register phase in `bin/vps-provision` main function
4. Add checkpoint at start and end of execute function
5. Record ALL state changes with `transaction_record`
6. Update phase weights for progress display
7. Add integration test in `tests/integration/test_your_module.bats`
8. Update documentation in `docs/module-api.md`

### When Modifying Core Libraries

1. Ensure backward compatibility
2. Update all dependent modules if API changes
3. Add/update unit tests
4. Test in both production and test environments
5. Update documentation
6. Consider impact on test isolation

### When Adding Python Utilities

1. Place in `lib/utils/` directory
2. Use type hints for all functions
3. Include comprehensive docstrings
4. Add to `requirements.txt` if new dependencies needed
5. Add pytest unit tests in `tests/unit/`
6. Follow exemplar pattern from `health-check.py`

### File Permission Requirements

- **Shell scripts**: 755 (executable)
- **Python scripts**: 755 (executable with shebang)
- **Configuration files**: 644 (readable by all)
- **Log files**: 640 (readable by owner and group)
- **Checkpoint files**: 644 (readable by all)
- **Transaction logs**: 640 (readable by owner and group)

### Critical Architectural Boundaries

- **Core libraries** must not depend on modules
- **Modules** must not depend on other modules directly
- **Utilities** can be used by both core and modules
- **CLI layer** orchestrates modules but contains no business logic
- **Test code** must not be imported into production code

## Anti-Patterns to Avoid

### Bash Anti-Patterns

- ❌ Using `cd` without error checking
- ❌ Parsing `ls` output
- ❌ Using `eval` on untrusted input
- ❌ Ignoring command exit codes
- ❌ Using bare variables in conditionals
- ❌ Modifying readonly variables
- ❌ Using global variables without readonly/export

### Python Anti-Patterns

- ❌ Using `random` for security-critical operations
- ❌ Catching generic `Exception` without re-raising
- ❌ Using mutable default arguments
- ❌ Not closing file handles
- ❌ Using `shell=True` in subprocess
- ❌ Missing type hints on public functions

### Module Anti-Patterns

- ❌ Creating checkpoints before validation
- ❌ Missing rollback commands for state changes
- ❌ Not checking for existing checkpoints
- ❌ Hardcoding paths instead of using variables
- ❌ Mixing business logic with logging
- ❌ Direct module-to-module dependencies

### Testing Anti-Patterns

- ❌ Tests that depend on execution order
- ❌ Tests that modify global state without cleanup
- ❌ Tests that require specific system configuration
- ❌ Setting LOG_FILE after sourcing logger.sh
- ❌ Not suppressing readonly warnings in tests
- ❌ Tests with hardcoded paths

## Quality Checklist

Before submitting code, verify:

- [ ] All shell scripts use `set -euo pipefail`
- [ ] All functions have appropriate headers/docstrings
- [ ] All user inputs are sanitized
- [ ] All state changes have transaction records
- [ ] All phases have checkpoints
- [ ] All errors are logged appropriately
- [ ] Unit tests are added/updated
- [ ] Integration tests pass
- [ ] Documentation is updated
- [ ] No hardcoded credentials or secrets
- [ ] All file operations create backups
- [ ] Performance requirements are met (≤15 min provisioning)

## Summary

When generating code for this VPS provisioning system:

1. **Respect exact versions**: Bash 5.2+, Python 3.13+, BATS 1.10.0+
2. **Follow architectural layers**: Core → Modules → Utilities → CLI
3. **Use established patterns**: Module loading, checkpoints, transactions, rollback
4. **Prioritize quality**: Security, testability, maintainability, performance
5. **Maintain consistency**: Naming, structure, error handling, logging
6. **Test thoroughly**: Unit tests (≥90%), integration tests (≥70%), E2E validation
7. **Document clearly**: Function headers, inline comments for non-obvious logic
8. **Handle errors gracefully**: Transaction rollback, clear error messages

**When in doubt**: Prioritize consistency with existing code over external best practices. Scan the codebase for similar patterns and follow them exactly.
