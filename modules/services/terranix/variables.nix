{
  services.terranix.nixos =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      cfg = config.services.terranix;
    in
    {
      options.services.terranix.variables = mkOption {
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              options = {
                name = mkOption {
                  type = types.str;
                };
                type = mkOption {
                  type = types.enum [
                    "string"
                    "number"
                    "bool"
                    "list"
                    "set"
                    "map"
                  ];
                };
                text = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                placeholder = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                secret = mkOption {
                  type = types.bool;
                  default = false;
                };
              };

              config = { inherit name; };
            }
          )
        );
        default = { };
      };

      config = {
        services.terranix.config.variable =
          cfg.variables
          |> lib.mapAttrs (
            _: var: {
              inherit (var) type;
              sensitive = var.secret;
            }
          );

        sops.templates = {
          "terranix/variables.env" = {
            content =
              cfg.variables
              |> lib.attrsToList
              |> map (
                { name, value }:
                let
                  env_name = "TF_VAR_${name}";
                  env_value =
                    if value.secret then
                      assert lib.assertMsg (
                        value.placeholder != null
                      ) "services.terranix.variables.\"${name}\".placeholder is not set.";
                      value.placeholder
                    else
                      assert lib.assertMsg (
                        value.text != null
                      ) "services.terranix.variables.\"${name}\".text is not set.";
                      value.text;
                in
                "${env_name}='${env_value}'"
              )
              |> lib.concatStringsSep "\n";
          };
        };

        systemd.services."terranix".serviceConfig.EnvironmentFile =
          config.sops.templates."terranix/variables.env".path;
      };
    };
}
