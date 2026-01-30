#!/usr/bin/env bash
set -euo pipefail

# Initialize a new template

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/templates"

usage() {
    echo "Usage: $0 <name> [--from <source>]"
    echo
    echo "Create a new template."
    echo
    echo "Options:"
    echo "  --from <source>   Copy from an existing template"
    echo
    echo "Examples:"
    echo "  $0 minimal                    # Create empty template"
    echo "  $0 gpu --from default         # Copy from 'default' template"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

NEW_NAME="$1"
shift

SOURCE_NAME=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)
            if [[ $# -lt 2 ]]; then
                echo "Error: --from requires a template name" >&2
                exit 1
            fi
            SOURCE_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

NEW_DIR="$TEMPLATES_DIR/$NEW_NAME"

if [[ -d "$NEW_DIR" ]]; then
    echo "Error: Template already exists: $NEW_NAME" >&2
    exit 1
fi

if [[ -n "$SOURCE_NAME" ]]; then
    SOURCE_DIR="$TEMPLATES_DIR/$SOURCE_NAME"
    if [[ ! -d "$SOURCE_DIR" ]]; then
        echo "Error: Source template not found: $SOURCE_NAME" >&2
        exit 1
    fi

    echo "Creating template '$NEW_NAME' from '$SOURCE_NAME'..."
    cp -r "$SOURCE_DIR" "$NEW_DIR"

    # Clean up terraform state files if present
    rm -rf "$NEW_DIR/.terraform"
    rm -f "$NEW_DIR/.terraform.lock.hcl"
    rm -f "$NEW_DIR/terraform.tfstate"*
else
    echo "Creating empty template: $NEW_NAME"
    mkdir -p "$NEW_DIR/build"

    cat > "$NEW_DIR/main.tf" << 'EOF'
terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}
provider "coder" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# TODO: Add your template configuration here
EOF

    cat > "$NEW_DIR/README.md" << EOF
# $NEW_NAME

Template description goes here.

## Features

- Feature 1
- Feature 2

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| ... | ... | ... |
EOF
fi

echo "Template created: $NEW_DIR"
echo
echo "Next steps:"
echo "  1. Edit the template: templates/$NEW_NAME/main.tf"
echo "  2. Validate: ./scripts/validate.sh $NEW_NAME"
echo "  3. Push to Coder: ./scripts/push.sh $NEW_NAME"
