{
  lib,
  pkgs,
  fetchFromGitHub,
  makeWrapper,
  resholve,
  autoPatchelfHook,
  autoconf,
  automake,
  bash,
  gnugrep,
  coreutils,
  libtool,
  libXt,
  lsb-release,
  git,
  gnused,
  pam,
  patch,
  pipewire,
  pixman,
  pkg-config,
  python3Packages,
  pulseaudio,
  qubes-core-qrexec,
  qubes-core-agent-linux,
  qubes-core-vchan-xen,
  qubes-core-qubesdb,
  qubes-gui-common,
  systemd,
  util-linux,
  which,
  xen,
  xfce,
  xorg,
  zenity,
}:
resholve.mkDerivation rec {
  version = "4.2.17";
  pname = "qubes-gui-agent-linux";

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-dELBBU0sRtp62QwrZKvV9SJQysMG5Eo1oQMaQy3lXUg=";
  };

  nativeBuildInputs =
    [
      autoPatchelfHook
      pkgs.mesa
      makeWrapper
      pkg-config
      patch
      git
      automake
      autoconf
      libtool
      pam
      pulseaudio
      pipewire
      libXt
      pixman
      lsb-release
      qubes-gui-common
      qubes-core-vchan-xen
      qubes-core-qubesdb
      xen
    ]
    ++ (with xorg; [
      libXdamage
      libXcomposite
      utilmacros
      xorgserver
    ]);

  buildInputs =
    [
      coreutils
      pkgs.mesa
      qubes-core-vchan-xen
      qubes-core-qubesdb
      pam
      zenity
      python3Packages.xcffib
      systemd
      xfce.xfconf
      # xdg-user-dirs-update
    ]
    ++ (with xorg; [
      libXcomposite
      libXdamage
      xinit
      xrandr
      xprop
      xsetroot
    ]);

  postPatch = ''
    rm -f pulse/pulsecore
    ln -s "pulsecore-17.0" pulse/pulsecore

    # since we don't know the final resholved package
    # path, it's easiest if we instead configure PATH later
    sed -i -e 's#execl("/usr/bin/qubes-run-xorg",#execlp("qubes-run-xorg",#' gui-agent/vmside.c
  '';

  buildPhase = ''
    make appvm
  '';

  # FIXME sub xdg autostart paths
  # FIXME nixgl
  installPhase = ''
    make install-rh-agent \
        DESTDIR="$out" \
        LIBDIR=/lib \
        USRLIBDIR=/lib \
        SYSLIBDIR=/lib

    # overwrite the broken symlink created by make install-rh-agent
    ln -sf ../../bin/qubes-set-monitor-layout $out/etc/qubes-rpc/qubes.SetMonitorLayout
    ln -sf ../../bin/qubes-start-xephyr $out/etc/qubes-rpc/qubes.GuiVMSession

    # this will point to the unresholved package but it is not an
    # issue since our wrapper only refers to external resources
    substituteInPlace "$out/etc/xdg/autostart/qubes-qrexec-fork-server.desktop" --replace '/usr/bin/qrexec-fork-server' "$out/bin/qrexec-fork-server"

    # these are nested within runuser calls, easier to just substituteInPlace
    # and pretend to resholve that runuser is not executing it's args
    substituteInPlace "$out/usr/bin/qubes-run-xorg" --replace ' /bin/sh' ' ${bash}/bin/sh'
    substituteInPlace "$out/usr/bin/qubes-run-xorg" --replace '/usr/bin/xinit' '${xorg.xinit}/bin/xinit'
    # skip the wrapper since it's just to determine which binary to call
    substituteInPlace "$out/usr/bin/qubes-run-xorg" --replace '/usr/lib/qubes/qubes-xorg-wrapper' "${xorg.xorgserver}/bin/Xorg"

    # config file template and rendered config relocation
    substituteInPlace "$out/usr/bin/qubes-run-xorg" --replace '/etc/X11/xorg-qubes.conf.template' "$out/etc/X11/xorg-qubes.conf.template"
    substituteInPlace "$out/usr/bin/qubes-run-xorg" --replace ' /etc/X11/xorg-qubes.conf' ' /var/run/xorg-qubes.conf'
    substituteInPlace "$out/usr/bin/qubes-run-xorg" --replace '-config xorg-qubes.conf' '-config /var/run/xorg-qubes.conf'

    # resholve won't replace the absolute path reference in this conditional,
    # we can just substitute with true
    # FIXME this wasn't actually replaced properly before...
    # substituteInPlace "$out/usr/bin/qubes-run-xorg" --replace 'if [ -x /bin/loginctl ]; then' 'if [ true ]; then'

    # replace xdg autostart since we generate systemd units instead
    # FIXME probably needs to be moved earlier in process
    substituteInPlace "$out/usr/bin/qubes-session" --replace '/usr/bin/qubes-session-autostart QUBES X-QUBES "X-$VMTYPE" "X-$UPDTYPE"' 'systemctl --user set-environment XDG_CURRENT_DESKTOP="QUBES:X-QUBES:X-$VMTYPE:X-$UPDTYPE"'

    cat >> $out/etc/X11/xorg-qubes.conf.template <<EOF
    Section "Files"
      ModulePath "${xorg.xorgserver}/lib/xorg/modules"
      ModulePath "${xorg.xorgserver}/lib/xorg/modules/extensions"
      ModulePath "${xorg.xorgserver}/lib/xorg/modules/drivers"
      ModulePath "$out/lib/xorg/modules/drivers"
    EndSection
    EOF

    mv "$out/usr/bin" "$out/bin"
    mv "$out/usr/share" "$out/share"
    mv "$out/usr/lib/qubes" "$out/lib/qubes"
    mv "$out/usr/lib/sysctl.d" "$out/lib/sysctl.d"

    rm -rf "$out/usr"
  '';

  solutions = {
    default = {
      scripts = [
        "lib/qubes/qubes-gui-agent-pre.sh"
        "bin/qubes-run-xorg"
        "bin/qubes-session"
        "etc/X11/xinit/xinitrc.d/50guivm-windows-prefix.sh"
        "etc/X11/xinit/xinitrc.d/60xfce-desktop.sh"
      ];
      interpreter = "none";
      fake = {
        # ignore for now, these paths are present in file check so the paths won't be reached
        source = [
          "/etc/X11/xinit/xinitrc.d/qubes-keymap.sh"
          "/etc/X11/Xsession.d/90qubes-keymap"
        ];
        # just ignore this, currently guarded by an unreplaced conditional
        # using which which is always false
        external = [
          "xdg-user-dirs-update"
        ];
      };
      fix = {
        source = ["/usr/lib/qubes/init/functions"];
        "/usr/bin/qubes-gui-runuser" = true;
        "/usr/bin/qubesdb-read" = true;
      };
      inputs = [
        "bin"
        "${qubes-core-agent-linux}/lib/qubes"
        "${qubes-core-agent-linux}/lib/qubes/init/functions"
        bash
        pkgs.mesa
        coreutils
        gnused
        qubes-core-qubesdb
        systemd
        util-linux
        which
        xfce.xfce4-settings
        xfce.xfconf
        xorg.xprop
        xorg.xinit
        xorg.xsetroot
      ];
      keep = {
        source = [
          "$HOME"
          "/etc/X11/xinit/xinitrc.d/qubes-keymap.sh"
          "/etc/X11/Xsession.d/90qubes-keymap"
        ];
        "$XSESSION" = true;
      };
      execer = [
        "cannot:${systemd}/bin/systemctl"
        "cannot:${xfce.xfce4-settings}/bin/xfsettingsd"
        "cannot:${xfce.xfconf}/bin/xfconf-query"
        # lies
        "cannot:bin/qubes-gui-runuser"
        "cannot:${util-linux}/bin/runuser"
      ];
    };
  };

  postFixup = ''
    # set the qrexec paths and override PATH so that we can
    # launch programs similar to the user from a login shell
    makeWrapper "${qubes-core-qrexec}/bin/qrexec-fork-server" "$out/bin/qrexec-fork-server" \
      --run "export QREXEC_SERVICE_PATH=\$(${systemd}/bin/systemctl cat qubes-qrexec-agent.service | ${gnugrep}/bin/grep -Po '(?<=QREXEC_SERVICE_PATH=)[^\"\n]*')" \
      --set QREXEC_MULTIPLEXER_PATH "${qubes-core-qrexec}/lib/qubes/qubes-rpc-multiplexer" \
      --set PATH "/run/wrappers/bin:/home/user/.nix-profile/bin:/nix/profile/bin:/home/user/.local/state/nix/profile/bin:/etc/profiles/per-user/user/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"

  '';

  meta = with lib; {
    description = "The Qubes GUI Agent for AppVMs";
    homepage = "https://qubes-os.org";
    license = licenses.gpl2Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
