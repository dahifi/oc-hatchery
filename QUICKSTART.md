# Quick Start Guide

Get your first OpenClaw instance running in under 5 minutes.

## 1. Prerequisites

Ensure you have:
- Docker and Docker Compose installed
- At least one LLM API key (Anthropic, OpenAI, etc.)

```bash
# Verify installations
docker --version      # Should show v20.10+
docker compose version  # Should show v2.0+
```

## 2. Create an Instance

```bash
# From the repository root
./scripts/hatch.sh my-advisor --port 18790
```

This creates `instances/my-advisor/` with all required files.

## 3. Configure API Keys

```bash
cd instances/my-advisor
cp .env.example .env
```

Edit `.env` and add your API key:

```bash
# For Anthropic (recommended)
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here

# OR for OpenAI
OPENAI_API_KEY=sk-your-key-here
```

## 4. Customize Your Instance (Optional)

Edit the workspace files to customize behavior:

```bash
# Define personality and expertise
vim workspace/SOUL.md

# Set name, role, and emoji
vim workspace/IDENTITY.md

# Describe who this instance helps
vim workspace/USER.md

# Add reference documents
cp ~/my-docs/* workspace/reference/
```

## 5. Launch

```bash
# Build and start in background
docker compose up -d --build
```

First build may take 2-5 minutes. Subsequent starts are faster.

## 6. Verify It's Running

```bash
# Check health
curl http://localhost:18790/health

# Should return: {"status":"ok"} or similar
```

## 7. Access the TUI

Open in your browser:
```
http://localhost:18790
```

Or use curl:
```bash
curl http://localhost:18790/
```

## 8. Monitor

```bash
# View logs
docker compose logs -f

# Or from repository root
cd ../..
./scripts/fleet.sh logs my-advisor
```

## 9. Stop When Done

```bash
# Stop and remove container
docker compose down

# Or from repository root
./scripts/fleet.sh stop
```

## 10. Manage Multiple Instances

```bash
# Create more instances with different ports
./scripts/hatch.sh assistant-1 --port 18791
./scripts/hatch.sh assistant-2 --port 18792

# View all running instances
./scripts/fleet.sh status

# Start all instances
./scripts/fleet.sh start

# Stop all instances
./scripts/fleet.sh stop
```

## Troubleshooting

### Port already in use?

```bash
# Use a different port
./scripts/hatch.sh my-advisor --port 18791
```

### Container won't start?

```bash
# Check logs
docker compose logs

# Verify API keys in .env
cat .env
```

### Health check failing?

```bash
# Wait up to 60 seconds for startup
# Check container status
docker ps

# Test health manually
docker exec hatchery-my-advisor curl http://localhost:18789/health
```

### Need to rebuild?

```bash
# Force rebuild
docker compose up -d --build --force-recreate
```

## Next Steps

- **Customize workspace**: Edit SOUL.md, IDENTITY.md, USER.md
- **Add reference docs**: Copy files to `workspace/reference/`
- **Test the API**: Use the TUI or integrate with your tools
- **Scale up**: Create multiple specialized instances
- **Read docs**: Check [TESTING.md](TESTING.md) and [KNOWN_ISSUES.md](KNOWN_ISSUES.md)

## Quick Reference

```bash
# Create instance
./scripts/hatch.sh <name> --port <port>

# Launch instance
cd instances/<name> && docker compose up -d

# Check status
./scripts/fleet.sh status

# View logs
./scripts/fleet.sh logs <name>

# Stop instance
cd instances/<name> && docker compose down

# Stop all
./scripts/fleet.sh stop
```

## Example Session

```bash
# Create and launch
./scripts/hatch.sh developer-assistant --port 18790
cd instances/developer-assistant
cp .env.example .env
echo "ANTHROPIC_API_KEY=sk-ant-..." >> .env
docker compose up -d --build

# Wait for health
sleep 30
curl http://localhost:18790/health

# Access
open http://localhost:18790

# When done
docker compose down
```

That's it! You now have a fully isolated OpenClaw instance running in Docker. 🦞
