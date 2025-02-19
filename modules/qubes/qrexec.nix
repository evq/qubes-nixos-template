{
  config,
  lib,
  pkgs,
  ...
}:
let
  qrexec_services = [
    "${pkgs.qubes-core-qrexec}/etc/qubes-rpc"
    "${pkgs.qubes-core-agent-linux}/etc/qubes-rpc"
  ] ++ map (x: "${x}/etc/qubes-rpc") config.services.qubes.qrexec.packages;
in
with lib;
{
  options.services.qubes.qrexec = {
    enable = mkEnableOption "the qubes remote exec agent daemon";
    packages = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
        List of packages containing {command}`qrexec` services.
        All files found in
        {file}`«pkg»/etc/qubes-rpc/`
        will be included.
      '';
      apply = map getBin;
    };
  };

  config = mkIf config.services.qubes.qrexec.enable {
    services.qubes.core.enable = true;

    boot.kernelModules = [
      "xen_evtchn"
      "xen_gntalloc"
    ];

    # adding to system packages will cause their xdg autostart files to be picked up
    environment.systemPackages = [
      pkgs.qubes-core-qrexec
    ];

    security.polkit.enable = true;
    security.pam.services.qrexec = {
      rootOK = true;
    };

    # TODO  just override parts of existing service?
    systemd.services.qubes-qrexec-agent = {
      description = "Qubes remote exec agent";
      requires = [ "qubes-db.service" ];
      wantedBy = [ "multi-user.target" ];
      after = [
        "systemd-modules-load.service"
        "xendriverdomain.service"
        "systemd-user-sessions.service"
      ];
      environment = {
        QREXEC_SERVICE_PATH = concatStringsSep ":" qrexec_services;
        QREXEC_MULTIPLEXER_PATH = "${pkgs.qubes-core-qrexec}/lib/qubes/qubes-rpc-multiplexer";
      };

      serviceConfig = {
        Type = "notify";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/log/qubes";
        ExecStart = "${pkgs.qubes-core-qrexec}/lib/qubes/qrexec-agent";
        KillMode = "process";
        SELinuxContext = "system_u:system_r:local_login_t:s0-s0:c0.c1023";
      };
    };
  };
}
