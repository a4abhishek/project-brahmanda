# 1Password Provider Configuration
provider "onepassword" { 
}

data "onepassword_item" "proxmox_credentials" {
  vault = "Project-Brahmanda"
  title = "Proxmox-samsara-iac"
}

data "onepassword_item" "upstash" {
  vault = "Project-Brahmanda"
  title = "Upstash-Sanchay-Token"
}

locals {
  # Extract Upstash credentials by searching all fields in all sections
  upstash_fields = flatten([
    for s in data.onepassword_item.upstash.section : s.field
  ])
  
  upstash_url   = one([for f in local.upstash_fields : f.value if f.label == "UPSTASH_REDIS_REST_URL"])
  upstash_token = one([for f in local.upstash_fields : f.value if f.label == "UPSTASH_REDIS_REST_TOKEN"])
}

# Fetch the current lock state from Upstash
data "http" "lock_check" {
  url = "${local.upstash_url}/GET/brahmanda_lock_brahmaloka"
  request_headers = {
    Authorization = "Bearer ${local.upstash_token}"
  }
}

# Lock Enforcement Guard
resource "null_resource" "lock_guard" {
  lifecycle {
    precondition {
      # The .result field in Upstash response contains the value (Job ID)
      condition     = jsondecode(data.http.lock_check.response_body).result == var.brahmanda_job_id
      error_message = "❌ FATAL: Deployment Lock mismatch! The lock in Redis does not match 'var.brahmanda_job_id'. You must run this via 'make brahmaloka'. Current holder: ${jsondecode(data.http.lock_check.response_body).result}"
    }
  }
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
