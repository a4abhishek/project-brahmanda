# RCA-013: ArgoCD External Access — Multi-Layer Configuration Failures

- **Date of Incident:** 2026-03-29
- **Severity:** High (GitOps control plane inaccessible from internet)
- **Status:** Resolved
- **Components:** Caddy (Kshitiz), Traefik (Vyom/K3s), ArgoCD, AWS Lightsail Firewall, Nebula Mesh, Terraform, Ansible, GHCR (OCI Helm registry)

---

## 1. The Incident (Ghatana)

- **Summary:** After the Nebula subnet migration (RCA-012), the full access path from the public internet to ArgoCD was attempted for the first time. It failed at multiple layers in sequence — each fix exposing the next issue deeper in the stack.
- **Impact:** ArgoCD completely inaccessible via `https://argocd.brahmanda.abhishek-kashyap.com`.
- **Detection:** `curl https://argocd.brahmanda.abhishek-kashyap.com/` returned `ERR_CONNECTION_TIMED_OUT`.

---

## 2. The Timeline (Samaya-Sarni)

| # | Symptom | Root Cause | Fix Applied |
|---|---|---|---|
| 1 | `ERR_CONNECTION_TIMED_OUT` on port 80 and 443 | Port 80 missing from Lightsail firewall | Added port 80 in Terraform |
| 2 | `ERR_SSL_PROTOCOL_ERROR` on port 443 | Caddyfile used wildcard `*.brahmanda.*` which requires DNS-01 ACME (not available) | Switched to explicit hostnames |
| 3 | Caddy cert issued but `404 page not found` from Traefik | Caddyfile proxied to stale IP `10.42.1.210` (old Flannel range) | Updated to `10.100.1.210` (Nebula IP) |
| 4 | Still `404 page not found` | Caddy proxied via HTTPS to Traefik; Traefik uses SNI hostname matching and received the bare IP as SNI → no router matched | Switched Caddy to proxy over `http://` per ADR-008 |
| 5 | Still `404 page not found` | ArgoCD Ingress used `websecure` entrypoint + port 443; traffic was arriving on `web` (port 80) | Updated Ingress to `web` entrypoint + port 80 |
| 6 | `404` from within ArgoCD | ArgoCD server was not in insecure mode; it refused to serve HTTP on port 80 | Patched `argocd-cmd-params-cm` with `server.insecure: true` |
| 7 | ✅ UI accessible | — | — |
| 8 | ✅ `brahmanda-sutra` repo sync | Private repo — no Git credentials registered in ArgoCD | Added `brahmanda-sutra-repo` Secret in `04-bootstrap-maya.yml` |
| 9 | ✅ `brahmanda-sutra` synced | — | — |
| 10 | ⚠️ `portfolio` app: `400 name invalid` from GHCR | `repoURL: oci://ghcr.io/a4abhishek` — missing chart name segment | Fixed `repoURL` to `oci://ghcr.io/a4abhishek/portfolio` in `brahmanda-sutra` (later superseded — see below) |
| 11 | ⚠️ `portfolio` app: `401 unauthorized` from GHCR | ArgoCD credential Secret `url` did not match Application `repoURL` after `NormalizeGitURL()` — various forms tried (`oci://ghcr.io/...`, `https://ghcr.io`) all failed | Normalized both to bare host: Secret `url: ghcr.io`, Application `repoURL: ghcr.io`, full OCI path in `chart` field |
| 12 | ✅ `portfolio` app syncing, pod `CreateContainerError: no command specified` | Docker image and Helm chart pushed to same OCI tag (`ghcr.io/a4abhishek/portfolio:0.1.0`) — Helm push ran second and overwrote the Docker image | Changed workflow to push charts to `oci://ghcr.io/a4abhishek/charts`; chart path updated to `a4abhishek/charts/portfolio` |
| 13 | ⚠️ `portfolio` pod: `ImagePullBackOff` | `ghcr-secret` only existed in `argocd` namespace; pods in `apps` namespace could not use it | Added `apps` namespace to the `ghcr-secret` creation loop in `04-bootstrap-maya.yml` |
| 14 | ✅ Portfolio pod running | — | — |

---

## 3. The Root Causes (Mula Karana)

### 3.1 — Port 80 Missing from Lightsail Firewall

The Terraform resource `aws_lightsail_instance_public_ports` only opened UDP/4242 (Nebula) and TCP/443 (HTTPS). Port 80 was never added.

**Why this matters for HTTPS:** Caddy's default ACME challenge (HTTP-01) requires Let's Encrypt to reach `http://<domain>/.well-known/acme-challenge/<token>` on port 80. Without port 80, cert issuance fails entirely, which is why 443 also didn't work.

### 3.2 — Wildcard Cert Requires DNS-01 ACME

The Caddyfile used `*.brahmanda.{{ domain_name }}` — a wildcard hostname. Let's Encrypt will only issue wildcard certificates via DNS-01 challenge, which requires API access to the DNS provider (Hostinger). The standard Caddy apt package includes no DNS plugin.

**Why it was written this way:** The original author (pre-RCA-012) intended this as a convenient catch-all, without accounting for the ACME protocol constraint.

**Fix:** Explicit hostnames (`argocd.brahmanda.abhishek-kashyap.com`) allow HTTP-01. Adding a new service just requires a new explicit block in the Caddyfile.

> **Future path to wildcards:** Build Caddy with `xcaddy` including `github.com/caddy-dns/hostinger`, add `hostinger_api_token` to vault, and use `tls { dns hostinger {env.HOSTINGER_API_TOKEN} }` in Caddyfile.

### 3.3 — Stale Nebula IP in Caddyfile

After RCA-012 migrated Nebula from `10.42.0.0/16` to `10.100.0.0/16`, the Caddyfile `reverse_proxy` target was not updated. It still pointed to `10.42.1.210` — an IP that no longer exists on any Kshitiz-reachable interface.

### 3.4 — HTTPS Proxy over Nebula Breaks Traefik SNI Routing

The Caddyfile was configured to proxy using `https://10.100.1.210:443`. When Caddy initiates a TLS connection to an IP address, the TLS SNI field contains the **IP literal**, not the original hostname. Traefik v3 performs SNI-based routing: it looks for a router matching `argocd.brahmanda.abhishek-kashyap.com` in the SNI, finds none (got an IP literal instead), and returns 404.

**ADR-008 already specified this correctly:** traffic between Kshitiz and Vyom should be plain HTTP, relying on Nebula's Noise Protocol encryption for security. The double-TLS approach violated the ADR and broke routing.

### 3.5 — ArgoCD Ingress and Server Not Configured for HTTP

The `argocd-ingress.yaml.j2` template was initially deployed with:

- Entrypoint: `websecure` (Traefik port 443)
- Backend port: `443`

After switching Caddy to HTTP, traffic arrives on Traefik's `web` entrypoint (port 80), so no router matched. Additionally, ArgoCD server itself defaults to HTTPS-only mode — it will not serve HTTP responses on port 80 unless started with `--insecure` or the `argocd-cmd-params-cm` ConfigMap sets `server.insecure: "true"`.

---

## 4. The Resolution (Samadhana)

### Changes to Infrastructure Code

**`samsara/terraform/kshitiz/main.tf`** — Added port 80 to Lightsail firewall:

```hcl
port_info {
  protocol  = "tcp"
  from_port = 80
  to_port   = 80
  cidrs     = ["0.0.0.0/0"]
}
```

**`samsara/ansible/playbooks/templates/Caddyfile.j2`** — Three fixes:

1. Explicit hostname instead of wildcard.
2. Correct Nebula IP (`10.100.1.210`).
3. HTTP proxy (not HTTPS) per ADR-008.

```caddyfile
argocd.brahmanda.{{ domain_name }} {
  reverse_proxy http://10.100.1.210:80
}
```

**`samsara/ansible/playbooks/templates/argocd-ingress.yaml.j2`** — Switch to `web` entrypoint + port 80:

```yaml
annotations:
  traefik.ingress.kubernetes.io/router.entrypoints: web
...
port:
  number: 80
```

**`samsara/ansible/playbooks/04-bootstrap-maya.yml`** — Added task to set insecure mode and restart ArgoCD server:

```yaml
- name: 🔓 Configure ArgoCD Server in Insecure Mode (HTTP over Nebula)
  ansible.builtin.shell: |
    kubectl patch configmap argocd-cmd-params-cm \
      -n {{ argocd_namespace }} \
      --type merge \
      -p '{"data":{"server.insecure":"true"}}'
    kubectl rollout restart deployment/argocd-server -n {{ argocd_namespace }}
    kubectl rollout status deployment/argocd-server -n {{ argocd_namespace }} --timeout=120s
```

### The Final Working Traffic Path

```
User (HTTPS)
  → Caddy on Kshitiz (TLS termination, Let's Encrypt cert)
  → HTTP:80 over Nebula tunnel (encrypted by Noise Protocol, per ADR-008)
  → Traefik on Vyom (web entrypoint, Host header routing)
  → argocd-server:80 (insecure mode)
```

---

## 5. Resolution Completion (Samadhana — Poorna)

**`brahmanda-sutra` sync is now fully operational.** The root cause was that `brahmanda-sutra` is a private GitHub repository, but no Git credentials were registered with ArgoCD. A task was added to `04-bootstrap-maya.yml` that creates a Kubernetes Secret labelled `argocd.argoproj.io/secret-type=repository` using `github_argocd_image_updater_pat` as the password.

### Portfolio Application Failures (Full Account)

After `brahmanda-sutra` synced, the `portfolio` ArgoCD Application failed through four further failure modes:

**Failure 1 — `400 name invalid`:** `repoURL: oci://ghcr.io/a4abhishek` was missing the chart name. Fixed by rewriting to `repoURL: ghcr.io` + `chart: a4abhishek/charts/portfolio` (see Failure 2 for why the final form differs from the initial fix).

**Failure 2 — `401 unauthorized` (ArgoCD credential mismatch):** ArgoCD looks up credentials via `git.SameURL(secret.Data["url"], repoURL)` — a normalized exact-string comparison. Every form attempted (`oci://ghcr.io/...`, `https://ghcr.io`, `ghcr.io/a4abhishek/portfolio`) failed to match the Application's `repoURL` after `NormalizeGitURL()`. The only working configuration is both set to the **bare registry host**:

- `ghcr-oci-helm-registry` Secret: `url: ghcr.io`
- Application: `repoURL: ghcr.io`, `chart: a4abhishek/charts/portfolio`

ArgoCD then passes both to the Helm SDK which constructs `oci://ghcr.io/a4abhishek/charts/portfolio` internally.

**Failure 3 — `CreateContainerError: no command specified`:** The GitHub Actions workflow pushed both the Docker image and the Helm chart to `ghcr.io/a4abhishek/portfolio:0.1.0`. Since `helm push` ran after `docker/build-push-action`, the Helm chart OCI artifact silently overwrote the Docker image at that tag. Kubernetes pulled a Helm chart manifest (no `Entrypoint`/`Cmd`) and the container runtime failed. Fixed by pushing charts to a dedicated sub-path: `oci://ghcr.io/a4abhishek/charts`.

**Failure 4 — `ImagePullBackOff`:** `ghcr-secret` (type `docker-registry`) is namespace-scoped. It was only created in `argocd`; pods in `apps` could not reference it. Fixed by looping the `ghcr-secret` creation task over both `argocd_namespace` and `apps_namespace` in `04-bootstrap-maya.yml`.

### Final Working Configuration

```
ghcr.io/a4abhishek/portfolio:VERSION      ← Docker image (container runtime)
ghcr.io/a4abhishek/charts/portfolio:VERSION ← Helm chart (ArgoCD)
```

`brahmanda-sutra/apps/portfolio.yaml`:
```yaml
source:
  repoURL: ghcr.io                     # matches Secret url: ghcr.io exactly
  chart: a4abhishek/charts/portfolio   # full OCI path
  targetRevision: 0.1.0
```

`ghcr-oci-helm-registry` Secret (`argocd` namespace):
```yaml
type: helm
url: ghcr.io
enableOCI: "true"
```

`ghcr-secret` (docker-registry) created in both `argocd` and `apps` namespaces.

---

## 6. Lessons Learned (Sikhsha)

1. **Firewall completeness is a prerequisite, not an afterthought.** Before debugging application-layer issues, verify all required ports are open at the cloud firewall level. Port 80 is non-negotiable for HTTP-01 ACME even on HTTPS-only services.

2. **Wildcard TLS certificates have a hidden prerequisite.** `*.domain.com` requires DNS-01 ACME challenge. Using wildcards without a DNS provider API integration will silently fail cert issuance. For homelab setups, explicit hostnames are simpler and more reliable.

3. **After an overlay network IP migration, grep for the old IPs.** When Nebula moved from `10.42.*` to `10.100.*`, the Caddyfile wasn't updated. A simple `grep -r "10\.42\." samsara/` after the migration would have caught this immediately.

4. **Proxy protocol matters for SNI-based ingress.** Proxying over HTTPS to an IP target sends the IP as TLS SNI. Traefik and most ingress controllers route on hostname SNI. The mismatch causes silent 404s with no obvious error. ADR-008's HTTP-over-Nebula design avoids this entirely.

5. **ArgoCD requires explicit insecure-mode configuration for HTTP ingress.** This is not obvious from the ArgoCD docs and is a common source of confusion. Document it as a required step in any HTTP-fronted ArgoCD deployment.

6. **ArgoCD credential matching for `secret-type: repository` is an exact normalized URL comparison.** Set `url` in the Secret to exactly match `repoURL` in the Application after `git.NormalizeGitURL()`. For a Helm OCI registry, use the bare host (`ghcr.io`) in both; the full OCI chart path belongs in the `chart` field.

7. **Never share an OCI repository path between Docker images and Helm charts.** Both are OCI artifacts tagged by `repo:tag`. The later push wins silently. Convention: Docker images at `ghcr.io/owner/app`, Helm charts at `ghcr.io/owner/charts/app`.

8. **`CreateContainerError: no command specified` does not always mean a missing `CMD` in the Dockerfile.** It can mean the pulled OCI artifact is not a container image at all (e.g., a Helm chart). Verify with: `crane manifest ghcr.io/owner/repo:tag | jq .mediaType`.

9. **ArgoCD's OCI Helm client does not use `docker-registry` pull secrets.** `ghcr-secret` is consumed only by the kubelet. For ArgoCD to pull private OCI Helm charts, a separate Secret with `argocd.argoproj.io/secret-type=repository`, `type: helm`, and `enableOCI: "true"` is required in the `argocd` namespace.

10. **`imagePullSecrets` are namespace-scoped.** A `docker-registry` secret in `argocd` cannot be used by pods in `apps`. Every namespace where workloads run needs its own copy.

11. **Avoid `--from-literal=key="{{ jinja2 | filter }}"` in Ansible shell tasks.** Ansible's argument splitter misparses `key=` followed by a quoted Jinja2 expression. Use `ansible.builtin.template` to render secrets to a temp file (mode `0600`, `no_log: true`), apply with `kubectl apply -f`, then immediately remove the file.

---

## 7. Security Addendum — `server.insecure` Threat Model

This section addresses the follow-up question: *"Does running ArgoCD in insecure mode on a public repository open security risks?"*

### Verdict: The mode is correct; there is one known gap.

**`server.insecure: true` is the official ArgoCD-recommended configuration** for every ingress controller that terminates TLS externally (Traefik, nginx, Contour, GKE, ALB, Istio — all documented in the ArgoCD ingress guide). It does not disable authentication.

**What `server.insecure` actually does:**
- ArgoCD API server serves HTTP on port 8080 instead of HTTPS.
- Component-to-component TLS (argocd-server ↔ argocd-repo-server ↔ argocd-application-controller) is **maintained**.
- JWT authentication is **still required** for all API calls.
- Sessions expire after 24 hours.

**Full attack surface map:**

| Layer | Path | Encryption | Auth Required |
|---|---|---|---|
| User → Kshitiz | Internet → HTTPS/443 | TLS (Let's Encrypt) | No (public) |
| Kshitiz → Vyom | Caddy → HTTP over Nebula | Noise Protocol | N/A |
| Traefik → ArgoCD | Cluster-internal HTTP | None (private LAN) | JWT |
| ArgoCD internals | server ↔ repo-server | TLS | Service account |

**The only actual risk:** Any pod inside the K3s cluster can open a TCP connection to `argocd-server.argocd.svc.cluster.local:80`. Authentication is still required, so an attacker cannot do anything without valid JWT credentials. However, unencrypted JWT tokens traverse the cluster network if a pod happens to initiate a session.

**Mitigations applied:**

1. **Anonymous access explicitly disabled** (`users.anonymous.enabled: "false"` in `argocd-cm`). This was already the default, but is now hardened to survive ConfigMap resets.

2. **NetworkPolicy declared** (`argocd-server-restrict-to-traefik`) restricting port 8080 to kube-system namespace (Traefik) only. All inter-ArgoCD traffic is allowed.

**Known enforcement gap:** K3s with Flannel does **not enforce NetworkPolicies** without a policy controller. The policy is declared (correct infrastructure intent) but not currently active. See `group_vars/vyom/vars.yml` for the upgrade path (Calico, Cilium, or kube-router policy-only).

**Why this is acceptable for this homelab:**
- No multi-tenant workloads — all pods are trusted
- Cluster is on a private LAN (192.168.68.0/24), not internet-reachable directly
- Nebula mesh + Traefik Host header matching forms a second-layer access constraint
- If the cluster network were compromised, an attacker would already have greater access than ArgoCD provides
