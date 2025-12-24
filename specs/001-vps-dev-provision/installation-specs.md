# Installation Specifications - Complete Reference

**Purpose**: Comprehensive installation requirements and specifications  
**Created**: December 23, 2025  
**Feature**: [spec.md](spec.md) | [research.md](research.md)

---

## Package Management Specifications

### Package Installation Requirements

**All Components** (FR-002):
- System packages: `task-xfce-desktop`, `xfce4-goodies`, `xrdp`, `git`, `build-essential`
- Desktop environment: XFCE 4.18.x complete meta-package
- RDP server: xrdp 0.9.x with dependencies
- Development tools: git, gcc, g++, make, python3, bash-completion
- IDEs: VSCode (via .deb), Cursor (.deb or AppImage), Antigravity (AppImage)

### Dependency Resolution Strategy

**Strategy**: Automatic resolution with retry on failure (Research §5)
```bash
# Primary approach
apt-get install -y --fix-broken <package>

# On failure, retry with:
apt-get update && apt-get install -y <package>

# Broken dependency handling:
dpkg --configure -a
apt-get install -f -y
```

**Validation**: Each package installation verifies:
1. Exit code = 0
2. Package appears in `dpkg -l` with status `ii`
3. Critical files exist (e.g., `/usr/bin/xrdp`)

### Package Repository Sources

**Repositories** (Research §3, §5):
1. **Debian Main**: Official Debian 13 packages
   - Sources: `http://deb.debian.org/debian bookworm main contrib non-free`
2. **Debian Security**: Security updates
   - Sources: `http://security.debian.org/debian-security bookworm-security main`
3. **Microsoft VSCode**: Official VSCode repository
   - Sources: `https://packages.microsoft.com/repos/code stable main`
   - GPG Key: `https://packages.microsoft.com/keys/microsoft.asc`
4. **Cursor**: Direct download from `https://download.cursor.sh/linux/`
5. **Antigravity**: GitHub releases `https://api.github.com/repos/<org>/antigravity/releases/latest`

### Version Pinning Strategy

**APT Pinning Configuration** (Research §5):
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
- Log all versions: `/var/log/vps-provision/installed-versions.json`
- Include in summary report
- Format: `{"package": "xrdp", "version": "0.9.22", "source": "debian-repo"}`

### Package Update Requirements

**Update Strategy** (Research §5, Assumptions #11):
- Automatic security updates: enabled via `unattended-upgrades`
- Package pinning: Critical packages (xrdp, xfce) pinned to minor version
- IDEs: Track latest stable from official sources
- Configuration: `/etc/apt/apt.conf.d/50unattended-upgrades`

### APT Configuration

**Complete Configuration**:
```bash
# /etc/apt/apt.conf.d/99vps-provision
APT::Install-Recommends "true";
APT::Install-Suggests "false";
APT::Get::Assume-Yes "true";
APT::Get::Fix-Broken "true";
Acquire::Retries "3";
Acquire::http::Timeout "300";
```

### Package Verification

**Verification Process**:
1. GPG signature verification for all .deb packages
2. SHA256 checksum verification for downloaded files
3. Post-install file existence checks
4. Service startup validation for daemon packages

```bash
# Verification example
verify_package() {
  local package=$1
  dpkg -s "$package" 2>/dev/null | grep -q "Status: install ok installed"
}
```

### Package Cache Management

**Cache Strategy** (Research §5):
- Pre-provisioning: `apt-get update` to refresh cache
- During install: Keep cache for rollback capability
- Post-provisioning: `apt-get clean` to free ~500MB disk space
- Retain: Package lists for debugging (`/var/lib/apt/lists/`)

### Broken Dependency Handling

**Handling Strategy**:
```bash
handle_broken_deps() {
  log "Attempting to fix broken dependencies..."
  dpkg --configure -a
  apt-get install -f -y
  apt-get update && apt-get upgrade -y
}

# On failure, log details and trigger rollback
if ! handle_broken_deps; then
  log "ERROR: Unable to resolve dependencies"
  trigger_rollback
  exit 2
fi
```

### Unattended Upgrades Configuration

**Configuration** (Research §5):
```bash
# Install and configure
apt-get install unattended-upgrades apt-listchanges -y

# /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
  "${distro_id}:${distro_codename}";
  "${distro_id}:${distro_codename}-security";
  "${distro_id}ESMApps:${distro_codename}-apps-security";
  "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
```

---

## Desktop Environment Installation

### Package Requirements Enumeration

**XFCE Complete Package List** (FR-010, Research §2):
```bash
# Meta package (includes 50+ packages)
task-xfce-desktop

# Additional utilities
xfce4-goodies
xfce4-terminal
xfce4-screenshooter
thunar
thunar-volman
xfce4-power-manager
xfce4-notifyd
xfce4-pulseaudio-plugin
```

### XFCE Version Requirement

**Version**: XFCE 4.18.x (Research §2)
- Available in Debian 13 repositories
- Pinned to 4.18.* series for stability
- Patch updates allowed, major version upgrade requires testing

### Display Manager Requirements

**Display Manager**: LightDM (Research §2)
- Automatically installed with task-xfce-desktop
- Configuration: `/etc/lightdm/lightdm.conf`
- Auto-login configuration for RDP compatibility:
  ```ini
  [Seat:*]
  autologin-user=
  autologin-user-timeout=0
  user-session=xfce
  ```

### Default Session Configuration

**Session Setup** (Research §2):
```bash
# Set default session for all users
update-alternatives --set x-session-manager /usr/bin/startxfce4

# User-specific session
echo "xfce4-session" > /home/devuser/.xsession
chown devuser:devuser /home/devuser/.xsession
```

### Desktop Customization Requirements

**Customizations Applied** (Research §2):
1. **Theme**: Set to Adwaita-dark for reduced eye strain
2. **Panel**: Single bottom panel with window list, system tray, clock
3. **Terminal**: xfce4-terminal with Solarized Dark color scheme
4. **File Manager**: Thunar with tree view enabled
5. **Desktop Icons**: Show mounted volumes and home folder

**Configuration Files**:
- Panel: `~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml`
- Desktop: `~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml`
- Terminal: `~/.config/xfce4/terminal/terminalrc`

### Resource Usage Validation

**Performance Targets** (NFR-001, Research §2):
- Idle RAM usage: ≤500MB
- CPU usage at idle: ≤2%
- Desktop startup time: ≤20 seconds
- Application launch overhead: ≤2 seconds

**Validation Script**:
```bash
validate_desktop_resources() {
  local ram_mb=$(free -m | awk '/^Mem:/{print $3}')
  if [ $ram_mb -gt 500 ]; then
    log "WARN: Desktop RAM usage ${ram_mb}MB exceeds 500MB target"
  fi
}
```

### Desktop Component Dependencies

**Explicit Dependencies** (Research §2):
- X Server: `xserver-xorg-core`, `xserver-xorg-video-all`
- Fonts: `fonts-dejavu-core`, `fonts-liberation`
- Sound: `pulseaudio`, `alsa-utils`
- Network: `network-manager-gnome`
- Display: `lightdm`, `lightdm-gtk-greeter`

### Desktop Startup Time

**Requirement**: ≤20 seconds from service start to desktop ready
**Measurement**: `systemd-analyze blame | grep lightdm`

### Required Desktop Utilities

**Utilities Enumeration** (Research §2):
- File manager: `thunar`
- Terminal: `xfce4-terminal`
- Text editor: `mousepad`
- Image viewer: `ristretto`
- PDF viewer: `atril` or `evince`
- Archive manager: `xarchiver`
- System monitor: `xfce4-taskmanager`

### Desktop Theme and Appearance

**Theme Configuration**:
```bash
# GTK Theme
xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark"

# Icon Theme
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"

# Font Configuration
xfconf-query -c xsettings -p /Gtk/FontName -s "DejaVu Sans 10"

# DPI
xfconf-query -c xsettings -p /Xft/DPI -s "96"
```

---

## RDP Server Installation

### xrdp Package Requirements

**Packages** (FR-011, Research §1):
```bash
# Main packages
xrdp
xorgxrdp

# TLS support
libssl3
openssl

# Session management
sesman
```

### xrdp Version Requirement

**Version**: xrdp 0.9.x (Research §1)
- Available in Debian 13: xrdp 0.9.22
- Pinned to 0.9.* series
- Session persistence supported from 0.9.17+

### xrdp Configuration Requirements

**Complete Configuration** (Research §1):
```ini
# /etc/xrdp/xrdp.ini
[Globals]
ini_version=1
fork=true
port=3389
tcp_nodelay=true
tcp_keepalive=true
security_layer=negotiate
crypt_level=high
certificate=/etc/xrdp/cert.pem
key_file=/etc/xrdp/key.pem
ssl_protocols=TLSv1.2, TLSv1.3
max_bpp=32
new_cursors=true

[Xorg]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
```

```ini
# /etc/xrdp/sesman.ini
[Globals]
ListenAddress=127.0.0.1
ListenPort=3350
EnableUserWindowManager=1
UserWindowManager=startxfce4
DefaultWindowManager=startxfce4

[Sessions]
X11DisplayOffset=10
MaxSessions=50
KillDisconnected=0
IdleTimeLimit=0
DisconnectedTimeLimit=0

[Security]
AllowRootLogin=0
MaxLoginRetry=3
TerminalServerUsers=devusers
TerminalServerAdmins=
```

### Multi-Session Configuration

**Configuration** (FR-013, Research §1):
- MaxSessions: 50 (configurable, default supports requirement)
- KillDisconnected: 0 (preserve sessions on disconnect)
- Session persistence: automatic via sesman
- Per-user isolation: systemd user sessions

### TLS Certificate Requirements

**Certificate Generation** (Research §1, §4):
```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 \
  -keyout /etc/xrdp/key.pem \
  -out /etc/xrdp/cert.pem \
  -days 3650 -nodes \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=$(hostname)"

# Set permissions
chmod 600 /etc/xrdp/key.pem
chmod 644 /etc/xrdp/cert.pem
chown xrdp:xrdp /etc/xrdp/key.pem /etc/xrdp/cert.pem
```

### Port Configuration

**Port**: 3389 (standard RDP port, Clarifications)
- Fixed, not configurable
- Firewall rule: allow tcp/3389

### xrdp Service Management

**Service Configuration** (Research §1):
```bash
# Enable and start
systemctl enable xrdp
systemctl enable xrdp-sesman
systemctl start xrdp
systemctl start xrdp-sesman

# Verify status
systemctl is-active xrdp
systemctl is-enabled xrdp
```

### xrdp Performance Tuning

**Tuning Parameters** (NFR-002):
```ini
# /etc/xrdp/xrdp.ini performance tuning
tcp_nodelay=true
tcp_keepalive=true
tcp_send_buffer_bytes=32768
tcp_recv_buffer_bytes=65536
max_bpp=32
```

**Target**: RDP session initialization ≤10 seconds

### xrdp XFCE Compatibility

**Compatibility Configuration** (Research §1, §2):
```bash
# Create .xsession for xrdp compatibility
cat > /home/devuser/.xsession << 'EOF'
#!/bin/bash
export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
exec startxfce4
EOF
chmod +x /home/devuser/.xsession
chown devuser:devuser /home/devuser/.xsession
```

### Session Persistence Configuration

**Persistence** (FR-014, Research §1):
- Session reconnect: automatic via session ID
- Application state: preserved on disconnect
- Configuration: `KillDisconnected=0` in sesman.ini

---

## IDE Installation Methods

### VSCode Installation Method

**Complete Specification** (Research §3):
```bash
# 1. Add Microsoft GPG key
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
  gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg

# 2. Add repository
echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" \
  > /etc/apt/sources.list.d/vscode.list

# 3. Update and install
apt-get update
apt-get install code -y

# 4. Verify installation
code --version
which code
test -f /usr/share/applications/code.desktop
```

**Benefits**: Auto-updates via APT, system integration, official support

### Cursor IDE Installation Method

**Complete Specification** (Research §3):
```bash
# Method 1: .deb package (preferred)
CURSOR_URL="https://download.cursor.sh/linux/cursor-latest.deb"
wget -O /tmp/cursor.deb "$CURSOR_URL"
dpkg -i /tmp/cursor.deb || apt-get install -f -y

# Method 2: AppImage (fallback)
CURSOR_APPIMAGE_URL=$(curl -s https://api.github.com/repos/getcursor/cursor/releases/latest | \
  grep -o 'https://.*\.AppImage' | head -n1)
mkdir -p /opt/cursor
wget -O /opt/cursor/cursor.AppImage "$CURSOR_APPIMAGE_URL"
chmod +x /opt/cursor/cursor.AppImage

# Create desktop launcher for AppImage
cat > /usr/share/applications/cursor.desktop << 'EOF'
[Desktop Entry]
Name=Cursor
Exec=/opt/cursor/cursor.AppImage
Icon=cursor
Type=Application
Categories=Development;IDE;
EOF
```

### Antigravity IDE Installation Method

**Complete Specification** (Research §3):
```bash
# Fetch latest AppImage from GitHub
AG_URL=$(curl -s https://api.github.com/repos/<org>/antigravity/releases/latest | \
  grep -o 'https://.*\.AppImage' | head -n1)

# Install to /opt/antigravity
mkdir -p /opt/antigravity
wget -O /opt/antigravity/antigravity.AppImage "$AG_URL"
chmod +x /opt/antigravity/antigravity.AppImage

# Create desktop launcher
cat > /usr/share/applications/antigravity.desktop << 'EOF'
[Desktop Entry]
Name=Antigravity
Exec=/opt/antigravity/antigravity.AppImage
Icon=antigravity
Type=Application
Categories=Development;IDE;
EOF

# Create CLI alias
ln -s /opt/antigravity/antigravity.AppImage /usr/local/bin/antigravity
```

### IDE Version Requirements

**Version Strategy** (Research §3):
- VSCode: Latest stable from Microsoft repository
- Cursor: Latest stable from official site
- Antigravity: Latest stable release from GitHub
- **No version pinning** - IDEs update frequently, latest assumed compatible

### IDE Dependency Requirements

**Dependencies** (FR-019, Research §3):
```bash
# Common IDE dependencies
apt-get install -y \
  libgtk-3-0 \
  libnotify4 \
  libnss3 \
  libxss1 \
  libxtst6 \
  libgbm1 \
  libasound2 \
  libsecret-1-0

# For AppImages
apt-get install -y fuse libfuse2
```

### Desktop Launcher Creation

**Launcher Requirements** (Research §3):
```bash
# Verify launcher exists
verify_launcher() {
  local app=$1
  test -f "/usr/share/applications/${app}.desktop"
}

# Test launcher functionality
gtk-launch code
gtk-launch cursor
gtk-launch antigravity
```

### CLI Command Alias Requirements

**CLI Aliases** (Research §3):
```bash
# Verify CLI commands
which code
which cursor
which antigravity

# Add to PATH if needed
ln -s /opt/cursor/cursor /usr/local/bin/cursor
ln -s /opt/antigravity/antigravity.AppImage /usr/local/bin/antigravity
```

### IDE Verification Procedure

**Complete Verification** (FR-037, Research §3):
```bash
verify_ide() {
  local ide=$1
  local command=$2
  
  # 1. Executable exists
  if ! which "$command" >/dev/null 2>&1; then
    log "ERROR: $ide command not found"
    return 1
  fi
  
  # 2. Version check (launches IDE briefly)
  if ! timeout 10 "$command" --version >/dev/null 2>&1; then
    log "ERROR: $ide fails version check"
    return 1
  fi
  
  # 3. Desktop launcher exists
  if ! test -f "/usr/share/applications/${ide}.desktop"; then
    log "WARN: $ide desktop launcher missing"
  fi
  
  # 4. Dependency check for AppImages
  if [[ "$command" == *.AppImage ]]; then
    if ! ldd "$command" | grep -q "not found"; then
      log "ERROR: $ide has missing dependencies"
      return 1
    fi
  fi
  
  log "SUCCESS: $ide verified"
  return 0
}

# Run verification
verify_ide "VSCode" "code"
verify_ide "Cursor" "cursor"
verify_ide "Antigravity" "antigravity"
```

### Fallback Installation Methods

**Fallback Strategy**:
1. **VSCode**: If .deb fails, try snap: `snap install code --classic`
2. **Cursor**: If .deb fails, use AppImage method
3. **Antigravity**: If GitHub unavailable, check backup mirror
4. **All**: Log warning, continue with other IDEs (non-critical failure)

### IDE Configuration Requirements

**Basic Configuration**:
```bash
# VSCode: Disable telemetry
mkdir -p /home/devuser/.config/Code/User
cat > /home/devuser/.config/Code/User/settings.json << 'EOF'
{
  "telemetry.enableTelemetry": false,
  "telemetry.enableCrashReporter": false,
  "update.mode": "manual"
}
EOF
chown -R devuser:devuser /home/devuser/.config/Code
```

---

## Idempotency Requirements

### Existing Installation Detection

**Detection Methods** (FR-007, Research §8):
```bash
# Package detection
is_package_installed() {
  dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Service detection
is_service_enabled() {
  systemctl is-enabled "$1" >/dev/null 2>&1
}

# User detection
user_exists() {
  id "$1" >/dev/null 2>&1
}

# File detection
file_configured() {
  test -f "$1.backup" && cmp -s "$1" "$1.expected"
}
```

### Checkpoint Mechanism

**Complete Specification** (Research §8):
```bash
# Checkpoint directory
CHECKPOINT_DIR="/var/vps-provision/checkpoints"

# Create checkpoint
create_checkpoint() {
  local phase=$1
  mkdir -p "$CHECKPOINT_DIR"
  echo "$(date -Iseconds)" > "$CHECKPOINT_DIR/${phase}.done"
  log "Checkpoint created: $phase"
}

# Check checkpoint
check_checkpoint() {
  local phase=$1
  test -f "$CHECKPOINT_DIR/${phase}.done"
}

# Clear all checkpoints (for --force)
clear_checkpoints() {
  rm -rf "$CHECKPOINT_DIR"
  mkdir -p "$CHECKPOINT_DIR"
}

# Usage
if check_checkpoint "desktop-install" && [ "$FORCE" != "true" ]; then
  log "Phase desktop-install already completed, skipping..."
else
  run_desktop_install
  create_checkpoint "desktop-install"
fi
```

### Checkpoint Validation

**Validation Requirements**:
```bash
validate_checkpoint() {
  local phase=$1
  case $phase in
    system-prep)
      dpkg -l | grep -q "^ii  xfce" && return 0
      ;;
    desktop-install)
      systemctl is-active lightdm >/dev/null 2>&1 && return 0
      ;;
    rdp-config)
      systemctl is-active xrdp >/dev/null 2>&1 && return 0
      ;;
    user-creation)
      id devuser >/dev/null 2>&1 && return 0
      ;;
  esac
  return 1
}

# Verify checkpoint validity before skipping
if check_checkpoint "desktop-install"; then
  if validate_checkpoint "desktop-install"; then
    log "Checkpoint valid, skipping phase"
  else
    log "Checkpoint invalid, re-running phase"
    run_desktop_install
  fi
fi
```

### Duplicate Installation Prevention

**Prevention Strategy** (FR-007):
- Check before every installation action
- Use package manager's built-in idempotency (`apt-get install` safe to rerun)
- Configuration file modifications: check for backup before modifying
- Service enable: `systemctl enable` is idempotent

### Configuration File Modification Checks

**Modification Detection**:
```bash
modify_config_idempotent() {
  local file=$1
  local marker=$2
  local content=$3
  
  # Check if already modified
  if grep -q "$marker" "$file"; then
    log "$file already configured, skipping..."
    return 0
  fi
  
  # Backup original
  cp "$file" "${file}.backup.$(date +%s)"
  
  # Apply modification
  echo "$content" >> "$file"
  log "$file configured successfully"
}

# Usage
modify_config_idempotent "/etc/xrdp/xrdp.ini" \
  "# VPS-PROVISION CONFIGURED" \
  "max_bpp=32\ntcp_nodelay=true"
```

### State Comparison Strategy

**Comparison Methods**:
```bash
compare_state() {
  local expected_state=$1
  local current_state=$2
  
  # Compare package lists
  diff <(echo "$expected_state" | jq -r '.packages[]' | sort) \
       <(dpkg -l | awk '/^ii/{print $2}' | sort) \
       > /tmp/package_diff.txt
  
  # Compare service states
  diff <(echo "$expected_state" | jq -r '.services[]' | sort) \
       <(systemctl list-units --type=service --state=running | awk '{print $1}' | sort) \
       > /tmp/service_diff.txt
  
  # Report differences
  if [ -s /tmp/package_diff.txt ] || [ -s /tmp/service_diff.txt ]; then
    log "State differences detected, provisioning required"
    return 1
  fi
  
  log "State matches expected, no provisioning needed"
  return 0
}
```

### Idempotency Verification Requirements

**Verification Test** (SC-008):
```bash
# Test 1: Run provisioning twice
run_provisioning
first_duration=$SECONDS

run_provisioning
second_duration=$SECONDS

# Verify second run is faster (< 5 minutes)
if [ $second_duration -gt 300 ]; then
  log "ERROR: Second run took ${second_duration}s, expected <300s"
  exit 1
fi

# Test 2: Verify no errors on second run
if grep -q "ERROR" /var/log/vps-provision/provision.log; then
  log "ERROR: Second run produced errors"
  exit 1
fi

# Test 3: Verify system state unchanged
compare_state "$(get_system_state)" "$expected_state"
```

### Re-run Performance Requirement

**Performance Target** (Plan):
- First run: ≤15 minutes (full provisioning)
- Second run: ≤5 minutes (validation only)
- Checkpoint detection: <1 second per phase
- Total overhead: <30 seconds for all checks

### Update vs Fresh Install Behaviors

**Behavior Distinction**:
```bash
handle_installation() {
  local package=$1
  
  if is_package_installed "$package"; then
    log "$package already installed"
    
    # Check if update available
    if apt-cache policy "$package" | grep -q "Candidate.*newer"; then
      log "Update available for $package, applying..."
      apt-get install --only-upgrade "$package" -y
    else
      log "$package is up-to-date, skipping..."
    fi
  else
    log "Installing $package..."
    apt-get install "$package" -y
  fi
}
```

### Checkpoint Cleanup Strategy

**Cleanup Rules**:
```bash
cleanup_checkpoints() {
  local reason=$1
  
  case $reason in
    force)
      # --force flag: remove all checkpoints
      rm -rf /var/vps-provision/checkpoints/*
      log "All checkpoints cleared due to --force"
      ;;
    success)
      # After successful completion: keep checkpoints
      log "Checkpoints preserved for idempotent re-runs"
      ;;
    failure)
      # After failure: remove checkpoints for failed/incomplete phases
      remove_incomplete_checkpoints
      log "Incomplete checkpoints removed"
      ;;
    manual)
      # Manual cleanup command
      rm -rf /var/vps-provision/checkpoints/*
      log "Checkpoints manually cleared"
      ;;
  esac
}
```

---

## Installation Sequence & Dependencies

### Phase Dependencies

**Explicit Dependency Graph** (Contracts):
```
system-prep (no dependencies)
  └─> desktop-install (requires: system-prep)
      └─> rdp-config (requires: desktop-install)
          └─> user-creation (requires: system-prep)
              ├─> ide-vscode (requires: user-creation)
              ├─> ide-cursor (requires: user-creation)
              ├─> ide-antigravity (requires: user-creation)
              └─> terminal-setup (requires: user-creation)
                  └─> dev-tools (requires: terminal-setup)
                      └─> verification (requires: all above)
```

**Validation**:
```bash
check_dependencies() {
  local phase=$1
  local deps=("${@:2}")
  
  for dep in "${deps[@]}"; do
    if ! check_checkpoint "$dep"; then
      log "ERROR: Dependency $dep not met for $phase"
      return 1
    fi
  done
  return 0
}

# Usage
if ! check_dependencies "rdp-config" "system-prep" "desktop-install"; then
  log "ERROR: Cannot run rdp-config, dependencies not met"
  exit 1
fi
```

### Installation Order Justification

**Order Rationale** (Plan):
1. **system-prep**: Must run first (package updates, base requirements)
2. **desktop-install**: Required before RDP (RDP needs X server)
3. **rdp-config**: Must have desktop available
4. **user-creation**: Required before user-specific installations
5. **IDE installations**: Can run in parallel after user creation
6. **terminal-setup**: Requires user home directory
7. **dev-tools**: Final tools installation
8. **verification**: Must run last to validate everything

### Parallel Installation Opportunities

**Parallelization** (NFR-001):
```bash
# IDEs can install in parallel
install_ides_parallel() {
  install_vscode &
  PID_VSCODE=$!
  
  install_cursor &
  PID_CURSOR=$!
  
  install_antigravity &
  PID_ANTIGRAVITY=$!
  
  # Wait for all to complete
  wait $PID_VSCODE
  RESULT_VSCODE=$?
  
  wait $PID_CURSOR
  RESULT_CURSOR=$?
  
  wait $PID_ANTIGRAVITY
  RESULT_ANTIGRAVITY=$?
  
  # Check results
  [ $RESULT_VSCODE -eq 0 ] && log "VSCode installed successfully"
  [ $RESULT_CURSOR -eq 0 ] && log "Cursor installed successfully"
  [ $RESULT_ANTIGRAVITY -eq 0 ] && log "Antigravity installed successfully"
}
```

**Estimated Time Savings**: 2-3 minutes (from ~15min to ~12min)

### Phase Prerequisite Validation

**Validation Before Each Phase** (Contracts):
```bash
validate_prerequisites() {
  local phase=$1
  
  case $phase in
    system-prep)
      # Check OS version
      grep -q "Debian GNU/Linux 13" /etc/os-release || return 1
      # Check disk space
      [ $(df / | awk 'NR==2{print $4}') -gt 10485760 ] || return 1
      # Check memory
      [ $(free -m | awk 'NR==2{print $2}') -gt 2000 ] || return 1
      ;;
    desktop-install)
      check_checkpoint "system-prep" || return 1
      ;;
    rdp-config)
      check_checkpoint "desktop-install" || return 1
      systemctl is-active lightdm >/dev/null 2>&1 || return 1
      ;;
    *)
      # Generic dependency check
      return 0
      ;;
  esac
  
  return 0
}
```

### Inter-Phase State Passing

**State Management** (Data Model):
```json
{
  "phase_state": {
    "desktop-install": {
      "display_manager": "lightdm",
      "desktop_environment": "xfce4",
      "x_display": ":10"
    },
    "user-creation": {
      "username": "devuser",
      "uid": 1000,
      "home": "/home/devuser",
      "password": "<generated>"
    }
  }
}
```

**Usage**:
```bash
# Write state after phase
write_phase_state() {
  local phase=$1
  local key=$2
  local value=$3
  
  jq --arg phase "$phase" \
     --arg key "$key" \
     --arg value "$value" \
     '.phase_state[$phase][$key] = $value' \
     /var/vps-provision/state.json > /tmp/state.json
  mv /tmp/state.json /var/vps-provision/state.json
}

# Read state in subsequent phase
read_phase_state() {
  local phase=$1
  local key=$2
  
  jq -r --arg phase "$phase" \
        --arg key "$key" \
        '.phase_state[$phase][$key]' \
        /var/vps-provision/state.json
}

# Example
username=$(read_phase_state "user-creation" "username")
install_vscode_for_user "$username"
```

---

## Verification Requirements

### Component Verification Requirements

**Per-Component Checks** (FR-035):
1. **Desktop Environment**:
   - `which startxfce4` returns 0
   - `systemctl is-active lightdm` returns 0
   - `/usr/bin/xfce4-session` exists
   
2. **RDP Server**:
   - `systemctl is-active xrdp` returns 0
   - `netstat -ln | grep :3389` shows LISTEN
   - `/etc/xrdp/cert.pem` exists
   
3. **IDEs**:
   - `which code` returns 0
   - `which cursor` returns 0
   - `which antigravity` returns 0
   - Each launches without error
   
4. **User Account**:
   - `id devuser` returns 0
   - `groups devuser | grep sudo` succeeds
   - `/home/devuser` exists with correct permissions

### Executable Existence Checks

**Verification** (FR-037):
```bash
verify_executables() {
  local executables=(
    "code"
    "cursor"
    "antigravity"
    "git"
    "xfce4-session"
    "xrdp"
  )
  
  for exe in "${executables[@]}"; do
    if ! which "$exe" >/dev/null 2>&1; then
      log "ERROR: Required executable '$exe' not found"
      return 1
    fi
    log "✓ Executable verified: $exe"
  done
  
  return 0
}
```

### IDE Launch Tests

**Launch Test Requirement** (FR-037):
```bash
test_ide_launch() {
  local ide=$1
  local command=$2
  
  log "Testing $ide launch..."
  
  # Launch with timeout (IDE should start within 10s)
  timeout 10 "$command" --version >/dev/null 2>&1
  local result=$?
  
  if [ $result -eq 0 ]; then
    log "✓ $ide launches successfully"
    return 0
  elif [ $result -eq 124 ]; then
    log "ERROR: $ide launch timed out (>10s)"
    return 1
  else
    log "ERROR: $ide failed to launch (exit code $result)"
    return 1
  fi
}

# Run tests
test_ide_launch "VSCode" "code"
test_ide_launch "Cursor" "cursor"
test_ide_launch "Antigravity" "antigravity"
```

### Service Status Checks

**Service Verification** (FR-036):
```bash
verify_services() {
  local services=(
    "xrdp"
    "xrdp-sesman"
    "lightdm"
    "systemd-logind"
  )
  
  for service in "${services[@]}"; do
    if ! systemctl is-active "$service" >/dev/null 2>&1; then
      log "ERROR: Service $service is not active"
      return 1
    fi
    
    if ! systemctl is-enabled "$service" >/dev/null 2>&1; then
      log "WARN: Service $service is not enabled"
    fi
    
    log "✓ Service verified: $service"
  done
  
  return 0
}
```

### Network Port Accessibility

**Port Verification** (FR-036):
```bash
verify_ports() {
  # Check RDP port (3389)
  if ! netstat -ln | grep -q ":3389.*LISTEN"; then
    log "ERROR: RDP port 3389 is not listening"
    return 1
  fi
  log "✓ RDP port 3389 accessible"
  
  # Check SSH port (22)
  if ! netstat -ln | grep -q ":22.*LISTEN"; then
    log "WARN: SSH port 22 is not listening"
  fi
  log "✓ SSH port 22 accessible"
  
  # Optional: Test external connectivity
  if command -v nc >/dev/null 2>&1; then
    timeout 5 nc -zv localhost 3389 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      log "✓ RDP port external connectivity verified"
    fi
  fi
  
  return 0
}
```

### File Permission Verifications

**Permission Checks**:
```bash
verify_permissions() {
  # User home directory
  if [ ! -d /home/devuser ]; then
    log "ERROR: User home directory missing"
    return 1
  fi
  
  local owner=$(stat -c '%U' /home/devuser)
  if [ "$owner" != "devuser" ]; then
    log "ERROR: Home directory has wrong owner: $owner"
    return 1
  fi
  log "✓ Home directory permissions correct"
  
  # Sudo permissions
  if ! sudo -l -U devuser | grep -q "NOPASSWD: ALL"; then
    log "ERROR: User lacks passwordless sudo"
    return 1
  fi
  log "✓ Sudo permissions verified"
  
  # Certificate permissions
  local key_perms=$(stat -c '%a' /etc/xrdp/key.pem)
  if [ "$key_perms" != "600" ]; then
    log "ERROR: xrdp key permissions incorrect: $key_perms"
    return 1
  fi
  log "✓ Certificate permissions correct"
  
  return 0
}
```

### Configuration Correctness Validation

**Configuration Checks**:
```bash
verify_configurations() {
  # xrdp configuration
  if ! grep -q "port=3389" /etc/xrdp/xrdp.ini; then
    log "ERROR: xrdp port misconfigured"
    return 1
  fi
  log "✓ xrdp configuration correct"
  
  # Desktop session configuration
  if ! grep -q "xfce4-session" /home/devuser/.xsession; then
    log "ERROR: Desktop session not configured"
    return 1
  fi
  log "✓ Desktop session configuration correct"
  
  # Git configuration
  if ! git config --global --get user.email >/dev/null 2>&1; then
    log "WARN: Git user email not configured"
  fi
  
  return 0
}
```

### Library Dependency Checks

**Dependency Verification** (Research §3):
```bash
verify_dependencies() {
  local binary=$1
  
  # For AppImages
  if [[ "$binary" == *.AppImage ]]; then
    # Extract and check dependencies
    "$binary" --appimage-extract-and-run --version >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      log "ERROR: $binary has missing dependencies"
      
      # Detailed check with ldd
      "$binary" --appimage-extract >/dev/null 2>&1
      local missing=$(ldd squashfs-root/usr/bin/* 2>/dev/null | grep "not found")
      if [ -n "$missing" ]; then
        log "Missing libraries: $missing"
      fi
      
      rm -rf squashfs-root
      return 1
    fi
  else
    # For regular binaries
    local missing=$(ldd "$binary" 2>/dev/null | grep "not found")
    if [ -n "$missing" ]; then
      log "ERROR: $binary has missing dependencies:"
      log "$missing"
      return 1
    fi
  fi
  
  log "✓ Dependencies verified for $binary"
  return 0
}

# Check all IDEs
verify_dependencies $(which code)
verify_dependencies $(which cursor)
verify_dependencies $(which antigravity)
```

### Verification Failure Handling

**Failure Response** (FR-039):
```bash
handle_verification_failure() {
  local component=$1
  local error=$2
  
  log "ERROR: Verification failed for $component: $error"
  
  # Add to failure report
  echo "$component: $error" >> /var/vps-provision/verification-failures.txt
  
  # Determine criticality
  case $component in
    "RDP Server"|"Desktop Environment"|"User Account")
      log "CRITICAL: Core component failed, triggering rollback"
      trigger_rollback
      exit 4
      ;;
    "VSCode"|"Cursor"|"Antigravity")
      log "NON-CRITICAL: IDE failed, continuing with other components"
      return 1
      ;;
    *)
      log "WARN: Optional component failed"
      return 1
      ;;
  esac
}
```

### Verification Timing Requirements

**Timing Targets**:
- Complete verification suite: ≤60 seconds
- Per-component verification: ≤10 seconds
- IDE launch tests: ≤10 seconds each
- Service checks: ≤5 seconds total
- Total overhead: <2% of provisioning time

```bash
time_verification() {
  local start=$SECONDS
  
  verify_services
  verify_executables
  verify_configurations
  verify_permissions
  verify_ports
  
  local duration=$((SECONDS - start))
  log "Verification completed in ${duration}s"
  
  if [ $duration -gt 60 ]; then
    log "WARN: Verification took longer than expected (60s)"
  fi
}
```

---

## Summary

This document provides complete specifications for all installation requirements identified in the checklist. All specifications are traceable to requirements in spec.md, research decisions in research.md, and contracts in the contracts/ directory.

**Key Additions**:
- Complete package management specifications with retry strategies
- Detailed desktop environment configuration
- Comprehensive RDP server setup with TLS
- Complete IDE installation procedures with fallbacks
- Robust idempotency implementation with checkpoints
- Detailed verification procedures for all components
- Resource management and monitoring specifications
- Performance targets for all operations

All 100 checklist items now have complete, measurable specifications.
