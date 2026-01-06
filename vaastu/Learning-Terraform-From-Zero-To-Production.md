# Learning Terraform: From Zero to Production

**Purpose:** A practical guide showing how to write production-grade Terraform code from scratch, using the Kshitiz (AWS Lightsail) infrastructure as a real-world example.

**Learning Approach:** We'll build incrementally, starting with the simplest working code and progressively adding production features. Each section explains *why* we make certain choices.

---

## **Phase 1: Absolute Minimum - Make It Work**

**Goal:** Get *something* deployed. No organization, no best practices—just prove Terraform works.

### **Step 1: Create Your First File**

Start with a single file that does everything:

```hcl
# main.tf - The absolute minimum to deploy something

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_lightsail_instance" "lighthouse" {
  name              = "my-lighthouse"
  availability_zone = "us-east-1a"
  blueprint_id      = "ubuntu_24_04"̥
  bundle_id         = "nano_3_0"
}
```

**Run it:**

```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

terraform init    # Downloads AWS provider
terraform plan    # Shows what will be created
terraform apply   # Creates the instance
```

**What you learned:**

- ✅ Terraform has three blocks: `terraform {}`, `provider {}`, `resource {}`
- ✅ `terraform init` downloads providers (only needed once or when providers change)
- ✅ `terraform plan` is a dry-run (safe to run anytime)
- ✅ `terraform apply` makes real changes (creates/modifies/destroys infrastructure)
- ✅ Terraform creates a `terraform.tfstate` file (tracks what's deployed)

💡 **TIP: State File is Critical**

- The `terraform.tfstate` file is Terraform's memory
- Without it, Terraform doesn't know what infrastructure exists
- NEVER delete state file manually
- NEVER commit state file to Git (contains secrets)
- We'll move to remote state in Phase 6

⚠️ **ANTI-PATTERN: Running apply without plan**

- Always run `terraform plan` first to review changes
- Use `terraform plan -out=tfplan` then `terraform apply tfplan` for safety
- Never blindly run `terraform apply -auto-approve` in production

**Problems with this approach:**

- ❌ Hardcoded values (region, bundle ID)
- ❌ No outputs (how do I get the IP address?)
- ❌ Everything in one file (gets messy quickly)
- ❌ No documentation
- ❌ State file stored locally (can't share with team)

---

## **Phase 2: Organization - Make It Maintainable**

**Goal:** Split into logical files, add variables and outputs.

### **Step 2: Separate Concerns**

Terraform doesn't care about file names, but humans do. Standard convention:

```
my-infrastructure/
├── versions.tf      # Terraform and provider version constraints
├── providers.tf     # Provider configuration (was just "provider" block before, but now we add more config)
├── main.tf          # Primary resources
├── variables.tf     # Input variables (things you can customize)
├── outputs.tf       # Output values (things you want to know after deployment)
└── README.md        # Documentation
```

✨ **BEST PRACTICE: File Naming Convention**

- **versions.tf**: ALWAYS separate - version changes are rare, keeping them isolated makes git diffs cleaner
- **providers.tf**: Provider config (region, default tags)
- **main.tf**: Core infrastructure resources
- **variables.tf**: All input variables with descriptions and defaults
- **outputs.tf**: All outputs with descriptions
- **data-sources.tf**: Data lookups (optional but recommended)
- **locals.tf**: Computed values (optional but recommended)

💡 **TIP: Split Large main.tf Files**
As projects grow, split main.tf by resource type:

- `compute.tf` - EC2, Lightsail instances
- `network.tf` - VPCs, subnets, security groups
- `storage.tf` - S3 buckets, EBS volumes
- `firewall.tf` - Security rules

⚠️ **ANTI-PATTERN: Random File Names**

- DON'T: `lightsail.tf`, `my-stuff.tf`, `resources.tf`
- These names don't follow conventions and confuse team members
- Stick to established patterns for consistency

**versions.tf** - Lock down versions:

```hcl
terraform {
  required_version = ">= 1.9.0"  # Specific minimum version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # ~> means "5.x" (allows 5.1, 5.2, but not 6.0)
    }
  }
}
```

**Why separate?** Version changes are rare. Keeping them separate makes git diffs cleaner.

✨ **BEST PRACTICE: Version Constraints**

- **Terraform version**: Use `>= X.Y.Z` to allow newer versions
  - Example: `>= 1.9.0` allows 1.9.x, 1.10.x, 2.x, etc.
- **Provider version**: Use `~> X.Y` for controlled updates
  - `~> 5.0` → Allows 5.1, 5.2, 5.99 but NOT 6.0
  - `~> 5.1` → Allows 5.1.1, 5.1.2 but NOT 5.2.0
- **Why pessimistic constraint (~>)?** Prevents breaking changes from major version bumps

💡 **TIP: Why Terraform >= 1.9.0 for This Project?**
Project Brahmanda requires Terraform >= 1.9.0 for several reasons:

- **Improved provider protocol**: Better error messages and faster operations
- **Enhanced state management**: More robust handling of complex dependencies
- **Security fixes**: Critical vulnerabilities patched in 1.9.x series
- **AWS provider compatibility**: Modern AWS features require recent Terraform versions

**What happens if you use an older version?**

```bash
$ terraform init
Error: Unsupported Terraform Core version
  on versions.tf line 2, in terraform:
   2:   required_version = ">= 1.9.0"

This configuration does not support Terraform version 1.2.3.
```

**How to upgrade:**

```bash
# Project Brahmanda provides automated upgrade via make init
make init    # Checks version, installs/upgrades Terraform if needed

# Or manually:
# Ubuntu/Debian (via HashiCorp APT repo)
sudo apt-get update && sudo apt-get install terraform

# macOS (via Homebrew)
brew upgrade terraform

# Verify version
terraform version
```

💡 **TIP: Lock File (.terraform.lock.hcl)**

- Created by `terraform init`
- Locks exact provider versions used
- COMMIT this file to Git (ensures team uses same versions)
- Update with: `terraform init -upgrade`

⚠️ **ANTI-PATTERN: No Version Constraints**

- DON'T: `version = "5.0.0"` (too restrictive, misses bug fixes)
- DON'T: No version constraint (uses latest, breaks on major updates)
- DON'T: `version = ">= 1.0"` (too permissive, allows breaking changes)

**providers.tf** - Configure the provider:

```hcl
provider "aws" {
  region = var.aws_region  # Now uses a variable instead of hardcoding

  default_tags {
    tags = {
      Project   = "MyProject"
      ManagedBy = "Terraform"
    }
  }
}
```

**Why default_tags?** Every resource gets these tags automatically. Helps with cost tracking and organization.

✨ **BEST PRACTICE: Tagging Strategy**

- **Always use default_tags** - Ensures every resource is tagged
- **Minimum recommended tags:**
  - `Project` - Which project/product
  - `Environment` - dev/staging/production
  - `ManagedBy` - "Terraform" (vs manual/CloudFormation)
  - `Owner` or `Team` - Who owns this resource
  - `CostCenter` - For billing allocation
- **Merge with resource-specific tags:**

  ```hcl
  tags = merge(local.common_tags, {
    Name = "specific-resource-name"
    Role = "webserver"
  })
  ```

💡 **TIP: Tags Enable Cost Tracking**

- Filter AWS Cost Explorer by Project tag
- Create billing alerts per environment
- Track spend per team/department

⚠️ **ANTI-PATTERN: Inconsistent Tagging**

- DON'T tag some resources but not others
- DON'T use different tag names (Project vs project vs ProjectName)
- DON'T hardcode tags in every resource (use default_tags + locals)

✨ **BEST PRACTICE: Security First**

- **Firewall rules are code** - Never configure manually in console
- **Principle of Least Privilege** - Open only required ports
- **Restrict SSH** - Use specific IP, not `0.0.0.0/0` in production
- **Document why ports are open** - Comments explain security decisions

💡 **TIP: Security Layers**

1. **Cloud firewall** (AWS Security Groups, Lightsail firewall) - First layer
2. **OS firewall** (UFW, iptables) - Defense in depth
3. **Application** - Authentication/authorization

Example security progression:

- **Development**: SSH from anywhere (convenience)
- **Staging**: SSH from office IP only
- **Production**: SSH from bastion host only + VPN

⚠️ **ANTI-PATTERN: Open to World**

- DON'T: `cidrs = ["0.0.0.0/0"]` for SSH in production
- DO: `cidrs = ["203.0.113.10/32"]` (your IP)
- DO: Document exceptions (e.g., Nebula UDP port needs 0.0.0.0/0)

**variables.tf** - Make values configurable:

```hcl
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_bundle_id" {
  description = "Lightsail bundle (size/price tier)"
  type        = string
  default     = "nano_3_0"

  # Document available options in comments
  # nano_3_0   - $3.50/month - 512MB RAM
  # micro_3_0  - $5.00/month - 1GB RAM
  # small_3_0  - $10.00/month - 2GB RAM
}

variable "instance_name" {
  description = "Name for the Lightsail instance"
  type        = string
  default     = "lighthouse"
}
```

**Why variables?**

- Can override defaults: `terraform apply -var="instance_bundle_id=micro_3_0"`
- Can use terraform.tfvars file for environment-specific values
- Self-documenting with descriptions

✨ **BEST PRACTICE: Variable Structure**
EVERY variable should have:

1. **description** - What it does (required for readability)
2. **type** - string, number, bool, list(), map(), object() (catches mistakes early)
3. **default** - Default value (optional, but recommended for non-sensitive values)
4. **validation** - Validation rules (optional, but great for enums/patterns)

💡 **TIP: Variable Naming Convention**

- Use `snake_case` (Terraform convention)
- Be specific: `instance_bundle_id` not `bundle`
- Group related variables with prefixes:
  - `nebula_version`, `nebula_network`, `nebula_port`
  - `aws_region`, `aws_availability_zones`

💡 **TIP: Variable Overrides (Priority Order)**

1. CLI: `-var="key=value"` (highest priority)
2. `.auto.tfvars` files (loaded automatically)
3. `terraform.tfvars` file (standard convention)
4. `TF_VAR_name` environment variables
5. Default value in `variables.tf` (lowest priority)

⚠️ **ANTI-PATTERN: Missing Descriptions**

- DON'T create variables without descriptions
- Future you (and your team) won't remember what they do

⚠️ **ANTI-PATTERN: Untyped Variables**

- DON'T: `variable "count" {}` (no type = accepts anything)
- DO: `variable "instance_count" { type = number }` (validates input)

**main.tf** - Now much cleaner:

```hcl
resource "aws_lightsail_instance" "lighthouse" {
  name              = var.instance_name
  availability_zone = "${var.aws_region}a"  # Construct from region
  blueprint_id      = "ubuntu_24_04"
  bundle_id         = var.instance_bundle_id

  tags = {
    Name = var.instance_name
    Role = "lighthouse"
  }
}

# Static IP (won't change on recreate)
resource "aws_lightsail_static_ip" "lighthouse" {
  name = "${var.instance_name}-ip"
}

# Attach static IP to instance
resource "aws_lightsail_static_ip_attachment" "lighthouse" {
  static_ip_name = aws_lightsail_static_ip.lighthouse.name
  instance_name  = aws_lightsail_instance.lighthouse.name
}
```

**outputs.tf** - Get useful information after deployment:

```hcl
output "public_ip" {
  description = "Public IP address of the Lightsail instance"
  value       = aws_lightsail_static_ip.lighthouse.ip_address
}

output "ssh_connection" {
  description = "SSH connection string"
  value       = "ssh ubuntu@${aws_lightsail_static_ip.lighthouse.ip_address}"
}

output "instance_id" {
  description = "Instance ID for reference"
  value       = aws_lightsail_instance.lighthouse.id
}
```

**Why outputs?** After `terraform apply`, you can:

```bash
terraform output public_ip           # Get just the IP
terraform output -json > outputs.json  # Save all outputs for scripts
```

**Run it:**

```bash
terraform init    # Re-run if you added new files (safe to run anytime)
terraform plan    # Review changes
terraform apply   # Deploy

# After deployment:
terraform output public_ip
# Outputs: 54.123.45.67

ssh ubuntu@$(terraform output -raw public_ip)
```

**What you learned:**

- ✅ File organization matters for maintainability
- ✅ Variables make code reusable
- ✅ Outputs make results accessible
- ✅ Resource references: `aws_lightsail_static_ip.lighthouse.name`
- ✅ String interpolation: `"${var.region}a"`

✨ **BEST PRACTICE: Resource References**

- **Implicit dependencies** - Terraform understands relationships:

  ```hcl
  resource "aws_lightsail_static_ip_attachment" "lighthouse" {
    static_ip_name = aws_lightsail_static_ip.lighthouse.name
    instance_name  = aws_lightsail_instance.lighthouse.name
    # Terraform knows: create IP and instance BEFORE attachment
  }
  ```

- **Reference syntax**: `resource_type.resource_name.attribute`
- Terraform builds a dependency graph automatically

💡 **TIP: String Interpolation**

- **With variables**: `"${var.region}a"` - Use when mixing variables and literals
- **Direct reference**: `var.region` - Use when passing entire value
- **Legacy syntax**: `"${var.region}"` works but unnecessary (use `var.region` directly)
- **Escape literal $**: Use `$${literal}` in templates

⚠️ **ANTI-PATTERN: Hardcoded Dependencies**

- DON'T reference IDs manually: `instance_id = "i-1234567890abcdef"`
- DO use references: `instance_id = aws_instance.web.id`
- Terraform handles creation order automatically

---

## **Phase 3: Data Sources - Use Existing Information**

**Goal:** Don't hardcode things that AWS already knows.

### **Step 3: Look Up Information Dynamically**

**Problem:** Blueprint IDs change between regions and over time. Hardcoding `blueprint_id = "ubuntu_24_04"` will break.

**Solution:** Use data sources to query AWS:

```hcl
# data-sources.tf (or add to main.tf)

# Find the latest Ubuntu 24.04 blueprint
data "aws_lightsail_blueprint" "ubuntu" {
  type = "os"

  filter {
    name   = "name"
    values = ["ubuntu_24_04"]
  }
}

# Find available instance bundles (optional, for reference)
data "aws_lightsail_bundles" "available" {
  type = "instance"
}

# Now use in main.tf:
resource "aws_lightsail_instance" "lighthouse" {
  name              = var.instance_name
  availability_zone = "${var.aws_region}a"
  blueprint_id      = data.aws_lightsail_blueprint.ubuntu.id  # Dynamic lookup
  bundle_id         = var.instance_bundle_id

  # ... rest of config
}
```

**What you learned:**

- ✅ `data` blocks query existing infrastructure
- ✅ Data sources don't create anything (read-only)
- ✅ Use them to avoid hardcoding IDs, AMIs, availability zones
- ✅ Reference like resources: `data.aws_lightsail_blueprint.ubuntu.id`

✨ **BEST PRACTICE: When to Use Data Sources**

- ✅ Looking up AMIs/blueprints (change over time)
- ✅ Getting availability zones in a region
- ✅ Finding existing VPCs/subnets (shared infrastructure)
- ✅ Retrieving account ID, region dynamically
- ✅ Fetching secrets from Parameter Store/Secrets Manager

💡 **TIP: Data Source Performance**

- Data sources query APIs on EVERY `terraform plan`/`apply`
- Can slow down large projects (hundreds of data sources)
- Cache in locals if used multiple times:

  ```hcl
  locals {
    ubuntu_blueprint = data.aws_lightsail_blueprint.ubuntu.id
  }
  # Then use: local.ubuntu_blueprint everywhere
  ```

⚠️ **ANTI-PATTERN: Data Source for Everything**

- DON'T query data that rarely changes (e.g., region names, standard ports)
- DON'T use data sources for values you can hardcode safely
- DO use variables for configuration values
- DO use data sources for dynamic infrastructure lookups

⚠️ **ANTI-PATTERN: Hardcoding What Should Be Dynamic**

- DON'T: `ami = "ami-12345678"` (AMI IDs change per region/time)
- DO: Use `aws_ami` data source with filters:

  ```hcl
  data "aws_ami" "ubuntu" {
    most_recent = true
    owners      = ["099720109477"]  # Canonical
    filter {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-*-24.04-amd64-server-*"]
    }
  }
  ```

---

## **Phase 4: Production Features - Security & Firewall**

**Goal:** Add firewall rules, user data, proper security.

### **Step 4: Secure Your Infrastructure**

**Add firewall rules:**

```hcl
# main.tf (add to existing resources)

resource "aws_lightsail_instance_public_ports" "lighthouse" {
  instance_name = aws_lightsail_instance.lighthouse.name

  # SSH access
  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidrs     = var.ssh_allowed_cidrs  # Configurable
  }

  # Nebula mesh port
  port_info {
    protocol  = "udp"
    from_port = 4242
    to_port   = 4242
    cidrs     = ["0.0.0.0/0"]  # Must be global for mesh
  }

  # HTTPS
  port_info {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
    cidrs     = ["0.0.0.0/0"]
  }
}
```

**Add to variables.tf:**

```hcl
variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Open to world

  # Production: Use your IP
  # default = ["203.0.113.10/32"]
}
```

**Add initialization script:**

```hcl
# user-data.sh (separate file - better for large scripts)
#!/bin/bash
set -euo pipefail

echo "=== Initial Setup ==="
apt-get update
apt-get upgrade -y
apt-get install -y curl wget vim htop

# Configure firewall
ufw --force enable
ufw allow 22/tcp
ufw allow 4242/udp
ufw allow 443/tcp

echo "=== Setup Complete ==="
```

**Reference in main.tf:**

```hcl
resource "aws_lightsail_instance" "lighthouse" {
  # ... existing config ...

  user_data = file("${path.module}/user-data.sh")  # Load from file

  # Alternative: Inline (for small scripts)
  # user_data = <<-EOF
  #   #!/bin/bash
  #   apt-get update
  #   apt-get install -y nginx
  # EOF
}
```

**What you learned:**

- ✅ Security is a first-class concern (not an afterthought)
- ✅ Firewall rules are managed as code
- ✅ User data scripts automate initial setup
- ✅ `file()` function loads external files
- ✅ `path.module` ensures paths work regardless of where you run Terraform

✨ **BEST PRACTICE: User Data Scripts**

- **Use external files** for scripts >10 lines (better readability/testing)
- **Start with shebang**: `#!/bin/bash`
- **Use set -euo pipefail**: Exit on error, unset variables, pipe failures
- **Log everything**: User data logs to `/var/log/cloud-init-output.log`
- **Idempotent operations**: Script may run multiple times

💡 **TIP: User Data Limitations**

- **Runs once**: Only on first boot (unless using cloud-init modules)
- **No Terraform awareness**: Can't access `terraform apply` output
- **Limited error visibility**: Check `/var/log/cloud-init.log` if issues
- **Better alternative**: Use Ansible after instance creation for:
  - Complex configuration
  - Multi-step setup
  - Configuration management

💡 **TIP: User-Data vs Ansible - What Goes Where?**

**User-Data = Complete the Resource:**

- Minimal config that makes the instance logically complete for its role
- Think: "Instance + user-data = one customized resource unit"
- Examples: Python for Ansible, basic firewall, hostname, monitoring agent

**Ansible = Everything Else:**

- Application deployment, complex configuration, secrets management
- Ongoing maintenance and updates
- Can be re-run without recreating the instance

**Why separate?**

- **User-data is immutable** - Changes require instance recreation
- **Ansible is flexible** - Update existing instances anytime, no downtime
- **Better visibility** - Ansible has superior error handling and logging
- **Version-controlled** - Playbooks are testable and auditable

💡 **TIP: Debugging User Data**

```bash
# SSH into instance and check:
sudo cat /var/log/cloud-init-output.log  # Script output
sudo cloud-init status                    # Check if complete
sudo cloud-init analyze show              # Timing info
```

⚠️ **ANTI-PATTERN: Inline User Data for Large Scripts**

- DON'T: 100+ line user_data in HCL (unreadable, no syntax highlighting)
- DO: External .sh or .tpl file

⚠️ **ANTI-PATTERN: Secrets in User Data**

- DON'T: `apt-get install mysql && mysql -pPASSWORD123`
- Secrets visible in EC2 metadata, logs, Terraform state
- DO: Fetch secrets from Secrets Manager/Parameter Store in script
- DO: Use IAM roles for API access (no hardcoded credentials)

---

## **Phase 5: Advanced Patterns - Locals, Templates, Dependencies**

**Goal:** Reduce repetition, use advanced Terraform features.

### **Step 5: Use Locals for Computed Values**

**locals.tf** (or add to main.tf):

```hcl
locals {
  # Computed naming convention
  resource_prefix = "${var.project_name}-${var.environment}"

  # Common tags
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CostCenter  = "Engineering"
  }

  # Availability zone (computed from region)
  availability_zone = "${var.aws_region}a"

  # Full instance name
  instance_name = "${local.resource_prefix}-lighthouse"
}

# Use in resources:
resource "aws_lightsail_instance" "lighthouse" {
  name              = local.instance_name
  availability_zone = local.availability_zone

  tags = merge(local.common_tags, {
    Name = local.instance_name
    Role = "Lighthouse"
  })

  # ... rest of config
}
```

**Why locals?**

- ✅ DRY (Don't Repeat Yourself)
- ✅ Computed values (concatenation, conditionals)
- ✅ Variables can't reference other variables, but locals can

✨ **BEST PRACTICE: Variables vs Locals**

- **Variables** (`var.X`):
  - User configurable (overridable)
  - External input to module
  - Example: `var.environment`, `var.instance_size`
- **Locals** (`local.X`):
  - Computed/derived values
  - DRY (avoid repeating expressions)
  - Example: `local.resource_prefix = "${var.project}-${var.env}"`

💡 **TIP: When to Use Locals**

1. **Avoid repetition:**

   ```hcl
   locals {
     common_tags = { Project = "Brahmanda", Env = var.environment }
   }
   # Use merge(local.common_tags, {...}) in every resource
   ```

2. **Complex expressions:**

   ```hcl
   locals {
     is_production = var.environment == "production"
     instance_count = local.is_production ? 3 : 1
   }
   ```

3. **Resource references:**

   ```hcl
   locals {
     instance_ips = [for i in aws_instance.web : i.private_ip]
   }
   ```

⚠️ **ANTI-PATTERN: Everything in Locals**

- DON'T move all variables to locals
- Locals can't be overridden by users
- Keep user-configurable values as variables

⚠️ **ANTI-PATTERN: Locals for Simple Values**

- DON'T: `locals { region = "us-east-1" }`
- DO: `variable "region" { default = "us-east-1" }`
- Use locals for COMPUTED values, variables for CONFIGURABLE values

### **Step 6: Use Templates for Complex User Data**

**user-data.sh.tpl** (template file):

```bash
#!/bin/bash
set -euo pipefail

echo "=== Lightsail Setup for ${instance_name} ==="

# Variables injected by Terraform
NEBULA_VERSION="${nebula_version}"
LIGHTHOUSE_IP="${lighthouse_ip}"

apt-get update
apt-get upgrade -y

# Download Nebula
wget -q "https://github.com/slackhq/nebula/releases/download/v$${NEBULA_VERSION}/nebula-linux-amd64.tar.gz"
tar -xzf nebula-linux-amd64.tar.gz
mv nebula nebula-cert /usr/local/bin/

echo "Nebula $${NEBULA_VERSION} installed for $${LIGHTHOUSE_IP}"
```

**Reference in main.tf:**

```hcl
resource "aws_lightsail_instance" "lighthouse" {
  # ... existing config ...

  user_data = templatefile("${path.module}/user-data.sh.tpl", {
    instance_name  = local.instance_name
    nebula_version = var.nebula_version
    lighthouse_ip  = var.lighthouse_nebula_ip
  })
}
```

**What you learned:**

- ✅ `locals` for computed/reusable values
- ✅ `merge()` combines maps (tags)
- ✅ `templatefile()` injects variables into scripts
- ✅ Template syntax: `${variable}` for Terraform, `$${literal}` for bash

✨ **BEST PRACTICE: Template Files**

- **Use .tpl extension** - Signals it's a template (not executable)
- **Escape bash variables** - `$${BASH_VAR}` becomes `${BASH_VAR}` after rendering
- **Terraform variables** - `${terraform_var}` gets substituted
- **Pass only needed vars** - Don't expose entire var/local namespace

💡 **TIP: Template Functions**

- `templatefile(path, vars)` - Most common, renders template with variables
- `file(path)` - Loads file as-is (no variable substitution)
- `filebase64(path)` - Load and base64 encode (useful for binary data)

💡 **TIP: Template Debugging**

```hcl
# Preview rendered template
output "rendered_user_data" {
  value = templatefile("${path.module}/user-data.sh.tpl", {
    nebula_version = var.nebula_version
  })
}
# Run: terraform console
# Then: > output.rendered_user_data.value
```

⚠️ **ANTI-PATTERN: Complex Logic in Templates**

- DON'T put conditionals/loops in bash templates
- DO compute values in Terraform (locals), pass results to template
- Templates should be straightforward variable substitution
- Use Terraform's `for`, `if`, conditional expressions instead

---

## **Phase 6: State Management - Remote Backend**

**Goal:** Share state with team, enable collaboration.

### **Step 7: Configure Remote State**

**Problem:** `terraform.tfstate` is stored locally. If you lose it, Terraform can't manage your infrastructure.

**Solution:** Store state remotely (S3, Terraform Cloud, etc.)

**versions.tf** (add backend block):

```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote backend (S3)
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "kshitiz/terraform.tfstate"
    region = "us-east-1"

    # State locking with DynamoDB (requires manual table creation)
    # dynamodb_table = "terraform-locks"
    # encrypt        = true
  }
}
```

**Migration process:**

```bash
# 1. Create S3 bucket (one-time setup)
aws s3 mb s3://my-terraform-state --region us-east-1

# 2. Add backend block to versions.tf

# 3. Re-initialize Terraform
terraform init

# Terraform will prompt:
# "Do you want to copy existing state to the new backend?"
# Type: yes

# 4. Local state is now uploaded to S3
# Delete local state file (optional):
rm terraform.tfstate terraform.tfstate.backup
```

**What you learned:**

- ✅ Remote state enables team collaboration
- ✅ S3 backend is reliable and cost-effective
- ✅ State locking prevents concurrent modifications (requires DynamoDB setup)
- ✅ Encryption protects sensitive data in state
- ✅ `terraform init -migrate-state` for migration

✨ **BEST PRACTICE: Remote State**

- **Always use remote state** for production (even single-person projects)
- **S3 + DynamoDB**: Industry standard for AWS
  - **S3**: Stores state file
  - **DynamoDB**: Prevents concurrent changes (state locking) - requires manual setup
- **Enable versioning** on S3 bucket (recover from mistakes)
- **Enable encryption**: `encrypt = true` (state contains secrets)
- **Separate state per environment/component**:

  ```
  s3://bucket/prod/network/terraform.tfstate
  s3://bucket/prod/compute/terraform.tfstate
  s3://bucket/staging/terraform.tfstate
  ```

💡 **TIP: S3 State Cost**

- Terraform state files are typically <1MB
- Monthly cost: ~$0.01 or less (effectively negligible)
- S3 Standard pricing: $0.023/GB/month + minimal request charges
- For 100KB state file: ~$0.0023/month (~3 cents per year)

💡 **TIP: S3 Versioning, Encryption, and Security**

```bash
# Enable versioning (recommended for state recovery)
aws s3api put-bucket-versioning \
  --bucket my-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption (AES-256)
aws s3api put-bucket-encryption \
  --bucket my-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access (prevents anonymous access, NOT Terraform)
aws s3api put-public-access-block \
  --bucket my-terraform-state \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

**Why these matter:**

- **Versioning**: Recover from accidental state corruption or deletions
- **Encryption**: State files contain secrets (passwords, API keys, IPs)
- **Block Public Access**: Prevents anonymous downloads (Terraform still works - uses IAM credentials, not IP-based)
- Works from anywhere (consumer internet, dynamic IP) - no bastion server needed

💡 **TIP: State Locking**

```hcl
backend "s3" {
  bucket         = "my-terraform-state"
  key            = "kshitiz/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"  # Create this table first
}
```

**DynamoDB setup (required for state locking):**

```bash
# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**DynamoDB requirements:**

- Primary key: `LockID` (String type)
- Billing: PAY_PER_REQUEST (scales with usage, ~$0.25 per million requests)
- **NOT enabled by default** - you must create the table and add `dynamodb_table` to backend config
- Without DynamoDB: Multiple `terraform apply` can run simultaneously (risk of state corruption)

**Cost breakdown:**

- S3 storage: ~$0.01/month (state file)
- S3 requests: ~$0.001/month (terraform operations)
- DynamoDB: ~$0.01-0.10/month (depends on frequency of terraform runs)
- **Total: ~$0.05-0.15/month** (~$1-2/year)

💡 **TIP: Backend Configuration**

- **DON'T hardcode** sensitive values (access keys) in backend block
- **DO use backend config file**:

  ```bash
  # backend.conf (don't commit)
  bucket         = "my-state-bucket"
  access_key     = "..."
  secret_key     = "..."

  # Use:
  terraform init -backend-config=backend.conf
  ```

- **OR use environment variables**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

⚠️ **ANTI-PATTERN: Local State in Production**

- Single point of failure (laptop dies = state lost)
- Can't collaborate (state on one machine)
- No state locking (concurrent applies corrupt state)

⚠️ **ANTI-PATTERN: Committing State to Git**

- State contains secrets (passwords, keys, private IPs)
- Large file that changes constantly (pollutes git history)
- Merge conflicts are nightmares
- ALWAYS add `*.tfstate*` to `.gitignore`

**⚠️ Important:** Add to `.gitignore`:

```
*.tfstate
*.tfstate.*
.terraform/
```

✨ **BEST PRACTICE: Commit `.terraform.lock.hcl`**

- Contains exact provider versions
- Ensures team uses same versions
- Update with: `terraform init -upgrade`

---

## **Phase 7: Modules - Reusable Components**

**Goal:** Create reusable infrastructure building blocks.

### **Step 8: Extract Reusable Logic**

**When to create a module:**

- ✅ You're deploying the same infrastructure pattern multiple times
- ✅ You want to share configuration across projects/environments
- ✅ The resource has complex inter-dependencies

**Example module structure:**

```
modules/
└── lightsail-instance/
    ├── main.tf          # Resources
    ├── variables.tf     # Module inputs
    ├── outputs.tf       # Module outputs
    └── README.md        # Module documentation
```

**modules/lightsail-instance/variables.tf:**

```hcl
variable "instance_name" {
  description = "Name for the instance"
  type        = string
}

variable "bundle_id" {
  description = "Instance size"
  type        = string
  default     = "nano_3_0"
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ... more variables
```

**modules/lightsail-instance/main.tf:**

```hcl
resource "aws_lightsail_instance" "this" {
  name              = var.instance_name
  blueprint_id      = data.aws_lightsail_blueprint.ubuntu.id
  bundle_id         = var.bundle_id
  availability_zone = "${var.aws_region}a"

  user_data = var.user_data

  tags = var.tags
}

# ... static IP, firewall, etc.
```

**modules/lightsail-instance/outputs.tf:**

```hcl
output "public_ip" {
  value = aws_lightsail_static_ip.this.ip_address
}

output "instance_id" {
  value = aws_lightsail_instance.this.id
}
```

**Use the module in main.tf:**

```hcl
module "lighthouse" {
  source = "./modules/lightsail-instance"

  instance_name     = "kshitiz-lighthouse"
  bundle_id         = "nano_3_0"
  ssh_allowed_cidrs = ["203.0.113.10/32"]

  tags = {
    Role = "Lighthouse"
  }
}

# Access module outputs:
output "lighthouse_ip" {
  value = module.lighthouse.public_ip
}
```

**What you learned:**

- ✅ Modules encapsulate related resources
- ✅ `source` can be local path, Git URL, or Terraform Registry
- ✅ Module inputs via variables, outputs via outputs
- ✅ Reference module outputs: `module.lighthouse.public_ip`

✨ **BEST PRACTICE: When to Create Modules**
Modules are for **reusability**, not organization. Create modules when:

- ✅ Same pattern used 3+ times (e.g., multiple Lightsail instances)
- ✅ Sharing across projects/teams
- ✅ Complex resource groups with interdependencies
- ✅ Publishing to Terraform Registry

**DON'T create modules for:**

- ❌ Organization (use files: compute.tf, network.tf instead)
- ❌ Single-use resources
- ❌ Premature abstraction ("might need it later")

💡 **TIP: Passing Variables to Modules**

**CLI/Environment variables do NOT automatically flow into modules:**

```bash
# These set ROOT module variables only
terraform apply -var="instance_name=my-server"
export TF_VAR_instance_name="my-server"
```

**To pass to modules, explicitly pass in module block:**

```hcl
# Root module variables.tf
variable "instance_name" {
  type = string
}

# Root module main.tf
module "lighthouse" {
  source = "./modules/lightsail-instance"

  # Explicitly pass root variable to module
  instance_name = var.instance_name  # Maps root var to module var
}

# Now CLI/env variables work:
# terraform apply -var="instance_name=my-server"
```

💡 **TIP: Module Versioning**

```hcl
# Local module (development)
module "lighthouse" {
  source = "./modules/lightsail-instance"
}

# Git module (shared)
module "lighthouse" {
  source = "git::https://github.com/user/terraform-modules.git//lightsail-instance?ref=v1.0.0"
}

# Registry module (public)
module "lighthouse" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
}
```

💡 **TIP: Module Design Principles**

1. **Single responsibility** - One purpose per module
2. **Sensible defaults** - Work out-of-box, customize when needed
3. **Required vs optional** - Minimize required variables
4. **No hardcoded values** - Use variables for everything configurable
5. **Comprehensive outputs** - Expose all useful attributes
6. **Good documentation** - README with examples

✨ **BEST PRACTICE: Module Structure**

```
modules/lightsail-instance/
├── README.md          # Usage examples, inputs, outputs
├── main.tf            # Resources
├── variables.tf       # Inputs
├── outputs.tf         # Outputs
├── versions.tf        # Provider version constraints
└── examples/          # Working examples
    └── basic/
        ├── main.tf
        └── README.md
```

⚠️ **ANTI-PATTERN: Module for Everything**

- DON'T wrap every resource in a module
- Adds complexity without benefit
- Harder to read/debug
- Use modules sparingly, only when clear value

⚠️ **ANTI-PATTERN: God Modules**

- DON'T create one module that does everything
- DO create focused modules with single responsibility
- Bad: `infrastructure` module (VPC, EC2, RDS, S3, IAM)
- Good: `vpc`, `ec2-cluster`, `rds-instance` modules

⚠️ **ANTI-PATTERN: Nested Modules**

- Avoid modules calling other modules (complex dependency graph)
- Keep module hierarchy flat (2 levels max)
- Exception: Terraform Registry modules (vetted/maintained)

---

## **Phase 8: Production Hardening - Complete Checklist**

**Goal:** Production-ready Terraform with all best practices.

### **Step 9: Final Production Features**

**1. Variable Validation:**

```hcl
variable "instance_bundle_id" {
  description = "Lightsail bundle ID"
  type        = string
  default     = "nano_3_0"

  validation {
    condition     = can(regex("^(nano|micro|small|medium|large)_3_0$", var.instance_bundle_id))
    error_message = "Bundle ID must be one of: nano_3_0, micro_3_0, small_3_0, medium_3_0, large_3_0."
  }
}
```

**2. Conditional Resources:**

```hcl
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}

resource "aws_cloudwatch_alarm" "cpu" {
  count = var.enable_monitoring ? 1 : 0  # Create only if enabled

  alarm_name          = "${local.instance_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  threshold           = 80

  # ... rest of alarm config
}
```

**3. Lifecycle Rules:**

```hcl
resource "aws_lightsail_instance" "lighthouse" {
  # ... existing config ...

  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = true

    # Ignore changes to user_data (won't recreate on change)
    ignore_changes = [user_data]

    # Create new before destroying old (zero downtime)
    create_before_destroy = true
  }
}
```

**4. Depends On (Explicit Dependencies):**

```hcl
resource "aws_lightsail_static_ip_attachment" "lighthouse" {
  static_ip_name = aws_lightsail_static_ip.lighthouse.name
  instance_name  = aws_lightsail_instance.lighthouse.name

  # Ensure instance is fully ready before attachment
  depends_on = [aws_lightsail_instance_public_ports.lighthouse]
}
```

**5. Comprehensive Outputs:**

```hcl
output "ansible_inventory" {
  description = "Ansible inventory YAML"
  value = yamlencode({
    all = {
      hosts = {
        lighthouse = {
          ansible_host = aws_lightsail_static_ip.lighthouse.ip_address
          ansible_user = "ubuntu"
          nebula_ip    = var.lighthouse_nebula_ip
        }
      }
    }
  })
}
```

**6. Documentation (README.md):**

```markdown
# Kshitiz Infrastructure

## Purpose
Deploys AWS Lightsail instance for Nebula Lighthouse.

## Prerequisites
- AWS credentials configured
- Terraform >= 1.9.0

## Usage
\`\`\`bash
terraform init
terraform plan
terraform apply
\`\`\`

## Variables
- `aws_region`: AWS region (default: us-east-1)
- `instance_bundle_id`: Instance size (default: nano_3_0)

## Outputs
- `public_ip`: Static IP address
- `ssh_connection`: SSH command

## Cost
$3.50/month (nano_3_0 bundle)
```

**What you learned:**

- ✅ Input validation prevents mistakes
- ✅ Conditionals create resources based on flags
- ✅ Lifecycle rules control resource behavior
- ✅ Explicit dependencies when implicit isn't enough
- ✅ Documentation is part of infrastructure code

✨ **BEST PRACTICE: Variable Validation**

```hcl
# Enum validation
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# Regex validation (CIDR block)
variable "cidr_block" {
  type = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.cidr_block))
    error_message = "Must be valid CIDR notation (e.g., 10.0.0.0/16)."
  }
}

# Range validation
variable "instance_count" {
  type = number
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}
```

✨ **BEST PRACTICE: Lifecycle Rules**

- **prevent_destroy**: Critical resources (databases, state buckets)

  ```hcl
  lifecycle {
    prevent_destroy = true
  }
  ```

- **create_before_destroy**: Zero-downtime replacements

  ```hcl
  lifecycle {
    create_before_destroy = true
  }
  ```

- **ignore_changes**: Fields changed outside Terraform

  ```hcl
  lifecycle {
    ignore_changes = [user_data, tags["LastUpdated"]]
  }
  ```

💡 **TIP: When to Use lifecycle.ignore_changes**

- Autoscaling changes `desired_count` (ECS, ASG)
- User data changes don't need instance replacement
- Tags modified by external systems (cost allocation, monitoring)

💡 **TIP: Depends On**
Rarely needed (Terraform infers dependencies). Use when:

- Module depends on another module being ready
- IAM policies need time to propagate
- External systems need specific order

```hcl
resource "aws_instance" "app" {
  # ... config ...

  depends_on = [
    aws_iam_role_policy_attachment.app
  ]
}
```

⚠️ **ANTI-PATTERN: Overusing lifecycle.ignore_changes**

- Makes Terraform unaware of real infrastructure state
- Configuration drift (manual changes not tracked)
- Use sparingly, document why

⚠️ **ANTI-PATTERN: No validation**

- Catch mistakes early (at plan time, not apply time)
- Better error messages ("invalid value" vs AWS API error)
- Self-documenting (validation shows valid values)

---

## **Phase 9: Testing & CI/CD Integration**

**Goal:** Validate infrastructure before deployment.

### **Step 10: Testing Infrastructure**

**1. Pre-commit Validation:**

```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Security scan (install tfsec)
tfsec .

# Lint (install tflint)
tflint --init
tflint
```

**2. Plan without Apply:**

```bash
# Generate plan file
terraform plan -out=tfplan

# Review plan
terraform show tfplan

# Apply only if approved
terraform apply tfplan
```

**3. GitHub Actions Workflow (.github/workflows/terraform.yml):**

```yaml
name: Terraform

on:
  pull_request:
    paths:
      - 'samsara/terraform/**'

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0

      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: samsara/terraform/kshitiz

      - name: Terraform Init
        run: terraform init
        working-directory: samsara/terraform/kshitiz
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

      - name: Terraform Validate
        run: terraform validate
        working-directory: samsara/terraform/kshitiz

      - name: Terraform Plan
        run: terraform plan -no-color
        working-directory: samsara/terraform/kshitiz
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

      - name: Comment PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: 'Terraform plan completed. Review changes in logs.'
            })
```

**What you learned:**

- ✅ `terraform fmt` enforces consistent formatting
- ✅ `terraform validate` checks syntax
- ✅ Security tools (tfsec, checkov) find vulnerabilities
- ✅ Plan files prevent drift between plan and apply
- ✅ CI/CD validates changes before merge

✨ **BEST PRACTICE: Pre-Commit Checks**
Run locally BEFORE committing:

```bash
terraform fmt -recursive  # Auto-format all files
terraform validate        # Check syntax
tfsec .                   # Security scan
tflint                    # Linting (install: brew install tflint)
```

Set up git pre-commit hook:

```bash
# .git/hooks/pre-commit
#!/bin/bash
cd samsara/terraform/kshitiz
terraform fmt -check || exit 1
terraform validate || exit 1
```

✨ **BEST PRACTICE: Security Scanning**

- **tfsec**: Fast, focused on Terraform

  ```bash
  brew install tfsec
  tfsec . --minimum-severity HIGH
  ```

- **checkov**: Comprehensive, slower

  ```bash
  pip install checkov
  checkov -d .
  ```

- **terrascan**: Policy-as-code

  ```bash
  brew install terrascan
  terrascan scan
  ```

Common issues found:

- Unencrypted S3 buckets
- Overly permissive security groups
- Missing logging/monitoring
- Hardcoded secrets

💡 **TIP: Plan Files for Safety**

```bash
# 1. Generate plan
terraform plan -out=tfplan

# 2. Review plan (human inspection)
terraform show tfplan

# 3. Apply exact plan (no surprises)
terraform apply tfplan

# Plan files prevent:
# - Changes between plan and apply
# - Drift from environment changes
# - Unexpected modifications
```

💡 **TIP: CI/CD Workflow**
**On Pull Request:**

1. `terraform fmt -check` - Enforce formatting
2. `terraform validate` - Check syntax
3. `tfsec` - Security scan
4. `terraform plan` - Show changes
5. Post plan as PR comment

**On Merge to Main:**

1. `terraform plan -out=tfplan`
2. Manual approval (in GitHub Actions)
3. `terraform apply tfplan`

**On Schedule (Daily):**

1. `terraform plan -detailed-exitcode` - Automated drift detection
2. Alert if exit code = 2 (changes detected)

💡 **TIP: Drift Detection**

`terraform plan` ALWAYS detects drift (compares state vs actual infrastructure). The `-detailed-exitcode` flag provides exit codes for automation:

```bash
# Manual drift check (shows changes visually)
terraform plan

# Automated drift check (for CI/CD)
terraform plan -detailed-exitcode
# Exit 0: No drift
# Exit 1: Error
# Exit 2: Drift detected (changes needed)

# Example CI/CD drift alert
if terraform plan -detailed-exitcode; then
  echo "No drift detected"
else
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 2 ]; then
    echo "ALERT: Infrastructure drift detected!"
  fi
fi
```

✨ **BEST PRACTICE: State Management in CI/CD**

- Use remote state (S3/Terraform Cloud)
- Enable state locking (DynamoDB)
- Never store state in CI artifacts
- Use service accounts (not personal credentials)

⚠️ **ANTI-PATTERN: Auto-Apply Without Review**

- NEVER `terraform apply -auto-approve` in CI/CD
- Always require manual approval for production
- Use GitHub Environments with protection rules

⚠️ **ANTI-PATTERN: Credentials in CI/CD**

- DON'T hardcode AWS keys in workflow files
- DO use GitHub Secrets
- DO use OIDC (OpenID Connect) for keyless auth:

  ```yaml
  permissions:
    id-token: write
    contents: read
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActions
        aws-region: us-east-1
  ```

⚠️ **ANTI-PATTERN: No Drift Detection**

- Manual changes in console → Terraform doesn't know
- Run scheduled `terraform plan` to detect drift
- Investigate and reconcile (apply Terraform or import changes)

---

## **Complete Production-Grade Structure**

**Final directory layout:**

```
samsara/terraform/kshitiz/
├── .gitignore                    # Ignore state files
├── README.md                     # Documentation
├── DEPLOYMENT.md                 # Step-by-step deployment guide
├── versions.tf                   # Terraform and provider versions
├── providers.tf                  # Provider configuration
├── data-sources.tf               # Data source queries
├── locals.tf                     # Computed local values
├── variables.tf                  # Input variables
├── main.tf                       # Primary resources
├── firewall.tf                   # Security rules (optional split)
├── outputs.tf                    # Output values
├── user-data.sh.tpl              # User data template
└── modules/                      # Reusable modules (if needed)
    └── lightsail-instance/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── README.md
```

**Complete example (commented):**

```hcl
# versions.tf
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" {
  #   bucket = "brahmanda-terraform-state"
  #   key    = "kshitiz/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# providers.tf
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# data-sources.tf
data "aws_lightsail_blueprint" "ubuntu" {
  type = "os"
  filter {
    name   = "name"
    values = ["ubuntu_24_04"]
  }
}

# locals.tf
locals {
  resource_prefix = "${var.project_name}-${var.environment}"
  instance_name   = "${local.resource_prefix}-lighthouse"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# variables.tf
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "brahmanda"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# ... more variables

# main.tf
resource "aws_lightsail_instance" "lighthouse" {
  name              = local.instance_name
  availability_zone = "${var.aws_region}a"
  blueprint_id      = data.aws_lightsail_blueprint.ubuntu.id
  bundle_id         = var.instance_bundle_id

  user_data = templatefile("${path.module}/user-data.sh.tpl", {
    nebula_version = var.nebula_version
  })

  tags = merge(local.common_tags, {
    Name = local.instance_name
    Role = "Lighthouse"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# ... static IP, firewall, etc.

# outputs.tf
output "public_ip" {
  description = "Public IP address"
  value       = aws_lightsail_static_ip.lighthouse.ip_address
}

# ... more outputs
```

---

## **Key Takeaways**

**1. Progressive Enhancement:**

- Start simple (single file, hardcoded values)
- Add organization (split files, variables)
- Add data sources (dynamic lookups)
- Add production features (security, templates)
- Add state management (remote backend)
- Add reusability (modules)
- Add validation (testing, CI/CD)

**2. Every Feature Has a Purpose:**

- Variables → Reusability
- Locals → DRY principles
- Data sources → Dynamic configuration
- Templates → Complex user data
- Modules → Reusable components
- Remote state → Team collaboration
- Lifecycle rules → Control resource behavior

**3. Documentation is Infrastructure:**

- README.md for overview
- DEPLOYMENT.md for step-by-step
- Comments in code for "why"
- Variable descriptions for "what"

**4. Production = Secure + Reliable + Maintainable:**

- Firewall rules from day one
- Input validation prevents mistakes
- Lifecycle rules prevent accidents
- CI/CD catches issues before production
- State management enables collaboration

---

## **Next Steps: Practice**

**Exercises:**

1. **Start from scratch:** Delete the Kshitiz directory and rebuild it step-by-step following this guide.

2. **Modify incrementally:**
   - Change instance size (nano → micro)
   - Add a second Lightsail instance
   - Create a module for firewall rules
   - Add CloudWatch alarms

3. **Experiment with plan:**
   - Change a variable, run `terraform plan`
   - See what Terraform will do
   - Run `terraform apply` to execute

4. **Break and fix:**
   - Introduce a syntax error, see what happens
   - Remove a resource, run plan (Terraform will destroy it)
   - Add back, run plan (Terraform will recreate it)

5. **Study the official examples:**
   - [Terraform AWS Provider Examples](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
   - [Terraform Best Practices](https://www.terraform-best-practices.com/)

**Remember:** Terraform is declarative. You describe the *desired state*, Terraform figures out how to get there. The journey from beginner to expert is understanding *how* to express that desired state effectively.
