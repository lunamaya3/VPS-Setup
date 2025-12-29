#!/bin/bash
# KVM Snapshot Management for E2E Testing
# Provides snapshot creation, restoration, and management utilities

set -euo pipefail

# Source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/kvm-helpers.sh"

# Create VM snapshot
kvm_snapshot_create() {
    local vm_name="$1"
    local snapshot_name="$2"
    local description="${3:-Automated test snapshot}"
    
    kvm_log_info "Creating snapshot: $snapshot_name"
    
    if ! kvm_vm_exists "$vm_name"; then
        kvm_log_error "VM does not exist: $vm_name"
        return 1
    fi
    
    # Create internal snapshot (memory + disk state)
    if virsh snapshot-create-as "$vm_name" \
        "$snapshot_name" \
        "$description" \
        --atomic; then
        kvm_log_info "Snapshot created successfully"
        return 0
    else
        kvm_log_error "Failed to create snapshot"
        return 1
    fi
}

# Restore VM to snapshot
kvm_snapshot_restore() {
    local vm_name="$1"
    local snapshot_name="$2"
    
    kvm_log_info "Restoring snapshot: $snapshot_name"
    
    if ! kvm_vm_exists "$vm_name"; then
        kvm_log_error "VM does not exist: $vm_name"
        return 1
    fi
    
    if ! kvm_snapshot_exists "$vm_name" "$snapshot_name"; then
        kvm_log_error "Snapshot does not exist: $snapshot_name"
        return 1
    fi
    
    # Shutdown VM if running
    if kvm_vm_is_running "$vm_name"; then
        kvm_shutdown_vm "$vm_name" 30
    fi
    
    # Restore snapshot
    if virsh snapshot-revert "$vm_name" "$snapshot_name" --running; then
        kvm_log_info "Snapshot restored successfully"
        sleep 5  # Allow VM to stabilize
        return 0
    else
        kvm_log_error "Failed to restore snapshot"
        return 1
    fi
}

# Check if snapshot exists
kvm_snapshot_exists() {
    local vm_name="$1"
    local snapshot_name="$2"
    
    virsh snapshot-list "$vm_name" --name 2>/dev/null | grep -q "^${snapshot_name}$"
}

# List all snapshots for VM
kvm_snapshot_list() {
    local vm_name="$1"
    
    if ! kvm_vm_exists "$vm_name"; then
        kvm_log_error "VM does not exist: $vm_name"
        return 1
    fi
    
    kvm_log_info "Snapshots for $vm_name:"
    virsh snapshot-list "$vm_name" --tree
}

# Delete specific snapshot
kvm_snapshot_delete() {
    local vm_name="$1"
    local snapshot_name="$2"
    
    kvm_log_info "Deleting snapshot: $snapshot_name"
    
    if ! kvm_vm_exists "$vm_name"; then
        kvm_log_error "VM does not exist: $vm_name"
        return 1
    fi
    
    if ! kvm_snapshot_exists "$vm_name" "$snapshot_name"; then
        kvm_log_warn "Snapshot does not exist: $snapshot_name"
        return 0
    fi
    
    if virsh snapshot-delete "$vm_name" "$snapshot_name"; then
        kvm_log_info "Snapshot deleted successfully"
        return 0
    else
        kvm_log_error "Failed to delete snapshot"
        return 1
    fi
}

# Delete all snapshots for VM
kvm_snapshot_delete_all() {
    local vm_name="$1"
    
    kvm_log_info "Deleting all snapshots for $vm_name"
    
    if ! kvm_vm_exists "$vm_name"; then
        kvm_log_warn "VM does not exist: $vm_name"
        return 0
    fi
    
    local snapshots
    snapshots=$(virsh snapshot-list "$vm_name" --name 2>/dev/null || echo "")
    
    if [[ -z "$snapshots" ]]; then
        kvm_log_info "No snapshots to delete"
        return 0
    fi
    
    while IFS= read -r snapshot; do
        [[ -z "$snapshot" ]] && continue
        kvm_snapshot_delete "$vm_name" "$snapshot"
    done <<< "$snapshots"
    
    kvm_log_info "All snapshots deleted"
}

# Get snapshot info
kvm_snapshot_info() {
    local vm_name="$1"
    local snapshot_name="$2"
    
    if ! kvm_vm_exists "$vm_name"; then
        kvm_log_error "VM does not exist: $vm_name"
        return 1
    fi
    
    if ! kvm_snapshot_exists "$vm_name" "$snapshot_name"; then
        kvm_log_error "Snapshot does not exist: $snapshot_name"
        return 1
    fi
    
    virsh snapshot-info "$vm_name" "$snapshot_name"
}

# Create snapshot after successful provisioning step
kvm_snapshot_checkpoint() {
    local vm_name="$1"
    local checkpoint_name="$2"
    local description="${3:-Checkpoint: $checkpoint_name}"
    
    kvm_log_info "Creating checkpoint snapshot: $checkpoint_name"
    
    # Ensure VM is running
    if ! kvm_vm_is_running "$vm_name"; then
        kvm_log_error "VM must be running to create checkpoint"
        return 1
    fi
    
    # Delete existing checkpoint if present
    if kvm_snapshot_exists "$vm_name" "$checkpoint_name"; then
        kvm_log_info "Removing existing checkpoint"
        kvm_snapshot_delete "$vm_name" "$checkpoint_name"
    fi
    
    # Create new checkpoint
    kvm_snapshot_create "$vm_name" "$checkpoint_name" "$description"
}

# Restore to latest checkpoint
kvm_snapshot_restore_latest() {
    local vm_name="$1"
    
    kvm_log_info "Restoring to latest snapshot"
    
    if ! kvm_vm_exists "$vm_name"; then
        kvm_log_error "VM does not exist: $vm_name"
        return 1
    fi
    
    local latest_snapshot
    latest_snapshot=$(virsh snapshot-list "$vm_name" --name 2>/dev/null | tail -n1)
    
    if [[ -z "$latest_snapshot" ]]; then
        kvm_log_error "No snapshots available"
        return 1
    fi
    
    kvm_snapshot_restore "$vm_name" "$latest_snapshot"
}

# Export functions
export -f kvm_snapshot_create kvm_snapshot_restore
export -f kvm_snapshot_exists kvm_snapshot_list
export -f kvm_snapshot_delete kvm_snapshot_delete_all
export -f kvm_snapshot_info kvm_snapshot_checkpoint
export -f kvm_snapshot_restore_latest
