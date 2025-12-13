#!/usr/bin/env nix
#!nix shell ``#.packages.x86_64-linux.nix-update`` nixpkgs#curl nixpkgs#jq --command bash
set -ex
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" &>/dev/null && pwd)"

update_packages() {
  local version_regex="$1"
  local src_suffix="$2"
  shift 2
  local dirs=("$@")
  
  for dir in "${dirs[@]}"; do
    local pkg_name=$(basename "$dir")
    nix-update \
      --version-regex $version_regex \
      --system x86_64-linux \
      --override-filename "$dir/default.nix" \
      --use-github-releases \
      --flake "$pkg_name$src_suffix"
  done
}

update_packages "v(4\.2\.[0-9.]+)" "" \
  "pkgs/qubes-core-qubesdb" \
  "pkgs/qubes-core-vchan-xen" \
  "pkgs/qubes-gui-common"

# whenever we use resholve, we need to look at the original derivation to find the updatable url
update_packages "v(4\.2\.[0-9.]+)" ".src" \
  "pkgs/qubes-core-agent-linux" \
  "pkgs/qubes-core-qrexec" \
  "pkgs/qubes-gui-agent-linux"

# in one case we wrap the resholved package
update_packages "v(4\.2\.[0-9.]+)" ".src.src" \
  "pkgs/qubes-linux-utils"

# this is an odd case as 1.3 is the release line for 4.2
update_packages "v(1\.3\.[0-9.]+)" ".src" \
  "pkgs/qubes-usb-proxy"

# these packages should work for both 4.2 and 4.3
update_packages "v([0-9.]+)" ".src" \
  "pkgs/qubes-gpg-split" \
