```
                                    oooo                   
                                    `888                   
oooo oooo    ooo  .ooooo.  oooo d8b  888  oooo             
 `88. `88.  .8'  d88' `88b `888""8P  888 .8P'              
  `88..]88..8'   888   888  888      888888.               
   `888'`888'    888   888  888      888 `88b.             
    `8'  `8'     `Y8bod8P' d888b    o888o o888o            
 .oooo.o oo.ooooo.   .oooo.    .ooooo.   .ooooo.   .oooo.o 
d88(  "8  888' `88b `P  )88b  d88' `"Y8 d88' `88b d88(  "8 
`"Y88b.   888   888  .oP"888  888       888ooo888 `"Y88b.  
o.  )88b  888   888 d8(  888  888   .o8 888    .o o.  )88b 
8""888P'  888bod8P' `Y888""8o `Y8bod8P' `Y8bod8P' 8""888P' 
          888                                              
         o888o                                             
                                                           
```

A multi-template repository for managing [Coder](https://coder.com) workspace templates with Docker-based development environments.

## Directory Structure

```
workspaces/
├── templates/              # Coder templates
│   └── default/            # Default workspace template
│       ├── main.tf
│       └── build/
├── scripts/                # CLI tooling
│   ├── list.sh             # List templates
│   ├── push.sh             # Push single template
│   ├── push-all.sh         # Push all templates
│   ├── pull.sh             # Pull from Coder
│   ├── validate.sh         # Validate configs
│   ├── fmt.sh              # Format TF files
│   └── init.sh             # Create new template
└── shared/
    └── modules/            # Shared Terraform modules
```

## Prerequisites

- [Coder CLI](https://coder.com/docs/cli) - authenticated with `coder login`
- [OpenTofu](https://opentofu.org/) or [Terraform](https://terraform.io/)
- [Docker](https://docker.com/) (for building workspace images)

## Quick Start

```bash
# List available templates
./scripts/list.sh

# Push a template to Coder
./scripts/push.sh default

# Validate all templates
./scripts/validate.sh

# Format Terraform files
./scripts/fmt.sh
```

## Available Templates

| Template | Description |
|----------|-------------|
| `default` | Full-featured workspace with DinD, Node.js, Python, Bun, and IDE integrations |

See individual template READMEs in `templates/<name>/README.md` for details.

## Creating a New Template

```bash
# Create from scratch
./scripts/init.sh my-template

# Copy from existing template
./scripts/init.sh gpu --from default
```

Then customize `templates/my-template/main.tf` and push:

```bash
./scripts/validate.sh my-template
./scripts/push.sh my-template
```

## Script Reference

| Script | Description | Usage |
|--------|-------------|-------|
| `list.sh` | List available templates | `./scripts/list.sh` |
| `push.sh` | Push template to Coder | `./scripts/push.sh <name> [--yes]` |
| `push-all.sh` | Push all templates | `./scripts/push-all.sh [--yes]` |
| `pull.sh` | Pull template from Coder | `./scripts/pull.sh <name>` |
| `validate.sh` | Validate Terraform | `./scripts/validate.sh [name]` |
| `fmt.sh` | Format Terraform files | `./scripts/fmt.sh [--check]` |
| `init.sh` | Create new template | `./scripts/init.sh <name> [--from <src>]` |

All scripts prefer `tofu` over `terraform` if available.

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Validate Templates

on:
  pull_request:
    paths:
      - 'templates/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: opentofu/setup-opentofu@v1

      - name: Check formatting
        run: ./scripts/fmt.sh --check

      - name: Validate templates
        run: ./scripts/validate.sh
```

## Resources

- [Coder Templates Documentation](https://coder.com/docs/templates)
- [Coder Module Registry](https://registry.coder.com/)
- [Terraform Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
