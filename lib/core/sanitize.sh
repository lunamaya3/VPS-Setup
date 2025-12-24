#!/bin/bash
# Input Sanitization Module
# Purpose: Prevent command injection and validate all user-provided inputs (SEC-018)
#
# Usage:
#   source lib/core/sanitize.sh
#   sanitize_string "$user_input"
#   sanitize_path "$file_path"
#   sanitize_username "$username"
#
# Dependencies:
#   - lib/core/logger.sh

set -euo pipefail

# Prevent multiple sourcing
if [[ -n "${_SANITIZE_SH_LOADED:-}" ]]; then
  return 0
fi
readonly _SANITIZE_SH_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${SCRIPT_DIR}")"
# shellcheck disable=SC1091
# shellcheck disable=SC1091
source "${LIB_DIR}/core/logger.sh"

# Dangerous characters that should be escaped or rejected
# shellcheck disable=SC2016
readonly DANGEROUS_CHARS='[;&|`$(){}<>"'\''\\]'

#######################################
# Sanitize generic string input
# Removes or escapes dangerous shell characters
# Globals:
#   DANGEROUS_CHARS
# Arguments:
#   $1 - Input string to sanitize
# Outputs:
#   Sanitized string to stdout
# Returns:
#   0 on success, 1 if input contains dangerous characters
#######################################
sanitize_string() {
  local input="$1"
  
  # Check for dangerous characters
  if [[ "$input" =~ $DANGEROUS_CHARS ]]; then
    log_error "Input contains dangerous characters (SEC-018)"
    return 1
  fi
  
  echo "$input"
  return 0
}

#######################################
# Sanitize file path input
# Validates path doesn't contain traversal or injection attempts
# Globals:
#   None
# Arguments:
#   $1 - File path to sanitize
# Outputs:
#   Sanitized path to stdout
# Returns:
#   0 if path is safe, 1 otherwise
#######################################
sanitize_path() {
  local path="$1"
  
  # Reject empty paths
  if [[ -z "$path" ]]; then
    log_error "Path is empty (SEC-018)"
    return 1
  fi
  
  # Reject paths with directory traversal attempts
  if [[ "$path" == *".."* ]]; then
    log_error "Path contains directory traversal (SEC-018): $path"
    return 1
  fi
  
  # Reject paths with null bytes
  if [[ "$path" == *$'\0'* ]]; then
    log_error "Path contains null bytes (SEC-018)"
    return 1
  fi
  
  # Check for dangerous shell characters
  if [[ "$path" =~ [';|&`$<>'] ]]; then
    log_error "Path contains dangerous shell characters (SEC-018): $path"
    return 1
  fi
  
  echo "$path"
  return 0
}

#######################################
# Sanitize username input
# Validates username matches Linux username requirements
# Globals:
#   None
# Arguments:
#   $1 - Username to sanitize
# Outputs:
#   Sanitized username to stdout
# Returns:
#   0 if username is valid, 1 otherwise
#######################################
sanitize_username() {
  local username="$1"
  
  # Linux username requirements:
  # - Start with lowercase letter
  # - Only lowercase letters, numbers, underscore, hyphen
  # - Length: 1-32 characters
  # - Recommended: 3-31 characters
  
  local username_regex='^[a-z][a-z0-9_-]{2,31}$'
  
  if [[ ! "$username" =~ $username_regex ]]; then
    log_error "Username is invalid (SEC-018): $username"
    log_error "Username must start with lowercase letter, contain only [a-z0-9_-], and be 3-32 chars"
    return 1
  fi
  
  # Additional check: reject reserved usernames
  local -a reserved_names=(
    "root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news"
    "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody"
    "systemd-network" "systemd-resolve" "messagebus" "syslog" "_apt"
    "mysql" "postgres" "redis" "mongodb"
  )
  
  for reserved in "${reserved_names[@]}"; do
    if [[ "$username" == "$reserved" ]]; then
      log_error "Username is reserved (SEC-018): $username"
      return 1
    fi
  done
  
  echo "$username"
  return 0
}

#######################################
# Sanitize log level input
# Validates log level is one of the allowed values
# Globals:
#   None
# Arguments:
#   $1 - Log level to validate
# Outputs:
#   Validated log level to stdout
# Returns:
#   0 if valid, 1 otherwise
#######################################
sanitize_log_level() {
  local level="$1"
  local -a valid_levels=("DEBUG" "INFO" "WARNING" "ERROR")
  
  # Convert to uppercase for comparison
  level="${level^^}"
  
  for valid in "${valid_levels[@]}"; do
    if [[ "$level" == "$valid" ]]; then
      echo "$level"
      return 0
    fi
  done
  
  log_error "Invalid log level (SEC-018): $level"
  log_error "Valid levels: ${valid_levels[*]}"
  return 1
}

#######################################
# Sanitize output format input
# Validates output format is one of the allowed values
# Globals:
#   None
# Arguments:
#   $1 - Output format to validate
# Outputs:
#   Validated format to stdout
# Returns:
#   0 if valid, 1 otherwise
#######################################
sanitize_output_format() {
  local format="$1"
  local -a valid_formats=("text" "json")
  
  # Convert to lowercase for comparison
  format="${format,,}"
  
  for valid in "${valid_formats[@]}"; do
    if [[ "$format" == "$valid" ]]; then
      echo "$format"
      return 0
    fi
  done
  
  log_error "Invalid output format (SEC-018): $format"
  log_error "Valid formats: ${valid_formats[*]}"
  return 1
}

#######################################
# Sanitize phase name input
# Validates phase name is one of the allowed phases
# Globals:
#   None
# Arguments:
#   $1 - Phase name to validate
# Outputs:
#   Validated phase name to stdout
# Returns:
#   0 if valid, 1 otherwise
#######################################
sanitize_phase_name() {
  local phase="$1"
  local -a valid_phases=(
    "system-prep"
    "desktop-install"
    "rdp-config"
    "user-creation"
    "ide-vscode"
    "ide-cursor"
    "ide-antigravity"
    "terminal-setup"
    "dev-tools"
    "verification"
  )
  
  for valid in "${valid_phases[@]}"; do
    if [[ "$phase" == "$valid" ]]; then
      echo "$phase"
      return 0
    fi
  done
  
  log_error "Invalid phase name (SEC-018): $phase"
  log_error "Valid phases: ${valid_phases[*]}"
  return 1
}

#######################################
# Escape string for safe use in shell commands
# Use this when you must pass user input to a shell command
# Globals:
#   None
# Arguments:
#   $1 - String to escape
# Outputs:
#   Escaped string to stdout (single-quoted with escaped single quotes)
# Returns:
#   0 always
#######################################
escape_for_shell() {
  local input="$1"
  
  # Single-quote the string and escape any single quotes within it
  # This is the safest way to pass arbitrary strings to shell commands
  printf '%s' "'${input//\'/\'\\\'\'}'"
  return 0
}

#######################################
# Validate and sanitize integer input
# Globals:
#   None
# Arguments:
#   $1 - Integer to validate
#   $2 - Minimum value (optional, default: no minimum)
#   $3 - Maximum value (optional, default: no maximum)
# Outputs:
#   Validated integer to stdout
# Returns:
#   0 if valid integer within range, 1 otherwise
#######################################
sanitize_integer() {
  local value="$1"
  local min="${2:-}"
  local max="${3:-}"
  
  # Check if it's a valid integer
  if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
    log_error "Not a valid integer (SEC-018): $value"
    return 1
  fi
  
  # Check minimum
  if [[ -n "$min" ]] && (( value < min )); then
    log_error "Value $value is below minimum $min (SEC-018)"
    return 1
  fi
  
  # Check maximum
  if [[ -n "$max" ]] && (( value > max )); then
    log_error "Value $value is above maximum $max (SEC-018)"
    return 1
  fi
  
  echo "$value"
  return 0
}
