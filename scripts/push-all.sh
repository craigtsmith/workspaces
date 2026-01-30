#!/usr/bin/env bash
set -euo pipefail

# Push all templates to Coder

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/templates"

YES_FLAG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            YES_FLAG="--yes"
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--yes]"
            exit 1
            ;;
    esac
done

if [[ ! -d "$TEMPLATES_DIR" ]]; then
    echo "No templates directory found" >&2
    exit 1
fi

TEMPLATES=()
for dir in "$TEMPLATES_DIR"/*/; do
    if [[ -d "$dir" && -f "$dir/main.tf" ]]; then
        TEMPLATES+=("$(basename "$dir")")
    fi
done

if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
    echo "No templates found" >&2
    exit 1
fi

echo "Pushing ${#TEMPLATES[@]} template(s)..."
echo

FAILED=()
for name in "${TEMPLATES[@]}"; do
    echo "=== $name ==="
    if "$SCRIPT_DIR/push.sh" "$name" $YES_FLAG; then
        echo
    else
        FAILED+=("$name")
        echo "Failed to push: $name" >&2
        echo
    fi
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Failed templates: ${FAILED[*]}" >&2
    exit 1
fi

echo "All templates pushed successfully"
