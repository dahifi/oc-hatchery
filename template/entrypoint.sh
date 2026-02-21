#!/bin/bash
set -euo pipefail

# entrypoint.sh — Run envsubst on openclaw config template, then start OpenClaw

CONFIG_DIR="${CONFIG_DIR:-/home/openclaw/.openclaw}"
TEMPLATE_FILE="$CONFIG_DIR/openclaw.template.json"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

echo "🦞 OpenClaw Entrypoint"

# Check if template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "⚠️  No openclaw.template.json found. Skipping envsubst step."
  echo "   OpenClaw will use defaults or existing config."
else
  echo "📝 Processing config template with envsubst..."
  
  # Check for at least one LLM API key
  if [[ -z "${ANTHROPIC_API_KEY:-}" ]] && [[ -z "${OPENAI_API_KEY:-}" ]] && [[ -z "${XAI_API_KEY:-}" ]] && [[ -z "${GOOGLE_API_KEY:-}" ]]; then
    echo "❌ ERROR: At least one LLM API key must be set:"
    echo "   - ANTHROPIC_API_KEY"
    echo "   - OPENAI_API_KEY"
    echo "   - XAI_API_KEY"
    echo "   - GOOGLE_API_KEY"
    echo ""
    echo "Set one in your .env file or environment."
    exit 1
  fi
  
  # Provide defaults for optional variables to avoid empty strings
  export DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-}"
  export DISCORD_CLIENT_ID="${DISCORD_CLIENT_ID:-}"
  export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
  export OPENAI_API_KEY="${OPENAI_API_KEY:-}"
  export XAI_API_KEY="${XAI_API_KEY:-}"
  export GOOGLE_API_KEY="${GOOGLE_API_KEY:-}"

  # Auto-detect LLM provider/model from available API keys if not explicitly set
  if [[ -z "${LLM_PROVIDER:-}" ]]; then
    _keys_set=0
    [[ -n "${ANTHROPIC_API_KEY:-}" ]] && _keys_set=$((_keys_set + 1))
    [[ -n "${OPENAI_API_KEY:-}" ]] && _keys_set=$((_keys_set + 1))
    [[ -n "${XAI_API_KEY:-}" ]] && _keys_set=$((_keys_set + 1))
    [[ -n "${GOOGLE_API_KEY:-}" ]] && _keys_set=$((_keys_set + 1))

    if [[ $_keys_set -eq 1 ]]; then
      if [[ -n "${OPENAI_API_KEY:-}" ]]; then
        export LLM_PROVIDER="openai"
        export LLM_MODEL="${LLM_MODEL:-gpt-4o}"
        export LLM_API_KEY="${LLM_API_KEY:-$OPENAI_API_KEY}"
      elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        export LLM_PROVIDER="anthropic"
        export LLM_MODEL="${LLM_MODEL:-claude-3-5-sonnet-20241022}"
        export LLM_API_KEY="${LLM_API_KEY:-$ANTHROPIC_API_KEY}"
      elif [[ -n "${GOOGLE_API_KEY:-}" ]]; then
        export LLM_PROVIDER="google"
        export LLM_MODEL="${LLM_MODEL:-gemini-2.0-flash}"
        export LLM_API_KEY="${LLM_API_KEY:-$GOOGLE_API_KEY}"
      elif [[ -n "${XAI_API_KEY:-}" ]]; then
        export LLM_PROVIDER="xai"
        export LLM_MODEL="${LLM_MODEL:-grok-3-mini}"
        export LLM_API_KEY="${LLM_API_KEY:-$XAI_API_KEY}"
      fi
    else
      # Multiple keys set: prefer anthropic if available, otherwise pick first available
      if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        export LLM_PROVIDER="anthropic"
        export LLM_MODEL="${LLM_MODEL:-claude-3-5-sonnet-20241022}"
        export LLM_API_KEY="${LLM_API_KEY:-$ANTHROPIC_API_KEY}"
      elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
        export LLM_PROVIDER="openai"
        export LLM_MODEL="${LLM_MODEL:-gpt-4o}"
        export LLM_API_KEY="${LLM_API_KEY:-$OPENAI_API_KEY}"
      elif [[ -n "${GOOGLE_API_KEY:-}" ]]; then
        export LLM_PROVIDER="google"
        export LLM_MODEL="${LLM_MODEL:-gemini-2.0-flash}"
        export LLM_API_KEY="${LLM_API_KEY:-$GOOGLE_API_KEY}"
      elif [[ -n "${XAI_API_KEY:-}" ]]; then
        export LLM_PROVIDER="xai"
        export LLM_MODEL="${LLM_MODEL:-grok-3-mini}"
        export LLM_API_KEY="${LLM_API_KEY:-$XAI_API_KEY}"
      fi
    fi
  fi
  echo "🤖 LLM provider: $LLM_PROVIDER, model: $LLM_MODEL"

  # Run envsubst to replace variables
  envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"
  
  echo "✅ Config generated at $CONFIG_FILE"
  
  # Show config for debugging (redact sensitive values)
  if [[ "${DEBUG:-}" == "1" ]]; then
    echo "📋 Generated config (with redacted secrets):"
    sed 's/\(apiKey\|token\)": "[^"]*"/\1": "***REDACTED***"/g' "$CONFIG_FILE"
  fi
fi

# Run doctor to fix any issues before starting
openclaw doctor --fix 2>/dev/null || true

echo "🚀 Starting OpenClaw..."
exec "$@"
