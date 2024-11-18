{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.qubes.core;
in
  with lib; {
    options.services.qubes.core = {
      enable = mkEnableOption "the core qubes services";
      networking = mkEnableOption "include core qubes networking services";
      package = mkOption {
        type = types.package;
        description = "qubes-core-agent-linux package as configured by the qubes module options";
        internal = true;
        defaultText = literalExpression "pkgs.qubes-core-agent-linux";
        default = pkgs.qubes-core-agent-linux;
      };
    };
    config = mkIf cfg.enable (
      let
        qubes-core-agent-linux =
          if cfg.networking
          then (pkgs.qubes-core-agent-linux.override {enableNetworking = true;})
          else (cfg.package.default);
      in {
        services.qubes.core.package = qubes-core-agent-linux;
        services.qubes.db.enable = true;

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
        security.pam.services.su.text = lib.mkDefault (lib.mkBefore ''
          auth sufficient ${pkgs.linux-pam}/lib/security/pam_succeed_if.so use_uid user ingroup qubes
        '');
        # ensure qvm-console-dispvm is logged in
        services.getty.autologinUser = "user";

        fileSystems = {
          "/" = {
            device = "/dev/mapper/dmroot";
            fsType = "ext4";
          };
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
          source = "${qubes-core-agent-linux}/bin/qfile-unpacker";
          setuid = true;
        };

        # adding to system packages will cause their xdg autostart files to be picked up
        environment.systemPackages = [
          qubes-core-agent-linux
        ];
        services.udev.packages = [
          pkgs.qubes-linux-utils
          qubes-core-agent-linux
        ];
        systemd.packages = [
          pkgs.qubes-linux-utils
          qubes-core-agent-linux
        ];

        # on other distros this is added on install of the package,
        # rather than create another module we just include in core
        systemd.services.qubes-meminfo-writer = {
          # ensure the service is started on boot, since Install is ignored
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            ExecStart = ["" "${pkgs.qubes-linux-utils}/bin/meminfo-writer 30000 100000 /run/meminfo-writer.pid"];
          };
        };

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

        systemd.sockets."qubes-updates-proxy-forwarder" = {
          # ensure the socket is activated, since Install is ignored
          wantedBy = ["multi-user.target"];
        };

        systemd.services."qubes-updates-proxy-forwarder@" = {
          serviceConfig = {
            ExecStart = ["" "${pkgs.qubes-core-qrexec}/bin/qrexec-client-vm --use-stdin-socket '' qubes.UpdatesProxy"];
          };
        };

        systemd.services.xendriverdomain = {
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/log/xen";
            # Note: the first "" overrides the ExecStart from the upstream unit
            ExecStart = ["" "${pkgs.xen}/bin/xl devd"];
          };
        };

        # since there is no global nix proxy setting, add aliases which will
        # inherit the proxy settings from nix-daemon set by update-proxy-configs
        environment.interactiveShellInit = ''
          alias nix="all_proxy=\$(systemctl show nix-daemon -p Environment | grep -oP '(?<=all_proxy=)[^ ]*') nix"
          alias nix-shell="all_proxy=\$(systemctl show nix-daemon -p Environment | grep -oP '(?<=all_proxy=)[^ ]*') nix-shell"
          alias nixos-rebuild="all_proxy=\$(systemctl show nix-daemon -p Environment | grep -oP '(?<=all_proxy=)[^ ]*') nixos-rebuild"
        '';
      }
    );
  }
