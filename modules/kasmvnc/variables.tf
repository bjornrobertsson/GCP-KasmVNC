
variable "agent_id" {
  type        = string
  description = "The ID of a Coder agent."
}

variable "port" {
  type        = number
  description = "The port to run KasmVNC on."
  default     = 6080
}

variable "kasm_version" {
  type        = string
  description = "Version of KasmVNC to install."
  default     = "1.3.2"
}

variable "desktop_environment" {
  type        = string
  description = "Specifies the desktop environment of the workspace. This should be pre-installed on the workspace."

  validation {
    condition     = contains(["xfce", "kde", "gnome", "lxde", "lxqt"], var.desktop_environment)
    error_message = "Invalid desktop environment. Please specify a valid desktop environment."
  }
}

variable "subdomain" {
  type        = bool
  description = "Specifies if subdomain sharing is enabled on the Coder cluster"
  default     = false
}

variable "app_slug" {
  type        = string
  description = "Specifies the URL-reference to the KasmVNC application"
  default     = "kasm-vnc"
}

variable "workspace_owner" {
  description = "Used to obtain the access URL and protocol"
}

variable "debug" {

}