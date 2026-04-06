{
  lib,
  fetchFromGitHub,
  nixpkgs,
  pkgs,
  nixosConfig,
  qubesVersion,
  templateTimestamp ? "197001010000",
  dist ? "nixos",
}: let
  version = "4.0.6";
  toplevel = nixosConfig.config.system.build.toplevel;

  # See: https://reproducible-builds.org/docs/system-images/
  e2fsprogs-deterministic =
    let
      wrappedMke2fs = pkgs.writeShellScriptBin "mke2fs" ''
        exec ${pkgs.e2fsprogs.bin}/bin/mke2fs -E hash_seed=035cb65d-0a86-404a-bad7-19c88d05e400 "$@"
      '';
      drv = pkgs.symlinkJoin {
        name = "e2fsprogs-deterministic";
        paths = [
          pkgs.e2fsprogs.bin
          wrappedMke2fs
        ];
        postBuild = ''
          rm -f $out/bin/mkfs.ext4
          ln -s mke2fs $out/bin/mkfs.ext4
        '';
      };
    in
    drv // { bin = drv; };

  rootImg = (pkgs.callPackage "${nixpkgs}/nixos/lib/make-ext4-fs.nix" {
    storePaths = [ toplevel ];
    volumeLabel = "root";
    e2fsprogs = e2fsprogs-deterministic;
    populateImageCommands = ''
      mkdir -p ./files/nix/var/nix/profiles
      ln -s ${toplevel} ./files/nix/var/nix/profiles/system-1-link
      ln -s system-1-link ./files/nix/var/nix/profiles/system

      mkdir -p ./files/sbin
      ln -s /nix/var/nix/profiles/system/init ./files/sbin/init
      mkdir -p ./files/etc
      touch ./files/etc/NIXOS
      mkdir -p ./files/var
      ln -s /run ./files/var/run

      mkdir -p ./files/etc/nixos
      cp ${../examples/configuration.nix} ./files/etc/nixos/configuration.nix
      cp ${../examples/flake.nix} ./files/etc/nixos/flake.nix
    '';
  }).overrideAttrs (prev: {
    buildCommand = prev.buildCommand + ''
      truncate -s 10G $img
    '';
  });
in
  pkgs.stdenvNoCC.mkDerivation {
    name = "qubes-template-rpm";

    src = fetchFromGitHub {
      owner = "QubesOS";
      repo = "qubes-linux-template-builder";
      rev = "v${version}";
      hash = "sha256-ABfhqyg9PypuKWYe6yhEr99hxf7qWsYCwRyToGhPKZA=";
    };

    nativeBuildInputs = [
      pkgs.rpm
      pkgs.coreutils
      pkgs.gnutar
    ];

    dontConfigure = true;
    dontFixup = true;

    buildPhase = ''
      set -x

      mkdir -p qubeized_images/${dist}
      ln -s ${rootImg} qubeized_images/${dist}/root.img

      ln -s "appmenus_generic" appmenus
      cp template_generic.conf template.conf

      echo ${templateTimestamp} > build_timestamp_${dist}
      echo ${qubesVersion} > version

      substituteInPlace templates.spec --replace qubeized_images "$(pwd)/qubeized_images"
      substituteInPlace templates.spec --replace " appmenus" " $(pwd)/appmenus"
      substituteInPlace templates.spec --replace " template.conf" " $(pwd)/template.conf"

      substituteInPlace build_template_rpm --replace "rpmbuild --target" \
        "rpmbuild --define 'build_mtime_policy clamp_to_source_date_epoch' --target"
      substituteInPlace build_template_rpm --replace "rpmbuild --define" \
        "rpmbuild --define 'use_source_date_epoch_as_buildtime 1' --define"

      DIST=${dist} ./build_template_rpm ${dist}
    '';

    installPhase = ''
      mkdir $out/
      mv rpm/noarch/*.rpm $out/
    '';
  }
