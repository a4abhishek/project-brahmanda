<img src="../.github/assets/visarga/visarga-cover.png" alt="Project Brahmanda Visarga Cover">

<p align="center">
भूतमात्रेन्द्रियधियां जन्म सर्ग उदाहृतः ।<br>
ब्रह्मणो गुणवैषम्याद्विसर्गः पौरुषः स्मृतः ॥
</p>

> **Translation:** "The elemental creation (Hardware/Network) is called Sarga. The secondary creation by Brahma (Deploying Workloads/Apps) is called Visarga." (Srimad Bhagavatam 2.10.3)

---

# Visarga (विसर्ग) — Population of the Brahmanda

**Visarga is the Great Emanation, the descent of the unmanifest Code into the manifest World. It is the breath of Prana that fills the silent void of Vyom, transforming the hollow shell of infrastructure into a living, breathing civilization of software.**

## 🌌 The Progression

In Sanatana philosophy, creation occurs in layers:

1. **Sarga (सर्ग)** — Primary creation: The manifestation of material elements (hardware, networks, operating systems)
2. **Samsara (संसार)** — The eternal cycle: Automation that governs birth, death, and rebirth (CI/CD pipelines)
3. **Visarga (विसर्ग)** — Secondary creation: The population of the universe with **sentient beings** (applications, microservices)

**This is the Visarga Manual.**

You have manifested the physical universe through [Sarga](./001-Sarga.md). You have established the eternal cycle through [Samsara](./002-Samsara.md). Now, it is time to **breathe life** into the void — to populate Brahmanda with the software that will serve its purpose.

---

## 📖 What This Manual Covers

**Audience:** You (Abhishek), or any future architect who inherits this universe.

**Assumption:** When you read this document, you have already completed:

- ✅ **Sarga:** Hardware assembled, Proxmox installed, K3s cluster operational
- ✅ **Samsara:** Brahmaloka orchestrator provisioned, `make` commands functional, distributed locking active

**Goal:** By the end of this manual, you will invoke a single command — `make visarga` — and watch as the GitOps machinery (Maya) manifests your first application into the cluster.

**Scope (Phase 1):** Deploy your **portfolio website** using ArgoCD, GHCR, and the GitOps patterns defined in [ADR-009](./vidhana/ADR-009-Visarga-Deployment-Architecture.md).

---

## 🏗️ Creating the Brahmanda-Sutra Repository

The `brahmanda-sutra` repository is where your **ArgoCD Application manifests** (the sutras) live. This is the **Atman** — the eternal source of truth for what applications should exist in your cluster.

### **Step 1: Create Repository**

```bash
gh repo create brahmanda-sutra --private --description="Concise eternal truths that manifest into running applications"
cd ~/projects   # Your Project Root
git clone git@github.com:a4abhishek/brahmanda-sutra.git
cd brahmanda-sutra
```

### **Step 2: Create Portfolio Application Sutra**

```bash
mkdir -p apps

cat > apps/portfolio.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: portfolio
  namespace: argocd
  annotations:
    argocd-image-updater.argoproj.io/image-list: portfolio=ghcr.io/a4abhishek/portfolio
    argocd-image-updater.argoproj.io/portfolio.update-strategy: semver
    argocd-image-updater.argoproj.io/portfolio.helm.image-name: image.repository
    argocd-image-updater.argoproj.io/portfolio.helm.image-tag: image.tag
    argocd-image-updater.argoproj.io/write-back-method: git
spec:
  project: default
  source:
    repoURL: oci://ghcr.io/a4abhishek
    chart: portfolio
    targetRevision: 1.0.0
    helm:
      releaseName: portfolio
  destination:
    server: https://kubernetes.default.svc
    namespace: apps
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

### **Step 3: Commit and Push**

```bash
git add .
git commit -m "feat: Add portfolio application sutra"
git push origin main
```

> **💡 NOTE:** The ArgoCD Application uses `repoURL: oci://ghcr.io/a4abhishek` (not `oci://ghcr.io/a4abhishek/portfolio`). This is because OCI Helm charts are stored at the **organization/user level** in GHCR, not repository level. The `chart: portfolio` field specifies which chart to pull.

---

## 🔑 Prerequisites: The Keys to the Kingdom

Before Maya (the GitOps facade) can manifest applications, you must acquire and store the necessary credentials. Think of these as the **divine keys** that unlock the gates between the mortal realm (your laptop) and the celestial machinery (GitHub, ArgoCD, GHCR).

### **1. GitHub Personal Access Token (PAT) — The Scribe's Quill**

ArgoCD Image Updater needs **write access** to `brahmanda-sutra` repository to automatically update image tags when new versions are published.

> **📌 Token Type:** Use **Fine-grained Personal Access Token** (not Classic)
> 
> **Why?** Fine-grained tokens allow scoped access to specific repositories, following the principle of least privilege. This token only needs write access to `brahmanda-sutra`, not your entire GitHub account.

**Create the PAT:**

1. Navigate to [GitHub Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens](https://github.com/settings/personal-access-tokens)
2. Click **Generate new token**
  <br><img src="../.github/assets/visarga/githug-pat-argocd-image-updated-01-click-generate-token.png" alt="Go to Fine-grained Token and Click Generate Token" width=600>
3. Configure:
   - **Token name:** `ArgoCD-Image-Updater-PAT`
   - **Expiration:** 1 year (or custom)
   - **Repository access:** Only select repositories → Choose `brahmanda-sutra`
   - **Permissions:**
     - Repository permissions → Contents: **Read and write**
     - Repository permissions → Metadata: **Read-only** (automatically selected)
4. Click **Generate token**
  <br><img src="../.github/assets/visarga/githug-pat-argocd-image-updated-02-fill-details-generate-token.png" alt="Go to Fine-grained Token and Click Generate Token" width=600>
5. A confirmation window will pop-up, verify the details and click **Generate token**.
  <br><img src="../.github/assets/visarga/githug-pat-argocd-image-updated-03-validate-chantes-and-confirm.png" alt="Validate Fine-grained Token details and Click Generate Token" width=600>
6. **Copy the token immediately** (you won't see it again)
  <br><img src="../.github/assets/visarga/githug-pat-argocd-image-updated-04-copy-pat.png" alt="Copy Fine-grained Token" width=600>

**Store in 1Password:**

```bash
# Ensure you're signed in to 1Password CLI
eval $(op signin)

# Create the credential entry
op item create \
  --category=Login \
  --title="GitHub-ArgoCD-Image-Updater-PAT" \
  --vault="Project-Brahmanda" \
  --tags="github,argocd,maya" \
  username=a4abhishek \
  password="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

> You can use 1Password UI to save this credentail, just enter same details as above.

✅ **Verification:** `op read "op://Project-Brahmanda/GitHub-ArgoCD-Image-Updater-PAT/credential"` should return your PAT.

Now you can close the PAT tab or reload to hide the token.

---

### **2. GHCR (GitHub Container Registry) Credentials — The Gatekeeper's Seal**

Your K3s cluster needs credentials to **pull private container images** from GitHub Container Registry (GHCR).

> **📌 Token Type:** Use **Classic Personal Access Token** (not Fine-grained)
> 
> **Why?** As of 2026, Fine-grained tokens do not yet support GitHub Package Registry permissions. You must use a Classic token to access GHCR for pulling/pushing container images and Helm charts.

**Create GHCR Token:**

1. Navigate to [GitHub Settings → Developer Settings → Personal Access Tokens → Tokens (classic)](https://github.com/settings/tokens)
2. Click **Generate new token (classic)**
  <br><img src="../.github/assets/visarga/github-pat-ghcr-01-click-generate-token.png" alt="Go to Classic Token and click on Generate Token" width=600>
3. Configure:
   - **Note:** `GHCR-Pull-Credentials`
   - **Expiration:** 1 year
   - **Scopes:**
     - ✅ `read:packages` (Download packages from GitHub Package Registry)
     - ✅ `write:packages` (Upload packages to GitHub Package Registry)
4. Click **Generate token**
  <br><img src="../.github/assets/visarga/github-pat-ghcr-02-fill-details.png" alt="Fill in the details and click Generate Token" width=600>
5. **Copy the token immediately**
  <br><img src="../.github/assets/visarga/github-pat-ghcr-03-copy-token.png" alt="Copy the token" width=600>

**Store in 1Password:**

```bash
op item create \
  --category=Login \
  --title="GHCR-Pull-Credentials" \
  --vault="Project-Brahmanda" \
  --tags="github,ghcr,maya" \
  username=a4abhishek \
  password="ghp_yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"
```

✅ **Verification:** `op read "op://Project-Brahmanda/GHCR-Pull-Credentials/password"` should return your token.

---

### **3. ArgoCD Admin Password — The Guardian's Passphrase**

Unlike auto-generated passwords, you will **define** a strong admin password for ArgoCD in advance.

**Generate a Strong Password:**

```bash
# Use 1Password CLI to generate a 32-character password
op item create \
  --category=Login \
  --title="ArgoCD-Admin-Password" \
  --vault="Project-Brahmanda" \
  --tags="argocd,maya,admin" \
  --generate-password='letters,digits,symbols,32' \
  username=admin
```

✅ **Verification:** `op read "op://Project-Brahmanda/ArgoCD-Admin-Password/password"` should return your password.

---

### **4. Upstash Credentials — The Lock Keeper's Token**

Your Makefile uses Upstash Redis for **distributed locking** to prevent concurrent infrastructure changes. These credentials should already exist from Samsara setup, but verify:

✅ **Verification:**

```bash
op read "op://Project-Brahmanda/Upstash-Sanchay-Token/UPSTASH_REDIS_REST_URL"
op read "op://Project-Brahmanda/Upstash-Sanchay-Token/UPSTASH_REDIS_REST_TOKEN"
```

If these fail, revisit [Samsara Section 3.4](./002-Samsara.md#34-configure-upstash-redis-for-distributed-locking).

---

## 🎨 Creating Your First Application (Portfolio Website)

Before Maya can manifest your application, the application itself must exist in a repository with a **Dockerfile**, **Helm chart**, and **CI pipeline**.

### **Step 1: Create the Repository**

```bash
# On your laptop
mkdir -p ~/projects/portfolio
cd ~/projects/portfolio
git init
gh repo create portfolio --public --source=. --remote=origin
```

### **Step 2: Add Application Code**

Create a simple static website (or use your existing portfolio):

```bash
# Create a basic HTML file
mkdir -p public
cat > public/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Abhishek Kashyap - Portfolio</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        h1 { font-size: 3em; }
        p { font-size: 1.2em; }
    </style>
</head>
<body>
    <h1>🚀 Welcome to Project Brahmanda</h1>
    <p>The universe has manifested successfully. This is Visarga — the population of the cosmos.</p>
    <p>— Abhishek Kashyap</p>
</body>
</html>
EOF
```

### **Step 3: Add Dockerfile**

```bash
cat > Dockerfile <<'EOF'
FROM nginx:alpine
COPY public /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
```

### **Step 4: Create Helm Chart**

```bash
mkdir -p helm/templates

# Chart.yaml
cat > helm/Chart.yaml <<'EOF'
apiVersion: v2
name: portfolio
description: Abhishek's Portfolio Website
type: application
version: 1.0.0
appVersion: "1.0.0"
EOF

# values.yaml
cat > helm/values.yaml <<'EOF'
image:
  repository: ghcr.io/a4abhishek/portfolio
  tag: "1.0.0"
  pullPolicy: IfNotPresent

replicaCount: 2

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: abhishek-kashyap.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: portfolio-tls
      hosts:
        - abhishek-kashyap.com
EOF

# Deployment
cat > helm/templates/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      imagePullSecrets:
        - name: ghcr-secret
      containers:
        - name: portfolio
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80
              name: http
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
EOF

# Service
cat > helm/templates/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app: {{ .Chart.Name }}
EOF

# Ingress
cat > helm/templates/ingress.yaml <<'EOF'
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Chart.Name }}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: {{ .Values.ingress.className }}
  tls:
  {{- range .Values.ingress.tls }}
    - hosts:
      {{- range .hosts }}
        - {{ . | quote }}
      {{- end }}
      secretName: {{ .secretName }}
  {{- end }}
  rules:
  {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
        {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $.Chart.Name }}
                port:
                  number: {{ $.Values.service.port }}
        {{- end }}
  {{- end }}
{{- end }}
EOF
```

### **Step 5: Create GitHub Actions Workflow**

```bash
mkdir -p .github/workflows

cat > .github/workflows/release.yml <<'EOF'
name: Build and Publish

on:
  push:
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Helm
        uses: azure/setup-helm@v4
        with:
          version: 'latest'

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=raw,value=latest

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

      - name: Package and Push Helm Chart
        run: |
          # Update chart version to match image tag (semver only)
          if [[ "${{ github.ref }}" == refs/tags/v* ]]; then
            VERSION=${GITHUB_REF#refs/tags/v}
            sed -i "s/^version:.*/version: $VERSION/" helm/Chart.yaml
            sed -i "s/^appVersion:.*/appVersion: \"$VERSION\"/" helm/Chart.yaml
          fi

          helm package helm/
          helm push portfolio-*.tgz oci://${{ env.REGISTRY }}/${{ github.repository_owner }}
EOF
```

### **Step 6: Commit and Push**

```bash
git add .
git commit -m "feat: Initial portfolio website with Helm chart"
git push origin main

# Create a release tag to trigger CI/CD
git tag v1.0.0
git push origin v1.0.0
```

✅ **Verification:** Go to your GitHub repository → Actions tab → Verify the workflow runs successfully and publishes the image/chart to GHCR.

---

## 🔐 Generating Maya Vault

The Maya Ansible playbook needs encrypted credentials stored in `group_vars/maya/vault.yml`. We use the **Nidhi framework** to generate this from 1Password.

### **Step 1: Verify Vault Template Exists**

The vault template **should already exist** at [samsara/ansible/group_vars/maya/vault.tpl.yml](../samsara/ansible/group_vars/maya/vault.tpl.yml) (created during Samsara setup). Verify:

```bash
cat samsara/ansible/group_vars/maya/vault.tpl.yml
```

Expected content:

```yaml
---
# Maya (GitOps Facade) Ansible Vault Template
github_username: "op://Project-Brahmanda/GitHub-ArgoCD-Image-Updater-PAT/username"
github_argocd_image_updater_pat: "op://Project-Brahmanda/GitHub-ArgoCD-Image-Updater-PAT/password"
ghcr_username: "op://Project-Brahmanda/GHCR-Pull-Credentials/username"
ghcr_password: "op://Project-Brahmanda/GHCR-Pull-Credentials/password"
argocd_admin_username: "op://Project-Brahmanda/ArgoCD-Admin-Password/username"
argocd_admin_password: "op://Project-Brahmanda/ArgoCD-Admin-Password/password"
upstash_url: "op://Project-Brahmanda/Upstash-Sanchay-Token/UPSTASH_REDIS_REST_URL"
upstash_token: "op://Project-Brahmanda/Upstash-Sanchay-Token/UPSTASH_REDIS_REST_TOKEN"
```

### **Step 2: Generate Encrypted Vault**

```bash
# From project root
make nidhi-tirodhana VAULT=maya
```

**What this does:**

1. Reads `group_vars/maya/vault.tpl.yml`
2. Resolves all `op://` references using 1Password CLI
3. Encrypts the result using Ansible Vault
4. Writes to `group_vars/maya/vault.yml`

---

## 🕉️ Invoking Visarga (The Act of Creation)

You are now ready. All keys have been forged, all credentials stored, all repositories prepared. With a single command, you will manifest the GitOps machinery and deploy your first application.

### **Pre-Flight Checklist**

Before invoking Visarga, verify all prerequisites:

```bash
# 1. Verify 1Password credentials exist
op read "op://Project-Brahmanda/GitHub-ArgoCD-Image-Updater-PAT/password" > /dev/null && echo "✅ GitHub PAT"
op read "op://Project-Brahmanda/GHCR-Pull-Credentials/password" > /dev/null && echo "✅ GHCR Token"
op read "op://Project-Brahmanda/ArgoCD-Admin-Password/password" > /dev/null && echo "✅ ArgoCD Password"
op read "op://Project-Brahmanda/Upstash-Sanchay-Token/UPSTASH_REDIS_REST_URL" > /dev/null && echo "✅ Upstash URL"

# 2. Verify Maya vault exists
make nidhi-tirodhana VAULT=maya

# 3. Setup kubeconfig
make kubeconfig
export KUBECONFIG=~/.kube/config-vyom

# 4. Verify K3s cluster is operational
kubectl get nodes

# 5. Verify portfolio image exists in GHCR
# Visit: https://github.com/a4abhishek/portfolio/pkgs/container/portfolio

# 6. Verify brahmanda-sutra repository exists and has portfolio.yaml
# Visit: https://github.com/a4abhishek/brahmanda-sutra
```

**If all checks pass, proceed to invocation.**

---

### **The Sacred Command**

```bash
# From project root
make visarga
```

**What Happens:**

1. **Lock Acquisition:** Makefile acquires `brahmanda_lock_sutra` from Upstash Redis
2. **Ansible Execution:** Runs `samsara/ansible/playbooks/04-bootstrap-maya.yml`:
   - Installs ArgoCD in `argocd` namespace
   - Installs ArgoCD Image Updater
   - Creates GHCR pull secret in `apps` namespace
   - Configures ArgoCD admin password
   - Deploys bootstrap Application (points to `brahmanda-sutra` repository)
3. **ArgoCD Sync:** ArgoCD detects the bootstrap Application, reads `apps/portfolio.yaml`, and deploys your portfolio
4. **Lock Release:** Makefile releases the distributed lock

**Expected Output:**

```
🔒 Acquiring lock: brahmanda_lock_sutra...
✅ Lock acquired successfully
🎭 Invoking Maya (GitOps Facade)...

PLAY [Bootstrap Maya (GitOps Facade)] ******************************

TASK [Install ArgoCD] *********************************************
changed: [localhost]

TASK [Install ArgoCD Image Updater] *******************************
changed: [localhost]

TASK [Create GHCR Pull Secret] ************************************
changed: [localhost]

TASK [Configure ArgoCD Admin Password] ****************************
changed: [localhost]

TASK [Deploy Bootstrap Application] *******************************
changed: [localhost]

PLAY RECAP ********************************************************
localhost                  : ok=5    changed=5    unreachable=0    failed=0

✅ Maya manifested successfully
🔓 Releasing lock: brahmanda_lock_sutra...
```

---

## 🌐 Accessing Your Application

### **Option 1: Port-Forward (Immediate Access)**

```bash
# Forward ArgoCD server to localhost
kubectl -n argocd port-forward svc/argocd-server 8080:443

# Open browser: https://localhost:8080
# Username: admin
# Password: (from 1Password)
op read "op://Project-Brahmanda/ArgoCD-Admin-Password/password"
```

### **Option 2: Ingress (Production Access)**

Once DNS is configured and cert-manager is operational (Phase 3+), access:

- **ArgoCD UI:** <https://argocd.vyom.abhishek-kashyap.com>
- **Portfolio:** <https://abhishek-kashyap.com>

---

## 🎉 Verification: The Universe is Alive

### **Check ArgoCD Status**

```bash
kubectl -n argocd get applications

# Expected output:
# NAME        SYNC STATUS   HEALTH STATUS
# portfolio   Synced        Healthy
```

### **Check Application Pods**

```bash
kubectl -n apps get pods

# Expected output:
# NAME                         READY   STATUS    RESTARTS   AGE
# portfolio-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# portfolio-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### **Check Ingress**

```bash
kubectl -n apps get ingress

# Expected output:
# NAME        CLASS   HOSTS                   ADDRESS        PORTS     AGE
# portfolio   nginx   abhishek-kashyap.com    10.30.0.100    80, 443   2m
```

### **Test Application**

```bash
# Port-forward to test locally (if DNS not yet configured)
kubectl -n apps port-forward svc/portfolio 8081:80

# Open browser: http://localhost:8081
# You should see: "🚀 Welcome to Project Brahmanda"
```

---

## 🔮 What's Next?

You have completed **Phase 1** of Visarga — your first application lives in the Brahmanda.

**Subsequent Phases (see [ADR-009](./vidhana/ADR-009-Visarga-Deployment-Architecture.md)):**

- **Phase 2:** Automated version updates via ArgoCD Image Updater
  - *Why:* Eliminate manual manifest updates when new image versions are published
  - *When:* After you've deployed 2-3 applications and manual updates become tedious

- **Phase 3:** Production-grade security (Sealed Secrets, Network Policies)
  - *Why:* Store encrypted secrets in Git, isolate application traffic
  - *When:* Before deploying applications with sensitive credentials (databases, APIs)

- **Phase 4:** Monitoring & observability (Prometheus, Grafana)
  - *Why:* Visibility into resource usage, application health, performance metrics
  - *When:* After 5+ applications are deployed and you need operational visibility

- **Phase 5:** Disaster recovery & chaos engineering (Velero, Chaos Mesh)
  - *Why:* Validate that Asanga Shastra (detachment) works — cluster can be destroyed and recreated
  - *When:* After cluster is stable and you want to validate recovery procedures

> **📜 Living Document:** As each subsequent phase is implemented, this Visarga manual will evolve to include the prerequisite steps and invocation procedures for that phase. Phase 1 establishes the foundation; future phases build upon it, and this document will reflect that progression. What you read here today is the seed — tomorrow it will have grown into a complete tree of operational knowledge.

---

### **Deploying Additional Applications**

After bootstrap, deploying new applications is simple:

1. Create application repository with:
   - Application code
   - `Dockerfile`
   - `helm/` directory with Chart.yaml, values.yaml, templates/
   - `.github/workflows/release.yml` (based on portfolio example)

2. Push code and create release tag:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. Add ArgoCD Application manifest to `brahmanda-sutra/apps/`:

   ```bash
   cd ~/projects/brahmanda-sutra
   cat > apps/my-new-app.yaml <<'EOF'
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-new-app
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: oci://ghcr.io/a4abhishek
       chart: my-new-app
       targetRevision: 1.0.0
     destination:
       server: https://kubernetes.default.svc
       namespace: apps
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   EOF

   git add apps/my-new-app.yaml
   git commit -m "feat: Add my-new-app sutra"
   git push origin main
   ```

4. ArgoCD automatically detects the new Application and deploys it (no `make visarga` needed)

5. Verify deployment:

   ```bash
   kubectl -n argocd get applications
   kubectl -n apps get pods -l app=my-new-app
   ```

**That's the power of GitOps — code push becomes deployment automatically.**

---

## 🕉️ Epilogue

> *"तत् सृष्ट्वा तदेवानुप्राविशत्"*
> *"Having created it, He entered into it."*
> — Taittiriya Upanishad 2.6.1

You have not merely deployed software — you have performed **Visarga**, the sacred act of breathing life into the universe. The applications you manifest are not static artifacts; they are **living entities** governed by the eternal cycle of Samsara (CI/CD), destined to evolve, die, and be reborn.

Wield the **Asanga Shastra** (Weapon of Detachment) with wisdom. Remember: the code (Atman) is eternal, but all manifestations (Maya) are transient.

**May your Brahmanda flourish. May your workloads be resilient. May your deployments be swift.**

🚀 **Om Shanti Shanti Shanti** 🚀
