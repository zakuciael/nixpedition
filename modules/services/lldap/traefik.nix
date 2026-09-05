{
  services.lldap.traefik =
    { host, ... }:
    let
      inherit (host.constants.services.lldap) domain http_port;
    in
    {
      # TODO: Secure access to the LDAP server dashboard.
      lldap.http = {
        routers.lldap = {
          rule = "Host(`${domain}`)";
          entryPoints = [
            "http"
            "https"
          ];
          tls.certResolver = "cloudflare";
          service = "lldap";
        };
        services.lldap.loadBalancer = {
          passHostHeader = true;
          servers = [
            {
              url = "http://localhost:${toString http_port}";
            }
          ];
        };
      };
    };
}
