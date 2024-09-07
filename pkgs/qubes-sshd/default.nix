{
  pkgs,
  stdenv,
}:
pkgs.writeTextFile {
  name = "qubes-rpc-sshd";
  text = ''
    #!${stdenv.shell}
    ${pkgs.socat}/bin/socat STDIO TCP:localhost:22
  '';
  executable = true;
  destination = "/etc/qubes-rpc/qubes.Sshd";
}
