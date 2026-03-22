{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  services.reverse-proxy = {
    includes = [ <services/reverse-proxy/secrets> ];

    nixos =
      { config, ... }:
      {
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        services.traefik = {
          enable = true;
          environmentFiles = [ config.sops.templates."traefik/envs".path ];

          staticConfigOptions = {
            entryPoints = {
              http = {
                address = ":80";
                asDefault = true;
                http.redirections.entrypoint = {
                  to = "https";
                  scheme = "https";
                };
              };
              https = {
                address = ":443";
                asDefault = true;
                http.tls.certResolver = "cloudflare";
              };
            };

            global = {
              checkNewVersion = false;
              sendAnonymousUsage = false;
            };

            log = {
              level = "INFO";
              filePath = "${config.services.traefik.dataDir}/traefik.log";
            };
            accessLog.filePath = "${config.services.traefik.dataDir}/access.log";

            certificatesResolvers.cloudflare.acme = {
              dnsChallenge = {
                provider = "cloudflare";
                propagation.delayBeforeChecks = 0;
              };
              email = "me@krzysztofsaczuk.pl";
              storage = "${config.services.traefik.dataDir}/acme.json";
            };
          };
        };

        # Custom traefik config when running as a VM
        virtualisation.vmVariant = {
          networking.firewall.allowedTCPPorts = [ 8080 ];

          services.traefik.staticConfigOptions = {
            api.insecure = true;
            certificatesResolvers.cloudflare.acme.caServer = "https://acme-staging-v02.api.letsencrypt.org/directory";
          };
        };
      };
  };
}
