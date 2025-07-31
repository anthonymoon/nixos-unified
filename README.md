# NixOS Unified Framework

This repository provides a powerful, modular, and reusable framework for managing NixOS systems. It is the result of merging the best features of `nixos-nixies` and `nixos-claude`, combining a robust, modular architecture with a feature-rich, modern ZFS implementation.

## Features

- **Modular Architecture:** Built on `flake-parts`, the framework is highly modular and scalable.
- **Declarative Disk Partitioning:** Uses `disko` for declarative, reproducible disk layouts.
- **ZFS on Root:** Provides a highly-tuned ZFS on root configuration with impermanence.
- **Impermanence:** The root filesystem is stateless, with persistent data managed by `impermanence`.
- **Home Manager:** Manages user environments declaratively with `home-manager`.
- **Host-Specific Configuration:** Easily manage multiple machines with per-host configuration files.

## Directory Structure

- **`/configurations/hosts`**: Contains per-host configurations. Each subdirectory defines a machine.
- **`/configurations/disko`**: Contains declarative disk layouts.
- **`/modules`**: Contains reusable NixOS modules (e.g., `zfs-root`, `persistence`).
- **`/profiles`**: Defines high-level system roles (e.g., `home-desktop`, `home-server`).

## Deploying a New Machine

1.  **Boot the NixOS installer.**
2.  **Clone this repository:**
    ```bash
    git clone <this-repo-url> /mnt/etc/nixos
    cd /mnt/etc/nixos
    ```
3.  **Configure a new host:**
    - Create a new directory in `configurations/hosts` for your new machine.
    - Create a `default.nix` and `disko.nix` in the new host directory, following the `unified-desktop` example.
    - Update the `diskDevice` in your new `disko.nix` to match your target disk.
4.  **Run the installer:**
    ```bash
    nixos-install --root /mnt --flake .#<your-hostname>
    ```
5.  **Reboot.**
