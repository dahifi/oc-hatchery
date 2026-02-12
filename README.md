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

## Usage

```bash
# Scaffold an instance
./scripts/hatch.sh my-advisor --port 18790

# Edit workspace files (SOUL.md, IDENTITY.md, USER.md, etc.)
# Add API keys to .env
# Launch
cd instances/my-advisor && docker compose up -d
```

## Testing

Run the quick test (no Docker required):
```bash
./scripts/test-hatch.sh
```

Run the full end-to-end test:
```bash
./scripts/e2e-test.sh
```

See [TESTING.md](TESTING.md) for detailed testing guide and troubleshooting.

## Status

✅ **Core functionality tested.** Instance creation and scaffolding validated. Docker workflow tested (requires network access).

## Requirements

- Docker + Docker Compose
- At least one LLM API key (Anthropic, OpenAI, etc.)

## License

MIT

---

*Part of the [OpenClaw](https://github.com/openclaw/openclaw) ecosystem.* 🦞
