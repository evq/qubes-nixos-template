{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  bash,
  glibc,
  pkg-config,
  python3,
  python3Packages,
  qubes-core-vchan-xen,
  systemd,
}:
let
  qubesdb-cmds = "qubesdb-read qubesdb-write qubesdb-rm qubesdb-multiread qubesdb-list qubesdb-watch";
in
stdenv.mkDerivation rec {
  pname = "qubes-core-qubesdb";
  version = "4.2.6";

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-vPv74tBD7elYNqpgKLFKAanMH8D18OdDj0xhmw8aWwM=";
  };

  nativeBuildInputs = [
    bash
    makeWrapper
    pkg-config
    python3Packages.setuptools
  ];

  buildInputs = [
    glibc
    qubes-core-vchan-xen
    python3
    systemd
  ];

  buildPhase = ''
    make all PREFIX=/ LIBDIR="$out/lib" INCLUDEDIR="$out/include" BINDIR="$out/bin" SBINDIR="$out/sbin"
  '';

  installPhase = ''
    make install DESTDIR=$out PREFIX=/ PYTHON_PREFIX_ARG="--prefix ." LIBDIR="/lib" INCLUDEDIR="/include" BINDIR="/bin" SBINDIR="/sbin"

    # dashes in the full nix store path conflict with command parsing for the qubesdb-cmd symlinks
    # we will replace them with wrappers that set the argv0 in postFixup
    for cmd in ${qubesdb-cmds}; do
      rm "$out/bin/$cmd";
    done
  '';

  postFixup = ''
    for cmd in ${qubesdb-cmds}; do
      makeWrapper "$out/bin/qubesdb-cmd" "$out/bin/$cmd" \
        --argv0 "$cmd"
    done
  '';

  meta = with lib; {
    description = "QubesDB libs and daemon service";
    homepage = "https://qubes-os.org";
    license = licenses.gpl2Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
