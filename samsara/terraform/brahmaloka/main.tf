# 1Password Provider Configuration
provider "onepassword" { 
}

data "onepassword_item" "proxmox_credentials" {
  vault = "Project-Brahmanda"
  title = "Proxmox-samsara-iac"
}

# Proxmox Provider Configuration
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username  = data.onepassword_item.proxmox_credentials.username
  password  = data.onepassword_item.proxmox_credentials.password
  insecure  = true
}

# --- Brahmaloka Node Resources ---

resource "proxmox_virtual_environment_vm" "brahmaloka_node_1" {
  name      = "brahmaloka-node-1"
  node_name = var.proxmox_node_1
  vm_id     = local.nodes.brahmaloka.ip_end

  agent {
    enabled = true
  }

  clone {
    vm_id = local.template_vm_id
    full  = true
  }

  cpu {
    cores = local.nodes.brahmaloka.cores
  }

  memory {
    dedicated = local.nodes.brahmaloka.memory
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    size         = local.nodes.brahmaloka.disk
    iothread     = true
    discard      = "on"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.cluster_ip_base}.${local.nodes.brahmaloka.ip_end}/${local.network_cidr}"
        gateway = local.network_gateway
      }
    }
    dns {
      servers = [local.dns_server]
      domain = local.dns_search_domain
    }
    user_account {
      keys = [trimspace(file(var.ssh_public_key_path))]
    }
  }
}
