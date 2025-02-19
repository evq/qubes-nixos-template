{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  options.services.qubes.usb.enable = mkEnableOption "enable usb over qrexec";

  config = mkIf config.services.qubes.usb.enable {
    environment.systemPackages = [ pkgs.usbutils ];
    services.qubes.qrexec.enable = true;
    services.qubes.qrexec.packages = [ pkgs.qubes-usb-proxy ];
    services.udev.packages = [
      pkgs.qubes-usb-proxy
    ];
  };
}
