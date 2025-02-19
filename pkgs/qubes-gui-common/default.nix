{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "qubes-gui-common";
  version = "4.2.5";

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-rv80X/wecXRtJ3HhHgksJd43AKvLQTHyX8e1EJPwEO0=";
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
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
