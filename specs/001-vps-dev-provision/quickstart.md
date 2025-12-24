# Quick Start Guide: VPS Developer Workstation Provisioning

**Feature**: [spec.md](spec.md) | [plan.md](plan.md)  
**Version**: 1.0.0  
**Date**: December 23, 2025

## Overview

This guide will help you provision a fresh Digital Ocean Debian 13 VPS into a fully-functional developer workstation in under 15 minutes with a single command.

---

## Prerequisites

Before running the provisioning tool, ensure you have:

1. **Digital Ocean Account** with ability to create Debian 13 droplets
2. **Fresh VPS Instance** running Debian 13 (Bookworm)
   - Minimum: 2GB RAM, 1 vCPU, 25GB disk
   - Recommended: 4GB RAM, 2 vCPU, 80GB disk
3. **Root SSH Access** to the VPS
4. **Stable Internet Connection** on the VPS for downloading packages

---

## Installation

### Step 1: Connect to Your VPS

```bash
ssh root@<your-vps-ip>
```

### Step 2: Download the Provisioning Tool

```bash
# Download the latest release
wget https://github.com/yourusername/vps-provision/releases/latest/download/vps-provision.tar.gz

# Extract
tar -xzf vps-provision.tar.gz
cd vps-provision
```

Or clone from source:

```bash
git clone https://github.com/yourusername/vps-provision.git
cd vps-provision
```

---

## Basic Usage

### Quick Provision (Default Settings)

Run the provisioning with all defaults:

```bash
sudo ./bin/vps-provision
```

This will:
- ✓ Install XFCE desktop environment
- ✓ Configure xrdp for remote desktop access (port 3389)
- ✓ Create developer user account named "devuser"
- ✓ Install VSCode, Cursor, and Antigravity IDEs
- ✓ Configure terminal with git aliases and colored prompt
- ✓ Set up passwordless sudo for the developer user
- ✓ Run verification checks

**Expected Duration**: 10-15 minutes on a 4GB/2vCPU droplet

---

## Example Output

```
╔══════════════════════════════════════════════════════════════╗
║        VPS Developer Workstation Provisioning Tool          ║
║                    Version 1.0.0                             ║
╚══════════════════════════════════════════════════════════════╝

Session ID: 20251223-103000
Start Time: 2025-12-23 10:30:00 UTC

[✓] Pre-Flight Validation
    ├─ OS Version: Debian 13 (Bookworm) ✓
    ├─ CPU Cores: 2 ✓
    ├─ RAM: 4096 MB ✓
    ├─ Disk Space: 72.3 GB available ✓
    └─ Network: Connected ✓

[⚙] Phase 1/7: System Preparation (est. 3-5 min)
    ├─ Updating package lists... Done
    ├─ Upgrading existing packages... Done
    ├─ Installing base packages... Done
    └─ Configuring auto-updates... Done
    Duration: 3m 45s ✓

[⚙] Phase 2/7: Desktop Environment (est. 4-6 min)
    ├─ Installing XFCE desktop... Done
    ├─ Configuring display manager... Done
    ├─ Setting default session... Done
    └─ Applying customizations... Done
    Duration: 4m 30s ✓

[⚙] Phase 3/7: RDP Server Configuration (est. 1-2 min)
    ├─ Installing xrdp... Done
    ├─ Generating TLS certificates... Done
    ├─ Configuring multi-session support... Done
    ├─ Enabling xrdp service... Done
    └─ Configuring firewall... Done
    Duration: 1m 15s ✓

[⚙] Phase 4/7: Developer User Creation (est. 30 sec)
    ├─ Creating user 'devuser'... Done
    ├─ Generating password... Done
    ├─ Configuring sudo access... Done
    └─ Setting group memberships... Done
    Duration: 28s ✓

[⚙] Phase 5/7: IDE Installations (est. 6-9 min)
    ├─ Installing VSCode... Done (v1.85.1)
    ├─ Installing Cursor... Done (v0.12.0)
    └─ Installing Antigravity... Done (v1.4.2)
    Duration: 6m 10s ✓

[⚙] Phase 6/7: Terminal Setup (est. 15-30 sec)
    ├─ Installing bash-completion... Done
    ├─ Configuring git aliases... Done
    └─ Setting colored prompt... Done
    Duration: 18s ✓

[⚙] Phase 7/7: Verification (est. 30-60 sec)
    ├─ RDP service status... Running ✓
    ├─ VSCode launch test... Passed ✓
    ├─ Cursor launch test... Passed ✓
    ├─ Antigravity launch test... Passed ✓
    ├─ User permissions... Verified ✓
    └─ System health... All checks passed ✓
    Duration: 42s ✓

╔══════════════════════════════════════════════════════════════╗
║                  PROVISIONING COMPLETE ✓                     ║
╚══════════════════════════════════════════════════════════════╝

Total Duration: 12 minutes 18 seconds

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     CONNECTION INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RDP Access:
  Address: 143.198.45.123:3389
  Username: devuser
  Password: Xy9#mK2$pL4@nQ7w
  
  ⚠  IMPORTANT: Change this password on first login!

SSH Access:
  Command: ssh devuser@143.198.45.123

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     INSTALLED COMPONENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Desktop Environment:  XFCE 4.18.2
RDP Server:           xrdp 0.9.22
IDEs:                 VSCode 1.85.1
                      Cursor 0.12.0
                      Antigravity 1.4.2
Development Tools:    Git 2.39.2
                      build-essential
                      Python 3.11.2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        NEXT STEPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Connect via RDP using the credentials above
   - Windows: Use "Remote Desktop Connection"
   - macOS: Use "Microsoft Remote Desktop" from App Store
   - Linux: Use Remmina or xfreerdp

2. Change your password on first login

3. Launch any IDE from the Applications menu:
   - Applications → Development → Visual Studio Code
   - Applications → Development → Cursor
   - Applications → Development → Antigravity

4. Start coding! 🚀

Logs saved to: /var/log/vps-provision/provision-20251223-103000.log
Session data: /var/vps-provision/sessions/session-20251223-103000.json
```

---

## Advanced Usage

### Custom Username

Create a developer account with a specific username:

```bash
sudo ./bin/vps-provision --username alice
```

### Dry Run (Preview Only)

See what will be installed without making changes:

```bash
sudo ./bin/vps-provision --dry-run
```

### Skip Specific Components

Skip Antigravity IDE installation:

```bash
sudo ./bin/vps-provision --skip-phase ide-antigravity
```

### Install Only Specific Components

Install only VSCode and Cursor:

```bash
sudo ./bin/vps-provision --only-phase ide-vscode --only-phase ide-cursor
```

### Resume After Failure

If provisioning fails, resume from the last checkpoint:

```bash
sudo ./bin/vps-provision --resume
```

### Debug Mode

Run with detailed logging:

```bash
sudo ./bin/vps-provision --log-level DEBUG
```

### JSON Output for Automation

Get machine-readable output:

```bash
sudo ./bin/vps-provision --output-format json > result.json
```

---

## Verification

After provisioning completes, verify the installation:

```bash
sudo ./bin/vps-provision-verify
```

Example verification output:

```
VPS Provisioning Verification
==============================
Timestamp: 2025-12-23 10:45:00

✓ OS Version: Debian 13 (Bookworm)
✓ System Resources: 4096MB RAM, 72.3GB disk available
✓ Desktop Environment: XFCE 4.18.2 installed
✓ RDP Service: xrdp running (PID 1234)
✓ RDP Port: Listening on 0.0.0.0:3389
✓ Developer User: devuser exists (UID 1001)
✓ User Groups: devuser in sudo, audio, video, dialout, plugdev
✓ Sudo Access: Passwordless sudo configured
✓ VSCode: Version 1.85.1 installed
✓ Cursor: Version 0.12.0 installed
✓ Antigravity: Version 1.4.2 installed
✓ Git: Version 2.39.2 installed
✓ Terminal Config: Git aliases and colored prompt configured

Summary: 13/13 checks passed ✓
System is ready for development work!
```

---

## Connecting via RDP

### Windows

1. Press `Win + R`, type `mstsc`, press Enter
2. Enter VPS IP address: `143.198.45.123`
3. Click "Connect"
4. Enter username: `devuser`
5. Enter the generated password
6. Accept certificate warning (first connection only)

### macOS

1. Download "Microsoft Remote Desktop" from App Store
2. Click "+" → "Add PC"
3. PC name: `143.198.45.123`
4. User account: Add username `devuser` and password
5. Click "Add"
6. Double-click the connection to start

### Linux

Using Remmina:

```bash
# Install Remmina if not already installed
sudo apt-get install remmina remmina-plugin-rdp

# Launch Remmina
remmina
```

Or use xfreerdp from command line:

```bash
xfreerdp /v:143.198.45.123 /u:devuser /p:'Xy9#mK2$pL4@nQ7w' /cert:ignore
```

---

## Troubleshooting

### Provisioning Failed

If provisioning fails, check the logs:

```bash
cat /var/log/vps-provision/provision-*.log | tail -100
```

Resume from last checkpoint:

```bash
sudo ./bin/vps-provision --resume
```

Or rollback and start fresh:

```bash
sudo ./bin/vps-provision-rollback
sudo ./bin/vps-provision
```

### Can't Connect via RDP

1. Verify xrdp is running:
   ```bash
   sudo systemctl status xrdp
   ```

2. Check firewall allows port 3389:
   ```bash
   sudo ufw status
   ```

3. Verify port is listening:
   ```bash
   sudo netstat -tlnp | grep 3389
   ```

4. Restart xrdp service:
   ```bash
   sudo systemctl restart xrdp
   ```

### IDE Won't Launch

Run verification to identify the issue:

```bash
sudo ./bin/vps-provision-verify --verbose
```

Re-install specific IDE:

```bash
sudo ./bin/vps-provision-module ide-vscode --force
```

### Permission Errors

Verify user has correct group memberships:

```bash
groups devuser
```

Should show: `devusers sudo audio video dialout plugdev`

Re-run user creation module if needed:

```bash
sudo ./bin/vps-provision-module user-creation --username devuser --force
```

---

## Common Use Cases

### Team Environment - Multiple Users

Provision VPS, then manually create additional users:

```bash
# Provision for first user
sudo ./bin/vps-provision --username alice

# Create additional developer users
sudo useradd -m -s /bin/bash -G devusers,sudo,audio,video,dialout,plugdev bob
sudo usermod -aG devusers charlie
sudo cp /etc/skel/.bashrc /home/bob/
sudo cp /etc/skel/.bashrc /home/charlie/

# Set passwords
sudo passwd bob
sudo passwd charlie
```

### Development + Production Separation

Provision separate VPS instances for dev and staging:

```bash
# On dev VPS
sudo ./bin/vps-provision --username dev-team

# On staging VPS
sudo ./bin/vps-provision --username staging-admin --skip-phase ide-antigravity
```

### Minimal Install (Desktop + VSCode Only)

Skip unnecessary components:

```bash
sudo ./bin/vps-provision \
  --only-phase system-prep \
  --only-phase desktop-install \
  --only-phase rdp-config \
  --only-phase user-creation \
  --only-phase ide-vscode \
  --only-phase verification
```

---

## Next Steps

1. **Change Password**: On first RDP login, you'll be prompted to change your password
2. **Configure Git**: Set your git identity
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```
3. **Install Extensions**: Add your favorite IDE extensions
4. **Clone Repositories**: Start working on your projects
5. **Customize Environment**: Personalize your desktop and terminal

---

## Additional Resources

- **Full Documentation**: See [architecture.md](../docs/architecture.md)
- **Module API Reference**: See [module-api.md](../docs/module-api.md)
- **Troubleshooting Guide**: See [troubleshooting.md](../docs/troubleshooting.md)
- **CLI Contract**: See [contracts/cli-interface.json](contracts/cli-interface.json)
- **Feature Specification**: See [spec.md](spec.md)

---

## Support

If you encounter issues:

1. Check logs in `/var/log/vps-provision/`
2. Run `vps-provision-verify --verbose` for diagnostics
3. Review session data in `/var/vps-provision/sessions/`
4. Open an issue on GitHub with log excerpts

---

**Happy Coding! 🚀**
