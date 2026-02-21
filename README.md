# 🦞 Hatchery

**Managed OpenClaw instances in Docker.**

Spin up sandboxed, persona-seeded [OpenClaw](https://github.com/openclaw/openclaw) containers. Each instance gets its own config, workspace, and identity — fully isolated from the others.

## Concept

```
oc-hatchery/
├── template/                  # Base container template
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── .env.example
├── instances/                 # Local only (gitignored)
│   └── my-advisor/
│       ├── docker-compose.yml
│       └── workspace/
├── scripts/
│   ├── hatch.sh               # Scaffold a new instance
│   └── fleet.sh               # Manage running instances
```

## Quick Start

### Prerequisites
- Docker 20.10+ and Docker Compose v2.0+
- At least one LLM API key (Anthropic, OpenAI, etc.)

### Get Started in 5 Steps

```bash
# 1. Create an instance (port auto-assigned starting from 18789)
./scripts/hatch.sh my-advisor

# 2. Configure API keys
cd instances/my-advisor
cp .env.example .env
# Edit .env and add your ANTHROPIC_API_KEY or OPENAI_API_KEY

# 3. Launch
docker compose up -d --build

# 4. Verify (wait ~30s for startup)
curl http://localhost:18789/health

# 5. Access the TUI
open http://localhost:18789  # or visit in browser
```

### Customize (Optional)

Edit workspace files to define personality and behavior:
- `workspace/SOUL.md` — personality and expertise
- `workspace/IDENTITY.md` — name, role, emoji
- `workspace/USER.md` — who this instance helps
- `workspace/reference/` — add reference documents

### Configuration & Secrets

Each instance uses environment variable templating for secure configuration:

- **`.env`** — Your API keys and secrets (never committed)
- **`openclaw.template.json`** — Config template with `$VARIABLE` placeholders
- **`openclaw.json`** — Generated at runtime (never committed)

At container startup, the entrypoint script runs `envsubst` to replace variables like `$ANTHROPIC_API_KEY` with values from your `.env` file. This ensures secrets are never stored in version control.

See [`template/VARS.md`](template/VARS.md) for a complete list of supported environment variables.

### Manage Instances

Fleet management commands for easy instance control:

```bash
# View all instances with status and uptime
./scripts/fleet.sh status

# Start all instances or a specific one
./scripts/fleet.sh start              # all instances
./scripts/fleet.sh start my-advisor   # specific instance

# Stop all instances or a specific one
./scripts/fleet.sh stop               # all instances
./scripts/fleet.sh stop my-advisor    # specific instance

# View logs from an instance
./scripts/fleet.sh logs my-advisor

# Update instances (pull latest image and restart)
./scripts/fleet.sh update my-advisor  # specific instance
./scripts/fleet.sh update --all       # all instances

# Or manage individual instances directly
cd instances/my-advisor && docker compose down
```

**Port Management:**
- Ports are automatically assigned starting from 18789 when creating instances
- Manually specify a port with `./scripts/hatch.sh my-instance --port 18800`
- Port assignments are tracked in `fleet.json` to prevent conflicts

**Remote Deploy via SSH:**
```bash
# Deploy directly to a remote host
./scripts/hatch.sh my-instance --port 18800 --host ssh://user@hostname --path /opt/hatchery/instances/my-instance
```
This scaffolds the instance locally, rsyncs files to the remote host, and runs `docker compose up -d --build` there.
The `--path` flag is optional (defaults to `/opt/hatchery/instances/<name>`).

See [TESTING.md](TESTING.md) for troubleshooting.

## Testing

Run the quick test (no Docker required):
```bash
./scripts/test-hatch.sh
```

Validate the Dockerfile configuration:
```bash
./scripts/validate-dockerfile.sh
```

Run the full end-to-end test:
```bash
./scripts/e2e-test.sh
```

See [TESTING.md](TESTING.md) for detailed testing guide and troubleshooting.

See [DOCKERFILE_VALIDATION.md](DOCKERFILE_VALIDATION.md) for comprehensive Dockerfile validation results.

## Status

🚧 **Work in progress.** Scaffolding validated, Docker workflow under test.

## Requirements

- Docker + Docker Compose
- At least one LLM API key (Anthropic, OpenAI, etc.)

## License

MIT

---

*Part of the [OpenClaw](https://github.com/openclaw/openclaw) ecosystem.* 🦞
