{
  services.authelia.nixos =
    {
      config,
      pkgs,
      ...
    }:
    let
      serviceCfg = config.services.authelia.instances."";
    in
    {
      clan.core.vars.generators = {
        authelia-constants = {
          files = {
            "port".secret = false;
            "domain".secret = false;
            "root_domain".secret = false;
            "access_control.default.domain".secret = false;
            "access_control.default.policy".secret = false;
            "redis.port".secret = false;

          };

          prompts = {
            "port" = {
              description = "Port for the Authelia server";
              persist = true;
              type = "line";
            };
            "domain" = {
              description = "Domain for the Authelia server";
              persist = true;
              type = "line";
            };
            "root_domain" = {
              description = "Base domain for the Authelia's sessions";
              persist = true;
              type = "line";
            };

            "access_control.default.domain" = {
              description = "Domain for the Authelia's default access control rule";
              persist = true;
              type = "line";
            };
            "access_control.default.policy" = {
              description = "Policy for the Authelia's default access control rule";
              persist = true;
              type = "line";
            };
            "redis.port" = {
              description = "Port for the Authelia Redis server";
              persist = true;
              type = "line";
            };
          };
        };

        # Authelia service
        authelia-jwt-secret = {
          files."secret" = {
            secret = true;
            owner = serviceCfg.user;
            group = serviceCfg.user;
          };

          script = /* bash */ ''
            openssl rand -hex -out $out/secret 64
          '';

          runtimeInputs = [
            pkgs.openssl
          ];
        };
        authelia-storage-encryption-key = {
          files."key" = {
            secret = true;
            owner = serviceCfg.user;
            group = serviceCfg.user;
          };

          script = /* bash */ ''
            openssl rand -hex -out $out/key 32
          '';

          runtimeInputs = [
            pkgs.openssl
          ];
        };
        authelia-session-secret = {
          files."secret" = {
            secret = true;
            owner = serviceCfg.user;
            group = serviceCfg.user;
          };

          script = /* bash */ ''
            openssl rand -hex -out $out/secret 32
          '';

          runtimeInputs = [
            pkgs.openssl
          ];
        };
        # authelia-lldap-user-password = {
        #   files."password" = {
        #     secret = true;
        #     owner = serviceCfg.user;
        #     group = serviceCfg.user;
        #   };

        #   script = /* bash */ ''
        #     tr -dc 'A-Za-z0-9~_-' < /dev/urandom | head -c 20 > $out/password || true
        #   '';
        # };
      };
    };
}
