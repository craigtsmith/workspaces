terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.13"
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
data "coder_task" "me" {}

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

data "coder_parameter" "user_type" {
  type         = "string"
  name         = "user_type"
  display_name = "User Type"
  description  = "Who will be using this workspace?"
  default      = "human"
  mutable      = false
  order        = 1

  option {
    name  = "Human"
    value = "human"
  }
  option {
    name  = "Agent"
    value = "agent"
  }
}

data "coder_parameter" "repo_url" {
  type         = "string"
  name         = "repo_url"
  display_name = "Git Repository"
  description  = "Repository to clone (should contain devcontainer.json)"
  mutable      = true
  order        = 2
}

data "coder_parameter" "system_prompt" {
  type         = "string"
  name         = "system_prompt"
  display_name = "System Prompt"
  form_type    = "textarea"
  description  = "System prompt for AI agents"
  default      = "You are a helpful coding assistant."
  mutable      = false
  order        = 3
}

#------------------------------------------------------------------------------
# LOCALS
#------------------------------------------------------------------------------

locals {
  home_dir = "/home/coder"

  # Git identity based on user type
  git_author_name  = data.coder_parameter.user_type.value == "agent" ? "agent smith" : "craig t smith"
  git_author_email = data.coder_parameter.user_type.value == "agent" ? "craigts-agent@users.noreply.github.com" : "craigtsmith@users.noreply.github.com"
}

#------------------------------------------------------------------------------
# AI TASK
#------------------------------------------------------------------------------

# Note: coder_ai_task is created by the claude-code module when ai_prompt is set
# Only one coder_ai_task can exist per template

#------------------------------------------------------------------------------
# AGENT
#------------------------------------------------------------------------------

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  dir  = local.home_dir

  startup_script = <<-EOT
    set -e
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi
    mkdir -p ~/projects
    
    # Remove oh-my-zsh devcontainer (installed by dotfiles, not wanted)
    rm -rf ~/.oh-my-zsh/.devcontainer
  EOT

  shutdown_script = <<-EOT
    docker system prune -a -f || true
    sudo service docker stop || true
  EOT

  env = {
    GIT_AUTHOR_NAME     = local.git_author_name
    GIT_AUTHOR_EMAIL    = local.git_author_email
    GIT_COMMITTER_NAME  = local.git_author_name
    GIT_COMMITTER_EMAIL = local.git_author_email
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

resource "coder_script" "init_dind" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main.id
  display_name = "Initialize Docker-in-Docker"
  run_on_start = true
  icon         = "/icon/docker.svg"
  script       = file("${path.module}/scripts/init-docker-in-docker.sh")
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
# MODULES: Git
#------------------------------------------------------------------------------

module "git-clone" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.repo_url.value
  base_dir = "${local.home_dir}/projects"
}

module "devcontainers-cli" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/devcontainers-cli/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}

#------------------------------------------------------------------------------
# MODULES: IDEs
#------------------------------------------------------------------------------

module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "${local.home_dir}/projects"
  order    = 1
}

module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "${local.home_dir}/projects"
  order    = 2
}



#------------------------------------------------------------------------------
# MODULES: AI Agents
#------------------------------------------------------------------------------

module "claude-code" {
  count         = data.coder_workspace.me.start_count
  source        = "registry.coder.com/coder/claude-code/coder"
  version       = "~> 4.0"
  agent_id      = coder_agent.main.id
  workdir       = "${local.home_dir}/projects"
  ai_prompt     = data.coder_task.me.prompt
  system_prompt = data.coder_parameter.system_prompt.value
  order         = 10
}

module "mux" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/mux/coder"
  version     = "~> 1.0"
  agent_id    = coder_agent.main.id
  add-project = "${local.home_dir}/projects"
  order       = 11
}

module "codex" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder-labs/codex/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "${local.home_dir}/projects"
  order    = 12
}

#------------------------------------------------------------------------------
# DEVCONTAINER
#------------------------------------------------------------------------------

resource "coder_devcontainer" "project" {
  count            = data.coder_workspace.me.start_count
  agent_id         = coder_agent.main.id
  workspace_folder = "${local.home_dir}/projects/${module.git-clone[0].folder_name}"
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
