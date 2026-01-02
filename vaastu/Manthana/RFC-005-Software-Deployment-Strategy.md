# **RFC 005: Software Deployment Strategy (The Cycle of Samsara)**

We need a strategy to deploy and update custom software (Go microservices, Python bots) and third-party applications (databases, monitoring) into the Brahmanda cluster. The solution must be automated, secure, and avoid "circular dependencies" (bootstrapping problems).

## **1. The Challenge**

- **Custom Software:** We write code (e.g., `greeter-service`). It needs to be built, containerized, and deployed.
- **Third-Party Software:** We use tools (e.g., `longhorn`, `prometheus`). These need to be installed via Helm.
- **The "Bootstrap Paradox":** If we host our own container registry (like Harbor) _inside_ the cluster, how do we pull the image for Harbor itself to deploy it?

## **2. Options Analysis**

### **Option A: GitOps (ArgoCD) + Raw Manifests**

- **Description:** Commit `deployment.yaml` files directly to the git repo.
- **Pros:** Simplest. No build artifacts other than the Docker image.
- **Cons:** Hard to manage complex apps. No versioning of the _deployment logic_ (Helm charts). Hard to roll back configuration changes independently of code.

### **Option B: Self-Hosted Registry (Harbor/JFrog) inside Cluster**

- **Description:** Run a registry in K8s. Push Helm charts and Docker images there.
- **Pros:** Data sovereignty. Fast pulls (local network).
- **Cons:** **High Resource Usage** (Java-based Artifactory or heavy Harbor components). **Bootstrap Paradox** (requires external storage/db before it can run). **Maintenance Burden** (upgrading the registry itself).

### **Option C: GitHub Packages (GHCR) + OCI Helm Charts**

- **Description:** Use GitHub Actions to build Docker images AND package Helm charts as OCI artifacts. Push both to GitHub Container Registry (GHCR). ArgoCD pulls charts from `oci://ghcr.io/...`.
- **Pros:**
  - **Zero Maintenance:** Managed by GitHub.
  - **Integrated:** CI/CD pipeline stays in one place.
  - **Standard:** OCI is the modern standard for Helm.
  - **Free Tier:** Generous for public/private packages.
- **Cons:** Requires internet access to pull images (mitigated by local caching).

### **Option D: GitHub Releases (Binaries/Tarballs)**

- **Description:** Upload Helm charts as `.tgz` files to GitHub Releases.
- **Pros:** Simple file hosting.
- **Cons:** ArgoCD integration is clunky compared to a proper Helm repository.

## **3. Recommendation**

**Option C: GitHub Packages (GHCR) + OCI Helm Charts.**

This aligns with the "Weapon of Detachment" philosophy. We don't want to maintain a heavy registry artifact inside our transient cluster.

### **Proposed Workflow**

1.  **Code Change:** Push to `main`.
2.  **CI (GitHub Actions):**
    - Build Docker Image -> Push to `ghcr.io/a4abhishek/greeter:sha-xyz`.
    - Package Helm Chart -> Push to `oci://ghcr.io/a4abhishek/charts/greeter:1.0.0`.
3.  **CD (ArgoCD):**
    - ArgoCD monitors the Helm Chart version.
    - Detects new version -> Syncs cluster.

### **Handling Third-Party Software**

We need to manage complex upstream stacks (Longhorn, Prometheus, Cert-Manager).

#### **Option A: The "Umbrella Chart" (Monolithic Helm)**

- **Description:** Create a single local chart (`brahmanda-core`) that lists all third-party tools as `dependencies` in `Chart.yaml`.
- **Pros:** Single atomic deployment.
- **Cons:** **Tight Coupling.** Upgrading one component (e.g., Longhorn) requires redeploying the entire stack. If one sub-chart fails, the whole release fails. Hard to visualize individual component health in ArgoCD.

#### **Option B: The "App of Apps" Pattern (GitOps Standard)**

- **Description:** A "Root" ArgoCD Application that points to a directory containing `Application` manifests for each tool (e.g., `longhorn.yaml`, `prometheus.yaml`).
- **Pros:** **Decoupling.** Each tool is an independent entity in ArgoCD. You can sync, debug, and rollback Longhorn without touching Prometheus. Better visibility in the UI.
- **Cons:** More YAML files to manage initially.

#### **Recommendation**

**Option B (App of Apps).**
This aligns with the modular nature of microservices. It allows us to treat the platform as a composition of independent services rather than a monolith.

- **Structure:**

  - `sankalpa/bootstrap.yaml` -> Points to `sankalpa/core/`
  - `sankalpa/core/longhorn.yaml` -> Points to upstream Longhorn chart.
  - `sankalpa/core/cert-manager.yaml` -> Points to upstream Cert-Manager chart.

- **Updates:** RenovateBot or GitHub Dependabot to monitor upstream chart versions and update our `Application` manifests.
