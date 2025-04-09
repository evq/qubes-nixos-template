{
  fetchFromGitHub,
  resholve,
  coreutils,
  qubes-core-qrexec,
  gnupg,
  pandoc,
}:
resholve.mkDerivation rec {
  pname = "qubes-gpg-split";
  version = "2.0.77";

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = "qubes-app-linux-split-gpg";
    rev = "v${version}";
    hash = "sha256-AGYJV+moLh58dbKi9K2aguPNHYE4ntQ8OmZvADAec0s=";
  };

  postPatch = ''
    substituteInPlace src/gpg-client.c --replace \
      '#define QREXEC_CLIENT_PATH "/usr/lib/qubes/qrexec-client-vm"' \
      '#define QREXEC_CLIENT_PATH "${qubes-core-qrexec}/bin/qrexec-client-vm"'
  '';

  buildInputs = [
    qubes-core-qrexec
    gnupg
  ];

  nativeBuildInputs = [
    pandoc
  ];

  buildPhase = ''
    make
  '';

  installPhase = ''
    make install-vm \
        DESTDIR="$out" \
        LIBDIR=/lib \
        USRLIBDIR=/lib \
        SYSLIBDIR=/lib

    mv $out/usr/bin $out/bin
    mv $out/usr/share $out/share
    # FIXME usr/lib/tmpfiles.d is probably needed in order to allow a nixos qube to be used as the gpg domain
    rm -rf $out/usr
  '';

  solutions = {
    default = {
      scripts = [
        "bin/qubes-gpg-client-wrapper"
        "bin/qubes-gpg-import-key"
        "etc/profile.d/qubes-gpg.sh"
      ];
      interpreter = "none";
      fix = {
        source = ["/etc/profile.d/qubes-gpg.sh"];
        "/usr/bin/gpg" = true;
        "/usr/lib/qubes/qrexec-client-vm" = true;
      };
      inputs = [
        "bin"
        "etc/profile.d"
        coreutils
        gnupg
        qubes-core-qrexec
      ];
      execer = [
        "cannot:bin/qubes-gpg-client"
        "cannot:bin/qubes-gpg-import-key"
        "cannot:${gnupg}/bin/gpg"
        # FIXME this is a lie
        # NOTE the invocation in qubes-gpg-import-key passes absolute paths
        # but for now we won't support nixos as the gpg domain
        # and instead only as the client
        "cannot:${qubes-core-qrexec}/bin/qrexec-client-vm"
      ];
    };
  };
}
