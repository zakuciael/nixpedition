{
  services.zitadel._.database.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      # Secrets
      clan.core.vars.generators."zitadel-database-password" = {
        files.password.secret = true;

        script = /* bash */ ''
          echo $(pwgen -y -c -s 32 1 | sed -e 's/[[:space:]]*//') > $out/password
        '';
        runtimeInputs = [
          pkgs.pwgen
          pkgs.toybox
        ];
      };

      sops.templates."zitadel/database.env".content = lib.generators.toKeyValue { } {
        POSTGRES_DB = "zitadel";
        POSTGRES_USER = "postgres";
        POSTGRES_PASSWORD = config.sops.placeholder."vars/zitadel-database-password/password";
      };

      # Containers
      virtualisation.oci-containers.containers."zitadel-database" = {
        image = "postgres:17.2-alpine";
        environmentFiles = [ config.sops.templates."zitadel/database.env".path ];
        volumes = [ "zitadel-database-data:/var/lib/postgresql/data:rw" ];
        podman.sdnotify = "healthy";
        log-driver = "journald";
        extraOptions = [
          "--health-cmd=pg_isready -d \${POSTGRES_USER} -U \${POSTGRES_DB}"
          "--health-interval=10s"
          "--health-retries=10"
          "--health-start-period=20s"
          "--health-timeout=30s"
          "--network-alias=zitadel-database"
          "--network=zitadel"
        ];
      };

      # Systemd service override
      systemd.services."podman-zitadel-database" = {
        after = [
          "podman-network-zitadel.service"
          "podman-volume-zitadel-database-data.service"
        ];
        requires = [
          "podman-network-zitadel.service"
          "podman-volume-zitadel-database-data.service"
        ];
        partOf = [
          "podman-compose-zitadel-root.target"
        ];
        wantedBy = [
          "podman-compose-zitadel-root.target"
        ];
      };

      # Volumes
      systemd.services."podman-volume-zitadel-database-data" = {
        path = [ pkgs.podman ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          podman volume inspect zitadel-database-data || podman volume create zitadel-database-data
        '';
        partOf = [ "podman-compose-zitadel-root.target" ];
        wantedBy = [ "podman-compose-zitadel-root.target" ];
      };
    };
}
