{
  config,
  lib,
  pkgs,
  ...
}: let
  # configure PATH so qubes-gui can find qubes-run-xorg
  # NOTE ideally this would be a normal makeWrapper, however the wrapper is created
  # before resholve rewrites the shell scripts and thus has the unresholved PATH.
  # also attempted to set via `path = [pkgs.qubes-gui-agent-linux];` in the systemd unit
  # however this seems to break the environment causing systemctl calls to fail and thus
  # qubes-gui-agent.service
  qubes-gui = pkgs.writeShellScriptBin "qubes-gui" ''
    export PATH='${pkgs.qubes-gui-agent-linux}/bin'
    exec -a "$0" "${pkgs.qubes-gui-agent-linux}/bin/qubes-gui"  "$@"
  '';
in
  with lib; {
    options.services.qubes.gui.enable = mkEnableOption "the qubes gui agent daemon";

    config = mkIf config.services.qubes.gui.enable {
      services.qubes.core.enable = true;
      services.qubes.db.enable = true;
      services.qubes.qrexec.enable = true;

      services.udev.packages = [
        pkgs.qubes-linux-utils
        pkgs.qubes-gui-agent-linux
      ];

      services.xserver.displayManager.startx.enable = true;
      environment.etc."X11/Xsession".source = config.services.xserver.displayManager.sessionData.wrapper;
      services.xserver.displayManager.sessionCommands = ''
        if [ -d ${pkgs.qubes-gui-agent-linux}/etc/X11/xinit/xinitrc.d ] ; then
         for f in ${pkgs.qubes-gui-agent-linux}/etc/X11/xinit/xinitrc.d/?*.sh ; do
          [ -x "$f" ] && . "$f"
         done
         unset f
        fi
      '';
      services.xserver.displayManager.session = [
        {
          manage = "window";
          name = "qubes-session";
          start = ''
            ${pkgs.qubes-gui-agent-linux}/bin/qubes-session
          '';
        }
      ];

      xdg.autostart.enable = true;
      systemd.user.targets.nixos-fake-graphical-session = {
        requires = ["xdg-desktop-autostart.target" "graphical-session.target"];
        before = ["xdg-desktop-autostart.target" "graphical-session.target"];
      };
      # adding to system packages will cause their xdg autostart files to be picked up
      environment.systemPackages = [
        pkgs.qubes-gui-agent-linux
      ];

      security.polkit.enable = true;
      security.pam.services.qubes-gui-agent = {
        rootOK = true;
        startSession = true;
      };

      systemd.packages = [pkgs.qubes-gui-agent-linux];
      systemd.services.qubes-gui-agent = {
        #
        requires = ["qubes-db.service"];
        # ensure the service is started on boot, since Install is ignored
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStartPre = ["" "${pkgs.bash}/bin/sh -c ${pkgs.qubes-gui-agent-linux}/lib/qubes/qubes-gui-agent-pre.sh"];
          ExecStart = ["" "${qubes-gui}/bin/qubes-gui $GUI_OPTS"];
        };
      };
    };
  }
