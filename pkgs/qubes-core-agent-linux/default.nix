{
  callPackage,
  enableNetworking ? false,
}:
callPackage ./generic.nix {
  version = "4.2.44";
  hash = "sha256-k3zBx3ND7sXPo/SC2VEicA2RzPom1dWkbOjhKU04DYs=";
  inherit enableNetworking;
}
