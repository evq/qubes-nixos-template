{
  lib,
  fetchFromGitHub,
  resholve,
  bash,
  coreutils,
  glibc,
  lsb-release,
  pam,
  pandoc,
  pkg-config,
  python3,
  python3Packages,
  qubes-core-vchan-xen,
  util-linux,
}:
resholve.mkDerivation rec {
  pname = "qubes-core-qrexec";
  version = "4.2.21";

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-an/jvcVJoCjhlcaWvf3pJbEukg9yei8oUoCvDkMiYKk=";
  };

  nativeBuildInputs = [
    bash
    pkg-config
    python3Packages.distutils
    python3Packages.setuptools
    lsb-release
    pandoc
  ];

  buildInputs = [
    glibc
    qubes-core-vchan-xen
    python3
    pam
  ];

  buildPhase = ''
    make all-base
    make all-vm
  '';

  # FIXME
  # - need to rewrite lib/qubes-qrexec-policy-agent autostart ( `exec qrexec-policy-agent "$@"` )
  # - need to add qubes-qrexec-agent.service service
  # - need to rewrite /etc/qubes-rpc in a few places
  # - subs in qubes-rpc-multiplexer

  installPhase = ''
    make install-base DESTDIR=$out PREFIX=/ PYTHON_PREFIX_ARG="--prefix ." LIBDIR="/lib" SYSLIBDIR="/lib"
    make install-vm DESTDIR=$out PREFIX=/ PYTHON_PREFIX_ARG="--prefix ." LIBDIR="/lib" SYSLIBDIR="/lib"

    mv $out/usr/bin $out/bin
    mv $out/usr/include $out/include
    mv $out/usr/lib/qubes $out/lib/qubes
    mv $out/usr/share $out/share

    substituteInPlace "$out/etc/xdg/autostart/qrexec-policy-agent.desktop" --replace '/usr/lib/qubes/qrexec-policy-agent-autostart' "$out/lib/qubes/qrexec-policy-agent-autostart"

    rm -rf $out/usr
  '';

  solutions = {
    default = {
      scripts = ["lib/qubes/qubes-rpc-multiplexer"];
      interpreter = "none";
      inputs = [coreutils util-linux];
    };
  };

  meta = with lib; {
    description = "The Qubes qrexec files (qube side)";
    homepage = "https://qubes-os.org";
    license = licenses.gpl2Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
