{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.services.qubes.networking = {
    enable = mkEnableOption "the qubes networking services";
  };

  config = mkIf config.services.qubes.networking.enable {
    services.qubes.core.enable = true;
    services.qubes.core.networking = true;

    services.resolved.enable = true;

    systemd.services.qubes-network-uplink = {
      # ensure the service is started on boot, since Install is ignored
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = ["" "${config.services.qubes.core.package}/lib/qubes/init/network-uplink-wait.sh"];
      };
    };

    systemd.services."qubes-network-uplink@" = {
      serviceConfig = {
        ExecStart = ["" "${config.services.qubes.core.package}/lib/qubes/setup-ip add \"%i\""];
        ExecStop = ["" "${config.services.qubes.core.package}/lib/qubes/setup-ip remove \"%i\""];
      };
    };

    # prevents renaming of xenlight net interfaces, to avoid race conditions
    systemd.network.links."80-qubes-vif" = {
      matchConfig.Driver = "vif";
      linkConfig.NamePolicy = "";
    };

    # ensure that dhcpcd doesn't conflict with the qubes network configuration
    networking.dhcpcd.enable = false;
  };
}
