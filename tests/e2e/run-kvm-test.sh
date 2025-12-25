#!/bin/bash
# KVM-based E2E Test Runner for VPS Provisioning Tool
# Executes provisioning tests in real KVM VMs with snapshot support

set -euo pipefail

# Script directory and project root
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source helper libraries
source "${SCRIPT_DIR}/lib/kvm-helpers.sh"
source "${SCRIPT_DIR}/lib/kvm-snapshot.sh"
source "${SCRIPT_DIR}/lib/kvm-validation.sh"

# Configuration
readonly BASE_IMAGE="${BASE_IMAGE:-/var/lib/libvirt/images/debian-13-base}"
readonly VM_NAME=$(kvm_generate_vm_name "vps-test")
readonly OVERLAY_DISK="/tmp/${VM_NAME}-overlay.qcow2"
readonly CLOUDINIT_ISO="/tmp/${VM_NAME}-cloudinit.iso"
readonly TEST_USER="${TEST_USER:-testuser}"
readonly TEST_TIMEOUT="${TEST_TIMEOUT:-1800}"  # 30 minutes
readonly REPORT_FILE="/tmp/${VM_NAME}-report.md"

# Test state tracking
declare -g VM_IP=""
declare -g START_TIME
declare -g END_TIME

# Cleanup function
cleanup() {
    local exit_code=$?
    END_TIME=$(date +%s)
    
    kvm_log_info "Starting cleanup..."
    
    # Generate test report
    local status="FAILED"
    [[ $exit_code -eq 0 ]] && status="PASSED"
    kvm_generate_test_report "$REPORT_FILE" "$VM_NAME" "$VM_IP" \
        "$START_TIME" "$END_TIME" "$status"
    
    # Cleanup VM and resources
    kvm_cleanup_on_exit "$VM_NAME" "$OVERLAY_DISK" "$CLOUDINIT_ISO"
    
    # Display report
    if [[ -f "$REPORT_FILE" ]]; then
        cat "$REPORT_FILE"
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        kvm_log_info "=== TEST PASSED ==="
    else
        kvm_log_error "=== TEST FAILED ==="
    fi
    
    exit $exit_code
}

trap cleanup EXIT INT TERM

# Check prerequisites
check_prerequisites() {
    kvm_log_info "Checking prerequisites..."
    
    # Check KVM availability
    if ! kvm_check_available; then
        kvm_log_error "KVM not available"
        exit 1
    fi
    
    # Check base image
    if [[ ! -f "$BASE_IMAGE" ]]; then
        kvm_log_error "Base image not found: $BASE_IMAGE"
        kvm_log_error "Build base image first: tests/e2e/packer/build-base-image.sh"
        exit 1
    fi
    
    # Check provisioning script
    if [[ ! -f "${PROJECT_ROOT}/bin/vps-provision" ]]; then
        kvm_log_error "Provisioning script not found: ${PROJECT_ROOT}/bin/vps-provision"
        exit 1
    fi
    
    # Check required tools
    local missing=()
    for tool in qemu-img virsh virt-install genisoimage; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        kvm_log_error "Missing required tools: ${missing[*]}"
        kvm_log_error "Install with: sudo apt-get install qemu-utils libvirt-clients virtinst genisoimage"
        exit 1
    fi
    
    kvm_log_info "Prerequisites check passed"
}

# Setup test VM
setup_vm() {
    kvm_log_info "Setting up test VM..."
    
    # Create overlay disk
    kvm_create_overlay_disk "$BASE_IMAGE" "$OVERLAY_DISK"
    
    # Create cloud-init ISO
    kvm_create_cloudinit_iso \
        "${SCRIPT_DIR}/cloud-init/user-data.yml" \
        "${SCRIPT_DIR}/cloud-init/meta-data.yml" \
        "$CLOUDINIT_ISO"
    
    # Create and start VM
    kvm_create_vm "$VM_NAME" "$OVERLAY_DISK" "$CLOUDINIT_ISO"
    
    # Get VM IP address
    VM_IP=$(kvm_get_vm_ip "$VM_NAME")
    
    # Wait for SSH access
    kvm_wait_for_ssh "$VM_IP" "$TEST_USER"
    
    kvm_log_info "Test VM ready: $VM_IP"
}

# Create initial snapshot
create_initial_snapshot() {
    kvm_log_info "Creating initial snapshot..."
    
    kvm_snapshot_checkpoint "$VM_NAME" "clean-boot" \
        "Clean boot state before provisioning"
}

# Copy provisioning files to VM
copy_provisioning_files() {
    kvm_log_info "Copying provisioning files to VM..."
    
    # Create remote directory
    kvm_exec_in_vm "$VM_IP" "$TEST_USER" "mkdir -p /home/${TEST_USER}/vps-provision"
    
    # Copy entire project directory
    kvm_log_info "Copying project files (this may take a moment)..."
    rsync -az --progress \
        -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        --exclude='.git' \
        --exclude='tests/e2e/packer' \
        --exclude='*.qcow2' \
        --exclude='*.iso' \
        "${PROJECT_ROOT}/" \
        "${TEST_USER}@${VM_IP}:/home/${TEST_USER}/vps-provision/"
    
    kvm_log_info "Files copied successfully"
}

# Execute provisioning script
execute_provisioning() {
    kvm_log_info "Executing provisioning script..."
    
    # Set executable permissions
    kvm_exec_in_vm "$VM_IP" "$TEST_USER" \
        "chmod +x /home/${TEST_USER}/vps-provision/bin/vps-provision"
    
    # Run provisioning with timeout
    kvm_log_info "Starting provisioning (timeout: ${TEST_TIMEOUT}s)..."
    
    local provision_cmd="cd /home/${TEST_USER}/vps-provision && sudo ./bin/vps-provision --non-interactive"
    
    if timeout "$TEST_TIMEOUT" \
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${TEST_USER}@${VM_IP}" "$provision_cmd"; then
        kvm_log_info "Provisioning completed successfully"
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            kvm_log_error "Provisioning timed out after ${TEST_TIMEOUT}s"
        else
            kvm_log_error "Provisioning failed with exit code $exit_code"
        fi
        return 1
    fi
}

# Create post-provisioning snapshot
create_provisioned_snapshot() {
    kvm_log_info "Creating post-provisioning snapshot..."
    
    kvm_snapshot_checkpoint "$VM_NAME" "provisioned" \
        "Fully provisioned state"
}

# Validate provisioning results
validate_results() {
    kvm_log_info "Validating provisioning results..."
    
    if kvm_validate_provisioning "$VM_IP" "$TEST_USER"; then
        kvm_log_info "Validation passed"
        return 0
    else
        kvm_log_error "Validation failed"
        return 1
    fi
}

# Main test execution
main() {
    START_TIME=$(date +%s)
    
    kvm_log_info "========================================"
    kvm_log_info "KVM E2E Test for VPS Provisioning Tool"
    kvm_log_info "========================================"
    kvm_log_info "VM Name: $VM_NAME"
    kvm_log_info "Base Image: $BASE_IMAGE"
    kvm_log_info "Test Timeout: ${TEST_TIMEOUT}s"
    
    check_prerequisites
    setup_vm
    create_initial_snapshot
    copy_provisioning_files
    execute_provisioning
    create_provisioned_snapshot
    validate_results
    
    kvm_log_info "Test completed successfully"
    exit 0
}

# Execute main function
main "$@"
