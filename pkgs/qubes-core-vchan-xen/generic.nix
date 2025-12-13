{
  lib,
  stdenv,
  fetchFromGitHub,
  xen,
  version,
  hash,
}:
stdenv.mkDerivation rec {
  pname = "qubes-core-vchan-xen";
  inherit version;

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = "v${version}";
    inherit hash;
  };

  buildInputs = [xen];

  buildPhase = ''
    make all PREFIX=/ LIBDIR="$out/lib" INCLUDEDIR="$out/include"
  '';

  installPhase = ''
    make install DESTDIR=$out PREFIX=/
  '';

  env.CFLAGS = "-DHAVE_XC_DOMAIN_GETINFO_SINGLE";

  meta = with lib; {
    description = "Libraries required for the higher-level Qubes daemons and tools";
    homepage = "https://qubes-os.org";
    license = licenses.gpl2Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
