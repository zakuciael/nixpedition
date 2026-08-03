{ inputs, lib, ... }:
let
  inherit (lib) mkOption mkPackageOption types;

  configurationType = mkOption {
    default = { };
    type = types.deferredModule;
    description = "Terranix configuration.";
  };
in
{
  globalModule = configurationType;

  localModule =
    pkgs:
    mkOption {
      default = {
        configuration = { };
      };
      type = types.submodule (submod: {
        options = {
          terraformWrapper = {
            package = mkPackageOption pkgs "opentofu" {
              example = "pkgs.terraform";
              extraDescription = ''
                Specifies which Terraform implementation you want to use.

                You may also specify which plugins you want to use with your Terraform implementation:

                    pkgs.terraform.withPlugins (p: [ p.external p.local p.null ])

                or for OpenTofu:

                    pkgs.opentofu.withPlugins (p: [ p.external p.local p.null ])
              '';
            };
            extraRuntimeInputs = mkOption {
              description = ''
                Extra runtimeInputs for the terraform
                invocations.
              '';
              type = types.listOf types.package;
              default = [ ];
            };
            prefixText = mkOption {
              description = ''
                Extra commands to run in the wrapper before invoking Terraform
              '';
              type = types.lines;
              default = "";
            };
            suffixText = mkOption {
              description = ''
                Extra commands to run in the wrapper after invoking Terraform
              '';
              type = types.lines;
              default = "";
            };
          };

          result = mkOption {
            description = ''
              A collection of useful read-only outputs by this configuration.
              For debugging or otherwise.
            '';
            default = { };
            internal = true;
            type = types.submodule {
              options = {
                terraformConfiguration = mkOption {
                  description = ''
                    The exposed Terranix configuration as created by lib.terranixConfiguration.
                  '';
                  default = inputs.terranix.lib.terranixConfiguration {
                    inherit pkgs;
                    modules = [ submod.config.configuration ];
                  };
                  defaultText = "The final Terraform configuration JSON.";
                };
                terraformWrapper = mkOption {
                  description = ''
                    The exposed, wrapped Terraform.
                  '';
                  default = pkgs.writeShellApplication {
                    name = submod.config.terraformWrapper.package.meta.mainProgram;
                    runtimeInputs = [
                      submod.config.terraformWrapper.package
                    ]
                    ++ submod.config.terraformWrapper.extraRuntimeInputs;
                    text = /* bash */ ''
                      mkdir -p ${submod.config.workdir}
                      cd ${submod.config.workdir}
                      ${submod.config.terraformWrapper.prefixText}
                      ${submod.config.terraformWrapper.package.meta.mainProgram} "$@"
                      ${submod.config.terraformWrapper.suffixText}
                    '';
                  };
                  defaultText = "The Terraform wrapper.";
                  type = types.package;
                };
                scripts = mkOption {
                  description = ''
                    The exposed Terraform scripts (apply, etc).
                  '';
                  default =
                    let
                      mkTfScript =
                        name: text:
                        pkgs.writeShellApplication {
                          inherit name;
                          runtimeInputs = [ submod.config.result.terraformWrapper ];
                          text = /* bash */ ''
                            mkdir -p ${submod.config.workdir}
                            ln -sf ${submod.config.result.terraformConfiguration} ${submod.config.workdir}/config.tf.json
                            ${text}
                          '';
                        };

                      tfBinaryName = submod.config.result.terraformWrapper.meta.mainProgram;
                    in
                    {
                      init = mkTfScript "init" /* bash */ ''
                        ${tfBinaryName} init
                      '';
                      apply = mkTfScript "apply" /* bash */ ''
                        ${tfBinaryName} init
                        ${tfBinaryName} apply -auto-approve
                      '';
                      plan = mkTfScript "plan" /* bash */ ''
                        ${tfBinaryName} init
                        ${tfBinaryName} plan
                      '';
                      destroy = mkTfScript "destroy" /* bash */ ''
                        ${tfBinaryName} init
                        ${tfBinaryName} destroy
                      '';
                    };
                  defaultText = /* nix */ ''
                    {
                      init = mkTfScript "init" '''
                        opentofu init
                      ''';
                      apply = mkTfScript "apply" '''
                        opentofu init
                        opentofu apply
                      ''';
                      plan = mkTfScript "plan" '''
                        opentofu init
                        opentofu plan
                      ''';
                      destroy = mkTfScript "destroy" '''
                        opentofu init
                        opentofu destroy
                      ''';
                    }
                  '';
                };
              };
            };
          };

          workdir = mkOption {
            description = "Working directory of the terranix configuration.";
            type = types.str;
            default = "/etc/terranix";
            internal = true;
          };

          wait = {
            services = mkOption {
              description = "A list of systemd services that are required before running terranix.";
              type = types.listOf types.str;
              example = [ "zitadel.service" ];
              default = [ ];
            };

            resources = mkOption {
              description = "An attribute set of network resources that need to be available before running terranix.";
              default = { };
              type = types.attrsOf (
                types.submodule (
                  { name, ... }:
                  {
                    options = {
                      name = mkOption {
                        description = "The name of the network resource.";
                        type = types.str;
                      };
                      type = mkOption {
                        description = "The kind of target being described";
                        type = types.enum [
                          "tcp"
                          "grpc"
                          "http"
                          "dns"
                        ];
                      };
                      target = mkOption {
                        description = "The location of the target to be tested";
                        type = types.str;
                      };
                      timeout = mkOption {
                        description = "The timeout to use for this specific target";
                        type = types.str;
                        default = "5s";
                      };
                      httpStatusPattern = mkOption {
                        description = "The regular expression pattern to match in the expected http status code result";
                        type = types.str;
                        default = "^2..$";
                      };
                      httpClientTimeout = mkOption {
                        description = "The timeout for requests made by a http client";
                        type = types.str;
                        default = "1s";
                      };
                    };

                    config = {
                      inherit name;
                    };
                  }
                )
              );
            };
          };

          configuration = configurationType;
        };
      });
    };
}
