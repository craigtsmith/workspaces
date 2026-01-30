#!/usr/bin/env bash
set -euo pipefail

# Format Terraform files

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

CHECK_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            CHECK_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--check]"
            echo
            echo "Format Terraform files in all templates."
            echo
            echo "Options:"
            echo "  --check    Check formatting without making changes (exit 1 if unformatted)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ "$CHECK_MODE" == true ]]; then
    echo "Checking Terraform formatting..."
    if $TF_CMD fmt -check -recursive "$TEMPLATES_DIR"; then
        echo "All files properly formatted"
    else
        echo "Some files need formatting. Run: ./scripts/fmt.sh" >&2
        exit 1
    fi
else
    echo "Formatting Terraform files..."
    $TF_CMD fmt -recursive "$TEMPLATES_DIR"
    echo "Done"
fi
