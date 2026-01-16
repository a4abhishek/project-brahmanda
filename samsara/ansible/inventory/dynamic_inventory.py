#!/usr/bin/env python3

import json
import argparse
import os

def merge_inventories(inv1, inv2):
    """
    Merges two Ansible inventory dictionaries.
    """
    # Merge children
    inv1["all"]["children"] = sorted(list(set(inv1["all"]["children"]) | set(inv2.get("all", {}).get("children", []))))

    # Merge hostvars
    inv1["_meta"]["hostvars"].update(inv2.get("_meta", {}).get("hostvars", {}))

    # Merge groups
    for group, data in inv2.items():
        if group not in ["_meta", "all"]:
            if group not in inv1:
                inv1[group] = {"hosts": []}
            inv1[group]["hosts"] = sorted(list(set(inv1[group]["hosts"]) | set(data.get("hosts", []))))
    return inv1


def get_inventory_from_manifest(manifest_path):
    """
    Parses a single terraform-generated manifest.json to build an Ansible inventory.
    """
    try:
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
            if not manifest:  # Handle empty JSON file
                return None
    except (IOError, json.JSONDecodeError):
        # Return None if the manifest doesn't exist or is malformed
        return None

    inventory = {
        "_meta": {"hostvars": {}},
        "all": {"children": []}
    }

    # Process the manifest
    for group_name, group_data in manifest.items():
        inventory["all"]["children"].append(group_name)
        inventory[group_name] = {"hosts": []}

        for host_data in group_data.get("hosts", []):
            host_name = host_data.get("name")
            if not host_name:
                continue
            
            inventory[group_name]["hosts"].append(host_name)
            # All other data from the manifest becomes hostvars
            inventory["_meta"]["hostvars"][host_name] = host_data
    
    return inventory


def find_and_merge_manifests(terraform_root):
    """
    Finds all 'manifest.json' files in the terraform directory and merges them.
    """
    final_inventory = {
        "_meta": {"hostvars": {}},
        "all": {"children": []}
    }

    if not os.path.isdir(terraform_root):
        return final_inventory

    for root, _, files in os.walk(terraform_root):
        if "manifest.json" in files:
            manifest_path = os.path.join(root, "manifest.json")
            inventory_part = get_inventory_from_manifest(manifest_path)
            if inventory_part:
                final_inventory = merge_inventories(final_inventory, inventory_part)
                
    return final_inventory


def main():
    """
    Main function to parse arguments and return inventory.
    """
    parser = argparse.ArgumentParser(description="Ansible dynamic inventory from Terraform manifests")
    parser.add_argument('--list', action='store_true', help="List all inventory")
    args = parser.parse_args()

    if args.list:
        # The root directory where all terraform modules live
        script_dir = os.path.dirname(os.path.realpath(__file__))
        terraform_root_path = os.path.join(script_dir, '../../../samsara/terraform/')
        
        inventory = find_and_merge_manifests(terraform_root_path)
        print(json.dumps(inventory, indent=4))

if __name__ == '__main__':
    main()
