# Coder Master Template

A comprehensive Docker-based Coder template with Docker-in-Docker support, modern development tooling, and Claude Code integration.

## Features

### Core Infrastructure
- **Docker-in-Docker (DinD)**: Run containers within your workspace for dev containers and project services
- **Persistent Storage**: Separate volumes for home directory, projects, Docker data, and Claude config
- **Resource Management**: Configurable CPU and memory limits

### Development Tools Pre-installed
- **Node.js**: Latest version via NVM with pnpm support
- **Bun**: Latest version
- **Python 3**: With uv package manager
- **tmux**: Terminal multiplexer
- **Docker CLI**: For interacting with the DinD sidecar

### IDE Support
- **code-server**: VS Code in the browser
- **Cursor**: Desktop IDE integration

### Git Configuration
- **git-config**: Automatic Git user configuration from Coder identity
- **git-commit-signing**: SSH-based commit signing
- **github-upload-public-key**: Automatic SSH key upload to GitHub

### AI Coding
- **Claude Code**: Full integration
  - Persistent authentication (survives workspace restarts)
  - Optional per-workspace API key (use client's key instead of your own)

### Workspace Personalization
- **Dotfiles**: Apply your own dotfiles repository
- **Git Clone**: Automatically clone a repository on workspace start

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `git_repo_url` | Git repository to clone into ~/Projects | Empty |
| `git_repo_branch` | Branch to checkout | Default branch |
| `claude_api_key` | Your own Anthropic API key (optional) | Empty (uses workspace auth) |
| `cpu` | CPU cores | 4 |
| `memory` | RAM in GB | 8 |

## Directory Structure

All coding happens in `~/Projects/`. When you specify a git repository, it will be cloned there.

```
/home/coder/
├── Projects/           # All your code lives here
│   └── <repo-name>/    # Auto-cloned if git_repo_url is set
├── .claude/            # Persistent Claude Code config
└── ...                 # Home directory (persisted)
```

## Persistent Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `*-home` | `/home/coder` | Home directory |
| `*-projects` | `/home/coder/Projects` | Project files |
| `*-docker` | DinD `/var/lib/docker` | Docker images/containers |
| `*-claude-config` | `/home/coder/.claude` | Claude authentication |

## Using Docker in the Workspace

The workspace connects to a Docker-in-Docker sidecar:

```bash
docker run -d nginx
docker compose up -d
docker build -t my-image .
```

## Deployment

```bash
cd coder-template
coder templates push
```
