# RCA-014: ArgoCD Image Updater v1.1.0 Breaking Change — Annotation-Based Config Silently Ignored

- **Date:** 2026-04-22
- **Severity:** Medium (no outage — portfolio was running at 0.1.0; new tags simply not deployed)
- **Status:** Resolved
- **Components:** ArgoCD Image Updater, brahmanda-sutra, GHCR

---

## 1. Summary

`argocd-image-updater v1.1.0` introduced a **completely new CRD-based control loop** that replaces the legacy annotation-based polling model. The controller now watches only `ImageUpdater` CR objects and produces `"No ImageUpdater CRs to process"` log output every cycle. All `argocd-image-updater.argoproj.io/*` annotations on `Application` objects are **silently ignored** unless an `ImageUpdater` CR explicitly opts in with `useAnnotations: true`.

The portfolio `Application` was correctly annotated per the v0.x API. Tag `0.1.1` was available in GHCR. Credentials were valid. The controller simply never looked at the Application.

---

## 2. Timeline

| Step | Observation | Root Cause |
|------|-------------|------------|
| 1 | `portfolio` deployed at `0.1.0`. Tag `0.1.1` pushed to GHCR. | — |
| 2 | `portfolio` Application remains at `0.1.0` indefinitely. | Image Updater not processing annotations |
| 3 | `kubectl logs argocd-image-updater-controller-*` shows `"No ImageUpdater CRs to process"` every 2 minutes. | v1.1.0 CRD-based controller ignores `Application` annotations |
| 4 | `kubectl get crd \| grep image` confirms `imageupdaters.argocd-image-updater.argoproj.io` CRD installed. | New CRD is installed but no CR was ever created |
| 5 | `kubectl get imageupdater -A` returns `No resources found`. | Confirms zero `ImageUpdater` CRs — controller does nothing |
| 6 | GHCR tags queried via OAuth token flow confirms `["0.1.0", "0.1", "latest", "0.1.1"]` all present. | Tag exists; credentials valid; problem is purely controller API mismatch |
| 7 | Created `portfolio-image-updater.yaml` CR with `useAnnotations: true`. | Fix applied |

---

## 3. Root Cause

`argocd-image-updater v1.1.0` (released 2026-02-05) migrated from an annotation-scanning model to a CRD-based reconciliation model:

| Version | How Image Updater discovers work |
|---------|----------------------------------|
| v0.x | Polls all ArgoCD `Application` objects every N minutes; reads `argocd-image-updater.argoproj.io/*` annotations |
| v1.1.0+ | Watches `ImageUpdater` CRs (`imageupdaters.argocd-image-updater.argoproj.io`); ignores Application annotations unless `useAnnotations: true` in the CR |

The `argocd_image_updater_version: "v1.1.0"` variable was set in `group_vars/maya/vars.yml` but the corresponding `ImageUpdater` CR was never created in `brahmanda-sutra`. The controller installed correctly, started successfully, acquired the leader lease, and then idled — producing no errors, only the quiet `"No ImageUpdater CRs to process"` message.

---

## 4. Contributing Factors

1. **v0.x annotation API still dominates documentation and examples.** The portfolio Application was written correctly per every example found online — because the v0.x annotation-based API is still the most widely referenced. The v1.1.0 CRD-based model was a fresh first-install, not an upgrade, so there was no prior working state to compare against.
2. **Silent failure mode.** The controller logs no warning about found-but-ignored annotations. A fresh install looks identical to a healthy working install — healthy pod, leader lease acquired, no errors.
3. **No verification step after bootstrap.** `04-bootstrap-maya.yml` does not verify that Image Updater actually processes any Application after deployment. The cluster became operational with this as the first Image Updater deployment, so the silence was never noticed until a new tag went undeployed.

---

## 5. Resolution

**Initial fix:** Created `portfolio-image-updater.yaml` with `useAnnotations: true` as a backward-compat bridge to unblock the deployment immediately.

**Final fix:** Migrated to the native v1.1.0 CRD API. All image update configuration removed from `portfolio.yaml` annotations and expressed natively in the `ImageUpdater` CR:

```yaml
apiVersion: argocd-image-updater.argoproj.io/v1alpha1
kind: ImageUpdater
metadata:
  name: portfolio
  namespace: argocd
spec:
  namespace: argocd
  writeBackConfig:
    method: argocd         # patch Application spec directly; no git commit needed
  applicationRefs:
    - namePattern: portfolio
      commonUpdateSettings:
        pullSecret: pullsecret:argocd/ghcr-secret
        updateStrategy: semver
      images:
        - alias: portfolio
          imageName: ghcr.io/a4abhishek/portfolio
          manifestTargets:
            helm:
              name: image.repository
              tag: image.tag
```

The `Application` manifest is now annotation-free. The `ImageUpdater` CR is the single source of truth for image tracking configuration.

---

## 6. Lessons Learned

1. **Check the version you are installing, not just the project name.** `argocd-image-updater v1.1.0` shipped a completely new CRD-based API while all prominent documentation and examples still describe the v0.x annotation model. When installing any tool for the first time, verify the installed version's API matches the examples you are following.

2. **A healthy pod is not a working pod.** Image Updater v1.1.0 starts cleanly, acquires a leader lease, and logs no errors even when completely idle. Verify function, not just health: `kubectl get imageupdater -A` should return results after deployment.

3. **Silent deprecation of an annotation-based API is a failure mode pattern.** When migrating from annotation-based to CRD-based, missing CRs produce no warnings. Add a post-bootstrap verification task that checks `kubectl get imageupdater -A` returns at least one CR.

4. **The fix for v1.1.0 is additive, not destructive.** The existing Application annotations remain valid and are honoured via `useAnnotations: true`. No annotation rewrites are needed.

---

## 7. Verification

After committing `portfolio-image-updater.yaml` and ArgoCD syncing brahmanda-sutra:

```bash
# Confirm the CR is created
kubectl get imageupdater -n argocd

# Watch Image Updater logs — should now show portfolio processing instead of "No ImageUpdater CRs"
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f | grep -i portfolio

# Confirm targetRevision updated to 0.1.1
kubectl get application portfolio -n argocd -o jsonpath='{.spec.source.targetRevision}'
```
