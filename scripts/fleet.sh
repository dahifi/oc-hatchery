#!/usr/bin/env bash
set -euo pipefail

# fleet.sh — Manage Hatchery instances
# Usage: ./scripts/fleet.sh <command> [args]
#   status           — Show status of all instances
#   health           — Curl each instance /health endpoint and report status
#   start [name]     — Start instance(s)
#   stop [name]      — Stop instance(s)
#   logs <name>      — Tail container logs
#   update [name|--all] — Pull latest image and restart

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
INSTANCES_DIR="$ROOT_DIR/instances"
FLEET_REGISTRY="$ROOT_DIR/fleet.json"

CMD="${1:-status}"

# Helper function to get uptime
get_uptime() {
  local container="$1"
  local started=$(docker inspect -f '{{.State.StartedAt}}' "$container" 2>/dev/null || echo "")
  if [[ -z "$started" ]]; then
    echo "n/a"
    return
  fi
  
  # Convert to epoch seconds (cross-platform compatible)
  local start_epoch=$(date -d "$started" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${started%.*}" +%s 2>/dev/null || echo "0")
  local now_epoch=$(date +%s)
  local diff=$((now_epoch - start_epoch))
  
  if [[ $diff -lt 60 ]]; then
    echo "${diff}s"
  elif [[ $diff -lt 3600 ]]; then
    echo "$((diff / 60))m"
  elif [[ $diff -lt 86400 ]]; then
    echo "$((diff / 3600))h"
  else
    echo "$((diff / 86400))d"
  fi
}

case "$CMD" in
  status)
    echo "🦞 Hatchery Fleet Status"
    echo "========================"
    
    # Initialize registry if needed
    if [[ ! -f "$FLEET_REGISTRY" ]]; then
      echo '{"instances":{}}' > "$FLEET_REGISTRY"
    fi
    
    # Read from registry and show status
    if [[ -d "$INSTANCES_DIR" ]]; then
      for dir in "$INSTANCES_DIR"/*/; do
        if [[ ! -d "$dir" ]]; then continue; fi
        name="$(basename "$dir")"
        
        # Get port from registry, fallback to docker-compose.yml
        port="?"
        if [[ -f "$FLEET_REGISTRY" ]]; then
          port=$(jq -r ".instances[\"$name\"].port // \"?\"" "$FLEET_REGISTRY" 2>/dev/null || echo "?")
        fi
        if [[ "$port" == "?" ]] && [[ -f "$dir/docker-compose.yml" ]]; then
          port=$(sed -n 's/.*"\([0-9]*\):18789".*/\1/p' "$dir/docker-compose.yml" 2>/dev/null || echo "?")
        fi
        
        container="hatchery-${name}"
        state=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "not-created")
        state=$(echo "$state" | tr -d '\n')
        uptime=$(get_uptime "$container")
        
        printf "  %-25s port=%-6s state=%-12s uptime=%s\n" "$name" "$port" "$state" "$uptime"
      done
    fi
    
    if [[ ! -d "$INSTANCES_DIR" ]] || [[ -z "$(ls -A "$INSTANCES_DIR" 2>/dev/null)" ]]; then
      echo "  (no instances found)"
    fi
    ;;
    
  start)
    name="${2:-}"
    if [[ -n "$name" ]]; then
      # Start specific instance
      instance_dir="$INSTANCES_DIR/$name"
      if [[ ! -d "$instance_dir" ]]; then
        echo "Error: Instance '$name' not found" >&2
        exit 1
      fi
      echo "Starting $name..."
      (cd "$instance_dir" && docker compose up -d)
    else
      # Start all instances
      for dir in "$INSTANCES_DIR"/*/; do
        if [[ -f "$dir/docker-compose.yml" ]]; then
          echo "Starting $(basename "$dir")..."
          (cd "$dir" && docker compose up -d)
        fi
      done
    fi
    ;;
    
  stop)
    name="${2:-}"
    if [[ -n "$name" ]]; then
      # Stop specific instance
      instance_dir="$INSTANCES_DIR/$name"
      if [[ ! -d "$instance_dir" ]]; then
        echo "Error: Instance '$name' not found" >&2
        exit 1
      fi
      echo "Stopping $name..."
      (cd "$instance_dir" && docker compose down)
    else
      # Stop all instances
      for dir in "$INSTANCES_DIR"/*/; do
        if [[ -f "$dir/docker-compose.yml" ]]; then
          echo "Stopping $(basename "$dir")..."
          (cd "$dir" && docker compose down)
        fi
      done
    fi
    ;;
    
  logs)
    name="${2:?Usage: fleet.sh logs <instance-name>}"
    container="hatchery-${name}"
    if ! docker inspect "$container" &>/dev/null; then
      echo "Error: Container '$container' not found" >&2
      exit 1
    fi
    docker logs -f "$container" 2>&1
    ;;
    
  health)
    echo "🦞 Hatchery Fleet Health"
    echo "========================"

    if [[ ! -f "$FLEET_REGISTRY" ]]; then
      echo "  (no fleet.json found)"
      exit 0
    fi

    instances=$(jq -r '.instances | keys[]' "$FLEET_REGISTRY" 2>/dev/null || true)
    if [[ -z "$instances" ]]; then
      echo "  (no instances registered)"
      exit 0
    fi

    printf "  %-25s %-8s %-12s %s\n" "INSTANCE" "PORT" "HTTP" "RESPONSE TIME"
    printf "  %-25s %-8s %-12s %s\n" "--------" "----" "----" "-------------"

    while IFS= read -r name; do
      port=$(jq -r ".instances[\"$name\"].port" "$FLEET_REGISTRY")
      host=$(jq -r ".instances[\"$name\"].host // \"localhost\"" "$FLEET_REGISTRY")
      ssh_host=$(jq -r ".instances[\"$name\"].ssh_host // empty" "$FLEET_REGISTRY" 2>/dev/null || true)
      ssh_user=$(jq -r ".instances[\"$name\"].ssh_user // empty" "$FLEET_REGISTRY" 2>/dev/null || true)

      url="http://${host}:${port}/health"
      ctrl_socket=""

      # Set up SSH tunnel if ssh_host is configured
      if [[ -n "${ssh_host:-}" ]]; then
        ctrl_socket="/tmp/oc-hatch-ssh-$$-${name}"
        ssh_target="${ssh_user:+${ssh_user}@}${ssh_host}"
        local_port=$(( ( RANDOM % 10000 ) + 50000 ))
        if ssh -fNM -S "$ctrl_socket" \
             -L "${local_port}:localhost:${port}" "$ssh_target" \
             -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 2>/dev/null; then
          sleep 1
          url="http://localhost:${local_port}/health"
        else
          ctrl_socket=""
        fi
      fi

      # Curl the health endpoint; capture HTTP status and response time in one request
      result=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" \
        --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000 0")
      http_status=$(echo "$result" | awk '{print $1}')
      response_time=$(echo "$result" | awk '{printf "%.3fs", $2}')

      # Close SSH tunnel if we opened one
      if [[ -n "$ctrl_socket" ]] && [[ -S "$ctrl_socket" ]]; then
        ssh -S "$ctrl_socket" -O exit "$ssh_target" 2>/dev/null || true
      fi

      printf "  %-25s %-8s %-12s %s\n" "$name" "$port" "$http_status" "$response_time"
    done <<< "$instances"
    ;;

  update)
    target="${2:-}"
    
    update_instance() {
      local instance_dir="$1"
      local name="$(basename "$instance_dir")"
      echo "Updating $name..."
      
      if [[ ! -f "$instance_dir/docker-compose.yml" ]]; then
        echo "  Skipping $name (no docker-compose.yml found)"
        return
      fi
      
      # Pull latest image and restart
      (cd "$instance_dir" && docker compose pull && docker compose up -d --force-recreate)
      echo "  ✓ $name updated"
    }
    
    if [[ "$target" == "--all" ]]; then
      for dir in "$INSTANCES_DIR"/*/; do
        if [[ -d "$dir" ]]; then
          update_instance "$dir"
        fi
      done
    elif [[ -n "$target" ]]; then
      instance_dir="$INSTANCES_DIR/$target"
      if [[ ! -d "$instance_dir" ]]; then
        echo "Error: Instance '$target' not found" >&2
        exit 1
      fi
      update_instance "$instance_dir"
    else
      echo "Usage: fleet.sh update <name|--all>" >&2
      exit 1
    fi
    ;;
    
  *)
    echo "Usage: fleet.sh {status|health|start [name]|stop [name]|logs <name>|update <name|--all>}" >&2
    exit 1
    ;;
esac
