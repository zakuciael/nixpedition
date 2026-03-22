{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  services.reverse-proxy = {
    includes = [
      <services/reverse-proxy/secrets>
    ];

    nixos =
      { config, lib, ... }:
      {
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        services.traefik = {
          enable = true;
          # Set the group to the currently enabled OCI Containers backend, so that the Docker/Podman integration works.
          group = config.virtualisation.oci-containers.backend;
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

            # Enable docker provider only if a OCI Container backend is enabled and it exposes an API socket.
            providers =
              lib.optionalAttrs
                (
                  (
                    config.virtualisation.oci-containers.backend == "podman"
                    && config.virtualisation.podman.dockerSocket.enable
                  )
                  || config.virtualisation.oci-containers.backend == "docker"
                )
                {
                  docker = {
                    endpoint = "unix:///var/run/docker.sock";
                    watch = true;
                    exposedByDefault = false;
                  };
                };

            global = {
              checkNewVersion = false;
              sendAnonymousUsage = false;
            };

            log = {
              level = lib.mkDefault "INFO";
              format = "common";
            };
            accessLog.format = "common";

            certificatesResolvers.cloudflare.acme = {
              dnsChallenge = {
                provider = "cloudflare";
                propagation.delayBeforeChecks = 0;
              };
              email = "me@krzysztofsaczuk.pl";
              storage = "acme.json";
            };
          };
        };

        # Custom traefik config when running inside a VM
        virtualisation.vmVariant = {
          networking.firewall.allowedTCPPorts = [ 8080 ];

          services.traefik.staticConfigOptions = {
            api.insecure = true;
            log.level = "TRACE";
            certificatesResolvers.cloudflare.acme.caServer = "https://acme-staging-v02.api.letsencrypt.org/directory";
          };
        };
      };
  };
}
