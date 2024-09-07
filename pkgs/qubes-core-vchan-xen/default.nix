{
  lib,
  stdenv,
  fetchFromGitHub,
  xenPackages,
}:
stdenv.mkDerivation rec {
  pname = "qubes-core-vchan-xen";
  version = "4.2.4";

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-O7i5zK7S+d/O8oPMvm6szNR1Xq6qSBNE2+uFI/1mDEg=";
  };

  buildInputs = [xenPackages.xen_4_17-slim];

  buildPhase = ''
    make all PREFIX=/ LIBDIR="$out/lib" INCLUDEDIR="$out/include"
  '';

  installPhase = ''
    make install DESTDIR=$out PREFIX=/
  '';

  meta = with lib; {
    description = "Libraries required for the higher-level Qubes daemons and tools";
    homepage = "https://qubes-os.org";
    license = licenses.gpl2Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
