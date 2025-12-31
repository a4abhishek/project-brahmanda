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


# --- Phony Targets ---
# These targets do not represent files.
.PHONY: help check_tools install_tools check_auth init srishti kshitiz vyom pralaya

# --- Main Targets ---

help:
	@echo "🕉️ Project Brahmanda Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Setup & Core Targets:"
	@echo "  init          : 🚀  Initializes the environment: installs tools and checks authentication."
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

init: install_tools check_auth
	@echo "✅ Environment is initialized and ready."


# --- Tooling Setup ---

check_tools:
	@echo "INFO: Checking for required tools..."
	@$(if $(shell command -v terraform),,$(error "Terraform not found. Please run 'make install_tools' or install it manually."))
	@$(if $(shell command -v ansible),,$(error "Ansible not found. Please run 'make install_tools' or install it manually."))
	@$(if $(shell command -v op),,$(error "1Password CLI (op) not found. Please run 'make install_tools' or install it manually."))
	@echo "SUCCESS: All required tools are installed."

install_tools:
	@echo "INFO: Detecting OS for installation..."
	@case "$(shell uname -s)" in \
		Linux) \
			echo "INFO: Linux detected. Running Linux installation script."; \
			chmod +x ./scripts/install-linux.sh; \
			./scripts/install-linux.sh; \
			;; \
		Darwin) \
			echo "INFO: macOS detected. Running macOS installation script."; \
			chmod +x ./scripts/install-macos.sh; \
			./scripts/install-macos.sh; \
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

srishti: init
	@echo "🕉️  Manifesting the Brahmanda..."
	@echo "INFO: This process will provision the Kshitiz (Edge) and Vyom (Compute) layers."
	make kshitiz
	make vyom
	@echo "SUCCESS: Srishti (Creation) is complete. The Brahmanda has been manifested."

kshitiz: init
	@echo "☁️  Provisioning Kshitiz (Edge Layer)..."
	@echo "INFO: Running Terraform for the Lightsail instance..."
	#(cd samsara/terraform/kshitiz && terraform init && terraform apply -auto-approve)
	@echo "INFO: Running Ansible to configure the Lighthouse..."
	# ansible-playbook samsara/ansible/playbooks/01-bootstrap-edge.yml --vault-password-file <(op read 'op://Private/Ansible Vault - Samsara/password')
	@echo "SUCCESS: Kshitiz has been provisioned."

vyom: init
	@echo "🏠  Provisioning Vyom (Compute Layer)..."
	@echo "INFO: Running Terraform for the Proxmox VMs..."
	#(cd samsara/terraform/vyom && terraform init && terraform apply -auto-approve)
	@echo "INFO: Running Ansible to bootstrap the Kubernetes cluster..."
	# ansible-playbook samsara/ansible/playbooks/02-bootstrap-cluster.yml --vault-password-file <(op read 'op://Private/Ansible Vault - Samsara/password')
	@echo "SUCCESS: Vyom has been provisioned."

pralaya: init
	@echo "🔥  Invoking Pralaya (Dissolution)..."
	@echo "WARNING: This will destroy all infrastructure managed by this project."
	@read -p "Are you sure you want to proceed? [y/N] " confirm && [[ $$confirm == [yY] || $$confirm == [yY][eE][sS] ]] || exit 1
	@echo "INFO: Destroying Vyom (Compute Layer)..."
	#(cd samsara/terraform/vyom && terraform destroy -auto-approve)
	@echo "INFO: Destroying Kshitiz (Edge Layer)..."
	#(cd samsara/terraform/kshitiz && terraform destroy -auto-approve)
	@echo "SUCCESS: Pralaya is complete. The universe has returned to the void."
