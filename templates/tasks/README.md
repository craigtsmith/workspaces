# Tasks Template

AI-powered task runner template for automated coding tasks.

## Features

- **AI Agent Selection**: Choose between Claude Code, OpenAI Codex, or Cursor CLI
- **Devcontainer Support**: Automatic devcontainer detection and setup
- **Docker-in-Docker**: Full Docker support inside the workspace
- **Persistent Storage**: Volumes for home, nvm cache, and uv cache

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `dotfiles_url` | Git URL for your dotfiles (uses GNU Stow) | (empty) |
| `repo_url` | Git repository to clone (required) | - |
| `ai_agent` | AI agent to use: `claude`, `codex`, or `cursor_cli` | `claude` |
| `system_prompt` | System prompt for AI agents | "You are a helpful coding assistant." |

## Variables (Push-time)

These are set when pushing the template and cannot be overridden by users:

- `anthropic_api_key` - Anthropic API key for Claude Code
- `openai_api_key` - OpenAI API key for Codex
- `enable_github_auth` - Enable GitHub external auth (default: true)

## Usage

```bash
# Push with API keys
TF_VAR_anthropic_api_key="sk-ant-..." TF_VAR_openai_api_key="sk-..." \
  ./scripts/push.sh tasks
```
