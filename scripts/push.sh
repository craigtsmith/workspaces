#!/usr/bin/env bash
set -euo pipefail

# Push a single template to Coder

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/templates"

usage() {
    echo "Usage: $0 <template-name> [--yes]"
    echo
    echo "Push a template to Coder."
    echo
    echo "Options:"
    echo "  --yes    Skip confirmation prompt"
    echo
    echo "Examples:"
    echo "  $0 default"
    echo "  $0 default --yes"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

TEMPLATE_NAME="$1"
shift

YES_FLAG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            YES_FLAG="--yes"
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

TEMPLATE_DIR="$TEMPLATES_DIR/$TEMPLATE_NAME"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "Template not found: $TEMPLATE_NAME" >&2
    echo "Available templates:"
    "$SCRIPT_DIR/list.sh"
    exit 1
fi

if [[ ! -f "$TEMPLATE_DIR/main.tf" ]]; then
    echo "Invalid template: $TEMPLATE_NAME (no main.tf found)" >&2
    exit 1
fi

echo "Pushing template: $TEMPLATE_NAME"
coder templates push --directory "$TEMPLATE_DIR" $YES_FLAG "$TEMPLATE_NAME"
