{
  perSystem =
    {
      config,
      pkgs,
      inputs',
      ...
    }:
    {
      devShells = {
        default = pkgs.mkShell {
          name = "nixpedition";

          inputsFrom = [
            config.pre-commit.devShell
          ];
          packages = with pkgs; [
            inputs'.deploy-rs.packages.default
            nixfmt-rfc-style
            nixd
          ];

          shellHook = ''
            ${config.pre-commit.settings.shellHook}
          '';
        };
      };
    };
}
