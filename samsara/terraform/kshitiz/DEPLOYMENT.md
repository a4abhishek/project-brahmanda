# Kshitiz Deployment Guide

This guide walks through deploying the Kshitiz (Edge Layer) - AWS Lightsail + Nebula Lighthouse.

## Prerequisites Checklist

- [ ] AWS account with Lightsail access
- [ ] AWS credentials in 1Password (`AWS-samsara-iac`)
- [ ] Terraform installed (`terraform --version` ≥ 1.9.0)
- [ ] Ansible installed (`ansible --version` ≥ 2.14)
- [ ] 1Password CLI authenticated (`op whoami`)
- [ ] SSH key generated for Lighthouse access

## Phase 1: Prepare Credentials

### 1. Load AWS Credentials

```bash
# Export AWS credentials from 1Password
export AWS_ACCESS_KEY_ID=$(op read "op://Project-Brahmanda/AWS-samsara-iac/AWS_ACCESS_KEY_ID")
export AWS_SECRET_ACCESS_KEY=$(op read "op://Project-Brahmanda/AWS-samsara-iac/AWS_SECRET_ACCESS_KEY")

# Verify credentials work
aws sts get-caller-identity
```

### 2. Generate SSH Key for Lighthouse

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

# Download providers
terraform init

# Verify configuration
terraform validate
```

### 2. Plan Infrastructure

```bash
# See what will be created
terraform plan

# Review output:
# - aws_lightsail_instance.lighthouse
# - aws_lightsail_static_ip.lighthouse
# - aws_lightsail_static_ip_attachment.lighthouse
# - aws_lightsail_instance_public_ports.lighthouse
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
# Expected: Nebula v1.9.5

# Check Nebula binaries
ls -lh /usr/local/bin/nebula*
# Expected: nebula, nebula-cert

# Exit
exit
```

## Phase 4: Configure with Ansible

### 1. Update Ansible Inventory

```bash
# Get Lighthouse public IP
LIGHTHOUSE_IP=$(cd samsara/terraform/kshitiz && terraform output -raw public_ip)

# Update inventory
cd samsara/ansible

# Edit inventory/hosts.yml
# Replace REPLACE_WITH_TERRAFORM_OUTPUT with $LIGHTHOUSE_IP
sed -i "s/REPLACE_WITH_TERRAFORM_OUTPUT/$LIGHTHOUSE_IP/" inventory/hosts.yml

# Or manually edit:
vim inventory/hosts.yml
```

### 2. Test Ansible Connectivity

```bash
# Ping Lighthouse
ansible kshitiz -i inventory/hosts.yml -m ping

# Expected output:
# kshitiz-lighthouse | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

### 3. Run Bootstrap Playbook

```bash
# Configure Nebula Lighthouse
ansible-playbook -i inventory/hosts.yml playbooks/01-bootstrap-edge.yml

# What it does:
# 1. Generates Nebula CA and certificates
# 2. Deploys Lighthouse configuration
# 3. Creates systemd service
# 4. Starts Nebula and verifies interface
```

### 4. Verify Nebula is Running

```bash
# SSH to Lighthouse
ssh -i ~/.ssh/kshitiz-lighthouse ubuntu@$LIGHTHOUSE_IP

# Check Nebula service
sudo systemctl status nebula

# Verify Nebula interface
ip addr show nebula1
# Expected: inet 10.42.0.1/16

# Check Nebula is listening
sudo netstat -ulnp | grep 4242
# Expected: udp 0.0.0.0:4242

# Test Prometheus metrics
curl http://127.0.0.1:8080/metrics

exit
```

## Phase 5: Retrieve Nebula CA

The Nebula CA certificate is needed to join other nodes to the mesh.

### 1. Download CA Certificate

```bash
# Copy CA cert to local machine
scp -i ~/.ssh/kshitiz-lighthouse \
  ubuntu@$LIGHTHOUSE_IP:/etc/nebula/ca.crt \
  /tmp/brahmanda-nebula-ca.crt

# View certificate
nebula-cert print -path /tmp/brahmanda-nebula-ca.crt
```

### 2. Store CA in 1Password

```bash
# Save to 1Password for future use
op document create /tmp/brahmanda-nebula-ca.crt \
  --title="Brahmanda Nebula CA Certificate" \
  --vault="Project-Brahmanda" \
  --tags="nebula,ca,certificate"

# Also save CA key (HIGHLY SENSITIVE)
scp -i ~/.ssh/kshitiz-lighthouse \
  ubuntu@$LIGHTHOUSE_IP:/etc/nebula/ca.key \
  /tmp/brahmanda-nebula-ca.key

op document create /tmp/brahmanda-nebula-ca.key \
  --title="Brahmanda Nebula CA Private Key" \
  --vault="Project-Brahmanda" \
  --tags="nebula,ca,private-key"

# Remove local copies
rm /tmp/brahmanda-nebula-ca.*
```

## Verification Checklist

- [ ] AWS Lightsail instance running
- [ ] Static IP attached
- [ ] Firewall rules configured (SSH, Nebula, HTTPS)
- [ ] SSH access works with key
- [ ] Nebula binary installed (`nebula -version`)
- [ ] Nebula CA generated
- [ ] Nebula service running (`systemctl status nebula`)
- [ ] Nebula interface up (`ip addr show nebula1`)
- [ ] Nebula listening on UDP 4242
- [ ] Prometheus metrics accessible
- [ ] CA certificate stored in 1Password

## Common Issues

### Issue: Terraform fails with AWS credentials

```bash
# Error: "NoCredentialProviders: no valid providers in chain"

# Solution: Verify credentials exported
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY

# Re-export if needed
export AWS_ACCESS_KEY_ID=$(op read "op://Project-Brahmanda/AWS-samsara-iac/AWS_ACCESS_KEY_ID")
export AWS_SECRET_ACCESS_KEY=$(op read "op://Project-Brahmanda/AWS-samsara-iac/AWS_SECRET_ACCESS_KEY")
```

### Issue: SSH connection refused

```bash
# Wait for cloud-init to complete
# Takes 2-3 minutes after instance creation

# Check instance console output
aws lightsail get-instance-console-output --instance-name kshitiz-lighthouse
```

### Issue: Ansible can't connect

```bash
# Verify SSH key path
ls -l ~/.ssh/kshitiz-lighthouse

# Test manual SSH
ssh -i ~/.ssh/kshitiz-lighthouse -v ubuntu@$LIGHTHOUSE_IP

# Check inventory file has correct IP
cat inventory/hosts.yml | grep ansible_host
```

### Issue: Nebula service fails to start

```bash
# SSH to instance
ssh -i ~/.ssh/kshitiz-lighthouse ubuntu@$LIGHTHOUSE_IP

# Check service logs
sudo journalctl -u nebula -n 50

# Common issues:
# - Missing certificates (check /etc/nebula/)
# - Config syntax error (validate config.yml)
# - Port already in use (check netstat)

# Restart service
sudo systemctl restart nebula
```

## Cost Tracking

- **Lightsail nano_3_0**: $3.50/month
- **Data transfer**: First 1TB included
- **Static IP**: Free while attached

**Estimated monthly cost: $3.50**

## Next Steps

After successful Kshitiz deployment:

1. **Create Vyom VMs** - Proxmox VMs for K3s cluster
2. **Join Vyom to mesh** - Issue Nebula certificates for compute nodes
3. **Test mesh connectivity** - Ping between Kshitiz and Vyom
4. **Deploy K3s** - Kubernetes cluster on Vyom nodes
5. **Configure ingress** - Route external traffic through Kshitiz

See `vaastu/002-Visarga.md` for operational procedures.

## Cleanup (Pralaya)

To destroy all Kshitiz resources:

```bash
cd samsara/terraform/kshitiz

# Destroy infrastructure
terraform destroy

# Type 'yes' to confirm

# Verify cleanup
aws lightsail get-instances --query "instances[?name=='kshitiz-lighthouse']"
# Expected: empty list
```

## References

- [AWS Lightsail](https://docs.aws.amazon.com/lightsail/)
- [Nebula Documentation](https://nebula.defined.net/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [RFC-001: Homelab Architecture](../../vaastu/manthana/RFC-001-Homelab-Architecture.md)
