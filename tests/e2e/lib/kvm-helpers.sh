#!/bin/bash
# KVM Helper Functions for E2E Testing
# Provides VM lifecycle management, networking, and resource utilities

set -euo pipefail

# Configuration
readonly DEFAULT_MEMORY="4096"
readonly DEFAULT_VCPUS="2"
readonly DEFAULT_DISK_SIZE="25G"
readonly DEFAULT_BASE_IMAGE="/var/lib/libvirt/images/debian-13-base"
readonly SSH_TIMEOUT=300  # 5 minutes
readonly BOOT_TIMEOUT=120  # 2 minutes

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Logging functions
kvm_log_info() {
    echo -e "${GREEN}[KVM]${NC} $*"
}

kvm_log_warn() {
    echo -e "${YELLOW}[KVM]${NC} $*"
}

kvm_log_error() {
    echo -e "${RED}[KVM]${NC} $*" >&2
}

# Check if KVM is available
kvm_check_available() {
    if [[ ! -e /dev/kvm ]]; then
        kvm_log_error "KVM not available. Check: lsmod | grep kvm"
        return 1
    fi
    
    if ! command -v virsh &>/dev/null; then
        kvm_log_error "virsh not found. Install: sudo apt-get install libvirt-clients"
        return 1
    fi
    
    return 0
}

# Generate unique VM name
kvm_generate_vm_name() {
    local prefix="${1:-vps-test}"
    echo "${prefix}-$(date +%s)-$$"
}

# Create overlay disk from base image
kvm_create_overlay_disk() {
    local base_image="$1"
    local overlay_path="$2"
    
    kvm_log_info "Creating overlay disk from base image..."
    
    if [[ ! -f "$base_image" ]]; then
        kvm_log_error "Base image not found: $base_image"
        return 1
    fi
    
    qemu-img create -f qcow2 -F qcow2 \
        -b "$base_image" \
        "$overlay_path" >/dev/null
    
    if [[ ! -f "$overlay_path" ]]; then
        kvm_log_error "Failed to create overlay disk"
        return 1
    fi
    
    kvm_log_info "Overlay disk created: $overlay_path"
}

# Create cloud-init ISO for VM configuration
kvm_create_cloudinit_iso() {
    local user_data="$1"
    local meta_data="$2"
    local output_iso="$3"
    
    kvm_log_info "Creating cloud-init ISO..."
    
    local temp_dir
    temp_dir=$(mktemp -d)
    
    cp "$user_data" "${temp_dir}/user-data"
    cp "$meta_data" "${temp_dir}/meta-data"
    
    if command -v genisoimage &>/dev/null; then
        genisoimage -output "$output_iso" \
            -volid cidata -joliet -rock \
            "${temp_dir}/user-data" "${temp_dir}/meta-data" >/dev/null 2>&1
    elif command -v mkisofs &>/dev/null; then
        mkisofs -output "$output_iso" \
            -volid cidata -joliet -rock \
            "${temp_dir}/user-data" "${temp_dir}/meta-data" >/dev/null 2>&1
    else
        kvm_log_error "Neither genisoimage nor mkisofs found"
        rm -rf "$temp_dir"
        return 1
    fi
    
    rm -rf "$temp_dir"
    kvm_log_info "Cloud-init ISO created: $output_iso"
}

# Create and start VM
kvm_create_vm() {
    local vm_name="$1"
    local disk_path="$2"
    local cloudinit_iso="$3"
    local memory="${4:-$DEFAULT_MEMORY}"
    local vcpus="${5:-$DEFAULT_VCPUS}"
    
    kvm_log_info "Creating VM: $vm_name"
    
    virt-install \
        --name "$vm_name" \
        --memory "$memory" \
        --vcpus "$vcpus" \
        --disk path="$disk_path",format=qcow2,bus=virtio \
        --disk path="$cloudinit_iso",device=cdrom \
        --import \
        --os-variant debian12 \
        --network network=default,model=virtio \
        --graphics none \
        --noautoconsole \
        --noreboot &>/dev/null
    
    kvm_log_info "VM created and starting..."
}

# Get VM IP address
kvm_get_vm_ip() {
    local vm_name="$1"
    local timeout="${2:-$BOOT_TIMEOUT}"
    local elapsed=0
    
    kvm_log_info "Waiting for VM IP address..."
    
    while (( elapsed < timeout )); do
        local ip
        ip=$(virsh domifaddr "$vm_name" 2>/dev/null | \
            awk '/ipv4/ {gsub(/\/.*/, "", $4); print $4}' | head -n1)
        
        if [[ -n "$ip" ]]; then
            kvm_log_info "VM IP address: $ip"
            echo "$ip"
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    kvm_log_error "Timeout waiting for VM IP address"
    return 1
}

# Wait for SSH to become available
kvm_wait_for_ssh() {
    local ip="$1"
    local username="$2"
    local ssh_key="${3:-}"
    local timeout="${4:-$SSH_TIMEOUT}"
    local elapsed=0
    
    kvm_log_info "Waiting for SSH access to $ip..."
    
    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
    if [[ -n "$ssh_key" ]]; then
        ssh_opts="$ssh_opts -i $ssh_key"
    fi
    
    while (( elapsed < timeout )); do
        if ssh $ssh_opts "${username}@${ip}" "exit" &>/dev/null; then
            kvm_log_info "SSH access established"
            return 0
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    kvm_log_error "Timeout waiting for SSH access"
    return 1
}

# Copy file to VM via SSH
kvm_copy_to_vm() {
    local ip="$1"
    local username="$2"
    local local_path="$3"
    local remote_path="$4"
    local ssh_key="${5:-}"
    
    kvm_log_info "Copying $local_path to VM..."
    
    local scp_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    if [[ -n "$ssh_key" ]]; then
        scp_opts="$scp_opts -i $ssh_key"
    fi
    
    if ! scp $scp_opts "$local_path" "${username}@${ip}:${remote_path}"; then
        kvm_log_error "Failed to copy file to VM"
        return 1
    fi
    
    kvm_log_info "File copied successfully"
}

# Execute command in VM via SSH
kvm_exec_in_vm() {
    local ip="$1"
    local username="$2"
    local command="$3"
    local ssh_key="${4:-}"
    
    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    if [[ -n "$ssh_key" ]]; then
        ssh_opts="$ssh_opts -i $ssh_key"
    fi
    
    ssh $ssh_opts "${username}@${ip}" "$command"
}

# Check if VM exists
kvm_vm_exists() {
    local vm_name="$1"
    virsh list --all --name | grep -q "^${vm_name}$"
}

# Check if VM is running
kvm_vm_is_running() {
    local vm_name="$1"
    virsh list --state-running --name | grep -q "^${vm_name}$"
}

# Shutdown VM gracefully
kvm_shutdown_vm() {
    local vm_name="$1"
    local timeout="${2:-60}"
    
    if ! kvm_vm_exists "$vm_name"; then
        return 0
    fi
    
    if kvm_vm_is_running "$vm_name"; then
        kvm_log_info "Shutting down VM: $vm_name"
        virsh shutdown "$vm_name" &>/dev/null || true
        
        # Wait for shutdown
        local elapsed=0
        while (( elapsed < timeout )) && kvm_vm_is_running "$vm_name"; do
            sleep 2
            elapsed=$((elapsed + 2))
        done
        
        # Force destroy if still running
        if kvm_vm_is_running "$vm_name"; then
            kvm_log_warn "Forcing VM destruction"
            virsh destroy "$vm_name" &>/dev/null || true
        fi
    fi
}

# Delete VM and associated resources
kvm_delete_vm() {
    local vm_name="$1"
    local delete_disks="${2:-true}"
    
    if ! kvm_vm_exists "$vm_name"; then
        return 0
    fi
    
    kvm_shutdown_vm "$vm_name"
    
    kvm_log_info "Deleting VM: $vm_name"
    
    if [[ "$delete_disks" == "true" ]]; then
        virsh undefine "$vm_name" --remove-all-storage --snapshots-metadata &>/dev/null || \
        virsh undefine "$vm_name" --remove-all-storage &>/dev/null || \
        virsh undefine "$vm_name" &>/dev/null
    else
        virsh undefine "$vm_name" --snapshots-metadata &>/dev/null || \
        virsh undefine "$vm_name" &>/dev/null
    fi
    
    kvm_log_info "VM deleted successfully"
}

# Cleanup function for trap
kvm_cleanup_on_exit() {
    local vm_name="$1"
    local overlay_disk="$2"
    local cloudinit_iso="$3"
    
    kvm_log_info "Cleaning up test resources..."
    
    kvm_delete_vm "$vm_name" false
    
    [[ -f "$overlay_disk" ]] && rm -f "$overlay_disk"
    [[ -f "$cloudinit_iso" ]] && rm -f "$cloudinit_iso"
    
    kvm_log_info "Cleanup complete"
}

# Export functions
export -f kvm_log_info kvm_log_warn kvm_log_error
export -f kvm_check_available kvm_generate_vm_name
export -f kvm_create_overlay_disk kvm_create_cloudinit_iso
export -f kvm_create_vm kvm_get_vm_ip kvm_wait_for_ssh
export -f kvm_copy_to_vm kvm_exec_in_vm
export -f kvm_vm_exists kvm_vm_is_running
export -f kvm_shutdown_vm kvm_delete_vm
export -f kvm_cleanup_on_exit
