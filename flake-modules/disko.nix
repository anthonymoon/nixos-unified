
{
  inputs,
  lib,
  ...
}: {
  flake.diskoConfigurations =
    let
      # Logic to find all host definition files
      hostFiles = lib.mapAttrsToList (name: value: value) (lib.filterAttrs (n: v: v == "directory") (builtins.readDir ../configurations/hosts));
      hosts = builtins.map (hostDir: ../configurations/hosts + "/${hostDir.name}/default.nix") hostFiles;

      # Function to create a disko config from a host file
      mkDiskoConfig = hostFile: (import hostFile).diskoLayout;

    in
    # Generate an attribute set like: { unified-desktop = import ./path/to/disko.nix; ... }
    lib.genAttrs (map (hostFile: (import hostFile).hostName) hosts) mkDiskoConfig;
}
