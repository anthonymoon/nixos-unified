
{
  # This file defines the specific parameters for the 'unified-desktop' host.
  hostName = "unified-desktop";
  userName = "amoon";
  userFullName = "Anthony Moon";
  userEmail = "amoon@example.com";

  # The primary disk for the OS installation.
  diskDevice = "/dev/disk/by-id/nvme-CT2000T500SSD8_241047B9A4C2"; # Change this for a new machine

  # The main system profile to apply.
  systemProfile = ../../../profiles/home-desktop.nix;

  # The declarative disk layout for this host.
  diskoLayout = ./disko.nix;
}
