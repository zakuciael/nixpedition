{
  services.authelia = {
    nixos = {
      # https://www.authelia.com/integration/proxies/traefik/
      services.authelia.instances."".settings.server.endpoints.authz.forward-auth.implementation =
        "ForwardAuth";
    };

    traefik =
      { host, ... }:
      let
        inherit (host.constants.services.authelia) domain port;

        serviceUrl = "http://localhost:${toString port}";
      in
      {
        authelia.http = {
          routers.authelia = {
            rule = "Host(`${domain}`)";
            entryPoints = [
              "http"
              "https"
            ];
            tls.certResolver = "cloudflare";
            service = "authelia";
          };
          services.authelia.loadBalancer = {
            passHostHeader = true;
            servers = [
              {
                url = serviceUrl;
              }
            ];
          };
          middlewares.authelia.forwardAuth = {
            address = "${serviceUrl}/api/authz/forward-auth";
            trustForwardHeader = true;
            maxResponseBodySize = 8192;
            authResponseHeaders = "Remote-User,Remote-Groups,Remote-Email,Remote-Name";
          };
        };
      };
  };
}
