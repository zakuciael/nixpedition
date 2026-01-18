# DO-NOT-EDIT. This file was auto-generated using github:mightyiam/files.
# Use `nix run .#write-compat-files` to regenerate it.

(import (
  let
    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    nodeName = lock.nodes.root.inputs.flake-compat;
  in
  fetchTarball {
    url =
      lock.nodes.${nodeName}.locked.url
        or "https://github.com/NixOS/flake-compat/archive/${lock.nodes.${nodeName}.locked.rev}.tar.gz";
    sha256 = lock.nodes.${nodeName}.locked.narHash;
  }
) { src = ./.; }).shellNix
