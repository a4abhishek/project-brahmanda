# Samsara (संसार) - The Cycle of Infrastructure

**Samsara** represents the continuous cycle of creation and destruction in Project Brahmanda. This directory contains all Infrastructure as Code (IaC) for automated provisioning and configuration.

## Philosophy

> "Having cut down this firmly rooted tree with the strong weapon of detachment..." — Bhagavad Gita 15.3

All infrastructure must be:
- **Declarative**: Defined in code, version-controlled
- **Reproducible**: Destroy and recreate at will
- **Idempotent**: Safe to apply multiple times
- **Testable**: Validate locally before automation

## Directory Structure

```
samsara/
├── terraform/          # Infrastructure provisioning
│   ├── kshitiz/       # Edge layer (AWS Lightsail + Nebula)
│   └── vyom/          # Compute layer (Proxmox VMs)
│
├── ansible/           # Configuration management
│   ├── playbooks/     # Automation playbooks
│   ├── templates/     # Configuration templates
│   ├── inventory/     # Host definitions
│   └── group_vars/    # Encrypted variables
│
└── proxmox/           # Proxmox installation automation
    ├── answer.toml    # Template for auto-install
    └── answer.local.toml  # Generated with secrets
```

## Layers

### **Kshitiz (क्षितिज - The Edge/Horizon)**

External access layer - AWS Lightsail running Nebula Lighthouse.

**Location**: `terraform/kshitiz/`

**Purpose**:
- Public internet gateway
- Nebula mesh coordinator (Lighthouse)
- External ingress point for services

**Technologies**:
- AWS Lightsail (Ubuntu 24.04 LTS)
- Nebula overlay network
- Static public IP

**Cost**: ~$3.50/month

**Deploy**:
```bash
cd terraform/kshitiz
terraform init
terraform apply

cd ../../ansible
ansible-playbook -i inventory/hosts.yml playbooks/01-bootstrap-edge.yml
```

See [terraform/kshitiz/DEPLOYMENT.md](terraform/kshitiz/DEPLOYMENT.md) for detailed guide.

### **Vyom (व्योम - The Sky/Space)**

On-premises compute layer - Proxmox VMs running K3s Kubernetes cluster.

**Location**: `terraform/vyom/` *(coming soon)*

**Purpose**:
- Kubernetes cluster (K3s)
- Application workloads
- Persistent storage (Longhorn)
- Local services

**Technologies**:
- Proxmox VE (hypervisor)
- Debian 12 VMs
- K3s (lightweight Kubernetes)
- Nebula client (joins mesh via Kshitiz)

**Cost**: $0 (runs on owned hardware)

**Deploy**: *(not yet implemented)*
```bash
cd terraform/vyom
terraform init
terraform apply

cd ../../ansible
ansible-playbook -i inventory/hosts.yml playbooks/02-bootstrap-cluster.yml
```

## Workflow

### **Local Development (Current Phase)**

```bash
# 1. Setup credentials
export AWS_ACCESS_KEY_ID=$(op read "op://Project-Brahmanda/AWS-samsara-iac/AWS_ACCESS_KEY_ID")
export AWS_SECRET_ACCESS_KEY=$(op read "op://Project-Brahmanda/AWS-samsara-iac/AWS_SECRET_ACCESS_KEY")

# 2. Deploy infrastructure
cd samsara/terraform/kshitiz
terraform init
terraform plan
terraform apply

# 3. Configure with Ansible
cd ../../ansible
ansible-playbook -i inventory/hosts.yml playbooks/01-bootstrap-edge.yml

# 4. Verify deployment
ssh ubuntu@$(cd ../terraform/kshitiz && terraform output -raw public_ip)
```

### **GitHub Actions (Future Phase)**

After local workflow succeeds, automate with GitHub Actions:

```yaml
# .github/workflows/samsara-apply.yml
on:
  push:
    branches: [main]
    paths: ['samsara/**']

jobs:
  deploy:
    - Load secrets from 1Password
    - Terraform plan
    - Terraform apply (on approval)
    - Ansible configure
```

## Secrets Management

**Three-tier approach:**

1. **GitHub Secrets**: Only `OP_SERVICE_ACCOUNT_TOKEN`
2. **1Password**: All actual secrets (AWS keys, SSH keys, passwords)
3. **Ansible Vault**: Encrypted configuration in Git

**Retrieve secrets**:
```bash
# AWS credentials
op read "op://Project-Brahmanda/AWS-samsara-iac/AWS_ACCESS_KEY_ID"

# Ansible vault password
op read "op://Project-Brahmanda/Ansible Vault - Samsara/password"
```

## Vault Management

```bash
# Encrypt vaults (Tirodhana - Concealment)
make tirodhana

# Decrypt vaults (Avirbhava - Manifestation)
make avirbhava

# Edit specific vault (Samshodhana - Editing)
make samshodhana VAULT=kshitiz
```

See [ADR-003: Secret Management](../vaastu/vidhana/ADR-003-secret-management.md) for details.

## Testing

### **Terraform Validation**

```bash
cd terraform/kshitiz

# Validate syntax
terraform validate

# Format code
terraform fmt -recursive

# Security scan
tfsec .

# Plan without applying
terraform plan
```

### **Ansible Validation**

```bash
cd ansible

# Lint playbooks
ansible-lint playbooks/*.yml

# Syntax check
ansible-playbook playbooks/01-bootstrap-edge.yml --syntax-check

# Dry-run
ansible-playbook -i inventory/hosts.yml playbooks/01-bootstrap-edge.yml --check
```

## State Management

### **Terraform State**

**Current**: Local state files (`.tfstate`)

**Future**: Remote backend (S3)

```hcl
# Uncomment in versions.tf after first apply
backend "s3" {
  bucket = "brahmanda-terraform-state"
  key    = "kshitiz/terraform.tfstate"
  region = "us-east-1"
}
```

### **Why Remote State**:
- ✅ Shared across team/CI
- ✅ Locks prevent concurrent changes
- ✅ Encrypted at rest
- ✅ Version history

## Common Tasks

### **Deploy Kshitiz**

```bash
# Complete edge layer setup
cd samsara/terraform/kshitiz
terraform apply

cd ../../ansible
ansible-playbook -i inventory/hosts.yml playbooks/01-bootstrap-edge.yml
```

### **Deploy Vyom**

*(Not yet implemented)*

### **Destroy Everything (Pralaya)**

```bash
# Destroy Vyom first (depends on Kshitiz)
cd samsara/terraform/vyom
terraform destroy

# Then destroy Kshitiz
cd ../kshitiz
terraform destroy
```

Or use Makefile:
```bash
make pralaya  # Interactive destruction
```

### **Update Infrastructure**

```bash
# Modify Terraform files
vim samsara/terraform/kshitiz/main.tf

# Plan changes
terraform plan

# Apply changes
terraform apply

# Reconfigure if needed
cd ../../ansible
ansible-playbook -i inventory/hosts.yml playbooks/01-bootstrap-edge.yml
```

## Troubleshooting

### **Terraform Errors**

```bash
# Refresh state
terraform refresh

# Unlock state (if stuck)
terraform force-unlock <LOCK_ID>

# Taint resource (force recreation)
terraform taint aws_lightsail_instance.lighthouse

# Import existing resource
terraform import aws_lightsail_instance.lighthouse kshitiz-lighthouse
```

### **Ansible Errors**

```bash
# Test connectivity
ansible all -i inventory/hosts.yml -m ping

# Run with verbosity
ansible-playbook -i inventory/hosts.yml playbooks/01-bootstrap-edge.yml -vvv

# Check facts
ansible kshitiz -i inventory/hosts.yml -m setup
```

## Architecture Decisions

Relevant ADRs:
- [ADR-001: Homelab Architecture](../vaastu/vidhana/ADR-001-Homelab-Architecture.md)
- [ADR-003: Secret Management](../vaastu/vidhana/ADR-003-secret-management.md)
- [ADR-004: Security Hardening](../vaastu/vidhana/ADR-004-Security-Hardening.md)

## Cost Breakdown

| Component | Provider | Cost | Notes |
|-----------|----------|------|-------|
| Kshitiz Lighthouse | AWS Lightsail | $3.50/mo | nano_3_0 bundle |
| Vyom Compute | On-premises | $0/mo | Owned hardware |
| AWS data transfer | AWS | $0/mo | 1TB included |
| **Total** | | **$3.50/mo** | **$42/year** |

## Next Steps

1. **Complete Kshitiz deployment** (current task)
   - Deploy Terraform configuration
   - Run Ansible playbook
   - Verify Nebula Lighthouse operational

2. **Create Vyom infrastructure** (next phase)
   - Terraform for Proxmox VMs
   - Ansible for K3s installation
   - Join Vyom nodes to Nebula mesh

3. **Automate with GitHub Actions** (after local success)
   - Create workflow files
   - Test in pull requests
   - Enable auto-apply on merge

4. **Deploy applications** (GitOps with ArgoCD)
   - See `sankalpa/` directory
   - Deploy core infrastructure (Longhorn, monitoring)
   - Deploy applications

## References

- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [AWS Lightsail](https://docs.aws.amazon.com/lightsail/)
- [Nebula Overlay Network](https://nebula.defined.net/)
- [Project Documentation](../vaastu/)
