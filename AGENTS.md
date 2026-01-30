You are an experienced, pragmatic software engineering AI agent. Do not over-engineer a solution when a simple one is possible. Keep edits minimal. If you want an exception to ANY rule, you MUST stop and get permission first.

# AGENTS.md

## Project Overview

Multi-template repository for managing **Coder workspace templates**. Each template provisions Docker-based development environments with customizable tooling.

**Technology stack:**
- Terraform/OpenTofu for infrastructure configuration
- Docker for container builds
- Bash scripts for CLI tooling
- Coder platform for workspace management

## Reference

### Directory Structure

```
├── templates/
│   ├── shared/
│   │   └── build/
│   │       └── Dockerfile      # Golden Alpine image (shared by all templates)
│   ├── devbox/                 # Full development environment
│   │   ├── main.tf
│   │   ├── personalize
│   │   └── README.md
│   └── tasks/                  # AI task runner with agent selection
│       ├── main.tf
│       ├── personalize
│       ├── scripts/
│       │   └── init-docker-in-docker.sh
│       └── README.md
├── scripts/                    # CLI tooling (bash)
```

### Templates

- **devbox** — Full development environment with all AI agents (Claude, Codex, Mux)
- **tasks** — AI task runner with selectable agent (Claude OR Codex OR Cursor CLI)

### Important Files

- `templates/shared/build/Dockerfile` — Golden Alpine image with all tooling
- `templates/<name>/main.tf` — Primary Terraform config for each template
- `scripts/*.sh` — All CLI operations

## Essential Commands

```bash
# List templates
./scripts/list.sh

# Validate (runs terraform/tofu validate)
./scripts/validate.sh           # All templates
./scripts/validate.sh default   # Single template

# Format Terraform
./scripts/fmt.sh                # Format all
./scripts/fmt.sh --check        # Check only (CI)

# Push to Coder
./scripts/push.sh default       # Single template
./scripts/push-all.sh           # All templates

# Pull from Coder
./scripts/pull.sh default

# Create new template
./scripts/init.sh minimal                   # Empty template
./scripts/init.sh gpu --from default        # Copy from existing
```

## Patterns

### Template Structure

- Each template is **self-contained** in `templates/<name>/`
- `main.tf` contains all Terraform configuration (no splitting)
- Shared golden image in `templates/shared/build/Dockerfile`
- Modules use `start_count` to only run on workspace start
- API keys are push-time variables only (no user override parameters)
- Persistent volumes survive workspace restarts (home, nvm cache, uv cache)

### Adding a New Template

1. Create template: `./scripts/init.sh <name> [--from <source>]`
2. Edit `templates/<name>/main.tf`
3. Add `templates/<name>/README.md`
4. Validate: `./scripts/validate.sh <name>`
5. Push: `./scripts/push.sh <name>`

## Commit and Pull Request Guidelines

### Before Committing

1. Format: `./scripts/fmt.sh`
2. Validate: `./scripts/validate.sh`

### Commit Messages

Use conventional commits: `type: message`

- `feat:` — New template or feature
- `fix:` — Bug fix
- `refactor:` — Code restructuring
- `docs:` — Documentation only
- `chore:` — Maintenance tasks

Keep subject line under 50 characters. Reference template name in parentheses when applicable: `fix(default): fix volume permissions`
