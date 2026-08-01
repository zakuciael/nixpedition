{
  den.quirks.traefik = {
    description = "Traefik dynamic file declarations";
  };

  services.traefik.nixos =
    {
      traefik,
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib)
        mkDefault
        optionalAttrs
        mapAttrs'
        foldl
        recursiveUpdate
        ;

      dynamicFiles = traefik |> foldl (acc: val: recursiveUpdate acc val) { };
      dynamicDir = "/var/lib/traefik/dynamic";

      format = pkgs.formats.json { };
      cfg = config.services.traefik;
    in
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
          providers = {
            file = {
              directory = dynamicDir;
              watch = true;
            };
          }
          // (optionalAttrs
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
            }
          );

          global = {
            checkNewVersion = false;
            sendAnonymousUsage = false;
          };

          log = {
            level = mkDefault "INFO";
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

      systemd.tmpfiles.settings."traefik" = {
        "${cfg.dataDir}".d = {
          inherit (cfg) group;
          user = "traefik";
          mode = "0700";
        };

        "${dynamicDir}".d = {
          inherit (cfg) group;
          user = "traefik";
          mode = "0700";
        };
        "${dynamicDir}/_nixos-*".r = { };
      }
      // (
        dynamicFiles
        |> mapAttrs' (
          name: value: {
            name = "${dynamicDir}/_nixos-${name}.yml";
            value = {
              "L+" = {
                mode = "0444";
                argument = toString (format.generate name value);
              };
            };
          }
        )
      );

      # Custom traefik config when running inside a VM
      virtualisation.vmVariant = {
        networking.firewall.allowedTCPPorts = [ 8080 ];

        # Add Let's Encrypt Staging Root CAs to the system's trusted certificates.
        security.pki.certificateFiles = [
          "${pkgs.letsencrypt-staging-cacert}/etc/ssl/certs/ca-bundle.pem"
        ];

        services.traefik.staticConfigOptions = {
          api.insecure = true;
          log.level = "TRACE";
          certificatesResolvers.cloudflare.acme.caServer = "https://acme-staging-v02.api.letsencrypt.org/directory";
        };
      };
    };
}
