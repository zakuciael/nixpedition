{
  services.zitadel._.login.nixos =
    {
      constants,
      ...
    }:
    let
      inherit (constants.services.zitadel)
        dataDir
        ports
        domain
        version
        ;
    in
    {
      # Containers
      virtualisation.oci-containers.containers."zitadel-login" = {
        image = "ghcr.io/zitadel/zitadel-login:v${version}";
        user = "root";
        environment = {
          "CUSTOM_REQUEST_HEADERS" = "Host:${domain},X-Forwarded-Proto:https";
          "NEXT_PUBLIC_BASE_PATH" = "/ui/v2/login";
          "PORT" = toString ports.login;
          "ZITADEL_API_URL" = "http://zitadel-api:${toString ports.api}";
          "ZITADEL_SERVICE_USER_TOKEN_FILE" = "/zitadel/login-client.pat";
        };
        volumes = [
          "${dataDir}/login-client.pat:/zitadel/login-client.pat:ro"
        ];
        labels = {
          "traefik.enable" = "true";
          "traefik.docker.network" = "zitadel";

          # Router
          "traefik.http.routers.zitadel-login.rule" = "Host(`${domain}`) && PathPrefix(`/ui/v2/login`)";
          "traefik.http.routers.zitadel-login.entrypoints" = "http,https";
          "traefik.http.routers.zitadel-login.service" = "zitadel-login";
          "traefik.http.routers.zitadel-login.tls.certresolver" = "cloudflare";

          # Service
          "traefik.http.services.zitadel-login.loadbalancer.server.port" = toString ports.login;
          "traefik.http.services.zitadel-login.loadbalancer.passhostheader" = "true";
        };
        dependsOn = [
          "zitadel-api"
        ];
        podman.sdnotify = "healthy";
        log-driver = "journald";
        extraOptions = [
          "--health-cmd=[\"/bin/sh\", \"-c\", \"node /app/healthcheck.mjs /ui/v2/login/healthy\"]"
          "--health-interval=10s"
          "--health-retries=12"
          "--health-start-period=20s"
          "--health-timeout=30s"
          "--network-alias=zitadel-login"
          "--network=zitadel"
        ];
      };

      # Systemd service override
      systemd.services."podman-zitadel-login" = {
        after = [ "podman-network-zitadel.service" ];
        requires = [ "podman-network-zitadel.service" ];
        partOf = [ "podman-compose-zitadel-root.target" ];
        wantedBy = [ "podman-compose-zitadel-root.target" ];
      };
    };
}
