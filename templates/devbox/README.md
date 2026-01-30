# Devbox Template

Personal remote development environment with AI coding assistants.

## Features

- **Base Image**: `codercom/enterprise-node:ubuntu` (Node.js + Docker pre-installed)
- **Docker**: Privileged mode with internal Docker-in-Docker
- **IDEs**: VS Code (code-server for browser/iPad), Cursor
- **AI Agents**: Claude Code, Mux, Codex
- **Tooling**: Dotfiles module for personal tool installation

## Parameters

| Parameter | Description |
|-----------|-------------|
| `git_repo_url` | Optional repository to clone into `~/Projects` |

## Template Variables

Set these when pushing the template:

| Variable | Description |
|----------|-------------|
| `anthropic_api_key` | Anthropic API key for Claude Code |
| `openai_api_key` | OpenAI API key for Codex |

## Volumes

- `/home/coder` - Persistent home directory
- `/var/lib/docker` - Docker cache (persists images/containers)

## Usage

```bash
# Push template
./scripts/push.sh devbox

# Create workspace
coder create my-devbox --template devbox
```
