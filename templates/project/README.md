# Project Template

Project-specific workspace with AI agent tasks support and devcontainer integration.

## Features

- **Base Image**: `codercom/enterprise-node:ubuntu` (Node.js + Docker pre-installed)
- **Docker**: Privileged mode with full Docker-in-Docker (devcontainer support)
- **IDEs**: VS Code (code-server for browser/iPad), Cursor
- **AI Agents**: Claude Code (with task reporting), Mux, Codex
- **Devcontainers**: Automatic devcontainer detection and startup
- **AI Tasks**: Supports Coder agent tasks via `coder_ai_task`

## Parameters

| Parameter | Description |
|-----------|-------------|
| `user_type` | Human or Agent (configures git identity) |
| `repo_url` | Repository to clone (should contain devcontainer.json) |
| `system_prompt` | System prompt for AI agents |

### Git Identity by User Type

| User Type | Name | Email |
|-----------|------|-------|
| Human | craig t smith | craigtsmith@users.noreply.github.com |
| Agent | agent smith | craigts-agent@users.noreply.github.com |

## Template Variables

Set these when pushing the template:

| Variable | Description |
|----------|-------------|
| `anthropic_api_key` | Anthropic API key for Claude Code |
| `openai_api_key` | OpenAI API key for Codex |

## Volumes

- `/home/coder` - Persistent home directory
- `/var/lib/docker` - Docker cache (persists images/containers/devcontainers)

## Usage

```bash
# Push template
./scripts/push.sh project

# Create workspace for human use
coder create my-project --template project \
  --parameter user_type=human \
  --parameter repo_url=https://github.com/org/repo

# Create workspace for agent tasks
coder create agent-project --template project \
  --parameter user_type=agent \
  --parameter repo_url=https://github.com/org/repo \
  --parameter system_prompt="You are a coding assistant for this project..."
```
