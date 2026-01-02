# **ADR 005: Software Deployment Strategy**

Date: 2026-01-03<br>
Status: Accepted

## **Context**

Project Brahmanda requires a robust mechanism to deploy two types of software:

1.  **Custom Microservices:** Code we write (Go, Python) that needs building, packaging, and deploying.
2.  **Third-Party Infrastructure:** Tools we consume (Longhorn, Prometheus, Cert-Manager).

We need to avoid the "Bootstrap Paradox" (hosting the registry inside the cluster it serves) and ensure deployments are atomic, versioned, and decoupled.

For a detailed analysis of options, see [Manthana/RFC-005-Software-Deployment-Strategy.md](../Manthana/RFC-005-Software-Deployment-Strategy.md).

## **Decision**

We will adopt a **GitOps-driven, OCI-native** strategy:

1.  **Artifact Registry (The Store):**

    - We will use **GitHub Packages (GHCR)** for storing both **Docker Images** and **Helm Charts** (OCI format).
    - **Rationale:** Zero maintenance, free tier, and tight integration with our source code. Eliminates the need for a self-hosted Harbor registry.

2.  **Deployment Pattern (The Method):**

    - We will use the **ArgoCD "App of Apps" Pattern**.
    - **Rationale:** Decouples the lifecycle of different applications. Allows us to upgrade Longhorn without touching Prometheus. Provides a clear hierarchy in the ArgoCD UI.

3.  **Update Strategy (The Cycle):**
    - **Custom Apps:** CI pipeline pushes new Chart versions; ArgoCD auto-syncs.
    - **Third-Party Apps:** **RenovateBot** monitors upstream Helm repositories and opens PRs to update version numbers in our GitOps repo (`sankalpa/`).

## **Implementation Guide**

### **1. The CI Pipeline (GitHub Actions)**

For every custom microservice (e.g., `greeter-service`), the pipeline must:

1.  **Build** the Docker container.
2.  **Push** the container to `ghcr.io/a4abhishek/greeter-service:sha-xyz`.
3.  **Package** the Helm Chart using `helm package`.
4.  **Push** the Chart to `oci://ghcr.io/a4abhishek/charts/greeter-service:1.0.0`.

### **2. The CD Structure (Sankalpa)**

The `sankalpa/` directory will be structured as follows:

```yaml
sankalpa/
├── bootstrap.yaml          # The "Multi-Root" Manifest (defines the 3 Layers)
├── core/                   # Layer 1: System Infrastructure
│   ├── longhorn.yaml       # ArgoCD Application -> Upstream Longhorn
│   ├── cert-manager.yaml   # ArgoCD Application -> Upstream Cert-Manager
│   └── ingress.yaml        # ArgoCD Application -> Traefik/Nginx
├── observability/          # Layer 2: Monitoring Stack
│   ├── prometheus.yaml     # ArgoCD Application -> Upstream Prometheus
│   ├── grafana.yaml        # ArgoCD Application -> Upstream Grafana
│   └── ...
└── apps/                   # Layer 3: Business Logic
    ├── greeter.yaml        # ArgoCD Application -> oci://ghcr.io/...
    └── ...
```

### **3. The Bootstrap Manifest (Example)**

The `bootstrap.yaml` is a **Multi-Doc YAML** that defines the three primary layers. This ensures logical separation while keeping the entry point simple.

```yaml
# sankalpa/bootstrap.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: layer-core
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/a4abhishek/project-brahmanda.git
    path: sankalpa/core
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: layer-observability
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/a4abhishek/project-brahmanda.git
    path: sankalpa/observability
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: layer-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/a4abhishek/project-brahmanda.git
    path: sankalpa/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
```

### **4. ArgoCD Configuration**

- **Repository:** Connect ArgoCD to the `project-brahmanda` repo.
- **Registry Credentials:** Create a Kubernetes Secret in the `argocd` namespace containing a GitHub PAT (Personal Access Token) with `read:packages` scope, so ArgoCD can pull private OCI charts from GHCR.

## **Consequences**

- **Positive:**
  - **Detachment:** The cluster state is fully reconstructible from Git and GHCR. No state is trapped inside the cluster's own registry.
  - **Speed:** OCI Helm charts are faster and more standard than HTTP-based Helm repos.
  - **Isolation:** Breaking one app's config doesn't break the deployment of others.
- **Negative:**
  - **Internet Dependency:** The cluster must have internet access to pull images/charts (mitigated by local caching).
  - **Complexity:** "App of Apps" requires understanding ArgoCD's recursive logic.
