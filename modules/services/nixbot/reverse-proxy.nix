{
  services.nixbot.nixos =
    { constants, ... }:
    let
      inherit (constants.services.nixbot) domain port;
    in
    {
      services.traefik.dynamicConfigOptions.http = {
        routers.nixbot = {
          rule = "Host(`${domain}`)";
          entryPoints = [
            "http"
            "https"
          ];
          middlewares = [ "nixbot" ];
          tls.certResolver = "cloudflare";
          service = "nixbot";
        };

        middlewares.nixbot.buffering = {
          maxRequestBodyBytes = 26214400; # 25m in bytes, request-side only
          memRequestBodyBytes = 2097152; # buffer in memory up to 2MB before spilling to disk
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
