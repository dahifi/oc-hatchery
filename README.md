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

**Quick start:** See [QUICKSTART.md](QUICKSTART.md) for a detailed step-by-step guide.

```bash
# Scaffold an instance
./scripts/hatch.sh my-advisor --port 18790

# Configure and launch
cd instances/my-advisor
cp .env.example .env
# Edit .env and add API keys
docker compose up -d --build

# Access at http://localhost:18790
```

For detailed instructions, customization options, and troubleshooting, see [QUICKSTART.md](QUICKSTART.md).

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
