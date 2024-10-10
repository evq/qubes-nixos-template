{
  lib,
  stdenv,
  fetchFromGitHub,
  icu,
  lsb-release,
  graphicsmagick,
  pkg-config,
  python3Packages,
  qubes-core-vchan-xen,
  xen,
}:
stdenv.mkDerivation rec {
  version = "4.3.3";
  pname = "qubes-linux-utils";

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-XHx1wt2whMQC+TUc2U97KCOJ8memT6cH0BAp2zxYQyQ=";
  };

  nativeBuildInputs =
    [
      icu
      pkg-config
      qubes-core-vchan-xen
      xen
    ]
    ++ (with python3Packages; [
      distutils
      setuptools
    ]);

  buildInputs =
    [
      graphicsmagick
      icu
    ]
    ++ (with python3Packages; [
      pycairo
      pillow
      numpy
    ]);

  postPatch = ''
    substituteInPlace qmemman/Makefile --replace '_XENSTORE_H=$(shell ls /usr/include/xenstore.h)' '_XENSTORE_H=1'
  '';

  buildPhase = ''
    make all
  '';

  # FIXME need to sub and move qubes-meminfo-writer
  installPhase = ''
    make install \
        PYTHON_PREFIX_ARG="--prefix ." \
        DESTDIR="$out" \
        LIBDIR=/lib \
        SYSLIBDIR=/lib \
        SBINDIR=/bin \
        SCRIPTSDIR=/lib/qubes \
        INCLUDEDIR=/include

    substituteInPlace "$out/lib/udev/rules.d/99-qubes-usb.rules" --replace '/usr/lib/qubes/' "$out/lib/qubes/"
    substituteInPlace "$out/lib/udev/rules.d/99-qubes-block.rules" --replace '/usr/lib/qubes/' "$out/lib/qubes/"

    mv "$out/usr/lib/systemd" "$out/lib/systemd"

    rm -rf "$out/usr"
  '';

  meta = with lib; {
    description = "Common Linux files for Qubes VM.";
    homepage = "https://qubes-os.org";
    license = licenses.gpl2Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
