# 1Password Provider Configuration
provider "onepassword" {
  # We'll use OP_SERVICE_ACCOUNT_TOKEN environment variable for authentication
  # This will ensure accessability of 1Password secrets for Terraform as well as op CLI.
}

data "onepassword_item" "proxmox_credentials" {
  vault = "Project-Brahmanda"
  title = "Proxmox-samsara-iac"
}

# Proxmox Provider Configuration
provider "proxmox" {
  pm_api_url      = "${var.proxmox_endpoint}/api2/json"
  pm_user         = data.onepassword_item.proxmox_credentials.username
  pm_password     = data.onepassword_item.proxmox_credentials.password
  pm_tls_insecure = true
}


# --- Vyom Cluster Resources ---                                                                                                                                  

# 1. K3s Control-Plane Node                                                                                                                                       
resource "proxmox_vm_qemu" "control_plane" {
  # VM General Settings                                                                                                                                           
  name        = "vyom-control-plane-1"
  target_node = var.proxmox_node_1
  clone       = var.template_name

  # VM Resources                                                                                                                                                  
  cores   = 4
  sockets = 1
  memory  = 8192 # 8 GB                                                                                                                                           

  # VM OS and Boot Settings                                                                                                                                       
  os_type = "cloud-init"
  agent   = 1 # Enable QEMU Guest Agent                                                                                                                           

  # Network Interface                                                                                                                                             
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Cloud-Init Configuration                                                                                                                                      
  ipconfig0 = "ip=192.168.68.210/20,gw=192.168.68.1"
  # Note: The SSH keys are already baked into the template, so we don't need to specify them here.                                                                

  # Disk Configuration                                                                                                                                            
  scsihw = "virtio-scsi-pci"
  disk {
    type    = "scsi"
    storage = "local-lvm"
    size    = "64G"
  }
}

# 2. K3s Worker Nodes                                                                                                                                             
resource "proxmox_vm_qemu" "worker" {
  count = 2

  # VM General Settings                                                                                                                                           
  name        = "vyom-worker-${count.index + 1}"
  target_node = var.proxmox_node_1
  clone       = var.template_name

  # VM Resources                                                                                                                                                  
  cores   = 4
  sockets = 1
  memory  = 16384 # 16 GB                                                                                                                                         

  # VM OS and Boot Settings                                                                                                                                       
  os_type = "cloud-init"
  agent   = 1 # Enable QEMU Guest Agent                                                                                                                           

  # Network Interface                                                                                                                                             
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Cloud-Init Configuration (assign IPs sequentially)                                                                                                            
  ipconfig0 = "ip=192.168.68.21${count.index + 1}/20,gw=192.168.68.1"

  # Disk Configuration                                                                                                                                            
  scsihw = "virtio-scsi-pci"
  disk {
    type    = "scsi"
    storage = "local-lvm"
    size    = "128G"
  }
}
