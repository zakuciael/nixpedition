{ lib, ... }: {
  services.terranix = {
    terranix.local =
      { osConfig, ... }:
      let
        inherit (lib) optionalAttrs optionalString mapAttrs';
        cfg = osConfig.services.terranix;
      in
      {
        terraformWrapper.prefixText = optionalString (cfg.variables != { }) ''
          ln -sf ${
            osConfig.sops.templates."terranix/terraform.tfvars.json".path
          } ${cfg.workdir}/terraform.tfvars.json
        '';

        configuration.variable = optionalAttrs (cfg.variables != { }) (
          cfg.variables
          |> mapAttrs' (
            _: var: {
              inherit (var) name;
              value = {
                inherit (var) type;
                sensitive = var.secret;
              };
            }
          )
        );
      };

    nixos =
      { config, lib, ... }:
      let
        inherit (lib) mkIf mapAttrs';
        cfg = config.services.terranix;
      in
      {
        sops.templates = {
          "terranix/terraform.tfvars.json" = mkIf (cfg.variables != { }) {
            content =
              cfg.variables
              |> mapAttrs' (
                _: var: {
                  inherit (var) name value;
                }
              )
              |> builtins.toJSON;
          };
        };
      };
  };
}
