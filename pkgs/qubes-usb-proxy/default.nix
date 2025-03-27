{
  lib,
  fetchFromGitHub,
  resholve,
  coreutils,
  gnugrep,
  kmod,
  nettools,
  python3,
  qubes-core-qrexec,
  qubes-core-qubesdb,
  systemd,
  usbutils,
}:
resholve.mkDerivation rec {
  pname = "qubes-usb-proxy";
  version = "1.3.2";

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = "qubes-app-linux-usb-proxy";
    rev = "v${version}";
    hash = "sha256-VyHDFKO0jaCeOkLWubfXOBw+PVHvPwq6iNqSYmFWOR0=";
  };

  buildInputs = [
    qubes-core-qrexec
  ];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/lib

    make install-vm DESTDIR=$out

    mv $out/usr/lib/qubes $out/lib/qubes
    mv "$out/usr/lib/udev" "$out/lib/udev"

    # overwrite the broken symlink created by make install-vm
    ln -sf ../../../lib/qubes/usb-detach-all "$out/etc/qubes/suspend-pre.d/usb-detach-all.sh"

    substituteInPlace "$out/lib/qubes/usb-reset" --replace "#!/usr/bin/python3" "#!${python3}/bin/python3"

    # we have udevadm by way of kmod, skip the check since resholve won't handle it
    substituteInPlace "$out/lib/qubes/usb-import" --replace '[ -f "/usr/bin/udevadm" ] && ' ' '

    # sudo isn't handled by resholve. ideally we'd just do a single substituteInPlace for sudo here
    # but the keep statement would result in usb-export being left unresolved. we can hack around this
    # by turning it into a variable and adding an explicit fix resolution
    substituteInPlace "$out/etc/qubes-rpc/qubes.USB" --replace "sudo" "/run/wrappers/bin/sudo" \
      --replace "/usr/lib/qubes/usb-export" "\$QUBES_USB_EXPORT"

    substituteInPlace "$out/etc/qubes-rpc/qubes.USBAttach" --replace "/usr/lib/qubes/usb-import" "\$QUBES_USB_IMPORT"

    rm -rf $out/usr
  '';

  solutions = {
    default = {
      scripts = [
        "lib/qubes/usb-detach-all"
        "lib/qubes/usb-export"
        "lib/qubes/usb-import"
        "etc/qubes-rpc/qubes.USB"
        "etc/qubes-rpc/qubes.USBAttach"
        "etc/qubes-rpc/qubes.USBDetach"
      ];
      interpreter = "none";
      fix = {
        "/usr/lib/qubes/usb-reset" = true;
        "/usr/lib/qubes/usb-export" = true;
        "$QUBES_USB_EXPORT" = ["${placeholder "out"}/lib/qubes/usb-export"];
        "$QUBES_USB_IMPORT" = ["${placeholder "out"}/lib/qubes/usb-import"];
      };
      fake = {
        external = [
          "usbguard"
        ];
      };
      inputs = [
        "lib/qubes"
        coreutils
        gnugrep
        kmod
        nettools
        qubes-core-qrexec
        qubes-core-qubesdb
        systemd
        usbutils
      ];
      keep = {
        "/run/wrappers/bin/sudo" = true;
        "${placeholder "out"}/lib/qubes/usb-export" = true;
        "${placeholder "out"}/lib/qubes/usb-import" = true;
      };
      execer = [
        "cannot:${kmod}/bin/modprobe"
        "cannot:${qubes-core-qrexec}/bin/qrexec-client-vm"
        "cannot:${systemd}/bin/udevadm"
        "cannot:lib/qubes/usb-reset"
        "cannot:lib/qubes/usb-export"
      ];
    };
  };

  meta = with lib; {
    description = "The Qubes service for proxying USB devices";
    homepage = "https://qubes-os.org";
    license = licenses.gpl2Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
