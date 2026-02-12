# OpenClaw Quickstart Dockerfile
FROM node:22-alpine

RUN apk add --no-cache git curl bash gettext

# Create openclaw user
RUN addgroup -g 1001 -S openclaw && \
    adduser -S openclaw -u 1001 -G openclaw

WORKDIR /home/openclaw

# Install OpenClaw globally with verbose logging
# Note: If openclaw package doesn't exist on npm, this will fail with a clear error
RUN npm install -g openclaw@latest --verbose || \
    (echo "ERROR: Failed to install openclaw@latest from npm" && \
     echo "This likely means the package doesn't exist or isn't published yet" && \
     echo "Check https://www.npmjs.com/package/openclaw for availability" && \
     exit 1)

# Create state directory structure
RUN mkdir -p /home/openclaw/.openclaw/workspace && \
    chown -R openclaw:openclaw /home/openclaw

# Copy config template and entrypoint script
COPY --chown=openclaw:openclaw openclaw.template.json /home/openclaw/.openclaw/
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

USER openclaw

ENV NODE_ENV=production

# TUI/Control UI port
EXPOSE 18789

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:18789/health || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# bind=lan so it listens on 0.0.0.0 inside the container
CMD ["openclaw", "gateway", "--port", "18789", "--bind", "lan"]
