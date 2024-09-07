{
  description = "nixos templatevm configurations";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    localPackages = final: prev: {
      qubes-core-qubesdb = prev.callPackage ./pkgs/qubes-core-qubesdb {};
      qubes-core-vchan-xen = prev.callPackage ./pkgs/qubes-core-vchan-xen {};
      qubes-core-qrexec = prev.callPackage ./pkgs/qubes-core-qrexec {};
      qubes-core-agent-linux = prev.callPackage ./pkgs/qubes-core-agent-linux {};
      qubes-linux-utils = prev.callPackage ./pkgs/qubes-linux-utils {};
      qubes-gui-common = prev.callPackage ./pkgs/qubes-gui-common {};
      qubes-gui-agent-linux = prev.callPackage ./pkgs/qubes-gui-agent-linux {};
      qubes-sshd = prev.callPackage ./pkgs/qubes-sshd {};
    };

    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        localPackages
      ];
    };
    nixos = lib.nixosSystem {
      inherit pkgs system;
      modules = [
        ./configuration.nix
      ];
    };
  in {
    inherit pkgs;
    nixosConfigurations = {
      nixos = nixos;
    };
    rpm = pkgs.callPackage ./tools/rpm.nix {
      inherit nixpkgs;
      nixosConfig = nixos.config;
    };
  };
}
