{
  services.zitadel.provides.proxy.nixos =
    { constants, ... }:
    let
      serviceConfig = constants.services.zitadel;
    in
    {
      services.traefik.dynamicConfigOptions.http = {
        services = {
          zitadel.loadBalancer = {
            servers = [
              { url = "h2c://${serviceConfig.containerAddress}:${toString serviceConfig.port}"; }
            ];
            passHostHeader = true;
          };
          zitadel-login.loadBalancer = {
            servers = [
              { url = "http://${serviceConfig.containerAddress}:${toString serviceConfig.port}"; }
            ];
            passHostHeader = true;
          };
        };

        routers = {
          zitadel = {
            rule = "Host(`${serviceConfig.domain}`) && !PathPrefix(`/ui/v2/login`)";
            service = "zitadel";
            tls.certResolver = "cloudflare";
            entryPoints = [
              "http"
              "https"
            ];
          };
          zitadel-login = {
            rule = "Host(`${serviceConfig.domain}`) && PathPrefix(`/ui/v2/login`)";
            service = "zitadel-login";
            tls.certResolver = "cloudflare";
            entryPoints = [
              "http"
              "https"
            ];
          };
        };
      };
    };
}
