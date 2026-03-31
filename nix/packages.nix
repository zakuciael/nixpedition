{
  inputs,
  withSystem,
  ...
}:
{
  flake-file = {
    inputs = {
      pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";
    };
  };

  imports = [
    inputs.pkgs-by-name-for-flake-parts.flakeModule
  ];

  perSystem = {
    pkgsDirectory = ../packages;
    pkgsNameSeparator = "/";
  };

  den.default.nixos = {
    nixpkgs.overlays = [ inputs.self.overlays.default ];
  };

  flake.overlays.default =
    _: prev: withSystem prev.stdenv.hostPlatform.system ({ config, ... }: config.packages);
}
