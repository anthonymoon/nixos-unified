{ config
, lib
, pkgs
, ...
}: {
  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/var/lib"
      "/var/log"
      "/etc/NetworkManager/system-connections"
      {
        directory = "/var/lib/systemd/coredump";
        user = "root";
        group = "root";
        mode = "0755";
      }
    ];
    files = [
      "/etc/machine-id"
      {
        file = "/etc/ssh/ssh_host_ed25519_key";
        parentDirectory = { mode = "0755"; };
      }
      {
        file = "/etc/ssh/ssh_host_ed25519_key.pub";
        parentDirectory = { mode = "0755"; };
      }
      {
        file = "/etc/ssh/ssh_host_rsa_key";
        parentDirectory = { mode = "0755"; };
      }
      {
        file = "/etc/ssh/ssh_host_rsa_key.pub";
        parentDirectory = { mode = "0755"; };
      }
    ];
    users.amoon = {
      directories = [
        "Downloads"
        "Documents"
        "Pictures"
        "Videos"
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".config";
          mode = "0755";
        }
        {
          directory = ".local/share";
          mode = "0755";
        }
      ];
      files = [
        ".bashrc"
        ".gitconfig"
      ];
    };
  };
}
