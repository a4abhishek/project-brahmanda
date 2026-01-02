# **🕉️ Brahmanda Siddhanta (The Cosmic Doctrine)**

**"Traffic enters through the Kshitiz gateway, is processed by the Vyom cluster, and maintained by the Samsara pipelines."**

## **The Philosophy**

**Project Brahmanda** is a Homelab experiment designed to simulate a production-grade, hybrid-cloud microservices environment. It adheres to the **"Asanga Shastra"** (Weapon of Detachment)—the principle that infrastructure is transient (*Naswar*) and should be capable of being destroyed and recreated at will via code.

The SRE Vidhana: This document serves as the immutable Blueprint for **Project Brahmanda**. It is written with the understanding that the infrastructure itself is **Transient**. We use the **Weapon of Detachment** aka Infrastructure as Code to sever ties with individual nodes.

**This document ensures that we can replicate, destroy, and recreate the "Brahmanda" without hesitation.**

## **The Architecture**

The universe is divided into three planes of existence:

1.  **Kshitiz (The Edge):** The event horizon. An AWS Lightsail instance in Singapore acting as the secure gateway and Nebula Lighthouse.
2.  **Vyom (The Cluster):** The compute core. An ASUS NUC 14 Pro Plus (96GB RAM) running Proxmox and Kubernetes (K3s), where the applications live.
3.  **Samsara (The Cycle):** The automation layer. Terraform and Ansible pipelines that govern the creation, configuration, and destruction of the universe.

## **Naming Convention**

To maintain a cohesive engineering dialect, the following internal codenames are adopted:

*   **Project Vyom (Cluster):** The Compute Layer (NUC). Represents the isolated universe where apps and data live.
*   **Project Kshitiz (Edge):** The Lighthouse Gateway. Represents the "Horizon" where the public cloud meets our private ground.
*   **Project Samsara (Pipelines):** The Automation Strategy. Represents the immutable cycle of infrastructure creation and destruction.