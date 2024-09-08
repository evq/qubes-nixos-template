{
  config,
  lib,
  pkgs,
  writeShellScriptBin,
  ...
}:
with lib; {
  options.services.qubes.updates = {
    check = mkEnableOption "enable updates check, can be resource intensive due to required nix build";
    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--update-input"
        "nixpkgs"
      ];
      example = [
        "-I"
        "stuff=/home/alice/nixos-stuff"
        "--option"
        "extra-binary-caches"
        "http://my-cache.example.org/"
      ];
      description = ''
        Any additional flags passed to {command}`nixos-rebuild`, used for both the check and actual update.

        If you are using flakes and use a local repo you can add
        {command}`[ "--update-input" "nixpkgs" "--commit-lock-file" ]`
        to update nixpkgs.
      '';
    };
  };
  config = mkMerge [
    (
      mkIf config.services.qubes.updates.check {
        systemd.timers.qubes-update-check = {
          wantedBy = ["timers.target"];
        };
      }
    )
    (
      let
        checkUpdatesScript = pkgs.writeShellScriptBin "upgrades-status-notify" ''
          set -e

          if [ "$1" = "started-by-init" ]; then
              true "INFO: Started by systemd unit (timer.) Continuing..."
          else
              true "INFO: Not started by systemd unit (timer.) Probably started by package manager hook script."
              if test -e /run/qubes/persistent-full; then
                  true "INFO: Running inside Template and Standalone. Continuing..."
              else
                  true "INFO: Probably running inside App Qube. Stop."
                  exit 0
              fi
          fi

          tempdir=$(mktemp -d /tmp/tmp.nix-updateinfo.XXX)
          cp -r /etc/nixos/. $tempdir
          cd $tempdir
          ${config.nix.package.out}/bin/nix build ".#nixosConfigurations.$(${pkgs.nettools}/bin/hostname).config.system.build.toplevel" ${toString config.services.qubes.updates.flags} 1>&2
          nix_diff=$(${config.nix.package.out}/bin/nix store diff-closures /run/current-system ./result \
            | ${pkgs.gawk}/bin/awk '/[0-9] →|→ [0-9]/ && !/nixos/' || true)
          echo "$nix_diff" 1>&2
          if [ -z "$nix_diff" ]; then
            ${pkgs.qubes-core-qrexec}/lib/qubes/qrexec-client-vm dom0 qubes.NotifyUpdates /bin/sh -c 'echo 0'
          else
            ${pkgs.qubes-core-qrexec}/lib/qubes/qrexec-client-vm dom0 qubes.NotifyUpdates /bin/sh -c 'echo 1'
          fi
          cd ~-
          rm -rf "$tempdir"
        '';

        installUpdates = pkgs.writeTextFile {
          name = "qubes-rpc-installupdatesgui";
          text = ''
            #!${pkgs.stdenv.shell}
            update_cmd='${config.system.build.nixos-rebuild}/bin/nixos-rebuild switch ${toString config.services.qubes.updates.flags}'

            ${pkgs.xterm}/bin/xterm -title update -e su -s /bin/sh -l -c "$update_cmd; echo Done.; test -f /var/run/qubes/this-is-templatevm && { echo Press Enter to shutdown the template, or Ctrl-C to just close this window; read x && ${pkgs.systemd}/bin/poweroff; } ;"

            # Notify dom0 about installed updates
            ${pkgs.systemd}/bin/systemctl start qubes-update-check
          '';
          executable = true;
          destination = "/etc/qubes-rpc/qubes.InstallUpdatesGUI";
        };
      in {
        services.qubes.qrexec.packages = [installUpdates];
        systemd.services.qubes-update-check = {
          serviceConfig = {
            ExecStart = ["" "${checkUpdatesScript}/bin/upgrades-status-notify started-by-init"];
          };
        };
      }
    )
  ];
}
