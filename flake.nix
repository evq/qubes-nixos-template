{
  description = "nixos templatevm configurations";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    qubesPackages = final: prev: {
      qubes-core-qubesdb = prev.callPackage ./pkgs/qubes-core-qubesdb {};
      qubes-core-vchan-xen = prev.callPackage ./pkgs/qubes-core-vchan-xen {};
      qubes-core-qrexec = prev.callPackage ./pkgs/qubes-core-qrexec {};
      qubes-core-agent-linux = prev.callPackage ./pkgs/qubes-core-agent-linux {};
      qubes-linux-utils = prev.callPackage ./pkgs/qubes-linux-utils {};
      qubes-gui-common = prev.callPackage ./pkgs/qubes-gui-common {};
      qubes-gui-agent-linux = prev.callPackage ./pkgs/qubes-gui-agent-linux {};
      qubes-sshd = prev.callPackage ./pkgs/qubes-sshd {};
      qubes-usb-proxy = prev.callPackage ./pkgs/qubes-usb-proxy {};
    };

    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        qubesPackages
      ];
    };
  in {
    overlays.default = qubesPackages;
    nixosModules.default = {
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = [
        ./modules/qubes/core.nix
        ./modules/qubes/db.nix
        ./modules/qubes/gui.nix
        ./modules/qubes/networking.nix
        ./modules/qubes/qrexec.nix
        ./modules/qubes/sshd.nix
        ./modules/qubes/updates.nix
        ./modules/qubes/usb.nix
      ];
    };
    nixosProfiles.default = {
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = [
        ./profiles/qubes.nix
      ];
    };
    rpm = pkgs.callPackage ./tools/rpm.nix {
      inherit nixpkgs;
      nixosConfig =
        lib.nixosSystem
        {
          inherit pkgs system;
          modules = [
            self.nixosModules.default
            self.nixosProfiles.default
            ./examples/configuration.nix
          ];
        };
    };
  };
}
