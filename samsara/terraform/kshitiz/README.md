# Kshitiz Terraform Configuration

This directory contains Terraform configuration for the **Kshitiz (Edge Layer)** - AWS Lightsail instance running Nebula Lighthouse.

## Architecture

```
Internet
   ↓
AWS Lightsail (Public IP)
   ├─ Nebula Lighthouse (UDP 4242)
   ├─ SSH Access (TCP 22)
   └─ HTTPS (TCP 443) [Future]

Nebula Mesh Network: 10.42.0.0/16
├─ Lighthouse: 10.42.0.1
└─ Vyom nodes: 10.42.1.x (configured later)
```

## Files

- `versions.tf` - Terraform and provider version constraints
- `main.tf` - AWS Lightsail instance, static IP, firewall rules
- `variables.tf` - Input variables with defaults
- `outputs.tf` - Output values for Ansible and reference
- `user-data.sh` - Initial instance setup script
- `README.md` - This file

## Prerequisites

1. **AWS Credentials** (stored in 1Password):

   ```bash
   export AWS_ACCESS_KEY_ID=$(op read "op://Project-Brahmanda/AWS-samsara-iac/AWS_ACCESS_KEY_ID")
   export AWS_SECRET_ACCESS_KEY=$(op read "op://Project-Brahmanda/AWS-samsara-iac/AWS_SECRET_ACCESS_KEY")
   ```

2. **SSH Key** for accessing Lightsail instance:

   This key should already exist from completing [vaastu/001-Sarga.md](../../../vaastu/001-Sarga.md) Phase 4 (Pramana).

   ```bash
   # Verify key exists
   ls -la ~/.ssh/kshitiz-lighthouse*

   # Retrieve from 1Password if needed
   op read "op://Project-Brahmanda/Kshitiz-Lighthouse-SSH-Key/private key" > ~/.ssh/kshitiz-lighthouse
   chmod 600 ~/.ssh/kshitiz-lighthouse
   ```

3. **Terraform installed** (via `make install_tools`)

## Usage

### Initial Deployment

```bash
# Navigate to directory
cd samsara/terraform/kshitiz

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply configuration
terraform apply

# Save outputs
terraform output -json > outputs.json
```

### Verify Deployment

```bash
# Get connection info
terraform output ssh_connection

# SSH into instance
ssh ubuntu@$(terraform output -raw public_ip)

# Verify Nebula installed
nebula -version
```

## Variables

### Required Variables

None - all variables have sensible defaults.

### Optional Variables

Override via command line or create `terraform.tfvars`:

```hcl
# Custom region
aws_region = "us-west-2"

# Larger instance
instance_bundle_id = "micro_3_0"  # $5/month, 1GB RAM

# Restrict SSH access to your IP
ssh_allowed_cidrs = ["YOUR_IP/32"]

# Custom Nebula network
nebula_network_cidr = "10.42.0.0/16"
lighthouse_nebula_ip = "10.42.0.1/16"
```

## Outputs

After successful apply, useful outputs:

```bash
terraform output public_ip              # Static IP for Lighthouse
terraform output nebula_lighthouse_endpoint  # For client config
terraform output ansible_inventory      # For Ansible playbook
```

## Cost Estimate

- **Lightsail nano_3_0**: $3.50/month (~$42/year)
- **Static IP**: Free (while attached to instance)
- **Data Transfer**: 1TB/month included

**Total**: ~$3.50/month

## Next Steps

After Terraform creates the infrastructure:

1. **Configure Nebula Lighthouse** with Ansible:

   ```bash
   ansible-playbook samsara/ansible/playbooks/01-bootstrap-edge.yml
   ```

2. **Generate Nebula CA and certificates** (done by Ansible)

3. **Test Lighthouse** is reachable from Vyom nodes

## Cleanup

```bash
# Destroy all resources
terraform destroy

# Or use Makefile
make pralaya  # Destroys entire Brahmanda
```

## Troubleshooting

### Instance not accessible

```bash
# Check instance status
aws lightsail get-instance --instance-name kshitiz-lighthouse

# Check firewall rules
aws lightsail get-instance-port-states --instance-name kshitiz-lighthouse
```

### Nebula not running

```bash
# SSH into instance
ssh ubuntu@$(terraform output -raw public_ip)

# Check Nebula status
sudo systemctl status nebula

# Check logs
sudo journalctl -u nebula -f
```

## Security Considerations

1. **SSH Access**: Default allows 0.0.0.0/0 - restrict to your IP in production
2. **Nebula Port**: Must be globally accessible (0.0.0.0/0) for mesh functionality
3. **Static IP**: Doesn't change - safe for DNS/client configs
4. **Firewall**: UFW configured to deny all except required ports

## References

- [AWS Lightsail Documentation](https://docs.aws.amazon.com/lightsail/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Nebula Documentation](https://nebula.defined.net/docs/)
