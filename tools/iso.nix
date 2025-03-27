{
  config,
  pkgs,
  lib,
  modulesPath,
  targetSystem,
  ...
}: let
  # this installer is based on
  # https://gitlab.com/misuzu/nixos-unattended-install-iso
  # Copyright (c) 2024 misuzu
  # MIT License
  # and https://github.com/NixOS/nixpkgs/blob/master/nixos/lib/make-disk-image.nix
  # Copyright (c) 2003-2025 Eelco Dolstra and the Nixpkgs/NixOS contributors
  # MIT License
  label = "nixos";
  bootSize = "256M";
  blockSize = toString (4 * 1024); # ext4fs block size (not block device sector size)
  configuration = ../examples/configuration.nix;
  flake = ../examples/flake.nix;
  installer = pkgs.writeShellApplication {
    name = "installer";
    runtimeInputs = with pkgs; [
      mesa
      wlroots
      dosfstools
      e2fsprogs
      gawk
      nixos-install-tools
      parted
      util-linux
      config.nix.package
    ];
    text = ''
      set -euo pipefail

      echo "Setting up disks..."
      for i in $(lsblk -pln -o NAME,TYPE | grep disk | awk '{ print $1 }'); do
        if [[ "$i" == "/dev/fd0" ]]; then
          echo "$i is a floppy, skipping..."
          continue
        fi
        if grep -ql "^$i" <(mount); then
          echo "$i is in use, skipping..."
        else
          DEVICE_MAIN="$i"
          break
        fi
      done
      if [[ -z "$DEVICE_MAIN" ]]; then
        echo "ERROR: No usable disk found on this machine!"
        exit 1
      else
        echo "Found $DEVICE_MAIN, erasing..."
      fi

      mebibyte=$(( 1024 * 1024 ))
      round_to_nearest() {
        echo $(( ( $1 / $2 + 1) * $2 ))
      }
      bootSize=$(round_to_nearest "$(numfmt --from=iec '${bootSize}')" $mebibyte)
      bootSizeMiB=$(( bootSize / 1024 / 1024 ))MiB

      parted --script "$DEVICE_MAIN" -- \
          mklabel gpt \
          mkpart ESP fat32 8MiB $bootSizeMiB \
          set 1 boot on \
          align-check optimal 1 \
          mkpart no-fs 0 1024KiB \
          set 2 bios_grub on \
          mkpart primary ext4 $bootSizeMiB 100% \
          align-check optimal 3 \
          print

      mkfs.ext4 -b ${blockSize} -L ${label} "$DEVICE_MAIN"3

      mkdir /mnt
      mount "$DEVICE_MAIN"3 /mnt

      mkdir -p /mnt/boot
      mkfs.vfat -n ESP "$DEVICE_MAIN"1
      mount "$DEVICE_MAIN"1 /mnt/boot

      echo "Installing the system..."
      nixos-install --no-channel-copy --no-root-password --option substituters "" --system ${targetSystem.config.system.build.toplevel}

      mkdir -p /mnt/etc/nixos
      cp ${configuration} /mnt/etc/nixos/configuration.nix
      cp ${flake} /mnt/etc/nixos/flake.nix

      echo "Done! Rebooting..."
      sleep 3
      reboot
    '';
  };
  installerFailsafe = pkgs.writeShellScript "failsafe" ''
    ${lib.getExe installer} || echo "ERROR: Installation failure!"
    sleep 3600
  '';
in {
  imports = [
    (modulesPath + "/installer/cd-dvd/iso-image.nix")
    (modulesPath + "/profiles/all-hardware.nix")
  ];

  boot.kernelParams = ["systemd.unit=serial-getty.target"];

  console = {
    earlySetup = true;
    font = "ter-v16n";
    packages = [pkgs.terminus_font];
  };

  services.getty.autologinUser = "root";
  programs.bash.interactiveShellInit = ''
    if [[ "$(tty)" =~ /dev/(tty1)$ ]]; then
      # workaround for https://github.com/NixOS/nixpkgs/issues/219239
      systemctl restart systemd-vconsole-setup.service

      reset

      ${installerFailsafe}
    fi
  '';

  isoImage.isoName = "${config.isoImage.isoBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
  isoImage.squashfsCompression = "zstd -Xcompression-level 15"; # xz takes forever
}
