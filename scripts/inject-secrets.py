#!/usr/bin/env python3
import yaml
import subprocess
import sys
import os

def get_op_secret(reference):
    """Fetches secret from 1Password using the CLI."""
    try:
        # op read -n prevents trailing newline from being added if not in secret
        result = subprocess.run(['op', 'read', '-n', reference], capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error fetching secret {reference}: {e.stderr}", file=sys.stderr)
        sys.exit(1)

def process_data(data):
    """Recursively traverses data to find and replace op:// references."""
    if isinstance(data, dict):
        for k, v in data.items():
            data[k] = process_data(v)
    elif isinstance(data, list):
        for i, v in enumerate(data):
            data[i] = process_data(v)
    elif isinstance(data, str) and data.startswith('op://'):
        # Found a reference! Fetch it.
        ref = data.strip()
        print(f"Resolving: {ref}", file=sys.stderr)
        return get_op_secret(ref)
    return data

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input_template.yml> <output_file.yml>", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    if not os.path.exists(input_path):
        print(f"Error: Input file {input_path} not found.", file=sys.stderr)
        sys.exit(1)

    # Read YAML
    with open(input_path, 'r') as f:
        try:
            # Use FullLoader to preserve some types, or SafeLoader for security
            template_data = yaml.safe_load(f)
        except yaml.YAMLError as e:
            print(f"Error parsing YAML: {e}", file=sys.stderr)
            sys.exit(1)

    # Process
    output_data = process_data(template_data)

    # Write YAML
    with open(output_path, 'w') as f:
        # width=1000 and default_flow_style=False ensures keys/certs 
        # are written as block scalars if they have newlines
        yaml.dump(output_data, f, default_flow_style=False, sort_keys=False, width=1000)

if __name__ == '__main__':
    main()