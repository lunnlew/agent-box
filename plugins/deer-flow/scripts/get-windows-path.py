#!/usr/bin/env python3
"""
Get Windows host path for Docker-in-Docker volume mounts
Usage: python3 get-windows-path.py <container_path>
"""
import subprocess
import os
import sys

def get_windows_path(container_path):
    """Convert container path to Windows host path for Docker Desktop WSL2"""
    home = os.environ.get('HOME', '/home/agent')

    # Get Docker inspect output
    result = subprocess.run(['docker', 'inspect', 'agentbox'], capture_output=True, text=True)
    for line in result.stdout.split('\n'):
        if '/home/agent:' in line:
            # Extract Windows host path (format: "D:\\path:/home/agent:rw")
            line = line.strip().strip('",')
            # Split to get Windows part
            parts = line.split(':/home/agent')
            if parts and parts[0]:
                windows_path = parts[0]
                # Normalize backslashes to forward slashes
                # Docker Desktop WSL2 escapes \ as \\ in JSON output
                # In Python string, \\\\ represents two literal backslashes
                # which represents one Windows backslash - replace with single /
                normalized = windows_path.replace('\\\\', '/')
                # Convert drive letter to lowercase
                normalized = normalized[0].lower() + normalized[1:]
                # Calculate relative path from /home/agent
                rel_path = container_path.replace(home + '/', '')
                return f'{normalized}/{rel_path}'

    # Fallback to container path
    return container_path

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(sys.stderr.write("Usage: python3 get-windows-path.py <container_path>\n"))
        sys.exit(1)

    container_path = sys.argv[1]
    print(get_windows_path(container_path))
