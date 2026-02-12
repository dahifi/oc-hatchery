# Known Issues and Limitations

## OpenClaw in Docker/Headless Context

### Issue: First-time Setup

OpenClaw may require interactive setup on first launch. In a Docker container, this can be problematic.

**Symptoms:**
- Container starts but health check fails
- Logs show prompts for configuration
- TUI not accessible

**Workaround:**
1. Pre-configure the workspace with all required files before launch
2. Ensure .env file has all required API keys
3. The template includes workspace files (SOUL.md, etc.) to minimize setup prompts

### Issue: npm install openclaw@latest

The Dockerfile installs `openclaw@latest` via npm in an Alpine container.

**Potential issues:**
- Package may have native dependencies that require build tools
- Network issues during npm install (especially in restricted CI environments)
- Version compatibility with Alpine/Node.js

**Current mitigations:**
- Using `node:22-alpine` for stability
- Installing git, curl, bash for dependencies
- Health check has 40s start period to allow for slow startup

**If you encounter issues:**
1. Check the OpenClaw version: `docker exec hatchery-<name> openclaw --version`
2. Try pinning to a specific version in Dockerfile: `npm install -g openclaw@1.2.3`
3. Check OpenClaw logs for errors

### Issue: Health Check Timing

The container health check may be too aggressive or too lenient depending on system performance.

**Current settings:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3
```

**docker-compose.yml:**
```yaml
start_period: 40s  # Allows more time on slower systems
```

**Adjust if needed:**
- Increase `start_period` for slower systems
- Increase `timeout` if health endpoint is slow
- Adjust `interval` for more/less frequent checks

### Issue: Port Binding

The container internally uses port 18789, mapped to a host port (default 18790).

**Symptoms:**
- Error: "port is already allocated"
- Container fails to start

**Solution:**
Choose a different port when hatching:
```bash
./scripts/hatch.sh my-instance --port 18791
```

Or manually edit the `docker-compose.yml` after creation.

### Issue: Volume Permissions

The container runs as user `openclaw` (UID 1001), which may cause permission issues with mounted volumes.

**Symptoms:**
- Cannot write to workspace
- Data directory errors
- Permission denied in logs

**Solution:**
Ensure the `data` directory is writable:
```bash
chmod -R 777 instances/my-instance/data
```

Or adjust container user in Dockerfile if needed.

## Environment-Specific Issues

### macOS: File Sharing

Docker Desktop on macOS requires file sharing to be enabled for mounted directories.

**Solution:**
1. Open Docker Desktop Settings
2. Go to Resources → File Sharing
3. Ensure your repository directory is included
4. Restart Docker Desktop

### Linux: Docker Permissions

On Linux, you may need sudo to run Docker commands.

**Solution:**
Add your user to the docker group:
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### CI/CD: Network Restrictions

Some CI environments have strict network policies that can break Docker builds.

**Symptoms:**
- TLS errors when fetching Alpine packages
- npm install fails with network errors
- Docker pull fails

**Solutions:**
1. Use environment-specific DNS settings
2. Cache Docker layers in CI
3. Use pre-built images instead of building on every run
4. Configure CI to allow required domains

## Reporting Issues

If you encounter issues not listed here:

1. Check the OpenClaw documentation: https://github.com/openclaw/openclaw
2. Review Docker logs: `docker logs hatchery-<name>`
3. Test the health endpoint: `curl -v http://localhost:18790/health`
4. File an issue with:
   - Platform (OS, Docker version)
   - Full error logs
   - Steps to reproduce
   - Contents of .env (with secrets redacted)

## OpenClaw Version Compatibility

This template is designed to work with OpenClaw's latest version. If you encounter issues:

1. Check which version is installed:
   ```bash
   docker exec hatchery-<name> openclaw --version
   ```

2. Pin to a specific known-good version in the Dockerfile:
   ```dockerfile
   RUN npm install -g openclaw@1.2.3
   ```

3. Report compatibility issues to the OpenClaw project
