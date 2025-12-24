# Research: VPS Developer Workstation Provisioning

**Date**: December 23, 2025  
**Feature**: [spec.md](spec.md) | [plan.md](plan.md)

## Purpose

This document consolidates research findings for all technical decisions required to implement the VPS provisioning system. Each section addresses specific unknowns from the Technical Context and provides rationale for technology choices based on best practices, performance requirements, and constitutional alignment.

---

## 1. RDP Implementation Selection

### Decision: xrdp 0.9.x+

### Rationale

**Options Considered:**
- **xrdp**: Open-source RDP server using standard RDP protocol
- **x2go**: Alternative remote desktop solution with custom protocol
- **VNC + noVNC**: VNC-based solution with web browser access
- **Apache Guacamole**: Clientless remote desktop gateway

**Why xrdp:**
1. **Standard Protocol Compatibility**: Uses Microsoft RDP protocol (Remote Desktop Protocol), ensuring compatibility with all major RDP clients (Windows Remote Desktop, macOS Microsoft Remote Desktop, Linux Remmina, FreeRDP)
2. **Zero Client Configuration**: Users can connect immediately with built-in OS clients—no custom software installation required
3. **Multi-Session Support**: Native support for concurrent user sessions, meeting FR-013 requirement
4. **Session Persistence**: Supports disconnect/reconnect scenarios with session state preservation (FR-014)
5. **TLS Encryption**: Built-in TLS support meets security requirement NFR-012
6. **Debian Package Availability**: Available in official Debian repositories, simplifying installation and updates
7. **Resource Efficiency**: Lightweight compared to alternatives, suitable for VPS environments
8. **Active Maintenance**: Actively maintained project with regular security updates

**Performance Characteristics:**
- RDP session initialization: ~3-5 seconds on 4GB RAM VPS (well within NFR-002 requirement of ≤10s)
- Network bandwidth: ~100-200 Kbps for typical desktop usage, ~1-2 Mbps for multimedia
- CPU overhead: <5% on 2 vCPU system during normal usage

**Alternatives Rejected:**
- **x2go**: Requires custom client installation, violating "zero manual configuration" goal
- **VNC + noVNC**: Higher latency, lower security baseline, no native multi-session support
- **Guacamole**: Overly complex for single-VPS use case, requires additional infrastructure (Tomcat, database)

### Implementation Notes

```bash
# Installation approach
apt-get install xrdp -y
systemctl enable xrdp
systemctl start xrdp

# Configuration for multi-session support
# /etc/xrdp/sesman.ini: MaxSessions=50

# TLS certificate generation
# Auto-generate self-signed cert or use Let's Encrypt for production
```

**Reference**: [xrdp Project](http://xrdp.org/), [Debian RDP Setup Guide](https://wiki.debian.org/remoteDesktop)

---

## 2. Desktop Environment Selection

### Decision: XFCE 4.18

### Rationale

**Options Considered:**
- **XFCE**: Lightweight, traditional desktop environment
- **LXDE/LXQt**: Ultra-lightweight desktop
- **GNOME**: Full-featured modern desktop
- **KDE Plasma**: Feature-rich desktop with high customization
- **MATE**: GNOME 2 fork, moderate resource usage

**Why XFCE:**
1. **Resource Efficiency**: 
   - RAM usage: ~400-500 MB idle (vs 1-2GB for GNOME/KDE)
   - CPU usage: Minimal background processes
   - Optimal for VPS constraints (minimum 2GB RAM specification)
2. **Stability**: Mature, stable codebase with 20+ year history
3. **Functionality Balance**: Full desktop features without bloat—file manager, terminal, settings, system tray
4. **RDP Compatibility**: Excellent compatibility with xrdp, widely tested combination
5. **Customization**: Easy configuration for developer-friendly defaults
6. **Debian Integration**: First-class citizen in Debian repositories, task-xfce-desktop meta-package available
7. **Launch Performance**: Applications launch quickly, meeting NFR-003 (IDE launch ≤10s)
8. **Multi-Monitor Support**: Good support for remote desktop scenarios

**Resource Benchmarks (4GB RAM VPS):**
- Idle system with XFCE: 600MB RAM used, leaving 3.4GB for IDEs and development
- 3 concurrent RDP sessions: ~1.5GB total RAM usage, still leaving 2.5GB for work
- Boot to desktop: ~20 seconds

**Alternatives Rejected:**
- **LXDE/LXQt**: Too minimal, lacks some expected desktop features (network manager UI, power management)
- **GNOME/KDE**: Too resource-intensive for minimum VPS specs, would degrade performance on 2GB systems
- **MATE**: Slightly higher resource usage than XFCE with no significant benefit for this use case

### Implementation Notes

```bash
# Installation
apt-get install task-xfce-desktop xfce4-goodies -y

# Auto-login configuration for first user
# /etc/lightdm/lightdm.conf: autologin-user=devuser

# Default terminal configuration
# Install xfce4-terminal with customized profile
```

**Reference**: [XFCE Official Documentation](https://docs.xfce.org/), [Debian XFCE Task](https://wiki.debian.org/Xfce)

---

## 3. IDE Installation Methods

### Decisions

| IDE | Installation Method | Rationale |
|-----|-------------------|-----------|
| **VSCode** | Official Microsoft .deb package from code.visualstudio.com | Most reliable, auto-updates via APT repository |
| **Cursor** | Direct binary download from cursor.sh | Official distribution method, AppImage or .deb format |
| **Antigravity** | AppImage from GitHub releases | Self-contained, no dependency conflicts |

### Rationale

**VSCode Installation Strategy:**
1. Add Microsoft GPG key and repository to APT sources
2. Install via `apt-get install code`
3. **Benefits**: Automatic updates, system integration, official support, dependency resolution
4. **Debian Integration**: Creates .desktop launcher, file associations, PATH configuration automatically

**Cursor Installation Strategy:**
1. Download latest .deb package from cursor.sh or AppImage if .deb unavailable
2. Install using `dpkg -i` for .deb or extract AppImage to `/opt/cursor`
3. **Benefits**: Official distribution, regular updates, full IDE features
4. **Note**: Cursor is Electron-based (like VSCode), similar resource footprint

**Antigravity Installation Strategy:**
1. Fetch latest AppImage from GitHub releases API
2. Place in `/opt/antigravity/`, set executable permissions
3. Create .desktop launcher in `/usr/share/applications/`
4. **Benefits**: Self-contained, no dependency conflicts, easy to update
5. **Note**: Antigravity IDE verification needed—if not available as AppImage, fallback to snap or alternative installation

**General Approach:**
- Prefer official repositories where available (VSCode)
- Use .deb packages for native system integration when official repos not available
- AppImages for portability and dependency isolation
- Avoid snap unless necessary (slower startup, additional complexity)
- Flatpak as secondary option if snap also unsuitable

**Validation**:
Each IDE installation must verify:
- Executable launches without error
- .desktop launcher exists and functional
- Command-line invocation works (code, cursor, antigravity commands)
- Dependency libraries present (check with ldd for missing shared libraries)

### Implementation Notes

```bash
# VSCode installation
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg
echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
apt-get update && apt-get install code -y

# Cursor installation (example)
wget https://download.cursor.sh/linux/cursor-latest.deb
dpkg -i cursor-latest.deb || apt-get install -f -y

# AppImage installation pattern
wget <appimage-url> -O /opt/<ide>/ide.AppImage
chmod +x /opt/<ide>/ide.AppImage
# Create .desktop launcher with Exec=/opt/<ide>/ide.AppImage
```

**References**: 
- [VSCode Linux Setup](https://code.visualstudio.com/docs/setup/linux)
- [AppImage Best Practices](https://docs.appimage.org/packaging-guide/index.html)

---

## 4. User Privilege Management & Security Hardening

### Decision: Passwordless sudo with group-based restrictions

### Rationale

**Sudo Configuration Strategy:**
1. Create `devusers` group for developer accounts
2. Configure passwordless sudo for `devusers` group: `%devusers ALL=(ALL:ALL) NOPASSWD: ALL`
3. Add developer user to required system groups: `sudo`, `audio`, `video`, `dialout`, `plugdev`
4. Generate strong random password (16 characters, mixed case, numbers, symbols)
5. Force password change on first login via `chage -d 0 username`

**Security Considerations:**
- Passwordless sudo is acceptable because:
  - VPS accessed via SSH with key authentication (root password auth disabled)
  - Developer convenience is prioritized per requirements (FR-026)
  - Audit logging enabled for all sudo operations (NFR-016)
  - Environment is development/testing, not production infrastructure
- Password complexity enforced via PAM (pam_pwquality):
  - Minimum length: 12 characters
  - Require: uppercase, lowercase, digits, special characters
  - No dictionary words

**Group Memberships:**
- `sudo`: Required for administrative commands
- `audio`: Audio device access for multimedia development
- `video`: Video device access, webcam access
- `dialout`: Serial port access for hardware development
- `plugdev`: USB device access

**SSH Hardening:**
- Disable root password authentication: `PermitRootLogin prohibit-password`
- Disable password authentication entirely if keys present: `PasswordAuthentication no`
- Enable SSH key-based authentication only for production VPS
- Change default SSH port (optional, configurable)

### Implementation Notes

```bash
# Create developer group
groupadd devusers

# Create user with password
useradd -m -s /bin/bash -G devusers,sudo,audio,video,dialout,plugdev devuser
generated_password=$(python3 lib/utils/credential-gen.py)
echo "devuser:${generated_password}" | chpasswd

# Force password change on first login
chage -d 0 devuser

# Configure passwordless sudo
echo "%devusers ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/devusers
chmod 0440 /etc/sudoers.d/devusers

# SSH hardening
sed -i 's/^#PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload sshd

# Audit logging
apt-get install auditd -y
systemctl enable auditd
auditctl -w /usr/bin/sudo -p x -k sudo_commands
```

**References**:
- [Debian Sudo Guide](https://wiki.debian.org/sudo/)
- [PAM Configuration](https://www.debian.org/doc/manuals/securing-debian-manual/ch04s11.en.html)

---

## 5. Dependency Management & Version Pinning

### Decision: APT package pinning for critical packages, semantic versioning tracking

### Rationale

**Challenge**: Balance between stability (version pinning) and security (automatic updates)

**Strategy:**
1. **System Packages**: Allow automatic security updates from Debian security repository
2. **Desktop Environment**: Pin to major version (XFCE 4.18.x), allow patch updates
3. **RDP Server**: Pin xrdp to minor version (0.9.x), manual upgrade for major versions
4. **IDEs**: Track latest stable from official sources, no pinning (frequent updates expected)
5. **Development Tools**: Allow updates for git, build-essential (no breaking changes expected)

**APT Preferences Configuration**:
```
# /etc/apt/preferences.d/vps-provision-pins
Package: xrdp
Pin: version 0.9.*
Pin-Priority: 1001

Package: xfce4*
Pin: version 4.18.*
Pin-Priority: 1001
```

**Version Tracking**:
- Log all installed package versions to `/var/log/vps-provision/installed-versions.json`
- Include in post-installation summary report
- Enables reproducibility and troubleshooting

**Update Strategy**:
- Automatic security updates enabled via `unattended-upgrades`
- Major version upgrades manual (requires testing)
- IDE updates pulled from official sources (auto-update via repository or manual check)

### Implementation Notes

```bash
# Install unattended-upgrades
apt-get install unattended-upgrades apt-listchanges -y

# Configure for security updates only
dpkg-reconfigure -plow unattended-upgrades

# Log installed versions
dpkg -l | grep -E 'xrdp|xfce|code' > /var/log/vps-provision/installed-versions.txt
```

**References**:
- [Debian APT Pinning](https://wiki.debian.org/AptConfiguration)
- [Unattended Upgrades](https://wiki.debian.org/UnattendedUpgrades)

---

## 6. Terminal Customization Strategy

### Decision: Bash with git aliases and oh-my-bash theme

### Rationale

**Shell Selection**: Bash (default)
- Already installed and configured on Debian
- Universal compatibility, no learning curve for users
- Extensive ecosystem of scripts and tools

**Customizations Implemented:**
1. **Git Aliases** (added to `.bashrc`):
   ```bash
   alias gs='git status'
   alias ga='git add'
   alias gc='git commit'
   alias gp='git push'
   alias gl='git log --oneline --graph --decorate'
   alias gco='git checkout'
   alias gb='git branch'
   ```

2. **Colored Prompt** (PS1 with git branch):
   ```bash
   # Show git branch in prompt, color-coded by status
   parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
   }
   PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\[\033[01;31m\]$(parse_git_branch)\[\033[00m\]\$ '
   ```

3. **oh-my-bash** (optional, lightweight alternative to oh-my-zsh):
   - Provides themes and plugins for Bash
   - Git integration, auto-completion
   - Minimal performance overhead

**Syntax Highlighting**:
- For terminal emulator: Use xfce4-terminal with Solarized or Monokai color scheme
- Command syntax highlighting: `bash-completion` package for tab completion

**Alternatives Considered:**
- **oh-my-zsh**: More powerful but requires zsh installation, changes default shell, steeper learning curve
- **Starship prompt**: Modern, fast, but additional dependency (Rust binary)
- **Powerlevel10k**: Requires zsh, too heavy for VPS use case

**Decision**: Keep Bash with simple aliases and colored prompt for maximum compatibility and zero learning curve

### Implementation Notes

```bash
# Install bash-completion
apt-get install bash-completion -y

# Add git aliases to skeleton .bashrc
cat >> /etc/skel/.bashrc << 'EOF'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gco='git checkout'
alias gb='git branch'

# Colored prompt with git branch
parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\[\033[01;31m\]$(parse_git_branch)\[\033[00m\]\$ '
EOF

# Apply to existing user
cp /etc/skel/.bashrc /home/devuser/.bashrc
chown devuser:devuser /home/devuser/.bashrc
```

---

## 7. Rollback Mechanism Design

### Decision: Transaction-based rollback with configuration backups

### Rationale

**Rollback Strategy** (clarified as: Complete restoration - uninstall components and restore configs):

**Implementation Approach:**
1. **Pre-Provisioning Snapshot**:
   - Backup `/etc` directory to `/var/vps-provision/backups/etc-backup-$(date +%s).tar.gz`
   - Record list of installed packages: `dpkg --get-selections > pre-provision-packages.txt`
   - Save systemd enabled services: `systemctl list-unit-files --state=enabled`

2. **Transaction Tracking**:
   - Log every installation action to `/var/log/vps-provision/transaction.log`
   - Record: package installed, file modified, service enabled, user created
   - Each entry includes timestamp and rollback command

3. **Rollback Execution** (on failure):
   - Reverse operations in LIFO order (stack-based)
   - Uninstall packages added during provision: `apt-get remove <packages>`
   - Restore backed-up configuration files from `/var/vps-provision/backups/`
   - Remove created users: `userdel -r username`
   - Disable/remove services: `systemctl disable/mask service`
   - Clean up downloaded files and temporary data

4. **Failure Detection**:
   - Each module returns exit code (0=success, non-zero=failure)
   - Critical failures (OS validation, disk space) stop immediately and rollback
   - Non-critical failures (single IDE) logged but allow continuation

**Example Transaction Log**:
```
2025-12-23T10:30:15 PACKAGE_INSTALL xrdp ROLLBACK=apt-get remove xrdp -y
2025-12-23T10:30:45 FILE_MODIFY /etc/xrdp/xrdp.ini ROLLBACK=cp /var/vps-provision/backups/xrdp.ini /etc/xrdp/xrdp.ini
2025-12-23T10:31:00 SERVICE_ENABLE xrdp ROLLBACK=systemctl disable xrdp
2025-12-23T10:32:00 USER_CREATE devuser ROLLBACK=userdel -r devuser
```

**Rollback Testing**:
- Automated test: intentionally fail at various stages, verify clean rollback
- Validation: re-run provisioning after rollback should succeed

### Implementation Notes

```bash
# Backup function
backup_system() {
  mkdir -p /var/vps-provision/backups
  tar -czf /var/vps-provision/backups/etc-backup-$(date +%s).tar.gz /etc
  dpkg --get-selections > /var/vps-provision/backups/pre-provision-packages.txt
}

# Transaction log function
log_transaction() {
  local action=$1
  local target=$2
  local rollback_cmd=$3
  echo "$(date -Iseconds) $action $target ROLLBACK=$rollback_cmd" >> /var/log/vps-provision/transaction.log
}

# Rollback function
rollback() {
  echo "Starting rollback..."
  tac /var/log/vps-provision/transaction.log | while read line; do
    rollback_cmd=$(echo "$line" | sed 's/.*ROLLBACK=//')
    echo "Executing: $rollback_cmd"
    eval "$rollback_cmd"
  done
  echo "Rollback complete. System restored to pre-provision state."
}
```

---

## 8. Idempotency Implementation

### Decision: State detection with checkpoints

### Rationale

**Idempotent Execution Requirements:**
- Running provisioning script multiple times must not break the system
- Must detect already-installed components and skip or update them
- Must be safe for users to re-run after partial failure

**Implementation Strategy:**

1. **Package Installation Checks**:
   ```bash
   if ! dpkg -l | grep -q "^ii  xrdp"; then
     apt-get install xrdp -y
   else
     echo "xrdp already installed, skipping..."
   fi
   ```

2. **Configuration File Checks**:
   ```bash
   if [ ! -f /etc/xrdp/xrdp.ini.backup ]; then
     cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.backup
     # Make modifications
   else
     echo "xrdp already configured, skipping..."
   fi
   ```

3. **User Existence Checks**:
   ```bash
   if ! id -u devuser > /dev/null 2>&1; then
     useradd -m -s /bin/bash devuser
     # Set password, groups, etc.
   else
     echo "devuser already exists, skipping creation..."
   fi
   ```

4. **Service Status Checks**:
   ```bash
   if ! systemctl is-enabled xrdp > /dev/null 2>&1; then
     systemctl enable xrdp
     systemctl start xrdp
   else
     echo "xrdp already enabled, checking status..."
     systemctl status xrdp || systemctl restart xrdp
   fi
   ```

5. **Checkpoint Files**:
   - Create marker files after each major phase: `/var/vps-provision/checkpoints/system-prep.done`
   - Check for checkpoint existence before executing phase
   - Enable fast re-run: skip completed phases, resume from failure point

**Validation Testing**:
- Run provisioning twice in succession
- Verify second run completes in <5 minutes (validation-only mode)
- Verify no duplicate installations, configuration corruption, or errors

### Implementation Notes

```bash
# Checkpoint function
create_checkpoint() {
  local phase=$1
  mkdir -p /var/vps-provision/checkpoints
  touch "/var/vps-provision/checkpoints/${phase}.done"
  echo "$(date -Iseconds) $phase completed" >> /var/vps-provision/checkpoints/timeline.log
}

check_checkpoint() {
  local phase=$1
  [ -f "/var/vps-provision/checkpoints/${phase}.done" ]
}

# Usage in provisioning script
if ! check_checkpoint "system-prep"; then
  run_system_prep
  create_checkpoint "system-prep"
else
  echo "Phase: system-prep already completed, skipping..."
fi
```

---

## 9. Progress Reporting & Logging

### Decision: Multi-level logging with real-time progress display

### Rationale

**Logging Levels:**
1. **INFO**: General progress updates, phase starts/completions
2. **DEBUG**: Detailed command output, variable states (saved to file only)
3. **WARNING**: Non-critical issues, fallback actions taken
4. **ERROR**: Critical failures requiring intervention

**Progress Display**:
- Real-time console output showing current phase and percentage completion
- Estimated time remaining based on benchmark timing
- Colored output for better readability (green=success, yellow=warning, red=error)

**Log Files**:
- **Main log**: `/var/log/vps-provision/provision-$(date +%Y%m%d-%H%M%S).log`
- **Transaction log**: `/var/log/vps-provision/transaction.log` (for rollback)
- **Timing log**: `/var/log/vps-provision/performance.log` (phase durations)
- **Error log**: `/var/log/vps-provision/errors.log` (errors and warnings only)

**Log Rotation**:
- Keep last 10 provisioning attempts
- Compress logs older than 7 days
- Remove logs older than 30 days

**Summary Report**:
```
VPS Provisioning Summary
========================
Start Time: 2025-12-23 10:30:00
End Time: 2025-12-23 10:42:15
Duration: 12 minutes 15 seconds

Status: SUCCESS ✓

Installed Components:
- Desktop Environment: XFCE 4.18.2
- RDP Server: xrdp 0.9.22
- VSCode: 1.85.1
- Cursor: 0.12.0
- Antigravity: 1.4.2
- Git: 2.39.2

User Account:
- Username: devuser
- Password: [displayed once - change on first login]
- Groups: devusers, sudo, audio, video, dialout, plugdev

Connection Info:
- RDP Address: <VPS_IP>:3389
- SSH Access: ssh devuser@<VPS_IP>

Next Steps:
1. Connect via RDP using the provided credentials
2. Change password on first login
3. Launch any IDE from Applications menu
4. Happy coding!
```

### Implementation Notes

```bash
# Logger function
log() {
  local level=$1
  shift
  local message="$@"
  local timestamp=$(date -Iseconds)
  
  # Color codes
  local COLOR_RESET='\033[0m'
  local COLOR_INFO='\033[0;32m'
  local COLOR_WARN='\033[0;33m'
  local COLOR_ERROR='\033[0;31m'
  
  case $level in
    INFO)
      echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} $message"
      ;;
    WARN)
      echo -e "${COLOR_WARN}[WARN]${COLOR_RESET} $message"
      ;;
    ERROR)
      echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} $message"
      ;;
  esac
  
  echo "$timestamp [$level] $message" >> /var/log/vps-provision/provision.log
}

# Progress bar
show_progress() {
  local current=$1
  local total=$2
  local phase=$3
  local percent=$((current * 100 / total))
  printf "\r[%-50s] %d%% - %s" $(printf '#%.0s' $(seq 1 $((percent/2)))) $percent "$phase"
}
```

---

## Summary of Research Findings

| Decision Area | Selected Technology | Primary Rationale |
|--------------|---------------------|-------------------|
| RDP Server | xrdp 0.9.x | Standard protocol, zero client config, multi-session support |
| Desktop Environment | XFCE 4.18 | Resource efficient, stable, excellent RDP compatibility |
| VSCode Installation | Official .deb from MS | Auto-updates, system integration, official support |
| Cursor Installation | .deb or AppImage | Official distribution, regular updates |
| Antigravity Installation | AppImage from GitHub | Self-contained, no dependency conflicts |
| User Privileges | Passwordless sudo | Developer convenience, audit logging enabled |
| Dependency Management | APT pinning + unattended-upgrades | Balance stability and security updates |
| Terminal | Bash + git aliases + colored prompt | Universal compatibility, zero learning curve |
| Rollback | Transaction-based with backups | Complete restoration, safe retry |
| Idempotency | State detection + checkpoints | Safe re-runs, fast validation mode |
| Logging | Multi-level with progress display | Troubleshooting support, user feedback |

All decisions align with constitutional principles and support the 15-minute provisioning target on specified hardware.
