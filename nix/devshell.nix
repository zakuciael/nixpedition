{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells = {
        default = pkgs.mkShell {
          name = "nixpedition";

          inputsFrom = [
            config.pre-commit.devShell
          ];
          packages = with pkgs; [
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
