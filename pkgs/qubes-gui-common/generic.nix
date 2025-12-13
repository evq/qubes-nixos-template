{
  lib,
  stdenv,
  fetchFromGitHub,
  version,
  hash,
}:
stdenv.mkDerivation rec {
  pname = "qubes-gui-common";
  inherit version;

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = "v${version}";
    inherit hash;
  };

  buildPhase = ''
    true
  '';

  installPhase = ''
    mkdir -p $out/include
    cp include/*.h $out/include/
  '';

  meta = with lib; {
    description = "Common files for Qubes GUI - protocol headers";
    homepage = "https://qubes-os.org";
    license = licenses.gpl2Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
