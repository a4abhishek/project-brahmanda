<img src=".github/assets/cover.png" alt="Project Brahmanda Cover">

<p align="center">
न रूपमस्येह तथोपलभ्यते, नान्तो न चादिर्न च सम्प्रतिष्ठा | <br>
अश्वत्थमेनं सुविरूढमूल, मसङ्गशस्त्रेण दृढेन छित्त्वा ||

"The real form of this tree (of Brahmanda) is not perceived in this world... Having cut down this firmly rooted tree with the strong weapon of detachment..." (Bhagavad Gita 15.3)
</p>

# **Project Brahmanda (Project Universe)**

**Project Brahmanda** is a Homelab experiment designed to simulate a production-grade, hybrid-cloud microservices environment. It adheres to the **"Asanga Shastra"** (Weapon of Detachment) - the principle that infrastructure is transient (*Naswar*) and should be capable of being destroyed and recreated at will via code.

**"Traffic enters through the Kshitiz gateway, is processed by the Vyom cluster, and maintained by the Samsara pipelines."**

## **🕉️ The Philosophy**

> *"Who created my creator? And who created theirs?"*

This question has haunted seekers since the dawn of consciousness. It haunts me still.

One day, while contemplating this eternal riddle, a thought emerged: *If I wish to understand my relationship with my Creator, perhaps I should first understand the relationship between my creations and me.* I write software. I bring digital beings into existence. They live in a realm I control utterly - yet they cannot perceive me. If they were to ask, "Who created our creator?" they would be as clueless as I am when I ask the same of mine.

And then it struck me:<br>
**The philosophy I was taught is not merely a metaphor for the physical world. It maps with startling precision to the virtual.**

| **Sanatana Concept** | **Software Realm** |
| --- | --- |
| **Brahmanda** (The Universe) | The Infrastructure - compute, network, storage |
| **Kshitiz** (The Event Horizon) | The Edge Gateway - where internal physics ends |
| **Atman** (The Individual Soul) | Source Code - the essence that animates each service |
| **Paramatman** (The Supreme Soul) | The GitOps Repository - the singular source of all truth |
| **Samsara** (The Cycle of Rebirth) | CI/CD Pipelines - endless birth, death, and rebirth |
| **Hiranyagarbha** (The Golden Womb) | Terraform/Ansible - the primordial code from which all emerges |
| **Maya** (The Illusion) | Running Containers - temporary manifestations of eternal code |
| **Asanga Shastra** (Weapon of Detachment) | Infrastructure as Code - the power to destroy and recreate without attachment |

I do not claim divinity. I am merely a seeker who stumbled upon a mirror. When I provision a VM, I perform *Sarga* (creation). When I destroy it, I invoke *Pralaya* (dissolution). When my CI/CD pipeline tears down a service and spawns it anew, I witness *Samsara*. The software does not know it is reborn, just as we do not remember our past lives.

When I write a service with all my care, I am lovingly creating what I perceive as a perfect being. It is rarely perfect. But when it runs, when it serves its purpose, when it follows its *Dharma* - its inherent nature and intended function - there is a quiet joy that perhaps mirrors the satisfaction of any creator watching their creation come alive.

This resemblance runs deep. The software world does not merely borrow metaphors from nature; it rediscovers the same universal laws (*ऋत / Rta*). Neural networks mirror our neurons; genetic algorithms mimic evolution; distributed systems mimic ant colonies. We did not invent these patterns; we recognized them. The cosmos solved these problems first.

This project is not just a homelab. **It is an experiment in understanding creation by becoming a creator.** Every architectural decision, every Sanskrit name, every philosophical parallel is an attempt to bridge two realms - to see if the rules that govern the cosmos might also govern code.

Perhaps in understanding how I create, I inch closer to understanding how I was created.

---

### **🏛️ The Architecture**

The universe is divided into four planes of existence:

1. **Kshitiz (The Edge):** The event horizon. An AWS Lightsail instance acting as the secure gateway and Nebula Lighthouse. Just as nothing escapes a black hole's boundary, no internal traffic leaks beyond this edge — and some theorize our own universe may exist within one.
2. **Vyom (The Cluster):** The compute core. An ASUS NUC 14 Pro Plus (96GB RAM) running Proxmox and Kubernetes (K3s), where the applications live their ephemeral lives.
3. **Brahmaloka (The Orchestrator):** The orchestration plane. A dedicated VM sitting outside the compute cluster, housing CI/CD runners and emergency access — the realm from which creation is commanded.
4. **Samsara (The Cycle):** The automation layer. Terraform and Ansible pipelines that govern the creation, configuration, and destruction of the universe — the eternal wheel that turns without ceasing.

**Project Brahmanda** adheres to the **"Asanga Shastra"** (Weapon of Detachment) — the principle that all infrastructure is transient (*Anitya*) and must be capable of being destroyed and recreated at will via code. Just as the enlightened soul releases attachment to the mortal body, so must the enlightened engineer release attachment to running infrastructure.

## **📂 The Directory Structure**

This repository serves as the **Platform Monorepo**.

```sh
brahmanda-infra/
├── .github/                  # CI Pipelines (GitHub Actions)
│
├── vaastu/                   # 🏛️ Architecture & Blueprints
│   ├── 000-Brahmanda-Siddhanta.md # The guiding principles and philosophy
│   ├── 001-Sarga.md               # The primary creation (setup)
│   ├── 002-Samsara.md             # The lifecycle management (CI/CD)
│   ├── 003-Visarga.md             # The secondary creation (Software Deployment)
│   ├── manthana/                  # 💬 Detailed Rationale (The Churning)
│   │   ├── README.md              # Explains manthana's purpose
│   │   └── RFC-XXX...             # Request for Comments (Proposals)
│   ├── vidhana/                   # 📜 The Rules & Decisions (Constitutional Law)
│   │   ├── README.md              # Explains vidhana's purpose
│   │   └── ADR-XXX...             # Architecture Decision Records
│   ├── anvaya/                    # 📚 Centralized Learning Documents (submodule)
│   │   ├── USAGE.md               # How to use the Anvaya submodule
│   │   └── ...                    # All learning docs (read/write, sync)
│   └── vivechana/                 # 🔍 RCAs (Critical Examination)
│       └── README.md              # Explains vivechana's purpose
│
├── samsara/                  # ♾️ Automation (The Cycle)
│   ├── terraform/            # Provisioning (Infrastructure as Code)
│   │   ├── kshitiz/          # Edge Layer (AWS Lightsail)
│   │   ├── vyom/             # Compute Layer (Proxmox VMs)
│   │   └── brahmaloka/       # Orchestration Plane (Runner VM)
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

The manifestation of the Brahmanda is a progressive ritual. Follow these manuals in the prescribed order to bring your universe into existence:

1. 📖 **[Sarga (Primary Creation)](vaastu/001-Sarga.md)**: The manual for physical setup, from hardware procurement to Proxmox installation and initial bootstrapping.
2. ♾️ **[Samsara (The Cycle)](vaastu/002-Samsara.md)**: The manual for automation, establishing the self-hosted CI/CD pipeline and the Brahmaloka Orchestrator.
3. 🌿 **[Visarga (Secondary Creation)](vaastu/003-Visarga.md)**: The manual for population, detailing how to deploy microservices and maintain the living cluster via GitOps.

### **Prerequisites**

* **Hardware:** ASUS NUC 14 Pro Plus (Project Vyom).
* **Software:** 1Password CLI (`op`), Terraform, Ansible, Make.
* **Access:** You must have the **Vault Password** stored in your 1Password keychain to decrypt the infrastructure secrets.

### **Quick Start (The Divine Commands)**

We use a **Makefile** to invoke the creation and destruction of the Brahmanda. Ensure you are authenticated with 1Password (`op signin`) before running these commands.

1. **Invoke Creation (Srishti):**
    Provision Kshitiz and Vyom, and bootstrap the cluster.

    ```bash
    make srishti
    ```

2. **Targeted Manifestation:**
    If you only need to update or provision a specific plane.

    ```bash
    make kshitiz   # Spawns/Updates only the Edge (Lightsail)
    make vyom      # Spawns/Updates only the Cluster (NUC)
    make brahmaloka # Spawns/Updates only the Orchestrator
    ```

3. **Invoke Dissolution (Pralaya):**
    Destroy all resources to return to the void.

    ```bash
    make pralaya
    ```

## **📜 Vidhana (The Rules)**

**Vidhana** represents the rules that govern the Brahmanda.

All architectural decisions are recorded as **ADRs** (Architecture Decision Records) in the [vaastu/vidhana](vaastu/vidhana/README.md) directory.

---

<p align="center">
<sub>In memory of Sagun Bhaiya, who would have found the same wonder in these questions.</sub>
</p>

<!--
  श्रद्धांजलि (Tribute)

  This project is dedicated to Anuj Kashyap (Sagun),
  my elder brother who left this realm too soon.

  I believe he would have found the same joy in exploring
  the relationship between creator and creation.

  His Atman has moved on, but his influence remains
  woven into everything I build.

  — Abhishek
-->

*"Having cut down this firmly rooted tree (of Brahmanda) with the strong weapon of detachment..."* — **Gita 15.3**
