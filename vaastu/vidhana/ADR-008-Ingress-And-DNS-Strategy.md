# **ADR-008: Ingress, DNS & The Gateway Strategy**

**Date:** 2026-02-02<br>
**Status:** Accepted<br>
**Enhances:** [ADR-001-Homelab-Architecture.md](./ADR-001-Homelab-Architecture.md)<br>
**Related Learning:** [Terraform-Persistent-State-Migration.md](../anvaya/terraform/Terraform-Persistent-State-Migration.md)

## **1. Context**

Project Brahmanda hosts services (e.g., ArgoCD, Personal Website, Games) within the private, on-premise **Vyom** cluster. These services need to be accessible from the public internet securely, reliably, and cost-effectively.

### **The Constraints**
1.  **Dynamic Home IP:** The physical cluster sits behind a residential ISP connection with a dynamic IP and NAT. Direct port forwarding is brittle (IP changes) and insecure (exposes home network).
2.  **Aparigraha (Frugality):** We reject recurring costs for dedicated Cloud Load Balancers ($15-20/mo) or Commercial VPN Gateways. We must use what we have: the existing **Kshitiz** (Lightsail) instance ($3.50/mo).
3.  **Asanga (Transience):** The Kshitiz Gateway is ephemeral. It can be destroyed and recreated at will. However, the **DNS Records** pointing to it must remain stable ("Achala") to prevent downtime.
4.  **Identity Separation:** Internal infrastructure services (ArgoCD, Grafana) should be namespace-isolated from public-facing "Vanity" services (Portfolio, Games).

## **2. Decision**

We will implement a **"Gateway-Bridge" Architecture** anchored by a **Persistent DNS Layer**.

### **A. DNS Management (The Achala Layer)**
*   **Provider:** **Hostinger**.
*   **Mechanism:** Managed via **Terraform** in the specialized `persistence` module.
*   **Strategy:**
    *   **Root Wildcard (`*`)**: Points to Kshitiz. Handles vanity domains (`games.abhishek-kashyap.com`).
    *   **Brahmanda Wildcard (`*.brahmanda`)**: Points to Kshitiz. Handles infrastructure (`argocd.brahmanda...`).
*   **Rationale:** Decoupling DNS from the ephemeral Kshitiz Terraform stack ensures records persist even during a "Pralaya" (destruction) of the compute layer. Hostinger is chosen for its API support and existing domain ownership.

### **B. The Gateway (Kshitiz as the Bridge)**
*   **Role:** Reverse Proxy and Edge SSL Terminator.
*   **Software:** **Caddy Web Server**.
*   **Why Caddy?**
    *   **Automatic HTTPS:** It handles Let's Encrypt challenges automatically for all configured domains.
    *   **Simplicity:** A single binary with a readable configuration (`Caddyfile`), adhering to *Aparigraha*.
*   **Traffic Flow:**
    1.  Terminates Public SSL (443).
    2.  Decrypts traffic.
    3.  Forwards traffic into the **Nebula Mesh** tunnel (`tun0`).

### **C. The Cluster Ingress (Traefik on Vyom)**
*   **Role:** Internal routing within the Kubernetes cluster.
*   **Software:** **Traefik** (K3s default).
*   **Binding:** Listens on the node's **Nebula IP** (`10.42.x.x`) and **LAN IP**.
*   **Protocol:** HTTP (Port 80).
    *   *Security Note:* Traffic between Kshitiz and Vyom is encrypted by Nebula (Noise Protocol). Therefore, we can safely offload SSL at Kshitiz and speak HTTP over the mesh, reducing double-encryption overhead.

## **3. Detailed Implementation**

### **A. Terraform Persistence (DNS)**

Located in `samsara/terraform/persistence/main.tf`. This stack is run *before* Kshitiz provisioning.

```hcl
# 1. The Anchor IP (AWS Lightsail Static IP)
resource "aws_lightsail_static_ip" "kshitiz" {
  name = "kshitiz-static-ip"
}

# 2. Infrastructure Wildcard (*.brahmanda.abhishek-kashyap.com)
resource "hostinger_dns_record" "brahmanda_wildcard" {
  zone  = var.domain_name
  name  = "*.brahmanda"
  type  = "A"
  value = aws_lightsail_static_ip.kshitiz.ip_address
  ttl   = 14400
}

# 3. Root Wildcard (*.abhishek-kashyap.com)
resource "hostinger_dns_record" "root_wildcard" {
  zone  = var.domain_name
  name  = "*"
  type  = "A"
  value = aws_lightsail_static_ip.kshitiz.ip_address
  ttl   = 14400
}
```

### **B. Caddy Configuration (The Gateway)**

Managed by Ansible in `samsara/ansible/playbooks/01-bootstrap-kshitiz.yml`.

**The `Caddyfile` Strategy:**

```caddyfile
{
    # Global Options
    email avskksyp@gmail.com
}

# ---------------------------------------------------------------------
# 1. Vanity Domains (Public Portfolio, Games)
# ---------------------------------------------------------------------
# Matches: abhishek-kashyap.com, games.abhishek-kashyap.com
abhishek-kashyap.com, *.abhishek-kashyap.com {
    # Proxy to the Vyom Ingress Service IP (Traefik LoadBalancer)
    # The Nebula Mesh IP of the K3s Master/LoadBalancer Node
    reverse_proxy 10.42.1.201:80
}

# ---------------------------------------------------------------------
# 2. Infrastructure Domains (ArgoCD, Grafana)
# ---------------------------------------------------------------------
# Matches: argocd.brahmanda.abhishek-kashyap.com
*.brahmanda.abhishek-kashyap.com {
    reverse_proxy 10.42.1.201:80
}
```

### **C. Kubernetes Ingress (The Destination)**

Managed via GitOps (ArgoCD) in `sankalpa/`.

**Example: Exposing ArgoCD**

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  entryPoints:
    - web # Traefik Port 80
  routes:
    - match: Host(`argocd.brahmanda.abhishek-kashyap.com`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
```

## **4. The Packet's Journey (Traffic Flow)**

Let's trace a user accessing `https://games.abhishek-kashyap.com`:

1.  **Resolution:**
    *   User queries DNS.
    *   Hostinger (managed by Terraform) returns `18.140.145.253` (Kshitiz Static IP).
2.  **Edge Entry:**
    *   User connects to Kshitiz on TCP/443.
    *   **Caddy** intercepts. It checks its certificate cache. If missing, it pauses, negotiates with Let's Encrypt via HTTP-01/DNS-01, obtains a cert, and resumes.
    *   SSL Handshake completes. Traffic is now decrypted at the edge.
3.  **The Tunnel:**
    *   Caddy matches `*.abhishek-kashyap.com`.
    *   Caddy forwards request to `10.42.1.201:80`.
    *   OS routes `10.42.x.x` into `tun0` (Nebula Interface).
    *   Nebula encrypts the packet (Noise Protocol) and UDP-encapsulates it.
    *   Packet flies over the public internet to your Home Router.
4.  **The Cluster:**
    *   Home Router forwards UDP/4242 to Vyom Node.
    *   Vyom Node (Nebula) decapsulates and decrypts.
    *   Packet arrives at `10.42.1.201` (Traefik) on Port 80.
    *   Traefik inspects `Host: games.abhishek-kashyap.com`.
    *   Traefik routes to the `tic-tac-toe` Pod service.
5.  **Response:**
    *   The path reverses. The user sees a secure, fast website, unaware it's served from a NUC in your living room.

## **5. Consequences**

### **Positive**
*   ✅ **Universal Namespace:** `*.brahmanda` provides a clean, consistent namespace for all internal tools.
*   ✅ **Vanity Support:** Root wildcard (`*`) allows effortless deployment of public apps (`games`, `blog`) without touching Terraform or DNS. Just add a K8s Ingress.
*   ✅ **Zero-Trust Edge:** The Kshitiz gateway has no application logic/data. If compromised, it has no keys to the cluster (only network access, controlled by Nebula firewall rules).
*   ✅ **Certificate Automation:** No manual cert management. Caddy handles everything.

### **Negative**
*   ⚠️ **Latency:** The "Double Hop" (User -> AWS -> Home) adds ~20-50ms latency compared to direct exposure. Accepted for security.
*   ⚠️ **Bandwidth:** Limited by Lightsail's 1TB/month cap (sufficient for homelab).
*   ⚠️ **Single Point of Failure:** Kshitiz is the choke point. If AWS ap-southeast-1 goes down, external access is lost (though internal VLAN access works).