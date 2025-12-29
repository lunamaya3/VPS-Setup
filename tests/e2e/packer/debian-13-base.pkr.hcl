# Packer template for Debian 13 base image optimized for KVM testing

packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "debian_version" {
  type    = string
  default = "13.2.0"
}

variable "debian_codename" {
  type    = string
  default = "trixie"
}

variable "output_directory" {
  type    = string
  default = "/tmp/packer-output"
}

variable "vm_name" {
  type    = string
  default = "debian-13-base"
}

variable "disk_size" {
  type    = string
  default = "25G"
}

variable "memory" {
  type    = string
  default = "2048"
}

variable "cpus" {
  type    = string
  default = "2"
}

variable "ssh_username" {
  type    = string
  default = "testuser"
}

variable "ssh_password" {
  type    = string
  default = "testpass"
  sensitive = true
}

source "qemu" "debian13" {
  # VM configuration
  vm_name              = var.vm_name
  output_directory     = var.output_directory
  
  # ISO and boot configuration
  iso_url              = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-${var.debian_version}-amd64-netinst.iso"
  iso_checksum         = "sha256:677c4d57aa034dc192b5191870141057574c1b05df2b9569c0ee08aa4e32125d"
  
  # Disk configuration optimized for KVM
  disk_size            = var.disk_size
  disk_interface       = "virtio"
  format               = "qcow2"
  disk_compression     = true
  
  # CPU and memory
  cpus                 = var.cpus
  memory               = var.memory
  
  # Network configuration
  net_device           = "virtio-net"
  
  # Accelerator and display
  accelerator          = "kvm"
  headless             = true
  vnc_bind_address     = "127.0.0.1"
  vnc_port_min         = 5900
  vnc_port_max         = 5999
  
  # SSH configuration for provisioning
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_timeout          = "20m"
  ssh_wait_timeout     = "20m"
  
  # Boot command for automated installation
  boot_wait            = "5s"
  boot_command = [
    "<esc><wait>",
    "auto <wait>",
    "console-setup/ask_detect=false <wait>",
    "console-keymaps-at/keymap=us <wait>",
    "debconf/frontend=noninteractive <wait>",
    "debian-installer=en_US.UTF-8 <wait>",
    "fb=false <wait>",
    "install <wait>",
    "kbd-chooser/method=us <wait>",
    "keyboard-configuration/xkb-keymap=us <wait>",
    "locale=en_US.UTF-8 <wait>",
    "netcfg/get_hostname=${var.vm_name} <wait>",
    "netcfg/get_domain=local <wait>",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <wait>",
    "<enter><wait>"
  ]
  
  # HTTP server for preseed file
  http_directory       = "."
  http_port_min        = 8000
  http_port_max        = 8100
  
  # Shutdown command
  shutdown_command     = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  shutdown_timeout     = "10m"
}

build {
  sources = ["source.qemu.debian13"]
  
  # Wait for system to be ready
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = [
      "echo 'Waiting for system to be ready...'",
      "sudo systemctl is-system-running --wait || true",
      "sleep 10"
    ]
  }
  
  # Install cloud-init and essential packages
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = [
      "echo 'Installing cloud-init and essential packages...'",
      "sudo apt-get update",
      "sudo apt-get install -y cloud-init cloud-utils cloud-guest-utils",
      "sudo apt-get install -y qemu-guest-agent",
      "sudo apt-get install -y curl wget git build-essential",
      "sudo apt-get clean"
    ]
  }
  
  # Configure cloud-init for NoCloud datasource and enable systemd-networkd
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = [
      "echo 'Configuring cloud-init...'",
      "sudo tee /etc/cloud/cloud.cfg.d/99_packer.cfg <<EOF",
      "datasource_list: [ NoCloud, None ]",
      "datasource:",
      "  NoCloud:",
      "    fs_label: cidata",
      "EOF",
      "",
      "echo 'Configuring network with /etc/network/interfaces...'",
      "sudo tee /etc/network/interfaces <<EOF",
      "# Network configuration for DHCP",
      "auto lo",
      "iface lo inet loopback",
      "",
      "# Auto-configure first available interface with DHCP",
      "auto ens3",
      "allow-hotplug ens3",
      "iface ens3 inet dhcp",
      "",
      "auto eth0",
      "allow-hotplug eth0",
      "iface eth0 inet dhcp",
      "",
      "auto enp1s0",
      "allow-hotplug enp1s0", 
      "iface enp1s0 inet dhcp",
      "EOF",
      "",
      "echo 'Starting network interfaces immediately...'",
      "sudo ifup ens3 || sudo ifup eth0 || sudo ifup enp1s0 || true",
      "",
      "echo 'Disabling cloud-init network management...'",
      "sudo mkdir -p /etc/cloud/cloud.cfg.d",
      "sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<EOF",
      "network:",
      "  config: disabled",
      "EOF",
      "",
      "echo 'Enabling networking service...'",
      "sudo systemctl enable networking",
      "sudo systemctl disable systemd-networkd || true",
      "",
      "echo 'Enabling cloud-init services...'",
      "sudo systemctl enable cloud-init.service || true",
      "sudo systemctl enable cloud-init-local.service || true", 
      "sudo systemctl enable cloud-config.service || true",
      "sudo systemctl enable cloud-final.service || true",
      "",
      "echo 'Cleaning cloud-init for first boot...'",
      "sudo cloud-init clean --logs --seed || true"
    ]
  }
  
  # Verify qemu-guest-agent is installed
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = [
      "echo 'Verifying QEMU guest agent...'",
      "dpkg -l | grep qemu-guest-agent || echo 'qemu-guest-agent is installed'",
      "sleep 2"
    ]
  }
  
  # Clean up for smaller image
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = [
      "echo 'Cleaning up for smaller image...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo find /var/log -type f -exec truncate -s 0 {} \\;",
      "sudo rm -f /home/${var.ssh_username}/.ssh/authorized_keys",
      "sudo rm -f /root/.ssh/authorized_keys",
      "sudo rm -f /home/${var.ssh_username}/.bash_history",
      "sudo rm -f /root/.bash_history"
    ]
  }
  
  # Quick sync for image finalization
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = [
      "echo 'Finalizing image...'",
      "sync",
      "echo 'Image finalized successfully'"
    ]
  }
  
  post-processor "shell-local" {
    inline = [
      "echo 'Base image created successfully: ${var.output_directory}/${var.vm_name}'",
      "qemu-img info ${var.output_directory}/${var.vm_name}"
    ]
  }
}
