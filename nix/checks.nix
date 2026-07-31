{ self, den, ... }:
{
  perSystem =
    {
      self',
      lib,
      system,
      ...
    }:
    let
      nixosMachines =
        (den.hosts.${system} or { })
        |> lib.mapAttrs' (
          name: _: {
            name = "nixos-${name}";
            value = self.nixosConfigurations.${name}.config.system.build.toplevel;
          }
        );

      blacklistPackages = [ ];
      packages =
        self'.packages
        |> lib.filterAttrs (name: _: !(builtins.elem name blacklistPackages))
        |> lib.mapAttrs' (name: lib.nameValuePair "package-${name}");

      packageTests =
        self'.packages
        |> lib.concatMapAttrs (
          pkg-name: pkg:
          lib.mapAttrs' (test-name: lib.nameValuePair "package-${pkg-name}-test-${test-name}") (
            pkg.tests or { }
          )
        );

      devShells = self'.devShells |> lib.mapAttrs' (name: lib.nameValuePair "devShell-${name}");
    in
    {
      checks = nixosMachines // packages // devShells // packageTests;
    };
}
