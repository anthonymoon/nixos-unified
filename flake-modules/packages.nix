{ self
, inputs
, ...
}: {
  perSystem =
    { config
    , self'
    , inputs'
    , pkgs
    , system
    , ...
    }: {
      packages = {
        installer = pkgs.writeShellScriptBin "nixos-nixies-installer" ''
          set -euo pipefail
          RED='\033[0;31m'
          GREEN='\033[0;32m'
          YELLOW='\033[1;33m'
          BLUE='\033[0;34m'
          NC='\033[0m'
          print_info() {
          echo -e "''${BLUE}[INFO]''${NC} $1"
          }
          print_success() {
          echo -e "''${GREEN}[SUCCESS]''${NC} $1"
          }
          print_warning() {
          echo -e "''${YELLOW}[WARNING]''${NC} $1"
          }
          print_error() {
          echo -e "''${RED}[ERROR]''${NC} $1"
          }
          show_usage() {
          echo "NixOS Nixies Installer"
          echo ""
          echo "Usage: $0 <profile> <hostname> [disk]"
          echo ""
          echo "Profiles:"
          echo "  workstation  - Desktop workstation with Niri/Hyprland"
          echo "  server       - Hardened server configuration"
          echo "  development  - Development environment"
          echo "  gaming       - Gaming-optimized workstation"
          echo "  base         - Minimal base system"
          echo ""
          echo "Examples:"
          echo "  $0 workstation my-laptop"
          echo "  $0 server my-server /dev/nvme0n1"
          echo ""
          }
          if [ $
          show_usage
          exit 1
          fi
          profile="$1"
          hostname="$2"
          disk="''${3:-}"
          case "$profile" in
          workstation|server|development|gaming|base)
          print_info "Using profile: $profile"
          ;;
          *)
          print_error "Unknown profile: $profile"
          show_usage
          exit 1
          ;;
          esac
          if [ -z "$disk" ]; then
          print_info "Auto-detecting installation disk..."
          for candidate in /dev/nvme0n1 /dev/sda /dev/vda; do
          if [ -b "$candidate" ]; then
          disk="$candidate"
          print_info "Found disk: $disk"
          break
          fi
          done
          if [ -z "$disk" ]; then
          print_error "Could not auto-detect disk. Please specify as third argument."
          exit 1
          fi
          fi
          print_warning "This will ERASE ALL DATA on $disk"
          echo "  Profile: $profile"
          echo "  Hostname: $hostname"
          echo "  Disk: $disk"
          echo ""
          read -p "Continue? (yes/no): " confirm
          if [ "$confirm" != "yes" ]; then
          print_info "Installation cancelled."
          exit 0
          fi
          print_info "Starting NixOS Unified installation..."
          print_info "Partitioning disk..."
          parted "$disk" -- mklabel gpt
          parted "$disk" -- mkpart primary 512MiB -8GiB
          parted "$disk" -- mkpart primary linux-swap -8GiB 100%
          parted "$disk" -- mkpart ESP fat32 1MiB 512MiB
          parted "$disk" -- set 3 esp on
          print_info "Formatting partitions..."
          mkfs.ext4 -L nixos "''${disk}p1" || mkfs.ext4 -L nixos "''${disk}1"
          mkswap -L swap "''${disk}p2" || mkswap -L swap "''${disk}2"
          mkfs.fat -F 32 -n boot "''${disk}p3" || mkfs.fat -F 32 -n boot "''${disk}3"
          print_info "Mounting filesystems..."
          mount /dev/disk/by-label/nixos /mnt
          mkdir -p /mnt/boot
          mount /dev/disk/by-label/boot /mnt/boot
          swapon /dev/disk/by-label/swap
          print_info "Generating hardware configuration..."
          nixos-generate-config --root /mnt
          print_info "Creating installation configuration..."
          cat > /mnt/etc/nixos/flake.nix << EOF
          {
          inputs = {
          nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
          nixos-nixies.url = "github:amoon/nixos-nixies";
          };
          outputs = { nixpkgs, nixos-nixies, ... }: {
          nixosConfigurations.$hostname = nixos-nixies.lib.mkSystem {
          hostname = "$hostname";
          profiles = [ "$profile" ];
          modules = [
          ./hardware-configuration.nix
          ];
          };
          };
          }
          EOF
          print_info "Installing NixOS..."
          nixos-install --flake "/mnt/etc/nixos
          print_success "Installation completed!"
          print_info "Next steps:"
          print_info "1. Reboot: reboot"
          print_info "2. Set user passwords"
          print_info "3. Configure SSH keys"
          print_info "4. Customize configuration in /etc/nixos/flake.nix"
        '';
        security-audit = pkgs.writeShellScriptBin "nixos-nixies-security-audit" ''
          set -euo pipefail
          echo "🛡️  NixOS Unified Security Audit"
          echo "==============================="
          echo ""
          failed_checks=0
          echo "🔥 Checking firewall..."
          if systemctl is-active --quiet firewall; then
          echo "  ✅ Firewall is active"
          else
          echo "  ❌ Firewall is not active"
          failed_checks=$((failed_checks + 1))
          fi
          echo ""
          echo "🔐 Checking SSH configuration..."
          if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
          echo "  ✅ Root SSH login is disabled"
          else
          echo "  ❌ Root SSH login is not properly disabled"
          failed_checks=$((failed_checks + 1))
          fi
          if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
          echo "  ✅ SSH password authentication is disabled"
          else
          echo "  ⚠️  SSH password authentication is enabled"
          fi
          echo ""
          echo "🚫 Checking intrusion detection..."
          if systemctl is-active --quiet fail2ban; then
          echo "  ✅ Fail2ban is active"
          else
          echo "  ⚠️  Fail2ban is not active"
          fi
          echo ""
          echo "🛡️  Checking mandatory access control..."
          if systemctl is-active --quiet apparmor; then
          echo "  ✅ AppArmor is active"
          else
          echo "  ⚠️  AppArmor is not active"
          fi
          echo ""
          echo "🔑 Checking for default passwords..."
          if grep -q "hashedPassword.*nixos" /etc/nixos/configuration.nix 2>/dev/null; then
          echo "  ❌ Default passwords detected in configuration"
          failed_checks=$((failed_checks + 1))
          else
          echo "  ✅ No default passwords found in configuration"
          fi
          echo ""
          echo "📦 Checking system updates..."
          if [ -f /var/lib/nixos/current-config-generation ]; then
          current=$(readlink /nix/var/nix/profiles/system | sed 's/.*system-//' | sed 's/-.*//')
          last_update=$(stat -c %Y /nix/var/nix/profiles/system)
          days_old=$(( ($(date +%s) - last_update) / 86400 ))
          if [ $days_old -lt 30 ]; then
          echo "  ✅ System updated $days_old days ago"
          else
          echo "  ⚠️  System not updated for $days_old days"
          fi
          fi
          echo ""
          echo "==============================="
          if [ $failed_checks -eq 0 ]; then
          echo "✅ Security audit passed ($failed_checks critical issues)"
          else
          echo "❌ Security audit failed ($failed_checks critical issues)"
          exit 1
          fi
        '';
        performance-benchmark = pkgs.writeShellScriptBin "nixos-nixies-benchmark" ''
          set -euo pipefail
          echo "⚡ NixOS Unified Performance Benchmark"
          echo "====================================="
          echo ""
          echo "🖥️  System Information:"
          echo "  OS: $(uname -sr)"
          echo "  CPU: $(nproc) cores"
          echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
          echo "  Uptime: $(uptime -p)"
          echo ""
          echo "🚀 Boot Performance:"
          systemd-analyze time
          echo ""
          echo "⏱️  Slowest Services:"
          systemd-analyze blame | head -10
          echo ""
          echo "💾 Memory Usage:"
          free -h
          echo ""
          echo "  Top memory consumers:"
          ps aux --sort=-%mem --no-headers | head -5 | awk '{printf "    %s: %s%%\n", $11, $4}'
          echo ""
          echo "💿 Disk Usage:"
          df -h / /boot 2>/dev/null || df -h /
          echo ""
          echo "  Nix store size:"
          du -sh /nix/store 2>/dev/null || echo "    Unable to check Nix store"
          echo ""
          echo "🌐 Network Configuration:"
          ip route show default | head -1
          echo ""
          echo "📊 System Load:"
          uptime
          echo ""
          boot_time=$(systemd-analyze time 2>/dev/null | grep "startup finished" | sed 's/.*= //' | sed 's/s$//' || echo "30")
          mem_usage=$(free 2>/dev/null | grep Mem | awk '{printf "%.0f", $3/$2 * 100}' || echo "45")
          echo "📈 Performance Summary:"
          echo "  Boot time: ''${boot_time}s"
          echo "  Memory usage: ''${mem_usage}%"
          if (( $(echo "''$boot_time < 30" | bc -l) )); then
          echo "  Boot performance: Excellent"
          elif (( $(echo "''$boot_time < 60" | bc -l) )); then
          echo "  Boot performance: Good"
          else
          echo "  Boot performance: Needs improvement"
          fi
          if [ "''$mem_usage" -lt 50 ]; then
          echo "  Memory efficiency: Excellent"
          elif [ "''$mem_usage" -lt 75 ]; then
          echo "  Memory efficiency: Good"
          else
          echo "  Memory efficiency: High usage"
          fi
        '';
        migration-helper = pkgs.writeShellScriptBin "nixos-nixies-migrate" ''
          set -euo pipefail
          echo "🔄 NixOS Unified Migration Helper"
          echo "================================"
          echo ""
          if [ $
          echo "Usage: $0 <source-config-dir>"
          echo ""
          echo "This tool helps migrate existing NixOS configurations to NixOS Unified."
          echo ""
          exit 1
          fi
          source_dir="$1"
          if [ ! -d "$source_dir" ]; then
          echo "❌ Source directory $source_dir does not exist"
          exit 1
          fi
          echo "📁 Analyzing source configuration: $source_dir"
          echo ""
          echo "🔍 Configuration Analysis:"
          if [ -f "$source_dir/flake.nix" ]; then
          echo "  ✅ Flake-based configuration detected"
          else
          echo "  ⚠️  Legacy configuration.nix detected"
          fi
          if grep -r "home-manager" "$source_dir" >/dev/null 2>&1; then
          echo "  ✅ Home Manager integration found"
          else
          echo "  ℹ️  No Home Manager detected"
          fi
          if grep -r "steam\|gaming" "$source_dir" >/dev/null 2>&1; then
          echo "  🎮 Gaming configuration detected"
          fi
          if grep -r "docker\|vscode\|development" "$source_dir" >/dev/null 2>&1; then
          echo "  💻 Development tools detected"
          fi
          if grep -r "gnome\|kde\|xfce\|niri\|hyprland" "$source_dir" >/dev/null 2>&1; then
          echo "  🖥️  Desktop environment detected"
          fi
          echo ""
          echo "🎯 Recommended Migration Path:"
          if grep -r "server\|headless" "$source_dir" >/dev/null 2>&1; then
          echo "  Profile: server"
          elif grep -r "gaming\|steam" "$source_dir" >/dev/null 2>&1; then
          echo "  Profile: gaming"
          elif grep -r "development\|docker\|vscode" "$source_dir" >/dev/null 2>&1; then
          echo "  Profile: development"
          else
          echo "  Profile: workstation"
          fi
          echo ""
          echo "📋 Migration Steps:"
          echo "1. Create new unified configuration:"
          echo "   nix flake new -t github:user/nixos-unified
          echo ""
          echo "2. Copy hardware configuration:"
          echo "   cp $source_dir/hardware-configuration.nix my-unified-config/"
          echo ""
          echo "3. Review and adapt custom configurations"
          echo "4. Test the new configuration"
          echo "5. Deploy when ready"
          echo ""
          echo "For detailed migration guide, see:"
          echo "https://github.com/user/nixos-unified/docs/migration.md"
        '';
        default = self'.packages.installer;
      };
    };
}
