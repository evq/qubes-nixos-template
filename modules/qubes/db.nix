{
  config,
  lib,
  pkgs,
  ...
}: let
  init = pkgs.writeShellScriptBin "qubes-db-init" ''
    ${pkgs.coreutils}/bin/mkdir -p /var/log/qubes
    ${pkgs.coreutils}/bin/mkdir -m 0775 -p /var/run/qubes
  '';
in
  with lib; {
    options.services.qubes.db.enable = mkEnableOption "the qubes db daemon";

    config = mkIf config.services.qubes.db.enable {
      boot.kernelModules = ["xen_gntdev" "xen_evtchn"];

      environment.systemPackages = [
        pkgs.qubes-core-qubesdb
      ];
      # TODO  just override parts of existing service?
      systemd.services.qubes-db = {
        description = "Qubes DB agent";
        after = ["systemd-modules-load.service"];

        unitConfig = {
          DefaultDependencies = false;
        };

        serviceConfig = {
          Group = "qubes";
          Type = "notify";
          ExecStartPre = "${init}/bin/qubes-db-init";
          ExecStart = "${pkgs.qubes-core-qubesdb}/sbin/qubesdb-daemon 0";
        };
      };
    };
  }
