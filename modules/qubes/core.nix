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

      # TODO make the username configurable?
      users.groups = {
        qubes = {
          # supposedly this should be 98, however 995 matches the debian value
          gid = 995;
        };
        user = {
          gid = 1000;
        };
      };
      users.users.user = {
        createHome = true;
        group = "user";
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

      fileSystems = {
        "/proc/xen" = {
          device = "xen";
          fsType = "xenfs";
          noCheck = true;
        };
        "/rw" = {
          device = "/dev/xvdb";
          fsType = "auto";
          options = [
            "noauto"
            "defaults"
            "discard"
            "nosuid"
            "nodev"
          ];
        };
        "/home" = {
          depends = ["/rw"];
          device = "/rw/home";
          fsType = "none";
          options = [
            "noauto"
            "bind"
            "defaults"
            "nosuid"
            "nodev"
          ];
        };
        "/usr/local" = {
          depends = ["/rw"];
          device = "/rw/usrlocal";
          fsType = "none";
          options = [
            "noauto"
            "bind"
            "defaults"
          ];
        };
      };
      systemd.tmpfiles.rules = [
        # create mount point
        "d /rw 0755 root root"
        # create mount point
        "d /usr/local 0755 root root"
        # mkdir so that first-boot-completed can be created here
        "d /var/lib/qubes 0755 root root"
      ];
      swapDevices = [
        {
          device = "/dev/xvdc1";
        }
      ];

      # qfile-unpacker needs setuid otherwise it fails during initgroups
      security.wrappers.qfile-unpacker = {
        owner = "root";
        group = "root";
        source = "${pkgs.qubes-core-agent-linux}/bin/qfile-unpacker";
        setuid = true;
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

      systemd.services.qubes-early-vm-config = {
        # ensure the service is started on boot, since Install is ignored
        wantedBy = ["sysinit.target"];

        serviceConfig = {
          ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/qubes-early-vm-config.sh"];
        };
      };

      systemd.services.qubes-misc-post = {
        # ensure the service is started on boot, since Install is ignored
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/misc-post.sh"];
        };
      };

      systemd.services.qubes-mount-dirs = {
        # ensure the service is started on boot, since Install is ignored
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/mount-dirs.sh"];
        };
      };

      systemd.services.qubes-rootfs-resize = {
        # ensure the service is started on boot, since Install is ignored
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/resize-rootfs-if-needed.sh"];
        };
      };

      #systemd.services.qubes-sync-time = {
      # TODO how to setup the timer?

      systemd.services.qubes-sysinit = {
        # ensure the service is started on boot, since Install is ignored
        wantedBy = ["sysinit.target"];

        serviceConfig = {
          ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/qubes-sysinit.sh"];
        };
      };

      #systemd.services.qubes-update-check = {
      # TODO how to setup the timer?

      #systemd.services.qubes-updates-proxy-forwarder@ = {

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
