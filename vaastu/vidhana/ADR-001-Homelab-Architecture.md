# **ADR-001: Hybrid Cloud Homelab Architecture**

Date: 2025-12-31
Status: Accepted

## **Context**

We need a scalable, secure, and professional homelab environment for experimentation (Kubernetes, AI/LLMs, Go services). The system must be accessible from the public internet but isolated from the physical home LAN to prevent lateral movement in case of a breach.

For a detailed discussion and rationale, please see [Manthana/001-Homelab-Architecture.md](../Manthana/001-Homelab-Architecture.md).

## **Decision**

We will adopt a **Hybrid Cloud Overlay** architecture consisting of three layers:

1.  **Edge Layer: Project Kshitiz (Lighthouse)**
2.  **Transport Layer (Mesh)**
3.  **Compute Layer: Project Vyom (On-Prem)**

## **Consequences**

- **Positive:** "Zero Trust" networking by default. No open ports on the home ISP router. High portability.
- **Negative:** Added latency. Requires managing Nebula certificates (PKI).
