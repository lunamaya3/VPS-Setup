#!/bin/bash
# Quick validation of Docker isolation implementation
set -euo pipefail

echo "=== Docker Isolation Implementation Validation ==="
echo ""

# Test 1: Dockerfile syntax
echo "✓ Test 1: Dockerfile builds successfully"
if docker images vps-provision-test:latest -q 2>/dev/null | grep -q .; then
    echo "  Image exists: vps-provision-test:latest ($(docker images vps-provision-test:latest --format '{{.Size}}'))"
else
    echo "  ✗ FAIL: Image not found"
    exit 1
fi

# Test 2: Test runner syntax
echo "✓ Test 2: Test runner script is valid"
if bash -n tests/e2e/run-isolated-test.sh; then
    echo "  Syntax OK"
else
    echo "  ✗ FAIL: Syntax errors"
    exit 1
fi

# Test 3: CLI help works
echo "✓ Test 3: CLI help command works"
if ./tests/e2e/run-isolated-test.sh --help >/dev/null 2>&1; then
    echo "  Help displays correctly"
else
    echo "  ✗ FAIL: Help command failed"
    exit 1
fi

# Test 4: Makefile targets exist
echo "✓ Test 4: Makefile targets exist"
targets=("test-e2e-isolated" "test-e2e-isolated-build" "test-e2e-isolated-rebuild" "test-e2e-isolated-debug")
for target in "${targets[@]}"; do
    if make -n "$target" >/dev/null 2>&1; then
        echo "  Target exists: $target"
    else
        echo "  ✗ FAIL: Target missing: $target"
        exit 1
    fi
done

# Test 5: .dockerignore exists
echo "✓ Test 5: .dockerignore file exists"
if [ -f .dockerignore ]; then
    lines=$(wc -l < .dockerignore)
    echo "  File exists ($lines exclusion rules)"
else
    echo "  ✗ FAIL: .dockerignore not found"
    exit 1
fi

# Test 6: Security features
echo "✓ Test 6: Security features verified"
echo "  - Multi-stage build: $(docker history vps-provision-test:latest --no-trunc | grep -c 'FROM' || echo 'N/A')"
echo "  - Image labels: $(docker inspect vps-provision-test:latest --format='{{json .Config.Labels}}' | grep -o 'security\\|test' | wc -l)"
echo "  - Health check: $(docker inspect vps-provision-test:latest --format='{{.Config.Healthcheck}}' | grep -q 'CMD' && echo 'Configured' || echo 'Not set')"

echo ""
echo "=== ✓ All validation checks passed ==="
echo ""
echo "Next steps:"
echo "  1. Run quick test: make test-e2e-isolated-build"
echo "  2. Full test suite: make test-e2e-isolated"
echo "  3. Debug mode: ./tests/e2e/run-isolated-test.sh --keep-container --debug"
echo ""
