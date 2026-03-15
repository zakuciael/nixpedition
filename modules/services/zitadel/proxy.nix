{
  services.zitadel.provides.proxy.nixos =
    { constants, ... }:
    let
      inherit (constants.services.zitadel) containerAddress port domain;
    in
    {
      security.acme.certs."${domain}" = { };
      services.caddy.virtualHosts."${domain}" = {
        useACMEHost = domain;
        extraConfig = ''
          reverse_proxy /ui/v2/login/* http://${containerAddress}:${toString port}
          reverse_proxy h2c://${containerAddress}:${toString port} {
            header_up -TE
          }
        '';
      };
    };
}
