{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
    };
  };

  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [
    xterm
  ];
}
