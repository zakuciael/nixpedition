{ inputs, ... }:
{
  flake.terranixModules.secrets =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        mkOption
        types
        mkDefault
        ;
    in
    {
      options.secrets = mkOption {
        default = { };
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              options = {
                secretName = mkOption {
                  type = types.str;
                };
              };

              config = {
                secretName = mkDefault name;
              };
            }
          )
        );
      };

      config = {
        terraform.required_providers.external.source = "hashicorp/external";

        data.external =
          config.secrets
          |> lib.mapAttrs' (
            name: value: {
              inherit name;
              value = {
                program = [
                  (lib.getExe (
                    pkgs.writeShellApplication {
                      name = "get-${name}-secret";
                      text = ''
                        jq -n --arg secret "$(clan secrets get ${value.secretName})" '{"secret":$secret}'
                      '';
                    }
                  ))
                ];
              };
            }
          );
      };
    };

  perSystem =
    { inputs', pkgs, ... }:
    let
      lib' = pkgs.lib.extend (import "${inputs.terranix}/core/helpers.nix" pkgs);
    in
    {
      terranix.terranixConfigurations.nixpedition = {
        workdir = "terraform/nixpedition";
        terraformWrapper.extraRuntimeInputs = [ inputs'.clan-core.packages.default ];
        extraArgs = {
          utils = {
            readSecret = name: "\${data.external.${name}.result.secret}";
            writeSecrets = secrets: {
              provisioner.local-exec =
                secrets
                |> map (
                  {
                    hostName,
                    secret,
                    ref,
                  }:
                  {
                    command = ''
                      echo '${lib'.tf.ref ref}' | clan vars set ${hostName} ${secret}
                    '';
                  }
                );
            };
          };
        };
      };
    };
}
