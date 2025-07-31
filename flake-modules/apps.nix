{
  self,
  pkgs,
  lib,
  ...
}: {
  flake.apps.${pkgs.system}.disko-install =
    let
      # Get all the hostnames from the nixosConfigurations
      hosts = lib.attrNames self.nixosConfigurations;
    in
    {
      type = "app";
      program = (pkgs.writeShellScriptBin "disko-install" ''
        #!/usr/bin/env bash
        set -euo pipefail

        # --- Helper Functions ---
        echo_green() { echo -e "\033[0;32m$1\033[0m"; }
        echo_red() { echo -e "\033[0;31m$1\033[0m"; }

        # --- Pre-flight Checks ---
        if [ "$EUID" -ne 0 ]; then
          echo_red "This script must be run as root. Please use sudo -i."
          exit 1
        fi

        # --- Argument Parsing ---
        if [ -z "$1" ]; then
          echo_red "Usage: $0 <hostname>"
          echo "Available hosts: ${builtins.concatStringsSep " " hosts}"
          exit 1
        fi

        HOSTNAME=$1
        FLAKE_URL="github:amoon/nixos-unified#$HOSTNAME"

        # Dynamically get the default disk for the selected host
        # This requires evaluating a bit of Nix code.
        DISK_DEVICE=$(nix eval --raw "$FLAKE_URL.config.system.diskDevice")

        # --- User Confirmation ---
        echo_green "--- NixOS Unified Installer ---"
        echo "Host to install:      $HOSTNAME"
        echo "Target disk (default):  $DISK_DEVICE"
        echo ""
        echo_red "WARNING: This will completely WIPE all data on $DISK_DEVICE."
        read -p "Are you absolutely sure? (yes/no): " CONFIRM
        if [[ "$CONFIRM" != "yes" ]]; then
            echo "Installation aborted."
            exit 0
        fi

        # --- Execution ---
        echo_green "
Step 1: Partitioning disk with disko..."
        nix run github:nix-community/disko -- --mode disko --flake "$FLAKE_URL"

        echo_green "
Step 2: Installing NixOS..."
        nixos-install --root /mnt --flake "$FLAKE_URL"

        echo_green "
--- Installation Complete! ---"
        echo "You can now reboot into your new system."
      '').outPath;
    };
}
