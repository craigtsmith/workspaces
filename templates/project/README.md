# Project Template

Project-specific workspace with AI agent tasks support and devcontainer integration.

## Features

- **Base Image**: `codercom/enterprise-node:ubuntu` (Node.js + Docker pre-installed)
- **Docker**: Privileged mode with full Docker-in-Docker (devcontainer support)
- **IDEs**: VS Code (code-server for browser/iPad), Cursor
- **AI Agents**: Claude Code (with task reporting), Mux, Codex
- **Devcontainers**: Automatic devcontainer detection and startup
- **AI Tasks**: Supports Coder agent tasks via `coder_ai_task`
- **Personalization**: personalize module pre-installs zsh and seeds a `~/personalize` script

## Parameters

| Parameter | Description |
|-----------|-------------|
| `repo_url` | Repository to clone (should contain devcontainer.json) |
| `system_prompt` | System prompt for AI agents |
| `anthropic_api_key` | Optional workspace override; leave blank to use `.envrc` value |
| `openai_api_key` | Optional workspace override; leave blank to use `.envrc` value |

## Template Variables

Set these when pushing the template:

| Variable | Description |
|----------|-------------|
| `anthropic_api_key` | Anthropic API key for Claude Code (default sourced from `.envrc`) |
| `openai_api_key` | OpenAI API key for Codex (default sourced from `.envrc`) |
| `enable_github_auth` | Set to `false` if GitHub external auth/SSH upload is not configured |

> The template prompts for Anthropic/OpenAI keys at workspace creation; leave them blank to use the values sourced from `.envrc` during `./scripts/push.sh`.

## GitHub integration

- [`git-config`](https://registry.coder.com/modules/coder/git-config) syncs Git author/email from your Coder user.
- [`github-upload-public-key`](https://registry.coder.com/modules/coder/github-upload-public-key) uploads SSH keys via GitHub external auth so clones work immediately.
- Run separate Coder accounts for each agent if you need distinct Git identities or GitHub tokens.

## Volumes

- `/home/coder` - Persistent home directory
- `/var/lib/docker` - Docker cache (persists images/containers/devcontainers)

## Usage

```bash
# Push template
./scripts/push.sh project

# Create workspace and provide repo url
coder create my-project --template project \
  --parameter repo_url=https://github.com/org/repo

# Override the system prompt (optional)
coder create agent-project --template project \
  --parameter repo_url=https://github.com/org/repo \
  --parameter system_prompt="You are a coding assistant for this project..."
```
