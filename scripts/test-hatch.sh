#!/usr/bin/env bash
set -euo pipefail

# test-hatch.sh — Quick test for hatch.sh functionality
# Tests instance creation without requiring Docker build

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Test configuration
TEST_INSTANCE="test-hatch-$(date +%s)"
TEST_PORT="18790"
INSTANCE_DIR="$ROOT_DIR/instances/$TEST_INSTANCE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}✓${NC} $1"
}

test_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}✗${NC} $1"
  return 1
}

# Cleanup function
cleanup() {
  if [[ -d "$INSTANCE_DIR" ]]; then
    rm -rf "$INSTANCE_DIR"
  fi
}

trap cleanup EXIT

echo "========================================"
echo "🦞 Hatchery Quick Test"
echo "========================================"
echo ""

# Test 1: hatch.sh creates instance
echo "Test 1: Creating instance with hatch.sh..."
if "$SCRIPT_DIR/hatch.sh" "$TEST_INSTANCE" --port "$TEST_PORT" > /dev/null; then
  test_pass "hatch.sh executed successfully"
else
  test_fail "hatch.sh failed"
  exit 1
fi

# Test 2: Verify instance directory exists
echo "Test 2: Checking instance directory..."
if [[ -d "$INSTANCE_DIR" ]]; then
  test_pass "Instance directory created at $INSTANCE_DIR"
else
  test_fail "Instance directory not found"
  exit 1
fi

# Test 3: Verify required files
echo "Test 3: Verifying required files..."
required_files=(
  "docker-compose.yml"
  "Dockerfile"
  ".env.example"
  ".gitignore"
  "openclaw.template.json"
  "entrypoint.sh"
)

for file in "${required_files[@]}"; do
  if [[ -f "$INSTANCE_DIR/$file" ]]; then
    test_pass "  $file exists"
  else
    test_fail "  $file missing"
  fi
done

# Test 4: Verify workspace structure
echo "Test 4: Verifying workspace structure..."
workspace_files=(
  "workspace/AGENTS.md"
  "workspace/SOUL.md"
  "workspace/IDENTITY.md"
  "workspace/USER.md"
  "workspace/HEARTBEAT.md"
)

for file in "${workspace_files[@]}"; do
  if [[ -f "$INSTANCE_DIR/$file" ]]; then
    test_pass "  $file exists"
  else
    test_fail "  $file missing"
  fi
done

# Test 5: Verify workspace directories
echo "Test 5: Verifying workspace directories..."
workspace_dirs=(
  "workspace/memory"
  "workspace/reference"
  "data"
)

for dir in "${workspace_dirs[@]}"; do
  if [[ -d "$INSTANCE_DIR/$dir" ]]; then
    test_pass "  $dir exists"
  else
    test_fail "  $dir missing"
  fi
done

# Test 6: Verify port configuration
echo "Test 6: Verifying port configuration..."
if grep -q "${TEST_PORT}:18789" "$INSTANCE_DIR/docker-compose.yml"; then
  test_pass "Port ${TEST_PORT} correctly configured in docker-compose.yml"
else
  test_fail "Port configuration incorrect"
fi

# Test 7: Verify container name
echo "Test 7: Verifying container name..."
if grep -q "hatchery-${TEST_INSTANCE}" "$INSTANCE_DIR/docker-compose.yml"; then
  test_pass "Container name set to hatchery-${TEST_INSTANCE}"
else
  test_fail "Container name incorrect"
fi

# Test 8: Verify .env.example content
echo "Test 8: Verifying .env.example..."
if [[ -f "$INSTANCE_DIR/.env.example" ]]; then
  if grep -q "ANTHROPIC_API_KEY=" "$INSTANCE_DIR/.env.example" && \
     grep -q "OPENAI_API_KEY=" "$INSTANCE_DIR/.env.example"; then
    test_pass ".env.example contains API key placeholders"
  else
    test_fail ".env.example missing expected API key placeholders"
  fi
else
  test_fail ".env.example not found"
fi

# Test 9: Verify workspace file content
echo "Test 9: Verifying workspace file content..."
if grep -q "SOUL.md" "$INSTANCE_DIR/workspace/AGENTS.md"; then
  test_pass "AGENTS.md contains expected instructions"
else
  test_fail "AGENTS.md doesn't contain expected content"
fi

# Test 10: Verify openclaw.template.json contains variable placeholders
echo "Test 10: Verifying openclaw.template.json..."
if [[ -f "$INSTANCE_DIR/openclaw.template.json" ]]; then
  if grep -q '\$ANTHROPIC_API_KEY' "$INSTANCE_DIR/openclaw.template.json" && \
     grep -q '\$DISCORD_BOT_TOKEN' "$INSTANCE_DIR/openclaw.template.json"; then
    test_pass "openclaw.template.json contains variable placeholders"
  else
    test_fail "openclaw.template.json missing expected variable placeholders"
  fi
else
  test_fail "openclaw.template.json not found"
fi

# Test 11: Verify entrypoint.sh is executable
echo "Test 11: Verifying entrypoint.sh..."
if [[ -f "$INSTANCE_DIR/entrypoint.sh" ]]; then
  if grep -q "envsubst" "$INSTANCE_DIR/entrypoint.sh"; then
    test_pass "entrypoint.sh contains envsubst logic"
  else
    test_fail "entrypoint.sh missing envsubst logic"
  fi
else
  test_fail "entrypoint.sh not found"
fi

# Test 12: Verify .gitignore contains openclaw.json
echo "Test 12: Verifying .gitignore..."
if [[ -f "$INSTANCE_DIR/.gitignore" ]]; then
  if grep -q "openclaw.json" "$INSTANCE_DIR/.gitignore"; then
    test_pass ".gitignore includes openclaw.json"
  else
    test_fail ".gitignore missing openclaw.json"
  fi
else
  test_fail ".gitignore not found"
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
  echo ""
  echo "Note: This test validates hatch.sh functionality."
  echo "For full end-to-end testing including Docker, run: ./scripts/e2e-test.sh"
  exit 0
else
  echo -e "${RED}✗ Some tests failed${NC}"
  exit 1
fi
