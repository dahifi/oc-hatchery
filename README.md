# 🦞 Hatchery

**Managed OpenClaw instances for everyone.**

Hatchery makes it easy to spin up sandboxed, persona-seeded [OpenClaw](https://github.com/openclaw/openclaw) instances in Docker containers. Give someone an AI advisor tailored to their domain — without asking them to set up infrastructure.

## Why

OpenClaw is powerful, but onboarding non-technical users is friction. Hatchery removes that friction:

- **One command** to spin up an isolated OC instance
- **Seeded workspaces** — persona, domain knowledge, and reference docs baked in
- **Sandboxed** — each instance runs in its own container with its own config
- **Managed** — you control the fleet; they just use it

## How It Works

```
oc-hatchery/
├── template/                  # Base OC container template
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── .env.example
├── instances/                 # One folder per managed instance
│   └── example-advisor/
│       ├── docker-compose.yml
│       └── workspace/         # Seeded workspace (SOUL.md, etc.)
├── scripts/
│   ├── hatch.sh               # Create a new instance from template
│   ├── fleet.sh               # Manage running instances
│   └── update.sh              # Update all instances to latest OC
└── docs/
    └── creating-instances.md
```

### Quick Start

```bash
# Create a new instance
./scripts/hatch.sh my-advisor --port 18790

# Seed the workspace
cp your-soul.md instances/my-advisor/workspace/SOUL.md
# ... add IDENTITY.md, USER.md, reference docs, etc.

# Add API keys
cp instances/my-advisor/.env.example instances/my-advisor/.env
# Edit .env with ANTHROPIC_API_KEY or OPENAI_API_KEY

# Launch
cd instances/my-advisor && docker compose up -d

# Check the fleet
./scripts/fleet.sh status
```

## Design Principles

- **Isolation first** — instances share nothing. No cross-contamination of context, keys, or sessions.
- **Persona-driven** — every instance starts with a clear identity (SOUL.md + IDENTITY.md). No generic chatbots.
- **Operator-managed** — the person running Hatchery controls the fleet. Users interact through Discord, Telegram, or the TUI.
- **OC-native** — built on OpenClaw conventions. Workspaces, skills, and config all work the standard way.

## Status

🚧 **Early development.** We're using this internally to onboard colleagues. The first instance (a business advisor for a home consulting startup) is built and working.

## Roadmap

- [ ] `hatch.sh` — instance scaffolding script
- [ ] `fleet.sh` — status, start, stop, logs across all instances
- [ ] `update.sh` — rolling OC updates across the fleet
- [ ] Port allocation manager
- [ ] Per-instance cost tracking (via OC dashboard API)
- [ ] Discord bot multiplexing (one bot, multiple instances via guild bindings)
- [ ] Web dashboard for fleet management
- [ ] Instance templates / marketplace (pre-built advisor personas)

## Requirements

- Docker + Docker Compose
- An always-on host (Mac mini, VPS, NAS, etc.)
- At least one LLM API key (Anthropic, OpenAI, etc.)
- [OpenClaw](https://github.com/openclaw/openclaw) (installed in container via npm)

## License

MIT

---

*Part of the [OpenClaw](https://github.com/openclaw/openclaw) ecosystem.* 🦞
