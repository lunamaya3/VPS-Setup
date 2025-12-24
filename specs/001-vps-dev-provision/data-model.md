# Data Model: VPS Developer Workstation Provisioning

**Date**: December 23, 2025  
**Feature**: [spec.md](spec.md) | [plan.md](plan.md)

## Overview

This document defines the core data structures and their relationships for the VPS provisioning system. The data model focuses on representing system state, tracking provisioning progress, and managing configuration.

---

## Core Entities

### 1. ProvisioningSession

Represents a single execution of the provisioning process.

**Attributes:**
- `session_id`: String - Unique identifier (timestamp-based: YYYYMMDD-HHMMSS)
- `start_time`: ISO 8601 timestamp - When provisioning started
- `end_time`: ISO 8601 timestamp - When provisioning completed/failed (null if in progress)
- `status`: Enum - Current status
  - `INITIALIZING`: Pre-flight checks in progress
  - `IN_PROGRESS`: Active provisioning
  - `COMPLETED`: Successfully finished
  - `FAILED`: Terminated due to error
  - `ROLLED_BACK`: Failed and rollback completed
- `phases`: Array<PhaseExecution> - Execution status of each provisioning phase
- `error_details`: String - Error message if status is FAILED (null otherwise)
- `duration_seconds`: Integer - Total execution time in seconds
- `vps_info`: VPSInstance - Information about target VPS

**Relationships:**
- Has many `PhaseExecution` records
- Has one `VPSInstance`
- Has many `TransactionLog` entries

**Storage**: `/var/vps-provision/sessions/session-<session_id>.json`

**Example:**
```json
{
  "session_id": "20251223-103000",
  "start_time": "2025-12-23T10:30:00Z",
  "end_time": "2025-12-23T10:42:15Z",
  "status": "COMPLETED",
  "duration_seconds": 735,
  "phases": [...],
  "error_details": null,
  "vps_info": {...}
}
```

---

### 2. PhaseExecution

Represents the execution state of a single provisioning phase.

**Attributes:**
- `phase_name`: String - Identifier for phase (e.g., "system-prep", "desktop-install", "rdp-config")
- `status`: Enum - Phase status
  - `PENDING`: Not yet started
  - `RUNNING`: Currently executing
  - `COMPLETED`: Successfully finished
  - `SKIPPED`: Skipped due to checkpoint
  - `FAILED`: Failed with error
- `start_time`: ISO 8601 timestamp - When phase started (null if not started)
- `end_time`: ISO 8601 timestamp - When phase completed (null if not finished)
- `duration_seconds`: Integer - Phase execution time
- `checkpoint_exists`: Boolean - Whether phase was previously completed
- `actions`: Array<ProvisioningAction> - Individual actions within phase
- `error_message`: String - Error details if failed (null otherwise)

**Relationships:**
- Belongs to one `ProvisioningSession`
- Has many `ProvisioningAction` records

**Storage**: Embedded in session JSON file

**Example:**
```json
{
  "phase_name": "desktop-install",
  "status": "COMPLETED",
  "start_time": "2025-12-23T10:32:00Z",
  "end_time": "2025-12-23T10:36:30Z",
  "duration_seconds": 270,
  "checkpoint_exists": false,
  "actions": [
    {
      "action_type": "PACKAGE_INSTALL",
      "target": "task-xfce-desktop",
      "status": "COMPLETED"
    }
  ],
  "error_message": null
}
```

---

### 3. ProvisioningAction

Represents a single action taken during provisioning (package install, file modification, etc.).

**Attributes:**
- `action_type`: Enum - Type of action performed
  - `PACKAGE_INSTALL`: Installing system package
  - `PACKAGE_REMOVE`: Removing system package
  - `FILE_MODIFY`: Modifying configuration file
  - `FILE_CREATE`: Creating new file
  - `SERVICE_ENABLE`: Enabling systemd service
  - `SERVICE_START`: Starting systemd service
  - `USER_CREATE`: Creating user account
  - `USER_MODIFY`: Modifying user account
  - `COMMAND_EXEC`: Executing arbitrary command
- `target`: String - Subject of action (package name, file path, service name, username)
- `status`: Enum - Action result (PENDING, COMPLETED, FAILED)
- `rollback_command`: String - Command to reverse this action
- `timestamp`: ISO 8601 timestamp - When action was performed
- `output`: String - Command output (truncated if lengthy)

**Relationships:**
- Belongs to one `PhaseExecution`

**Storage**: Transaction log file + embedded in session JSON

**Example:**
```json
{
  "action_type": "PACKAGE_INSTALL",
  "target": "xrdp",
  "status": "COMPLETED",
  "rollback_command": "apt-get remove xrdp -y",
  "timestamp": "2025-12-23T10:34:15Z",
  "output": "Setting up xrdp (0.9.22) ...\nProcessing triggers..."
}
```

---

### 4. VPSInstance

Represents the target Virtual Private Server being provisioned.

**Attributes:**
- `hostname`: String - System hostname
- `ip_address`: String - Primary IP address
- `os_name`: String - Operating system name (e.g., "Debian GNU/Linux")
- `os_version`: String - OS version (e.g., "13" for Bookworm)
- `kernel_version`: String - Kernel version string
- `cpu_cores`: Integer - Number of CPU cores
- `ram_mb`: Integer - Total RAM in megabytes
- `disk_space_gb`: Integer - Total disk space in gigabytes
- `disk_available_gb`: Float - Available disk space before provisioning
- `validated`: Boolean - Whether system passes pre-flight checks

**Validation Rules:**
- `os_name` must contain "Debian"
- `os_version` must equal "13"
- `ram_mb` must be >= 2048 (minimum spec)
- `disk_available_gb` must be >= 10 (minimum for installation)

**Storage**: Embedded in session JSON

**Example:**
```json
{
  "hostname": "debian-4gb-fra1-01",
  "ip_address": "143.198.45.123",
  "os_name": "Debian GNU/Linux",
  "os_version": "13",
  "kernel_version": "6.1.0-16-amd64",
  "cpu_cores": 2,
  "ram_mb": 4096,
  "disk_space_gb": 80,
  "disk_available_gb": 75.3,
  "validated": true
}
```

---

### 5. DeveloperUser

Represents the developer user account created during provisioning.

**Attributes:**
- `username`: String - System username (e.g., "devuser")
- `full_name`: String - Full name for display (optional)
- `uid`: Integer - Unix user ID
- `gid`: Integer - Unix group ID
- `home_directory`: String - Home directory path
- `shell`: String - Default shell (e.g., "/bin/bash")
- `groups`: Array<String> - Group memberships
- `password_hash`: String - Hashed password (never store plain text)
- `generated_password`: String - Plain text password displayed once (not persisted)
- `password_expires`: Boolean - Whether password must be changed on first login
- `ssh_key_auth_enabled`: Boolean - Whether SSH key authentication is configured
- `created_at`: ISO 8601 timestamp - When user was created

**Relationships:**
- Belongs to one `ProvisioningSession`

**Security Notes:**
- `generated_password` is displayed in terminal output once and not saved to disk
- `password_hash` is stored in system `/etc/shadow`, not in data model files
- SSH keys copied from root user's authorized_keys if available

**Storage**: Partial data in session JSON (username, groups, timestamps only)

**Example:**
```json
{
  "username": "devuser",
  "full_name": null,
  "uid": 1001,
  "gid": 1001,
  "home_directory": "/home/devuser",
  "shell": "/bin/bash",
  "groups": ["devusers", "sudo", "audio", "video", "dialout", "plugdev"],
  "password_expires": true,
  "ssh_key_auth_enabled": true,
  "created_at": "2025-12-23T10:35:00Z"
}
```

---

### 6. IDEInstallation

Represents an installed IDE with its metadata and status.

**Attributes:**
- `ide_name`: Enum - IDE identifier
  - `VSCODE`: Visual Studio Code
  - `CURSOR`: Cursor IDE
  - `ANTIGRAVITY`: Antigravity IDE
- `version`: String - Installed version string
- `installation_method`: Enum - How IDE was installed
  - `APT_REPOSITORY`: Via APT package manager
  - `DEB_PACKAGE`: Direct .deb file installation
  - `APPIMAGE`: AppImage executable
  - `SNAP`: Snap package (fallback)
- `installation_path`: String - Primary installation directory
- `executable_path`: String - Path to main executable
- `desktop_launcher_path`: String - Path to .desktop file
- `command_name`: String - CLI command to launch (e.g., "code", "cursor")
- `installed_at`: ISO 8601 timestamp - When IDE was installed
- `verified`: Boolean - Whether post-installation verification passed
- `verification_errors`: Array<String> - Error messages if verification failed

**Relationships:**
- Belongs to one `ProvisioningSession`

**Verification Checks:**
- Executable exists and is executable
- Desktop launcher exists and is valid
- Command can be invoked without error
- Required libraries are present (ldd check)

**Storage**: Embedded in session JSON

**Example:**
```json
{
  "ide_name": "VSCODE",
  "version": "1.85.1",
  "installation_method": "APT_REPOSITORY",
  "installation_path": "/usr/share/code",
  "executable_path": "/usr/bin/code",
  "desktop_launcher_path": "/usr/share/applications/code.desktop",
  "command_name": "code",
  "installed_at": "2025-12-23T10:38:45Z",
  "verified": true,
  "verification_errors": []
}
```

---

### 7. TransactionLog

Represents a single transaction entry for rollback purposes.

**Attributes:**
- `sequence_number`: Integer - Order of execution (for LIFO rollback)
- `timestamp`: ISO 8601 timestamp - When transaction occurred
- `action_type`: String - Type of action (matches ProvisioningAction types)
- `target`: String - Subject of action
- `rollback_command`: String - Exact command to reverse action
- `executed`: Boolean - Whether rollback has been executed

**Relationships:**
- Belongs to one `ProvisioningSession`

**Storage**: `/var/log/vps-provision/transaction-<session_id>.log` (line-based format)

**Format Example:**
```
0001 2025-12-23T10:30:15Z PACKAGE_INSTALL xrdp "apt-get remove xrdp -y" false
0002 2025-12-23T10:30:45Z FILE_MODIFY /etc/xrdp/xrdp.ini "cp /var/vps-provision/backups/xrdp.ini /etc/xrdp/xrdp.ini" false
0003 2025-12-23T10:31:00Z SERVICE_ENABLE xrdp "systemctl disable xrdp" false
```

**Rollback Process:**
- Read transaction log in reverse order (highest sequence first)
- Execute each rollback command
- Mark transaction as executed
- Continue until all transactions rolled back

---

### 8. Checkpoint

Represents a phase completion marker for idempotency.

**Attributes:**
- `phase_name`: String - Name of completed phase
- `completed_at`: ISO 8601 timestamp - When phase finished
- `session_id`: String - ID of session that completed phase
- `checksum`: String - Hash of critical files/state (for integrity verification)

**Purpose:**
- Enable fast re-runs by skipping completed phases
- Detect if system state has changed since checkpoint
- Allow resume from failure point

**Storage**: `/var/vps-provision/checkpoints/<phase_name>.done` (touch file)
Plus metadata in `/var/vps-provision/checkpoints/metadata.json`

**Example:**
```json
{
  "phase_name": "desktop-install",
  "completed_at": "2025-12-23T10:36:30Z",
  "session_id": "20251223-103000",
  "checksum": "a1b2c3d4e5f6..."
}
```

---

## Entity Relationships Diagram

```
ProvisioningSession
├── 1:N PhaseExecution
│   └── 1:N ProvisioningAction
├── 1:N TransactionLog
├── 1:1 VPSInstance
├── 1:1 DeveloperUser
├── 1:N IDEInstallation (3 total: VSCode, Cursor, Antigravity)
└── 1:N Checkpoint
```

---

## State Transitions

### ProvisioningSession Status Flow
```
INITIALIZING → IN_PROGRESS → COMPLETED
                ↓
              FAILED → ROLLED_BACK
```

### PhaseExecution Status Flow
```
PENDING → RUNNING → COMPLETED
          ↓         ↑
        FAILED    SKIPPED (if checkpoint exists)
```

### ProvisioningAction Status Flow
```
PENDING → COMPLETED
    ↓
  FAILED
```

---

## Data Persistence Strategy

| Entity | Storage Location | Format | Purpose |
|--------|-----------------|---------|---------|
| ProvisioningSession | `/var/vps-provision/sessions/` | JSON | Session state and results |
| TransactionLog | `/var/vps-provision/transaction-<id>.log` | Text | Rollback commands |
| Checkpoint | `/var/vps-provision/checkpoints/` | Touch file + JSON metadata | Idempotency markers |
| DeveloperUser | System `/etc/passwd`, `/etc/shadow` | Standard | User account |
| IDEInstallation | System package DB + session JSON | Mixed | Installation records |
| Logs | `/var/log/vps-provision/` | Text | Debugging and audit |

---

## Example Complete Session State

```json
{
  "session_id": "20251223-103000",
  "start_time": "2025-12-23T10:30:00Z",
  "end_time": "2025-12-23T10:42:15Z",
  "status": "COMPLETED",
  "duration_seconds": 735,
  "vps_info": {
    "hostname": "debian-4gb-fra1-01",
    "ip_address": "143.198.45.123",
    "os_version": "13",
    "cpu_cores": 2,
    "ram_mb": 4096,
    "validated": true
  },
  "phases": [
    {
      "phase_name": "system-prep",
      "status": "COMPLETED",
      "duration_seconds": 180,
      "actions": [...]
    },
    {
      "phase_name": "desktop-install",
      "status": "COMPLETED",
      "duration_seconds": 270,
      "actions": [...]
    },
    {
      "phase_name": "rdp-config",
      "status": "COMPLETED",
      "duration_seconds": 45,
      "actions": [...]
    },
    {
      "phase_name": "user-creation",
      "status": "COMPLETED",
      "duration_seconds": 30,
      "actions": [...]
    },
    {
      "phase_name": "ide-installations",
      "status": "COMPLETED",
      "duration_seconds": 180,
      "actions": [...]
    },
    {
      "phase_name": "terminal-setup",
      "status": "COMPLETED",
      "duration_seconds": 15,
      "actions": [...]
    },
    {
      "phase_name": "verification",
      "status": "COMPLETED",
      "duration_seconds": 15,
      "actions": [...]
    }
  ],
  "developer_user": {
    "username": "devuser",
    "groups": ["devusers", "sudo", "audio", "video", "dialout", "plugdev"],
    "created_at": "2025-12-23T10:35:00Z"
  },
  "ide_installations": [
    {
      "ide_name": "VSCODE",
      "version": "1.85.1",
      "installation_method": "APT_REPOSITORY",
      "verified": true
    },
    {
      "ide_name": "CURSOR",
      "version": "0.12.0",
      "installation_method": "DEB_PACKAGE",
      "verified": true
    },
    {
      "ide_name": "ANTIGRAVITY",
      "version": "1.4.2",
      "installation_method": "APPIMAGE",
      "verified": true
    }
  ],
  "error_details": null
}
```
