# Learning Terraform: Secret Management

## 1. What: Securely Manage Terraform Secrets

This guide covers how Terraform handles sensitive data (secrets) using external tools and best practices. It clarifies AWS KMS costs and introduces the 1Password Terraform provider.

## 2. Why: Keep Secrets Out of Code

Terraform manages infrastructure, not secrets. Storing secrets (API keys, passwords, SSH keys) directly in `.tf` or `.tfvars` files is risky: they can be exposed in Git, logs, or compromised systems.

**Goal:** Keep secrets out of plain text in Git, retrieve them securely when needed, and use dedicated tools for their lifecycle (rotation, auditing).

## 3. How: Terraform's Secret Approach

Terraform integrates with external secret managers. Key methods:

### a. AWS Key Management Service (KMS) Costs

**What:** AWS KMS manages encryption keys for your data and integrates with other AWS services.

**Cost (Not Free):**
- **Keys (CMKs):** Monthly fee per key, even if unused.
- **API Requests:** Charged for every action (encrypt, decrypt).
- **Free Tier:** Limited free usage, then costs apply.

**Homelab Note:** KMS costs can add up. Evaluate if its advanced features are essential for your homelab needs.

### b. Terraform's Built-in Sensitive Data Handling

- **`sensitive = true` (Variables & Outputs):** Hides values from logs/console (`terraform plan`, `apply`).
  ```terraform
  variable "db_password" {
    sensitive = true # Hides from console output
  }

  output "db_connection_string" {
    value     = "..."
    sensitive = true # Hides from console output
  }
  ```
- **Remote State Storage:** State files (`.tfstate`) can hold sensitive data. Always use encrypted remote backends (e.g., S3 with encryption, Terraform Cloud) with strict access controls.

### c. External Secret Managers

Terraform's best practice is using specialized secret managers:

#### i. HashiCorp Vault

- **`vault` provider:** Reads secrets from HashiCorp Vault.
- **Use:** Complex secret management, dynamic secrets, fine-grained access control.

#### ii. Cloud Secret Managers

- **AWS Secrets Manager, Azure Key Vault, Google Cloud Secret Manager:** Providers to retrieve secrets from cloud-native stores.

#### iii. 1Password Terraform Provider

**What:** The `1password/onepassword` provider fetches secrets directly from your 1Password vaults into Terraform. This fits Project Brahmanda's 1Password strategy.

**Setup (in `versions.tf`):**
```terraform
terraform {
  required_providers {
    onepassword = {
      source  = "1password/onepassword"
      version = "~> 1.0"
    }
    # ...
  }
}
```

**Usage (Example `main.tf`):**
```terraform
# 1. Configure Provider (1Password CLI must be authenticated: `op signin`)
provider "onepassword" { /* ... */ }

# 2. Get Secret Item (e.g., AWS Credentials)
data "onepassword_item" "aws_creds" {
  vault = "Project-Brahmanda"
  title = "AWS-samsara-iac"
}

# 3. Use Secret in Resources (e.g., AWS Provider Config)
# For AWS, env vars or ~/.aws/credentials are typical.
# If direct passing is needed:
# provider "aws" {
#   access_key = data.onepassword_item.aws_creds.field["AWS_ACCESS_KEY_ID"].value
#   secret_key = data.onepassword_item.aws_creds.field["AWS_SECRET_ACCESS_KEY"].value
#   # ...
# }

# Example: SSH Key for a User Data Script (Use with extreme caution!)
data "onepassword_item" "kshitiz_ssh_key" {
  vault = "Project-Brahmanda"
  title = "Kshitiz-Lighthouse-SSH-Key"
}

resource "aws_instance" "my_server" {
  # ...
  user_data = <<-EOF
    echo "${data.onepassword_item.kshitiz_ssh_key.field["private key"].value}" > /home/ubuntu/.ssh/id_rsa
  EOF
  # WARNING: User data scripts expose plaintext secrets in launch configs.
  # Prefer existing key pairs or Ansible for key distribution.
}
```

**Benefits:**
- **Direct Integration:** Less scripting, fewer environment variables.
- **Type Safety:** Terraform understands secret data types.
- **Central Source:** 1Password remains the single source of truth.
- **Security:** Secrets fetched at runtime, not stored in repo plaintext.

## 4. Gotchas & Best Practices

- **No Hardcoding:** Never embed sensitive values in `.tf` or `.tfvars`.
- **Minimize Plaintext:** Use env vars (`TF_VAR_`) or secret managers. Avoid sensitive data in `user_data`.
- **Secure State:** Always use encrypted remote state.
- **Least Privilege:** Terraform runner needs minimal access to secrets.
- **Authentication:** 1Password CLI must be authenticated (e.g., `op signin`, `OP_SERVICE_ACCOUNT_TOKEN` for CI/CD).
- **Audit Logs:** Use logs from KMS, 1Password to track secret access.

## 5. References

- [1Password Terraform Provider](https://registry.terraform.io/providers/1password/onepassword/latest/docs)
- [Terraform Sensitive Data](https://developer.hashicorp.com/terraform/language/values/variables#sensitive-variables)
- [AWS KMS Pricing](https://aws.amazon.com/kms/pricing/)
- [HashiCorp Vault Terraform Provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)