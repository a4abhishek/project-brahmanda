# **ADR-008: Ingress, DNS & The Gateway Strategy**

**Created:** 2026-02-02<br>
**Last Updated:** 2026-03-30<br>
**Status:** Accepted<br>
**Enhances:** [ADR-001-Homelab-Architecture.md](./ADR-001-Homelab-Architecture.md), [ADR-004-Security-Hardening.md](./ADR-004-Security-Hardening.md)<br>
**Related Learning:** [Terraform-Persistent-State-Migration.md](../anvaya/terraform/Terraform-Persistent-State-Migration.md)<br>
**Post-Mortems:** [RCA-013-ArgoCD-External-Access-Configuration.md](../vivechana/RCA-013-ArgoCD-External-Access-Configuration.md)

## **1. Context**

Project Brahmanda hosts services (e.g., ArgoCD, Personal Website, Games) within the private, on-premise **Vyom** cluster. These services need to be accessible from the public internet securely, reliably, and cost-effectively.

### **The Constraints**

1. **Dynamic Home IP:** The physical cluster sits behind a residential ISP connection with a dynamic IP and NAT. Direct port forwarding is brittle (IP changes) and insecure (exposes home network).
2. **Aparigraha (Frugality):** We reject recurring costs for dedicated Cloud Load Balancers ($15-20/mo) or Commercial VPN Gateways. We must use what we have: the existing **Kshitiz** (Lightsail) instance ($3.50/mo).
3. **Asanga (Transience):** The Kshitiz Gateway is ephemeral. It can be destroyed and recreated at will. However, the **DNS Records** pointing to it must remain stable ("Achala") to prevent downtime.
4. **Identity Separation:** Internal infrastructure services (ArgoCD, Grafana) should be namespace-isolated from public-facing "Vanity" services (Portfolio, Games).

## **2. Decision**

We will implement a **"Gateway-Bridge" Architecture** anchored by a **Persistent DNS Layer**.

### **A. DNS Management (The Achala Layer)**

* **Provider:** **Hostinger**.
* **Mechanism:** Managed via **Terraform** in the specialized `persistence` module.
* **Strategy:**
  * **Root Wildcard (`*`)**: Points to Kshitiz. Handles vanity domains (`games.abhishek-kashyap.com`).
  * **Brahmanda Wildcard (`*.brahmanda`)**: Points to Kshitiz. Handles infrastructure (`argocd.brahmanda...`).
* **Rationale:** Decoupling DNS from the ephemeral Kshitiz Terraform stack ensures records persist even during a "Pralaya" (destruction) of the compute layer. Hostinger is chosen for its API support and existing domain ownership.

### **B. The Gateway (Kshitiz as the Bridge)**

* **Role:** Reverse Proxy and Edge SSL Terminator.
* **Software:** **Caddy Web Server**.
* **Why Caddy?**
  * **Automatic HTTPS:** It handles Let's Encrypt challenges automatically for all configured domains.
  * **Simplicity:** A single binary with a readable configuration (`Caddyfile`), adhering to *Aparigraha*.
* **Traffic Flow:**
    1. Terminates Public SSL (443).
    2. Decrypts traffic.
    3. Forwards traffic into the **Nebula Mesh** tunnel (`tun0`).

### **C. The Cluster Ingress (Traefik on Vyom)**

* **Role:** Internal routing within the Kubernetes cluster.
* **Software:** **Traefik** (K3s default).
* **Binding:** Listens on the node's **Nebula IP** (`10.100.x.x`) and **LAN IP**.
* **Protocol:** HTTP (Port 80).
  * *Security Note:* Traffic between Kshitiz and Vyom is encrypted by Nebula (Noise Protocol). Therefore, we can safely offload SSL at Kshitiz and speak HTTP over the mesh, reducing double-encryption overhead.
  * *Routing Note:* Traefik performs routing by matching the HTTP `Host` header. Caddy **must** forward plain HTTP (not HTTPS-to-IP), otherwise Traefik receives the IP literal as TLS SNI instead of the hostname, and no router matches. See RCA-013 §3.4.

### **D. ArgoCD Insecure Mode**

ArgoCD server **must** run with `server.insecure: "true"` in `argocd-cmd-params-cm`. This is the official ArgoCD-recommended configuration for all setups where TLS is terminated by an upstream ingress controller.

* This does **not** disable authentication — JWT is still required for all API calls.
* Component-to-component TLS within ArgoCD (server ↔ repo-server ↔ app-controller) is maintained regardless.
* The HTTP segment (Traefik → ArgoCD, port 8080) is private to the cluster LAN.

See the Security section below for mitigations applied to protect the HTTP endpoint within the cluster.

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

> ⚠️ **Wildcard cert constraint:** Wildcard hostnames (`*.brahmanda.*`) require DNS-01 ACME challenge, which needs a DNS provider API plugin. The standard Caddy apt package does not include one. **Use explicit hostnames** for HTTP-01 (standard Caddy). Future path to wildcards: build with `xcaddy` + `caddy-dns/hostinger`.

```caddyfile
{
    email {{ acme_email }}
}

# --- Infrastructure Services (brahmanda.* namespace) ---
# Add one block per new infra service. HTTP-01 cert issued per hostname.
argocd.brahmanda.{{ domain_name }} {
  # ADR-008: plain HTTP to Traefik over Nebula (Nebula handles encryption).
  # Must NOT be https:// — that would send IP as TLS SNI, breaking Traefik routing.
  reverse_proxy http://10.100.1.210:80
}

# --- Public / Vanity Services ---
{{ domain_name }}, www.{{ domain_name }} {
  reverse_proxy http://10.100.1.210:80
}
```

> Note: `10.100.1.210` is the Nebula IP of `vyom-control-plane-1` (migrated from `10.42.1.210` — see RCA-012). The OS routes `10.100.*` into `nebula1`, where Nebula encrypts before sending to Vyom.

### **C. Kubernetes Ingress (The Destination)**

Managed via Ansible template `samsara/ansible/playbooks/templates/argocd-ingress.yaml.j2`.

> **Entrypoint must be `web` (port 80), not `websecure` (port 443).** Traffic from Caddy arrives on Traefik's HTTP entrypoint. Using `websecure` was the original bug (see RCA-013 §3.5).

**ArgoCD Ingress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: argocd.brahmanda.{{ domain_name }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
```

## **4. The Packet's Journey (Traffic Flow)**

Let's trace a user accessing `https://argocd.brahmanda.abhishek-kashyap.com`:

1. **Resolution:**
    * User queries DNS.
    * Hostinger (managed by Terraform `persistence` module) returns `18.140.145.253` (Kshitiz Static IP).
2. **Edge Entry:**
    * User connects to Kshitiz on TCP/443.
    * **Caddy** intercepts. It checks its certificate cache. If missing, it initiates Let's Encrypt HTTP-01 challenge (requires TCP/80 open on Lightsail firewall), obtains a cert, and resumes.
    * SSL Handshake completes. Traffic is now decrypted at the edge.
3. **The Tunnel:**
    * Caddy matches the `argocd.brahmanda.abhishek-kashyap.com` block.
    * Caddy forwards plain HTTP request to `http://10.100.1.210:80` — preserving the original `Host` header.
    * OS routes `10.100.x.x` into `nebula1` (Nebula Interface). Nebula encrypts (Noise Protocol) and UDP-encapsulates.
    * Packet flies over the public internet to the home router.
4. **The Cluster:**
    * Home Router forwards UDP/4242 to Vyom Node.
    * Vyom Node (Nebula) decapsulates and decrypts. Plain HTTP packet arrives at `10.100.1.210:80`.
    * **Traefik** (`web` entrypoint) inspects the HTTP `Host` header: `argocd.brahmanda.abhishek-kashyap.com`.
    * Traefik matches the `argocd-server` Ingress rule and routes to `argocd-server.argocd.svc.cluster.local:80`.
    * **ArgoCD** (running in insecure mode) serves the response on port 8080.
5. **Response:**
    * The path reverses. The user sees a secure HTTPS UI, unaware it's served from a NUC in your living room.

## **5. Security Hardening (The Chakravyuha Layer)**

This section documents the security measures applied on top of the base ingress architecture to satisfy the Chakravyuha principle (ADR-004).

### **5.1 ArgoCD: Insecure Mode is Safe Here**

`server.insecure: "true"` is the **official ArgoCD recommendation** for all external-TLS-termination setups. It only removes ArgoCD's own TLS on port 8080 — it does not disable authentication.

**What remains in place:**
* JWT authentication required for every API call (24-hour expiry, revoked on password change)
* Component-to-component TLS: `argocd-server ↔ argocd-repo-server ↔ argocd-application-controller`
* External TLS provided by Caddy (Let's Encrypt)
* Tunnel encryption by Nebula (Noise Protocol)

**Full encryption map:**

| Segment | Encryption | Notes |
|---|---|---|
| User → Kshitiz | TLS 1.2+ (Let's Encrypt) | Caddy terminates |
| Kshitiz → Vyom (10.100.x.x) | Noise Protocol (Nebula) | Always encrypted |
| Traefik → ArgoCD (cluster-internal) | None | Private LAN only |
| ArgoCD internals | TLS (mutual) | Maintained regardless of insecure flag |

### **5.2 Anonymous Access: Explicitly Disabled**

ArgoCD's `argocd-cm` ConfigMap is patched during bootstrap with:

```yaml
users.anonymous.enabled: "false"
```

This is ArgoCD's default, but it is set explicitly in `04-bootstrap-maya.yml` to survive upstream `install.yaml` resets or ConfigMap drift.

### **5.3 NetworkPolicy: Intent Declared, Enforcement Pending**

A `NetworkPolicy` restricting access to `argocd-server` port 8080 is deployed via `argocd-network-policy.yaml.j2`:

```yaml
# Allow only: kube-system namespace (Traefik) + argocd namespace (internal components)
podSelector:
  matchLabels:
    app.kubernetes.io/name: argocd-server
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
    ports:
      - port: 8080
  - from:
      - podSelector: {}  # all pods in argocd namespace
```

> ⚠️ **Enforcement gap:** K3s with the default **Flannel CNI does not enforce NetworkPolicies**. This manifest declares correct intent and will enforce automatically once a NetworkPolicy controller is deployed. Upgrade path (all documented in `group_vars/vyom/vars.yml`):
>
> * **Option A (recommended):** Switch to Calico CNI — replace Flannel at cluster rebuild.
> * **Option B:** Switch to Cilium CNI — eBPF-based, better observability.
> * **Option C (no rebuild):** Deploy kube-router policy-only DaemonSet alongside Flannel (`--run-router=false --run-service-proxy=false --run-firewall=true`).

### **5.4 Lightsail Firewall (Terraform-managed)**

All firewall rules are in `samsara/terraform/kshitiz/main.tf`:

| Port | Protocol | Source | Purpose |
|---|---|---|---|
| `var.ssh_port` | TCP | `var.ssh_allowed_cidrs` | SSH (restricted CIDRs) |
| 4242 | UDP | `0.0.0.0/0` | Nebula Lighthouse |
| 80 | TCP | `0.0.0.0/0` | HTTP-01 ACME + HTTP→HTTPS redirect |
| 443 | TCP | `0.0.0.0/0` | HTTPS public ingress |

> Port 80 is required for Let's Encrypt HTTP-01 ACME challenge even on HTTPS-only services. Without it, certificate issuance fails and port 443 also stops working.

---

## **6. Consequences**

### **Positive**

* ✅ **Universal Namespace:** `*.brahmanda` DNS provides a clean, consistent namespace for all internal tools.
* ✅ **Vanity Support:** Root wildcard DNS (`*`) allows effortless deployment of public apps (`games`, `blog`) without touching Terraform or DNS. Just add a K8s Ingress and a Caddyfile block.
* ✅ **Zero-Trust Edge:** The Kshitiz gateway has no application logic/data. If compromised, the Nebula firewall rules still limit what it can reach inside the cluster.
* ✅ **Certificate Automation:** No manual cert management. Caddy handles everything per hostname.
* ✅ **No Double-TLS Overhead:** Caddy terminates TLS at the edge; Nebula handles tunnel encryption. ArgoCD insecure mode avoids redundant TLS on the private LAN segment.

### **Negative / Known Constraints**

* ⚠️ **Latency:** The "Double Hop" (User → AWS → Home) adds ~20-50ms latency compared to direct exposure. Accepted for security.
* ⚠️ **No Wildcard Certs (currently):** Each new service requires an explicit Caddyfile block. Future fix: rebuild Caddy with `xcaddy` + `caddy-dns/hostinger`.
* ⚠️ **NetworkPolicy not enforced (currently):** Flannel CNI limitation. Mitigated by: no multi-tenant workloads, private LAN cluster, JWT auth still required. Upgrade path documented.
* ⚠️ **Single Point of Failure:** Kshitiz is the choke point. If AWS ap-southeast-1 goes down, external access is lost (though internal VLAN access works).
