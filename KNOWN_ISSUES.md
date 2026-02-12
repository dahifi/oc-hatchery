# Known Issues

## OpenClaw Package Not Available on npm

The Dockerfile attempts to install `openclaw@latest` from npm, but this package may not be published yet.

**Observed symptoms:**
- Docker build fails at `RUN npm install -g openclaw@latest`
- Error: `npm ERR! 404 Not Found - GET https://registry.npmjs.org/openclaw`

**Status:** This is a blocking issue for Docker-based testing. The template is prepared for when the package becomes available. To proceed with testing, you'll need to either:
1. Wait for openclaw to be published on npm
2. Modify the Dockerfile to install from a different source (git, local package, etc.)
3. Use a mock/placeholder package for infrastructure testing

## Port Already in Use

If you see "port is already allocated" when starting a container:

**Solution:** Choose a different port when creating the instance:
```bash
./scripts/hatch.sh my-instance --port 18791
```

## CI/CD: Network Restrictions

Docker builds may fail in CI environments with strict network policies.

**Observed symptoms:**
- TLS errors when fetching Alpine packages during build
- `apk add` fails with "unable to select packages"

**Workaround:** The e2e test script detects these failures and exits gracefully. For local development, ensure your network allows access to Alpine package repositories.

## macOS: grep -oP Not Supported

The `fleet.sh status` command previously used `grep -oP` (Perl regex) which is not available on macOS by default.

**Status:** Fixed in commit 53f118c with POSIX-compatible sed alternative.
