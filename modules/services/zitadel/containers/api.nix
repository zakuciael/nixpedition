{
  services.zitadel._.api.nixos =
    {
      config,
      pkgs,
      lib,
      constants,
      ...
    }:
    let
      inherit (constants.services.zitadel)
        ports
        dataDir
        domain
        version
        ;
    in
    {
      # Secrets
      clan.core.vars.generators = {
        "zitadel-master-key" = {
          files.key.secret = true;

          script = /* bash */ ''
            pwgen -ycsr \'\"\` 32 1 | sed -e 's/[[:space:]]*//' | tr -d '\n' > $out/key
          '';
          runtimeInputs = [
            pkgs.pwgen
            pkgs.toybox
          ];
        };
        "zitadel-admin-password" = {
          files.password.secret = true;

          script = /* bash */ ''
            pwgen -ycsr \'\"\` 32 1 | sed -e 's/[[:space:]]*//' | tr -d '\n' > $out/password
          '';
          runtimeInputs = [
            pkgs.pwgen
            pkgs.toybox
          ];
        };
      };

      sops.templates = {
        "zitadel/config.yaml".content = lib.generators.toYAML { } {
          TLS.Enabled = false;
          Port = ports.api;
          ExternalDomain = domain;
          ExternalPort = 443;
          ExternalSecure = true;

          Machine.Identification.Hostname.Enabled = true;
          Database.postgres = {
            Host = "zitadel-database";
            Port = 5432;
            Database = "zitadel";
            User = {
              Username = "postgres";
              Password = config.sops.placeholder."vars/zitadel-database-password/password";
              SSL.Mode = "disable";
            };
            Admin = {
              Username = "postgres";
              Password = config.sops.placeholder."vars/zitadel-database-password/password";
              SSL.Mode = "disable";
              ExistingDatabase = "zitadel";
            };
          };
        };
        "zitadel/init-steps.yaml".content = lib.generators.toYAML { } {
          FirstInstance = {
            InstanceName = "SSO";
            LoginPolicy.AllowRegister = false;
            MachineKeyPath = "/zitadel/service-account-key.json";
            LoginClientPatPath = "/zitadel/login-client.pat";
            Org = {
              Name = "SSO";
              Human = {
                UserName = "admin@${domain}";
                FirstName = "ZITADEL";
                LastName = "Admin";
                Password = config.sops.placeholder."vars/zitadel-admin-password/password";
                PasswordChangeRequired = false;
                Email = {
                  Address = "admin@${domain}";
                  Verified = true;
                };
              };
              Machine = {
                Machine = {
                  Username = "terraform";
                  Name = "Terraform";
                };
                MachineKey = {
                  ExpirationDate = "2099-01-01T00:00:00Z";
                  Type = 1;
                };
              };
              LoginClient = {
                Machine = {
                  Username = "login-client";
                  Name = "Login Client";
                };
                Pat.ExpirationDate = "2099-01-01T00:00:00Z";
              };
            };
          };
        };
      };

      # Containers
      virtualisation.oci-containers.containers."zitadel-api" = {
        image = "ghcr.io/zitadel/zitadel:v${version}";
        user = "root";
        volumes = [
          "${config.clan.core.vars.generators."zitadel-master-key".files.key.path}:/zitadel/masterkey:ro"
          "${config.sops.templates."zitadel/config.yaml".path}:/zitadel/config.yaml:ro"
          "${config.sops.templates."zitadel/init-steps.yaml".path}:/zitadel/steps.yaml:ro"
          "${dataDir}/login-client.pat:/zitadel/login-client.pat:rw"
          "${dataDir}/service-account-key.json:/zitadel/service-account-key.json:rw"
        ];
        cmd = [
          "start-from-init"
          "--masterkeyFile"
          "/zitadel/masterkey"
          "--steps"
          "/zitadel/steps.yaml"
          "--config"
          "/zitadel/config.yaml"
          "--tlsMode"
          "external"
        ];
        labels = {
          # Traefik config
          "traefik.enable" = "true";
          "traefik.docker.network" = "zitadel";

          # Router
          "traefik.http.routers.zitadel-api.rule" = "Host(`${domain}`) && !PathPrefix(`/ui/v2/login`)";
          "traefik.http.routers.zitadel-api.entrypoints" = "http,https";
          "traefik.http.routers.zitadel-api.service" = "zitadel-api";
          "traefik.http.routers.zitadel-api.tls.certresolver" = "cloudflare";

          # Service
          "traefik.http.services.zitadel-api.loadbalancer.server.port" = toString ports.api;
          "traefik.http.services.zitadel-api.loadbalancer.server.scheme" = "h2c";
          "traefik.http.services.zitadel-api.loadbalancer.passhostheader" = "true";
        };
        dependsOn = [
          "zitadel-database"
        ];
        podman.sdnotify = "healthy";
        log-driver = "journald";
        extraOptions = [
          "--health-cmd=[\"/app/zitadel\", \"--config\", \"/zitadel/config.yaml\", \"ready\"]"
          "--health-interval=10s"
          "--health-retries=12"
          "--health-start-period=20s"
          "--health-timeout=30s"
          "--network-alias=zitadel-api"
          "--network=zitadel"
        ];
      };

      # Systemd service override
      systemd.services."podman-zitadel-api" = {
        after = [ "podman-network-zitadel.service" ];
        requires = [ "podman-network-zitadel.service" ];
        partOf = [ "podman-compose-zitadel-root.target" ];
        wantedBy = [ "podman-compose-zitadel-root.target" ];
      };
    };
}
