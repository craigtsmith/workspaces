#!/usr/bin/env bash
set -euo pipefail

# Pull a template from Coder

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/templates"

usage() {
    echo "Usage: $0 <template-name>"
    echo
    echo "Pull a template from Coder into the local templates directory."
    echo
    echo "Examples:"
    echo "  $0 default"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

TEMPLATE_NAME="$1"
TEMPLATE_DIR="$TEMPLATES_DIR/$TEMPLATE_NAME"

mkdir -p "$TEMPLATE_DIR"
cd "$TEMPLATE_DIR"

echo "Pulling template: $TEMPLATE_NAME"
coder templates pull "$TEMPLATE_NAME" .

echo "Template pulled to: $TEMPLATE_DIR"
