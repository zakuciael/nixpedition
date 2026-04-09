{
  services.zitadel.provides.secrets.nixos =
    {
      config,
      pkgs,
      constants,
      ...
    }:
    let
      serviceConfig = constants.services.zitadel;
    in
    {
      clan.core.vars.generators = {
        "zitadel-master-key" = {
          files.key.secret = true;

          script = /* bash */ ''
            echo $(pwgen -y -c -s 31 1 | sed -e 's/[[:space:]]*//') > $out/key
          '';
          runtimeInputs = [
            pkgs.pwgen
            pkgs.toybox
          ];
        };
        "zitadel-admin-password" = {
          # This secret doesn't need to be bound to a user since it is only used in SOPS template.
          files.password.secret = true;

          script = /* bash */ ''
            echo $(pwgen -y -c -s 32 1 | sed -e 's/[[:space:]]*//') > $out/password
          '';
          runtimeInputs = [
            pkgs.pwgen
            pkgs.toybox
          ];
        };
      };

      sops.templates = {
        "zitadel/init-steps.yaml" = {
          file = pkgs.writers.writeYAML "init-steps.yaml" {
            FirstInstance = {
              InstanceName = "sso";
              LoginPolicy.AllowRegister = false;
              Org = {
                Name = "SSO";
                Human = {
                  UserName = "admin@${serviceConfig.domain}";
                  FirstName = "admin";
                  LastName = "admin";
                  Password = config.sops.placeholder."vars/zitadel-admin-password/password";
                  PasswordChangeRequired = false;
                  Email = {
                    Address = "admin@${serviceConfig.domain}";
                    Verified = true;
                  };
                };
              };
            };
          };
        };
      };

      nixos-containers.containers.zitadel.binds = {
        "zitadel-master-key" = {
          mountPoint = "/run/secrets/zitadel-master-key";
          hostPath = config.clan.core.vars.generators."zitadel-master-key".files.key.path;
          isReadOnly = true;
          type = "file";
          user = {
            inherit (serviceConfig.user) name uid;
          };
          group = {
            inherit (serviceConfig.user) name gid;
          };
        };
        "zitadel-init-steps.yaml" = {
          mountPoint = "/run/secrets/zitadel-init-steps.yaml";
          hostPath = config.sops.templates."zitadel/init-steps.yaml".path;
          isReadOnly = true;
          type = "file";
          user = {
            inherit (serviceConfig.user) name uid;
          };
          group = {
            inherit (serviceConfig.user) name gid;
          };
        };
      };
    };
}
