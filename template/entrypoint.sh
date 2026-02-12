#!/bin/bash
set -euo pipefail

# entrypoint.sh — Run envsubst on openclaw config template, then start OpenClaw

CONFIG_DIR="/home/openclaw/.openclaw"
TEMPLATE_FILE="$CONFIG_DIR/openclaw.template.json"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

echo "🦞 OpenClaw Entrypoint"

# Check if template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "⚠️  No openclaw.template.json found. Skipping envsubst step."
  echo "   OpenClaw will use defaults or existing config."
else
  echo "📝 Processing config template with envsubst..."
  
  # Define required environment variables
  REQUIRED_VARS=(
    "ANTHROPIC_API_KEY"
  )
  
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
  
  # Run envsubst to replace variables
  envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"
  
  echo "✅ Config generated at $CONFIG_FILE"
  
  # Show config for debugging (redact sensitive values)
  if [[ "${DEBUG:-}" == "1" ]]; then
    echo "📋 Generated config (with redacted secrets):"
    sed 's/\(apiKey\|token\)": "[^"]*"/\1": "***REDACTED***"/g' "$CONFIG_FILE"
  fi
fi

echo "🚀 Starting OpenClaw..."
exec "$@"
