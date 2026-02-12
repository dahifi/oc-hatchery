# Manual Test Checklist

Use this checklist to manually validate the oc-hatchery workflow on your platform.

## Prerequisites

- [ ] Docker installed and running
- [ ] Docker Compose installed (version 2.0+)
- [ ] At least one LLM API key (Anthropic or OpenAI recommended)

Check versions:
```bash
docker --version
docker compose version
```

## Test 1: Instance Creation

- [ ] Run: `./scripts/hatch.sh test-instance --port 18790`
- [ ] Verify output shows: "✅ Instance created at: instances/test-instance"
- [ ] Check directory exists: `ls -la instances/test-instance/`
- [ ] Verify files exist:
  - [ ] `docker-compose.yml`
  - [ ] `Dockerfile`
  - [ ] `.env.example`
  - [ ] `workspace/AGENTS.md`
  - [ ] `workspace/SOUL.md`
  - [ ] `workspace/IDENTITY.md`
  - [ ] `workspace/USER.md`
  - [ ] `workspace/HEARTBEAT.md`
  - [ ] `workspace/memory/` (directory)
  - [ ] `workspace/reference/` (directory)
  - [ ] `data/` (directory)

## Test 2: Configuration

- [ ] Copy environment file: `cp instances/test-instance/.env.example instances/test-instance/.env`
- [ ] Edit `.env` and add at least one API key:
  ```bash
  # Add one of these:
  ANTHROPIC_API_KEY=sk-ant-...
  OPENAI_API_KEY=sk-...
  ```
- [ ] Verify port in `docker-compose.yml` shows `18790:18789`
- [ ] Verify container name in `docker-compose.yml` is `hatchery-test-instance`

## Test 3: Docker Build and Start

- [ ] Navigate to instance: `cd instances/test-instance`
- [ ] Build and start: `docker compose up -d --build`
- [ ] Wait for build to complete (may take 2-5 minutes first time)
- [ ] Verify container is running: `docker ps | grep hatchery-test-instance`
- [ ] Check container status: `docker inspect hatchery-test-instance --format='{{.State.Status}}'`
  - Expected: `running`

## Test 4: Health Check

- [ ] Wait for container to be healthy (up to 60 seconds): 
  ```bash
  docker inspect hatchery-test-instance --format='{{.State.Health.Status}}'
  ```
  - Expected: `healthy`
- [ ] Test health endpoint: 
  ```bash
  curl -f http://localhost:18790/health
  ```
  - Expected: HTTP 200 response
- [ ] Check health endpoint response content (optional)

## Test 5: TUI Accessibility

- [ ] Access TUI in browser: `http://localhost:18790`
  - [ ] Page loads without errors
  - [ ] OpenClaw UI is visible
  - [ ] Can interact with the interface
- [ ] OR test via curl:
  ```bash
  curl -s http://localhost:18790/ | head -20
  ```
  - [ ] Returns HTML content

## Test 6: Fleet Management

- [ ] Navigate back to repository root: `cd ../..`
- [ ] Check fleet status: `./scripts/fleet.sh status`
  - [ ] Shows `test-instance` in output
  - [ ] Port shows as `18790`
  - [ ] State shows as `running`

## Test 7: Logs

- [ ] View logs: `./scripts/fleet.sh logs test-instance`
  - [ ] Shows OpenClaw startup logs
  - [ ] No error messages (warnings are OK)
  - [ ] Shows "Gateway running on port 18789" or similar

- [ ] OR use docker compose:
  ```bash
  cd instances/test-instance
  docker compose logs
  ```

## Test 8: Cleanup

- [ ] Stop container: `docker compose down` (from instance directory)
  - OR from root: `./scripts/fleet.sh stop`
- [ ] Verify container stopped: `docker ps -a | grep hatchery-test-instance`
  - Expected: No output (container removed)
- [ ] Remove instance directory: `rm -rf instances/test-instance`
- [ ] Verify cleanup: `ls instances/`
  - Expected: Directory empty or doesn't exist

## Platform-Specific Tests

### macOS (Docker Desktop)

- [ ] Docker Desktop is running (check menu bar icon)
- [ ] Verify memory allocation (Settings → Resources): at least 2GB
- [ ] Verify file sharing enabled for repository directory

### Linux (Docker Engine)

- [ ] User in docker group: `groups | grep docker`
- [ ] Docker daemon running: `sudo systemctl status docker`
- [ ] Can run docker without sudo: `docker ps`

### Windows (WSL2 + Docker Desktop)

- [ ] Running from WSL2 terminal
- [ ] Repository is on WSL2 filesystem (not /mnt/c/)
- [ ] Docker Desktop WSL2 integration enabled

## Performance Notes

Record times for reference:

- Instance creation time: _____ seconds
- Docker build time (first): _____ minutes
- Docker build time (cached): _____ seconds
- Health check wait time: _____ seconds
- Container startup time: _____ seconds

## Issues Found

Document any issues encountered:

1. 
2. 
3. 

## Test Results

- **Date:** _______________
- **Platform:** _______________
- **Docker Version:** _______________
- **Result:** PASS / FAIL
- **Notes:**
