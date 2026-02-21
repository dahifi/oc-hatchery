# Hatchery Deployment SOP

Standard Operating Procedure for deploying a new OpenClaw hatchling instance.
Derived from the Todd/CHC (Certainty Home Consulting) deployment — February 2026.

---

## 1. Pre-deployment — Client Side

The client completes these steps. Send them this section.

- [ ] **Create a Discord server** for their business
- [ ] **Create a Discord Application** at https://discord.com/developers/applications
  - Click "New Application", name it after the bot
- [ ] **Create a Bot** under the application
  - Go to Bot settings → click "Add Bot"
- [ ] **Enable MESSAGE CONTENT INTENT**
  - Bot settings → Privileged Gateway Intents → toggle **Message Content Intent** ON
  - ⚠️ **This is the #1 deployment failure.** Without it, the bot gets error `4014` and cannot read messages.
- [ ] **Copy the bot token** — Bot settings → "Reset Token" → copy
- [ ] **Note the Client ID** — OAuth2 → General → "Client ID"
- [ ] **Invite the bot to their server**
  - OAuth2 → URL Generator
  - Scopes: `bot`, `applications.commands`
  - Permissions: Send Messages, Read Message History, Embed Links, Attach Files, Add Reactions, Use Slash Commands
  - Copy generated URL, open in browser, select server
- [ ] **Send credentials securely**
  - ✅ Apple Notes shared via iCloud (preferred)
  - ✅ Direct message (Signal, iMessage)
  - ❌ **NEVER** plaintext in Discord channels
  - Send: bot token, client ID, server ID, target channel ID(s)

---

## 2. Pre-deployment — Operator Side

### 2.1 Prepare the container directory

```bash
ssh zeph@revere
mkdir -p /share/Container/<hatchling-name>
```

### 2.2 Copy template files

If oc-hatchery is cloned on the NAS:
```bash
cp -r /path/to/oc-hatchery/template/* /share/Container/<hatchling-name>/
```

Or use `hatch.sh` if available:
```bash
./hatch.sh <hatchling-name>
```

### 2.3 Seed workspace files

Ensure these exist in the workspace directory:
- `SOUL.md` — personality, role, tone
- `USER.md` — client profile
- `AGENTS.md` — session behavior
- `IDENTITY.md` — name, purpose
- `HEARTBEAT.md` — periodic check instructions
- `MEMORY.md` — initial context
- `TOOLS.md` — available tools/integrations

Customize each for the client. At minimum, edit `SOUL.md`, `USER.md`, and `IDENTITY.md`.

### 2.4 Create `.env`

```bash
cat > /share/Container/<hatchling-name>/.env << 'EOF'
ANTHROPIC_API_KEY=sk-ant-...
DISCORD_BOT_TOKEN=<from client>
DISCORD_CLIENT_ID=<from client>
EOF
```

- Anthropic API key can be shared across hatchlings (same subscription).
- Each hatchling gets its own Discord bot token and client ID.

### 2.5 Configure `openclaw.template.json`

Edit the template to set:
- `model` — e.g., `anthropic/claude-sonnet-4-20250514`
- `agent.name` — the hatchling's name
- Discord channel bindings — map channel IDs to behaviors
- Tool permissions / allowlists

### 2.6 Create `docker-compose.yml`

Assign a unique port. Check `fleet.json` for existing allocations.

```
Port allocation:
  18789 — Zephyr (primary)
  18790 — Seraphel
  18791+ — next hatchling
```

```yaml
services:
  <hatchling-name>:
    image: openclaw/openclaw:latest
    container_name: hatchery-<hatchling-name>
    restart: unless-stopped
    ports:
      - "<port>:18789"
    env_file:
      - .env
    volumes:
      - ./workspace:/app/workspace
      - ./openclaw.template.json:/app/openclaw.template.json:ro
```

---

## 3. Deployment

```bash
cd /share/Container/<hatchling-name>

# Build and start
docker compose up -d --build

# Wait for startup
sleep 30

# Health check
curl http://localhost:<port>/health
```

- [ ] Health endpoint returns OK
- [ ] Bot appears online in Discord (green dot)
- [ ] Send a test message in the bound channel
- [ ] Bot responds correctly

### Troubleshooting: Error 4014

```
Error: Used disallowed intents
```

**Fix:**
1. Go to https://discord.com/developers/applications
2. Select the application → Bot → Privileged Gateway Intents
3. Enable **Message Content Intent**
4. Restart the container:
   ```bash
   docker compose restart
   ```

---

## 4. Post-deployment

- [ ] **Create `#<client>` channel** in BCM server for operator visibility/monitoring
- [ ] **Add to `fleet.json`** — name, port, client, Discord server ID, deploy date
- [ ] **Update `MEMORY.md`** with client details, preferences, deployment notes
- [ ] **Schedule follow-up checks:**
  - 24 hours — confirm stable operation, check logs
  - 1 week — review usage, adjust personality/config if needed

---

## 5. Maintenance

### OC Updates
```bash
cd /share/Container/<hatchling-name>
docker compose pull
docker compose up -d --force-recreate
```

### Config Changes
Edit workspace files (`SOUL.md`, `TOOLS.md`, etc.) then restart:
```bash
docker compose restart
```

### Monitoring
```bash
# Fleet status (if fleet.sh available)
./fleet.sh status

# Container logs
docker logs hatchery-<hatchling-name> --tail 100 -f

# Health check
curl http://localhost:<port>/health
```

---

## Lessons Learned

1. **Message Content Intent is the #1 gotcha.** Every single deployment will hit this if the client forgets. Emphasize it in client instructions. Bold it. Underline it.
2. **Credential transfer:** Apple Notes via iCloud sharing works well when Tailscale MacBook→mini is broken. Never send tokens in Discord.
3. **Anthropic API key is shared** across all hatchlings — same subscription, one key.
4. **Each client gets their own Discord server** — this is the security boundary. Never put two clients' bots in the same server.
5. **Port allocation:** Start at `18789`, increment per instance. Track in `fleet.json` to avoid conflicts.
6. **Docker on QNAP:** Volume mounts resolve on the NAS filesystem. Use `docker cp` if injecting files from the Mac.
7. **Container user is UID 1001.** If permission errors: `docker exec -u root <container> chown -R 1001:1001 /app/workspace`
