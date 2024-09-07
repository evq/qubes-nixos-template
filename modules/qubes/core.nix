{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.services.qubes.core = {
    enable = mkEnableOption "the core qubes services";
    networking = mkEnableOption "include core qubes networking services";
  };
  config = mkIf config.services.qubes.core.enable (
    let
      qubes-core-agent-linux =
        if config.services.qubes.core.networking
        then (pkgs.qubes-core-agent-linux.override {enableNetworking = true;})
        else (pkgs.qubes-core-agent-linux);
    in {
      services.qubes.db.enable = true;
      services.qubes.networking.package = qubes-core-agent-linux;

      users.groups.qubes = {
        gid = 98;
      };
      # TODO make the username configurable?
      users.users.user = {
        createHome = true;
        extraGroups = ["qubes" "wheel"];
        home = "/home/user";
        isNormalUser = true;
        password = "";
        shell = pkgs.bash;
        uid = 1000;
      };
      security.sudo.wheelNeedsPassword = false;
      # ensure qvm-console-dispvm is logged in
      services.getty.autologinUser = "user";

      fileSystems."/proc/xen" = {
        device = "xen";
        fsType = "xenfs";
        noCheck = true;
      };

      services.udev.packages = [
        pkgs.qubes-linux-utils
        qubes-core-agent-linux
      ];
      systemd.packages = [
        qubes-core-agent-linux
      ];
      # adding to system packages will cause their xdg autostart files to be picked up
      environment.systemPackages = [
        pkgs.qubes-core-agent-linux
      ];

      systemd.services.qubes-sysinit = {
        # ensure the service is started on boot, since Install is ignored
        wantedBy = ["sysinit.target"];

        serviceConfig = {
          ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/qubes-sysinit.sh"];
        };
      };

      systemd.services.xendriverdomain = {
        serviceConfig = {
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/log/xen";
          # Note: the first "" overrides the ExecStart from the upstream unit
          ExecStart = ["" "${pkgs.xenPackages.xen_4_17-slim}/bin/xl devd"];
        };
      };
    }
  );
}
