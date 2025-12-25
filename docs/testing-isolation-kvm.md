# KVM Virtualization Testing Guide

This guide explains how to run E2E tests using KVM virtualization for maximum test fidelity and hardware-level isolation.

## Overview

KVM (Kernel-based Virtual Machine) testing provides full hardware virtualization for VPS provisioning tests. Unlike Docker-based isolation, KVM tests run in complete virtual machines with:

- **Full system isolation**: Separate kernel, complete filesystem
- **Native systemd**: Full init system without privileged mode
- **Desktop environment**: Complete X11/XFCE stack without quirks
- **RDP server**: Real xrdp service with network stack
- **Hardware fidelity**: Matches actual VPS deployment exactly

## Trade-offs: KVM vs Docker

| Criteria                | Docker (Current)              | KVM                                | Winner     |
| ----------------------- | ----------------------------- | ---------------------------------- | ---------- |
| **Isolation Level**     | Container (shared kernel)     | Full VM (separate kernel)          | **KVM**    |
| **Startup Time**        | 5-10 seconds                  | 30-60 seconds                      | **Docker** |
| **Resource Overhead**   | ~100MB RAM                    | ~500MB RAM                         | **Docker** |
| **Systemd Support**     | Requires `--privileged`       | Native full support                | **KVM**    |
| **Desktop Environment** | Works (with caveats)          | Full native support                | **KVM**    |
| **Snapshot Speed**      | Fast (overlay filesystem)     | Medium (qcow2 snapshots)           | **Docker** |
| **CI/CD Integration**   | Excellent (Docker-in-Docker)  | Good (nested KVM support)          | **Docker** |
| **Network Isolation**   | Good (bridge networking)      | Excellent (full network stack)     | **KVM**    |
| **Setup Complexity**    | Low (Dockerfile)              | Medium (virt-install + cloud-init) | **Docker** |
| **Test Fidelity**       | High (matches container prod) | **Highest (matches bare metal)**   | **KVM**    |

**Recommendation**: Use Docker for CI/CD and quick iteration. Use KVM for weekly validation and pre-release testing.

## Prerequisites

### Hardware Requirements

- **CPU**: Intel VT-x or AMD-V hardware virtualization support
- **RAM**: 8GB minimum (4GB for VM + 4GB host overhead)
- **Disk**: 50GB SSD (25GB for VM + snapshots)
- **OS**: Linux with KVM kernel modules

### Software Requirements

```bash
# Required packages
sudo apt-get install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    virtinst \
    qemu-utils \
    genisoimage \
    cloud-init \
    rsync

# Add user to libvirt group
sudo usermod -aG libvirt $USER
newgrp libvirt  # Or logout/login

# Verify KVM availability
lsmod | grep kvm
# Expected: kvm_intel or kvm_amd

# Start libvirt daemon
sudo systemctl start libvirtd
sudo systemctl enable libvirtd

# Verify libvirt
virsh version
```

### Verify KVM Support

```bash
# Check KVM device
ls -la /dev/kvm
# Expected: crw-rw---- 1 root kvm /dev/kvm

# Check CPU virtualization
egrep -c '(vmx|svm)' /proc/cpuinfo
# Expected: non-zero (number of CPU cores)

# Verify user permissions
groups | grep libvirt
# Expected: your username should be in libvirt group
```

## Quick Start

### 1. Build Base Image (One-Time Setup)

```bash
# Build Debian 13 base image with Packer
cd tests/e2e/packer
./build-base-image.sh

# This creates: /var/lib/libvirt/images/debian-13-base
# Duration: ~15-20 minutes (automated, unattended)
```

**What the base image includes**:

- Debian 13 (Bookworm) minimal installation
- VirtIO drivers for optimal performance
- Cloud-init for automated configuration
- SSH server enabled with password authentication
- Passwordless sudo configured
- Essential packages (curl, wget, git)

### 2. Run KVM E2E Tests

```bash
# Check prerequisites first
make check-kvm-prerequisites

# Run full E2E test in KVM
make test-e2e-kvm

# Test will:
# 1. Create overlay disk from base image (fast, copy-on-write)
# 2. Launch VM with cloud-init configuration
# 3. Copy provisioning files to VM
# 4. Execute vps-provision script
# 5. Validate all components (desktop, RDP, IDEs)
# 6. Generate test report
# 7. Clean up VM and resources
```

### 3. Review Test Results

```bash
# Test report is generated at:
cat /tmp/vps-test-*-report.md

# Example output:
# ✅ All validation checks passed
# - User configuration: PASSED
# - System packages: PASSED
# - Desktop environment: PASSED
# - RDP server: PASSED
# - IDE installations: PASSED
```

## Base Image Details

### Automated Build Process

The Packer template (`tests/e2e/packer/debian-13-base.pkr.hcl`) automates:

1. **ISO Download**: Fetches Debian 13 netinst ISO
2. **Preseed Installation**: Unattended Debian setup
3. **VirtIO Configuration**: Optimized drivers for KVM
4. **Package Installation**: Essential tools and dependencies
5. **Cloud-init Setup**: First-boot automation support
6. **Image Optimization**: Zeros unused space, compresses disk

### Manual Base Image Creation (Alternative)

If Packer fails or you prefer manual setup:

```bash
# Create disk image
qemu-img create -f qcow2 /var/lib/libvirt/images/debian-13-base.qcow2 25G

# Install Debian interactively
virt-install \
    --name debian-13-base \
    --ram 4096 \
    --vcpus 2 \
    --disk path=/var/lib/libvirt/images/debian-13-base.qcow2,format=qcow2,bus=virtio \
    --os-variant debian12 \
    --network network=default,model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --location 'https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/' \
    --extra-args 'console=ttyS0,115200n8'

# Follow interactive installation
# Configure: testuser with sudo, SSH enabled, minimal system

# After installation, shutdown and create snapshot
virsh shutdown debian-13-base
virsh snapshot-create-as debian-13-base "clean-install"
```

## Test Execution Details

### VM Lifecycle

```
1. Create overlay disk from base image (copy-on-write, ~1s)
2. Generate cloud-init ISO with user configuration (~1s)
3. Launch VM with overlay disk + cloud-init ISO (~30s)
4. Wait for VM network ready (~10s)
5. Wait for SSH access available (~10s)
6. Copy provisioning files via rsync (~30s)
7. Execute provisioning script (~13-15 min)
8. Validate results (~1 min)
9. Create success snapshot (~5s)
10. Generate test report (~1s)
11. Destroy VM and cleanup resources (~5s)
```

**Total duration**: ~17-20 minutes (15 min provision + 2-5 min overhead)

### Snapshot-Based Isolation

Every test creates isolated snapshots:

- **clean-boot**: VM state before provisioning
- **provisioned**: VM state after successful provisioning

Benefits:

- Test isolation guaranteed (fresh state every run)
- Quick rollback for debugging
- Multiple test runs without rebuilding base image

## Troubleshooting

### KVM Not Available

**Error**: `/dev/kvm not found`

**Solution**:

```bash
# Check if KVM modules loaded
lsmod | grep kvm

# Load modules if missing
sudo modprobe kvm
sudo modprobe kvm_intel  # or kvm_amd for AMD

# Make permanent
echo "kvm" | sudo tee -a /etc/modules
echo "kvm_intel" | sudo tee -a /etc/modules  # or kvm_amd
```

### Libvirt Permission Denied

**Error**: `permission denied` when running virsh

**Solution**:

```bash
# Add user to libvirt group
sudo usermod -aG libvirt $USER

# Apply group membership
newgrp libvirt  # Or logout/login

# Verify
groups | grep libvirt
```

### Base Image Not Found

**Error**: `Base image not found: /var/lib/libvirt/images/debian-13-base`

**Solution**:

```bash
# Build base image
cd tests/e2e/packer
./build-base-image.sh

# Or check if image exists but with different path
sudo find /var/lib/libvirt/images -name "*debian*"
```

### VM Network Timeout

**Error**: `Timeout waiting for VM IP address`

**Solution**:

```bash
# Check libvirt network running
sudo virsh net-list --all

# Start default network if stopped
sudo virsh net-start default
sudo virsh net-autostart default

# Verify DHCP range
sudo virsh net-dumpxml default | grep dhcp

# Check firewall not blocking DHCP
sudo iptables -L -n | grep 67
```

### Test Cleanup Failed

**Error**: VM or disk images remain after test

**Solution**:

```bash
# Manual cleanup - list all VMs
sudo virsh list --all

# Destroy and undefine test VMs
sudo virsh destroy vps-test-12345 2>/dev/null || true
sudo virsh undefine vps-test-12345 --remove-all-storage 2>/dev/null || true

# Clean up overlay images
sudo find /tmp -name "vps-test-*.qcow2" -delete
sudo find /tmp -name "vps-test-*.iso" -delete
```

### Slow Provisioning Performance

**Problem**: Test takes >25 minutes

**Solution**:

```bash
# Enable KVM nested virtualization (if on VM)
echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm-intel.conf
sudo modprobe -r kvm_intel && sudo modprobe kvm_intel

# Use SSD for libvirt images
sudo mv /var/lib/libvirt/images /path/to/ssd/
sudo ln -s /path/to/ssd/images /var/lib/libvirt/images

# Allocate more resources to VM
# Edit: tests/e2e/run-kvm-test.sh
# Change: --memory 4096 -> --memory 8192
```

## Performance Tuning

### Host Optimization

```bash
# CPU governor for consistent performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Hugepages for better memory performance
echo 2048 | sudo tee /proc/sys/vm/nr_hugepages
echo 'vm.nr_hugepages = 2048' | sudo tee -a /etc/sysctl.conf

# Disable swap for predictable performance
sudo swapoff -a
```

### VM Resource Tuning

Edit `tests/e2e/lib/kvm-helpers.sh` function `kvm_create_vm()`:

```bash
# Increase memory
--memory 8192  # from 4096

# Increase CPUs
--vcpu 4  # from 2

# Use host CPU model
--cpu host-passthrough
```

## CI/CD Integration

### GitHub Actions

The workflow `.github/workflows/kvm-e2e-tests.yml` runs KVM tests:

- **Manual trigger**: `workflow_dispatch` with configurable timeout
- **Weekly schedule**: Every Monday at 2:00 AM UTC
- **Release branches**: Automatic on `release/**` and `hotfix/**` pushes

**Note**: GitHub-hosted runners do not support nested virtualization. Use self-hosted runners with KVM support for best results.

### Self-Hosted Runner Setup

```bash
# Install runner on KVM-capable host
# Follow: https://docs.github.com/en/actions/hosting-your-own-runners

# Verify KVM available to runner user
sudo usermod -aG libvirt github-runner
sudo systemctl restart actions.runner.service

# Test KVM access
sudo -u github-runner virsh version
```

## Advanced Usage

### Custom Base Image

Create specialized base images for different scenarios:

```bash
# Build with custom preseed
cd tests/e2e/packer
./build-base-image.sh --preseed custom-preseed.cfg

# Or use Terraform
cd tests/e2e/terraform
terraform apply -var="base_image=/custom/path.qcow2"
```

### Debugging Failed Tests

```bash
# Keep VM running after test
# Edit run-kvm-test.sh, comment out cleanup:
# kvm_cleanup_on_exit "$VM_NAME" ...

# Run test
make test-e2e-kvm

# Connect to VM
VM_IP=$(sudo virsh domifaddr vps-test-12345 | awk '/ipv4/{print $4}' | cut -d'/' -f1)
ssh testuser@$VM_IP

# Or use VNC
sudo virsh domdisplay vps-test-12345
```

### Snapshot Management

```bash
# List snapshots for VM
sudo virsh snapshot-list vps-test-12345 --tree

# Restore to specific snapshot
sudo virsh snapshot-revert vps-test-12345 clean-boot

# Create manual snapshot
sudo virsh snapshot-create-as vps-test-12345 "debug-state" "Before debugging"

# Delete snapshot
sudo virsh snapshot-delete vps-test-12345 "debug-state"
```

## Performance Benchmarks

Based on testing with base image on SSD:

| Operation               | Docker | KVM    | Notes                   |
| ----------------------- | ------ | ------ | ----------------------- |
| **Test Environment**    | 5s     | 45s    | VM boot overhead        |
| **Provisioning**        | 13min  | 13min  | Identical (same script) |
| **Validation**          | 30s    | 1min   | KVM more thorough       |
| **Cleanup**             | 2s     | 5s     | VM destruction overhead |
| **Total Duration**      | ~14min | ~18min | +4 min for VM lifecycle |
| **Idempotent Re-run**   | 3min   | 5min   | Both use checkpoints    |
| **Memory Usage (peak)** | 2GB    | 5GB    | Full VM vs container    |
| **Disk Space (active)** | 3GB    | 8GB    | Overlay + base image    |

**Conclusion**: KVM adds ~4 minutes overhead but provides highest test fidelity matching actual VPS deployment.

## Related Documentation

- [Testing Isolation (Docker)](./testing-isolation.md) - Docker-based E2E testing
- [Architecture](./architecture.md) - System architecture overview
- [Troubleshooting](./troubleshooting.md) - General troubleshooting guide
- [Performance](./performance.md) - Performance optimization guide

## Support

For issues specific to KVM testing:

1. Check [Troubleshooting](#troubleshooting) section above
2. Verify prerequisites: `make check-kvm-prerequisites`
3. Review test logs: `/tmp/vps-test-*-report.md`
4. Check libvirt logs: `sudo journalctl -u libvirtd -n 100`

For general provisioning issues, see [docs/troubleshooting.md](./troubleshooting.md).
