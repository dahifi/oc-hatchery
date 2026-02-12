#!/usr/bin/env bash
set -euo pipefail

# fleet.sh — Manage Hatchery instances
# Usage: ./scripts/fleet.sh <command>
#   status  — Show status of all instances
#   start   — Start all instances
#   stop    — Stop all instances
#   logs    — Tail logs from all instances

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
INSTANCES_DIR="$ROOT_DIR/instances"

CMD="${1:-status}"

case "$CMD" in
  status)
    echo "🦞 Hatchery Fleet Status"
    echo "========================"
    for dir in "$INSTANCES_DIR"/*/; do
      name="$(basename "$dir")"
      if [[ -f "$dir/docker-compose.yml" ]]; then
        port=$(grep -oP '\d+(?=:18789)' "$dir/docker-compose.yml" 2>/dev/null || echo "?")
        container="hatchery-${name}"
        state=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "not created")
        printf "  %-30s port=%-6s state=%s\n" "$name" "$port" "$state"
      fi
    done
    ;;
  start)
    for dir in "$INSTANCES_DIR"/*/; do
      if [[ -f "$dir/docker-compose.yml" ]]; then
        echo "Starting $(basename "$dir")..."
        (cd "$dir" && docker compose up -d)
      fi
    done
    ;;
  stop)
    for dir in "$INSTANCES_DIR"/*/; do
      if [[ -f "$dir/docker-compose.yml" ]]; then
        echo "Stopping $(basename "$dir")..."
        (cd "$dir" && docker compose down)
      fi
    done
    ;;
  logs)
    name="${2:-}"
    if [[ -n "$name" ]]; then
      docker logs -f "hatchery-${name}" 2>&1
    else
      echo "Usage: fleet.sh logs <instance-name>"
    fi
    ;;
  *)
    echo "Usage: fleet.sh {status|start|stop|logs [name]}" >&2
    exit 1
    ;;
esac
