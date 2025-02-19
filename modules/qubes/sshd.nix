{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  options.services.qubes.sshd.enable = mkEnableOption "enable sshd over qrexec";

  config = mkIf config.services.qubes.sshd.enable {
    services.qubes.networking.enable = true;
    services.qubes.qrexec.enable = true;

    services.qubes.qrexec.packages = [ pkgs.qubes-sshd ];
    services.openssh.enable = true;
  };
}
