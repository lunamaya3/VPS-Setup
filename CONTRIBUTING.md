# Contributing to VPS Developer Workstation Provisioning

> **Thank you for your interest in contributing!** This document provides guidelines for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Environment](#development-environment)
4. [Development Workflow](#development-workflow)
5. [Coding Standards](#coding-standards)
6. [Testing Requirements](#testing-requirements)
7. [Documentation](#documentation)
8. [Pull Request Process](#pull-request-process)
9. [Issue Reporting](#issue-reporting)
10. [Communication](#communication)

## Code of Conduct

### Our Pledge

We pledge to make participation in this project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

**Examples of behavior that contributes to a positive environment**:

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Examples of unacceptable behavior**:

- Use of sexualized language or imagery
- Trolling, insulting/derogatory comments, or personal attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct that could reasonably be considered inappropriate

## Getting Started

### Prerequisites

Before you begin, ensure you have:

- **Debian 13 (Bookworm) VPS** for testing (recommended: Digital Ocean droplet)
- **Git** 2.39+
- **Bash** 5.1+
- **Python** 3.11+
- **BATS** (Bash Automated Testing System)
- **shellcheck** for linting
- **Make** for build automation

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/your-username/vps-provision.git
cd vps-provision
```

3. Add upstream remote:

```bash
git remote add upstream https://github.com/original-org/vps-provision.git
```

## Development Environment

### Installation

Set up your development environment:

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y git build-essential python3 python3-pip shellcheck bats

# Install Python dependencies
pip3 install -r requirements.txt

# Install Git hooks
make hooks

# Run preflight checks
make preflight
```

### Directory Structure

```
vps-provision/
├── bin/                    # Executable scripts
│   ├── vps-provision       # Main CLI
│   ├── preflight-check     # Environment validation
│   └── session-manager.sh  # Session management
├── lib/
│   ├── core/               # Core libraries (12 modules)
│   ├── modules/            # Provisioning modules (15 modules)
│   └── utils/              # Python utilities
├── config/                 # Configuration files
├── docs/                   # Documentation
├── tests/                  # Test suite
│   ├── unit/               # Unit tests (BATS)
│   ├── integration/        # Integration tests (BATS)
│   ├── contract/           # Contract tests (BATS)
│   └── e2e/                # End-to-end tests (Bash)
├── specs/                  # Specifications
│   └── 001-vps-dev-provision/
│       ├── spec.md         # Requirements
│       ├── plan.md         # Technical plan
│       ├── tasks.md        # Task breakdown
│       └── data-model.md   # Data structures
└── Makefile                # Build automation
```

### Environment Variables

Set these for development:

```bash
export LOG_LEVEL=DEBUG              # Enable debug logging
export TEST_MODE=1                  # Enable test mode
export CHECKPOINT_DIR=/tmp/checkpoints  # Use temp checkpoints
export STATE_DIR=/tmp/vps-state    # Use temp state directory
```

## Development Workflow

### 1. Create a Branch

Create a feature branch from `main`:

```bash
git checkout main
git pull upstream main
git checkout -b feature/your-feature-name
```

**Branch Naming Convention**:

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring
- `test/description` - Test additions/improvements

### 2. Make Changes

Follow the [Spec-Driven Workflow](.github/instructions/spec-driven-workflow-v1.instructions.md):

1. **Research**: Understand the problem and existing code
2. **Design**: Plan your changes in relevant spec files
3. **Implement**: Write code following standards
4. **Test**: Write tests before or alongside code (TDD)
5. **Document**: Update docs and inline comments

### 3. Commit Changes

Write clear, descriptive commit messages:

```bash
git add .
git commit -m "feat: Add parallel IDE installation support

- Implement parallel execution for VSCode, Cursor, Antigravity
- Add coordination logic to prevent conflicts
- Update progress reporting for concurrent operations
- Saves ~3 minutes on 4GB/2vCPU systems

Resolves #42"
```

**Commit Message Format**:

```
<type>: <subject>

<body>

<footer>
```

**Types**:

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `refactor` - Code refactoring
- `test` - Adding or updating tests
- `perf` - Performance improvements
- `chore` - Build process or auxiliary tool changes

### 4. Run Tests

Before pushing, ensure all tests pass:

```bash
make test               # All tests
make test-unit          # Fast unit tests
make test-integration   # Integration tests
make test-contract      # Contract tests
```

### 5. Push and Open PR

```bash
git push origin feature/your-feature-name
```

Then open a Pull Request on GitHub.

## Coding Standards

### Bash Style Guide

**Function Naming**:

```bash
# Use snake_case
module_execute() { ... }
check_prerequisites() { ... }

# Prefix module-specific functions
ide_vscode_install() { ... }
desktop_env_configure() { ... }
```

**Variable Naming**:

```bash
# lowercase with underscores
local file_path="/path/to/file"
local user_name="devuser"

# UPPERCASE for constants/environment vars
readonly CHECKPOINT_DIR="/var/vps-provision/checkpoints"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"
```

**Error Handling**:

```bash
# Always use set -euo pipefail
set -euo pipefail

# Check command success
if ! some_command; then
  log_error "Command failed"
  return 1
fi

# Use trap for cleanup
trap 'error_handler $? "$BASH_COMMAND" "${BASH_SOURCE[0]}" "${LINENO}"' ERR
```

**Shellcheck Compliance**:

- Run `shellcheck` on all `.sh` files
- Fix all warnings (SC2086, SC2046, SC2059, etc.)
- Use `# shellcheck disable=SCXXXX` sparingly with justification

### Python Style Guide

Follow **PEP 8**:

```python
# Function names: snake_case
def generate_password(length: int) -> str:
    """Generate a secure random password.

    Args:
        length: Password length in characters

    Returns:
        Securely generated password string
    """
    pass

# Class names: PascalCase
class HealthChecker:
    """Validates system health post-installation."""
    pass

# Constants: UPPER_SNAKE_CASE
MIN_PASSWORD_LENGTH = 16
DEFAULT_TIMEOUT = 30
```

**Type Hints**: Use type hints for all function signatures

**Docstrings**: Use Google-style docstrings

**Linting**: Run `pylint` and aim for score ≥ 9.0

### Shell Script Template

Use this template for new modules:

```bash
#!/bin/bash
# Module: module-name
# Description: One-line description of module purpose
# Dependencies: comma-separated list of prerequisite modules
# Checkpoint: checkpoint-name

set -euo pipefail

# Prevent double-sourcing
if [[ -n "${_MODULE_NAME_LOADED:-}" ]]; then
  return 0
fi
readonly _MODULE_NAME_LOADED=1

# Source dependencies
source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/checkpoint.sh"
source "${LIB_DIR}/core/transaction.sh"

#######################################
# Check if module prerequisites are met
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 if prerequisites met, 1 otherwise
#######################################
module_check_prerequisites() {
  checkpoint_exists "dependency-module" || return 1
  command -v required-command &>/dev/null || return 1
  return 0
}

#######################################
# Execute module provisioning
# Globals:
#   LIB_DIR, CHECKPOINT_DIR
# Arguments:
#   None
# Returns:
#   0 on success, non-zero on failure
#######################################
module_execute() {
  if checkpoint_exists "module-name"; then
    log_info "Module already completed"
    return 0
  fi

  if ! module_check_prerequisites; then
    log_error "Prerequisites not met"
    return 1
  fi

  log_info "Executing module"
  # Implementation here

  checkpoint_create "module-name"
  return 0
}
```

## Testing Requirements

### Test Coverage Targets

- **Unit Tests**: ≥80% coverage for utility functions
- **Integration Tests**: ≥70% coverage for module interactions
- **E2E Tests**: 100% coverage for P1 user journeys
- **Contract Tests**: 100% coverage for public APIs

### Writing Unit Tests

Use **BATS** (Bash Automated Testing System):

```bash
#!/usr/bin/env bats
# tests/unit/test_logger.bats

setup() {
  source lib/core/logger.sh
}

@test "log_info writes to stdout" {
  run log_info "test message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test message" ]]
}

@test "log_error writes to stderr" {
  run log_error "error message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "error message" ]]
}
```

### Writing Integration Tests

Test module interactions:

```bash
#!/usr/bin/env bats
# tests/integration/test_desktop_install.bats

setup() {
  export TEST_MODE=1
  export CHECKPOINT_DIR="/tmp/test-checkpoints"
  mkdir -p "$CHECKPOINT_DIR"
}

teardown() {
  rm -rf "$CHECKPOINT_DIR"
}

@test "desktop-env: requires system-prep checkpoint" {
  source lib/modules/desktop-env.sh

  # Without system-prep checkpoint, should fail
  run desktop_env_check_prerequisites
  [ "$status" -eq 1 ]

  # Create prerequisite checkpoint
  touch "$CHECKPOINT_DIR/system-prep"

  # Now should succeed
  run desktop_env_check_prerequisites
  [ "$status" -eq 0 ]
}
```

### Running Tests

```bash
# All tests
make test

# Specific test file
bats tests/unit/test_logger.bats

# With verbose output
bats -t tests/unit/test_logger.bats

# E2E tests (requires fresh VPS)
sudo tests/e2e/test_full_provision.sh
```

### Test Best Practices

1. **Test one thing**: Each test should validate a single behavior
2. **Descriptive names**: Test names explain what is being tested
3. **Setup/teardown**: Use setup/teardown for test isolation
4. **No side effects**: Tests should not affect each other
5. **Fast execution**: Unit tests should run in milliseconds
6. **Mock external dependencies**: Don't rely on network or external services

## Documentation

### Code Documentation

**Bash Functions**: Use structured comments:

```bash
#######################################
# Brief description of function purpose
# Globals:
#   VAR1 - Description of global used
#   VAR2 - Another global
# Arguments:
#   $1 - Description of first argument
#   $2 - Description of second argument
# Outputs:
#   Writes progress to stdout
# Returns:
#   0 on success, 1 on failure
#######################################
function_name() {
  ...
}
```

**Python Functions**: Use Google-style docstrings:

```python
def function_name(arg1: str, arg2: int) -> bool:
    """Brief description of function.

    Longer description if needed, explaining behavior,
    edge cases, and usage examples.

    Args:
        arg1: Description of first argument
        arg2: Description of second argument

    Returns:
        Boolean indicating success or failure

    Raises:
        ValueError: If arg2 is negative

    Examples:
        >>> function_name("test", 5)
        True
    """
    pass
```

### User Documentation

When adding features, update:

- **README.md**: User-facing features and quick start
- **docs/cli-usage.md**: CLI options and examples
- **docs/troubleshooting.md**: Known issues and solutions
- **docs/architecture.md**: Architectural changes
- **CHANGELOG.md**: Version history

## Pull Request Process

### Before Submitting

Ensure your PR:

- ✅ Passes all tests (`make test`)
- ✅ Passes shellcheck linting
- ✅ Has no merge conflicts with `main`
- ✅ Includes tests for new functionality
- ✅ Updates relevant documentation
- ✅ Follows commit message conventions
- ✅ Has clear PR description

### PR Template

When opening a PR, include:

```markdown
## Description

Brief description of changes

## Related Issue

Fixes #123

## Type of Change

- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change (fix or feature that breaks existing functionality)
- [ ] Documentation update

## Testing

- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] E2E tests pass (if applicable)
- [ ] Manual testing on fresh VPS

## Checklist

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings from linters
- [ ] Tests added/updated
- [ ] All tests pass
```

### Review Process

1. **Automated Checks**: CI runs tests and linters
2. **Code Review**: Maintainers review code quality
3. **Testing**: Changes tested on real VPS
4. **Approval**: At least one maintainer approval required
5. **Merge**: Maintainer merges to `main`

### After Merge

- Your branch will be deleted automatically
- Update your local repository:

```bash
git checkout main
git pull upstream main
git branch -d feature/your-feature-name
```

## Issue Reporting

### Bug Reports

Use the bug report template:

```markdown
**Describe the bug**
Clear description of what the bug is

**To Reproduce**
Steps to reproduce the behavior:

1. Run command '...'
2. See error

**Expected behavior**
What you expected to happen

**Environment**

- VPS Provider: [e.g., Digital Ocean]
- OS Version: [e.g., Debian 13]
- RAM: [e.g., 4GB]
- vCPUs: [e.g., 2]

**Logs**
Attach `/var/log/vps-provision/provision.log`

**Additional context**
Any other relevant information
```

### Feature Requests

Use the feature request template:

```markdown
**Is your feature request related to a problem?**
Description of the problem

**Describe the solution you'd like**
Clear description of desired behavior

**Describe alternatives you've considered**
Other solutions you've thought about

**Additional context**
Screenshots, mockups, or other context
```

## Communication

### Channels

- **GitHub Issues**: Bug reports, feature requests
- **Pull Requests**: Code contributions and reviews
- **Discussions**: General questions and ideas (when enabled)

### Response Times

- Issues: Maintainers aim to respond within 48 hours
- PRs: Initial review within 1 week
- Security issues: Within 24 hours

## Getting Help

Stuck? Here's how to get help:

1. **Read the docs**: Check [docs/](docs/) for guides
2. **Search issues**: Your question may already be answered
3. **Ask in discussions**: General questions welcome
4. **Open an issue**: Specific problems or bugs

## Recognition

Contributors are recognized in:

- **README.md**: Acknowledgments section
- **CHANGELOG.md**: Release notes
- **Git history**: Permanent record of contributions

Thank you for contributing to VPS Developer Workstation Provisioning! 🎉
