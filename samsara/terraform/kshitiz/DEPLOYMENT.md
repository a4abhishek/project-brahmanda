# Kshitiz Deployment Guide

This guide walks through deploying the Kshitiz (Edge Layer) - AWS Lightsail + Nebula Lighthouse.

## Prerequisites Checklist

- [ ] AWS account with Lightsail access
- [ ] AWS credentials in 1Password (`AWS-samsara-iac`)
- [ ] Terraform installed (`terraform --version` ≥ 1.9.0)
- [ ] Ansible installed (`ansible --version` ≥ 2.14)
- [ ] 1Password CLI authenticated (`op whoami`)
- [ ] SSH key generated for Lighthouse access

## Phase 1: Prepare Credentials & Environment

### 1. Set 1Password Service Account Token

Before running Terraform, you must export the 1Password Service Account Token. This allows the Terraform provider to authenticate with the 1Password API and fetch the required secrets (like AWS credentials) dynamically.

```bash
# Export the Service Account Token from your 1Password "Project-Brahmanda" vault
export OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://Project-Brahmanda/GitHub-Actions-Token/token")

# Verify the token is set (optional)
echo $OP_SERVICE_ACCOUNT_TOKEN | cut -c 1-10
# Expected: The first 10 characters of your token
```
*💡 TIP: Add the `export` command to your shell's profile (`.bashrc`, `.zshrc`) to avoid running it in every new terminal session.*

### 2. Generate SSH Key for Lighthouse (If not already done)

This key is used for management access to the Lightsail instance.

```bash
# Generate ED25519 key (modern, secure)
ssh-keygen -t ed25519 -f ~/.ssh/kshitiz-lighthouse -C "kshitiz-lighthouse@brahmanda"

# Save to 1Password
op item create --category="SSH Key" \
  --title="Kshitiz Lighthouse SSH Key" \
  --vault="Project-Brahmanda" \
  "private_key[file]=$HOME/.ssh/kshitiz-lighthouse" \
  "public_key[file]=$HOME/.ssh/kshitiz-lighthouse.pub"
```

## Phase 2: Deploy with Terraform

### 1. Initialize Terraform

```bash
cd samsara/terraform/kshitiz

# Download providers (including the 1Password provider)
terraform init

# Verify configuration
terraform validate
```

### 2. Plan Infrastructure

```bash
# See what will be created
terraform plan

# Review output:
# - data.onepassword_item.aws_credentials
# - aws_lightsail_instance.kshitiz
# - aws_lightsail_static_ip.kshitiz
# ... and other resources
```

### 3. Apply Configuration

```bash
# Create infrastructure
terraform apply

# Review and type 'yes' to confirm

# Wait for completion (~2-3 minutes)
```

### 4. Capture Outputs

```bash
# Save all outputs
terraform output -json > outputs.json

# Get specific values
terraform output public_ip
terraform output ssh_connection
terraform output nebula_lighthouse_endpoint

# Example outputs:
# public_ip = "54.123.45.67"
# ssh_connection = "ssh ubuntu@54.123.45.67"
```

## Phase 3: Verify Instance Access

### 1. Wait for Instance to Complete Initialization

```bash
# User-data script takes ~2-3 minutes to complete
# Watch cloud-init logs
ssh -i ~/.ssh/kshitiz-lighthouse ubuntu@$(terraform output -raw public_ip) \
  "tail -f /var/log/cloud-init-output.log"

# Wait for: "=== Initial setup complete ==="
```

### 2. SSH into Instance

```bash
# Connect to Lighthouse
ssh -i ~/.ssh/kshitiz-lighthouse ubuntu@$(terraform output -raw public_ip)

# Verify Nebula installed
nebula -version
# Expected: Nebula v1.10.0 or as per variables.tf

# Check Nebula binaries
ls -lh /usr/local/bin/nebula*
# Expected: nebula, nebula-cert

# Exit
exit
```

## Phase 4: Configure with Ansible

With the infrastructure provisioned by Terraform, the next step is to run the Ansible playbook to configure the instance as a Nebula lighthouse.

### 1. Update Ansible Inventory

First, provide the dynamic IP address of your new instance to Ansible's inventory.

```bash
# Navigate to the kshitiz terraform directory
cd samsara/terraform/kshitiz

# Get the public IP output from your terraform state
LIGHTHOUSE_IP=$(terraform output -raw public_ip)

# Navigate to the ansible directory
cd ../../ansible

# Use 'sed' to replace the placeholder in the inventory file.
# This is a temporary manual step. See RFC-008 for future automation.
sed -i "s/REPLACE_WITH_TERRAFORM_OUTPUT/$$LIGHTHOUSE_IP/" inventory/hosts.yml

echo "INFO: Inventory updated with IP: $$LIGHTHOUSE_IP"
```

### 2. Run the Bootstrap Playbook

Now, run the playbook to configure the server. This will copy the Nebula certificates from your vault and set up the service.

```bash
# From the 'samsara/ansible' directory

# First, test connectivity to the host
ansible kshitiz -m ping

# Expected output: "ping": "pong"

# Run the playbook. Use the vault password from 1Password.
ansible-playbook playbooks/01-bootstrap-kshitiz.yml --vault-password-file <(op read "op://Project-Brahmanda/Ansible Vault - Samsara/password")
```

### 3. Verify Nebula is Running

After the playbook succeeds, you can SSH into the server to verify Nebula is running correctly.

```bash
# SSH to the Lighthouse
ssh -i ~/.ssh/kshitiz-lighthouse ubuntu@$LIGHTHOUSE_IP

# Check Nebula service status (should be active and running)
sudo systemctl status nebula

# Verify Nebula network interface is up and has the correct IP
ip addr show nebula1
# Expected: inet 10.42.0.1/16 ...

# Exit the SSH session
exit
```

## Phase 5: Retrieve Nebula CA

This phase is now obsolete. The Ansible playbook handles the secure distribution of the CA certificate from the 1Password-backed Ansible Vault.

## Verification Checklist

- [x] AWS Lightsail instance running
- [x] Static IP attached
- [x] Firewall rules configured
- [x] Terraform successfully fetched credentials from 1Password
- [x] SSH access works with key
- [x] **Ansible playbook ran successfully and configured the instance**
- [x] **Nebula service is active (`systemctl status nebula`)**
- [x] **Nebula interface is up with correct IP (`ip addr show nebula1`)**

## Common Issues

### Issue: Terraform fails with a 1Password authentication error

```bash
# Error: "failed to get service account: 1password-cli desktop integration is not available"
# OR
# Error: "No OP_SERVICE_ACCOUNT_TOKEN environment variable set"

# Solution: Verify the service account token is exported correctly.
echo $OP_SERVICE_ACCOUNT_TOKEN

# Re-export if needed
export OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://Project-Brahmanda/GitHub-Actions-Token/token")

# Ensure you have also run `op signin` at least once.
op whoami
```

### Issue: SSH connection refused

```bash
# Wait for cloud-init to complete
# Takes 2-3 minutes after instance creation

# Check instance console output from the AWS Management Console
# or via the AWS CLI:
aws lightsail get-instance-console-output --instance-name kshitiz-lighthouse
```

### Issue: Ansible can't connect

```bash
# Verify SSH key path
ls -l ~/.ssh/kshitiz-lighthouse

# Test manual SSH with verbose output
ssh -i ~/.ssh/kshitiz-lighthouse -v ubuntu@$(terraform output -raw public_ip)

# Check inventory file has the correct IP
cat samsara/ansible/inventory/hosts.yml | grep ansible_host
```

### Issue: Nebula service fails to start

```bash
# SSH into instance
ssh -i ~/.ssh/kshitiz-lighthouse ubuntu@$(terraform output -raw public_ip)

# Check service logs for errors
sudo journalctl -u nebula -n 50

# Common issues:
# - Missing certificates (check /etc/nebula/) -> Did Ansible run correctly?
# - Config syntax error (validate Ansible-generated config.yml)
# - Port already in use (check `sudo netstat -ulnp`)

# Restart service after fixing
sudo systemctl restart nebula
```

## Cost Tracking

- **Lightsail nano_3_0**: $3.50/month
- **Data transfer**: First 1TB included
- **Static IP**: Free while attached

**Estimated monthly cost: $3.50**

## Next Steps

After successful Kshitiz deployment and Ansible configuration:

1. Create Vyom VMs and join them to the Nebula mesh.
2. Deploy the K3s Kubernetes cluster.
3. Configure Ingress to route traffic from Kshitiz to services in Vyom.

See `vaastu/003-Visarga.md` for operational procedures.

## Cleanup (Pralaya)

To destroy all Kshitiz resources:

```bash
cd samsara/terraform/kshitiz

# Ensure OP_SERVICE_ACCOUNT_TOKEN is set
export OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://Project-Brahmanda/GitHub-Actions-Token/token")

# Destroy infrastructure
terraform destroy

# Type 'yes' to confirm
```

## References

- [1Password Terraform Provider](https://registry.terraform.io/providers/1Password/onepassword/latest/docs)
- [AWS Lightsail Documentation](https://docs.aws.amazon.com/lightsail/)
- [Nebula Documentation](https://nebula.defined.net/docs/)
- [RFC-007: Terraform Secret Management](../../vaastu/manthana/RFC-007-Terraform-Secret-Management.md)
