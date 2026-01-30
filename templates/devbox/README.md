# Devbox Template

Personal remote development environment with AI coding assistants.

## Features

- **Base Image**: `codercom/enterprise-node:ubuntu` (Node.js + Docker pre-installed)
- **Docker**: Privileged mode with internal Docker-in-Docker
- **IDEs**: VS Code (code-server for browser/iPad), Cursor
- **AI Agents**: Claude Code, Mux, Codex
- **Tooling**: Dotfiles module for personal tool installation
- **Personalization**: personalize module pre-installs zsh and seeds a `~/personalize` script you can edit

## Parameters

| Parameter | Description |
|-----------|-------------|
| `git_repo_url` | Optional repository to clone into `~/Projects` |

## Template Variables

Set these when pushing the template:

| Variable | Description |
|----------|-------------|
| `anthropic_api_key` | Anthropic API key for Claude Code (default taken from `.envrc`) |
| `openai_api_key` | OpenAI API key for Codex (default taken from `.envrc`) |
| `enable_github_auth` | Set to `false` if GitHub external auth/SSH upload is not configured |

> The template prompts for Anthropic/OpenAI keys at workspace creation; leave them blank to use the values sourced from `.envrc` during `./scripts/push.sh`.

## GitHub integration

- [`git-config`](https://registry.coder.com/modules/coder/git-config) syncs your Git author/email from Coder.
- [`github-upload-public-key`](https://registry.coder.com/modules/coder/github-upload-public-key) uploads the workspace SSH key via GitHub external auth (requires the `admin:public_key` scope).
- Create separate Coder accounts for each agent if you want distinct Git identities.

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
