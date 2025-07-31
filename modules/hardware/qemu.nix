{ config
, lib
, pkgs
, inputs
, ...
}:
let
  nixies-lib = import ../../lib { inherit inputs lib; };
in
(nixies-lib.mkUnifiedModule {
  name = "qemu";
  description = "QEMU virtual machine hardware support and optimizations";
  category = "hardware";
  options = with lib; {
    enable = mkEnableOption "QEMU VM hardware support";
    guest = {
      enable = mkEnableOption "QEMU guest services and optimizations" // { default = true; };
      spice = mkEnableOption "SPICE guest agent for improved VM integration" // { default = true; };
      qga = mkEnableOption "QEMU guest agent for host communication" // { default = true; };
    };
    virtio = {
      enable = mkEnableOption "VirtIO device drivers" // { default = true; };
      drivers = {
        balloon = mkEnableOption "VirtIO memory balloon driver" // { default = true; };
        console = mkEnableOption "VirtIO serial console driver" // { default = true; };
        rng = mkEnableOption "VirtIO random number generator" // { default = true; };
        net = mkEnableOption "VirtIO network driver" // { default = true; };
        blk = mkEnableOption "VirtIO block device driver" // { default = true; };
        scsi = mkEnableOption "VirtIO SCSI driver" // { default = true; };
        gpu = mkEnableOption "VirtIO GPU driver" // { default = false; };
        fs = mkEnableOption "VirtIO filesystem driver" // { default = false; };
      };
    };
    performance = {
      enable = mkEnableOption "QEMU performance optimizations" // { default = true; };
      kernel = {
        elevator = mkOption {
          type = types.enum [ "noop" "deadline" "cfq" "bfq" "kyber" ];
          default = "noop";
          description = "I/O scheduler optimized for VMs";
        };
        preemption = mkOption {
          type = types.enum [ "none" "voluntary" "full" ];
          default = "voluntary";
          description = "Kernel preemption model for VMs";
        };
        hz = mkOption {
          type = types.enum [ 100 250 300 1000 ];
          default = 250;
          description = "Kernel timer frequency for VMs";
        };
      };
      cpu = {
        governor = mkOption {
          type = types.str;
          default = "performance";
          description = "CPU frequency governor for VMs";
        };
        mitigations = mkEnableOption "CPU security mitigations (disable for better performance)";
      };
      memory = {
        ksm = mkEnableOption "Kernel Same-page Merging for memory efficiency";
        zram = mkEnableOption "zRAM compressed swap";
        hugepages = mkEnableOption "Transparent huge pages";
      };
    };
    networking = {
      optimization = mkEnableOption "Network performance optimizations" // { default = true; };
      drivers = {
        virtio-net = mkEnableOption "VirtIO network driver" // { default = true; };
        e1000 = mkEnableOption "Intel E1000 network driver" // { default = false; };
        rtl8139 = mkEnableOption "Realtek RTL8139 network driver" // { default = false; };
      };
    };
    graphics = {
      enable = mkEnableOption "Graphics support for VMs";
      drivers = {
        virtio-gpu = mkEnableOption "VirtIO GPU driver" // { default = true; };
        qxl = mkEnableOption "QXL graphics driver" // { default = false; };
        cirrus = mkEnableOption "Cirrus Logic graphics driver" // { default = false; };
      };
      acceleration = mkEnableOption "Hardware graphics acceleration (if available)";
    };
    storage = {
      optimization = mkEnableOption "Storage performance optimizations" // { default = true; };
      drivers = {
        virtio-blk = mkEnableOption "VirtIO block driver" // { default = true; };
        virtio-scsi = mkEnableOption "VirtIO SCSI driver" // { default = true; };
        ahci = mkEnableOption "AHCI SATA driver" // { default = true; };
      };
      trim = mkEnableOption "TRIM support for SSD optimization" // { default = true; };
    };
  };
  config =
    { cfg
    , config
    , lib
    , pkgs
    ,
    }:
    lib.mkMerge [
      (lib.mkIf cfg.guest.enable {
        services.qemuGuest.enable = cfg.guest.qga;
        services.spice-vdagentd.enable = cfg.guest.spice;
        services.udev.extraRules = ''
          SUBSYSTEM=="virtio", GROUP="kvm"
          KERNEL=="ttyS0", GROUP="dialout", MODE="0664"
          KERNEL=="vport*", GROUP="dialout", MODE="0664"
        '';
      })
      (lib.mkIf cfg.virtio.enable {
        boot.kernelModules = lib.flatten [
          (lib.optional cfg.virtio.drivers.balloon "virtio_balloon")
          (lib.optional cfg.virtio.drivers.console "virtio_console")
          (lib.optional cfg.virtio.drivers.rng "virtio_rng")
          (lib.optional cfg.virtio.drivers.net "virtio_net")
          (lib.optional cfg.virtio.drivers.blk "virtio_blk")
          (lib.optional cfg.virtio.drivers.scsi "virtio_scsi")
          (lib.optional cfg.virtio.drivers.gpu "virtio_gpu")
          (lib.optional cfg.virtio.drivers.fs "virtio_fs")
        ];
        boot.initrd.availableKernelModules = lib.flatten [
          (lib.optional cfg.virtio.drivers.blk "virtio_blk")
          (lib.optional cfg.virtio.drivers.scsi "virtio_scsi")
          (lib.optional cfg.virtio.drivers.net "virtio_net")
          [ "virtio_pci" ]
        ];
      })
      (lib.mkIf cfg.performance.enable {
        boot.kernelParams = lib.flatten [
          "elevator=${cfg.performance.kernel.elevator}"
          (lib.optional (!cfg.performance.cpu.mitigations) "mitigations=off")
          (lib.optional (!cfg.performance.cpu.mitigations) "spectre_v2=off")
          (lib.optional (!cfg.performance.cpu.mitigations) "spec_store_bypass_disable=off")
          (lib.optional cfg.performance.memory.hugepages "transparent_hugepage=always")
          "intel_idle.max_cstate=1"
          "processor.max_cstate=1"
          "idle=poll"
          "nohz=off"
          "rcu_nocbs=0-$(nproc)"
          "net.core.default_qdisc=fq"
          "net.ipv4.tcp_congestion_control=bbr"
        ];
        boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
        powerManagement.cpuFreqGovernor = cfg.performance.cpu.governor;
        boot.kernel.sysctl = lib.mkMerge [
          {
            "vm.swappiness" = 10;
            "vm.dirty_background_ratio" = 5;
            "vm.dirty_ratio" = 10;
            "vm.dirty_writeback_centisecs" = 1500;
            "vm.dirty_expire_centisecs" = 3000;
            "vm.vfs_cache_pressure" = 50;
          }
          (lib.mkIf cfg.performance.memory.ksm {
            "kernel.sched_migration_cost_ns" = 5000000;
            "kernel.sched_autogroup_enabled" = 0;
          })
          (lib.mkIf cfg.networking.optimization {
            "net.core.rmem_default" = 262144;
            "net.core.rmem_max" = 16777216;
            "net.core.wmem_default" = 262144;
            "net.core.wmem_max" = 16777216;
            "net.core.netdev_max_backlog" = 5000;
            "net.core.netdev_budget" = 600;
            "net.ipv4.tcp_rmem" = "4096 65536 16777216";
            "net.ipv4.tcp_wmem" = "4096 65536 16777216";
            "net.ipv4.tcp_congestion_control" = "bbr";
            "net.ipv4.tcp_fastopen" = 3;
            "net.ipv4.tcp_mtu_probing" = 1;
          })
        ];
        zramSwap = lib.mkIf cfg.performance.memory.zram {
          enable = true;
          algorithm = "zstd";
          memoryPercent = 25;
        };
        hardware.ksm = lib.mkIf cfg.performance.memory.ksm {
          enable = true;
          sleep = 1000;
        };
      })
      (lib.mkIf cfg.networking.optimization {
        boot.kernelModules = lib.flatten [
          (lib.optional cfg.networking.drivers.virtio-net "virtio_net")
          (lib.optional cfg.networking.drivers.e1000 "e1000")
          (lib.optional cfg.networking.drivers.rtl8139 "8139too")
        ];
        systemd.network.networks."10-vm-optimization" = {
          matchConfig.Type = "ether";
          linkConfig = {
            RxBufferSize = "16M";
            TxBufferSize = "16M";
            RxMiniBufferSize = "8M";
            RxJumboBufferSize = "32M";
          };
        };
      })
      (lib.mkIf cfg.graphics.enable {
        boot.kernelModules = lib.flatten [
          (lib.optional cfg.graphics.drivers.virtio-gpu "virtio_gpu")
          (lib.optional cfg.graphics.drivers.qxl "qxl")
          (lib.optional cfg.graphics.drivers.cirrus "cirrusfb")
        ];
        hardware.graphics = {
          enable = true;
          driSupport = cfg.graphics.acceleration;
          driSupport32Bit = cfg.graphics.acceleration;
        };
        services.xserver = lib.mkIf cfg.graphics.enable {
          videoDrivers = lib.flatten [
            (lib.optional cfg.graphics.drivers.virtio-gpu "virtio")
            (lib.optional cfg.graphics.drivers.qxl "qxl")
            (lib.optional cfg.graphics.drivers.cirrus "cirrus")
          ];
        };
      })
      (lib.mkIf cfg.storage.optimization {
        boot.kernelModules = lib.flatten [
          (lib.optional cfg.storage.drivers.virtio-blk "virtio_blk")
          (lib.optional cfg.storage.drivers.virtio-scsi "virtio_scsi")
          (lib.optional cfg.storage.drivers.ahci "ahci")
        ];
        boot.initrd.availableKernelModules = lib.flatten [
          (lib.optional cfg.storage.drivers.virtio-blk "virtio_blk")
          (lib.optional cfg.storage.drivers.virtio-scsi "virtio_scsi")
          (lib.optional cfg.storage.drivers.ahci "ahci")
          [ "sd_mod" "sr_mod" ]
        ];
        services.fstrim = lib.mkIf cfg.storage.trim {
          enable = true;
          interval = "weekly";
        };
        services.udev.extraRules = ''
          ACTION=="add|change", KERNEL=="vd[a-z]", ATTR{queue/scheduler}="${cfg.performance.kernel.elevator}"
          ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="${cfg.performance.kernel.elevator}"
          ACTION=="add|change", KERNEL=="vd[a-z]", ATTR{queue/nr_requests}="128"
          ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/nr_requests}="128"
        '';
      })
      {
        environment.systemPackages = with pkgs; [
          qemu-utils
          libvirt
          iotop
          nload
          htop
          ethtool
          tcpdump
          iperf3
          pciutils
          usbutils
          dmidecode
          lshw
          stress
          sysbench
          fio
          screen
          tmux
        ];
      }
    ];
  security = cfg: {
    security.sudo.wheelNeedsPassword = lib.mkDefault false;
    users.groups.kvm = { };
    users.groups.qemu = { };
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
      if (action.id == "org.libvirt.unix.manage" &&
      subject.isInGroup("wheel")) {
      return polkit.Result.YES;
      }
      });
    '';
  };
  dependencies = [ "core" ];
}) {
  inherit config lib pkgs inputs;
}
