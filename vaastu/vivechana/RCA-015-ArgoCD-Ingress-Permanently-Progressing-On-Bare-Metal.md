# RCA-015: ArgoCD Ingress Permanently Progressing on Bare-Metal K3s

- **Date:** 2026-04-24
- **Severity:** Low (cosmetic — application was running and routing correctly; only the ArgoCD health status was wrong)
- **Status:** Resolved
- **Components:** ArgoCD, Traefik, portfolio Application

---

## 1. Summary

The `portfolio` ArgoCD Application was stuck in `Synced/Progressing` health status from its very first deployment. All pods were running, the Ingress rules were in effect, and traffic was routing correctly through Traefik. The problem was purely a health check mismatch: ArgoCD's built-in Lua health check for `networking.k8s.io/Ingress` requires `status.loadBalancer.ingress` to be populated before declaring the resource `Healthy`. On bare-metal K3s, Traefik runs as a `ClusterIP` service with no external IP ever assigned, so that field is permanently empty.

---

## 2. Timeline

| Step | Observation |
|------|-------------|
| 1 | `portfolio` Application deployed. Pods running, Ingress present, traffic working. |
| 2 | ArgoCD UI shows `portfolio` as `Synced/Progressing` indefinitely. |
| 3 | `kubectl get application portfolio -n argocd` confirms `HEALTH STATUS: Progressing`. |
| 4 | Pod and Deployment health is fine; `kubectl rollout status` shows successful rollout. |
| 5 | `kubectl get ingress portfolio -n apps -o jsonpath='{.status.loadBalancer}'` returns `map[]`. |
| 6 | `kubectl get svc traefik -n kube-system` shows `ClusterIP` — no `EXTERNAL-IP`. |
| 7 | No `cert-manager` installed; no `MetalLB` installed. No mechanism to assign an external IP. |
| 8 | Custom Lua health check applied to `argocd-cm`. Portfolio flipped to `Healthy` within ~30 seconds. |

---

## 3. Root Cause

ArgoCD's default Ingress health check (`resource.customizations.health.networking.k8s.io_Ingress`) is written for cloud providers where an `IngressController` of type `LoadBalancer` is always assigned a public IP by the cloud control plane. The check returns `Progressing` until `status.loadBalancer.ingress` is non-empty.

On bare-metal K3s:

- Traefik is installed as a `ClusterIP` service (no `LoadBalancer` type, no MetalLB).
- External access goes through Nebula mesh → Caddy on Kshitiz, not through a Kubernetes LoadBalancer.
- `status.loadBalancer.ingress` is never populated.
- The default health check therefore returns `Progressing` forever, regardless of actual routing health.

---

## 4. Resolution

Added a custom Lua health check to `argocd-cm` that considers an Ingress `Healthy` once it has at least one rule defined — the correct signal for bare-metal:

**`templates/argocd-ingress-health-patch.yaml.j2`:**

```lua
hs = {}
if obj.spec ~= nil and obj.spec.rules ~= nil and #obj.spec.rules > 0 then
  hs.status = "Healthy"
  hs.message = "Ingress rules configured"
else
  hs.status = "Progressing"
  hs.message = "No ingress rules defined"
end
return hs
```

Applied via `kubectl patch configmap argocd-cm --type merge --patch-file`. Added as an idempotent task to `04-bootstrap-maya.yml` so it is applied automatically on every cluster recreate.

This check is controller-agnostic (works with Traefik, nginx, or any future replacement).

---

## 5. Lessons Learned

1. **ArgoCD's default health checks assume cloud LoadBalancer semantics.** Bare-metal clusters will always need a custom Ingress health check. Add it to bootstrap immediately, not after noticing the problem.
2. **`Progressing` ≠ broken.** ArgoCD distinguishes `Degraded` (something failed) from `Progressing` (waiting for a condition). A permanently `Progressing` app does not page or alert — it silently masks real future regressions. Fix it to keep the signal meaningful.
3. **The custom health check Lua approach is the official ArgoCD solution** for exactly this scenario. It is not a hack — it is the documented extension point for operator-specific health semantics.
