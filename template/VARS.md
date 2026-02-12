# Environment Variables Reference

This document lists all environment variables used by OpenClaw instances in the Hatchery.

## Required Variables

At least **one** of the following LLM API keys must be set:

- `ANTHROPIC_API_KEY` — Anthropic Claude API key
- `OPENAI_API_KEY` — OpenAI API key
- `XAI_API_KEY` — xAI API key (Grok)
- `GOOGLE_API_KEY` — Google AI API key (Gemini)

## Optional Variables

### Discord Integration

Only required if you want to connect OpenClaw to Discord:

- `DISCORD_BOT_TOKEN` — Discord bot token
- `DISCORD_CLIENT_ID` — Discord application client ID

To enable Discord:
1. Set both `DISCORD_BOT_TOKEN` and `DISCORD_CLIENT_ID` in your `.env`
2. Ensure the Discord section in `openclaw.template.json` has `"enabled": true`

## Configuration Flow

1. **Environment variables** are set in your instance's `.env` file
2. **Template processing** happens at container startup via `entrypoint.sh`
3. **envsubst** replaces `$VARIABLE_NAME` placeholders in `openclaw.template.json`
4. **Final config** is generated at `/home/openclaw/.openclaw/openclaw.json`
5. **OpenClaw** starts and reads the generated config

## Security Notes

- Never commit `.env` files or `openclaw.json` to version control
- `openclaw.json` is runtime-generated and listed in `.gitignore`
- Use `.env.example` as a template for required variables
- Secrets are only stored in `.env` or your environment, never in committed files

## Debugging

To see the generated config (with redacted secrets), set `DEBUG=1` in your `.env`:

```bash
DEBUG=1
```

Then check container logs:

```bash
docker compose logs
```

## Example .env File

```bash
# Required: At least one LLM provider
ANTHROPIC_API_KEY=your-anthropic-api-key-here

# Optional: Additional LLM providers
# OPENAI_API_KEY=your-openai-api-key-here
# XAI_API_KEY=your-xai-api-key-here
# GOOGLE_API_KEY=your-google-api-key

# Optional: Discord integration
# DISCORD_BOT_TOKEN=your-discord-bot-token
# DISCORD_CLIENT_ID=your-discord-client-id

# Optional: Debug mode
# DEBUG=1
```

## Customizing Config Templates

You can modify `openclaw.template.json` to add more configuration options. Any `$VARIABLE_NAME` will be replaced by envsubst at startup.

### Adding a New Variable

1. Add the variable to your instance's `.env` file
2. Add `$VARIABLE_NAME` placeholder to `openclaw.template.json`
3. (Optional) Export a default in `entrypoint.sh` to prevent empty strings
4. Document the variable in this file

### Example

To add a custom workspace path:

**In .env:**
```bash
CUSTOM_WORKSPACE_PATH=/custom/path
```

**In openclaw.template.json:**
```json
{
  "workspace": {
    "path": "$CUSTOM_WORKSPACE_PATH"
  }
}
```

**In entrypoint.sh (optional defaults):**
```bash
export CUSTOM_WORKSPACE_PATH="${CUSTOM_WORKSPACE_PATH:-/home/openclaw/.openclaw/workspace}"
```
