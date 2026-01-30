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

locals {
  username = data.coder_workspace_owner.me.name
}

provider "docker" {}

provider "coder" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

#------------------------------------------------------------------------------
# WORKSPACE PARAMETERS
#------------------------------------------------------------------------------

data "coder_parameter" "git_repo_url" {
  type         = "string"
  name         = "git_repo_url"
  display_name = "Git Repository URL"
  description  = "Git repository to clone into ~/Projects (leave empty to skip)"
  default      = ""
  mutable      = true
  order        = 1
}

data "coder_parameter" "git_repo_branch" {
  type         = "string"
  name         = "git_repo_branch"
  display_name = "Git Branch"
  description  = "Branch to checkout (leave empty for default branch)"
  default      = ""
  mutable      = true
  order        = 2
}

variable "claude_api_key" {
  type        = string
  description = "Anthropic API key for Claude Code (optional - leave empty to use workspace authentication)"
  default     = ""
  sensitive   = true
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores for the workspace"
  type         = "number"
  default      = "4"
  mutable      = true
  order        = 4

  option {
    name  = "2 Cores"
    value = "2"
  }
  option {
    name  = "4 Cores"
    value = "4"
  }
  option {
    name  = "8 Cores"
    value = "8"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Amount of RAM for the workspace"
  type         = "number"
  default      = "8"
  mutable      = true
  order        = 5

  option {
    name  = "4 GB"
    value = "4"
  }
  option {
    name  = "8 GB"
    value = "8"
  }
  option {
    name  = "16 GB"
    value = "16"
  }
  option {
    name  = "32 GB"
    value = "32"
  }
}

#------------------------------------------------------------------------------
# CODER AGENT
#------------------------------------------------------------------------------

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  dir  = "/home/${local.username}"

  startup_script = <<-EOT
    set -e

    # Fix ownership of mounted volumes (Docker creates them as root)
    sudo chown -R $(id -u):$(id -g) ~ 2>/dev/null || true

    # Ensure directories exist with correct permissions
    mkdir -p ~/Projects ~/.claude ~/.local/bin

    # Wait for Docker to be available (from sidecar)
    echo "Waiting for Docker to be available..."
    timeout 60 bash -c 'until docker info >/dev/null 2>&1; do sleep 1; done' || echo "Docker not available yet"

    # Source shell configurations
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$HOME/.local/bin:$PATH"
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "Projects Disk"
    key          = "4_projects_disk"
    script       = "coder stat disk --path $${HOME}/Projects"
    interval     = 60
    timeout      = 1
  }
}

#------------------------------------------------------------------------------
# MODULES: DOTFILES
#------------------------------------------------------------------------------

module "dotfiles" {
  count                = data.coder_workspace.me.start_count
  source               = "registry.coder.com/coder/dotfiles/coder"
  version              = "1.0.29"
  agent_id             = coder_agent.main.id
  default_dotfiles_uri = "https://github.com/craigtsmith/dotfiles"
}

#------------------------------------------------------------------------------
# MODULES: GIT CLONE (conditional)
#------------------------------------------------------------------------------

module "git-clone" {
  count    = data.coder_workspace.me.start_count > 0 && data.coder_parameter.git_repo_url.value != "" ? 1 : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.2.2"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_repo_url.value
  base_dir = "/home/${local.username}/Projects"
}

#------------------------------------------------------------------------------
# MODULES: GIT CONFIG & SIGNING
#------------------------------------------------------------------------------

module "git-config" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-config/coder"
  version  = "1.0.17"
  agent_id = coder_agent.main.id
}

module "git-commit-signing" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-commit-signing/coder"
  version  = "1.0.17"
  agent_id = coder_agent.main.id
}

module "github-upload-public-key" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/github-upload-public-key/coder"
  version  = "1.0.18"
  agent_id = coder_agent.main.id
}

#------------------------------------------------------------------------------
# MODULES: CODE-SERVER (VS Code in Browser)
#------------------------------------------------------------------------------

module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "1.3.0"
  agent_id = coder_agent.main.id
  folder   = "/home/${local.username}/Projects"
  order    = 1
}

#------------------------------------------------------------------------------
# MODULES: CURSOR
#------------------------------------------------------------------------------

module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.0.21"
  agent_id = coder_agent.main.id
  folder   = "/home/${local.username}/Projects"
  order    = 2
}

#------------------------------------------------------------------------------
# MODULES: CLAUDE CODE
#------------------------------------------------------------------------------

module "claude-code" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/coder/claude-code/coder"
  version             = "4.4.2"
  agent_id            = coder_agent.main.id
  workdir             = "/home/${local.username}/Projects"
  install_claude_code = true
  claude_code_version = "latest"
  order               = 3
}

# Set ANTHROPIC_API_KEY if provided via template variable
resource "coder_env" "anthropic_api_key" {
  count    = var.claude_api_key != "" ? data.coder_workspace.me.start_count : 0
  agent_id = coder_agent.main.id
  name     = "ANTHROPIC_API_KEY"
  value    = var.claude_api_key
}

#------------------------------------------------------------------------------
# DOCKER NETWORKING
#------------------------------------------------------------------------------

resource "docker_network" "workspace_network" {
  name = "coder-${data.coder_workspace.me.id}-network"
}

#------------------------------------------------------------------------------
# DOCKER VOLUMES (Persistent)
#------------------------------------------------------------------------------

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_volume" "projects_volume" {
  name = "coder-${data.coder_workspace.me.id}-projects"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_volume" "docker_volume" {
  name = "coder-${data.coder_workspace.me.id}-docker"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_volume" "claude_config_volume" {
  name = "coder-${data.coder_workspace.me.id}-claude-config"
  lifecycle {
    ignore_changes = all
  }
}

#------------------------------------------------------------------------------
# DOCKER IMAGE
#------------------------------------------------------------------------------

resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}"
  build {
    context = "./build"
    build_args = {
      USER = local.username
    }
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

#------------------------------------------------------------------------------
# DOCKER-IN-DOCKER SIDECAR
#------------------------------------------------------------------------------

resource "docker_container" "dind" {
  image      = "docker:dind"
  privileged = true
  name       = "dind-${data.coder_workspace.me.id}"
  entrypoint = ["dockerd", "-H", "tcp://0.0.0.0:2375", "--tls=false"]

  networks_advanced {
    name = docker_network.workspace_network.name
  }

  volumes {
    volume_name    = docker_volume.docker_volume.name
    container_path = "/var/lib/docker"
  }
}

#------------------------------------------------------------------------------
# WORKSPACE CONTAINER
#------------------------------------------------------------------------------

resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.main.name
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name

  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "DOCKER_HOST=tcp://dind-${data.coder_workspace.me.id}:2375"
  ]

  networks_advanced {
    name = docker_network.workspace_network.name
  }

  volumes {
    container_path = "/home/${local.username}"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }

  volumes {
    container_path = "/home/${local.username}/Projects"
    volume_name    = docker_volume.projects_volume.name
    read_only      = false
  }

  volumes {
    container_path = "/home/${local.username}/.claude"
    volume_name    = docker_volume.claude_config_volume.name
    read_only      = false
  }

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  depends_on = [docker_container.dind]
}
