# Devbox Template

Full-featured development environment with AI coding assistants.

## Features

- **Golden Alpine Image**: Lightweight base (~50MB) with all common dev tools
- **Pre-installed Tools**: git, tmux, fzf, eza, starship, zoxide, direnv, stow
- **Language Runtimes**: nvm (Node.js), uv (Python), bun (JS runtime)
- **AI Assistants**: Claude Code, Codex, and Mux
- **IDEs**: Code Server (VS Code in browser) and Cursor desktop link
- **Persistent Storage**: Home directory, nvm cache, and uv cache survive restarts

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `dotfiles_url` | Git URL for your dotfiles (uses GNU Stow) | (empty) |
| `repo_url` | Git repository to clone | (empty) |

## Variables (Push-time)

These are set when pushing the template and cannot be overridden by users:

- `anthropic_api_key` - Anthropic API key for Claude Code
- `openai_api_key` - OpenAI API key for Codex
- `enable_github_auth` - Enable GitHub external auth (default: true)

## Usage

```bash
# Push with API keys
TF_VAR_anthropic_api_key="sk-ant-..." TF_VAR_openai_api_key="sk-..." \
  ./scripts/push.sh devbox
```

## Personalization

The `~/personalize` script runs on every workspace start. Add your custom setup:

```bash
#!/usr/bin/env bash
# Install additional tools, set env vars, etc.
```
