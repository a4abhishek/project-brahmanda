# 1Password Provider Configuration
provider "onepassword" {
}

# Proxmox Provider Configuration
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username  = data.onepassword_item.proxmox_credentials.username
  password  = data.onepassword_item.proxmox_credentials.password
  insecure  = true
}

data "onepassword_item" "proxmox_credentials" {
  vault = "Project-Brahmanda"
  title = "Proxmox-samsara-iac"
}

# --- Vyom Cluster Resources ---

# 1. K3s Control-Plane Node
resource "proxmox_virtual_environment_vm" "control_plane" {
  name      = "vyom-control-plane-1"
  node_name = var.proxmox_node_1
  vm_id     = local.nodes.control_plane.ip_end

  agent {
    enabled = true
  }

  clone {
    vm_id = local.template_vm_id
    full  = true
  }

  cpu {
    cores = local.nodes.control_plane.cores
  }

  memory {
    dedicated = local.nodes.control_plane.memory
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    interface    = "virtio0"
    datastore_id = "local-lvm"
    size         = local.nodes.control_plane.disk
    iothread     = true
    discard      = "on"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.cluster_ip_base}.${local.nodes.control_plane.ip_end}/${local.network_cidr}"
        gateway = local.network_gateway
      }
    }
  }
}

# 2. K3s Worker Nodes
resource "proxmox_virtual_environment_vm" "worker" {
  count     = local.nodes.worker.count
  name      = "vyom-worker-${count.index + 1}"
  node_name = var.proxmox_node_1
  vm_id     = local.nodes.worker.ip_end + count.index

  agent {
    enabled = true
  }

  clone {
    vm_id = local.template_vm_id
    full  = true
  }

  cpu {
    cores = local.nodes.worker.cores
  }

  memory {
    dedicated = local.nodes.worker.memory
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "local-lvm"
    size         = local.nodes.worker.disk
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.cluster_ip_base}.${local.nodes.worker.ip_end + count.index}/${local.network_cidr}"
        gateway = local.network_gateway
      }
    }
  }
}
