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
# 1. Create an instance
./scripts/hatch.sh my-advisor --port 18790

# 2. Configure API keys
cd instances/my-advisor
cp .env.example .env
# Edit .env and add your ANTHROPIC_API_KEY or OPENAI_API_KEY

# 3. Launch
docker compose up -d --build

# 4. Verify (wait ~30s for startup)
curl http://localhost:18790/health

# 5. Access the TUI
open http://localhost:18790  # or visit in browser
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

```bash
# View all instances
./scripts/fleet.sh status

# Stop when done
cd instances/my-advisor && docker compose down
```

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
