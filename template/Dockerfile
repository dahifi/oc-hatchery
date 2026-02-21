# OpenClaw Quickstart Dockerfile
FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends git curl bash ca-certificates && rm -rf /var/lib/apt/lists/*

# Create openclaw user
RUN groupadd -g 1001 openclaw && useradd -u 1001 -g openclaw -m openclaw

WORKDIR /home/openclaw

ARG OC_VERSION=latest

# Install OpenClaw globally
RUN npm install -g openclaw@${OC_VERSION} --verbose || \
    (echo "ERROR: Failed to install openclaw@${OC_VERSION} from npm" && \
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
