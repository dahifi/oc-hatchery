# Testing Guide

This document describes how to test the oc-hatchery functionality.

## Quick Test (No Docker Required)

Tests hatch.sh functionality without requiring Docker networking:

```bash
./scripts/test-hatch.sh
```

This test validates:
- ✓ Instance creation with hatch.sh
- ✓ Directory structure
- ✓ Required files (Dockerfile, docker-compose.yml, .env.example)
- ✓ Workspace files (AGENTS.md, SOUL.md, etc.)
- ✓ Port configuration
- ✓ Container naming

**Time:** ~1 second  
**Requirements:** bash

## Dockerfile Validation

Validates the Dockerfile configuration and best practices:

```bash
./scripts/validate-dockerfile.sh
```

This validation checks:
- ✓ Alpine package dependencies (git, curl, bash, gettext)
- ✓ Non-root user configuration
- ✓ UID/GID configuration (1001)
- ✓ Entrypoint script setup
- ✓ Health check configuration
- ✓ Port exposure
- ✓ Workspace directory structure
- ✓ Environment variable templating
- ✓ API key validation
- ✓ Production environment settings
- ✓ Docker image build (if package available)

**Time:** 1-3 minutes  
**Requirements:** Docker (for full validation)

See [DOCKERFILE_VALIDATION.md](DOCKERFILE_VALIDATION.md) for detailed validation results.

## End-to-End Test (Full Workflow)

Tests the complete workflow from hatch to launch:

```bash
./scripts/e2e-test.sh
```

This test validates:
- ✓ Instance creation with hatch.sh
- ✓ Directory and file structure
- ✓ Docker image build
- ✓ Container startup
- ✓ Health check endpoint
- ✓ TUI accessibility
- ✓ fleet.sh status reporting
- ✓ Clean shutdown with docker compose down

**Time:** 3-5 minutes (first run), faster on subsequent runs  
**Requirements:** 
- Docker + Docker Compose
- Network access for Docker image builds
- At least one LLM API key (optional but recommended)

### Setting API Keys for Testing

The e2e test will use API keys from environment variables if available:

```bash
# Using Anthropic
export ANTHROPIC_API_KEY="your-key-here"
./scripts/e2e-test.sh

# Or using OpenAI
export OPENAI_API_KEY="your-key-here"
./scripts/e2e-test.sh
```

Without API keys, the container will start but may not be fully functional.

## Manual Testing

### 1. Create an Instance

```bash
./scripts/hatch.sh my-advisor --port 18790
```

### 2. Configure Environment

```bash
cd instances/my-advisor
cp .env.example .env
# Edit .env and add your API keys
```

### 3. Customize Workspace

Edit the files in `workspace/`:
- `SOUL.md` - Define personality and expertise
- `IDENTITY.md` - Set name, role, emoji
- `USER.md` - Describe who this instance helps
- Add reference docs to `workspace/reference/`

### 4. Launch

```bash
docker compose up -d --build
```

### 5. Verify

Check health:
```bash
curl http://localhost:18790/health
```

Access TUI:
```bash
open http://localhost:18790
# or
curl http://localhost:18790
```

Check status:
```bash
# From the repository root
./scripts/fleet.sh status
```

View logs:
```bash
docker compose logs -f
# or
./scripts/fleet.sh logs my-advisor
```

### 6. Cleanup

```bash
docker compose down
# or from repository root
./scripts/fleet.sh stop
```

## Troubleshooting

### Docker Build Fails with TLS Errors

If you see errors like "TLS: unspecified error" when building:

1. Check your network connection
2. Try setting Docker DNS servers:
   ```bash
   # In /etc/docker/daemon.json
   {
     "dns": ["8.8.8.8", "8.8.4.4"]
   }
   ```
3. Restart Docker daemon

### Container Starts But Health Check Fails

1. Check logs: `docker compose logs`
2. Verify port is not already in use: `lsof -i :18790`
3. Check if API keys are set in .env
4. Verify OpenClaw installed correctly:
   ```bash
   docker exec -it hatchery-my-advisor openclaw --version
   ```
5. Try accessing directly: `docker exec -it hatchery-my-advisor sh`

### OpenClaw Installation Issues

If the container builds but OpenClaw doesn't work:

1. Check if openclaw is installed:
   ```bash
   docker exec hatchery-my-advisor which openclaw
   ```
2. Try running openclaw directly:
   ```bash
   docker exec hatchery-my-advisor openclaw --help
   ```
3. Check npm global packages:
   ```bash
   docker exec hatchery-my-advisor npm list -g
   ```

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for more details.

### Port Already in Use

Change the port when creating the instance:
```bash
./scripts/hatch.sh my-advisor --port 18791
```

## Platform-Specific Notes

### macOS (Docker Desktop)

- Ensure Docker Desktop is running
- File sharing should be enabled for the repository directory
- Default resources (2GB RAM) should be sufficient

### Linux (Docker Engine)

- Ensure your user is in the `docker` group: `sudo usermod -aG docker $USER`
- Log out and back in for group changes to take effect
- Ensure Docker daemon is running: `sudo systemctl status docker`

### Windows (Docker Desktop with WSL2)

- Run tests from within WSL2
- Ensure WSL2 integration is enabled in Docker Desktop settings
- Repository should be on WSL2 filesystem for best performance

## CI/CD

The e2e test is designed to gracefully handle network restrictions common in CI environments. It will:

1. Run all non-Docker tests
2. Attempt Docker build
3. If Docker build fails due to network issues, exit gracefully with passed core tests
4. If Docker build succeeds, run full end-to-end validation

This allows the test to provide useful feedback even in restricted environments.
