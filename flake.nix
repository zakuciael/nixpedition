# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      imports = [
        (inputs.import-tree [
          ./nix
          ./modules
        ])
      ];
    };

  nixConfig = {
    extra-substituters = [ "https://cache.zakku.eu" ];
    extra-trusted-public-keys = [ "cache.zakku.eu-1:X219JrBeYMjhvMb0BXYci2gyAAiOQj4dGizzf+yCVcI=" ];
  };

  inputs = {
    clan-core = {
      url = "github:zakuciael/clan-core";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    den.url = "github:vic/den/v0.17.0";
    files.url = "github:mightyiam/files";
    flake-aspects.url = "github:vic/flake-aspects/v0.7.0";
    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
      };
    };
    hercules-ci-effects = {
      url = "github:hercules-ci/hercules-ci-effects";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    niks3 = {
      url = "github:Mic92/niks3";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    nixbot = {
      url = "github:Mic92/nixbot";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "https://channels.nixos.org/nixos-25.11/nixexprs.tar.xz";
    pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";
    systems.url = "github:nix-systems/default";
    terranix = {
      url = "github:terranix/terranix";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix/db94781";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
