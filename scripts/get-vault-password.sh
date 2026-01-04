#!/bin/bash
# Helper script to retrieve Ansible Vault password from 1Password
# This script is called by ansible-vault as a password source

op read "op://Project-Brahmanda/Ansible Vault - Samsara/password"
