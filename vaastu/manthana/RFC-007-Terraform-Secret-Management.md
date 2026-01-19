# **RFC-007: Terraform Secret Management with 1Password Provider**

**Status:** Accepted<br>
**Date:** 2026-01-08
**Enhances:** [ADR-003: Hybrid Secret Management Strategy](../vidhana/ADR-003-secret-management.md)

---

## **1. Context**

ADR-003 establishes a hybrid secret management strategy using 1Password as the single source of truth and Ansible Vault for offline-capable configuration secrets. However, this ADR primarily details the implementation for Ansible.

Terraform, our provisioning tool, currently has no standardized method for accessing secrets. The common practice of passing secrets via environment variables (`TF_VAR_...` or provider-specific variables like `AWS_ACCESS_KEY_ID`) has several drawbacks:
- **Insecurity:** Secrets can leak into shell history or be exposed in process lists.
- **Manual Effort:** Requires developers to manually export variables before every `terraform` run.
- **Lack of Declarative Dependencies:** The Terraform code itself doesn't declare what secrets it needs, making the dependency implicit and invisible.
- **CI/CD Complexity:** Managing the injection of numerous environment variables into CI/CD pipelines is cumbersome.

We need a secure, declarative, and consistent method for Terraform to consume secrets directly from 1Password, aligning with our established "single source of truth" principle.

---

## **2. Scope**

### **Current (Phase 1):**
- Formally adopt and document the use of the official 1Password Provider for Terraform.
- Define the authentication method for the provider (Service Account Token).
- Establish a standard HCL pattern for fetching and using secrets.
- Update `ADR-003` to reflect this as the official implementation for Terraform.

### **Out of Scope for Now:**
- Migrating all existing Terraform variables to use this provider.
- Implementing secret rotation policies within Terraform.
- Using the provider to *write* secrets to 1Password.

---

## **3. Proposal: Adopt the 1Password Provider for Terraform**

We will integrate the official `1Password/onepassword` Terraform provider as the standard way to inject secrets into our Terraform configurations.

### **Architecture**

This approach allows Terraform to query the 1Password API directly during the `plan` and `apply` phases, using a Service Account Token for authentication.

```
 GitHub Actions / Local Shell
 (Exports OP_SERVICE_ACCOUNT_TOKEN)
             │
             ▼
      Terraform Core
 (Initializes 1Password Provider)
             │
             ▼
   1Password Provider
 (Queries 1Password API)
             │
             ▼
1Password "Project-Brahmanda" Vault
(Returns secret values)
             │
             ▼
   Terraform Resources
 (Secrets used to configure providers like AWS, Cloudflare, etc.)
```

### **Implementation Pattern**

1.  **Provider Configuration:** The provider is configured in `versions.tf` or a dedicated `providers.tf` file. It requires no arguments as it authenticates via an environment variable.

    ```hcl
    # terraform/providers.tf

    terraform {
      required_providers {
        onepassword = {
          source  = "1Password/onepassword"
          version = "~> 1.0"
        }
      }
    }
    ```

2.  **Secret Consumption:** Secrets are fetched using the `onepassword_item` data source. This makes the code declarative and easy to audit.

    ```hcl
    # terraform/kshitiz/main.tf

    # Fetch the AWS credentials from 1Password
    data "onepassword_item" "aws_credentials" {
      vault = "Project-Brahmanda"
      title = "AWS-samsara-iac"
    }

    # Configure the AWS provider using the fetched secrets
    provider "aws" {
      region              = "ap-south-1" # Example region
      access_key          = data.onepassword_item.aws_credentials.username
      secret_key          = data.onepassword_item.aws_credentials.password
    }
    ```
    *(Note: Field names like `username` and `password` are default mappings for Login items in 1Password).*

3.  **Authentication:** Before running `terraform`, the `OP_SERVICE_ACCOUNT_TOKEN` must be exported as an environment variable. This aligns with the CI/CD strategy outlined in ADR-003.

    ```bash
    export OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://Project-Brahmanda/GitHub-Actions-Token/token")
    terraform plan
    ```

---

## **4. Alternatives Considered**

### **Alternative 1: Environment Variables (Status Quo)**

- **Description:** Manually `export`ing variables like `AWS_ACCESS_KEY_ID` before running Terraform.
- **Pros:** Simple for a single, one-off secret. No new dependencies.
- **Cons:** ❌ **Insecure**, not declarative, error-prone, and doesn't scale. Violates the "single source of truth" principle in code.
- **Decision:** **Rejected.** This is the problem we are trying to solve.

### **Alternative 2: Plaintext `.tfvars` Files**

- **Description:** Storing secrets in a `secrets.auto.tfvars` file and adding it to `.gitignore`.
- **Pros:** Separates secrets from configuration.
- **Cons:** ❌ **High risk of accidental commit.** Every developer must manage this file manually, leading to drift. Not a single source of truth.
- **Decision:** **Rejected.** Too insecure and operationally fragile.

### **Alternative 3: HashiCorp Vault**

- **Description:** Deploying and managing a separate HashiCorp Vault instance to serve secrets to Terraform.
- **Pros:** Extremely powerful, feature-rich, and the industry gold standard for large enterprises.
- **Cons:** ❌ **Massive complexity overhead.** Requires deploying, securing, and maintaining a new stateful service (Vault) just to support our existing tools. This violates our "99% Perfection" and "Focus on Current Problems" principles. 1Password is already our chosen secrets hub.
- **Decision:** **Rejected.** Grossly over-engineered for this project's scale and needs.

---

## **5. Consequences**

### **Positive**
- ✅ **Declarative Secrets:** Terraform code now explicitly declares its secret dependencies.
- ✅ **Enhanced Security:** Secrets are fetched in-memory during execution and are not stored in plaintext, shell history, or `.tfvars` files.
- ✅ **Consistency:** Aligns Terraform's secret management strategy with the 1Password-centric approach used by Ansible.
- ✅ **Simplified CI/CD:** Only one secret (`OP_SERVICE_ACCOUNT_TOKEN`) needs to be injected into the CI/CD environment.

### **Negative**
- ⚠️ **New Dependency:** Adds a new Terraform provider to the project.
- ⚠️ **Authentication Prerequisite:** Requires the `OP_SERVICE_ACCOUNT_TOKEN` to be present in the environment before execution, which must be clearly documented.

---

## **6. References**

- [1Password Provider for Terraform Documentation](https://registry.terraform.io/providers/1Password/onepassword/latest/docs)
- [ADR-003: Hybrid Secret Management Strategy](../vidhana/ADR-003-secret-management.md)

---

## **7. Conclusion**

Adopting the official 1Password Terraform provider is a natural extension of our existing secret management strategy. It significantly improves security, developer experience, and code clarity with minimal added complexity.

**Recommendation:** **Accept.** Update `ADR-003` to include this as the standard implementation for Terraform.
