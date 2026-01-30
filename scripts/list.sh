#!/usr/bin/env bash
set -euo pipefail

# List all available templates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/templates"

if [[ ! -d "$TEMPLATES_DIR" ]]; then
    echo "No templates directory found" >&2
    exit 1
fi

echo "Available templates:"
echo

for dir in "$TEMPLATES_DIR"/*/; do
    if [[ -d "$dir" ]]; then
        name=$(basename "$dir")
        if [[ -f "$dir/main.tf" ]]; then
            echo "  $name"
        fi
    fi
done
