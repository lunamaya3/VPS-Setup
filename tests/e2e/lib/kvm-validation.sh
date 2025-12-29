#!/bin/bash
# KVM Test Validation Functions
# Provides validation utilities for VPS provisioning tests

set -euo pipefail

# Source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/kvm-helpers.sh"

# Validate system packages installed
kvm_validate_system_packages() {
    local vm_ip="$1"
    local username="$2"
    local ssh_key="${3:-}"
    
    kvm_log_info "Validating system packages..."
    
    local packages=(
        "build-essential"
        "git"
        "curl"
        "wget"
    )
    
    local missing=()
    for pkg in "${packages[@]}"; do
        if ! kvm_exec_in_vm "$vm_ip" "$username" \
            "dpkg -l | grep -q \"^ii  $pkg\"" "$ssh_key" 2>/dev/null; then
            missing+=("$pkg")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        kvm_log_error "Missing packages: ${missing[*]}"
        return 1
    fi
    
    kvm_log_info "System packages validated"
    return 0
}

# Validate desktop environment
kvm_validate_desktop() {
    local vm_ip="$1"
    local username="$2"
    local ssh_key="${3:-}"
    
    kvm_log_info "Validating desktop environment..."
    
    # Check XFCE installed
    if ! kvm_exec_in_vm "$vm_ip" "$username" \
        "dpkg -l | grep -q xfce4" "$ssh_key" 2>/dev/null; then
        kvm_log_error "XFCE not installed"
        return 1
    fi
    
    # Check X11 display manager
    if ! kvm_exec_in_vm "$vm_ip" "$username" \
        "systemctl is-active --quiet lightdm || systemctl is-active --quiet gdm3" \
        "$ssh_key" 2>/dev/null; then
        kvm_log_warn "Display manager not running (may be expected)"
    fi
    
    kvm_log_info "Desktop environment validated"
    return 0
}

# Validate RDP server
kvm_validate_rdp() {
    local vm_ip="$1"
    local username="$2"
    local ssh_key="${3:-}"
    
    kvm_log_info "Validating RDP server..."
    
    # Check xrdp installed
    if ! kvm_exec_in_vm "$vm_ip" "$username" \
        "dpkg -l | grep -q \"^ii  xrdp\"" "$ssh_key" 2>/dev/null; then
        kvm_log_error "xrdp not installed"
        return 1
    fi
    
    # Check xrdp service running
    if ! kvm_exec_in_vm "$vm_ip" "$username" \
        "systemctl is-active --quiet xrdp" "$ssh_key" 2>/dev/null; then
        kvm_log_error "xrdp service not running"
        return 1
    fi
    
    # Check xrdp listening on port 3389
    if ! kvm_exec_in_vm "$vm_ip" "$username" \
        "ss -tlnp | grep -q ':3389'" "$ssh_key" 2>/dev/null; then
        kvm_log_error "xrdp not listening on port 3389"
        return 1
    fi
    
    kvm_log_info "RDP server validated"
    return 0
}

# Validate IDE installation
kvm_validate_ide() {
    local vm_ip="$1"
    local username="$2"
    local ide_name="$3"
    local ssh_key="${4:-}"
    
    kvm_log_info "Validating $ide_name installation..."
    
    case "$ide_name" in
        vscode)
            if ! kvm_exec_in_vm "$vm_ip" "$username" \
                "command -v code &>/dev/null" "$ssh_key" 2>/dev/null; then
                kvm_log_error "VSCode not installed"
                return 1
            fi
            ;;
        cursor)
            if ! kvm_exec_in_vm "$vm_ip" "$username" \
                "command -v cursor &>/dev/null || test -f /usr/local/bin/cursor" \
                "$ssh_key" 2>/dev/null; then
                kvm_log_error "Cursor not installed"
                return 1
            fi
            ;;
        antigravity)
            if ! kvm_exec_in_vm "$vm_ip" "$username" \
                "test -d /opt/antigravity" "$ssh_key" 2>/dev/null; then
                kvm_log_error "Antigravity not installed"
                return 1
            fi
            ;;
        *)
            kvm_log_error "Unknown IDE: $ide_name"
            return 1
            ;;
    esac
    
    kvm_log_info "$ide_name validated"
    return 0
}

# Validate all IDEs
kvm_validate_all_ides() {
    local vm_ip="$1"
    local username="$2"
    local ssh_key="${3:-}"
    
    kvm_log_info "Validating IDE installations..."
    
    local ides=("vscode" "cursor" "antigravity")
    local failed=()
    
    for ide in "${ides[@]}"; do
        if ! kvm_validate_ide "$vm_ip" "$username" "$ide" "$ssh_key"; then
            failed+=("$ide")
        fi
    done
    
    if [[ ${#failed[@]} -gt 0 ]]; then
        kvm_log_error "Failed IDE validation: ${failed[*]}"
        return 1
    fi
    
    kvm_log_info "All IDEs validated"
    return 0
}

# Validate user configuration
kvm_validate_user() {
    local vm_ip="$1"
    local username="$2"
    local ssh_key="${3:-}"
    
    kvm_log_info "Validating user configuration..."
    
    # Check user exists
    if ! kvm_exec_in_vm "$vm_ip" "$username" \
        "id $username &>/dev/null" "$ssh_key" 2>/dev/null; then
        kvm_log_error "User $username does not exist"
        return 1
    fi
    
    # Check sudo access
    if ! kvm_exec_in_vm "$vm_ip" "$username" \
        "sudo -n true" "$ssh_key" 2>/dev/null; then
        kvm_log_error "User $username does not have passwordless sudo"
        return 1
    fi
    
    kvm_log_info "User configuration validated"
    return 0
}

# Run complete validation suite
kvm_validate_provisioning() {
    local vm_ip="$1"
    local username="$2"
    local ssh_key="${3:-}"
    
    kvm_log_info "=== Starting Complete Validation ==="
    
    local failed=()
    
    # Validate user
    if ! kvm_validate_user "$vm_ip" "$username" "$ssh_key"; then
        failed+=("User configuration")
    fi
    
    # Validate system packages
    if ! kvm_validate_system_packages "$vm_ip" "$username" "$ssh_key"; then
        failed+=("System packages")
    fi
    
    # Validate desktop
    if ! kvm_validate_desktop "$vm_ip" "$username" "$ssh_key"; then
        failed+=("Desktop environment")
    fi
    
    # Validate RDP
    if ! kvm_validate_rdp "$vm_ip" "$username" "$ssh_key"; then
        failed+=("RDP server")
    fi
    
    # Validate IDEs
    if ! kvm_validate_all_ides "$vm_ip" "$username" "$ssh_key"; then
        failed+=("IDE installations")
    fi
    
    # Summary
    if [[ ${#failed[@]} -eq 0 ]]; then
        kvm_log_info "=== All Validations PASSED ==="
        return 0
    else
        kvm_log_error "=== Validation FAILED ==="
        kvm_log_error "Failed components: ${failed[*]}"
        return 1
    fi
}

# Generate test report
kvm_generate_test_report() {
    local output_file="$1"
    local vm_name="$2"
    local vm_ip="$3"
    local start_time="$4"
    local end_time="$5"
    local status="$6"
    
    local duration=$((end_time - start_time))
    
    cat > "$output_file" <<EOF
# KVM E2E Test Report

## Test Information
- **VM Name**: $vm_name
- **VM IP**: $vm_ip
- **Start Time**: $(date -d "@$start_time" '+%Y-%m-%d %H:%M:%S')
- **End Time**: $(date -d "@$end_time" '+%Y-%m-%d %H:%M:%S')
- **Duration**: ${duration}s ($(printf '%dm %ds' $((duration/60)) $((duration%60))))
- **Status**: $status

## Test Results
EOF
    
    if [[ "$status" == "PASSED" ]]; then
        cat >> "$output_file" <<EOF

✅ All validation checks passed
- User configuration: PASSED
- System packages: PASSED
- Desktop environment: PASSED
- RDP server: PASSED
- IDE installations: PASSED
EOF
    else
        cat >> "$output_file" <<EOF

❌ Test failed - see logs for details
EOF
    fi
    
    kvm_log_info "Test report generated: $output_file"
}

# Export functions
export -f kvm_validate_system_packages kvm_validate_desktop
export -f kvm_validate_rdp kvm_validate_ide
export -f kvm_validate_all_ides kvm_validate_user
export -f kvm_validate_provisioning kvm_generate_test_report
