# Visarga (Formation of Life-Forms)

This document details the **operational architecture** of Project Brahmanda - the workflows for creation, expansion, population, and maintenance.

## **Operational Workflows**

While **Sarga** deals with the _creation_ of the infrastructure (Day 0), **Visarga** deals with the _evolution_ and _population_ of that universe (Day 1+).

These workflows describe the "Happy Path" to manifest the universe using the tools defined in our ADRs.

### **1. Vistara (Expansion Sequence)**

**Scenario: Adding a Jetson Node**

1.  **Inventory:** Add the Jetson IP to `samsara/ansible/inventory/hosts.ini` under the `[vyom:children]` group (e.g., in a `gpu_nodes` subgroup).
2.  **Secrets:** Ensure the specific Nebula certificate key is added to `group_vars/vyom/vault.yml`.
3.  **Execution:** Re-run the cluster playbook:
    ```bash
    ansible-playbook playbooks/02-bootstrap-cluster.yml
    ```
    - _Result:_ Ansible detects the new node, installs Nebula, and joins it to the existing K3s cluster automatically.

### **2. Sankalpa (Application Deployment)**

**Scenario: Deploying Custom Software**

- **Strategy:** We use **GitHub Packages (GHCR)** for both Docker images and OCI Helm Charts.
- **Flow:**
  1.  CI Pipeline builds image & chart -> Pushes to GHCR.
  2.  ArgoCD (running in Vyom) detects the new Chart version.
  3.  ArgoCD syncs the application state.
- _See [RFC-005](../Vaastu/Manthana/RFC-005-Software-Deployment-Strategy.md) for details._
