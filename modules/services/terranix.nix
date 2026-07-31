{ inputs, ... }:
{
  flake-file.inputs = {
    terranix = {
      url = "github:terranix/terranix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        systems.follows = "systems";
      };
    };
  };

  services.terranix.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) mkOption mkPackageOption types;
      cfg = config.services.terranix;

      waitTimeout = 300;
      waitInterval = 5;

      waitForEndpointsScript = pkgs.writeShellApplication {
        name = "wait-for-endpoints.sh";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          ENDPOINTS_FILE="/etc/${config.environment.etc."terranix/wait-endpoints.conf".target}"
          TIMEOUT=${toString waitTimeout}
          INTERVAL=${toString waitInterval}
          elapsed=0

          while IFS= read -r url || [[ -n "$url" ]]; do
            # skip empty lines and comments
            [[ -z "$url" || "$url" == \#* ]] && continue

            echo "Waiting for $url..."
            while ! curl -sf --max-time 3 "$url" > /dev/null 2>&1; do
              if [ "$elapsed" -ge "$TIMEOUT" ]; then
                echo "Timeout waiting for $url"
                exit 1
              fi
              sleep "$INTERVAL"
              elapsed=$((elapsed + INTERVAL))
            done
            echo "$url is up."
          done < "$ENDPOINTS_FILE"

          echo "All services are ready."
        '';
      };

      terraformScript =
        let
          terraformPackage = cfg.terraform.package.withPlugins (_: cfg.terraform.plugins);
          binaryName = "${lib.getExe terraformPackage}";
        in
        pkgs.writeShellApplication {
          name = "terraform-apply";
          runtimeInputs = [ terraformPackage ] ++ cfg.terraform.runtimeInputs;
          text = ''
            WORKDIR="/etc/terranix"

            ${binaryName} -chdir="''${WORKDIR}" init
            ${binaryName} -chdir="''${WORKDIR}" apply -auto-approve
          '';
        };
    in
    {
      options.services.terranix = {
        terraform = {
          package = mkPackageOption pkgs "opentofu" {
            example = "pkgs.opentofu";
            extraDescription = ''
              Specifies which Terraform implementation you want to use.
            '';
          };
          plugins = mkOption {
            description = "";
            type = types.listOf types.package;
            default = [ ];
          };
          runtimeInputs = mkOption {
            description = ''
              Extra runtimeInputs for the terraform
              invocations.
            '';
            type = types.listOf types.package;
            default = [ ];
          };
        };

        wait = {
          services = mkOption {
            description = ''
              A list of systemd services that is required to start successfully before running terranix.
            '';
            type = types.listOf types.str;
            example = [ "zitadel.service" ];
            default = [ ];
          };
          endpoints = mkOption {
            description = ''
              A list of HTTP endpoints to check before running terranix.
            '';
            type = types.lines;
            example = ''
              http://zitadel:8080/debug/ready
            '';
            default = "";
          };
        };

        variables = mkOption {
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

        config = mkOption {
          description = ''
            Terranix configuration.
          '';
          type = types.deferredModule;
          default = { };
        };

        extraArgs = mkOption {
          description = ''
            Extra arguments that are accessible from Terranix configuration.
          '';
          type = types.attrsOf types.anything;
          default = { };
        };

        result = {
          terraformScript = mkOption {
            readOnly = true;
            type = types.package;
            default = terraformScript;
          };
          waitScript = mkOption {
            readOnly = true;
            type = types.package;
            default = waitForEndpointsScript;
          };

          terraformConfig = mkOption {
            readOnly = true;
            type = types.package;
            default = config.environment.etc."terranix/config.tf.json".source;
          };
          endpointsFile = mkOption {
            readOnly = true;
            type = types.package;
            default = config.environment.etc."terranix/wait-endpoints.conf".source;
          };
        };
      };

      config = {
        services.terranix.config.variable =
          cfg.variables
          |> lib.mapAttrs (
            name: var: {
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

        environment.etc = {
          "terranix/config.tf.json".source = inputs.terranix.lib.terranixConfiguration {
            inherit pkgs;
            inherit (cfg) extraArgs;
            modules = [ cfg.config ];
          };
          "terranix/wait-endpoints.conf".text = cfg.wait.endpoints;
        };

        systemd.services = {
          "terranix-wait-online" = {
            after = [ "network.target" ];
            before = [ config.systemd.services."terranix".name ];
            bindsTo = [ config.systemd.services."terranix".name ];

            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe waitForEndpointsScript}";
              TimeoutStartSec = (waitTimeout + 20);
            };
          };
          "terranix" = {
            after = [
              "network.target"
              config.systemd.services."terranix-wait-online".name
            ];
            requires = [ config.systemd.services."terranix-wait-online".name ] ++ cfg.wait.services;
            wantedBy = [ "multi-user.target" ];

            environment = {
              TF_LOG = "debug";
              TF_INPUT = "false"; # Disable user input
            };

            restartTriggers = [
              "/etc/${config.environment.etc."terranix/config.tf.json".target}"
              "/etc/${config.environment.etc."terranix/wait-endpoints.conf".target}"
            ];

            serviceConfig = {
              Type = "oneshot";

              ExecStart = "${lib.getExe terraformScript}";
              EnvironmentFile = config.sops.templates."terranix/variables.env".path;
            };
          };
        };
      };
    };
}
