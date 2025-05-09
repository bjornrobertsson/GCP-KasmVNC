terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 0.12"
    }
  }
}

resource "coder_script" "kasm_vnc" {
  agent_id     = var.agent_id
  display_name = "KasmVNC"
  icon         = "/icon/kasmvnc.svg"
  run_on_start = true
  script       = templatefile("${path.module}/run.sh", {
    PORT                 = var.port,
    DESKTOP_ENVIRONMENT  = var.desktop_environment,
    KASM_VERSION         = var.kasm_version,
    WORKSPACE_OWNER_NAME = var.workspace_owner.name,
    SUBDOMAIN            = var.subdomain,
    DEBUG                = "${var.debug ? "Y" : "N"}"
  })
}

locals {
  templates=tomap(
    {"/tmp/path_vnc.html" = filebase64("${path.module}/path_vnc.html")}
  )
}

# The base64 shenanigans are to prevent terraform from trying to
# parse the filedata in any meaningful way; a really brittle hack.
resource "coder_script" "upload_files" {
  for_each     = local.templates
  agent_id     = var.agent_id
  run_on_start = true
  display_name = "File Dropper"
  icon         = "/icon/filebrowser.svg"
  script       =<<-EOT
    #!/usr/bin/env bash
    mkdir -p ${basename(each.key)}
    cat << EOF > ${each.key}
    ${base64decode(each.value)}
    EOF
  EOT
}

resource "coder_app" "kasm_vnc" {
  agent_id     = var.agent_id
  slug         = var.app_slug
  display_name = "kasmVNC"
  url          = "http://127.0.0.1:${var.port}"
  icon         = "/icon/kasmvnc.svg"
  subdomain    = var.subdomain
}
