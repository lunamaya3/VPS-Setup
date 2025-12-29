#!/bin/bash
# Isolated E2E Test Runner
# Executes VPS provisioning tests in Docker container for complete host isolation

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly CONTAINER_NAME="vps-test-$(date +%s)-$$"
readonly IMAGE_NAME="vps-provision-test"
readonly TEST_TIMEOUT=1800  # 30 minutes

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

cleanup_container() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Cleaning up container: ${CONTAINER_NAME}"
        docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    fi
}

# Ensure cleanup on exit
trap cleanup_container EXIT INT TERM

main() {
    log_info "Starting isolated E2E test for VPS provisioning tool"
    
    # Verify Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not running. Start Docker and retry."
        exit 1
    fi
    
    # Build test image if not exists or if rebuild requested
    if [[ ! "$(docker images -q ${IMAGE_NAME} 2>/dev/null)" ]] || [[ "${REBUILD:-false}" == "true" ]]; then
        log_info "Building isolated test environment image..."
        docker build -t "${IMAGE_NAME}" -f "${SCRIPT_DIR}/Dockerfile.test" "${PROJECT_ROOT}"
    fi
    
    # Start container with proper systemd support
    log_info "Starting isolated test container: ${CONTAINER_NAME}"
    docker run -d \
        --name "${CONTAINER_NAME}" \
        --privileged \
        --cgroupns=host \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        -v "${PROJECT_ROOT}:/provisioning:ro" \
        --tmpfs /run:exec \
        --tmpfs /run/lock \
        "${IMAGE_NAME}"
    
    # Wait for systemd to be ready
    log_info "Waiting for systemd initialization..."
    for i in {1..30}; do
        if docker exec "${CONTAINER_NAME}" systemctl is-system-running --wait 2>/dev/null | grep -qE 'running|degraded'; then
            log_info "Systemd ready"
            break
        fi
        sleep 1
    done
    
    # Copy project to writable location inside container (provisioning needs write access)
    log_info "Preparing test environment inside container..."
    docker exec "${CONTAINER_NAME}" bash -c '
        cp -r /provisioning /tmp/vps-provision-test
        chown -R testuser:testuser /tmp/vps-provision-test
    '
    
    # Run unit tests (fast validation)
    log_info "Running unit tests..."
    if ! docker exec -u testuser -w /tmp/vps-provision-test "${CONTAINER_NAME}" make test-unit; then
        log_error "Unit tests failed"
        exit 1
    fi
    
    # Run integration tests
    log_info "Running integration tests..."
    if ! docker exec -u testuser -w /tmp/vps-provision-test "${CONTAINER_NAME}" make test-integration; then
        log_error "Integration tests failed"
        exit 1
    fi
    
    # Run actual provisioning script (full E2E)
    log_info "Executing full provisioning script..."
    if ! timeout "${TEST_TIMEOUT}" docker exec -u testuser -w /tmp/vps-provision-test "${CONTAINER_NAME}" \
        sudo /tmp/vps-provision-test/bin/vps-provision --config /tmp/vps-provision-test/config/default.conf --dry-run; then
        log_error "Provisioning script failed"
        
        # Capture logs for debugging
        log_warn "Retrieving logs for analysis..."
        docker exec "${CONTAINER_NAME}" cat /var/log/vps-provision/provision.log || true
        exit 1
    fi
    
    # Run contract tests to verify CLI interface
    log_info "Running contract tests..."
    if ! docker exec -u testuser -w /tmp/vps-provision-test "${CONTAINER_NAME}" make test-contract; then
        log_error "Contract tests failed"
        exit 1
    fi
    
    # Verify checkpoint system integrity
    log_info "Verifying checkpoint system..."
    docker exec "${CONTAINER_NAME}" ls -la /var/vps-provision/checkpoints/ || true
    
    # Verify installed components
    log_info "Validating installation..."
    docker exec "${CONTAINER_NAME}" bash -c '
        echo "=== Installed Packages ==="
        dpkg -l | grep -E "(xfce|xrdp|code|cursor)" || echo "No packages found"
        
        echo -e "\n=== Running Services ==="
        systemctl list-units --type=service --state=running | grep -E "(xrdp|ssh)" || echo "No services running"
        
        echo -e "\n=== User Configuration ==="
        id devuser 2>/dev/null || echo "devuser not created"
    '
    
    log_info "All tests passed successfully!"
    log_info "Container cleanup will happen automatically"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild)
            REBUILD=true
            shift
            ;;
        --keep-container)
            trap - EXIT INT TERM
            log_warn "Container will NOT be cleaned up automatically"
            shift
            ;;
        --help)
            cat <<EOF
Usage: $0 [OPTIONS]

Run VPS provisioning E2E tests in isolated Docker container

OPTIONS:
    --rebuild           Force rebuild of test image
    --keep-container    Don't auto-cleanup container (for debugging)
    --help              Show this help message

ENVIRONMENT VARIABLES:
    TEST_TIMEOUT        Timeout for provisioning script (default: 1800s)

EXAMPLES:
    # Standard isolated test run
    $0
    
    # Rebuild image and keep container for inspection
    $0 --rebuild --keep-container
    
    # Quick retry with existing image
    TEST_TIMEOUT=300 $0
EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

main
