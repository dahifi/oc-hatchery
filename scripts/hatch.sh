#!/usr/bin/env bash
set -euo pipefail

# hatch.sh — Create a new Hatchery instance from template
# Usage: ./scripts/hatch.sh <name> [--port PORT] [--host ssh://user@host] [--path /remote/path]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$ROOT_DIR/template"
INSTANCES_DIR="$ROOT_DIR/instances"
FLEET_REGISTRY="$ROOT_DIR/fleet.json"

NAME="${1:?Usage: hatch.sh <name> [--port PORT] [--host ssh://user@host] [--path /remote/path]}"
PORT=""
AUTO_PORT=false
SSH_HOST=""
SSH_USER=""
REMOTE_PATH=""

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --host)
      host_arg="$2"
      if [[ "$host_arg" =~ ^ssh://([^@]+)@(.+)$ ]]; then
        SSH_USER="${BASH_REMATCH[1]}"
        SSH_HOST="${BASH_REMATCH[2]}"
      elif [[ "$host_arg" =~ ^ssh://(.+)$ ]]; then
        SSH_HOST="${BASH_REMATCH[1]}"
      else
        echo "Error: Invalid --host format. Expected ssh://[user@]host" >&2
        exit 1
      fi
      shift 2
      ;;
    --path) REMOTE_PATH="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Validate --path when --host is provided
if [[ -n "$SSH_HOST" && -n "$REMOTE_PATH" ]]; then
  if [[ ! "$REMOTE_PATH" =~ ^/[a-zA-Z0-9/_.-]+$ ]]; then
    echo "Error: --path must be an absolute path with only alphanumeric, '/', '-', '_', '.' characters" >&2
    exit 1
  fi
fi

# Initialize fleet registry if it doesn't exist
if [[ ! -f "$FLEET_REGISTRY" ]]; then
  echo '{"instances":{}}' > "$FLEET_REGISTRY"
fi

# Auto-assign port if not specified
if [[ -z "$PORT" ]]; then
  AUTO_PORT=true
  # Find next available port starting from 18789
  next_port=18789
  while true; do
    # Check if port is in use using jq
    port_in_use=$(jq -r "[.instances[] | .port] | contains([$next_port])" "$FLEET_REGISTRY" 2>/dev/null || echo "false")
    if [[ "$port_in_use" == "false" ]]; then
      PORT=$next_port
      break
    fi
    next_port=$((next_port + 1))
    # Safety limit to prevent infinite loop
    if [[ $next_port -gt 19000 ]]; then
      echo "Error: No available ports found (reached limit)" >&2
      exit 1
    fi
  done
fi

# Check if port is already in use in the registry
port_check=$(jq -r "[.instances[] | .port] | contains([$PORT])" "$FLEET_REGISTRY" 2>/dev/null || echo "false")
if [[ "$port_check" == "true" ]]; then
  echo "Error: Port $PORT is already assigned in fleet.json" >&2
  exit 1
fi

INSTANCE_DIR="$INSTANCES_DIR/$NAME"

if [[ -d "$INSTANCE_DIR" ]]; then
  echo "Error: Instance '$NAME' already exists at $INSTANCE_DIR" >&2
  exit 1
fi

echo "🦞 Hatching new instance: $NAME (port $PORT)"

# Scaffold instance directory
mkdir -p "$INSTANCE_DIR/workspace/memory" "$INSTANCE_DIR/workspace/reference" "$INSTANCE_DIR/data"

# Copy template files
cp "$TEMPLATE_DIR/Dockerfile" "$INSTANCE_DIR/"
cp "$TEMPLATE_DIR/.env.example" "$INSTANCE_DIR/.env.example"
cp "$TEMPLATE_DIR/openclaw.template.json" "$INSTANCE_DIR/"
cp "$TEMPLATE_DIR/entrypoint.sh" "$INSTANCE_DIR/"
cp "$TEMPLATE_DIR/.gitignore" "$INSTANCE_DIR/.gitignore"

# Generate docker-compose with correct port and container name
sed "s/18789:18789/${PORT}:18789/g; s/openclaw-quickstart/hatchery-${NAME}/g" \
  "$TEMPLATE_DIR/docker-compose.yml" > "$INSTANCE_DIR/docker-compose.yml"

# Seed minimal workspace files
cat > "$INSTANCE_DIR/workspace/AGENTS.md" << 'EOF'
# AGENTS.md

## Every Session
1. Read `SOUL.md` — this is who you are
2. Read `USER.md` — this is who you're helping
3. Read `memory/` for recent context

## Safety
- Don't exfiltrate private data
- Don't run destructive commands without asking
- When in doubt, ask
EOF

cat > "$INSTANCE_DIR/workspace/SOUL.md" << 'EOF'
# SOUL.md

TODO: Define this instance's personality, expertise, and boundaries.
EOF

cat > "$INSTANCE_DIR/workspace/IDENTITY.md" << 'EOF'
# IDENTITY.md

- **Name:** (unnamed)
- **Role:** Assistant
- **Emoji:** 🦞
EOF

cat > "$INSTANCE_DIR/workspace/USER.md" << 'EOF'
# USER.md

TODO: Describe the person this instance helps.
EOF

cat > "$INSTANCE_DIR/workspace/HEARTBEAT.md" << 'EOF'
# HEARTBEAT.md
Heartbeat is DISABLED.
On every heartbeat, reply exactly: HEARTBEAT_OK
EOF

# Update fleet registry
tmp_file=$(mktemp)
jq --arg name "$NAME" --arg port "$PORT" --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg ssh_host "$SSH_HOST" --arg ssh_user "$SSH_USER" \
  '.instances[$name] = {port: ($port | tonumber), created: $created} |
   if $ssh_host != "" then .instances[$name].ssh_host = $ssh_host else . end |
   if $ssh_user != "" then .instances[$name].ssh_user = $ssh_user else . end' \
  "$FLEET_REGISTRY" > "$tmp_file" && mv "$tmp_file" "$FLEET_REGISTRY"

echo ""
if [[ "$AUTO_PORT" == "true" ]]; then
  echo "✅ Instance created at: $INSTANCE_DIR (auto-assigned port $PORT)"
else
  echo "✅ Instance created at: $INSTANCE_DIR"
fi

# Remote deploy via SSH
if [[ -n "$SSH_HOST" ]]; then
  SSH_TARGET="${SSH_USER:+${SSH_USER}@}${SSH_HOST}"
  DEST_PATH="${REMOTE_PATH:-/opt/hatchery/instances/$NAME}"

  # Validate default DEST_PATH (only needed when REMOTE_PATH was not set)
  if [[ -z "$REMOTE_PATH" && ! "$DEST_PATH" =~ ^/[a-zA-Z0-9/_.-]+$ ]]; then
    echo "Error: computed remote path contains unsafe characters: $DEST_PATH" >&2
    exit 1
  fi

  echo ""
  echo "🚀 Deploying to ${SSH_TARGET}:${DEST_PATH}..."

  ssh "$SSH_TARGET" "mkdir -p $(printf '%q' "$DEST_PATH")"
  rsync -az "$INSTANCE_DIR/" "${SSH_TARGET}:${DEST_PATH}/"
  ssh "$SSH_TARGET" "cd $(printf '%q' "$DEST_PATH") && docker compose up -d --build"

  echo ""
  echo "✅ Deployed to ${SSH_TARGET}:${DEST_PATH}"
  echo ""
  echo "Next steps:"
  echo "  1. Edit workspace files on the remote host or push updates with rsync"
  echo "  2. Copy .env.example to .env on the remote and add API keys:"
  echo "     ssh ${SSH_TARGET} \"cp ${DEST_PATH}/.env.example ${DEST_PATH}/.env\""
else
  echo ""
  echo "Next steps:"
  echo "  1. Edit workspace files (SOUL.md, IDENTITY.md, USER.md)"
  echo "  2. Add reference docs to workspace/reference/"
  echo "  3. Copy .env.example to .env and add API keys:"
  echo "     cp $INSTANCE_DIR/.env.example $INSTANCE_DIR/.env"
  echo "  4. Launch:"
  echo "     cd $INSTANCE_DIR && docker compose up -d"
fi
echo ""
echo "🦞 Happy hatching!"
