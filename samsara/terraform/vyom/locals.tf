locals {
  # --- Networking ---
  network_gateway = "192.168.68.1"
  network_cidr    = "20"
  cluster_ip_base = "192.168.68"

  # --- VM Configuration ---
  template_vm_id = 9000

  # --- Node Definitions ---
  # This map defines the resources for each node type in the cluster.
  nodes = {
    control_plane = {
      count  = 1
      cores  = 4
      memory = 8192  # 8 GB
      disk   = 64    # GB
      ip_end = 210
    },
    worker = {
      count  = 2
      cores  = 4
      memory = 16384 # 16 GB
      disk   = 128   # GB
      ip_end = 211
    }
  }
}
