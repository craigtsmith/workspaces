# Default Workspace Template

A comprehensive Docker-based Coder template with Docker-in-Docker support, modern development tooling, and Claude Code integration.

## Features

### Core Infrastructure
- **Docker-in-Docker (DinD)**: Run containers within your workspace for dev containers and project services
- **Persistent Storage**: Separate volumes for home directory, projects, Docker data, and Claude config
- **Resource Management**: Configurable CPU and memory limits

### Development Tools
- **Node.js**: Latest version via NVM with pnpm
- **Bun**: Fast JavaScript runtime
- **Python 3**: With uv package manager
- **Docker CLI**: For container operations
- **tmux**: Terminal multiplexer

### IDE Support
- **code-server**: VS Code in the browser
- **Cursor**: Desktop IDE integration

### Git Integration
- Automatic Git user configuration from Coder identity
- SSH-based commit signing
- Automatic SSH key upload to GitHub

### AI Coding
- **Claude Code**: Full integration with persistent authentication

### Personalization
- **Dotfiles**: Apply your dotfiles repository
- **Git Clone**: Auto-clone a repository on workspace start

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `git_repo_url` | Git repository to clone into ~/Projects | Empty |
| `git_repo_branch` | Branch to checkout | Default branch |
| `claude_api_key` | Anthropic API key (optional) | Empty (uses workspace auth) |
| `cpu` | CPU cores (2, 4, 8) | 4 |
| `memory` | RAM in GB (4, 8, 16, 32) | 8 |

## Persistent Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `*-home` | `/home/<user>` | Home directory |
| `*-projects` | `/home/<user>/Projects` | Project files |
| `*-docker` | DinD `/var/lib/docker` | Docker images/containers |
| `*-claude-config` | `/home/<user>/.claude` | Claude authentication |

## Directory Structure

```
/home/<user>/
├── Projects/           # All code lives here
│   └── <repo-name>/    # Auto-cloned if git_repo_url is set
├── .claude/            # Persistent Claude config
└── ...
```

## Using Docker

The workspace connects to a Docker-in-Docker sidecar:

```bash
docker run -d nginx
docker compose up -d
docker build -t my-image .
```

## Deployment

```bash
# From repo root
./scripts/push.sh default

# Or from this directory
coder templates push default
```
