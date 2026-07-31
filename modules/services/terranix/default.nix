{
  inputs,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
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

      terraformScript =
        let
          terraformPackage = cfg.terraform.package.withPlugins (_: cfg.terraform.providers);
          binaryName = "${lib.getExe terraformPackage}";
        in
        pkgs.writeShellApplication {
          name = "terraform-apply";
          runtimeInputs = [ terraformPackage ] ++ cfg.terraform.runtimeInputs;
          text = ''
            mkdir -p ${cfg.terraform.workdir}
            ln -sf ${cfg.result.terraformConfig} ${cfg.terraform.workdir}/config.tf.json
            cd ${cfg.terraform.workdir}

            ${binaryName} init
            ${binaryName} apply -auto-approve
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
          providers = mkOption {
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
          workdir = mkOption {
            description = "Working directory of the terranix configuration.";
            type = types.str;
            default = "/etc/terranix";
          };
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
          terraformConfig = mkOption {
            readOnly = true;
            type = types.package;
            default = inputs.terranix.lib.terranixConfiguration {
              inherit pkgs;
              inherit (cfg) extraArgs;
              modules = [ cfg.config ];
            };
          };
        };
      };

      config = {
        systemd.services = {
          "terranix" = {
            after = [ "network.target" ];
            requires = cfg.wait.services;
            wantedBy = [ "multi-user.target" ];

            environment = {
              TF_LOG = "debug";
              TF_INPUT = "false"; # Disable user input
            };

            restartTriggers = [ "${cfg.terraform.workdir}/config.tf.json" ];

            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe terraformScript}";
            };
          };
        };

        virtualisation.vmVariant = {
          services.terranix.terraform.workdir = "/vmstate/terranix";
        };
      };
    };
}
