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
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        config = {
          networking.firewall.allowedTCPPorts = [
            80
            443
          ];

          services.caddy = {
            enable = true;
            package = pkgs.caddy.withPlugins {
              plugins = [
                "github.com/mholt/caddy-l4@v0.1.0"
              ];
              hash = "sha256-Q3Og34QO9Zbecf5jZCj+cr8riGW4/T44uJcRc3gU5aE=";
            };

            # Default log settings
            logFormat = ''
              format console
              level INFO
            '';

            # Global settings
            enableReload = true; # Only enable when admin API is turned on
            globalConfig = ''
              admin unix/${config.services.caddy.dataDir}/admin.sock
            '';
          };

          security.acme = {
            acceptTerms = true;
            defaults = {
              email = "me@krzysztofsaczuk.pl";
              dnsResolver = "1.1.1.1:53";
              dnsProvider = "cloudflare";
            };
          };

          virtualisation.vmVariant = {
            security.acme.defaults.server = "https://acme-staging-v02.api.letsencrypt.org/directory";
            services.caddy.logFormat = lib.mkForce ''
              format console
              level DEBUG
            '';

            # Add a rule to the /etc/hosts file to point all virtual hosts to localhost.
            networking.hosts = {
              "127.0.0.1" = config.services.caddy.virtualHosts |> lib.attrNames;
            };

            # Add Let's Encrypt Staging Root CAs to the system's trusted certificates.
            security.pki.certificateFiles = [
              "${pkgs.letsencrypt-staging-cacert}/etc/ssl/certs/ca-bundle.pem"
            ];

            nixos-containers.defaultConfig = {
              # Add a rule to the /etc/hosts file to point all virtual hosts to the containers host IP address
              networking.hosts = {
                "${config.nixos-containers.hostAddress}" = config.services.caddy.virtualHosts |> lib.attrNames;
              };

              # Add Let's Encrypt Staging Root CAs to the system's trusted certificates.
              security.pki.certificateFiles = [
                "${pkgs.letsencrypt-staging-cacert}/etc/ssl/certs/ca-bundle.pem"
              ];
            };
          };
        };
      };
  };
}
