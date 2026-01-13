#!/usr/bin/env python3
import os
import sys
from urllib.parse import urlparse

# Constants - Updated for Work Profile
EXCLUDE_FILE = os.path.expanduser("~/.config/qutebrowser_work/config/darkmode_excludes")
QUTE_FIFO = os.environ.get("QUTE_FIFO")
QUTE_URL = os.environ.get("QUTE_URL")

def send_to_qute(command):
    """Writes a command to the qutebrowser FIFO."""
    if not QUTE_FIFO:
        print("Error: QUTE_FIFO not set. Are you running this from qutebrowser?", file=sys.stderr)
        return
    
    with open(QUTE_FIFO, "w") as f:
        f.write(command + "\n")

def get_domain(url):
    """Extracts the domain from a URL."""
    if not url:
        return None
    try:
        parsed = urlparse(url)
        return parsed.netloc
    except Exception:
        return None

def main():
    try:
        if not QUTE_URL:
            send_to_qute("message-error 'Error: Could not determine current URL'")
            sys.exit(1)

        domain = get_domain(QUTE_URL)
        if not domain:
            send_to_qute("message-error 'Error: Invalid URL or Domain'")
            sys.exit(1)
        
        # Ensure the file exists
        if not os.path.exists(EXCLUDE_FILE):
            open(EXCLUDE_FILE, "a").close()

        with open(EXCLUDE_FILE, "r") as f:
            lines = [line.strip() for line in f.readlines()]

        if domain in lines:
            # Remove it
            lines.remove(domain)
            action = "enabled"
        else:
            # Add it
            lines.append(domain)
            action = "disabled"

        with open(EXCLUDE_FILE, "w") as f:
            f.write("\n".join(filter(None, lines)) + "\n")

        if action == "enabled":
            # Dark mode enabled -> set to True
            cmd_value = "true"
        else:
            # Dark mode disabled -> set to False
            cmd_value = "false"

        # Apply runtime change immediately
        pattern = f"*://{domain}/*"
        send_to_qute(f"set colors.webpage.darkmode.enabled {cmd_value} -u '{pattern}'")
        
        # Reload page
        send_to_qute("reload")
        send_to_qute(f"message-info 'Dark Mode {action} for {domain}'")
        
    except Exception as e:
        send_to_qute(f"message-error 'Dark Mode Script Error: {e}'")
        sys.exit(1)

if __name__ == "__main__":
    main()
