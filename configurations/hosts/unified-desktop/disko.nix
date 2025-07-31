{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
                device = config.system.diskDevice;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };
    zpool = {
      rpool = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          dnodesize = "auto";
          normalization = "formD";
          relatime = "on";
          atime = "off";
          "com.sun:auto-snapshot" = "false";
          canmount = "off";
          mountpoint = "none";
        };
        postCreateHook = ''
          zfs create -o canmount=off -o mountpoint=none rpool/local
          zfs create -o canmount=off -o mountpoint=none rpool/safe
          zfs snapshot rpool/local@blank
        '';
        datasets = {
          "local/root" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/";
            postCreateHook = "zfs snapshot rpool/local/root@blank";
          };
          "local/nix" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              atime = "off";
              compression = "zstd-3";
            };
            mountpoint = "/nix";
          };
          "safe/persist" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "true";
            };
            mountpoint = "/persist";
          };
          "safe/home" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "true";
            };
            mountpoint = "/home";
          };
          "local/var-log" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              compression = "zstd-9";
            };
            mountpoint = "/var/log";
          };
          "reserved" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              reservation = "5G";
              quota = "5G";
            };
          };
        };
      };
    };
  };
}
