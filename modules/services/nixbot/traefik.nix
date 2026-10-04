{
  services.nixbot.traefik =
    { host, ... }:
    let
      inherit (host.constants.services.nixbot) domain port;
    in
    {
      nixbot.http = {
        routers.nixbot = {
          rule = "Host(`${domain}`)";
          entryPoints = [
            "http"
            "https"
          ];
          tls.certResolver = "cloudflare";
          service = "nixbot";
        };

        serversTransports.nixbot = {
          # respondingTimeouts = {
          #   readTimeout = "3600s";
          #   writeTimeout = "0";
          #   idleTimeout = "180s";
          # };
          forwardingTimeouts = {
            dialTimeout = "120s"; # ~ proxy_connect_timeout
            responseHeaderTimeout = "3600s"; # ~ proxy_read_timeout (time to first response byte)
            idleConnTimeout = "90s";
          };
        };

        services.nixbot = {
          loadBalancer = {
            serversTransport = "nixbot";
            passHostHeader = true;
            servers = [
              {
                url = "http://localhost:${toString port}";
              }
            ];
          };
        };
      };
    };
}
