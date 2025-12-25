#!/bin/bash
# Status Banner Display
# Shows completion banner with connection credentials
#
# Usage: source lib/modules/status-banner.sh && display_ready_banner

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck disable=SC1091
source "${LIB_DIR}/core/logger.sh"

# Colors for banner
readonly BANNER_BLUE='\033[0;34m'
readonly BANNER_GREEN='\033[0;32m'
readonly BANNER_YELLOW='\033[1;33m'
readonly BANNER_RED='\033[0;31m'
readonly BANNER_NC='\033[0m'

# Display ready status banner
display_ready_banner() {
  local dev_username="${1:-devuser}"
  local dev_password="${2:-[Generated - see logs]}"

  # Get system information
  local hostname ip_address rdp_port
  hostname=$(hostname)
  ip_address=$(hostname -I | awk '{print $1}' || echo "unknown")
  rdp_port="3389"

  # Calculate total duration
  local duration
  duration="15 minutes" # Placeholder - should be calculated from session

  echo ""
  echo -e "${BANNER_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${BANNER_NC}"
  echo -e "${BANNER_GREEN}  ✓ VPS Developer Workstation Ready!${BANNER_NC}"
  echo -e "${BANNER_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${BANNER_NC}"
  echo ""
  echo -e "${BANNER_GREEN}RDP Connection Details:${BANNER_NC}"
  echo -e "  Host:     ${BANNER_BLUE}${ip_address}${BANNER_NC}"
  echo -e "  Port:     ${BANNER_BLUE}${rdp_port}${BANNER_NC}"
  echo -e "  Username: ${BANNER_BLUE}${dev_username}${BANNER_NC}"
  echo -e "  Password: ${BANNER_YELLOW}${dev_password}${BANNER_NC}"
  echo ""
  echo -e "${BANNER_RED}⚠️  IMPORTANT SECURITY NOTICE:${BANNER_NC}"
  echo -e "  ${BANNER_YELLOW}Change password immediately after first login!${BANNER_NC}"
  echo -e "  ${BANNER_YELLOW}Command: passwd${BANNER_NC}"
  echo ""
  echo -e "${BANNER_GREEN}SSH Connection:${BANNER_NC}"
  echo -e "  ${BANNER_BLUE}ssh ${dev_username}@${ip_address}${BANNER_NC}"
  echo ""
  echo -e "${BANNER_GREEN}Installed IDEs:${BANNER_NC}"
  echo -e "  • VSCode      - ${BANNER_BLUE}Applications → Development → Visual Studio Code${BANNER_NC}"
  echo -e "  • Cursor      - ${BANNER_BLUE}Applications → Development → Cursor${BANNER_NC}"
  echo -e "  • Antigravity - ${BANNER_BLUE}Applications → Development → Antigravity${BANNER_NC}"
  echo ""
  echo -e "${BANNER_GREEN}System Information:${BANNER_NC}"
  echo -e "  Hostname:  ${BANNER_BLUE}${hostname}${BANNER_NC}"
  echo -e "  Duration:  ${BANNER_BLUE}${duration}${BANNER_NC}"
  echo -e "  Desktop:   ${BANNER_BLUE}XFCE 4.18${BANNER_NC}"
  echo ""
  echo -e "${BANNER_GREEN}Next Steps:${BANNER_NC}"
  echo -e "  1. Connect via RDP client (Windows: mstsc, Mac: Microsoft Remote Desktop)"
  echo -e "  2. Login with provided credentials"
  echo -e "  3. ${BANNER_YELLOW}Change your password immediately${BANNER_NC}"
  echo -e "  4. Launch any IDE from Applications menu"
  echo -e "  5. Start coding!"
  echo ""
  echo -e "${BANNER_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${BANNER_NC}"
  echo -e "${BANNER_GREEN}  Provisioning completed successfully!${BANNER_NC}"
  echo -e "${BANNER_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${BANNER_NC}"
  echo ""

  return 0
}

# Module execute function (for contract compliance)
status_banner_execute() {
  local dev_username="${1:-devuser}"
  local dev_password="${2:-[Generated]}"
  display_ready_banner "$dev_username" "$dev_password"
}

# Show RDP connection info
status_banner_show_rdp_info() {
  local ip_address
  ip_address=$(hostname -I | awk '{print $1}' || echo "unknown")
  local rdp_port="3389"

  echo "RDP: ${ip_address}:${rdp_port}"
}

# Export functions
export -f display_ready_banner
export -f status_banner_execute
export -f status_banner_show_rdp_info
