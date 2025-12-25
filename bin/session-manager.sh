#!/bin/bash
# RDP Session Management Utility
# Provides commands to list, monitor, and cleanup RDP sessions
#
# Usage:
#   session-manager.sh list                  # List all active sessions
#   session-manager.sh status                # Show resource usage per session
#   session-manager.sh cleanup [--force]     # Cleanup orphaned sessions
#   session-manager.sh kill <display>        # Terminate specific session
#   session-manager.sh stats                 # Show session statistics
#
# Exit codes:
#   0 - Success
#   1 - Error or invalid usage
#   2 - No sessions found

set -euo pipefail

# Configuration
readonly SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR
LIB_DIR="$(dirname "$(dirname "${SCRIPT_DIR}")")"
readonly SESSION_MONITOR="${LIB_DIR}/lib/utils/session-monitor.py"

# Colors for output
readonly COLOR_RESET="\033[0m"
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_YELLOW="\033[0;33m"
readonly COLOR_RED="\033[0;31m"
readonly COLOR_BLUE="\033[0;34m"

# Helper: Print colored message
# Args: color, message
print_color() {
  local color="$1"
  shift
  echo -e "${color}$*${COLOR_RESET}"
}

# Helper: Print usage information
print_usage() {
  cat <<EOF
RDP Session Management Utility

Usage:
  $(basename "$0") <command> [options]

Commands:
  list                    List all active RDP sessions
  status                  Show resource usage for each session
  cleanup [--force]       Remove orphaned sessions (requires --force for cleanup)
  kill <display>          Terminate session by display number (e.g., :10)
  stats                   Show session statistics and health
  help                    Show this help message

Examples:
  $(basename "$0") list
  $(basename "$0") status
  $(basename "$0") cleanup --force
  $(basename "$0") kill :10
  $(basename "$0") stats

Exit Codes:
  0 - Success
  1 - Error or invalid usage
  2 - No sessions found
EOF
}

# Command: list
# Lists all active RDP sessions
cmd_list() {
  print_color "${COLOR_BLUE}" "=== Active RDP Sessions ==="
  echo

  # Get list of Xorg processes (xrdp sessions)
  local session_count=0

  # shellcheck disable=SC2009
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi

    # Parse ps output: user, pid, cpu%, mem%, display
    local user
    user=$(echo "$line" | awk '{print $1}')
    local pid
    pid=$(echo "$line" | awk '{print $2}')
    local cpu
    cpu=$(echo "$line" | awk '{print $3}')
    local mem
    mem=$(echo "$line" | awk '{print $4}')
    local display
    display=$(echo "$line" | grep -oP ':\d+' | head -1)

    if [[ -n "${display}" ]]; then
      printf "%-15s %-10s %-8s %-8s %-8s\n" \
        "${user}" "${display}" "${pid}" "${cpu}%" "${mem}%"
      ((session_count++))
    fi

  done < <(ps aux | grep '[X]org.*:[0-9]' || true)

  if [[ ${session_count} -eq 0 ]]; then
    print_color "${COLOR_YELLOW}" "No active RDP sessions found"
    return 2
  fi

  echo
  print_color "${COLOR_GREEN}" "Total sessions: ${session_count}"
  return 0
}

# Command: status
# Shows detailed resource usage for each session
cmd_status() {
  print_color "${COLOR_BLUE}" "=== RDP Session Resource Status ==="
  echo

  # Use session monitor utility
  if [[ ! -x "${SESSION_MONITOR}" ]]; then
    print_color "${COLOR_RED}" "Error: Session monitor utility not found: ${SESSION_MONITOR}"
    return 1
  fi

  python3 "${SESSION_MONITOR}"
  return $?
}

# Command: stats
# Shows session statistics and health
cmd_stats() {
  print_color "${COLOR_BLUE}" "=== RDP Session Statistics ==="
  echo

  # Count sessions
  local session_count
  session_count=$(pgrep -c -f "Xorg.*:[0-9]" || echo 0)

  # System uptime
  local uptime_info
  uptime_info=$(uptime -p)

  # xrdp service status
  local xrdp_status
  if systemctl is-active --quiet xrdp; then
    xrdp_status="active"
  else
    xrdp_status="inactive"
  fi

  local sesman_status
  if systemctl is-active --quiet xrdp-sesman; then
    sesman_status="active"
  else
    sesman_status="inactive"
  fi

  # Memory usage
  local mem_info
  mem_info=$(free -h | grep "Mem:" | awk '{print $3 " / " $2}')

  # Connection count from xrdp logs
  local total_connections=0
  if [[ -f /var/log/xrdp.log ]]; then
    total_connections=$(grep -c "connection ok" /var/log/xrdp.log 2>/dev/null || echo 0)
  fi

  # Display statistics
  echo "System Uptime:        ${uptime_info}"
  echo "Memory Usage:         ${mem_info}"
  echo
  echo "XRDP Status:          ${xrdp_status}"
  echo "Session Manager:      ${sesman_status}"
  echo
  echo "Active Sessions:      ${session_count}"
  echo "Total Connections:    ${total_connections} (since last log rotation)"
  echo

  # Health check
  if [[ "${xrdp_status}" == "active" && "${sesman_status}" == "active" ]]; then
    print_color "${COLOR_GREEN}" "✓ RDP services healthy"
  else
    print_color "${COLOR_RED}" "✗ RDP services degraded"
  fi

  return 0
}

# Command: cleanup
# Removes orphaned sessions
cmd_cleanup() {
  local force_cleanup=false

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force_cleanup=true
        shift
        ;;
      *)
        print_color "${COLOR_RED}" "Unknown option: $1"
        return 1
        ;;
    esac
  done

  if [[ "${force_cleanup}" != "true" ]]; then
    print_color "${COLOR_YELLOW}" "Dry run mode - no changes will be made"
    print_color "${COLOR_YELLOW}" "Use '--force' to actually cleanup sessions"
    echo
  fi

  print_color "${COLOR_BLUE}" "=== Checking for Orphaned Sessions ==="
  echo

  local orphan_count=0

  # Find Xorg processes without active RDP connections
  while IFS= read -r pid; do
    local user
    user=$(ps -p "${pid}" -o user= 2>/dev/null || echo "unknown")
    local display
    display=$(ps -p "${pid}" -o args= | grep -oP ':\d+' | head -1)

    # Check if there's an active xrdp connection for this display
    local has_connection=false
    if netstat -tnp 2>/dev/null | grep -q "xrdp.*ESTABLISHED"; then
      has_connection=true
    fi

    # If no active connection, mark as orphan
    if [[ "${has_connection}" == "false" ]]; then
      echo "Orphaned session: User=${user}, Display=${display}, PID=${pid}"

      if [[ "${force_cleanup}" == "true" ]]; then
        print_color "${COLOR_YELLOW}" "  Terminating PID ${pid}..."
        kill "${pid}" 2>/dev/null || true
        sleep 1

        # Force kill if still running
        if ps -p "${pid}" &>/dev/null; then
          kill -9 "${pid}" 2>/dev/null || true
        fi
      fi

      ((orphan_count++))
    fi

  done < <(pgrep -f '[X]org.*:[0-9]' || true)

  echo
  if [[ ${orphan_count} -eq 0 ]]; then
    print_color "${COLOR_GREEN}" "✓ No orphaned sessions found"
  elif [[ "${force_cleanup}" == "true" ]]; then
    print_color "${COLOR_GREEN}" "✓ Cleaned up ${orphan_count} orphaned session(s)"
  else
    print_color "${COLOR_YELLOW}" "Found ${orphan_count} orphaned session(s)"
    print_color "${COLOR_YELLOW}" "Run with --force to remove them"
  fi

  return 0
}

# Command: kill
# Terminates a specific session by display number
cmd_kill() {
  if [[ $# -lt 1 ]]; then
    print_color "${COLOR_RED}" "Error: Display number required"
    echo "Usage: $(basename "$0") kill <display>"
    echo "Example: $(basename "$0") kill :10"
    return 1
  fi

  local target_display="$1"

  # Ensure display format is correct
  if [[ ! "${target_display}" =~ ^:[0-9]+$ ]]; then
    print_color "${COLOR_RED}" "Error: Invalid display format: ${target_display}"
    echo "Display must be in format ':NUMBER' (e.g., :10)"
    return 1
  fi

  print_color "${COLOR_BLUE}" "=== Terminating Session ${target_display} ==="
  echo

  # Find process with this display
  local pid
  pid=$(pgrep -a "Xorg" | grep "${target_display}" | awk '{print $1}' | head -1)

  if [[ -z "${pid}" ]]; then
    print_color "${COLOR_RED}" "✗ No session found for display ${target_display}"
    return 2
  fi

  local user
  user=$(ps -p "${pid}" -o user= 2>/dev/null)

  echo "Session found:"
  echo "  Display: ${target_display}"
  echo "  PID:     ${pid}"
  echo "  User:    ${user}"
  echo

  print_color "${COLOR_YELLOW}" "Sending TERM signal..."
  kill "${pid}" 2>/dev/null || {
    print_color "${COLOR_RED}" "✗ Failed to terminate session"
    return 1
  }

  sleep 2

  # Check if still running
  if ps -p "${pid}" &>/dev/null; then
    print_color "${COLOR_YELLOW}" "Process still running, sending KILL signal..."
    kill -9 "${pid}" 2>/dev/null || true
    sleep 1
  fi

  # Verify termination
  if ! ps -p "${pid}" &>/dev/null; then
    print_color "${COLOR_GREEN}" "✓ Session ${target_display} terminated successfully"
    return 0
  else
    print_color "${COLOR_RED}" "✗ Failed to terminate session ${target_display}"
    return 1
  fi
}

# Main entry point
main() {
  if [[ $# -lt 1 ]]; then
    print_usage
    return 1
  fi

  local command="$1"
  shift

  case "${command}" in
    list)
      cmd_list "$@"
      ;;
    status)
      cmd_status "$@"
      ;;
    stats)
      cmd_stats "$@"
      ;;
    cleanup)
      cmd_cleanup "$@"
      ;;
    kill)
      cmd_kill "$@"
      ;;
    help | --help | -h)
      print_usage
      return 0
      ;;
    *)
      print_color "${COLOR_RED}" "Unknown command: ${command}"
      echo
      print_usage
      return 1
      ;;
  esac
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
