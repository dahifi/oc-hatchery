# OpenClaw Quickstart Dockerfile
FROM node:22-alpine

RUN apk add --no-cache git curl bash

# Create openclaw user
RUN addgroup -g 1001 -S openclaw && \
    adduser -S openclaw -u 1001 -G openclaw

WORKDIR /home/openclaw

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Create state directory structure
RUN mkdir -p /home/openclaw/.openclaw/workspace && \
    chown -R openclaw:openclaw /home/openclaw

USER openclaw

ENV NODE_ENV=production

# TUI/Control UI port
EXPOSE 18789

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:18789/health || exit 1

# bind=lan so it listens on 0.0.0.0 inside the container
CMD ["openclaw", "gateway", "--port", "18789", "--bind", "lan"]
