# RCA-012: Nebula Mesh Network Configuration Failures

- **Date of Incident:** 2026-02-17 (Phase 1) → 2026-03-28 (Phase 2)
- **Duration:** ~2 weeks total (remote debugging + on-site resolution)
- **Severity:** Critical (complete loss of external access to the cluster)
- **Status:** Resolved
- **Components:** Nebula Mesh, K3s (Flannel), Ansible Automation, Overlay Networking

---

## 1. The Incident (Ghatana)

- **Summary:** The Nebula mesh failed in two distinct phases, both preventing Kshitiz from routing traffic to Vyom. Phase 1 was caused by a broken Ansible role generating invalid configuration. Phase 2, discovered after resolving Phase 1 during a cert migration, was a subnet collision between Nebula's overlay (`10.42.0.0/16`) and K3s Flannel's pod network (also `10.42.0.0/24`).
- **Impact:** Kshitiz could not reach any Vyom node over the Nebula mesh. ArgoCD, ingress, and all externally-facing services were completely inaccessible.
- **Detection:**
  - Phase 1: Lighthouse logs showed `udpAddrs="[]"` — no Vyom handshake packets arriving.
  - Phase 2: After re-deploying with corrected certs, Nebula interfaces came up but inter-node pings timed out. `ip addr show` revealed both `nebula1` (`10.42.1.210/16`) and `cni0` (`10.42.0.1/24`) sharing the same `/16` parent.

---

## 2. The Timeline (Samaya-Sarni)

**Phase 1: Ansible Role Failure**

1. Initial Nebula bootstrap via `make vyom` using `trozz.ansible_nebula` role.
2. Nebula service started on all nodes — `systemctl status nebula` showed active.
3. Lighthouse logs: `vpnAddrs="[10.42.1.210]"` but `udpAddrs="[]"` — Vyom is not sending handshake packets.
4. Config inspection on Vyom revealed `static_host_map: {}` and `lighthouse.hosts: []` — both empty.
5. Diagnosed: the role silently consumed variables with the wrong structure and wrote an empty config.
6. Decision made to abandon the role and implement Nebula deployment directly.

**Phase 2: Subnet Collision**

1. During a refactor to per-host certificates, Nebula certs were regenerated using `10.42.0.0/16`.
2. Bootstrap ran successfully. Nebula handshakes with the lighthouse succeeded.
3. Inter-node pings timed out: `ping -c 3 10.42.1.211` from control plane returned 100% loss.
4. `ip addr show` revealed both `nebula1` and K3s's `cni0`/`flannel.1` owning IPs in `10.42.0.0/16`.
5. Root cause: Linux routes `10.42.x.x` to the more-specific `/24` route on `cni0`, not into the Nebula tunnel.
6. Resolved by migrating Nebula to `10.100.0.0/16` and regenerating all certificates.

---

## 3. The Root Cause (Mula Karana)

### Phase 1: Role-Generated Invalid Configuration

- **Why did Vyom not send handshake packets?** → Nebula config had an empty `static_host_map`, so Vyom had no destination to send to.
- **Why was `static_host_map` empty?** → The `trozz.ansible_nebula` role expected variables in a specific undocumented nested structure. The variables provided were flat, so the role silently produced empty values instead of failing.
- **Technical Cause:** Ansible role consumed wrong variable structure, wrote an empty lighthouse map. No validation, no error. Silent misconfiguration.

### Phase 2: Overlay-on-Overlay Subnet Collision

- **Why did inter-node pings fail after certs were fixed?** → Packets to `10.42.x.x` never entered the Nebula tunnel.
- **Why?** → Flannel installs a per-node `/24` route for **every** node in the cluster, collectively covering the entire `10.42.0.0/16` space via `eth0`. Linux kernel longest-prefix-match prefers these more-specific `/24` routes over Nebula's single `/16` route on `nebula1`:
  ```
  10.42.0.0/24 dev cni0        # local pod subnet (direct)
  10.42.1.0/24 via 192.168.68.211 dev eth0   # worker-1 pods (via LAN)
  10.42.2.0/24 via 192.168.68.212 dev eth0   # worker-2 pods (via LAN)
  10.42.0.0/16 dev nebula1     # Nebula mesh (always loses to the /24s above)
  ```
  Note: `cni0` itself has a `/24` address (each node gets a `/24` slice of the cluster CIDR), but the collision isn't caused by `cni0` alone — it's the full set of Flannel per-node routes that saturates the whole `/16` space.
- **Why did both occupy the same space?** → Both Nebula and K3s Flannel default to `10.42.0.0/16`. Neither detects nor prevents the collision.
- **The "Ghost" handshake:** Nebula tried to reach peers at `10.42.x.x`, but packets were silently routed by Flannel over `eth0` into the physical LAN, never entering the Nebula tunnel.

---

## 4. The Resolution (Samadhana)

### Phase 1: Replace Role with Custom Implementation

Replaced `trozz.ansible_nebula` with a direct, role-free implementation in `02-bootstrap-vyom.yml`:

- **Binary install:** Direct download from GitHub Releases, copied to `/usr/bin/nebula`.
- **Configuration:** Full Jinja2 templates (`nebula-node-config.yaml.j2`, `nebula-lighthouse-config.yml.j2`) with all values explicitly declared — no implicit defaults.
- **Verification:** 15+ post-install checks (binary exists, version matches, all cert files present, service active, lighthouse reachable by ping).

Key configuration that was missing in the role output and now explicit in the template:

```yaml
static_host_map:
  "10.100.0.1": ["{{ hostvars['kshitiz-lighthouse']['ansible_host'] }}:4242"]

lighthouse:
  am_lighthouse: false
  hosts:
    - "10.100.0.1"
```

### Phase 2: Migrate Nebula to Non-Conflicting Subnet

Moved Nebula off `10.42.0.0/16` to `10.100.0.0/16`:

| Node | Old Nebula IP | New Nebula IP |
|---|---|---|
| kshitiz-lighthouse | `10.42.0.1/16` | `10.100.0.1/16` |
| vyom-control-plane-1 | `10.42.1.210/16` | `10.100.1.210/16` |
| vyom-worker-1 | `10.42.1.211/16` | `10.100.1.211/16` |
| vyom-worker-2 | `10.42.1.212/16` | `10.100.1.212/16` |

Steps taken:

1. Updated `scripts/generate-nebula-certs.sh` to use the `10.100` prefix.
2. Updated all Nebula config templates to reference `10.100.0.1` as the lighthouse IP.
3. Regenerated all 1Password certificate items via `./scripts/generate-nebula-certs.sh --force`.
4. Updated `debug-nebula.yml` playbook ping targets to the new IPs.
5. Redeployed all nodes via `make vyom`.

---

## 5. Verification

After both fixes, confirm the mesh is healthy:

```bash
# On any Vyom node:
ip addr show nebula1            # Must show 10.100.x.x/16, NOT 10.42.x.x
ping -c 3 10.100.0.1            # Lighthouse reachable
ping -c 3 10.100.1.210          # Inter-node reachable

# Confirm Flannel and Nebula are on separate subnets:
ip route show | grep 10.42      # Should resolve via eth0/cni0
ip route show | grep 10.100     # Should resolve via nebula1
```

---

## 6. Lessons Learned (Sikhsha)

1. **Never trust a role that can succeed silently with wrong config.** Validate critical service output (not just service status) immediately after deployment. Nebula being `active` in systemd is not the same as Nebula being correctly configured.

2. **Overlay networks collide by default.** K3s Flannel (`10.42.0.0/16`), Calico, Cilium, and Nebula all use popular RFC 1918 ranges. Always audit `ip addr show` and `ip route show` before deploying any new overlay.

3. **Lighthouse IP is the mesh's anchor.** If it overlaps with a local bridge IP (like `cni0`), the entire mesh routing collapses at the kernel level. There will be no error message — just silent packet loss.

4. **Prefer high-octet administrative subnets.** Use `10.100.x.x`, `10.200.x.x`, or `172.20.x.x` ranges for administrative overlays (VPNs, mesh networks) to minimize collision risk with application-layer defaults.

5. **Custom implementations beat opaque roles for critical infrastructure.** The custom Nebula deployment is ~50 more lines than the role invocation, but every config value is visible, testable, and verified. The role saved 5 minutes of writing and cost 2 weeks of debugging.
