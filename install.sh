
#!/usr/bin/env bash
set -euo pipefail

# This script provides a guided installation for the NixOS Unified Framework.

# --- Configuration ---
HARDWARE_CONFIG_DIR="/mnt/etc/nixos/configurations/hosts"

# --- Helper Functions ---
echo_green() {
    echo -e "\033[0;32m$1\033[0m"
}

echo_red() {
    echo -e "\033[0;31m$1\033[0m"
}

# --- Main Logic ---
main() {
    echo_green "Welcome to the NixOS Unified Framework Installer!"

    # 1. Select Host
    echo "Please select the host to install:"
    select host in $(ls $HARDWARE_CONFIG_DIR); do
        if [ -n "$host" ]; then
            echo_green "You selected: $host"
            break
        else
            echo_red "Invalid selection. Please try again."
        fi
    done

    # 2. Confirm Disk
    DISK=$(grep -r "diskDevice" "$HARDWARE_CONFIG_DIR/$host" | awk -F '"' '{print $2}')
    echo "The selected host will be installed on: $DISK"
    read -p "Is this correct? (y/n): " confirm_disk
    if [[ "$confirm_disk" != "y" ]]; then
        echo_red "Installation aborted."
        exit 1
    fi

    # 3. Run Installation
    echo_green "Starting installation..."
    nixos-install --root /mnt --flake ".#$host"

    echo_green "Installation complete! You can now reboot."
}

main "$@"
