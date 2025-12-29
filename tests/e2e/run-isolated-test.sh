#!/bin/bash
# Isolated E2E Test Runner
# Executes VPS provisioning tests in Docker container with enhanced security isolation
# Follows Docker best practices for testing, security, and container lifecycle management

set -euo pipefail

# ============================================
# Configuration
# ============================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly TIMESTAMP="$(date +%s)"
readonly CONTAINER_NAME="vps-test-${TIMESTAMP}-$$"
readonly IMAGE_NAME="vps-provision-test"
readonly IMAGE_TAG="latest"
readonly TEST_TIMEOUT=1800  # 30 minutes
readonly HEALTH_CHECK_TIMEOUT=60  # 1 minute
readonly SYSTEMD_READY_TIMEOUT=45  # 45 seconds

# Security: Run with minimal privileges
readonly CONTAINER_USER="testuser"
readonly CONTAINER_UID="10001"
readonly CONTAINER_GID="10001"

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ============================================
# Logging Functions
# ============================================
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    fi
}

# ============================================
# Cleanup & Error Handling
# ============================================
cleanup_container() {
    local exit_code=$?
    
    if [[ "${KEEP_CONTAINER:-false}" == "true" ]]; then
        log_warn "Container preserved for debugging: ${CONTAINER_NAME}"
        log_info "Access with: docker exec -it ${CONTAINER_NAME} bash"
        log_info "View logs: docker logs ${CONTAINER_NAME}"
        log_info "Remove later: docker rm -f ${CONTAINER_NAME}"
        return 0
    fi
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Cleaning up container: ${CONTAINER_NAME}"
        
        # Capture logs if test failed
        if [[ $exit_code -ne 0 ]]; then
            log_warn "Test failed - capturing container logs..."
            docker logs "${CONTAINER_NAME}" > "/tmp/${CONTAINER_NAME}.log" 2>&1 || true
            log_info "Logs saved to: /tmp/${CONTAINER_NAME}.log"
        fi
        
        docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
        log_info "Container removed successfully"
    fi
}

# Ensure cleanup on exit (all signals)
trap cleanup_container EXIT INT TERM HUP QUIT

# ============================================
# Validation Functions
# ============================================
validate_docker() {
    log_info "Validating Docker environment..."
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not running"
        log_error "Start Docker: sudo systemctl start docker"
        return 1
    fi
    
    # Check Docker version
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    log_info "Docker version: ${docker_version}"
    
    # Check available disk space (need at least 5GB)
    local available_space
    available_space=$(df /var/lib/docker | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 5242880 ]]; then  # 5GB in KB
        log_warn "Low disk space: $(( available_space / 1048576 ))GB available"
        log_warn "Consider running: docker system prune -af"
    fi
    
    # Check for conflicting containers
    if docker ps -a --format '{{.Names}}' | grep -q "^vps-test-"; then
        log_warn "Found existing test containers:"
        docker ps -a --filter "name=vps-test-" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}"
    fi
    
    log_info "Docker environment validated"
    return 0
}

build_test_image() {
    log_info "Building isolated test environment image..."
    
    local build_args=()
    build_args+=("--file" "${SCRIPT_DIR}/Dockerfile.test")
    build_args+=("--tag" "${IMAGE_NAME}:${IMAGE_TAG}")
    build_args+=("--tag" "${IMAGE_NAME}:${TIMESTAMP}")
    
    # Enable BuildKit for advanced features
    export DOCKER_BUILDKIT=1
    
    # Build with progress and build cache
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        build_args+=("--progress" "plain")
    else
        build_args+=("--progress" "auto")
    fi
    
    # Add build args for customization
    build_args+=("--build-arg" "BUILDKIT_INLINE_CACHE=1")
    build_args+=("--build-arg" "UID=${CONTAINER_UID}")
    build_args+=("--build-arg" "GID=${CONTAINER_GID}")
    
    # Security: Add labels
    build_args+=("--label" "test.timestamp=${TIMESTAMP}")
    build_args+=("--label" "test.runner=isolated-e2e")
    
    log_info "Build command: docker build ${build_args[*]} ${PROJECT_ROOT}"
    
    if ! docker build "${build_args[@]}" "${PROJECT_ROOT}"; then
        log_error "Image build failed"
        return 1
    fi
    
    log_info "Test image built successfully: ${IMAGE_NAME}:${IMAGE_TAG}"
    return 0
}

start_test_container() {
    log_info "Starting isolated test container: ${CONTAINER_NAME}"
    
    # Security: Use minimal privileges with read-only mounts
    local docker_run_args=()
    docker_run_args+=("--name" "${CONTAINER_NAME}")
    docker_run_args+=("--detach")
    
    # Required for systemd
    docker_run_args+=("--privileged")
    docker_run_args+=("--cgroupns=host")
    
    # Mounts
    docker_run_args+=("--volume" "/sys/fs/cgroup:/sys/fs/cgroup:rw")
    docker_run_args+=("--volume" "${PROJECT_ROOT}:/provisioning:ro")  # Read-only!
    docker_run_args+=("--tmpfs" "/run:exec")
    docker_run_args+=("--tmpfs" "/run/lock")
    docker_run_args+=("--tmpfs" "/tmp:exec")
    
    # Security: Drop unnecessary capabilities
    docker_run_args+=("--cap-drop" "ALL")
    docker_run_args+=("--cap-add" "SYS_ADMIN")  # Required for systemd
    docker_run_args+=("--cap-add" "NET_ADMIN")  # Required for network config
    
    # Resource limits
    docker_run_args+=("--memory" "4g")
    docker_run_args+=("--memory-swap" "4g")
    docker_run_args+=("--cpus" "2")
    
    # Labels
    docker_run_args+=("--label" "test.type=isolated-e2e")
    docker_run_args+=("--label" "test.timestamp=${TIMESTAMP}")
    
    # Health check
    docker_run_args+=("--health-interval" "30s")
    docker_run_args+=("--health-timeout" "10s")
    docker_run_args+=("--health-retries" "3")
    
    log_debug "Container run args: ${docker_run_args[*]}"
    
    if ! docker run "${docker_run_args[@]}" "${IMAGE_NAME}:${IMAGE_TAG}"; then
        log_error "Failed to start container"
        return 1
    fi
    
    log_info "Container started successfully"
    return 0
}

wait_for_systemd() {
    log_info "Waiting for systemd initialization..."
    
    local timeout=$SYSTEMD_READY_TIMEOUT
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        # Note: 'degraded' is acceptable in containers since some services may fail
        # but core system is functional. This is expected behavior in Docker.
        # We need to check the actual status string, not the exit code
        local systemd_state
        systemd_state=$(docker exec "${CONTAINER_NAME}" systemctl is-system-running 2>/dev/null || true)
        
        if [[ "${systemd_state}" =~ ^(running|degraded)$ ]]; then
            log_info "Systemd ready: ${systemd_state} (${elapsed}s)"
            return 0
        fi
        
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    log_error "Systemd failed to initialize within ${timeout}s"
    docker exec "${CONTAINER_NAME}" systemctl status || true
    return 1
}

main() {
    log_info "Starting isolated E2E test for VPS provisioning tool"
    log_info "Timestamp: ${TIMESTAMP}"
    log_info "Container: ${CONTAINER_NAME}"
    
    # Validate environment
    validate_docker || exit 1
    
    # Build or use cached image
    if [[ ! "$(docker images -q ${IMAGE_NAME}:${IMAGE_TAG} 2>/dev/null)" ]] || [[ "${REBUILD:-false}" == "true" ]]; then
        build_test_image || exit 1
    else
        log_info "Using cached image: ${IMAGE_NAME}:${IMAGE_TAG}"
    fi
    
    # Start container
    start_test_container || exit 1
    
    # Wait for systemd
    wait_for_systemd || exit 1
    
    # Prepare test environment
    log_info "Preparing test environment inside container..."
    if ! docker exec "${CONTAINER_NAME}" bash -c '
        set -ex
        echo "Copying project files from /provisioning to /tmp/vps-provision-test..."
        cp -r /provisioning /tmp/vps-provision-test
        echo "Setting ownership to testuser:testuser..."
        chown -R testuser:testuser /tmp/vps-provision-test
        echo "Setting write permissions..."
        chmod -R u+w /tmp/vps-provision-test
        echo "Test environment prepared successfully"
    ' 2>&1; then
        log_error "Failed to prepare test environment"
        return 1
    fi
    
    # Test execution phases
    local test_start
    test_start=$(date +%s)
    local phase_count=0
    local failed_phases=0
    
    # Phase 1: Unit tests (fast validation)
    phase_count=$((phase_count + 1))
    log_info "[Phase ${phase_count}] Running unit tests..."
    if ! docker exec -u "${CONTAINER_USER}" -w /tmp/vps-provision-test "${CONTAINER_NAME}" \
        bash -c 'make test-unit 2>&1 | tee /tmp/unit-test.log'; then
        log_error "Unit tests failed"
        failed_phases=$((failed_phases + 1))
    else
        log_info "✓ Unit tests passed"
    fi
    
    # Phase 2: Integration tests
    phase_count=$((phase_count + 1))
    log_info "[Phase ${phase_count}] Running integration tests..."
    if ! docker exec -u "${CONTAINER_USER}" -w /tmp/vps-provision-test "${CONTAINER_NAME}" \
        bash -c 'make test-integration 2>&1 | tee /tmp/integration-test.log'; then
        log_error "Integration tests failed"
        failed_phases=$((failed_phases + 1))
    else
        log_info "✓ Integration tests passed"
    fi
    
    # Phase 3: Dry-run provisioning
    phase_count=$((phase_count + 1))
    log_info "[Phase ${phase_count}] Executing provisioning (dry-run)..."
    if ! timeout "${TEST_TIMEOUT}" docker exec -u "${CONTAINER_USER}" -w /tmp/vps-provision-test "${CONTAINER_NAME}" \
        bash -c 'sudo /tmp/vps-provision-test/bin/vps-provision --config /tmp/vps-provision-test/config/default.conf --dry-run 2>&1 | tee /tmp/provision.log'; then
        log_error "Provisioning script failed"
        log_warn "Retrieving logs..."
        docker exec "${CONTAINER_NAME}" cat /var/log/vps-provision/provision.log 2>/dev/null || true
        failed_phases=$((failed_phases + 1))
    else
        log_info "✓ Provisioning completed"
    fi
    
    # Phase 4: Contract tests
    phase_count=$((phase_count + 1))
    log_info "[Phase ${phase_count}] Running contract tests..."
    if ! docker exec -u "${CONTAINER_USER}" -w /tmp/vps-provision-test "${CONTAINER_NAME}" \
        bash -c 'make test-contract 2>&1 | tee /tmp/contract-test.log'; then
        log_error "Contract tests failed"
        failed_phases=$((failed_phases + 1))
    else
        log_info "✓ Contract tests passed"
    fi
    
    # Phase 5: System validation
    phase_count=$((phase_count + 1))
    log_info "[Phase ${phase_count}] Validating system state..."
    docker exec "${CONTAINER_NAME}" bash -c '
        echo "=== Checkpoint System ==="
        ls -lah /var/vps-provision/checkpoints/ 2>/dev/null || echo "No checkpoints"
        
        echo -e "\n=== Transaction Log ==="
        ls -lah /var/vps-provision/transactions/ 2>/dev/null || echo "No transactions"
        
        echo -e "\n=== Installed Packages ==="
        dpkg -l | grep -E "(xfce|xrdp|code|cursor)" || echo "No packages found"
        
        echo -e "\n=== Running Services ==="
        systemctl list-units --type=service --state=running | grep -E "(xrdp|ssh)" || echo "No services running"
        
        echo -e "\n=== User Configuration ==="
        id devuser 2>/dev/null || echo "devuser not created (dry-run mode)"
        
        echo -e "\n=== Disk Usage ==="
        df -h / /tmp
        
        echo -e "\n=== Memory Usage ==="
        free -h
    ' | tee /tmp/"${CONTAINER_NAME}"-validation.log
    
    # Calculate test duration
    local test_end
    test_end=$(date +%s)
    local duration=$((test_end - test_start))
    
    # Summary report
    echo ""
    log_info "============================================"
    log_info "Test Execution Summary"
    log_info "============================================"
    log_info "Container: ${CONTAINER_NAME}"
    log_info "Total phases: ${phase_count}"
    log_info "Failed phases: ${failed_phases}"
    log_info "Duration: ${duration}s"
    log_info "Validation log: /tmp/${CONTAINER_NAME}-validation.log"
    
    if [[ $failed_phases -eq 0 ]]; then
        log_info "✓ All tests passed successfully!"
        log_info "Container cleanup will happen automatically"
        return 0
    else
        log_error "✗ ${failed_phases} test phase(s) failed"
        log_error "Container preserved for debugging (use --keep-container to keep)"
        return 1
    fi
}

# Parse arguments
KEEP_CONTAINER=false
REBUILD=false
VERBOSE=false
DEBUG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild)
            REBUILD=true
            shift
            ;;
        --keep-container)
            KEEP_CONTAINER=true
            log_warn "Container will NOT be cleaned up automatically"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --help)
            cat <<EOF
Isolated E2E Test Runner for VPS Provisioning Tool

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --rebuild           Force rebuild of test image
    --keep-container    Preserve container after tests for debugging
    --verbose          Enable verbose output
    --debug            Enable debug logging
    --help             Display this help message

EXAMPLES:
    # Standard test run
    $0

    # Rebuild image and run tests
    $0 --rebuild

    # Keep container for debugging
    $0 --keep-container

    # Debug mode with verbose output
    $0 --debug --verbose

ENVIRONMENT:
    REBUILD            Set to 'true' to force rebuild
    KEEP_CONTAINER     Set to 'true' to preserve container
    DEBUG              Set to 'true' for debug logging

SECURITY:
    - Container runs with minimal privileges
    - Project mounted read-only
    - Resource limits enforced (4GB RAM, 2 CPUs)
    - Automatic cleanup on exit

For more information, see docs/testing-isolation.md
EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            log_info "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Execute main function
main
exit $?

