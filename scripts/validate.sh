#!/usr/bin/env bash
set -euo pipefail

# Validate Terraform configurations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/templates"

# Prefer tofu over terraform if available
if command -v tofu &>/dev/null; then
    TF_CMD="tofu"
elif command -v terraform &>/dev/null; then
    TF_CMD="terraform"
else
    echo "Error: Neither tofu nor terraform found in PATH" >&2
    exit 1
fi

usage() {
    echo "Usage: $0 [template-name]"
    echo
    echo "Validate Terraform configuration for templates."
    echo "If no template name is provided, validates all templates."
    echo
    echo "Examples:"
    echo "  $0           # Validate all templates"
    echo "  $0 default   # Validate only 'default' template"
    exit 1
}

validate_template() {
    local name="$1"
    local dir="$TEMPLATES_DIR/$name"

    if [[ ! -f "$dir/main.tf" ]]; then
        echo "Skipping $name (no main.tf)" >&2
        return 0
    fi

    echo "Validating: $name"
    cd "$dir"

    # Initialize if needed
    if [[ ! -d ".terraform" ]]; then
        $TF_CMD init -backend=false >/dev/null 2>&1 || true
    fi

    $TF_CMD validate
}

if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help)
            usage
            ;;
        *)
            validate_template "$1"
            ;;
    esac
else
    # Validate all templates
    FAILED=()
    for dir in "$TEMPLATES_DIR"/*/; do
        if [[ -d "$dir" ]]; then
            name=$(basename "$dir")
            if ! validate_template "$name"; then
                FAILED+=("$name")
            fi
        fi
    done

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo
        echo "Failed templates: ${FAILED[*]}" >&2
        exit 1
    fi

    echo
    echo "All templates valid"
fi
