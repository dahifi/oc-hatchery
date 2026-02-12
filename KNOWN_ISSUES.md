# Known Issues

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

The `fleet.sh status` command uses `grep -oP` (Perl regex) which is not available on macOS by default.

**Status:** Fixed in this PR with POSIX-compatible alternative.
