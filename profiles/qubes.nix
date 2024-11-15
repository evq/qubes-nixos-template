{
  config,
  lib,
  pkgs,
  ...
}: {
  services.qubes.qrexec.enable = true;
  services.qubes.gui.enable = true;
  services.qubes.networking.enable = true;
  services.qubes.usb.enable = true;

  fonts.enableDefaultPackages = true;

  # When running in PVH mode, the qubes init script will bind mount the kernel modules here
  systemd.tmpfiles.rules = [
    "d /lib/modules 0755 root root"
  ];
  # When running in PVH mode, the qubes init script expects /sbin/init to exist
  boot.loader.initScript.enable = true;

  # Don't use the GRUB 2 boot loader since it conflicts with initScript.enable
  boot.loader.grub.enable = false;
}
