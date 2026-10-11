{
  services.niks3.traefik =
    { host, config, ... }:
    let
      inherit (host.constants.services.niks3) domain;
      cfg = config.services.niks3;
    in
    {
      binary-cache.http = {
        routers.binary-cache = {
          rule = "Host(`${domain}`)";
          entryPoints = [
            "http"
            "https"
          ];
          tls.certResolver = "cloudflare";
          service = "binary-cache";
        };

        serversTransports.binary-cache.forwardingTimeouts = {
          dialTimeout = cfg.nginx.proxyTimeout;
          responseHeaderTimeout = cfg.nginx.proxyTimeout;
        };

        services.binary-cache = {
          loadBalancer = {
            serversTransport = "binary-cache";
            passHostHeader = true;
            servers = [
              {
                url = "http://${cfg.httpAddr}";
              }
            ];
          };
        };
      };
    };
}
