# **ADR-008: Ingress, DNS & The Gateway Strategy**

**Date:** 2026-02-02<br>
**Status:** Accepted<br>
**Enhances:** [ADR-001-Homelab-Architecture.md](./ADR-001-Homelab-Architecture.md)<br>
**Related Learning:** [Terraform-Persistent-State-Migration.md](../anvaya/terraform/Terraform-Persistent-State-Migration.md)

## **1. Context**

Project Brahmanda hosts services (e.g., ArgoCD, Personal Website) within the private, on-premise **Vyom** cluster. These services need to be accessible from the public internet securely.

* **Constraint 1 (Dynamic IPs):** The home ISP IP is dynamic and behind NAT. Direct port forwarding is brittle and insecure.
* **Constraint 2 (Aparigraha):** We want to avoid recurring costs for dedicated Load Balancers or expensive VPN gateways.
* **Constraint 3 (Asanga):** The Gateway instance (Kshitiz) is transient and may be destroyed/recreated. The Public IP and DNS records must persist ("Achala") to avoid downtime or manual reconfiguration.

## **2. Decision**

We will implement a **Gateway-Bridge Pattern** using **Kshitiz** as the unified entry point.

1. **DNS Management:** **Hostinger**, managed via **Terraform (Persistence Layer)**.
    * **Rationale:** Decouples DNS from the ephemeral Kshitiz instance. Terraform ensures records always point to the static anchor IP.
2. **The Gateway (Kshitiz):** Acts as a **Reverse Proxy Bridge**.
    * **Software:** We can deploy something like **Caddy Web Server**.
    * **Role:** Terminates Public SSL (Let's Encrypt) and forwards traffic into the Nebula Mesh.
3. **The Bridge:** **Public Internet -> Kshitiz (443) -> Nebula Tunnel (tun0) -> Vyom Ingress (Traefik).**
    * **Rationale:** Allows us to expose private cluster services without exposing the cluster nodes directly.

## **3. Detailed Implementation**

### **A. DNS Architecture (The Achala Layer)**

The DNS records are managed in the `samsara/terraform/persistence` module to ensure they survive the `pralaya` (destruction) of the compute layers.

* **Provider:** `hostinger/hostinger`
* **Configuration:**

    ```hcl
    # samsara/terraform/persistence/main.tf
    resource "hostinger_dns_record" "root_a" {
      zone  = var.domain_name # abhishek-kashyap.com
      name  = "@"
      type  = "A"
      value = aws_lightsail_static_ip.kshitiz.ip_address
      ttl   = 14400
    }

        resource "hostinger_dns_record" "brahmanda_wildcard" {

          zone  = var.domain_name

          name  = "*.brahmanda" # e.g., argocd.brahmanda.abhishek-kashyap.com

          type  = "A"

          value = aws_lightsail_static_ip.kshitiz.ip_address

          ttl   = 14400

        }

    

        resource "hostinger_dns_record" "root_wildcard" {

          zone  = var.domain_name

          name  = "*" # e.g., games.abhishek-kashyap.com

          type  = "A"

          value = aws_lightsail_static_ip.kshitiz.ip_address

          ttl   = 14400

        }

        ```

    

    ### **B. The Gateway Configuration (Caddy on Kshitiz)**

    

    Kshitiz runs **Caddy** as a systemd service. Caddy automatically manages SSL certificates for the domains it serves.

    

    *   **Installation:** Handled by Ansible (`01-bootstrap-kshitiz.yml`).

    *   **Configuration (`Caddyfile`):**

        ```caddyfile

        {

            # Global Options

            email avskksyp@gmail.com

        }

    

        # 1. Root Domain -> Personal Website (hosted in Vyom)

        abhishek-kashyap.com {

            reverse_proxy 10.42.1.201:80 # Vyom Ingress Service IP

        }

    

        # 2. Infrastructure Subdomains -> Vyom Traefik Ingress

        *.brahmanda.abhishek-kashyap.com {

            reverse_proxy 10.42.1.201:80

            

            # TLS is terminated at Kshitiz. 

            # Traffic inside Nebula (10.42.x.x) is encrypted by Nebula itself.

            # We forward to HTTP port of Traefik to avoid double encryption overhead/complexity.

        }

    

        # 3. Vanity Subdomains (games, portfolio, etc.) -> Vyom Traefik Ingress

        *.abhishek-kashyap.com {

            reverse_proxy 10.42.1.201:80

        }

        ```

    

    ### **C. The Cluster Ingress (Traefik on Vyom)**

    

    Inside the Vyom cluster, K3s ships with **Traefik** as the Ingress Controller.

    

    *   Traefik listens on the node's Nebula IP (e.g., `10.42.1.201`).

    *   **IngressRoute CRD:**

        ```yaml

        apiVersion: traefik.containo.us/v1alpha1

        kind: IngressRoute

        metadata:

          name: argocd-server

          namespace: argocd

        spec:

          entryPoints:

            - web # Port 80

          routes:

            - match: Host(`argocd.brahmanda.abhishek-kashyap.com`)

              kind: Rule

              services:

                - name: argocd-server

                  port: 80

        ```

    

    ### **D. Traffic Flow (The Path of the Photon)**

    

    1.  **User** visits `https://argocd.brahmanda.abhishek-kashyap.com`.

    2.  **DNS** resolves to `18.140.145.253` (Kshitiz Static IP).

    3.  **Kshitiz (Caddy)**:

        *   Receives request on port 443.

        *   Terminates SSL (Valid Let's Encrypt Cert).

        *   Matches `*.brahmanda...` pattern.

        *   Proxies to `10.42.1.201:80` (Vyom Node).

    4.  **Nebula Mesh**:

        *   Encrypts packet.

        *   Routes through UDP hole-punch to Home Router.

        *   Delivers packet to Vyom Node.

    5.  **Vyom (Traefik)**:

        *   Receives request on port 80.

        *   Matches `Host` header.

        *   Routes to `argocd-server` Pod.

## **4. Consequences**

### **Positive**

* ✅ **Single Entry Point:** Reduced attack surface. Only Kshitiz 443/4242/22 are exposed.
* ✅ **Auto-SSL:** Caddy handles certificates automatically on the public edge. Internal services don't need public certs.
* ✅ **Resilience:** Kshitiz can be destroyed/recreated. As long as `persistence` state exists, DNS and IP remain valid. Caddy re-provisioning takes minutes.
* ✅ **Cost:** Zero. Uses existing Lightsail instance.

### **Negative**

* ⚠️ **Single Point of Failure:** If Kshitiz goes down, all external access breaks (though internal LAN access remains).
* ⚠️ **Double Hop:** Traffic goes Client -> AWS -> Home. Adds latency compared to direct port forwarding (but safer).
