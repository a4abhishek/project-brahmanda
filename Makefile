# Makefile for Project Brahmanda
#
# This Makefile provides commands for managing the Brahmanda homelab environment.

# --- OS Detection and WSL Check ---
# This project depends on Linux-compatible tools such as `ansible`.
# If the OS is Windows, print an error and exit immediately.
# This ensures all commands are run within the expected Linux-compatible environment (WSL).
ifeq ($(OS),Windows_NT)
    $(error This Makefile requires Linux tools like Ansible and must be run from within a Linux environment (like WSL). Please switch to your WSL terminal.)
endif

# It assumes a Linux-compatible shell (e.g., bash/zsh on Linux, macOS, or WSL).

# --- Configuration ---
# Default target to run when no target is specified.
.DEFAULT_GOAL := help

SHELL := /bin/bash
INSTALL_SCRIPT := ./scripts/install_tools.sh

# Ansible Environment
# We set ANSIBLE_CONFIG explicitly to avoid issues with world-writable directories (WSL)
export ANSIBLE_CONFIG := $(CURDIR)/samsara/ansible/ansible.cfg
ANSIBLE_ENV := ANSIBLE_CONFIG=$(ANSIBLE_CONFIG)


# --- Phony Targets ---
# These targets do not represent files.
.PHONY: help check_tools install_tools check_auth init nidhi-tirodhana nidhi-avirbhava samshodhana nidhi-nikasha pratistha samskara mukti srishti kshitiz vyom pralaya

# --- Main Targets ---

help:
	@echo "🕉️ Project Brahmanda Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Setup & Core Targets:"
	@echo "  init          : 🚀  Initializes the environment: installs tools and checks authentication."
	@echo "  pratistha     : 🖥️  (OS Consecration) Automates Proxmox ISO download, config, and USB creation."
	@echo "  samskara      : 🕉️  (Purification) Refines Proxmox installation (repos, packages, disables popup)."
	@echo "  mukti         : 🔓  (Liberation) Reclaims USB drive for general use after Pratistha."
	@echo "  srishti       : 🕉️  (Creation) Provisions the Brahmanda (Kshitiz and Vyom)."
	@echo "  pralaya       : 🔥  (Dissolution) Destroys the Brahmanda."
	@echo ""
	@echo "Partial Targets:"
	@echo "  kshitiz       : ☁️  Provisions or updates the Edge layer (AWS Lightsail)."
	@echo "  vyom          : 🏠  Provisions or updates the Compute layer (Proxmox VMs)."
	@echo ""
	@echo "Maintenance:"
	@echo "  install_tools : 🛠️  Installs necessary CLI tools (Terraform, Ansible, 1Password CLI)."
	@echo "  check_tools   : ✅  Verifies that all required tools are installed."
	@echo "  check_auth    : 🔑  Verifies that the 1Password CLI is authenticated."
	@echo "  help          : 📖  Shows this help message."
	@echo ""
	@echo "Vault Management:"
	@echo "  nidhi-tirodhana : 🔒💎  (Treasury Concealment) Generates and encrypts vault(s) from 1Password."
	@echo "  nidhi-avirbhava : 🔓💎  (Treasury Manifestation) Decrypts Ansible Vault(s)."
	@echo "  samshodhana     : 📝    (Editing) Edits a specific Ansible Vault."
	@echo "  nidhi-nikasha   : 🪨💎  (Treasury Touchstone Test) Verifies all vaults can be decrypted."
	@echo ""
	@echo "Parameters:"
	@echo "  VAULT=<name>           : Target specific vault (brahmanda|kshitiz|vyom)."
	@echo "                           If omitted: nidhi-tirodhana/nidhi-avirbhava process all vaults."
	@echo "                           Required for: samshodhana (cannot edit multiple)."
	@echo "                           Example: make samshodhana VAULT=kshitiz"
	@echo ""
	@echo "  ISO_VERSION=<version>  : Proxmox version for pratistha (default: 9.1-1)."
	@echo "  ROOT_PASSWORD=<pass>   : Root password (use 1Password: \\$$\(op read '...'\\))."
	@echo "  SSH_KEY_PATH=<path>    : SSH public key path (default: ~/.ssh/proxmox-brahmanda.pub)."
	@echo "  USB_DEVICE=<device>    : Target USB device (required for pratistha)."
	@echo "  SKIP_DOWNLOAD=true     : Skip ISO download if already cached."
	@echo "  FORCE=true             : Force USB regeneration even if already bootable."
	@echo "                           Example: make pratistha USB_DEVICE=/dev/sdb ROOT_PASSWORD='...'"
	@echo ""
	@echo "  PROXMOX_HOST=<ip>      : Proxmox host IP for samskara (default: 192.168.68.200)."
	@echo "  KEEP_POPUP=true        : Keep subscription popup (for legal compliance, default: false)."
	@echo "  SSH_USER=<user>        : SSH user for samskara (default: root)."
	@echo "                           Example: make samskara PROXMOX_HOST=192.168.68.200"
	@echo ""
	@echo "  FORMAT=<filesystem>    : Filesystem for shuddhi (default: exfat, options: exfat, fat32, ext4, ntfs)."
	@echo "  LABEL=<label>          : Volume label for shuddhi (default: BRAHMANDA)."
	@echo "                           Example: make shuddhi USB_DEVICE=/dev/sdb"
	@echo "                           Example: make shuddhi USB_DEVICE=/dev/sdb FORMAT=fat32 LABEL=\"USB_DRIVE\""
	@echo "                           Example: make samskara KEEP_POPUP=true  # Preserve popup"

init: install_tools check_auth
	@echo "✅ Environment is initialized and ready."

# --- Vault Management ---

install-python-requirements:
	@echo "🐍 Checking/Installing Python dependencies..."
	@if [ ! -d ".venv" ]; then \
		echo "Creating virtual environment..."; \
		python3 -m venv .venv; \
	fi
	@.venv/bin/pip install -q -r requirements.txt

nidhi-tirodhana: install-python-requirements
	@chmod +x scripts/get-vault-password.sh
	@if [ -z "$(VAULT)" ]; then \
		echo "💎🔒 Nidhi-Tirodhana: Generating and securing all treasure repositories..."; \
		for vault in brahmanda kshitiz vyom; do \
			if [ -f "samsara/ansible/group_vars/$$vault/vault.tpl.yml" ]; then \
				echo "  → Processing $$vault..."; \
				.venv/bin/python3 scripts/inject-secrets.py "samsara/ansible/group_vars/$$vault/vault.tpl.yml" "samsara/ansible/group_vars/$$vault/vault.tmp.yml" && \
				(cd samsara/ansible && $(ANSIBLE_ENV) ansible-vault encrypt "group_vars/$$vault/vault.tmp.yml" \
					--encrypt-vault-id default \
					--vault-password-file=../../scripts/get-vault-password.sh \
					--output="group_vars/$$vault/vault.yml") && \
				rm -f "samsara/ansible/group_vars/$$vault/vault.tmp.yml" && \
				echo "  ✅ $$vault treasury secured"; \
			else \
				echo "  ⚠️  No template found for $$vault (skipping)"; \
			fi; \
		done; \
		echo "✅ All treasure repositories secured successfully"; \
	else \
		echo "💎🔒 Nidhi-Tirodhana: Generating and securing $(VAULT) treasury..."; \
		if [ ! -f "samsara/ansible/group_vars/$(VAULT)/vault.tpl.yml" ]; then \
			echo "❌ Template not found: samsara/ansible/group_vars/$(VAULT)/vault.tpl.yml"; \
			exit 1; \
		fi; \
		.venv/bin/python3 scripts/inject-secrets.py "samsara/ansible/group_vars/$(VAULT)/vault.tpl.yml" "samsara/ansible/group_vars/$(VAULT)/vault.tmp.yml" && \
		(cd samsara/ansible && $(ANSIBLE_ENV) ansible-vault encrypt "group_vars/$(VAULT)/vault.tmp.yml" \
			--encrypt-vault-id default \
			--vault-password-file=../../scripts/get-vault-password.sh \
			--output="group_vars/$(VAULT)/vault.yml") && \
		rm -f "samsara/ansible/group_vars/$(VAULT)/vault.tmp.yml" && \
		echo "✅ $(VAULT) treasury secured successfully"; \
	fi

nidhi-nikasha:
	@chmod +x scripts/get-vault-password.sh
	@echo "🪨💎 Nidhi-Nikasha: Testing treasuries on the touchstone..."
	@for vault in brahmanda kshitiz vyom; do \
		if [ -f "samsara/ansible/group_vars/$$vault/vault.yml" ]; then \
			echo "  → Examining $$vault..."; \
			(cd samsara/ansible && $(ANSIBLE_ENV) ansible-vault view "group_vars/$$vault/vault.yml" \
				--vault-password-file=../../scripts/get-vault-password.sh > /dev/null) && \
			echo "  ✅ $$vault treasury intact"; \
		else \
			echo "  ⚠️  No vault found for $$vault (skipping)"; \
		fi; \
	done
	@echo "✅ All treasuries verified and secure"

nidhi-avirbhava:
	@chmod +x scripts/get-vault-password.sh
	@if [ -z "$(VAULT)" ]; then \
		echo "🔓 Decrypting all Ansible Vaults..."; \
		for vault in brahmanda kshitiz vyom; do \
			if [ -f "samsara/ansible/group_vars/$$vault/vault.yml" ] && head -n1 "samsara/ansible/group_vars/$$vault/vault.yml" | grep -q '\$$ANSIBLE_VAULT'; then \
				echo "  - Decrypting $$vault vault..."; \
				(cd samsara/ansible && $(ANSIBLE_ENV) ansible-vault decrypt "group_vars/$$vault/vault.yml" --vault-password-file ../../scripts/get-vault-password.sh); \
			fi; \
		done; \
		echo "✅ All treasure repositories manifested successfully"; \
	else \
		echo "💎🔓 Nidhi-Avirbhava: Manifesting $(VAULT) treasury..."; \
		(cd samsara/ansible && $(ANSIBLE_ENV) ansible-vault decrypt "group_vars/$(VAULT)/vault.yml" --vault-password-file ../../scripts/get-vault-password.sh); \
		echo "✅ $(VAULT) treasury manifested successfully"; \
	fi

samshodhana:
	@if [ -z "$(VAULT)" ]; then \
		echo "ERROR: VAULT parameter required for editing."; \
		echo "Usage: make samshodhana VAULT=<brahmanda|kshitiz|vyom>"; \
		exit 1; \
	fi
	@echo "📝 Editing $(VAULT) Ansible Vault..."
	@chmod +x scripts/get-vault-password.sh
	@(cd samsara/ansible && $(ANSIBLE_ENV) ansible-vault edit "group_vars/$(VAULT)/vault.yml" --vault-password-file ../../scripts/get-vault-password.sh)
	@echo "SUCCESS: $(VAULT) vault editing complete."


# --- Tooling Setup ---

check_tools:
	@echo "INFO: Checking for required tools..."
	@$(if $(shell command -v terraform),,$(error "Terraform not found. Please run 'make install_tools' or install it manually."))
	@TERRAFORM_VERSION=$$(terraform version -json 2>/dev/null | grep -oP '"terraform_version":\s*"\K[^"]+' || echo "0.0.0"); \
	if ! printf '%s\n%s\n' "1.9.0" "$$TERRAFORM_VERSION" | sort -V -C 2>/dev/null; then \
		echo "ERROR: Terraform version $$TERRAFORM_VERSION is too old (< 1.9.0 required)."; \
		echo "Please run 'make install_tools' to upgrade."; \
		exit 1; \
	fi
	@$(if $(shell command -v ansible),,$(error "Ansible not found. Please run 'make install_tools' or install it manually."))
	@$(if $(shell command -v op),,$(error "1Password CLI (op) not found. Please run 'make install_tools' or install it manually."))
	@$(if $(shell command -v proxmox-auto-install-assistant),,$(error "Proxmox Auto-Install Assistant not found. Please run 'make install_tools' or install it manually."))
	@$(if $(shell command -v dasel),,$(error "dasel not found. Please run 'make install_tools' or install it manually."))
	@$(if $(shell command -v mkfs.exfat),,$(error "exfatprogs not found. Please run 'make install_tools' or install it manually."))
	@$(if $(shell command -v mkfs.ntfs),,$(error "ntfs-3g not found. Please run 'make install_tools' or install it manually."))
	@$(if $(shell command -v mkfs.vfat),,$(error "dosfstools not found. Please run 'make install_tools' or install it manually."))
	@echo "SUCCESS: All required tools are installed."

install_tools:
	@echo "INFO: Detecting OS for installation..."
	@case "$(shell uname -s)" in \
		Linux) \
			echo "INFO: Linux detected. Running Linux installation script."; \
			chmod +x ./scripts/initialize-linux.sh; \
			./scripts/initialize-linux.sh; \
			;; \
		Darwin) \
			echo "INFO: macOS detected. Running macOS installation script."; \
			chmod +x ./scripts/initialize-macos.sh; \
			./scripts/initialize-macos.sh; \
			;; \
		*) \
			echo "ERROR: Unsupported OS. Please install tools manually."; \
			exit 1; \
			;; \
	esac

check_auth:
	@echo "INFO: Checking 1Password CLI authentication status..."
	@if ! op whoami > /dev/null 2>&1; then \
		echo ""; \
		echo "ERROR: 1Password CLI is not authenticated."; \
		echo "Please run 'op signin' in your terminal and follow the prompts."; \
		echo "For more details, see: https://developer.1password.com/docs/cli/get-started/"; \
		echo ""; \
		exit 1; \
	else \
		echo "SUCCESS: 1Password CLI is authenticated."; \
	fi


# --- Orchestration Targets ---

# Pratistha: Automated Proxmox Installation
# Parameters:
#   ISO_VERSION    - Proxmox VE version (default: 9.1-1)
#   ROOT_PASSWORD  - Root password (required, use 1Password)
#   SSH_KEY_PATH   - Path to SSH public key (default: ~/.ssh/proxmox-brahmanda.pub)
#   USB_DEVICE     - Target USB device (required, e.g., /dev/sdb)
#   SKIP_DOWNLOAD  - Skip ISO download if already exists (default: false)
#   FORCE          - Force regeneration even if USB is already bootable (default: false)
#   VERIFY_USB     - Verify USB after creation (requires replugging, default: false)
pratistha:
	@echo "🖥️  Pratistha (OS Consecration) - Automating Proxmox Installation..."
	@if [ -z "$(USB_DEVICE)" ]; then \
		echo "ERROR: USB_DEVICE parameter required."; \
		echo "Usage: make pratistha USB_DEVICE=/dev/sdX [ISO_VERSION=9.1-1] [ROOT_PASSWORD=...] [SSH_KEY_PATH=...]"; \
		echo "Example: make pratistha USB_DEVICE=/dev/sdb ROOT_PASSWORD=\$$(op read 'op://Project-Brahmanda/Proxmox Brahmanda Root Password/password')"; \
		exit 1; \
	fi
	@chmod +x scripts/pratistha-proxmox.sh
	@./scripts/pratistha-proxmox.sh \
		--iso-version "$(or $(ISO_VERSION),9.1-1)" \
		--root-password "$(ROOT_PASSWORD)" \
		--ssh-key-path "$(or $(SSH_KEY_PATH),~/.ssh/proxmox-brahmanda.pub)" \
		--usb-device "$(USB_DEVICE)" \
		$(if $(SKIP_DOWNLOAD),--skip-download) \
		$(if $(FORCE),--force) \
		$(if $(VERIFY_USB),--verify-usb)
	@echo "SUCCESS: Pratistha complete. Bootable USB ready at $(USB_DEVICE)."

# Target: samskara
# Description: Samskara (Purification/Refinement) - Post-installation configuration
#              Refines base Proxmox installation into production-ready state
#              By default, disables subscription popup (use KEEP_POPUP=true to preserve)
# Parameters:
#   PROXMOX_HOST     - Proxmox host IP/FQDN (default: 192.168.68.200)
#   KEEP_POPUP       - Keep subscription popup for legal compliance (default: false)
#   SSH_USER         - SSH user for connection (default: root)
samskara:
	@echo "🕉️  Samskara (Purification) - Refining Proxmox installation..."
	@if [ ! -f scripts/samskara-proxmox.sh ]; then \
		echo "ERROR: scripts/samskara-proxmox.sh not found"; \
		exit 1; \
	fi
	@chmod +x scripts/samskara-proxmox.sh
	@echo "INFO: Copying Samskara script to $(or $(PROXMOX_HOST),192.168.68.200)..."
	@scp scripts/samskara-proxmox.sh $(or $(SSH_USER),root)@$(or $(PROXMOX_HOST),192.168.68.200):/tmp/
	@echo "INFO: Executing Samskara on Proxmox host..."
	@ssh $(or $(SSH_USER),root)@$(or $(PROXMOX_HOST),192.168.68.200) \
		"chmod +x /tmp/samskara-proxmox.sh && /tmp/samskara-proxmox.sh $(if $(KEEP_POPUP),--keep-subscription-popup) && rm /tmp/samskara-proxmox.sh"
	@echo "SUCCESS: Samskara complete. System refined and ready."
	@echo "INFO: Access Proxmox Web UI at https://$(or $(PROXMOX_HOST),192.168.68.200):8006"

# Target: mukti
# Description: Mukti (Liberation) - Reclaim USB drive after Pratistha (OS Consecration)
#              Formats USB to remove bootable installation media and return to general use
#              ⚠️  WARNING: This will permanently erase ALL data on the USB device
#              Includes safety checks (removable device verification, confirmation prompts)
# Parameters:
#   USB_DEVICE       - Target USB device (required, e.g., /dev/sdb)
#   FORMAT           - Filesystem format (default: exfat, options: exfat, fat32, ext4, ntfs)
#   LABEL            - Volume label (default: BRAHMANDA)
#   FORCE            - Skip confirmation prompt (use for automation, default: false)
mukti:
	@echo "🔓  Mukti (Liberation) - Reclaiming USB drive for general use..."
	@if [ -z "$(USB_DEVICE)" ]; then \
		echo "ERROR: USB_DEVICE parameter required."; \
		echo "Usage: make mukti USB_DEVICE=/dev/sdX [FORMAT=exfat] [LABEL=BRAHMANDA] [FORCE=true]"; \
		echo "Example: make mukti USB_DEVICE=/dev/sdb"; \
		echo "Example: make mukti USB_DEVICE=/dev/sdb FORMAT=fat32 LABEL=\"USB_DRIVE\""; \
		echo "Example: make mukti USB_DEVICE=/dev/sdb FORCE=true  # Skip confirmation"; \
		exit 1; \
	fi
	@if [ ! -f scripts/mukti-usb.sh ]; then \
		echo "ERROR: scripts/mukti-usb.sh not found"; \
		exit 1; \
	fi
	@chmod +x scripts/mukti-usb.sh
	@sudo ./scripts/mukti-usb.sh \
		--usb-device "$(USB_DEVICE)" \
		--format "$(or $(FORMAT),exfat)" \
		--label "$(or $(LABEL),BRAHMANDA)" \
		$(if $(FORCE),--force)
	@echo "SUCCESS: Mukti complete. USB drive liberated and ready for general use."

srishti:
	@echo "🕉️  Manifesting the Brahmanda..."
	@echo "INFO: This process will provision the Kshitiz (Edge) and Vyom (Compute) layers."
	make kshitiz
	make vyom
	@echo "SUCCESS: Srishti (Creation) is complete. The Brahmanda has been manifested."

kshitiz:
	@echo "☁️  Provisioning Kshitiz (Edge Layer)..."
	@echo "INFO: Running Terraform for the Lightsail instance..."
	(cd samsara/terraform/kshitiz && terraform init && terraform apply -auto-approve)

	@echo "INFO: Preparing to configure the Lighthouse with Ansible..."
	@op read "op://Project-Brahmanda/Kshitiz-Lighthouse-SSH-Key/private key" > /tmp/kshitiz_ssh_key
	@chmod 600 /tmp/kshitiz_ssh_key

	@echo "INFO: Running Ansible to configure the Lighthouse..."
	(cd samsara/ansible && $(ANSIBLE_ENV) ansible-playbook playbooks/01-bootstrap-kshitiz.yml --vault-password-file <(op read 'op://Project-Brahmanda/Ansible Vault - Samsara/password'))

	@rm -f /tmp/kshitiz_ssh_key
	@echo "SUCCESS: Kshitiz has been provisioned and configured."

vyom:
	@echo "🏠  Provisioning Vyom (Compute Layer)..."
	@echo "INFO: Running Terraform for the Proxmox VMs..."
	(cd samsara/terraform/vyom && terraform init && terraform apply -auto-approve)
	@echo "INFO: Running Ansible to bootstrap the Kubernetes cluster..."
	(cd samsara/ansible && $(ANSIBLE_ENV) ansible-playbook playbooks/02-bootstrap-cluster.yml --vault-password-file <(op read 'op://Project-Brahmanda/Ansible Vault - Samsara/password'))
	@echo "SUCCESS: Vyom has been provisioned."

pralaya:
	@echo "🔥  Invoking Pralaya (Dissolution)..."
	@echo "WARNING: This will destroy all infrastructure managed by this project."
	@read -p "Are you sure you want to proceed? [y/N] " confirm && [[ $$confirm == [yY] || $$confirm == [yY][eE][sS] ]] || exit 1
	@echo "INFO: Destroying Vyom (Compute Layer)..."
	#(cd samsara/terraform/vyom && terraform destroy -auto-approve)
	@echo "INFO: Destroying Kshitiz (Edge Layer)..."
	#(cd samsara/terraform/kshitiz && terraform destroy -auto-approve)
	@echo "SUCCESS: Pralaya is complete. The universe has returned to the void."
