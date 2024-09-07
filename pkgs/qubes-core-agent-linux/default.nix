{
  fetchFromGitHub,
  lib,
  resholve,
  wrapGAppsNoGuiHook,
  stdenv,
  bash,
  coreutils,
  diffutils,
  e2fsprogs,
  dconf,
  desktop-file-utils,
  fakeroot,
  findutils,
  gawk,
  getent,
  gnome-packagekit,
  gnugrep,
  gobject-introspection,
  graphicsmagick,
  haveged,
  iproute2,
  kmod,
  librsvg,
  lsb-release,
  lvm2,
  mount,
  nettools,
  ntp,
  pandoc,
  parted,
  pkg-config,
  procps,
  psmisc,
  python3,
  python3Packages,
  qubes-core-qrexec,
  qubes-core-qubesdb,
  qubes-core-vchan-xen,
  qubes-linux-utils,
  gnused,
  shared-mime-info,
  socat,
  systemd,
  umount,
  util-linux,
  xdg-utils,
  xorg,
  zenity,
  # FIXME networking optional
  networkmanager,
  tinyproxy,
  nftables,
  conntrack-tools,
  enableNetworking ? false,
}: let
  scripts_using_functions = [
    "lib/qubes/init/qubes-early-vm-config.sh"
    "lib/qubes/init/qubes-sysinit.sh"
    "lib/qubes/init/misc-post.sh"
    "lib/qubes/init/mount-dirs.sh"
    "lib/qubes/init/setup-rwdev.sh"
    "lib/qubes/init/bind-dirs.sh"
  ];
  scripts =
    scripts_using_functions
    ++ [
      "etc/qubes-rpc/qubes.Filecopy"
      "etc/qubes-rpc/qubes.VMShell"
      "etc/qubes-rpc/qubes.WaitForSession"
      "lib/qubes/init/functions"
      "lib/qubes/init/setup-rw.sh"
      "lib/qubes/init/resize-rootfs-if-needed.sh"
      "lib/qubes/resize-rootfs"
      "lib/qubes/update-proxy-configs"
    ];
in
  resholve.mkDerivation rec {
    version = "4.3.5";
    pname = "qubes-core-agent-linux";

    #PKG_CONFIG_SYSTEMD_SYSTEMDSYSTEMUNITDIR = "${placeholder "out"}/lib/systemd/system";

    src = fetchFromGitHub {
      owner = "QubesOS";
      repo = "qubes-core-agent-linux";
      rev = "v${version}";
      hash = "sha256-ff+L1t6TYCD9S6iyCebZlIuYP0oHnUcQiSdOJ1YHSQw=";
    };

    nativeBuildInputs =
      [
        bash
        desktop-file-utils
        gobject-introspection
        lsb-release
        pandoc
        pkg-config
        python3
        qubes-core-qubesdb
        qubes-core-vchan-xen
        qubes-linux-utils
        shared-mime-info
        wrapGAppsNoGuiHook
        xorg.libX11
      ]
      ++ (with python3Packages; [
        wrapPython
        distutils
        setuptools
      ]);

    buildInputs =
      [
        coreutils
        dconf
        fakeroot
        gawk
        gnome-packagekit
        gnused
        graphicsmagick
        haveged
        iproute2
        librsvg
        ntp
        parted
        procps
        python3
        qubes-core-qrexec
        qubes-core-qubesdb
        qubes-core-vchan-xen
        qubes-linux-utils
        socat
        xdg-utils
        zenity
      ]
      ++ lib.optional enableNetworking networkmanager
      ++ lib.optional enableNetworking tinyproxy
      ++ lib.optional enableNetworking nftables
      ++ lib.optional enableNetworking conntrack-tools
      ++ (with python3Packages; [
        dbus-python
        pygobject3
        pyxdg
      ]);

    postPatch = ''
      substituteInPlace Makefile --replace 'SHELL = /bin/bash' 'SHELL = ${bash}/bin/bash'

      # skip installing qfile-unpacker / bin-qfile-unpacker as SUID
      sed -i 's/-m 4755/-m 755/g' qubes-rpc/Makefile
    '';

    buildPhase = ''
      # Fix for network tools paths
      # FIXME use substituteInPlace
      # sed 's:/sbin/ip:pkgs.iproute2/bin/ip:g' -i network/*
      # sed 's:/bin/grep:pkgs.grep/bin/grep:g' -i network/*

      # Fix for archlinux sbindir
      # FIXME use substituteInPlace
      # sed 's:/usr/sbin/ntpdate:/usr/bin/ntpdate:g' -i qubes-rpc/sync-ntp-clock

      for dir in qubes-rpc misc; do
          make -C "$dir"
      done
    '';

    # Don't move doc, needed in the subsequent packaging
    forceShare = ["man" "info"];

    # FIXME
    # - finish path fixup
    # - investigate which archlinux specific installs need replacement
    # - fixup services in lib/systemd/system/
    # - figure out how to adapt service dropins?
    installPhase =
      ''
        # install -D -m 0644 -- "boot/grub.qubes" "$out/etc/default/grub.qubes"
        make install-corevm \
            PYTHON_PREFIX_ARG="--prefix ." \
            DESTDIR="$out" \
            BINDIR=/bin \
            SBINDIR=/bin \
            LIBDIR=/lib \
            SYSLIBDIR=/lib \
            SYSTEM_DROPIN_DIR=/usr/lib/systemd/system \
            USER_DROPIN_DIR=/usr/lib/systemd/user \
            DIST=nixos \
            PYTHON=${python3}/bin/python3
        make -C app-menu install DESTDIR="$out" install BINDIR=/bin LIBDIR=/lib
        make -C misc install DESTDIR="$out" LIBDIR=/lib SYSLIBDIR=/lib
        make -C qubes-rpc DESTDIR="$out" BINDIR=/bin LIBDIR=/lib install
        make -C qubes-rpc/caja DESTDIR="$out" BINDIR=/bin LIBDIR=/lib install
        make -C qubes-rpc/kde DESTDIR="$out" BINDIR=/bin LIBDIR=/lib install
        make -C qubes-rpc/nautilus DESTDIR="$out" BINDIR=/bin LIBDIR=/lib QUBESLIBDIR=/lib/qubes install
        make -C qubes-rpc/thunar DESTDIR="$out" BINDIR=/bin LIBDIR=/lib install

        # install cron bindmount
        mkdir -p "$out/lib/qubes-bind-dirs.d"
        install -m 0644 "filesystem/30_cron.conf" "$out/lib/qubes-bind-dirs.d/30_cron.conf"

        # nixos does not have /etc/skel, initialize_home() requires it
        substituteInPlace "$out/lib/qubes/init/functions" --replace "/etc/skel" "/var/empty"

        # Fixup paths
        substituteInPlace "$out/bin/qubes-session-autostart" --replace "QUBES_XDG_CONFIG_DROPINS = '/etc/qubes/autostart'" "QUBES_XDG_CONFIG_DROPINS = \"$out/etc/qubes/autostart\""

        # use suid wrapper we will create in the module
        substituteInPlace "$out/etc/qubes-rpc/qubes.Filecopy" --replace "/usr/lib/qubes/qfile-unpacker" "/run/wrappers/bin/qfile-unpacker"

        for path in ${lib.concatStringsSep " " scripts_using_functions}; do
          substituteInPlace "$out/$path" --replace '/usr/lib/qubes/init/functions' "functions"
        done

        substituteInPlace "$out/lib/qubes/init/bind-dirs.sh" --replace "for source_folder in /usr/lib/qubes-bind-dirs.d /etc/qubes-bind-dirs.d /rw/config/qubes-bind-dirs.d ; do" "for source_folder in $out/lib/qubes-bind-dirs.d /rw/config/qubes-bind-dirs.d ; do"

        # Install systemd script allowing to automount /lib/modules
        # install -m 644 "archlinux/PKGBUILD.qubes-ensure-lib-modules.service" "$out/usr/lib/systemd/system/qubes-ensure-lib-modules.service"

        # Install pacman hook to update desktop icons
        # mkdir -p "$out/usr/share/libalpm/hooks/"
        # install -m 644 "archlinux/PKGBUILD.qubes-update-desktop-icons.hook" "$out/usr/share/libalpm/hooks/qubes-update-desktop-icons.hook"

        # Install pacman hook to notify dom0 about successful upgrade
        # install -m 644 "archlinux/PKGBUILD.qubes-post-upgrade.hook" "$out/usr/share/libalpm/hooks/qubes-post-upgrade.hook"

        # Install pacman.d drop-ins (at least 1 drop-in must be installed or pacman will fail)
        # mkdir -p -m 0755 "$out/etc/pacman.d"
        # install -m 644 "archlinux/PKGBUILD-qubes-pacman-options.conf" "$out/etc/pacman.d/10-qubes-options.conf"

        # Install upgrade check scripts
        # install -m 0755 "package-managers/upgrades-installed-check" "$out/usr/lib/qubes/"
        # install -m 0755 "package-managers/upgrades-status-notify" "$out/usr/lib/qubes/"

        mv "$out/usr/share" "$out/share"
        mv "$out/etc/systemd/system/xendriverdomain.service" "$out/lib/systemd/system/"

        rm -rf "$out/var/run"
      ''
      + lib.optionalString (!enableNetworking) ''
        # mock update-proxy-configs with an empty script
        echo "#!${bash}/bin/sh" > "$out/lib/qubes/update-proxy-configs"
        chmod +x "$out/lib/qubes/update-proxy-configs"
      ''
      + lib.optionalString enableNetworking ''
        make -C network install \
            PYTHON_PREFIX_ARG="--prefix ." \
            DESTDIR="$out" \
            BINDIR=/bin \
            SBINDIR=/bin \
            LIBDIR=/lib \
            SYSLIBDIR=/lib \
            SYSTEM_DROPIN_DIR=/usr/lib/systemd/system \
            USER_DROPIN_DIR=/usr/lib/systemd/user \
            DIST=nixos
        make install-netvm \
            PYTHON_PREFIX_ARG="--prefix ." \
            DESTDIR="$out" \
            BINDIR=/bin \
            SBINDIR=/bin \
            LIBDIR=/lib \
            SYSLIBDIR=/lib \
            SYSTEM_DROPIN_DIR=/usr/lib/systemd/system \
            USER_DROPIN_DIR=/usr/lib/systemd/user \
            DIST=nixos


        for path in lib/qubes/init/network-uplink-wait.sh lib/qubes/setup-ip lib/qubes/update-proxy-configs ; do
          substituteInPlace "$out/$path" --replace '/usr/lib/qubes/init/functions' "functions"
        done

        substituteInPlace "$out/etc/udev/rules.d/99-qubes-network.rules" --replace '/usr/bin/systemctl' '${systemd}/bin/systemctl'

        mv "$out/etc/udev/rules.d/99-qubes-network.rules" "$out/lib/udev/rules.d/"
      '';

    solutions = {
      default = {
        scripts =
          scripts
          ++ lib.optional enableNetworking "lib/qubes/init/network-uplink-wait.sh"
          ++ lib.optional enableNetworking "lib/qubes/setup-ip";
        interpreter = "none";
        fake.external =
          # guarded by check for /sys/fs/selinux
          ["restorecon"]
          ++ lib.optional (!enableNetworking) "ip";
        fix = {
          "/bin/bash" = true;
          "/usr/bin/qubesdb-read" = true;
          "/usr/lib/qubes/init/bind-dirs.sh" = true;
          "/usr/lib/qubes/init/setup-rw.sh" = true;
          "/usr/lib/qubes/init/setup-rwdev.sh" = true;
          "/usr/lib/qubes/qubes-setup-dnat-to-ns" = true;
          "/usr/lib/qubes/qvm_nautilus_bookmark.sh" = true;
          "/usr/lib/qubes/resize-rootfs" = true;
          "/usr/lib/qubes/update-proxy-configs" = true;
          "/lib/systemd/systemd-sysctl" = true;
          "/sbin/ip" = true;
          umount = true;
          mount = true;
        };
        inputs =
          [
            "lib/qubes"
            "lib/qubes/init"
            "${qubes-core-qrexec}/lib/qubes"
            "${systemd}/lib/systemd"
            bash
            coreutils
            diffutils
            e2fsprogs
            findutils
            gawk
            getent
            gnugrep
            gnused
            kmod
            lvm2
            mount
            nettools
            networkmanager
            parted
            procps
            psmisc
            qubes-core-qrexec
            qubes-core-qubesdb
            stdenv.cc.libc
            systemd
            umount
            util-linux
          ]
          ++ lib.optional enableNetworking iproute2;
        keep = {
          source = ["$file_name"];
          "$rc" = true;
          "/rw/config/qubes_ip_change_hook" = enableNetworking;
          "/rw/config/qubes-ip-change-hook" = enableNetworking;
          "/run/wrappers/bin/qfile-unpacker" = true;
        };
        execer =
          [
            "cannot:${e2fsprogs}/bin/fsck.ext4"
            "cannot:${e2fsprogs}/bin/mkfs.ext4"
            "cannot:${kmod}/bin/modprobe"
            "cannot:${lib.getBin lvm2}/bin/dmsetup"
            "cannot:${networkmanager}/bin/nmcli"
            "cannot:${systemd}/bin/systemctl"
            "cannot:${systemd}/bin/udevadm"
            "cannot:lib/qubes/init/bind-dirs.sh"
            "cannot:lib/qubes/qfile-unpacker"
          ]
          ++ lib.optional enableNetworking "cannot:${iproute2}/bin/ip";
      };
    };

    pythonPath = with python3Packages; [dbus-python pygobject3 pyxdg];

    dontWrapGApps = true;

    preFixup = ''
      makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
      buildPythonPath "$out $pythonPath"
    '';

    postFixup = ''
      wrapPythonPrograms
    '';

    meta = with lib; {
      description = "The Qubes core files for installation inside a Qubes VM";
      homepage = "https://qubes-os.org";
      license = licenses.gpl2Plus;
      maintainers = [];
      platforms = platforms.linux;
    };
  }
