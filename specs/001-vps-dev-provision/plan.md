# Implementation Plan: VPS Developer Workstation Provisioning

**Branch**: `001-vps-dev-provision` | **Date**: December 23, 2025 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-vps-dev-provision/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

This feature automates the complete provisioning of a fresh Digital Ocean Debian 13 VPS into a fully-functional developer workstation. The system installs a graphical desktop environment with RDP access, three IDEs (VSCode, Cursor, Antigravity), configures a developer user account with passwordless sudo privileges, and sets up terminal enhancements—all through a single command execution completing in under 15 minutes. The provisioning system is idempotent, includes rollback capabilities, and validates all installations before declaring success.

## Technical Context

**Language/Version**: Bash 5.1+ for provisioning orchestration, Python 3.11+ for validation and reporting utilities  
**Primary Dependencies**: 
- Desktop environment (XFCE 4.18 for lightweight performance)
- RDP server (xrdp 0.9.x for standard RDP protocol compatibility)
- Package management (apt/dpkg for Debian package handling)
- Git 2.39+, build-essential, common development utilities
- IDEs: VSCode (latest stable), Cursor (latest), Antigravity (latest available)

**Storage**: 
- Installation logs stored in `/var/log/vps-provision/`
- Configuration backups in `/var/vps-provision/backups/`
- Minimum 25GB disk space required on target VPS

**Testing**: 
- Bash unit tests using bats-core for library functions
- Integration tests on fresh Debian 13 Digital Ocean droplets
- Contract tests for all CLI interfaces using JSON schema validation
- Performance benchmarks measuring complete provisioning time

**Target Platform**: 
- Digital Ocean Debian 13 (Bookworm) VPS instances
- Minimum specs: 2GB RAM, 1 vCPU, 25GB disk
- Recommended: 4GB RAM, 2 vCPU for optimal performance

**Project Type**: Single CLI-based provisioning tool with modular library architecture

**Performance Goals**: 
- Complete provisioning: ≤ 15 minutes on 4GB/2vCPU droplet
- RDP connection ready: immediately after provisioning completes
- IDE launch time: ≤ 10 seconds from click to usable interface
- Idempotent re-run: ≤ 5 minutes for validation-only mode

**Constraints**: 
- Zero manual intervention required (fully automated)
- Idempotent execution (safe to re-run multiple times)
- Complete rollback on failure (restore to clean state)
- Network-dependent (requires stable internet for package downloads)
- Debian 13 specific (validation must reject other OS versions)

**Scale/Scope**: 
- 40 functional requirements across 6 categories
- 12 measurable success criteria
- 9 edge cases to handle gracefully
- 3 target user personas (individual developers, team leads, consultants)
- Support for concurrent multi-user RDP sessions (up to 3 users)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Code Quality Standards
- ✅ **Naming Conventions**: Bash functions use snake_case, Python uses PEP 8 conventions
- ✅ **Function Length**: All functions ≤ 50 lines; provisioning broken into discrete modules
- ✅ **Documentation**: All public functions documented with purpose, parameters, usage examples
- ✅ **Code Reviews**: Review checklist includes standards adherence, test coverage, documentation
- ✅ **Technical Debt**: Tracked in tasks.md with priority classification
- ✅ **Refactoring**: Triggers defined for complexity threshold breaches

### Testing Requirements
- ✅ **Unit Test Coverage**: ≥ 80% for utility functions, ≥ 90% for critical validation logic
- ✅ **Integration Tests**: ≥ 70% coverage for module interactions and provisioning workflows
- ✅ **E2E Tests**: 100% of P1 user journey (one-command setup) validated on real VPS instances
- ✅ **Meaningful Assertions**: All tests validate actual outcomes, not just execution completion
- ✅ **Performance Tests**: Automated timing benchmarks for 15-minute completion target
- ✅ **Load Tests**: Multi-VPS concurrent provisioning validation
- ✅ **TDD Approach**: Tests written first for validation functions, then implementation
- ✅ **CI/CD Integration**: All tests run automatically; deployment blocked on failures

### User Experience Consistency
- ✅ **Consistent Patterns**: CLI follows standard Unix conventions (flags, exit codes, output)
- ✅ **Accessibility**: Terminal-based interface accessible to screen readers via standard output
- ✅ **Error Messaging**: Clear, actionable error messages with suggested remediation steps
- ✅ **Progress Indicators**: Real-time status updates during provisioning process
- ✅ **Content Style**: Help text and messages follow consistent tone and terminology

### Performance Requirements
- ✅ **Execution Time**: Complete provisioning ≤ 15 minutes (P1 requirement)
- ✅ **Resource Utilization**: Monitor memory/CPU during installation to prevent system overload
- ✅ **Network Optimization**: Parallel downloads where safe, retry logic for network failures
- ✅ **Caching Strategy**: Package cache to speed up re-provisioning scenarios
- ✅ **Monitoring**: Log timing for each phase to identify bottlenecks

**Constitution Compliance Status**: ✅ PASS - All requirements aligned with constitutional principles

## Project Structure

### Documentation (this feature)

```text
specs/001-vps-dev-provision/
├── spec.md              # Feature specification
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── cli-interface.json           # Main provisioning CLI contract
│   ├── module-interfaces.json       # Individual module CLI contracts
│   └── validation-interface.json    # Verification and health-check contracts
├── checklists/
│   └── requirements.md  # Quality validation checklist
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
vps-provision/
├── bin/
│   └── vps-provision              # Main entry point executable
├── lib/
│   ├── core/
│   │   ├── logger.sh              # Logging and progress reporting
│   │   ├── validator.sh           # System prerequisite validation
│   │   ├── rollback.sh            # Rollback and error recovery
│   │   └── config.sh              # Configuration management
│   ├── modules/
│   │   ├── system-prep.sh         # System updates and base packages
│   │   ├── desktop-env.sh         # Desktop environment installation
│   │   ├── rdp-server.sh          # RDP server setup and configuration
│   │   ├── user-provisioning.sh   # Developer user account creation
│   │   ├── ide-vscode.sh          # VSCode installation
│   │   ├── ide-cursor.sh          # Cursor IDE installation
│   │   ├── ide-antigravity.sh     # Antigravity IDE installation
│   │   ├── terminal-setup.sh      # Terminal customization
│   │   └── dev-tools.sh           # Git and development utilities
│   └── utils/
│       ├── package-manager.py     # Python utility for package operations
│       ├── credential-gen.py      # Password generation and display
│       └── health-check.py        # Post-installation validation
├── config/
│   ├── default.conf               # Default configuration values
│   └── desktop/
│       └── xfce4-customizations   # Desktop environment presets
├── tests/
│   ├── unit/
│   │   ├── test_validator.bats    # Validator function tests
│   │   ├── test_rollback.bats     # Rollback logic tests
│   │   └── test_utils.py          # Python utility tests
│   ├── integration/
│   │   ├── test_system_prep.bats  # System preparation module tests
│   │   ├── test_desktop_rdp.bats  # Desktop+RDP integration tests
│   │   └── test_ide_install.bats  # IDE installation tests
│   ├── contract/
│   │   └── test_cli_interface.bats # CLI contract validation
│   └── e2e/
│       └── test_full_provision.sh # Complete provisioning workflow test
├── docs/
│   ├── architecture.md            # System architecture overview
│   ├── module-api.md              # Module interface documentation
│   └── troubleshooting.md         # Common issues and solutions
├── Makefile                       # Build and test automation
├── README.md                      # Project overview and quick start
└── .bats-version                  # Test framework version lock
```

**Structure Decision**: Single CLI-based project structure selected because:
1. Provisioning is a single-purpose automation tool without frontend/backend separation
2. Modular library architecture provides reusability within a cohesive codebase
3. Bash as primary language with Python utilities for complex operations aligns with Unix tool philosophy
4. Clear separation between core logic (lib/), tests, and configuration
5. Module-based organization enables selective provisioning and easy maintenance

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitution violations - all requirements align with constitutional principles. No complexity tracking needed.
