# CLAUDE.md

Agent instructions for working with this repository.

## Project Overview

Multi-template repository for managing Coder workspace templates. Each template provisions Docker-based development environments with customizable tooling.

## Directory Structure

```
workspaces/
├── templates/              # Coder templates (each is self-contained)
│   └── <name>/
│       ├── main.tf         # Template configuration
│       ├── build/          # Dockerfile and build context
│       └── README.md       # Template-specific docs
├── scripts/                # CLI tooling
└── shared/modules/         # Shared Terraform modules
```

## Commands

```bash
# List templates
./scripts/list.sh

# Validate templates
./scripts/validate.sh           # All templates
./scripts/validate.sh default   # Single template

# Format Terraform
./scripts/fmt.sh                # Format all
./scripts/fmt.sh --check        # Check only

# Push to Coder
./scripts/push.sh default       # Single template
./scripts/push-all.sh           # All templates

# Pull from Coder
./scripts/pull.sh default

# Create new template
./scripts/init.sh minimal                   # Empty template
./scripts/init.sh gpu --from default        # Copy from existing
```

## Template Patterns

- Each template is self-contained in `templates/<name>/`
- `main.tf` contains all Terraform configuration
- `build/` contains Dockerfile and build context
- Modules use `start_count` to only run on workspace start
- DinD sidecar provides Docker via `tcp://dind-{workspace-id}:2375`
- Persistent volumes survive workspace restarts

## Adding a New Template

1. Create template: `./scripts/init.sh <name> [--from <source>]`
2. Edit `templates/<name>/main.tf`
3. Add `templates/<name>/README.md`
4. Validate: `./scripts/validate.sh <name>`
5. Push: `./scripts/push.sh <name>`
