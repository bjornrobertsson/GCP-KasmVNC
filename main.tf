terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 1.0.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.31.0"
    }
  }
}

provider "coder" {
}

variable "project_id" {
  description = "Which Google Compute Project should your workspace live in?"
}

variable "credential_file_path" {
  description = "Credential file"
}

variable "service_account" {
  description = "A Google Service or User Account running and owning the Coder deployment"
}

provider "google" {
  zone        = data.coder_parameter.zone.value
  project     = var.project_id
  credentials = file(var.credential_file_path)
}



locals {
  #vnc_url_path = format("/@%s/%s/apps/%s", data.coder_workspace_owner.me.name, data.coder_workspace.me.name, "tiger")

  # Ensure Coder username is a valid Linux username
  linux_user = lower(substr(data.coder_workspace_owner.me.name, 0, 32))
}
data "coder_parameter" "machine_type" {
  name        = "Instance Types"
  description = "What Instance type should your workspace use?"
  default     = "custom-4-16384"
  icon        = "/emojis/1f5a5.png"
  mutable     = true
  order       = 1
  option {
    name  = "custom-4-16384 (4 vCPU, 16 GiB Memory)"
    value = "custom-4-16384"
  }
  option {
    name  = "custom-8-32768 (8 vCPU, 32 GiB Memory)"
    value = "custom-8-32768"
  }
    option {
    name  = "a2-highgpu-1g (12 vCPU,6 core, 85 GB Memory)"
    value = "a2-highgpu-1g"
  }
  
}
data "coder_parameter" "zone" {
  name         = "Zone"
  display_name = "Zone"
  description  = "Which zone should your workspace live in?"
  type         = "string"
  icon         = "/emojis/1f30e.png"
  default      = "europe-west2-a"
  mutable      = false
  order        = 2
  option {
    name  = "Eu west2a"
    value = "europe-west2-a"
  }
}
data "coder_parameter" "gpu" {
  name        = "Machine Types"
  description = "Do you need GPU enabled or NON GPU workspace ?"
  default     = "no_gpu"
  icon        = "/emojis/1f5a5.png"
  mutable     = false
  order       = 3
  option {
    name  = "With GPU"
    value = "gpu"
  }
  option {
    name  = "Without GPU"
    value = "no_gpu"
  }
}
data "coder_parameter" "gpu_type" {
  name        = "GPU Types"
  description = "Which GPU should be part of your workspace?"
  default     = "nvidia-tesla-t4"
  icon        = "/emojis/1f5a5.png"
  mutable     = true
  order = 4
  option {
    name  = "Tesla-t4"
    value = "nvidia-tesla-t4"
  }
  option {
    name  = "Tesla-v100(Available only in Netherland's)"
    value = "nvidia-tesla-v100"
  }
  option {
    name  = "Tesla-a100(Available only in Netherland's)"
    value = "nvidia-tesla-a100"
  }
}

data "coder_workspace" "me" {
}
data "coder_workspace_owner" "me" {
} 
resource "google_compute_disk" "root" {
  name    = "coder-${lower(data.coder_workspace_owner.me.name)}-${data.coder_workspace.me.id}-root"
  type    = "pd-ssd"
  project = var.project_id
  zone    = data.coder_parameter.zone.value
  image = "debian-cloud/debian-12"
  size    = "10"
    labels = {
    name = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-root"
    vm_name = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-vm"
    coder_provisioned = "true"
    environment = "cdw-prod"
    usecase = "engineering"
    username = "${lower(data.coder_workspace_owner.me.name)}"
    templatename = "${data.coder_workspace.me.template_name}"
  }
}

resource "coder_agent" "main" {
  auth                   = "google-instance-identity"
  arch                   = "amd64"
  os                     = "linux"
  startup_script         = <<-EOT
    set -e

    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server --version 4.11.0
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat cpu"
  }
  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat mem"
  }
  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat disk --path $HOME"
  }
}

# code-server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=/home/${local.linux_user}"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "google_compute_instance" "dev" {
  zone         = data.coder_parameter.zone.value
  depends_on =[
  google_compute_disk.root
  ]
  #count        = data.coder_workspace.me.start_count
  name         = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-vm"
  machine_type = data.coder_parameter.machine_type.value
	  network_interface {
    subnetwork_project = var.project_id
	    subnetwork         = data.coder_parameter.zone.value == "europe-west2-a"? "projects/$PROJECT/regions/europe-west2/subnetworks/$SUBNET" : "$SUBNET"
	  }
  dynamic "guest_accelerator" {
    for_each = data.coder_parameter.gpu.value == "gpu" ? [data.coder_parameter.gpu_type.value] : []
    content {
      type  = guest_accelerator.value
      count = 1
    }
  }
  scheduling {
    on_host_maintenance = "TERMINATE"
  }
  boot_disk {
    auto_delete = false
    source      = google_compute_disk.root.self_link
  }
  labels = {
    name = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-vm"
    coder_provisioned = "true"
    environment = "prod"
    usecase = "engineering"
    username = "${lower(data.coder_workspace_owner.me.name)}"
    templatename = "${data.coder_workspace.me.template_name}"
  }
  service_account {
    email  = var.service_account
    scopes = ["cloud-platform"]
  }
  shielded_instance_config {
    enable_secure_boot  = true
  }
  metadata = {
    block-project-ssh-keys = true
  }
  
  # The startup script runs as root with no $HOME environment set up, so instead of directly
  # running the agent init script, create a user (with a homedir, default shell and sudo
  # permissions) and execute the init script as that user.
  metadata_startup_script = <<EOMETA
#!/bin/bash
set -eux

export DEBIAN_FRONTEND=noninteractive

echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
apt update
apt install -y docker docker.io libdatetime-perl xfce4 xfce4-goodies
#sudo groupadd -f docker

#linking gcp resolv.conf with ubuntu reslov.conf , to resolve the connection reset by peer issue 
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

# sed -i 's/^owner.*/owner = "${local.linux_user}"/' /etc/dcv/dcv.conf
# sed -i 's/^ubuntu:x:1000:1000.*/ubuntu:x:1000:1000:Ubuntu:\/home\/ubuntu:\/bin\/false/' /etc/passwd
# sudo sed -i 's/#license-file = ""/license-file = "<port>@<ip>"/g' /etc/dcv/dcv.conf
# sudo systemctl restart dcvserver
echo "tested"
logger "Passed dcv"

# Just in case, if you need this, the 'Google' method of adding the user to the appropriate group
# is not working.
#
## LINUX_USER="${local.linux_user}"
## sudo echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER
## sudo chmod 550 /etc/sudoers.d/$USER

if ! id -u "${local.linux_user}" >/dev/null 2>&1; then
  echo ${local.linux_user}
  useradd -m -s /bin/bash "${local.linux_user}"
  echo "${local.linux_user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"${local.linux_user}"
  cat /etc/passwd
  echo "tested"
fi
sudo usermod -aG docker "${local.linux_user}"
echo "added to docker group"

LINUX_USER="${local.linux_user}"

if [ ! -d "/home/$LINUX_USER/.vnc" ]; then
  mkdir -p /home/$LINUX_USER/.vnc
  chown $LINUX_USER:$LINUX_USER /home/$LINUX_USER/.vnc
fi

# echo "$LINUX_USER" | vncpasswd -f > /home/$LINUX_USER/.vnc/passwd
# chmod 600 /home/$LINUX_USER/.vnc/passwd
# chown $LINUX_USER:$LINUX_USER /home/$LINUX_USER/.vnc/passwd

# sudo -u $LINUX_USER vncserver :1 -geometry 1280x1024 -depth 24

# nohup /usr/share/novnc/utils/launch.sh --vnc localhost:5901 &

echo "${local.linux_user}:${local.linux_user}" | chpasswd

echo "node-test"

sudo mkdir -p "/home/${local.linux_user}"
#sudo cp /var/opt/node.sh /home/${local.linux_user}/node.sh
#cd /home/${local.linux_user}
#sudo chmod 777 node.sh

echo '${coder_agent.main.init_script}' > /tmp/init-script.sh
exec sudo -u "${local.linux_user}" sh -c '${coder_agent.main.init_script}'

# Install current Chrome browser:
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y  ./google-chrome-stable_current_amd64.deb && rm -f ./google-chrome-stable_current_amd64.deb

EOMETA
}


# Start the VM
resource "null_resource" "start" {
  count      = data.coder_workspace.me.transition == "start" ? 1 : 0
  depends_on = [google_compute_instance.dev]
  provisioner "local-exec" {
    #command = "gcloud compute instances start ${google_compute_instance.dev.name}"
    command = "gcloud compute instances start ${google_compute_instance.dev.name} --zone ${data.coder_parameter.zone.value}"
  }
}

# Stop the VM
resource "null_resource" "stop" {
  count      = data.coder_workspace.me.transition == "stop" ? 1 : 0
  depends_on = [google_compute_instance.dev]
  provisioner "local-exec" {
    #Use deallocate so the VM is not charged
    command = "gcloud compute instances stop ${google_compute_instance.dev.name} --zone ${data.coder_parameter.zone.value}"
  }
}


#Hide disk from metadata
resource "coder_metadata" "hide_google_compute_disk" {
  count = data.coder_workspace.me.start_count
  resource_id = google_compute_disk.root.id
  hide = true
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  daily_cost = 10
  resource_id = google_compute_instance.dev.id

  item {
    key   = "type"
    value = google_compute_instance.dev.machine_type
  }
  item {
    key   = "size"
    value = "${google_compute_disk.root.size} GiB"
  }
}
