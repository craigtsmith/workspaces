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

locals {
  username = data.coder_workspace_owner.me.name
  home_dir = "/home/coder"
}

#------------------------------------------------------------------------------
# VARIABLES (API Keys)
#------------------------------------------------------------------------------

variable "anthropic_api_key" {
  type        = string
  description = "Anthropic API key for Claude Code"
  default     = ""
  sensitive   = true
}

variable "openai_api_key" {
  type        = string
  description = "OpenAI API key for Codex"
  default     = ""
  sensitive   = true
}

#------------------------------------------------------------------------------
# PARAMETERS
#------------------------------------------------------------------------------

data "coder_parameter" "git_repo_url" {
  type         = "string"
  name         = "git_repo_url"
  display_name = "Git Repository URL"
  description  = "Repository to clone into ~/Projects (optional)"
  default      = ""
  mutable      = true
}

#------------------------------------------------------------------------------
# AGENT
#------------------------------------------------------------------------------

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  dir  = local.home_dir

  startup_script = <<-EOT
    set -e
    # Initialize home from skeleton on first run
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi
    mkdir -p ~/Projects ~/.claude
  EOT

  shutdown_script = <<-EOT
    docker system prune -a -f || true
    sudo service docker stop || true
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
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    script       = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

#------------------------------------------------------------------------------
# SCRIPTS
#------------------------------------------------------------------------------

resource "coder_script" "docker_init" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main.id
  display_name = "Start Docker"
  run_on_start = true
  icon         = "/icon/docker.svg"
  script       = "sudo service docker start"
}

#------------------------------------------------------------------------------
# API KEY INJECTION
#------------------------------------------------------------------------------

resource "coder_env" "anthropic_api_key" {
  count    = var.anthropic_api_key != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "ANTHROPIC_API_KEY"
  value    = var.anthropic_api_key
}

resource "coder_env" "openai_api_key" {
  count    = var.openai_api_key != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "OPENAI_API_KEY"
  value    = var.openai_api_key
}

#------------------------------------------------------------------------------
# MODULES: Dotfiles & Git
#------------------------------------------------------------------------------

module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/dotfiles/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}

module "git-config" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-config/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}

module "git-clone" {
  count    = data.coder_workspace.me.start_count > 0 && data.coder_parameter.git_repo_url.value != "" ? 1 : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_repo_url.value
  base_dir = "${local.home_dir}/Projects"
}

#------------------------------------------------------------------------------
# MODULES: IDEs
#------------------------------------------------------------------------------

module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "${local.home_dir}/Projects"
  order    = 1
}

module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "${local.home_dir}/Projects"
  order    = 2
}

#------------------------------------------------------------------------------
# MODULES: AI Agents
#------------------------------------------------------------------------------

module "claude-code" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/coder/claude-code/coder"
  version             = "~> 4.0"
  agent_id            = coder_agent.main.id
  workdir             = "${local.home_dir}/Projects"
  install_claude_code = true
  order               = 3
}

module "mux" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/mux/coder"
  version     = "~> 1.0"
  agent_id    = coder_agent.main.id
  add-project = "${local.home_dir}/Projects"
  order       = 4
}

module "codex" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder-labs/codex/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "${local.home_dir}/Projects"
  order    = 5
}

#------------------------------------------------------------------------------
# DOCKER RESOURCES
#------------------------------------------------------------------------------

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_volume" "docker" {
  name = "coder-${data.coder_workspace.me.id}-docker"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  image      = "codercom/enterprise-node:ubuntu"
  name       = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname   = data.coder_workspace.me.name
  privileged = true

  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  volumes {
    container_path = "/var/lib/docker"
    volume_name    = docker_volume.docker.name
    read_only      = false
  }
}
