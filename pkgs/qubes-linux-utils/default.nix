{
  lib,
  stdenv,
  fetchFromGitHub,
  resholve,
  coreutils,
  gnugrep,
  icu,
  lsb-release,
  kmod,
  graphicsmagick,
  pkg-config,
  python3Packages,
  qubes-core-vchan-xen,
  qubes-core-qubesdb,
  xen,
}: let
  version = "4.3.3";
  name = "qubes-linux-utils";
  resholved = resholve.mkDerivation rec {
    inherit version;
    pname = "${name}-resholved";

    src = fetchFromGitHub {
      owner = "QubesOS";
      repo = name;
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


      mv "$out/usr/lib/systemd" "$out/lib/systemd"

      rm -rf "$out/usr"
    '';

    solutions = {
      default = {
        scripts = [
          "lib/qubes/udev-usb-add-change"
          "lib/qubes/udev-usb-remove"
        ];
        interpreter = "none";
        fix = {
          "/sbin/modprobe" = true;
        };
        inputs = [
          coreutils
          gnugrep
          kmod
          qubes-core-qubesdb
        ];
        execer = [
          "cannot:${kmod}/bin/modprobe"
        ];
      };
    };

    meta = with lib; {
      description = "Common Linux files for Qubes VM.";
      homepage = "https://qubes-os.org";
      license = licenses.gpl2Plus;
      maintainers = [];
      platforms = platforms.linux;
    };
  };
in
  # FIXME stupid hack, can't figure out how to do these fixups otherwise
  lib.extendDerivation true {} (stdenv.mkDerivation {
    src = resholved;
    inherit version;
    pname = name;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      cp -R $src $out
      substituteInPlace "$out/lib/udev/rules.d/99-qubes-usb.rules" --replace '/usr/lib/qubes/' "${resholved}/lib/qubes/"
      substituteInPlace "$out/lib/udev/rules.d/99-qubes-block.rules" --replace '/usr/lib/qubes/' "${resholved}/lib/qubes/"
    '';
  })
