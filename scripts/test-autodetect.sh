#!/usr/bin/env bash
set -euo pipefail

# test-autodetect.sh — Tests for LLM provider auto-detection in entrypoint.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$ROOT_DIR/template"
ENTRYPOINT="$TEMPLATE_DIR/entrypoint.sh"

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

# run_entrypoint: sets up a temp config dir and runs entrypoint.sh with given env vars.
# Prints the contents of the generated openclaw.json on stdout.
# Usage: run_entrypoint VAR=value ...
run_entrypoint() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  local config_dir="$tmpdir/.openclaw"
  mkdir -p "$config_dir"
  cp "$TEMPLATE_DIR/openclaw.template.json" "$config_dir/openclaw.template.json"

  # Run entrypoint with 'true' as the wrapped command so it exits without launching openclaw
  env -i PATH="$PATH" CONFIG_DIR="$config_dir" "$@" bash "$ENTRYPOINT" true 2>&1 | grep -v "^🦞\|^📝\|^✅\|^🚀\|^🤖" || true

  cat "$config_dir/openclaw.json" 2>/dev/null || true
  rm -rf "$tmpdir"
}

echo "========================================"
echo "🦞 LLM Provider Auto-Detection Tests"
echo "========================================"
echo ""

# Test 1: Only OPENAI_API_KEY → provider: openai, model: gpt-4o
echo "Test 1: Only OPENAI_API_KEY set..."
config=$(run_entrypoint OPENAI_API_KEY="sk-openai-test-key")
if echo "$config" | grep -q '"provider": "openai"' && \
   echo "$config" | grep -q '"model": "gpt-4o"' && \
   echo "$config" | grep -q '"apiKey": "sk-openai-test-key"'; then
  test_pass "Only OPENAI_API_KEY → provider=openai, model=gpt-4o"
else
  test_fail "Only OPENAI_API_KEY → expected provider=openai, model=gpt-4o"
  echo "  Got config: $config"
fi

# Test 2: Only ANTHROPIC_API_KEY → provider: anthropic, model: claude-3-5-sonnet-20241022
echo "Test 2: Only ANTHROPIC_API_KEY set..."
config=$(run_entrypoint ANTHROPIC_API_KEY="sk-ant-test-key")
if echo "$config" | grep -q '"provider": "anthropic"' && \
   echo "$config" | grep -q '"model": "claude-3-5-sonnet-20241022"' && \
   echo "$config" | grep -q '"apiKey": "sk-ant-test-key"'; then
  test_pass "Only ANTHROPIC_API_KEY → provider=anthropic, model=claude-3-5-sonnet-20241022"
else
  test_fail "Only ANTHROPIC_API_KEY → expected provider=anthropic, model=claude-3-5-sonnet-20241022"
  echo "  Got config: $config"
fi

# Test 3: Only GOOGLE_API_KEY → provider: google, model: gemini-2.0-flash
echo "Test 3: Only GOOGLE_API_KEY set..."
config=$(run_entrypoint GOOGLE_API_KEY="google-test-key")
if echo "$config" | grep -q '"provider": "google"' && \
   echo "$config" | grep -q '"model": "gemini-2.0-flash"' && \
   echo "$config" | grep -q '"apiKey": "google-test-key"'; then
  test_pass "Only GOOGLE_API_KEY → provider=google, model=gemini-2.0-flash"
else
  test_fail "Only GOOGLE_API_KEY → expected provider=google, model=gemini-2.0-flash"
  echo "  Got config: $config"
fi

# Test 4: Only XAI_API_KEY → provider: xai, model: grok-3-mini
echo "Test 4: Only XAI_API_KEY set..."
config=$(run_entrypoint XAI_API_KEY="xai-test-key")
if echo "$config" | grep -q '"provider": "xai"' && \
   echo "$config" | grep -q '"model": "grok-3-mini"' && \
   echo "$config" | grep -q '"apiKey": "xai-test-key"'; then
  test_pass "Only XAI_API_KEY → provider=xai, model=grok-3-mini"
else
  test_fail "Only XAI_API_KEY → expected provider=xai, model=grok-3-mini"
  echo "  Got config: $config"
fi

# Test 5: Both OPENAI_API_KEY and ANTHROPIC_API_KEY → default to anthropic
echo "Test 5: Both OPENAI_API_KEY and ANTHROPIC_API_KEY set..."
config=$(run_entrypoint OPENAI_API_KEY="sk-openai-test" ANTHROPIC_API_KEY="sk-ant-test")
if echo "$config" | grep -q '"provider": "anthropic"' && \
   echo "$config" | grep -q '"model": "claude-3-5-sonnet-20241022"'; then
  test_pass "Multiple keys (with ANTHROPIC) → defaults to anthropic"
else
  test_fail "Multiple keys (with ANTHROPIC) → expected default provider=anthropic"
  echo "  Got config: $config"
fi

# Test 5b: Multiple keys set but ANTHROPIC_API_KEY not among them → picks first available
echo "Test 5b: OPENAI_API_KEY and GOOGLE_API_KEY set (no anthropic)..."
config=$(run_entrypoint OPENAI_API_KEY="sk-openai-test" GOOGLE_API_KEY="google-test")
if echo "$config" | grep -q '"provider": "openai"' && \
   echo "$config" | grep -q '"apiKey": "sk-openai-test"'; then
  test_pass "Multiple keys (no ANTHROPIC) → picks first available (openai)"
else
  test_fail "Multiple keys (no ANTHROPIC) → expected provider=openai"
  echo "  Got config: $config"
fi

# Test 6: Explicit LLM_PROVIDER overrides auto-detection
echo "Test 6: Explicit LLM_PROVIDER overrides auto-detection..."
config=$(run_entrypoint \
  OPENAI_API_KEY="sk-openai-test" \
  LLM_PROVIDER="openai" \
  LLM_MODEL="gpt-4-turbo" \
  LLM_API_KEY="sk-openai-test")
if echo "$config" | grep -q '"provider": "openai"' && \
   echo "$config" | grep -q '"model": "gpt-4-turbo"'; then
  test_pass "Explicit LLM_PROVIDER/LLM_MODEL respected"
else
  test_fail "Explicit LLM_PROVIDER/LLM_MODEL not respected"
  echo "  Got config: $config"
fi

# Test 7: No API keys → entrypoint should exit with error
echo "Test 7: No API keys → should fail..."
tmpdir="$(mktemp -d)"
config_dir="$tmpdir/.openclaw"
mkdir -p "$config_dir"
cp "$TEMPLATE_DIR/openclaw.template.json" "$config_dir/openclaw.template.json"
if env -i PATH="$PATH" CONFIG_DIR="$config_dir" bash "$ENTRYPOINT" true 2>/dev/null; then
  test_fail "No API keys → expected failure but succeeded"
else
  test_pass "No API keys → entrypoint correctly exits with error"
fi
rm -rf "$tmpdir"

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
