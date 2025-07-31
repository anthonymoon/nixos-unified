{ self
, inputs
, ...
}: {
  flake.nixosConfigurations =
    let
      lib = inputs.nixpkgs.lib;
      system = "x86_64-linux";
      nixies-lib = import ../lib {
        inherit inputs;
        inherit (inputs.nixpkgs) lib;
      };
      # Function to build a system from a host definition
      mkHost = hostFile:
        let
          hostConfig = import hostFile;
        in
        nixies-lib.mkSystem {
          hostname = hostConfig.hostName;
          inherit system;
          profiles = [ hostConfig.systemProfile ];
          modules = [
            hostConfig.diskoLayout
            ({ config, ... }: {
              system.diskDevice = hostConfig.diskDevice;
              users.users.${hostConfig.userName} = {
                isNormalUser = true;
                description = hostConfig.userFullName;
                extraGroups = [ "wheel" "networkmanager" "docker" "libvirtd" ];
              };
              # Pass user info to home-manager
              home-manager.users.${hostConfig.userName} = {
                imports = [ ../../templates/default/home.nix ];
                home.username = hostConfig.userName;
                home.homeDirectory = "/home/${hostConfig.userName}";
                programs.git.userName = hostConfig.userFullName;
                programs.git.userEmail = hostConfig.userEmail;
              };
            })
          ];
        };
      # Read all host directories and build a system for each
      hostFiles = lib.mapAttrsToList (name: value: value) (lib.filterAttrs (n: v: v == "directory") (builtins.readDir ../configurations/hosts));
      hosts = builtins.map (hostDir: ../configurations/hosts + "/${hostDir.name}/default.nix") hostFiles;
    in
    lib.genAttrs (map (hostFile: (import hostFile).hostName) hosts) mkHost;
}
