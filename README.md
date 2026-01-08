<img src=".github/assets/cover.png" alt="Project Brahmanda Cover">

<p align="center">
न रूपमस्येह तथोपलभ्यते, नान्तो न चादिर्न च सम्प्रतिष्ठा | <br>
अश्वत्थमेनं सुविरूढमूल, मसङ्गशस्त्रेण दृढेन छित्त्वा ||

"The real form of this tree (of Brahmanda) is not perceived in this world... Having cut down this firmly rooted tree with the strong weapon of detachment..." (Bhagavad Gita 15.3)
</p>

# **Project Brahmanda (Project Universe)**

**"Traffic enters through the Kshitiz gateway, is processed by the Vyom cluster, and maintained by the Samsara pipelines."**

## **🕉️ The Philosophy**

**Project Brahmanda** is a Homelab experiment designed to simulate a production-grade, hybrid-cloud microservices environment. It adheres to the **"Asanga Shastra"** (Weapon of Detachment)—the principle that infrastructure is transient (*Naswar*) and should be capable of being destroyed and recreated at will via code.

### **🏛️ The Architecture**

The universe is divided into three planes of existence:

1. **Kshitiz (The Edge):** The event horizon. An AWS Lightsail instance in Singapore acting as the secure gateway and Nebula Lighthouse.
2. **Vyom (The Cluster):** The compute core. An ASUS NUC 14 Pro Plus (96GB RAM) running Proxmox and Kubernetes (K3s), where the applications live.
3. **Samsara (The Cycle):** The automation layer. Terraform and Ansible pipelines that govern the creation, configuration, and destruction of the universe.

## **📂 The Directory Structure**

This repository serves as the **Platform Monorepo**.

```sh
brahmanda-infra/
├── .github/                  # CI Pipelines (GitHub Actions)
│
├── vaastu/                   # 🏛️ Architecture & Blueprints
│   ├── 00_Brahmanda-Siddhanta.md # The guiding principles and philosophy
│   ├── 001-Sarga.md              # The primary creation (setup)
│   ├── 002-Visarga.md            # The secondary creation (architecture)
│   ├── manthana/                 # 💬 Detailed Rationale (The Churning)
│   │   ├── README.md             # Explains manthana's purpose
│   │   └── RFC-XXX...            # Request for Comments (Proposals)
│   ├── vidhana/                  # 📜 The Rules & Decisions (Constitutional Law)
│   │   ├── README.md             # Explains vidhana's purpose
│   │   └── ADR-XXX...            # Architecture Decision Records
│   ├── anvaya/                   # 📚 Centralized Learning Documents (submodule)
│   │   ├── USAGE.md              # How to use the Anvaya submodule
│   │   └── ...                   # All learning docs (read/write, sync)
│   └── vivechana/                # 🔍 RCAs (Critical Examination)
│       └── README.md             # Explains vivechana's purpose
│
├── samsara/                  # ♾️ Automation (The Cycle)
│   ├── terraform/            # Provisioning (Infrastructure as Code)
│   │   ├── kshitiz/          # Edge Layer (AWS Lightsail)
│   │   └── vyom/             # Compute Layer (Proxmox VMs)
│   │
│   └── ansible/              # Configuration Management
│       ├── inventory/        # Hosts and IPs
│       ├── group_vars/       # Variables & Encrypted Secrets
│       │   ├── brahmanda/    # Global variables
│       │   ├── kshitiz/      # Edge specific
│       │   └── vyom/         # Compute specific
│       ├── roles/            # Reusable logic (Nebula, K3s, Hardening)
│       └── playbooks/        # Execution scripts
│
├── sankalpa/                 # ☸️ Desired State (GitOps/ArgoCD)
│   ├── bootstrap.yaml        # The "Multi-Root" Manifest
│   ├── core/                 # System Apps (Longhorn, Ingress, Cert-Manager)
│   ├── observability/        # Prometheus, Grafana, Loki
│   └── apps/                 # Custom Applications (Greeter AI, Go Services)
│
├── scripts/                  # 🛠️ Utilities (Disaster Recovery, ISO Gen)(Srishti/Pralaya)
└── Makefile                  # 🕹️ The Control Plane
```

## **💥 Mahasphota (Getting Started)**

### **Prerequisites**

* **Hardware:** ASUS NUC 14 Pro Plus (Project Vyom).
* **Software:** 1Password CLI (op), Terraform, Ansible, Make.
* **Access:** You must have the **Vault Password** stored in your 1Password keychain to decrypt the infrastructure secrets.

### **Quick Start (The Divine Commands)**

We use a **Makefile** to invoke the creation and destruction of the Brahmanda. Ensure you are authenticated with 1Password (op signin) before running these commands.

1. Invoke Creation (Srishti):
   Provision Kshitiz and Vyom, and bootstrap the cluster.
   make srishti
2. Targeted Manifestation:
   If you only need to update or provision a specific plane.
   make kshitiz   \# Spawns/Updates only the Edge (Lightsail)
   make vyom      \# Spawns/Updates only the Cluster (NUC)
3. Restore State (Sankalpa):
   Once the universe is created, apply your will (GitOps).
   * Log into ArgoCD.
   * Sync the sankalpa/ directory.
4. Invoke Dissolution (Pralaya):
   Destroy all resources to return to the void.
   make pralaya

## **📜 Vidhana (The Rules)**

**Vidhana** represents the rules that govern the Brahmanda.

All architectural decisions are recorded as **ADRs** (Architecture Decision Records) in the [vaastu/vidhana](vaastu/vidhana/README.md) directory.

*"Having cut down this firmly rooted tree (of Brahmanda) with the strong weapon of detachment..."* — **Gita 15.3**
