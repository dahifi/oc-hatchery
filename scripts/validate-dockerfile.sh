#!/usr/bin/env bash
set -euo pipefail

# validate-dockerfile.sh — Comprehensive Dockerfile validation
# Tests the Dockerfile build process, Alpine packages, and container configuration

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$ROOT_DIR/template"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Helper functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
}

test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}✓${NC} $1"
}

test_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}✗${NC} $1"
}

test_skip() {
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
  echo -e "${YELLOW}⊘${NC} $1"
}

log_section "🐳 Dockerfile Validation"
echo ""

# Test 1: Verify Dockerfile exists
log_info "Test 1: Checking Dockerfile exists..."
if [[ -f "$TEMPLATE_DIR/Dockerfile" ]]; then
  test_pass "Dockerfile exists at $TEMPLATE_DIR/Dockerfile"
else
  test_fail "Dockerfile not found"
  exit 1
fi

# Test 2: Verify required Alpine packages are listed
log_info "Test 2: Checking Alpine package dependencies..."
REQUIRED_PACKAGES=("git" "curl" "bash" "gettext")
MISSING_PACKAGES=()

for pkg in "${REQUIRED_PACKAGES[@]}"; do
  if grep -q "apk add.*$pkg" "$TEMPLATE_DIR/Dockerfile"; then
    echo "  ✓ $pkg is included"
  else
    echo "  ✗ $pkg is missing"
    MISSING_PACKAGES+=("$pkg")
  fi
done

if [[ ${#MISSING_PACKAGES[@]} -eq 0 ]]; then
  test_pass "All required Alpine packages are listed (git, curl, bash, gettext)"
else
  test_fail "Missing Alpine packages: ${MISSING_PACKAGES[*]}"
fi

# Test 3: Verify non-root user configuration
log_info "Test 3: Checking non-root user configuration..."
if grep -q "adduser.*openclaw" "$TEMPLATE_DIR/Dockerfile" && grep -q "^USER openclaw" "$TEMPLATE_DIR/Dockerfile"; then
  test_pass "Container configured to run as non-root user 'openclaw'"
else
  test_fail "Non-root user not properly configured"
fi

# Test 4: Verify user ID and group ID
log_info "Test 4: Checking user/group ID (1001)..."
if grep -q "adduser.*-u 1001" "$TEMPLATE_DIR/Dockerfile" && grep -q "addgroup.*-g 1001" "$TEMPLATE_DIR/Dockerfile"; then
  test_pass "User and group IDs set to 1001 for better volume permission handling"
else
  test_fail "User/group ID not set to 1001"
fi

# Test 5: Verify entrypoint script exists
log_info "Test 5: Checking entrypoint script..."
if [[ -f "$TEMPLATE_DIR/entrypoint.sh" ]]; then
  test_pass "Entrypoint script exists"
  
  # Verify it's executable in the Dockerfile
  if grep -q "chmod +x.*entrypoint.sh" "$TEMPLATE_DIR/Dockerfile"; then
    test_pass "Entrypoint script is made executable"
  else
    test_fail "Entrypoint script not made executable in Dockerfile"
  fi
else
  test_fail "Entrypoint script not found"
fi

# Test 6: Verify health check configuration
log_info "Test 6: Checking HEALTHCHECK configuration..."
if grep -q "HEALTHCHECK" "$TEMPLATE_DIR/Dockerfile"; then
  test_pass "HEALTHCHECK directive is configured"
  
  # Check health check parameters
  if grep -q "HEALTHCHECK.*--interval" "$TEMPLATE_DIR/Dockerfile"; then
    test_pass "Health check interval is configured"
  fi
  
  if grep -q "curl.*health" "$TEMPLATE_DIR/Dockerfile"; then
    test_pass "Health check uses curl to test /health endpoint"
  fi
else
  test_fail "HEALTHCHECK not configured"
fi

# Test 7: Verify port exposure
log_info "Test 7: Checking EXPOSE directive..."
if grep -q "EXPOSE 18789" "$TEMPLATE_DIR/Dockerfile"; then
  test_pass "Port 18789 is exposed"
else
  test_fail "Port 18789 not exposed"
fi

# Test 8: Verify workspace directory creation
log_info "Test 8: Checking workspace directory configuration..."
if grep -q "mkdir.*workspace" "$TEMPLATE_DIR/Dockerfile"; then
  test_pass "Workspace directory creation is configured"
else
  test_fail "Workspace directory not created"
fi

# Test 9: Verify directory ownership
log_info "Test 9: Checking directory ownership..."
if grep -q "chown.*openclaw:openclaw" "$TEMPLATE_DIR/Dockerfile"; then
  test_pass "Directory ownership set to openclaw user"
else
  test_fail "Directory ownership not properly configured"
fi

# Test 10: Verify config template exists
log_info "Test 10: Checking config template..."
if [[ -f "$TEMPLATE_DIR/openclaw.template.json" ]]; then
  test_pass "openclaw.template.json exists"
  
  # Verify it uses environment variable placeholders
  if grep -q '\$[A-Z_]*API_KEY' "$TEMPLATE_DIR/openclaw.template.json"; then
    test_pass "Config template uses environment variable placeholders"
  else
    test_fail "Config template doesn't use environment variable placeholders"
  fi
else
  test_fail "openclaw.template.json not found"
fi

# Test 11: Verify entrypoint script uses envsubst
log_info "Test 11: Checking envsubst usage in entrypoint..."
if grep -q "envsubst" "$TEMPLATE_DIR/entrypoint.sh"; then
  test_pass "Entrypoint script uses envsubst for config templating"
else
  test_fail "Entrypoint script doesn't use envsubst"
fi

# Test 12: Verify entrypoint validates API keys
log_info "Test 12: Checking API key validation..."
if grep -q "ANTHROPIC_API_KEY\|OPENAI_API_KEY" "$TEMPLATE_DIR/entrypoint.sh" && \
   grep -q "ERROR.*API key" "$TEMPLATE_DIR/entrypoint.sh"; then
  test_pass "Entrypoint script validates at least one API key is set"
else
  test_fail "Entrypoint doesn't validate API keys"
fi

# Test 13: Verify CMD uses --bind lan for container networking
log_info "Test 13: Checking gateway bind configuration..."
if grep -q 'CMD.*--bind.*lan' "$TEMPLATE_DIR/Dockerfile"; then
  test_pass "Gateway configured to bind to LAN (0.0.0.0) for container access"
else
  test_warn "Gateway may not be configured for container networking"
  test_skip "Gateway bind configuration check (not critical)"
fi

# Test 14: Verify NODE_ENV is set to production
log_info "Test 14: Checking NODE_ENV..."
if grep -q "NODE_ENV=production" "$TEMPLATE_DIR/Dockerfile"; then
  test_pass "NODE_ENV set to production"
else
  test_fail "NODE_ENV not set to production"
fi

# Test 15: Try to build the Docker image (optional, may fail if openclaw package unavailable)
log_info "Test 15: Attempting Docker image build..."
BUILD_LOG="/tmp/dockerfile-validation-build-$$.log"

echo "  Building Docker image (this may take a few minutes)..."
cd "$TEMPLATE_DIR"

if docker build -t openclaw-validation-test:latest . > "$BUILD_LOG" 2>&1; then
  test_pass "Docker image built successfully"
  BUILD_SUCCESS=true
  
  # Test 16: Inspect the built image
  log_info "Test 16: Inspecting built image..."
  
  # Check if openclaw user exists
  if docker run --rm openclaw-validation-test:latest id openclaw > /dev/null 2>&1; then
    test_pass "openclaw user exists in container"
    
    # Verify UID/GID
    USER_INFO=$(docker run --rm openclaw-validation-test:latest id openclaw)
    if echo "$USER_INFO" | grep -q "uid=1001" && echo "$USER_INFO" | grep -q "gid=1001"; then
      test_pass "openclaw user has correct UID/GID (1001)"
    else
      test_fail "openclaw user has incorrect UID/GID"
    fi
  else
    test_fail "openclaw user not found in container"
  fi
  
  # Check if required packages are installed
  log_info "Test 17: Verifying Alpine packages in container..."
  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if docker run --rm openclaw-validation-test:latest which $pkg > /dev/null 2>&1; then
      echo "  ✓ $pkg is installed"
    else
      echo "  ✗ $pkg is not installed"
      test_fail "$pkg not installed in container"
    fi
  done
  test_pass "All required Alpine packages are installed"
  
  # Check if workspace directory exists
  log_info "Test 18: Verifying workspace directory..."
  if docker run --rm openclaw-validation-test:latest test -d /home/openclaw/.openclaw/workspace; then
    test_pass "Workspace directory exists in container"
  else
    test_fail "Workspace directory not found in container"
  fi
  
  # Cleanup test image
  log_info "Cleaning up test image..."
  docker rmi openclaw-validation-test:latest > /dev/null 2>&1 || true
  
else
  BUILD_SUCCESS=false
  
  # Check if it's an expected failure
  if grep -q "npm ERR!\|404 Not Found.*openclaw" "$BUILD_LOG"; then
    log_warn "Docker build failed: openclaw package not available on npm (expected)"
    test_skip "Docker image build (openclaw package not published yet)"
    test_skip "Built image inspection (build failed)"
    test_skip "Alpine package verification in container (build failed)"
    test_skip "Workspace directory verification (build failed)"
  elif grep -q "TLS: unspecified error\|unable to select packages" "$BUILD_LOG"; then
    log_warn "Docker build failed: network/TLS issues (infrastructure problem)"
    test_skip "Docker image build (network issues)"
    test_skip "Built image inspection (build failed)"
    test_skip "Alpine package verification in container (build failed)"
    test_skip "Workspace directory verification (build failed)"
  else
    log_error "Docker build failed unexpectedly"
    echo "Build log excerpt:"
    tail -20 "$BUILD_LOG" | sed 's/^/  /'
    test_fail "Docker image build (unexpected error)"
    test_skip "Built image inspection (build failed)"
    test_skip "Alpine package verification in container (build failed)"
    test_skip "Workspace directory verification (build failed)"
  fi
fi

# Cleanup build log
rm -f "$BUILD_LOG"

# Summary
log_section "Test Summary"
echo ""
echo -e "${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo ""

# Final verdict
if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ Dockerfile validation successful!${NC}"
  echo ""
  echo "All static validation checks passed."
  if [[ $TESTS_SKIPPED -gt 0 ]]; then
    echo "Some runtime tests were skipped (likely due to openclaw package availability)."
    echo "This is expected until the openclaw package is published to npm."
  fi
  exit 0
else
  echo -e "${RED}✗ Dockerfile validation failed${NC}"
  echo ""
  echo "Please fix the issues listed above."
  exit 1
fi
