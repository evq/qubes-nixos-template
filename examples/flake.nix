{
  description = "example nixos templatevm configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    qubes-nixos-template = {
      url = "github:evq/qubes-nixos-template";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    qubes-nixos-template,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        qubes-nixos-template.overlays.default
      ];
    };
  in {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        inherit pkgs system;
        modules = [
          qubes-nixos-template.nixosModules.default
          qubes-nixos-template.nixosProfiles.default
          ./configuration.nix
        ];
      };
    };
  };
}
