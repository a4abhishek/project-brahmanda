#!/usr/bin/env python3

import json
import argparse
import os

def merge_inventories(inv1, inv2):
    """
    Merges two Ansible inventory dictionaries.
    """
    # Merge children from the 'all' group
    inv1["all"]["children"] = sorted(list(set(inv1["all"]["children"]) | set(inv2.get("all", {}).get("children", []))))

    # Merge hostvars
    inv1["_meta"]["hostvars"].update(inv2.get("_meta", {}).get("hostvars", {}))

    # Merge groups and their hosts
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
            if not manifest:
                return None
    except (IOError, json.JSONDecodeError):
        return None

    inventory = {"_meta": {"hostvars": {}}, "all": {"children": []}}
    for group_name, group_data in manifest.items():
        inventory["all"]["children"].append(group_name)
        inventory[group_name] = {"hosts": []}
        for host_data in group_data.get("hosts", []):
            host_name = host_data.get("name")
            if host_name:
                inventory[group_name]["hosts"].append(host_name)

                # Derive nebula_ip from ansible_host
                ansible_host_ip = host_data.get("ansible_host")
                if ansible_host_ip:
                    last_octet = ansible_host_ip.split('.')[-1]
                    host_data["inventory_nebula_ip"] = f"10.42.1.{last_octet}" # Assuming 10.42.1.x for vyom nodes

                inventory["_meta"]["hostvars"][host_name] = host_data
    return inventory


def find_and_merge_manifests(terraform_root):
    """
    Finds all 'manifest.json' files in the terraform directory and merges them.
    """
    final_inventory = {"_meta": {"hostvars": {}}, "all": {"children": []}}
    if not os.path.isdir(terraform_root):
        return final_inventory

    for root, _, files in os.walk(terraform_root):
        if "manifest.json" in files:
            manifest_path = os.path.join(root, "manifest.json")
            inventory_part = get_inventory_from_manifest(manifest_path)
            if inventory_part:
                final_inventory = merge_inventories(final_inventory, inventory_part)
    return final_inventory


def create_parent_groups(inventory):
    """
    Post-processes the inventory to create logical parent groups.
    """
    # Define which groups belong to the 'k3s_cluster' parent
    k3s_cluster_children = ["vyom_control_plane", "vyom_workers"]

    # Check if any of the child groups actually exist in the inventory
    if any(group in inventory for group in k3s_cluster_children):
        inventory["k3s_cluster"] = {
            "children": [group for group in k3s_cluster_children if group in inventory]
        }
        # Add the new parent group to the 'all' children list
        if "k3s_cluster" not in inventory["all"]["children"]:
            inventory["all"]["children"].append("k3s_cluster")

        # Optional: Remove the direct children from 'all' for a cleaner hierarchy,
        # as they are now reachable via the parent.
        for group in k3s_cluster_children:
            if group in inventory["all"]["children"]:
                inventory["all"]["children"].remove(group)

    return inventory


def main():
    """
    Main function to parse arguments and return inventory.
    """
    parser = argparse.ArgumentParser(description="Ansible dynamic inventory from Terraform manifests")
    parser.add_argument('--list', action='store_true', help="List all inventory")
    args = parser.parse_args()

    if args.list:
        script_dir = os.path.dirname(os.path.realpath(__file__))
        terraform_root_path = os.path.abspath(os.path.join(script_dir, '..', '..', '..', 'samsara', 'terraform'))

        inventory = find_and_merge_manifests(terraform_root_path)
        inventory = create_parent_groups(inventory) # Post-process to add parent groups

        print(json.dumps(inventory, indent=4))

if __name__ == '__main__':
    main()
