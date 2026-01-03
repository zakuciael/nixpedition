{
  perSystem =
    { pkgs, ... }:
    {
      devShells = {
        default = pkgs.mkShell {
          name = "nixpedition";
          packages = with pkgs; [
            nixfmt-rfc-style
            nixd
          ];
        };
      };
    };
}
