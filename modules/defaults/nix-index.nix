{ inputs, ... }:
{
  flake-file.inputs.nix-index-database = {
    url = "github:nix-community/nix-index-database";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.default.nixos = {
    imports = [ inputs.nix-index-database.nixosModules.nix-index ];

    # Flake-compatible command-not-found via prebuilt nix-locate DB.
    # (Channel programs.sqlite is unreliable under flakes / DetSys Nix.)
    programs = {
      command-not-found.enable = false;
      nix-index.enable = true;
      nix-index-database.comma.enable = true;
    };
  };
}
