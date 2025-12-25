#!/bin/bash
# rollback.sh - Rollback engine for error recovery
# Parses transaction log, executes rollback commands in reverse order, verifies system state

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/core/logger.sh
source "${SCRIPT_DIR}/logger.sh"
# shellcheck source=lib/core/transaction.sh
source "${SCRIPT_DIR}/transaction.sh"

# Rollback state
ROLLBACK_IN_PROGRESS=false
ROLLBACK_ERRORS=0

# Initialize rollback system
rollback_init() {
  log_debug "Rollback system initialized"
  transaction_init
}

# Execute rollback for all transactions
# Returns: 0 on success, 1 on failure
rollback_execute() {
  log_info "Starting rollback process..."
  log_separator "="
  
  ROLLBACK_IN_PROGRESS=true
  ROLLBACK_ERRORS=0
  
  local transaction_count
  transaction_count=$(transaction_count)
  
  if [[ $transaction_count -eq 0 ]]; then
    log_info "No transactions to rollback"
    ROLLBACK_IN_PROGRESS=false
    return 0
  fi
  
  log_info "Rolling back $transaction_count transaction(s) in LIFO order"
  
  # Backup transaction log before rollback
  transaction_backup "${TRANSACTION_LOG}.pre-rollback"
  
  local commands
  local cmd
  local count=0
  
  # Get rollback commands in LIFO order
  mapfile -t commands < <(transaction_get_rollback_commands)
  
  for cmd in "${commands[@]}"; do
    count=$((count + 1))
    
    log_info "[$count/$transaction_count] Executing rollback: $cmd"
    
    if ! rollback_execute_command "$cmd"; then
      log_error "Rollback command failed: $cmd"
      ROLLBACK_ERRORS=$((ROLLBACK_ERRORS + 1))
      
      # Continue with other rollback commands even if one fails
      log_warning "Continuing with remaining rollback operations"
    else
      log_debug "Rollback command succeeded: $cmd"
    fi
  done
  
  ROLLBACK_IN_PROGRESS=false
  
  if [[ $ROLLBACK_ERRORS -gt 0 ]]; then
    log_error "Rollback completed with $ROLLBACK_ERRORS error(s)"
    log_warning "System may not be fully restored to clean state"
    return 1
  fi
  
  log_info "Rollback completed successfully"
  log_separator "="
  
  return 0
}

# Execute a single rollback command
# Args: $1 - rollback command
# Returns: 0 on success, 1 on failure
rollback_execute_command() {
  local cmd="$1"
  
  if [[ -z "$cmd" ]]; then
    log_error "Empty rollback command"
    return 1
  fi
  
  # Execute command and capture output
  local output
  local exit_code
  
  if output=$(eval "$cmd" 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi
  
  if [[ $exit_code -ne 0 ]]; then
    log_error "Rollback command failed with exit code $exit_code"
    if [[ -n "$output" ]]; then
      log_error "Command output: $output"
    fi
    return 1
  fi
  
  if [[ -n "$output" ]]; then
    log_debug "Command output: $output"
  fi
  
  return 0
}

# Verify system state after rollback
# Returns: 0 if clean, 1 if residual artifacts found
rollback_verify() {
  log_info "Verifying system state after rollback..."
  
  local issues=0
  
  # Check for residual directories
  local dirs_to_check=(
    "/opt/vps-provision"
    "/var/vps-provision"
  )
  
  local dir
  for dir in "${dirs_to_check[@]}"; do
    if [[ -d "$dir" ]]; then
      local contents
      contents=$(find "$dir" -mindepth 1 2>/dev/null | wc -l)
      if [[ $contents -gt 0 ]]; then
        log_warning "Directory not empty after rollback: $dir"
        issues=$((issues + 1))
      fi
    fi
  done
  
  # Check for residual users
  if id "devuser" &>/dev/null; then
    log_warning "Developer user still exists after rollback"
    issues=$((issues + 1))
  fi
  
  # Check for residual services
  local services_to_check=("xrdp" "lightdm")
  local service
  for service in "${services_to_check[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
      log_warning "Service still active after rollback: $service"
      issues=$((issues + 1))
    fi
  done
  
  if [[ $issues -gt 0 ]]; then
    log_warning "Rollback verification found $issues issue(s)"
    return 1
  fi
  
  log_info "Rollback verification passed: system state is clean"
  return 0
}

# Perform complete rollback with verification
# Returns: 0 on success, 1 on failure
rollback_complete() {
  log_section "System Rollback"
  
  if ! rollback_execute; then
    log_error "Rollback execution failed"
    return 1
  fi
  
  if ! rollback_verify; then
    log_warning "Rollback verification detected issues"
    log_info "Manual cleanup may be required"
    return 1
  fi
  
  # Clear transaction log after successful rollback
  transaction_clear
  
  log_info "Complete rollback finished successfully"
  return 0
}

# Rollback specific phase
# Args: $1 - phase name
rollback_phase() {
  local phase_name="$1"
  
  log_info "Rolling back phase: $phase_name"
  
  # This is a simplified version - in practice, we'd need to track
  # which transactions belong to which phase
  log_warning "Phase-specific rollback not yet implemented"
  log_info "Use full rollback instead"
  
  return 1
}

# Dry-run rollback (show what would be done)
# Returns: list of rollback commands
rollback_dry_run() {
  log_info "Rollback Dry-Run:"
  echo "Rollback Dry-Run:"
  log_info "The following commands would be executed (in order):"
  echo "The following commands would be executed (in order):"
  log_separator "-"
  echo "----------------------------------------"
  
  local transaction_count
  transaction_count=$(transaction_count)
  
  if [[ $transaction_count -eq 0 ]]; then
    log_info "  (no transactions to rollback)"
    echo "  (no transactions to rollback)"
    return 0
  fi
  
  local commands
  local cmd
  local count=0
  
  mapfile -t commands < <(transaction_get_rollback_commands)
  
  for cmd in "${commands[@]}"; do
    count=$((count + 1))
    log_info "  [$count] $cmd"
    echo "  [$count] $cmd"
  done
  
  log_separator "-"
  echo "----------------------------------------"
  log_info "Total rollback commands: $count"
  echo "Total rollback commands: $count"
  
  return 0
}

# Check if rollback is currently in progress
rollback_is_in_progress() {
  if [[ "$ROLLBACK_IN_PROGRESS" == "true" ]]; then
    return 0
  fi
  return 1
}

# Get rollback error count
rollback_get_error_count() {
  echo "$ROLLBACK_ERRORS"
}

# Get rollback statistics
# Returns: JSON string with stats
rollback_get_stats() {
  local total_count
  local error_count
  
  total_count=$(transaction_count 2>/dev/null || echo "0")
  error_count="$ROLLBACK_ERRORS"
  
  echo "{\"total\":${total_count},\"errors\":${error_count},\"in_progress\":${ROLLBACK_IN_PROGRESS}}"
}

# Clean up rollback artifacts
rollback_cleanup() {
  log_debug "Cleaning up rollback artifacts"
  
  # Remove backup transaction logs older than 7 days
  find "$(dirname "$TRANSACTION_LOG")" -name "*.pre-rollback" -mtime +7 -delete 2>/dev/null || true
  
  log_debug "Rollback cleanup complete"
}

# Interactive rollback with confirmation
rollback_interactive() {
  log_warning "This will attempt to rollback all provisioning changes"
  log_warning "System will be restored to pre-provisioning state"
  
  transaction_show_summary
  
  echo ""
  read -rp "Continue with rollback? (yes/no): " response
  
  case "${response,,}" in
    yes|y)
      log_info "Starting rollback..."
      rollback_complete
      ;;
    *)
      log_info "Rollback cancelled by user"
      return 1
      ;;
  esac
}
