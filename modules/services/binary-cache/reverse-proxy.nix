{
  services.binary-cache.nixos =
    { config, ... }:
    let
      cfg = config.services.niks3;

      terraformConfig = config.services.terranix.result.terraformConfig.passthru.config;
      domain = terraformConfig.resource."cloudflare_dns_record"."binary-cache-dns".name;
    in
    {
      services.traefik.dynamicConfigOptions.http = {
        routers = {
          binary-cache = {
            rule = "Host(`${domain}`) && !Path(`/`)";
            entryPoints = [
              "http"
              "https"
            ];
            tls.certResolver = "cloudflare";
            service = "binary-cache";
          };
          binary-cache-landing-page = {
            rule = "Host(`${domain}`) && Path(`/`)";
            entryPoints = [
              "http"
              "https"
            ];
            middlewares = [
              "binary-cache-landing-page"
            ];
            tls.certResolver = "cloudflare";
            service = "binary-cache";
          };
        };

        middlewares.binary-cache-landing-page.replacePath.path = "/index.html";

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
