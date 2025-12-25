# Copilot Instructions for VPS Provisioning System

## Overview

This directory contains comprehensive instructions for GitHub Copilot to generate code that is consistent with the VPS Provisioning System's architecture, patterns, and standards.

## Generated File

### `copilot-instructions.md` (709 lines, 21KB)

A comprehensive guide for GitHub Copilot that includes:

#### 1. **Technology Version Detection**
- Bash 5.2.37+ specific patterns and constraints
- Python 3.13.5 requirements and modern features
- BATS 1.10.0+ testing framework patterns
- All tool versions from requirements.txt

#### 2. **Three-Layer Architecture**
- **Core Library Layer** (`lib/core/`): Foundation libraries (logger, checkpoint, transaction, rollback, etc.)
- **Module Layer** (`lib/modules/`): Business logic for provisioning phases
- **Utility Layer** (`lib/utils/`): Python utilities for complex operations

#### 3. **Mandatory Patterns**
- **Module Loading Guard**: Prevents double-sourcing and readonly variable conflicts
- **Checkpoint Pattern**: Enables idempotent re-runs
- **Transaction Recording**: Supports automatic rollback on failures
- **Error Handling**: Centralized error handling with proper traps

#### 4. **Code Quality Standards**
- **Maintainability**: Naming conventions, function responsibilities, code organization
- **Performance**: Bash and Python optimizations, parallel processing patterns
- **Security**: Input sanitization, credential handling, command execution safety
- **Testability**: Unit testing patterns, integration testing, test isolation

#### 5. **Testing Approach**
- **Unit Tests**: ≥90% coverage on core libraries, BATS patterns with proper setup/teardown
- **Integration Tests**: ≥70% coverage on modules, testing module interactions
- **E2E Tests**: Full provisioning validation on fresh VPS

#### 6. **Technology-Specific Guidelines**
- **Bash**: Strict mode, error handling, quoting, arrays, process substitution
- **Python**: Type hints, docstrings, exception handling, f-strings
- **Configuration Management**: Config loading and validation patterns

#### 7. **Anti-Patterns to Avoid**
Explicit list of what NOT to do in:
- Bash scripting
- Python coding
- Module development
- Testing

#### 8. **Project-Specific Guidance**
Step-by-step instructions for:
- Adding new modules
- Modifying core libraries
- Adding Python utilities
- File permissions
- Architectural boundaries

## How Copilot Uses These Instructions

When GitHub Copilot generates code for this repository, it will:

1. **Check exact versions** of Bash and Python in use
2. **Reference instruction files** in `.github/instructions/` directory
3. **Scan exemplar files** for established patterns:
   - `lib/core/logger.sh` for module loading guards
   - `lib/modules/system-prep.sh` for complete module template
   - `lib/utils/health-check.py` for Python utility patterns
   - `tests/unit/test_logger.bats` for BATS testing patterns
4. **Follow architectural layers** strictly
5. **Prioritize consistency** with existing code over external best practices

## Key Benefits

✅ **Version Compatibility**: Never generates code with incompatible features  
✅ **Pattern Consistency**: All generated code follows established patterns  
✅ **Security First**: Built-in input sanitization and credential handling  
✅ **Test Coverage**: Automatic test generation following project patterns  
✅ **Documentation**: Proper headers and docstrings in generated code  
✅ **Quality Assurance**: Code follows all quality standards automatically

## Generated According to Blueprint

This file was generated following the **Copilot Instructions Blueprint Generator** specification:
- Technology-agnostic approach adapted for Bash/Python project
- Based on actual codebase analysis (not assumptions)
- All patterns extracted from existing exemplar files
- Version information from actual project files
- Architectural patterns from real implementation

## Maintenance

When project patterns or versions change:

1. Update this file to reflect new patterns
2. Add new exemplar references when introducing new patterns
3. Update version numbers when dependencies are upgraded
4. Expand anti-patterns section based on code review findings

## Related Files

- `.github/instructions/`: General coding standards and best practices
- `CONTRIBUTING.md`: Contribution guidelines and development workflow
- `specs/001-vps-dev-provision/`: Complete requirements and specifications
- `README.md`: Project overview and quick start guide
