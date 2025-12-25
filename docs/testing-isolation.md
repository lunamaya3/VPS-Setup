# Isolated Testing Guide

## Overview

This VPS provisioning tool modifies system-level configurations, installs packages, and manages services. To prevent host system corruption during development and testing, we provide a **complete Docker-based isolation environment** that mirrors production Debian 13 VPS specifications.

## Why Isolated Testing?

**Risk Factors Without Isolation:**

- Package installation conflicts with host system
- Service configuration overwrites (SSH, RDP, systemd)
- User/group modifications affecting host
- Checkpoint files polluting host filesystem
- Transaction rollback affecting host state

**Benefits of Docker Isolation:**

- Complete filesystem isolation from host
- Safe to test destructive operations
- Reproducible test environment
- Parallel test execution without conflicts
- Easy cleanup (destroy container)

## Quick Start

### Run Isolated E2E Tests

```bash
# Standard isolated test execution
make test-e2e-isolated

# First time or after Dockerfile changes
make test-e2e-isolated-rebuild

# Keep container running for debugging
./tests/e2e/run-isolated-test.sh --keep-container
```

### Architecture

```
┌─────────────────────────────────────────────────┐
│ Host System (Your Development Machine)          │
│                                                  │
│  ┌────────────────────────────────────────┐    │
│  │ Docker Container (vps-test-TIMESTAMP)   │    │
│  │                                          │    │
│  │  • Fresh Debian 13 environment          │    │
│  │  • Systemd init system                  │    │
│  │  • /provisioning → Project (read-only)  │    │
│  │  • Isolated /var/vps-provision/         │    │
│  │  • Contained service modifications      │    │
│  │                                          │    │
│  │  [VPS Provisioning Script Executes]     │    │
│  │                                          │    │
│  └────────────────────────────────────────┘    │
│                                                  │
│  Container destroyed after tests complete ✓     │
└─────────────────────────────────────────────────┘
```

## Isolation Guarantees

### Filesystem Isolation

- **Read-Only Project Mount**: Source code mounted as `:ro` prevents container modifications
- **Ephemeral Container**: All changes confined to container, destroyed on completion
- **Separate Working Copy**: Tests run on `/tmp/vps-provision-test` inside container

### Network Isolation

- **Bridge Network**: Container uses isolated Docker bridge network
- **No Host Network Access**: `--network host` explicitly avoided
- **Port Mapping**: Only exposed ports accessible from host

### Process Isolation

- **Containerized Systemd**: Services run in container init system
- **Separate PID Namespace**: Process isolation from host
- **Cgroup Limits**: Resource constraints prevent host exhaustion

### User Isolation

- **Test User**: Provisioning runs as `testuser`, not host user
- **Sudo in Container**: Passwordless sudo confined to container
- **No Host UID Conflicts**: UIDs isolated within container namespace

## Test Execution Flow

```bash
./tests/e2e/run-isolated-test.sh
```

**Steps:**

1. **Verify Docker Daemon** - Ensures Docker is running on host
2. **Build/Reuse Test Image** - Debian 13 with systemd and test dependencies
3. **Start Container** - Privileged mode for systemd support
4. **Mount Project Read-Only** - Source code accessible but protected
5. **Wait for Systemd** - Container init system ready
6. **Copy to Writable Location** - `/tmp/vps-provision-test` for execution
7. **Run Unit Tests** - Fast validation (5-10 seconds)
8. **Run Integration Tests** - Module testing (1-2 minutes)
9. **Execute Full Provisioning** - Complete E2E scenario (≤15 minutes)
10. **Run Contract Tests** - CLI interface validation
11. **Verify Installation** - Check packages, services, user creation
12. **Automatic Cleanup** - Container removed (even on failure)

## Safety Checklist

Before running isolated tests, verify:

- [ ] Docker daemon running (`docker info`)
- [ ] Sufficient disk space (≥10GB for image + container)
- [ ] `/sys/fs/cgroup` accessible on host
- [ ] No conflicting containers named `vps-test-*`
- [ ] Project directory contains no sensitive data in tests/

**Post-Test Validation:**

- [ ] Container destroyed (`docker ps -a | grep vps-test`)
- [ ] No leftover volumes (`docker volume ls`)
- [ ] Host system unchanged (`systemctl status xrdp` should fail if not installed)
- [ ] No checkpoint files in host `/var/vps-provision/`

## Dockerfile Structure

**`tests/e2e/Dockerfile.test`** creates:

```dockerfile
FROM debian:13                    # Match production OS
RUN apt-get install systemd ...   # Init system support
RUN useradd -m testuser ...       # Test user with sudo
RUN mkdir /var/vps-provision ...  # Isolated state directories
CMD ["/sbin/init"]                # Systemd as PID 1
```

**Key Features:**

- Systemd-enabled for service management testing
- Pre-installed BATS for test execution
- Test user mirrors provisioning target user pattern
- Clean slate for each test run

## Troubleshooting

### Container Won't Start

```bash
# Check Docker daemon
docker info

# Verify cgroup v2 support (required for systemd)
ls /sys/fs/cgroup/

# Check for port conflicts
docker ps -a
```

### Tests Fail Inside Container

```bash
# Keep container running for inspection
./tests/e2e/run-isolated-test.sh --keep-container

# Inspect logs
docker logs vps-test-<timestamp>

# Access shell inside container
docker exec -it vps-test-<timestamp> bash

# Check provisioning logs
docker exec vps-test-<timestamp> cat /var/log/vps-provision/provision.log
```

### Systemd Issues in Container

```bash
# Verify systemd is running
docker exec vps-test-<timestamp> systemctl status

# Check init system
docker exec vps-test-<timestamp> ps aux | grep systemd

# Inspect failed services
docker exec vps-test-<timestamp> systemctl --failed
```

### Image Build Failures

```bash
# Clean Docker cache
docker builder prune

# Rebuild from scratch
docker build --no-cache -t vps-provision-test -f tests/e2e/Dockerfile.test .
```

## Advanced Usage

### Custom Test Configuration

```bash
# Override provisioning config
docker exec -u testuser vps-test-<timestamp> \
  sudo /tmp/vps-provision-test/bin/vps-provision \
  --config /tmp/custom-test.conf
```

### Parallel Test Execution

```bash
# Run multiple isolated tests in parallel
for i in {1..3}; do
  CONTAINER_NAME="vps-test-parallel-$i" ./tests/e2e/run-isolated-test.sh &
done
wait
```

### Extract Artifacts from Container

```bash
# Copy logs from container before cleanup
docker cp vps-test-<timestamp>:/var/log/vps-provision/provision.log ./test-results/

# Extract checkpoint state
docker cp vps-test-<timestamp>:/var/vps-provision/checkpoints/ ./test-checkpoints/
```

### Test Different Configurations

```bash
# Test with minimal config
docker exec -u testuser vps-test-<timestamp> bash -c '
  echo "USERNAME=testuser" > /tmp/test.conf
  echo "INSTALL_VSCODE=false" >> /tmp/test.conf
  sudo /tmp/vps-provision-test/bin/vps-provision --config /tmp/test.conf
'
```

## Performance Considerations

**Image Build**: ~2-3 minutes (cached on subsequent runs)
**Container Startup**: ~5-10 seconds (systemd init)
**Test Execution**: ~15-20 minutes (full provisioning)

**Optimization Tips:**

- Reuse built image (don't rebuild unless Dockerfile changes)
- Use `--keep-container` for iterative debugging
- Run unit/integration tests before full E2E to fail fast

## CI/CD Integration

### GitHub Actions Example

```yaml
jobs:
  test-isolated:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build test environment
        run: make test-e2e-isolated-build

      - name: Run isolated E2E tests
        run: make test-e2e-isolated

      - name: Upload logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-logs
          path: /tmp/test-results/
```

## Comparison: Isolated vs. Non-Isolated Testing

| Aspect                 | Isolated (Docker)                | Non-Isolated (Host)          |
| ---------------------- | -------------------------------- | ---------------------------- |
| **Safety**             | ✅ Complete isolation            | ❌ Can corrupt host          |
| **Cleanup**            | ✅ Automatic (destroy container) | ⚠️ Manual rollback required  |
| **Reproducibility**    | ✅ Fresh environment each run    | ❌ Affected by previous runs |
| **Parallel Execution** | ✅ Multiple containers           | ❌ Conflicts likely          |
| **Performance**        | ⚠️ ~10% overhead (startup)       | ✅ Direct execution          |
| **Requirements**       | Docker daemon                    | Root access                  |

**Recommendation**: Always use isolated testing for E2E. Reserve non-isolated tests for unit/integration only.

## References

- [Docker Best Practices for Testing](https://docs.docker.com/develop/dev-best-practices/)
- [Systemd in Containers](https://systemd.io/CONTAINER_INTERFACE/)
- [Azure DevTest Labs Isolation Patterns](https://learn.microsoft.com/en-us/azure/devtest-labs/)
- Project: `tests/e2e/run-isolated-test.sh` (implementation details)
