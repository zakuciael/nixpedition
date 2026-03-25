{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  services.zitadel = {
    includes = [
      <services/zitadel/secrets>
      <services/zitadel/proxy>
    ];

    nixos =
      { config, constants, ... }:
      let
        serviceConfig = constants.services.zitadel;
      in
      {
        containers-utils.zitadel = {
          privateNetwork = true;
          binds = {
            "postgres-data" = {
              mountPoint = "/var/lib/postgresql/17";
              hostPath = "/var/lib/zitadel/postgres";
              isReadOnly = false;
              user = {
                name = "postgres";
                uid = config.ids.uids.postgres;
                gid = config.ids.gids.postgres;
              };
            };
          };
        };

        containers.zitadel = {
          ephemeral = true;
          autoStart = true;

          # Network config
          localAddress = serviceConfig.containerAddress;
          localAddress6 = serviceConfig.containerAddress6;

          config =
            { pkgs, ... }:
            {
              # Set the state version to the same as the host
              system.stateVersion = config.system.stateVersion;

              networking.firewall = {
                enable = true;
                allowedTCPPorts = [ serviceConfig.port ];
              };

              services.postgresql = {
                enable = true;
                package = pkgs.postgresql_17_jit;
                enableJIT = true;
                authentication = ''
                  local all all trust
                  host all all 127.0.0.1/8 trust
                  host all all ::1/128 trust
                  host all all fc00::1/128 trust
                '';
                ensureDatabases = [ "zitadel" ];
                ensureUsers = [
                  {
                    name = "zitadel";
                    ensureDBOwnership = true;
                    ensureClauses.login = true;
                    ensureClauses.superuser = true;
                  }
                ];
              };

              services.zitadel = {
                enable = true;
                openFirewall = true;
                masterKeyFile = config.containers-utils.zitadel.binds."zitadel-master-key".mountPoint;
                extraStepsPaths = [ config.containers-utils.zitadel.binds."zitadel-init-steps.yaml".mountPoint ];

                tlsMode = "external";
                settings = {
                  Port = serviceConfig.port;
                  ExternalDomain = serviceConfig.domain;
                  ExternalPort = 443;
                  ExternalSecure = true;

                  Machine.Identification.Hostname.Enabled = true;
                  Database.postgres = {
                    Host = "/var/run/postgresql/";
                    Port = 5432;
                    Database = "zitadel";
                    User = {
                      Username = "zitadel";
                      SSL.Mode = "disable";
                    };
                    Admin = {
                      Username = "zitadel";
                      SSL.Mode = "disable";
                      ExistingDatabase = "zitadel";
                    };
                  };
                };
              };

              systemd.services.zitadel = {
                requires = [ "postgresql.service" ];
                after = [ "postgresql.service" ];
              };
            };
        };
      };
  };
}
