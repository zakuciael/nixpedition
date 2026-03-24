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
    clan-core = {
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:zakuciael/clan-core";
    };
    den.url = "github:vic/den?rev=ece9f9ec1647e82c96e4c21bb9c7060678e21d43";
    files.url = "github:mightyiam/files";
    flake-aspects.url = "github:vic/flake-aspects/v0.7.0";
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
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "https://channels.nixos.org/nixos-25.11/nixexprs.tar.xz";
    nixpkgs-lib.follows = "nixpkgs";
  };

}
