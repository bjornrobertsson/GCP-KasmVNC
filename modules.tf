module "kasmvnc" {
  count               = data.coder_workspace.me.start_count
  workspace_owner     = data.coder_workspace_owner.me
  source              = "./modules/kasmvnc"
#  version             = "1.0.23"
  agent_id            = coder_agent.main.id
  desktop_environment = "xfce"
  debug               = var.debug
}
