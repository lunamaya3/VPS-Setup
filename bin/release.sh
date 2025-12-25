#!/bin/bash
# Release Script: Package VPS Provisioning Tool for Distribution
# Version: 1.0.0
# Creates distribution tarball with all necessary files

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Version and release info
VERSION="${VERSION:-1.0.0}"
RELEASE_NAME="vps-provision-${VERSION}"
BUILD_DIR="${PROJECT_ROOT}/build"
DIST_DIR="${BUILD_DIR}/${RELEASE_NAME}"
TARBALL="${BUILD_DIR}/${RELEASE_NAME}.tar.gz"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."
  
  local missing=()
  
  command -v tar >/dev/null || missing+=("tar")
  command -v gzip >/dev/null || missing+=("gzip")
  command -v shellcheck >/dev/null || log_warning "shellcheck not found (optional)"
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required tools: ${missing[*]}"
    exit 1
  fi
  
  log_success "Prerequisites OK"
}

# Run tests
run_tests() {
  log_info "Running test suite..."
  
  if [[ -f "${PROJECT_ROOT}/Makefile" ]]; then
    if make -C "$PROJECT_ROOT" test 2>&1 | tail -5; then
      log_success "Tests passed"
    else
      log_error "Tests failed"
      return 1
    fi
  else
    log_warning "No Makefile found, skipping tests"
  fi
}

# Lint code
lint_code() {
  log_info "Running code linters..."
  
  local lint_errors=0
  
  # Shellcheck on bash scripts
  if command -v shellcheck >/dev/null; then
    log_info "Running shellcheck..."
    if shellcheck -e SC1091 "${PROJECT_ROOT}"/bin/* "${PROJECT_ROOT}"/lib/**/*.sh 2>/dev/null; then
      log_success "Shellcheck passed"
    else
      log_warning "Shellcheck found issues (non-blocking)"
    fi
  fi
  
  # Python syntax check
  if command -v python3 >/dev/null; then
    log_info "Checking Python syntax..."
    if python3 -m py_compile "${PROJECT_ROOT}"/lib/utils/*.py 2>/dev/null; then
      log_success "Python syntax OK"
    else
      log_error "Python syntax errors found"
      ((lint_errors++))
    fi
  fi
  
  if [[ $lint_errors -gt 0 ]]; then
    log_error "Linting failed with $lint_errors errors"
    return 1
  fi
}

# Create build directory
create_build_dir() {
  log_info "Creating build directory..."
  
  rm -rf "$BUILD_DIR"
  mkdir -p "$DIST_DIR"
  
  log_success "Build directory created: $DIST_DIR"
}

# Copy files to distribution
copy_files() {
  log_info "Copying files to distribution..."
  
  # Core executables
  cp -r "${PROJECT_ROOT}/bin" "$DIST_DIR/"
  chmod +x "${DIST_DIR}"/bin/*
  
  # Libraries
  cp -r "${PROJECT_ROOT}/lib" "$DIST_DIR/"
  
  # Configuration
  cp -r "${PROJECT_ROOT}/config" "$DIST_DIR/"
  
  # Documentation
  cp -r "${PROJECT_ROOT}/docs" "$DIST_DIR/"
  cp "${PROJECT_ROOT}/README.md" "$DIST_DIR/"
  cp "${PROJECT_ROOT}/CHANGELOG.md" "$DIST_DIR/"
  cp "${PROJECT_ROOT}/CONTRIBUTING.md" "$DIST_DIR/"
  
  # License (if exists)
  [[ -f "${PROJECT_ROOT}/LICENSE" ]] && cp "${PROJECT_ROOT}/LICENSE" "$DIST_DIR/"
  
  # Makefile
  [[ -f "${PROJECT_ROOT}/Makefile" ]] && cp "${PROJECT_ROOT}/Makefile" "$DIST_DIR/"
  
  # Requirements
  [[ -f "${PROJECT_ROOT}/requirements.txt" ]] && cp "${PROJECT_ROOT}/requirements.txt" "$DIST_DIR/"
  
  # Bash completion
  [[ -d "${PROJECT_ROOT}/etc" ]] && cp -r "${PROJECT_ROOT}/etc" "$DIST_DIR/"
  
  log_success "Files copied"
}

# Remove development files
clean_dev_files() {
  log_info "Removing development files..."
  
  # Remove test files
  rm -rf "${DIST_DIR}/tests"
  
  # Remove spec files
  rm -rf "${DIST_DIR}/specs"
  
  # Remove Git files
  rm -rf "${DIST_DIR}/.git"
  rm -f "${DIST_DIR}/.gitignore"
  rm -f "${DIST_DIR}/.gitattributes"
  
  # Remove editor files
  rm -rf "${DIST_DIR}/.vscode"
  rm -rf "${DIST_DIR}/.idea"
  rm -f "${DIST_DIR}/.editorconfig"
  
  # Remove CI/CD files
  rm -rf "${DIST_DIR}/.github"
  
  # Remove Python cache
  find "$DIST_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
  find "$DIST_DIR" -type f -name "*.pyc" -delete 2>/dev/null || true
  
  # Remove temporary files
  find "$DIST_DIR" -type f -name "*.swp" -delete 2>/dev/null || true
  find "$DIST_DIR" -type f -name "*.bak" -delete 2>/dev/null || true
  find "$DIST_DIR" -type f -name "*~" -delete 2>/dev/null || true
  
  log_success "Development files removed"
}

# Create installation script
create_install_script() {
  log_info "Creating installation script..."
  
  cat > "${DIST_DIR}/install.sh" <<'EOF'
#!/bin/bash
# VPS Provisioning Tool Installer
# Installs the tool to /opt/vps-provision

set -euo pipefail

INSTALL_DIR="/opt/vps-provision"
BIN_LINK="/usr/local/bin/vps-provision"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root"
  exit 1
fi

echo "Installing VPS Provisioning Tool to $INSTALL_DIR..."

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Copy files
cp -r bin lib config docs "$INSTALL_DIR/"
[[ -f requirements.txt ]] && cp requirements.txt "$INSTALL_DIR/"
[[ -f Makefile ]] && cp Makefile "$INSTALL_DIR/"
[[ -d etc ]] && cp -r etc "$INSTALL_DIR/"

# Set permissions
chmod +x "${INSTALL_DIR}"/bin/*
chmod -R 755 "${INSTALL_DIR}/lib"

# Create symlink
ln -sf "${INSTALL_DIR}/bin/vps-provision" "$BIN_LINK"

# Install bash completion
if [[ -f "${INSTALL_DIR}/etc/bash-completion.d/vps-provision" ]]; then
  mkdir -p /etc/bash_completion.d
  cp "${INSTALL_DIR}/etc/bash-completion.d/vps-provision" /etc/bash_completion.d/
fi

# Install Python dependencies
if [[ -f "${INSTALL_DIR}/requirements.txt" ]]; then
  pip3 install -r "${INSTALL_DIR}/requirements.txt" 2>/dev/null || echo "WARNING: Failed to install Python dependencies"
fi

echo "Installation complete!"
echo ""
echo "Usage: vps-provision [options]"
echo "Help:  vps-provision --help"
echo ""
echo "Documentation: ${INSTALL_DIR}/docs/"
EOF

  chmod +x "${DIST_DIR}/install.sh"
  log_success "Installation script created"
}

# Create VERSION file
create_version_file() {
  log_info "Creating VERSION file..."
  
  cat > "${DIST_DIR}/VERSION" <<EOF
VPS Developer Workstation Provisioning Tool
Version: ${VERSION}
Release Date: $(date +%Y-%m-%d)
Build Date: $(date +%Y-%m-%d\ %H:%M:%S)

Features:
- One-command VPS provisioning
- XFCE desktop + RDP server
- VSCode, Cursor, Antigravity IDEs
- Developer user with passwordless sudo
- Complete rollback on failure
- Idempotent re-runs

Minimum Requirements:
- Debian 13 (Bookworm)
- 2GB RAM, 1 vCPU
- 25GB disk space
- Root access

For documentation, see docs/README.md
For installation, run: sudo ./install.sh
EOF

  log_success "VERSION file created"
}

# Generate checksums
generate_checksums() {
  log_info "Generating checksums..."
  
  cd "$DIST_DIR"
  
  # SHA256 checksums
  find . -type f ! -name "SHA256SUMS" -exec sha256sum {} \; > SHA256SUMS
  
  cd "$PROJECT_ROOT"
  
  log_success "Checksums generated"
}

# Create tarball
create_tarball() {
  log_info "Creating tarball..."
  
  cd "$BUILD_DIR"
  
  tar -czf "$TARBALL" "$RELEASE_NAME"
  
  cd "$PROJECT_ROOT"
  
  local size
  size="$(du -h "$TARBALL" | cut -f1)" || size="unknown"
  log_success "Tarball created: $TARBALL ($size)"
}

# Generate release notes
generate_release_notes() {
  log_info "Generating release notes..."
  
  local notes_file="${BUILD_DIR}/RELEASE_NOTES.txt"
  
  cat > "$notes_file" <<EOF
VPS Developer Workstation Provisioning Tool v${VERSION}
Release Date: $(date +%Y-%m-%d)

OVERVIEW
========
One-command transformation of fresh Debian 13 VPS into fully-functional
developer workstation with RDP access and three IDEs.

FEATURES
========
✓ XFCE 4.18 desktop environment
✓ xrdp RDP server (port 3389)
✓ VSCode, Cursor, Antigravity IDEs
✓ Developer user with passwordless sudo
✓ Terminal enhancements (oh-my-bash)
✓ Complete rollback on failure
✓ Idempotent re-runs (safe to retry)
✓ 13-15 minute provisioning time

SYSTEM REQUIREMENTS
===================
- Debian 13 (Bookworm) - REQUIRED
- Minimum: 2GB RAM, 1 vCPU, 25GB disk
- Recommended: 4GB RAM, 2 vCPU, 50GB disk
- Root access required

INSTALLATION
============
1. Extract tarball:
   tar -xzf ${RELEASE_NAME}.tar.gz

2. Run installer:
   cd ${RELEASE_NAME}
   sudo ./install.sh

3. Provision VPS:
   sudo vps-provision --username devuser

USAGE
=====
Basic provisioning:
  sudo vps-provision --username myuser

With configuration:
  sudo vps-provision --config /path/to/config.conf

Dry-run (no changes):
  sudo vps-provision --dry-run

Verify installation:
  sudo vps-provision --verify

Rollback changes:
  sudo vps-provision --rollback

For detailed options:
  vps-provision --help

DOCUMENTATION
=============
- README.md - Quick start and overview
- docs/quickstart.md - Step-by-step guide
- docs/cli-usage.md - Complete CLI reference
- docs/troubleshooting.md - Common issues
- docs/architecture.md - System design
- CONTRIBUTING.md - Development guide

SECURITY
========
- SSH hardening (disable root, password auth)
- UFW firewall (default deny, explicit allow)
- fail2ban intrusion prevention
- TLS encryption for RDP (4096-bit RSA)
- Session isolation and timeouts
- Audit logging with auditd

PERFORMANCE
===========
Provisioning Time (4GB/2vCPU): 13-15 minutes
Provisioning Time (2GB/1vCPU): 18-20 minutes
Idempotent Re-run: 3-5 minutes
RDP Ready: <10 seconds after completion

CHANGELOG
=========
See CHANGELOG.md for complete version history.

KNOWN ISSUES
============
None reported in this release.

SUPPORT
=======
Documentation: ${INSTALL_DIR}/docs/
GitHub Issues: (repository URL when public)
EOF

  log_success "Release notes created: $notes_file"
}

# Verify distribution
verify_distribution() {
  log_info "Verifying distribution..."
  
  local errors=0
  
  # Check required files
  local required_files=(
    "bin/vps-provision"
    "lib/core/logger.sh"
    "lib/modules/system-prep.sh"
    "config/default.conf"
    "docs/README.md"
    "README.md"
    "install.sh"
    "VERSION"
    "SHA256SUMS"
  )
  
  for file in "${required_files[@]}"; do
    if [[ ! -f "${DIST_DIR}/${file}" ]]; then
      log_error "Missing required file: $file"
      ((errors++))
    fi
  done
  
  # Check executables
  if [[ ! -x "${DIST_DIR}/bin/vps-provision" ]]; then
    log_error "vps-provision is not executable"
    ((errors++))
  fi
  
  # Check no test files
  if find "$DIST_DIR" -name "*.bats" -o -name "test_*.sh" | grep -q .; then
    log_warning "Test files found in distribution"
  fi
  
  if [[ $errors -gt 0 ]]; then
    log_error "Distribution verification failed with $errors errors"
    return 1
  fi
  
  log_success "Distribution verified"
}

# Print summary
print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Release Package Created Successfully"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Version:       ${VERSION}"
  echo "Release Name:  ${RELEASE_NAME}"
  echo "Tarball:       ${TARBALL}"
  echo "Size:          $(du -h "$TARBALL" | cut -f1)"
  echo "Build Dir:     ${BUILD_DIR}"
  echo ""
  echo "Files:"
  echo "  - ${RELEASE_NAME}.tar.gz  (distribution tarball)"
  echo "  - RELEASE_NOTES.txt       (release documentation)"
  echo "  - ${RELEASE_NAME}/        (extracted contents)"
  echo ""
  echo "Distribution includes:"
  echo "  ✓ Executables (bin/)"
  echo "  ✓ Libraries (lib/)"
  echo "  ✓ Configuration (config/)"
  echo "  ✓ Documentation (docs/)"
  echo "  ✓ Installation script (install.sh)"
  echo "  ✓ Version info (VERSION)"
  echo "  ✓ Checksums (SHA256SUMS)"
  echo ""
  echo "Next steps:"
  echo "  1. Test installation: cd ${RELEASE_NAME} && sudo ./install.sh"
  echo "  2. Verify checksums: cd ${RELEASE_NAME} && sha256sum -c SHA256SUMS"
  echo "  3. Upload tarball for distribution"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main execution
main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " VPS Provisioning Tool - Release Builder"
  echo " Version: ${VERSION}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  check_prerequisites
  
  # Optional: run tests (can be skipped with --skip-tests)
  if [[ "${1:-}" != "--skip-tests" ]]; then
    run_tests || {
      log_warning "Tests failed. Continue anyway? (y/N)"
      read -r response
      [[ "$response" =~ ^[Yy]$ ]] || exit 1
    }
  fi
  
  lint_code || {
    log_warning "Linting issues found. Continue anyway? (y/N)"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] || exit 1
  }
  
  create_build_dir
  copy_files
  clean_dev_files
  create_install_script
  create_version_file
  generate_checksums
  verify_distribution
  create_tarball
  generate_release_notes
  
  print_summary
}

# Handle arguments
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  cat <<EOF
Usage: $0 [OPTIONS]

Build and package VPS Provisioning Tool for distribution.

Options:
  --skip-tests       Skip running test suite
  --help, -h         Show this help message

Environment Variables:
  VERSION           Set release version (default: 1.0.0)

Examples:
  $0                              # Build with default version
  VERSION=1.1.0 $0                # Build with specific version
  $0 --skip-tests                 # Build without running tests

Output:
  build/vps-provision-VERSION.tar.gz
  build/RELEASE_NOTES.txt
  build/vps-provision-VERSION/
EOF
  exit 0
fi

main "$@"
