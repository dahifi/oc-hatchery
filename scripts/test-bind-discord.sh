#!/usr/bin/env bash
set -euo pipefail

# test-bind-discord.sh — Tests for bind-discord.sh
# Validates argument handling, dependency checks, API error handling,
# and JSON output format using a mock curl in a temporary PATH.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOCK_DIR="$(mktemp -d)"
ORIG_PATH="$PATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}✓${NC} $1"
}

test_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}✗${NC} $1"
}

cleanup() {
  rm -rf "$MOCK_DIR"
}
trap cleanup EXIT

# Helper: write a fake curl that returns preset body + status code.
# Usage: make_mock_curl <response_file>
# The response file holds lines of the form:
#   <url_pattern> <status_code> <json_body>
# where url_pattern is a substring matched against the last argument to curl.
make_mock_curl() {
  local responses_file="$1"
  cat > "$MOCK_DIR/curl" << 'MOCK'
#!/usr/bin/env bash
# Fake curl: reads MOCK_RESPONSES_FILE for URL-pattern → response mappings.
# Mimics `curl -s -w "\n%{http_code}" ... <url>`
url="${@: -1}"
while IFS='|' read -r pattern status body; do
  if [[ "$url" == *"$pattern"* ]]; then
    printf '%s\n%s' "$body" "$status"
    exit 0
  fi
done < "$MOCK_RESPONSES_FILE"
# No match → simulate connection error with empty body + 000
printf '\n000'
MOCK
  chmod +x "$MOCK_DIR/curl"
  export MOCK_RESPONSES_FILE="$responses_file"
  export PATH="$MOCK_DIR:$ORIG_PATH"
}

echo "========================================"
echo "🦞 bind-discord.sh Tests"
echo "========================================"
echo ""

# ---------------------------------------------------------------------------
# Test 1: No arguments → usage error
# ---------------------------------------------------------------------------
echo "Test 1: No arguments → usage error..."
if "$SCRIPT_DIR/bind-discord.sh" 2>/dev/null; then
  test_fail "Should have exited with error when no token provided"
else
  test_pass "Exits with error when no token provided"
fi

# ---------------------------------------------------------------------------
# Test 2: Unknown option → usage error
# ---------------------------------------------------------------------------
echo "Test 2: Unknown option → exits with error..."
if "$SCRIPT_DIR/bind-discord.sh" fake-token --unknown-flag 2>/dev/null; then
  test_fail "Should have exited with error on unknown option"
else
  test_pass "Exits with error on unknown option"
fi

# ---------------------------------------------------------------------------
# Test 3: Missing jq dependency
# ---------------------------------------------------------------------------
echo "Test 3: Missing jq dependency → error..."
# Temporarily shadow jq with a non-existent path
(
  MISSING_DIR="$(mktemp -d)"
  # jq is NOT placed in MISSING_DIR, but curl is still available
  cp "$(command -v curl)" "$MISSING_DIR/curl" 2>/dev/null || true
  export PATH="$MISSING_DIR:$(echo "$PATH" | tr ':' '\n' | grep -v "^$MISSING_DIR$" | grep -v jq | tr '\n' ':' | sed 's/:$//')"
  if command -v jq &>/dev/null; then
    # jq still found, can't test this without removing it; skip
    echo "  (skipped: cannot shadow jq on this system)"
  else
    if "$SCRIPT_DIR/bind-discord.sh" fake-token 2>/dev/null; then
      test_fail "Should have exited when jq missing"
    else
      test_pass "Exits with error when jq is missing"
    fi
  fi
  rm -rf "$MISSING_DIR"
)

# ---------------------------------------------------------------------------
# Test 4: Discord API returns 401 (invalid token) → error
# ---------------------------------------------------------------------------
echo "Test 4: API returns 401 → exits with error..."

responses_file="$(mktemp)"
printf 'users/@me/guilds|401|{"code":0,"message":"401: Unauthorized"}\n' > "$responses_file"
make_mock_curl "$responses_file"

if DISCORD_API="https://mock.discord.test" \
   "$SCRIPT_DIR/bind-discord.sh" bad-token --all 2>/dev/null; then
  test_fail "Should have exited on HTTP 401"
else
  test_pass "Exits with error on HTTP 401 from guilds endpoint"
fi


# ---------------------------------------------------------------------------
# Test 5: Bot is in zero guilds → error
# ---------------------------------------------------------------------------
echo "Test 5: Empty guild list → exits with error..."

responses_file="$(mktemp)"
printf 'users/@me/guilds|200|[]\n' > "$responses_file"
make_mock_curl "$responses_file"

if DISCORD_API="https://mock.discord.test" \
   "$SCRIPT_DIR/bind-discord.sh" my-token --all 2>/dev/null; then
  test_fail "Should have exited when bot is in no guilds"
else
  test_pass "Exits with error when guild list is empty"
fi

# ---------------------------------------------------------------------------
# Test 6: No text channels in any guild → error
# ---------------------------------------------------------------------------
echo "Test 6: No text channels → exits with error..."

responses_file="$(mktemp)"
cat > "$responses_file" << 'EOF'
users/@me/guilds|200|[{"id":"111","name":"TestServer"}]
guilds/111/channels|200|[{"id":"222","name":"voice-lobby","type":2}]
EOF
make_mock_curl "$responses_file"

if DISCORD_API="https://mock.discord.test" \
   "$SCRIPT_DIR/bind-discord.sh" my-token --all 2>/dev/null; then
  test_fail "Should have exited when no text channels found"
else
  test_pass "Exits with error when no text channels found"
fi

# ---------------------------------------------------------------------------
# Test 7: Valid response + --all → valid JSON array on stdout
# ---------------------------------------------------------------------------
echo "Test 7: Valid API response with --all → valid JSON array..."

responses_file="$(mktemp)"
cat > "$responses_file" << 'EOF'
users/@me/guilds|200|[{"id":"111","name":"TestServer"}]
guilds/111/channels|200|[{"id":"222","name":"general","type":0},{"id":"333","name":"random","type":0},{"id":"444","name":"voice","type":2}]
EOF
make_mock_curl "$responses_file"

output=$(DISCORD_API="https://mock.discord.test" \
  "$SCRIPT_DIR/bind-discord.sh" my-token --all 2>/dev/null)

if echo "$output" | jq -e '. | type == "array"' &>/dev/null; then
  test_pass "--all produces a valid JSON array"
else
  test_fail "--all did not produce a valid JSON array"
  echo "  Output: $output"
fi

# ---------------------------------------------------------------------------
# Test 8: Only text channels are included (not voice)
# ---------------------------------------------------------------------------
echo "Test 8: Only text channels in output..."
channel_count=$(echo "$output" | jq 'length')
if [[ "$channel_count" -eq 2 ]]; then
  test_pass "Output contains exactly 2 text channels (voice channel excluded)"
else
  test_fail "Expected 2 channels, got $channel_count"
  echo "  Output: $output"
fi

# ---------------------------------------------------------------------------
# Test 9: JSON entries have required fields
# ---------------------------------------------------------------------------
echo "Test 9: JSON entries contain required fields..."
required_fields=("guildId" "guildName" "channelId" "channelName")
all_fields_present=true
for field in "${required_fields[@]}"; do
  if ! echo "$output" | jq -e ".[0].${field}" &>/dev/null; then
    test_fail "Missing field '$field' in output"
    all_fields_present=false
  fi
done
if [[ "$all_fields_present" == "true" ]]; then
  test_pass "All required fields present (guildId, guildName, channelId, channelName)"
fi

# ---------------------------------------------------------------------------
# Test 10: Field values are correct
# ---------------------------------------------------------------------------
echo "Test 10: Field values are correct..."
guild_id=$(echo "$output" | jq -r '.[0].guildId')
guild_name=$(echo "$output" | jq -r '.[0].guildName')
channel_id=$(echo "$output" | jq -r '.[0].channelId')
channel_name=$(echo "$output" | jq -r '.[0].channelName')

if [[ "$guild_id" == "111" ]] && \
   [[ "$guild_name" == "TestServer" ]] && \
   [[ "$channel_id" == "222" ]] && \
   [[ "$channel_name" == "general" ]]; then
  test_pass "Field values match expected Discord API data"
else
  test_fail "Field values do not match expected data"
  echo "  guildId=$guild_id guildName=$guild_name channelId=$channel_id channelName=$channel_name"
fi

# ---------------------------------------------------------------------------
# Test 11: Status messages go to stderr, not stdout
# ---------------------------------------------------------------------------
echo "Test 11: Status messages go to stderr, not stdout..."

responses_file="$(mktemp)"
cat > "$responses_file" << 'EOF'
users/@me/guilds|200|[{"id":"111","name":"TestServer"}]
guilds/111/channels|200|[{"id":"222","name":"general","type":0}]
EOF
make_mock_curl "$responses_file"

stdout_output=$(DISCORD_API="https://mock.discord.test" \
  "$SCRIPT_DIR/bind-discord.sh" my-token --all 2>/dev/null)

if echo "$stdout_output" | jq -e '.' &>/dev/null; then
  test_pass "stdout is pure JSON (status messages on stderr)"
else
  test_fail "stdout contains non-JSON content"
  echo "  stdout: $stdout_output"
fi

# ---------------------------------------------------------------------------
# Test 12: Multiple guilds produce entries from all guilds
# ---------------------------------------------------------------------------
echo "Test 12: Multiple guilds → entries from all guilds..."

responses_file="$(mktemp)"
cat > "$responses_file" << 'EOF'
users/@me/guilds|200|[{"id":"111","name":"Server1"},{"id":"222","name":"Server2"}]
guilds/111/channels|200|[{"id":"333","name":"general","type":0}]
guilds/222/channels|200|[{"id":"444","name":"announcements","type":0}]
EOF
make_mock_curl "$responses_file"

output=$(DISCORD_API="https://mock.discord.test" \
  "$SCRIPT_DIR/bind-discord.sh" my-token --all 2>/dev/null)

count=$(echo "$output" | jq 'length')
if [[ "$count" -eq 2 ]]; then
  test_pass "Channels from multiple guilds all included ($count entries)"
else
  test_fail "Expected 2 entries from 2 guilds, got $count"
  echo "  Output: $output"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
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
