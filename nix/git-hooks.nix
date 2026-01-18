{ inputs, ... }:
{
  imports = [
    inputs.git-hooks-nix.flakeModule
  ];

  flake-file.inputs = {
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.flake-compat.follows = "flake-compat";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  perSystem =
    { config, ... }:
    {
      pre-commit = {
        check.enable = true;
        settings = {
          enable = true;
          hooks = {
            write-flake = {
              enable = true;
              name = "write-flake";
              description = "Generate flake.nix file using flake-file";
              entry = "${config.packages.write-flake}/bin/write-flake";
              always_run = true;
              pass_filenames = false;
            };
            write-compat-files = {
              enable = true;
              name = "write-compat-files";
              description = "Generate files using mightyiam/files";
              entry = "${config.packages.write-compat-files}/bin/write-files";
              always_run = true;
              pass_filenames = false;
            };
          };
        };
      };
    };
}
