---
display_name: KasmVNC
description: A modern open source VNC server
icon: ../.icons/kasmvnc.svg
maintainer_github: coder
verified: true
tags: [helper, vnc, desktop]
---

# KasmVNC

Automatically install [KasmVNC](https://kasmweb.com/kasmvnc) in a workspace, and create an app to access it via the dashboard.
When using the modules in the raw format, comment out the 'version' line.
This instance adds path_vnc.html to redirect the VNC agent.

```tf
module "kasmvnc" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/modules/kasmvnc/coder"
#  version             = "1.0.23"
  agent_id            = coder_agent.example.id
  desktop_environment = "xfce"
}
```

> **Note:** This module only works on workspaces with a pre-installed desktop environment. As an example base image you can use `codercom/enterprise-desktop` image.
