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

  inputs = {
    dedupe-flake-utils.url = "github:numtide/flake-utils";
    den.url = "github:vic/den";
    deploy-rs = {
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
        utils.follows = "dedupe-flake-utils";
      };
      url = "github:serokell/deploy-rs?rev=7edf1f4fd866fc5718aa5358dc720f4ee90909e3";
    };
    disko.url = "github:nix-community/disko";
    files.url = "github:mightyiam/files";
    flake-aspects.url = "github:vic/flake-aspects";
    flake-compat = {
      flake = false;
      url = "github:NixOS/flake-compat";
    };
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
      url = "github:hercules-ci/flake-parts";
    };
    git-hooks-nix = {
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:cachix/git-hooks.nix";
    };
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager/release-25.11";
    };
    import-tree.url = "github:vic/import-tree";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-lib.follows = "nixpkgs";
    systems.url = "github:nix-systems/default";
  };

}
