{ inputs, ... }: {
  flake-file = {
    inputs = {
      # Determinate Nix (lazy trees, parallel eval, determinate-nixd).
      determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

      # Source-only: built below against the host Determinate Nix.
      # Community nix-eval-jobs is incompatible with Determinate-specific settings.
      determinate-nix-eval-jobs = {
        url = "github:DeterminateSystems/nix-eval-jobs/detsys";
        flake = false;
      };
    };
    nixConfig = {
      extra-substituters = [
        "https://install.determinate.systems"
      ];
      extra-trusted-public-keys = [
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      ];
    };
  };

  perSystem =
    { pkgs, system, ... }:
    let
      # Build DetSys nej against the same Determinate Nix the host runs.
      # Upstream detsys still targets 3.15 APIs; patch for 3.23.
      detNixPkgs = inputs.determinate.inputs.nix.packages.${system};
    in
    {
      packages.determinate-nix-eval-jobs =
        (pkgs.callPackage "${inputs.determinate-nix-eval-jobs}/default.nix" {
          nixComponents = {
            inherit (detNixPkgs)
              nix-cli
              nix-cmd
              nix-store
              nix-fetchers
              nix-expr
              nix-flake
              nix-main
              ;
          };
        }).overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [
              ./patches/nix-eval-jobs-determinate-3.23.patch
            ];
          });
    };

  den.default.nixos =
    { lib, ... }:
    {
      imports = [ inputs.determinate.nixosModules.default ];

      nix.settings = {
        # Parallel eval across all cores for interactive / rebuild workloads
        eval-cores = lib.mkDefault 0;

        # Prefer DetSys binary caches so rebuilds do not compile Determinate Nix from source.
        extra-substituters = [ "https://install.determinate.systems" ];
        extra-trusted-public-keys = [
          "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
        ];
      };
    };
}
