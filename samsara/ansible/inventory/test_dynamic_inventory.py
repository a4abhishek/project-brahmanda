#!/usr/bin/env python3
import unittest
import json
import os
import shutil
import tempfile
import sys

# Add the script's directory to the Python path to allow importing
script_dir = os.path.dirname(os.path.realpath(__file__))
sys.path.append(script_dir)

from dynamic_inventory import get_inventory_from_manifest, merge_inventories, find_and_merge_manifests

class TestDynamicInventory(unittest.TestCase):

    def setUp(self):
        """Set up a temporary directory for test files."""
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        """Remove the temporary directory after tests."""
        shutil.rmtree(self.test_dir)

    def test_get_inventory_from_valid_manifest(self):
        """Test parsing a single, valid manifest.json file."""
        manifest_content = {
            "kshitiz": {
                "hosts": [{
                    "name": "kshitiz-lighthouse",
                    "ansible_host": "1.1.1.1",
                    "role": "lighthouse"
                }]
            }
        }
        manifest_path = os.path.join(self.test_dir, "manifest.json")
        with open(manifest_path, 'w') as f:
            json.dump(manifest_content, f)
            
        inventory = get_inventory_from_manifest(manifest_path)

        expected_inventory = {
            '_meta': {
                'hostvars': {
                    'kshitiz-lighthouse': {
                        "name": "kshitiz-lighthouse",
                        "ansible_host": "1.1.1.1",
                        "role": "lighthouse"
                    }
                }
            },
            'all': {
                'children': ['kshitiz']
            },
            'kshitiz': {
                'hosts': ['kshitiz-lighthouse']
            }
        }
        self.assertEqual(inventory, expected_inventory)

    def test_get_inventory_from_empty_manifest(self):
        """Test parsing an empty but valid JSON manifest."""
        manifest_path = os.path.join(self.test_dir, "manifest.json")
        with open(manifest_path, 'w') as f:
            f.write("{}")
        
        inventory = get_inventory_from_manifest(manifest_path)
        self.assertIsNone(inventory, "Should return None for an empty manifest object")

    def test_get_inventory_from_nonexistent_file(self):
        """Test handling of a non-existent manifest file."""
        inventory = get_inventory_from_manifest("nonexistent/path/manifest.json")
        self.assertIsNone(inventory)

    def test_merge_inventories(self):
        """Test merging two separate inventory structures."""
        inv1 = {
            '_meta': {'hostvars': {'host1': {'ip': '1.1.1.1'}}},
            'all': {'children': ['group1']},
            'group1': {'hosts': ['host1']}
        }
        inv2 = {
            '_meta': {'hostvars': {'host2': {'ip': '2.2.2.2'}}},
            'all': {'children': ['group2']},
            'group2': {'hosts': ['host2']}
        }
        
        merged = merge_inventories(inv1, inv2)

        expected = {
            '_meta': {
                'hostvars': {
                    'host1': {'ip': '1.1.1.1'},
                    'host2': {'ip': '2.2.2.2'}
                }
            },
            'all': {'children': sorted(['group1', 'group2'])},
            'group1': {'hosts': ['host1']},
            'group2': {'hosts': ['host2']}
        }
        self.assertEqual(merged, expected)
        
    def test_find_and_merge_manifests(self):
        """Integration test: find and merge multiple manifests in a directory tree."""
        # Create a mock terraform directory structure
        terraform_root = os.path.join(self.test_dir, "samsara", "terraform")
        kshitiz_dir = os.path.join(terraform_root, "kshitiz")
        vyom_dir = os.path.join(terraform_root, "vyom")
        os.makedirs(kshitiz_dir)
        os.makedirs(vyom_dir)

        # Kshitiz manifest
        kshitiz_manifest_content = {
            "kshitiz": {
                "hosts": [{
                    "name": "kshitiz-lighthouse",
                    "ansible_host": "13.214.253.51"
                }]
            }
        }
        with open(os.path.join(kshitiz_dir, "manifest.json"), 'w') as f:
            json.dump(kshitiz_manifest_content, f)

        # Vyom manifest
        vyom_manifest_content = {
            "vyom": {
                "hosts": [
                    {"name": "vyom-master-01", "ansible_host": "192.168.68.201"},
                    {"name": "vyom-worker-01", "ansible_host": "192.168.68.202"}
                ]
            }
        }
        with open(os.path.join(vyom_dir, "manifest.json"), 'w') as f:
            json.dump(vyom_manifest_content, f)

        # Run the discovery and merge process
        final_inventory = find_and_merge_manifests(terraform_root)
        
        # Define the expected final, merged output
        expected_final_inventory = {
            '_meta': {
                'hostvars': {
                    'kshitiz-lighthouse': {"name": "kshitiz-lighthouse", "ansible_host": "13.214.253.51"},
                    'vyom-master-01': {"name": "vyom-master-01", "ansible_host": "192.168.68.201"},
                    'vyom-worker-01': {"name": "vyom-worker-01", "ansible_host": "192.168.68.202"}
                }
            },
            'all': {
                'children': sorted(['kshitiz', 'vyom'])
            },
            'kshitiz': {
                'hosts': ['kshitiz-lighthouse']
            },
            'vyom': {
                'hosts': sorted(['vyom-master-01', 'vyom-worker-01'])
            }
        }
        
        # Sort hosts within groups for consistent comparison
        if 'vyom' in final_inventory:
            final_inventory['vyom']['hosts'].sort()

        self.assertEqual(final_inventory, expected_final_inventory)

if __name__ == '__main__':
    unittest.main()
