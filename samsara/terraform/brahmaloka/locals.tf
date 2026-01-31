locals {
  # --- Networking ---
  network_gateway = "192.168.68.1"
  network_cidr    = "20"
  cluster_ip_base = "192.168.68"
  dns_server      = "8.8.8.8"
  dns_search_domain = "brahmanda.local"

  # --- VM Configuration ---
  template_vm_id = 9000

  # --- Node Definitions ---
  # This map defines the resources for each node type in the cluster.
  nodes = {
    brahmaloka = {
      cores  = 4
      memory = 4096  # 4 GB
      disk   = 64    # GB
      ip_end = 240
    }
  }
}
