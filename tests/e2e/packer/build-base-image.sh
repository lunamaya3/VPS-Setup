#!/bin/bash
# Build script for Debian 13 KVM base image using Packer
set -euo pipefail

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Configuration
readonly PACKER_TEMPLATE="${SCRIPT_DIR}/debian-13-base.pkr.hcl"
readonly BASE_IMAGE_NAME="debian-13-base"
readonly OUTPUT_DIR="${OUTPUT_DIR:-/var/lib/libvirt/images}"
readonly BASE_IMAGE_PATH="${OUTPUT_DIR}/${BASE_IMAGE_NAME}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    if ! command -v packer &>/dev/null; then
        missing_tools+=("packer")
    fi
    
    if ! command -v qemu-img &>/dev/null; then
        missing_tools+=("qemu-img (qemu-utils package)")
    fi
    
    if ! command -v virsh &>/dev/null; then
        missing_tools+=("virsh (libvirt-clients package)")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Install with: sudo apt-get install packer qemu-utils libvirt-clients"
        return 1
    fi
    
    # Check KVM support and permissions
    if [[ ! -e /dev/kvm ]]; then
        log_error "/dev/kvm not found. KVM not available or not enabled."
        log_error "Check with: lsmod | grep kvm"
        return 1
    fi
    
    # Check if user has KVM access
    if ! groups | grep -qE '\b(kvm|libvirt)\b'; then
        log_error "User not in kvm or libvirt group"
        log_error "Fix: sudo usermod -aG kvm,libvirt \$USER && newgrp kvm"
        log_error "Then logout/login or run: newgrp kvm"
        return 1
    fi
    
    # Test KVM access
    if ! test -r /dev/kvm || ! test -w /dev/kvm; then
        log_error "No read/write access to /dev/kvm"
        log_error "Run: newgrp kvm (then retry)"
        return 1
    fi
    
    # Check and setup libvirt network
    if virsh net-list --all 2>/dev/null | grep -q "default"; then
        # Network exists, check if active
        if ! virsh net-list 2>/dev/null | grep -q "default.*active"; then
            log_info "Starting libvirt default network..."
            sudo virsh net-start default 2>/dev/null || true
        fi
        # Ensure autostart is enabled
        sudo virsh net-autostart default 2>/dev/null || true
    else
        # Network doesn't exist, create it
        log_info "Creating libvirt default network..."
        sudo virsh net-define /usr/share/libvirt/networks/default.xml 2>/dev/null || true
        sudo virsh net-start default 2>/dev/null || true
        sudo virsh net-autostart default 2>/dev/null || true
    fi
    
    # Check output directory permissions
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        log_info "Creating output directory: $OUTPUT_DIR"
        sudo mkdir -p "$OUTPUT_DIR"
    fi
    
    if [[ ! -w "$OUTPUT_DIR" ]]; then
        log_error "No write permission to $OUTPUT_DIR"
        log_error "Run with sudo or add user to libvirt group: sudo usermod -aG libvirt \$USER"
        return 1
    fi
    
    log_info "Prerequisites check passed"
}

# Build base image with Packer
build_base_image() {
    log_info "Building Debian 13 base image with Packer..."
    log_info "This may take 15-20 minutes..."
    
    cd "$SCRIPT_DIR"
    
    # Initialize Packer plugins
    log_info "Initializing Packer plugins..."
    packer init "$PACKER_TEMPLATE"
    
    # Validate Packer template
    log_info "Validating Packer template..."
    if ! packer validate "$PACKER_TEMPLATE"; then
        log_error "Packer template validation failed"
        return 1
    fi
    
    # Build image
    log_info "Starting Packer build..."
    if ! packer build \
        -var "vm_name=$BASE_IMAGE_NAME" \
        "$PACKER_TEMPLATE"; then
        log_error "Packer build failed"
        return 1
    fi
    
    # Move image to final location
    log_info "Moving image to final location..."
    local packer_output="/tmp/packer-output/${BASE_IMAGE_NAME}"
    if [[ -f "$packer_output" ]]; then
        sudo mv "$packer_output" "$BASE_IMAGE_PATH"
        sudo rm -rf /tmp/packer-output
        log_info "Image moved to $BASE_IMAGE_PATH"
    else
        log_error "Packer output not found at $packer_output"
        return 1
    fi
    
    log_info "Base image built successfully"
}

# Verify base image
verify_base_image() {
    log_info "Verifying base image..."
    
    if [[ ! -f "$BASE_IMAGE_PATH" ]]; then
        log_error "Base image not found at $BASE_IMAGE_PATH"
        return 1
    fi
    
    # Get image info
    log_info "Image information:"
    qemu-img info "$BASE_IMAGE_PATH"
    
    # Check image size
    local image_size
    image_size=$(qemu-img info "$BASE_IMAGE_PATH" | grep "virtual size" | awk '{print $3}')
    log_info "Virtual size: $image_size"
    
    log_info "Base image verification complete"
}

# Create initial snapshot
create_snapshot() {
    log_info "Creating initial snapshot for testing..."
    
    local vm_name="${BASE_IMAGE_NAME}-test"
    local snapshot_name="clean-install"
    
    # Check if test VM already exists
    if virsh list --all | grep -q "$vm_name"; then
        log_warn "Test VM '$vm_name' already exists. Removing..."
        virsh destroy "$vm_name" 2>/dev/null || true
        virsh undefine "$vm_name" 2>/dev/null || true
    fi
    
    # Import base image as VM
    log_info "Importing base image as test VM..."
    if ! sudo virt-install \
        --name "$vm_name" \
        --memory 2048 \
        --vcpus 2 \
        --disk path="$BASE_IMAGE_PATH",format=qcow2,bus=virtio \
        --import \
        --os-variant debian12 \
        --network network=default,model=virtio \
        --graphics none \
        --noautoconsole &>/dev/null; then
        log_warn "Failed to create test VM (non-critical)"
        log_info "Base image is ready at: $BASE_IMAGE_PATH"
        return 0
    fi
    
    # Wait for VM to be defined
    log_info "Waiting for VM to be defined..."
    sleep 5
    
    # Verify VM was created
    if ! sudo virsh list --all 2>/dev/null | grep -q "$vm_name"; then
        log_warn "VM '$vm_name' was not created (non-critical)"
        log_info "Base image is ready at: $BASE_IMAGE_PATH"
        return 0
    fi
    
    # Wait for VM to boot
    log_info "Waiting for VM to start..."
    sleep 10
    
    # Create snapshot
    log_info "Creating snapshot '$snapshot_name'..."
    if sudo virsh snapshot-create-as \
        "$vm_name" \
        "$snapshot_name" \
        "Clean Debian 13 installation" \
        --disk-only \
        --atomic 2>/dev/null; then
        log_info "Snapshot created successfully"
    else
        log_warn "Snapshot creation skipped (disk-only snapshots not supported on this system)"
    fi
    
    # List snapshots if VM exists
    log_info "Available snapshots:"
    if sudo virsh list --all 2>/dev/null | grep -q "$vm_name"; then
        sudo virsh snapshot-list "$vm_name" 2>/dev/null || log_info "No snapshots available"
    else
        log_info "No snapshots available (VM already cleaned up)"
    fi
    
    # Shutdown and remove test VM
    log_info "Cleaning up test VM..."
    sudo virsh destroy "$vm_name" 2>/dev/null || true
    sudo virsh undefine "$vm_name" --snapshots-metadata 2>/dev/null || true
    
    log_info "Base image ready for use at: $BASE_IMAGE_PATH"
}

# Main execution
main() {
    log_info "=== Debian 13 KVM Base Image Build ==="
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Base image name: $BASE_IMAGE_NAME"
    
    # Check if image already exists
    if [[ -f "$BASE_IMAGE_PATH" ]]; then
        log_warn "Base image already exists at $BASE_IMAGE_PATH"
        read -p "Do you want to rebuild? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping build"
            verify_base_image
            exit 0
        fi
        log_info "Removing existing image..."
        rm -f "$BASE_IMAGE_PATH"
    fi
    
    check_prerequisites || exit 1
    build_base_image || exit 1
    verify_base_image || exit 1
    create_snapshot || exit 1
    
    log_info "=== Build Complete ==="
    log_info "Base image location: $BASE_IMAGE_PATH"
    log_info "Use this image for KVM E2E testing"
}

# Run main function
main "$@"
