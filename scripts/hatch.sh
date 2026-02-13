#!/usr/bin/env bash
set -euo pipefail

# hatch.sh — Create a new Hatchery instance from template
# Usage: ./scripts/hatch.sh <name> [--port PORT]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$ROOT_DIR/template"
INSTANCES_DIR="$ROOT_DIR/instances"

NAME="${1:?Usage: hatch.sh <name> [--port PORT]}"
PORT=18789

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

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

echo ""
echo "✅ Instance created at: $INSTANCE_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit workspace files (SOUL.md, IDENTITY.md, USER.md)"
echo "  2. Add reference docs to workspace/reference/"
echo "  3. Copy .env.example to .env and add API keys:"
echo "     cp $INSTANCE_DIR/.env.example $INSTANCE_DIR/.env"
echo "  4. Launch:"
echo "     cd $INSTANCE_DIR && docker compose up -d"
echo ""
echo "🦞 Happy hatching!"
