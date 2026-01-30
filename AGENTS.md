# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Overview

This is a Coder template that provisions Docker-based development workspaces with Docker-in-Docker support. It creates containerized dev environments with pre-installed tooling (Node.js, Python, Bun) and IDE integrations.

## Commands

```bash
# Validate Terraform configuration
terraform validate

# Format Terraform files
terraform fmt

# Deploy template to Coder
coder templates push
```

## Architecture

**main.tf** - Single Terraform file containing all infrastructure:
- Workspace parameters (git repo, CPU/memory limits, API keys)
- Coder agent with startup script and metadata
- Coder modules from registry (dotfiles, git-clone, code-server, cursor, claude-code)
- Docker resources: network, volumes (home, projects, docker, claude-config), image build, containers

**build/Dockerfile** - Ubuntu 22.04 base image with:
- Docker CLI (connects to DinD sidecar)
- Node.js via NVM with pnpm
- Bun runtime
- Python 3 with uv package manager

**Key patterns:**
- DinD sidecar provides Docker functionality via `tcp://dind-{workspace-id}:2375`
- Four persistent volumes survive workspace restarts (home, projects, docker data, claude config)
- Modules use `start_count` to only run on workspace start, not stop
- Git config pulled from `coder_workspace_owner` data source
