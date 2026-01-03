{ inputs, ... }:
{
  imports = [
    inputs.files.flakeModules.default
  ];

  flake-file.inputs = {
    files.url = "github:mightyiam/files";
    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };
  };

  perSystem =
    { config, pkgs, ... }:
    let
      compatBase = ''
        (import (
          let
            lock = builtins.fromJSON (builtins.readFile ./flake.lock);
            nodeName = lock.nodes.root.inputs.flake-compat;
          in
          fetchTarball {
            url =
              lock.nodes.''${nodeName}.locked.url
                or "https://github.com/NixOS/flake-compat/archive/''${lock.nodes.''${nodeName}.locked.rev}.tar.gz";
            sha256 = lock.nodes.''${nodeName}.locked.narHash;
          }
        ) { src = ./.; })'';
    in
    {
      packages = {
        write-files = config.files.writer.drv;
      };

      files.files = [
        {
          path_ = "shell.nix";
          drv = pkgs.writeText "shell.nix" ''
            ${compatBase}.shellNix
          '';
        }
        {
          path_ = "nixd.nix";
          drv = pkgs.writeText "nixd.nix" ''
            let
              outputs =
                ${compatBase}.outputs;
            in
            {
              inherit (outputs) debug currentSystem;
              inherit (outputs.inputs) nixpkgs;
            }
          '';
        }
      ];
    };
}
