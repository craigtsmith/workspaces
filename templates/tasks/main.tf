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

data "coder_external_auth" "github" {
  count = var.enable_github_auth ? 1 : 0
  id    = "github"
}

#------------------------------------------------------------------------------
# VARIABLES (push-time secrets - NOT exposed as parameters)
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

variable "enable_github_auth" {
  type        = bool
  description = "Enable GitHub external auth integration (git-config + SSH key upload)."
  default     = true
}

#------------------------------------------------------------------------------
# PARAMETERS (user-configurable)
#------------------------------------------------------------------------------

data "coder_parameter" "dotfiles_url" {
  type         = "string"
  name         = "dotfiles_url"
  display_name = "Dotfiles Repository"
  description  = "Git URL for your dotfiles (uses GNU Stow)"
  default      = ""
  mutable      = true
  order        = 1
}

data "coder_parameter" "repo_url" {
  type         = "string"
  name         = "repo_url"
  display_name = "Project Repository"
  description  = "Git repository to clone (required for tasks)"
  mutable      = true
  order        = 2
}

data "coder_parameter" "ai_agent" {
  type         = "string"
  name         = "ai_agent"
  display_name = "AI Agent"
  description  = "Select which AI agent to use for this task"
  default      = "claude"
  mutable      = false
  order        = 3

  option {
    name  = "Claude Code"
    value = "claude"
  }
  option {
    name  = "OpenAI Codex"
    value = "codex"
  }
  option {
    name  = "Cursor CLI"
    value = "cursor_cli"
  }
}

data "coder_parameter" "system_prompt" {
  type         = "string"
  name         = "system_prompt"
  display_name = "System Prompt"
  form_type    = "textarea"
  description  = "System prompt for AI agents"
  default      = "You are a helpful coding assistant."
  mutable      = false
  order        = 4
}

#------------------------------------------------------------------------------
# LOCALS
#------------------------------------------------------------------------------

locals {
  home_dir                = "/home/coder"
  anthropic_api_key       = trimspace(var.anthropic_api_key)
  openai_api_key          = trimspace(var.openai_api_key)
  github_external_auth_id = try(data.coder_external_auth.github[0].id, null)
  claude_ai_prompt        = data.coder_task.me.enabled ? trimspace(data.coder_task.me.prompt) : ""

  # AI agent selection flags
  use_claude = data.coder_parameter.ai_agent.value == "claude"
  use_codex  = data.coder_parameter.ai_agent.value == "codex"
  use_cursor = data.coder_parameter.ai_agent.value == "cursor_cli"

  agent_metadata = [
    {
      display_name = "CPU Usage"
      key          = "0_cpu_usage"
      script       = "coder stat cpu"
      interval     = 10
      timeout      = 1
    },
    {
      display_name = "RAM Usage"
      key          = "1_ram_usage"
      script       = "coder stat mem"
      interval     = 10
      timeout      = 1
    },
    {
      display_name = "Home Disk"
      key          = "3_home_disk"
      script       = "coder stat disk --path $${HOME}"
      interval     = 60
      timeout      = 1
    },
    {
      display_name = "CPU Usage (Host)"
      key          = "4_cpu_usage_host"
      script       = "coder stat cpu --host"
      interval     = 10
      timeout      = 1
    },
    {
      display_name = "Memory Usage (Host)"
      key          = "5_mem_usage_host"
      script       = "coder stat mem --host"
      interval     = 10
      timeout      = 1
    },
    {
      display_name = "Load Average (Host)"
      key          = "6_load_host"
      script       = <<-EOT
        echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
      EOT
      interval     = 60
      timeout      = 1
    },
    {
      display_name = "Swap Usage (Host)"
      key          = "7_swap_host"
      script       = <<-EOT
        free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
      EOT
      interval     = 10
      timeout      = 1
    }
  ]
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
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~ || true
      touch ~/.init_done
    fi
    mkdir -p ~/projects ~/.claude

    # Set zsh as default shell if available
    if command -v zsh >/dev/null 2>&1; then
      zsh_path="$(command -v zsh)"
      if [ "$SHELL" != "$zsh_path" ]; then
        sudo chsh -s "$zsh_path" "$USER" || true
      fi
    fi

    if [ ! -f ~/personalize ]; then
      cat <<'PERSONALIZE' > ~/personalize
${file("${path.module}/personalize")}
PERSONALIZE
      chmod +x ~/personalize
    fi
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  dynamic "metadata" {
    for_each = local.agent_metadata
    content {
      display_name = metadata.value.display_name
      key          = metadata.value.key
      script       = metadata.value.script
      interval     = metadata.value.interval
      timeout      = metadata.value.timeout
    }
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
  count    = local.anthropic_api_key != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "ANTHROPIC_API_KEY"
  value    = local.anthropic_api_key
}

resource "coder_env" "openai_api_key" {
  count    = local.openai_api_key != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "OPENAI_API_KEY"
  value    = local.openai_api_key
}

#------------------------------------------------------------------------------
# MODULES: Git
#------------------------------------------------------------------------------

module "dotfiles" {
  count        = data.coder_workspace.me.start_count > 0 && data.coder_parameter.dotfiles_url.value != "" ? 1 : 0
  source       = "registry.coder.com/coder/dotfiles/coder"
  version      = "~> 1.0"
  agent_id     = coder_agent.main.id
  dotfiles_uri = data.coder_parameter.dotfiles_url.value
}

module "git-config" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-config/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}

module "github-upload-public-key" {
  count            = local.github_external_auth_id != null ? data.coder_workspace.me.start_count : 0
  source           = "registry.coder.com/coder/github-upload-public-key/coder"
  version          = "~> 1.0"
  agent_id         = coder_agent.main.id
  external_auth_id = local.github_external_auth_id
}

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

module "personalize" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/personalize/coder"
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
# MODULES: AI Agents (conditional based on dropdown selection)
#------------------------------------------------------------------------------

# Claude Code - only when ai_agent == "claude"
module "claude-code" {
  count          = local.use_claude ? data.coder_workspace.me.start_count : 0
  source         = "registry.coder.com/coder/claude-code/coder"
  version        = "~> 4.0"
  agent_id       = coder_agent.main.id
  workdir        = "${local.home_dir}/projects"
  claude_api_key = local.anthropic_api_key
  ai_prompt      = local.claude_ai_prompt
  report_tasks   = false
  system_prompt  = data.coder_parameter.system_prompt.value
  order          = 10
}

# Codex - only when ai_agent == "codex"
module "codex" {
  count          = local.use_codex ? data.coder_workspace.me.start_count : 0
  source         = "registry.coder.com/coder-labs/codex/coder"
  version        = "~> 1.0"
  agent_id       = coder_agent.main.id
  folder         = "${local.home_dir}/projects"
  openai_api_key = local.openai_api_key
  order          = 11
}

# Cursor CLI - only when ai_agent == "cursor_cli"
# Note: This uses the cursor module which provides desktop app link
# For true CLI-only usage, a custom script would be needed
module "cursor-cli" {
  count    = local.use_cursor ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "${local.home_dir}/projects"
  order    = 12
}

# Mux - always available for AI agent orchestration
module "mux" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/mux/coder"
  version     = "~> 1.0"
  agent_id    = coder_agent.main.id
  add-project = "${local.home_dir}/projects"
  order       = 13
}

#------------------------------------------------------------------------------
# DEVCONTAINER
#------------------------------------------------------------------------------

resource "coder_devcontainer" "project" {
  count            = data.coder_workspace.me.start_count > 0 && length(module.git-clone) > 0 ? 1 : 0
  agent_id         = coder_agent.main.id
  workspace_folder = "${local.home_dir}/projects/${module.git-clone[0].folder_name}"
}

#------------------------------------------------------------------------------
# DOCKER RESOURCES
#------------------------------------------------------------------------------

resource "docker_image" "golden" {
  name = "coder-golden:latest"
  build {
    context    = "${path.module}/build"
    dockerfile = "Dockerfile"
  }
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_volume" "nvm_cache" {
  name = "coder-${data.coder_workspace.me.id}-nvm"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_volume" "uv_cache" {
  name = "coder-${data.coder_workspace.me.id}-uv"
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
  image      = docker_image.golden.image_id
  name       = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname   = data.coder_workspace.me.name
  privileged = true

  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = compact([
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    local.anthropic_api_key != "" ? "ANTHROPIC_API_KEY=${local.anthropic_api_key}" : "",
    local.openai_api_key != "" ? "OPENAI_API_KEY=${local.openai_api_key}" : "",
  ])

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
    container_path = "/home/coder/.nvm"
    volume_name    = docker_volume.nvm_cache.name
    read_only      = false
  }

  volumes {
    container_path = "/home/coder/.cache/uv"
    volume_name    = docker_volume.uv_cache.name
    read_only      = false
  }

  volumes {
    container_path = "/var/lib/docker"
    volume_name    = docker_volume.docker.name
    read_only      = false
  }
}
