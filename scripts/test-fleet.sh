#!/usr/bin/env bash
set -euo pipefail

# test-fleet.sh — Test fleet management functionality
# Tests fleet registry, auto-port assignment, and fleet commands

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
FLEET_REGISTRY="$ROOT_DIR/fleet.json"

# Test configuration
TEST_INSTANCE1="test-fleet-1-$(date +%s)"
TEST_INSTANCE2="test-fleet-2-$(date +%s)"
INSTANCE_DIR1="$ROOT_DIR/instances/$TEST_INSTANCE1"
INSTANCE_DIR2="$ROOT_DIR/instances/$TEST_INSTANCE2"

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
  if [[ -d "$INSTANCE_DIR1" ]]; then
    rm -rf "$INSTANCE_DIR1"
  fi
  if [[ -d "$INSTANCE_DIR2" ]]; then
    rm -rf "$INSTANCE_DIR2"
  fi
  # Clean up test instances from fleet.json
  if [[ -f "$FLEET_REGISTRY" ]]; then
    tmp_file=$(mktemp)
    jq "del(.instances[\"$TEST_INSTANCE1\"]) | del(.instances[\"$TEST_INSTANCE2\"])" "$FLEET_REGISTRY" > "$tmp_file" && mv "$tmp_file" "$FLEET_REGISTRY"
  fi
}

trap cleanup EXIT

echo "========================================"
echo "🦞 Fleet Management Test"
echo "========================================"
echo ""

# Test 1: Create instance with auto-port assignment
echo "Test 1: Auto-port assignment..."
if "$SCRIPT_DIR/hatch.sh" "$TEST_INSTANCE1" > /dev/null 2>&1; then
  test_pass "Created instance with auto-assigned port"
else
  test_fail "Failed to create instance with auto-port"
  exit 1
fi

# Test 2: Verify fleet.json was created and contains instance
echo "Test 2: Verifying fleet.json..."
if [[ -f "$FLEET_REGISTRY" ]]; then
  test_pass "fleet.json exists"
  
  # Check if instance is in registry
  if jq -e ".instances[\"$TEST_INSTANCE1\"]" "$FLEET_REGISTRY" > /dev/null 2>&1; then
    test_pass "Instance registered in fleet.json"
  else
    test_fail "Instance not found in fleet.json"
  fi
  
  # Check if port is assigned
  port1=$(jq -r ".instances[\"$TEST_INSTANCE1\"].port" "$FLEET_REGISTRY" 2>/dev/null)
  if [[ -n "$port1" ]] && [[ "$port1" != "null" ]]; then
    test_pass "Port assigned in fleet.json: $port1"
  else
    test_fail "Port not assigned in fleet.json"
  fi
else
  test_fail "fleet.json not created"
fi

# Test 3: Create second instance and verify it gets different port
echo "Test 3: Sequential auto-port assignment..."
if "$SCRIPT_DIR/hatch.sh" "$TEST_INSTANCE2" > /dev/null 2>&1; then
  test_pass "Created second instance"
  
  port2=$(jq -r ".instances[\"$TEST_INSTANCE2\"].port" "$FLEET_REGISTRY" 2>/dev/null)
  if [[ "$port1" != "$port2" ]]; then
    test_pass "Second instance has different port: $port2"
  else
    test_fail "Second instance has same port as first"
  fi
else
  test_fail "Failed to create second instance"
fi

# Test 4: Verify manual port assignment still works
echo "Test 4: Manual port assignment..."
TEST_INSTANCE3="test-fleet-3-$(date +%s)"
INSTANCE_DIR3="$ROOT_DIR/instances/$TEST_INSTANCE3"
MANUAL_PORT=19999

if "$SCRIPT_DIR/hatch.sh" "$TEST_INSTANCE3" --port "$MANUAL_PORT" > /dev/null 2>&1; then
  test_pass "Created instance with manual port"
  
  port3=$(jq -r ".instances[\"$TEST_INSTANCE3\"].port" "$FLEET_REGISTRY" 2>/dev/null)
  if [[ "$port3" == "$MANUAL_PORT" ]]; then
    test_pass "Manual port correctly assigned: $port3"
  else
    test_fail "Manual port not correctly assigned (expected $MANUAL_PORT, got $port3)"
  fi
  
  # Cleanup
  rm -rf "$INSTANCE_DIR3"
  tmp_file=$(mktemp)
  jq "del(.instances[\"$TEST_INSTANCE3\"])" "$FLEET_REGISTRY" > "$tmp_file" && mv "$tmp_file" "$FLEET_REGISTRY"
else
  test_fail "Failed to create instance with manual port"
fi

# Test 5: Verify port conflict detection
echo "Test 5: Port conflict detection..."
TEST_INSTANCE4="test-fleet-4-$(date +%s)"
if "$SCRIPT_DIR/hatch.sh" "$TEST_INSTANCE4" --port "$port1" > /dev/null 2>&1; then
  test_fail "Should have rejected duplicate port"
  rm -rf "$ROOT_DIR/instances/$TEST_INSTANCE4"
  tmp_file=$(mktemp)
  jq "del(.instances[\"$TEST_INSTANCE4\"])" "$FLEET_REGISTRY" > "$tmp_file" && mv "$tmp_file" "$FLEET_REGISTRY"
else
  test_pass "Correctly rejected duplicate port assignment"
fi

# Test 6: Test fleet.sh status command
echo "Test 6: Fleet status command..."
if "$SCRIPT_DIR/fleet.sh" status > /dev/null 2>&1; then
  test_pass "fleet.sh status executed successfully"
else
  test_fail "fleet.sh status failed"
fi

# Test 9: Test fleet.sh health command runs successfully
echo "Test 9: Fleet health command..."
if "$SCRIPT_DIR/fleet.sh" health > /dev/null 2>&1; then
  test_pass "fleet.sh health executed successfully"
else
  test_fail "fleet.sh health failed"
fi

# Test 10: Verify fleet.sh health output format
echo "Test 10: Fleet health output format..."
health_output=$("$SCRIPT_DIR/fleet.sh" health 2>&1)
if echo "$health_output" | grep -q "INSTANCE"; then
  test_pass "fleet.sh health shows INSTANCE header"
else
  test_fail "fleet.sh health missing INSTANCE header"
fi
if echo "$health_output" | grep -q "HTTP"; then
  test_pass "fleet.sh health shows HTTP header"
else
  test_fail "fleet.sh health missing HTTP header"
fi
if echo "$health_output" | grep -q "RESPONSE TIME"; then
  test_pass "fleet.sh health shows RESPONSE TIME header"
else
  test_fail "fleet.sh health missing RESPONSE TIME header"
fi
if echo "$health_output" | grep -q "$TEST_INSTANCE1"; then
  test_pass "fleet.sh health lists test instance"
else
  test_fail "fleet.sh health does not list test instance"
fi

# Test 7: Verify fleet.json structure
echo "Test 7: Verifying fleet.json structure..."
if jq -e '.instances' "$FLEET_REGISTRY" > /dev/null 2>&1; then
  test_pass "fleet.json has 'instances' object"
  
  # Verify instance has required fields
  if jq -e ".instances[\"$TEST_INSTANCE1\"].port" "$FLEET_REGISTRY" > /dev/null 2>&1 && \
     jq -e ".instances[\"$TEST_INSTANCE1\"].created" "$FLEET_REGISTRY" > /dev/null 2>&1; then
    test_pass "Instance has required fields (port, created)"
  else
    test_fail "Instance missing required fields"
  fi
else
  test_fail "fleet.json missing 'instances' object"
fi

# Test 8: Verify created timestamp format
echo "Test 8: Verifying timestamp format..."
created=$(jq -r ".instances[\"$TEST_INSTANCE1\"].created" "$FLEET_REGISTRY" 2>/dev/null)
if [[ "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  test_pass "Timestamp in ISO 8601 format: $created"
else
  test_fail "Timestamp not in expected format: $created"
fi

# Test 9: destroy --force removes instance directory and fleet.json entry
echo "Test 9: destroy --force removes instance..."
TEST_DESTROY="test-destroy-$(date +%s)"
if "$SCRIPT_DIR/hatch.sh" "$TEST_DESTROY" > /dev/null 2>&1; then
  if "$SCRIPT_DIR/fleet.sh" destroy "$TEST_DESTROY" --force > /dev/null 2>&1; then
    if [[ ! -d "$ROOT_DIR/instances/$TEST_DESTROY" ]]; then
      test_pass "Instance directory removed by destroy"
    else
      test_fail "Instance directory still exists after destroy"
      rm -rf "$ROOT_DIR/instances/$TEST_DESTROY"
    fi
    if ! jq -e ".instances[\"$TEST_DESTROY\"]" "$FLEET_REGISTRY" > /dev/null 2>&1; then
      test_pass "Instance removed from fleet.json by destroy"
    else
      test_fail "Instance still in fleet.json after destroy"
      tmp_file=$(mktemp)
      jq "del(.instances[\"$TEST_DESTROY\"])" "$FLEET_REGISTRY" > "$tmp_file" && mv "$tmp_file" "$FLEET_REGISTRY"
    fi
  else
    test_fail "fleet.sh destroy --force failed"
    rm -rf "$ROOT_DIR/instances/$TEST_DESTROY"
    tmp_file=$(mktemp)
    jq "del(.instances[\"$TEST_DESTROY\"])" "$FLEET_REGISTRY" > "$tmp_file" && mv "$tmp_file" "$FLEET_REGISTRY"
  fi
else
  test_fail "Failed to create instance for destroy test"
fi

# Test 10: destroy --force --archive saves a tarball before removal
echo "Test 10: destroy --archive saves workspace..."
TEST_ARCHIVE="test-archive-$(date +%s)"
if "$SCRIPT_DIR/hatch.sh" "$TEST_ARCHIVE" > /dev/null 2>&1; then
  if "$SCRIPT_DIR/fleet.sh" destroy "$TEST_ARCHIVE" --force --archive > /dev/null 2>&1; then
    archive_file=$(ls "$ROOT_DIR/archives/${TEST_ARCHIVE}-"*.tar.gz 2>/dev/null | head -1)
    if [[ -n "$archive_file" && -f "$archive_file" ]]; then
      test_pass "Archive created at $archive_file"
      rm -f "$archive_file"
    else
      test_fail "No archive file found after destroy --archive"
    fi
    if [[ ! -d "$ROOT_DIR/instances/$TEST_ARCHIVE" ]]; then
      test_pass "Instance directory removed when --archive used"
    else
      test_fail "Instance directory still exists after destroy --archive"
      rm -rf "$ROOT_DIR/instances/$TEST_ARCHIVE"
    fi
  else
    test_fail "fleet.sh destroy --force --archive failed"
    rm -rf "$ROOT_DIR/instances/$TEST_ARCHIVE"
    tmp_file=$(mktemp)
    jq "del(.instances[\"$TEST_ARCHIVE\"])" "$FLEET_REGISTRY" > "$tmp_file" && mv "$tmp_file" "$FLEET_REGISTRY"
  fi
else
  test_fail "Failed to create instance for archive test"
fi

# Test 11: destroy nonexistent instance errors
echo "Test 11: destroy nonexistent instance..."
if ! "$SCRIPT_DIR/fleet.sh" destroy "no-such-instance-xyz" --force > /dev/null 2>&1; then
  test_pass "destroy correctly errors on nonexistent instance"
else
  test_fail "destroy should have failed on nonexistent instance"
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
  exit 0
else
  echo -e "${RED}✗ Some tests failed${NC}"
  exit 1
fi
