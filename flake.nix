{
  description = "NixOS Nixies Configuration Framework";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs @ { self
    , nixpkgs
    , flake-parts
    , ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];
      imports = [
        ./flake-modules/systems.nix
        ./flake-modules/packages.nix
        ./flake-modules/apps.nix
        ./flake-modules/checks.nix
        ./flake-modules/deployment.nix
        ./flake-modules/vm-images.nix
      ];
      flake = {
        lib = import ./lib {
          inherit inputs;
          inherit (nixpkgs) lib;
        };
        nixosModules = import ./modules;
        templates = import ./templates;
      };
      perSystem =
        { config
        , self'
        , inputs'
        , pkgs
        , system
        , ...
        }: {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
            };
          };
          checks = {
            # Check that the primary desktop profile evaluates and builds
            unified-desktop-build = self.nixosConfigurations."unified-desktop".config.system.build.toplevel;
          };
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              # Core Nix tooling
              nixpkgs-fmt
              alejandra
              statix
              deadnix
              nil
              nix-tree
              nix-du

              # Project tooling
              git
              pre-commit
              direnv
              jq

              # Shell utilities
              shellcheck
              hyperfine
              nodePackages.markdownlint-cli
            ];
            shellHook = ''
              echo "
              🏗️  NixOS Unified Development Environment Activated

              This shell provides all tools for formatting, linting, and deployment.
              The pre-commit hooks are active and will run on every commit.

              Key Commands:
                nix flake check   # Run all build checks
                pre-commit run -a # Manually run all hooks
                ./install.sh      # Start a new installation

              💡 For more help, see README.md
              ''
          };
          formatter = pkgs.alejandra;
        };
    };
}
