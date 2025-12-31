# **ADR-003: Hybrid Secret Management Strategy**

Date: 2025-12-31
Status: Accepted

## **Context**

Project Brahmanda requires the management of highly sensitive credentials (Nebula CA keys, SSH private keys, Cloud API tokens). Since the infrastructure spans multiple environments (MacBook, Windows/WSL, CI/CD pipelines) and manages the network layer itself, relying solely on an online-only secret manager creates a "Connectivity Paradox".

For a detailed discussion and rationale, please see [Manthana/003-Secret-Management.md](../Manthana/003-Secret-Management.md).

## **Decision**

We will adopt a **Hybrid Secret Management** model combining **Ansible Vault** and **1Password**.

## **Consequences**

- **Positive:** Full offline recovery capability. Secrets are version-controlled with code. Zero-trust regarding where the code is stored.
- **Negative:** High friction if the Vault Password is lost.
