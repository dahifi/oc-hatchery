#!/usr/bin/env bash
set -euo pipefail

# bind-discord.sh — Generate Discord channel binding config for openclaw.template.json
# Usage: ./scripts/bind-discord.sh <bot-token> [--all]
#
# Fetches guilds and text channels the bot can see, presents an interactive
# selection menu (or dumps all with --all), and prints a JSON "channels" array
# to stdout suitable for pasting into the discord section of openclaw.template.json.
#
# All status/progress messages go to stderr so stdout is clean JSON.

DISCORD_API="${DISCORD_API:-https://discord.com/api/v10}"

BOT_TOKEN="${1:?Usage: bind-discord.sh <bot-token> [--all]}"
DUMP_ALL=false

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) DUMP_ALL=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Check dependencies
for dep in curl jq; do
  if ! command -v "$dep" &>/dev/null; then
    echo "Error: '$dep' is required but not installed." >&2
    exit 1
  fi
done

# Fetch guilds the bot is in
echo "🔍 Fetching Discord guilds..." >&2
guilds_response=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bot $BOT_TOKEN" \
  "$DISCORD_API/users/@me/guilds")

guilds_body=$(echo "$guilds_response" | head -n -1)
guilds_status=$(echo "$guilds_response" | tail -n 1)

if [[ "$guilds_status" != "200" ]]; then
  error_msg=$(echo "$guilds_body" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
  echo "Error: Discord API returned HTTP $guilds_status: $error_msg" >&2
  exit 1
fi

guild_count=$(echo "$guilds_body" | jq 'length')
if [[ "$guild_count" -eq 0 ]]; then
  echo "Error: Bot is not in any guilds." >&2
  exit 1
fi

echo "✅ Found $guild_count guild(s)" >&2

# Collect text channels (type 0) from every guild
all_channels=()

while IFS=$'\t' read -r guild_id guild_name; do
  echo "📡 Fetching channels for: $guild_name..." >&2

  channels_response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bot $BOT_TOKEN" \
    "$DISCORD_API/guilds/$guild_id/channels")

  channels_body=$(echo "$channels_response" | head -n -1)
  channels_status=$(echo "$channels_response" | tail -n 1)

  if [[ "$channels_status" != "200" ]]; then
    error_msg=$(echo "$channels_body" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
    echo "  Warning: Could not fetch channels for '$guild_name' (HTTP $channels_status: $error_msg)" >&2
    continue
  fi

  while IFS=$'\t' read -r channel_id channel_name; do
    all_channels+=("$(printf '%s\t%s\t%s\t%s' "$guild_id" "$guild_name" "$channel_id" "$channel_name")")
  done < <(echo "$channels_body" | jq -r '.[] | select(.type == 0) | [.id, .name] | @tsv')
done < <(echo "$guilds_body" | jq -r '.[] | [.id, .name] | @tsv')

if [[ ${#all_channels[@]} -eq 0 ]]; then
  echo "Error: No text channels found in any guild." >&2
  exit 1
fi

# Interactive selection or dump all
selected_channels=()

if [[ "$DUMP_ALL" == "true" ]] || [[ ! -t 2 ]]; then
  # Non-interactive: include everything
  selected_channels=("${all_channels[@]}")
else
  echo "" >&2
  echo "Available text channels:" >&2
  echo "" >&2
  for i in "${!all_channels[@]}"; do
    IFS=$'\t' read -r guild_id guild_name channel_id channel_name <<< "${all_channels[$i]}"
    printf "  %3d)  %-28s  #%-28s  (%s)\n" "$((i + 1))" "$guild_name" "$channel_name" "$channel_id" >&2
  done
  echo "" >&2
  printf "Enter channel numbers (space-separated, e.g. '1 3 5') or 'all': " >&2
  read -r selection

  if [[ "$selection" == "all" ]]; then
    selected_channels=("${all_channels[@]}")
  else
    for idx in $selection; do
      if [[ "$idx" =~ ^[0-9]+$ ]] && [[ "$idx" -ge 1 ]] && [[ "$idx" -le "${#all_channels[@]}" ]]; then
        selected_channels+=("${all_channels[$((idx - 1))]}")
      else
        echo "Warning: Ignored invalid selection '$idx'" >&2
      fi
    done
  fi
fi

if [[ ${#selected_channels[@]} -eq 0 ]]; then
  echo "No channels selected." >&2
  exit 0
fi

echo "" >&2
echo "📋 Channel binding JSON (add to the \"discord\" section of openclaw.template.json):" >&2
echo "" >&2

# Build JSON array
entries=()
for entry in "${selected_channels[@]}"; do
  IFS=$'\t' read -r guild_id guild_name channel_id channel_name <<< "$entry"
  entries+=("$(jq -n \
    --arg guildId "$guild_id" \
    --arg guildName "$guild_name" \
    --arg channelId "$channel_id" \
    --arg channelName "$channel_name" \
    '{guildId: $guildId, guildName: $guildName, channelId: $channelId, channelName: $channelName}')")
done

# Join entries with commas and wrap in array
printf '%s\n' "${entries[@]}" | jq -s '.'
