{
  services.nixbot.nixos =
    {
      host,
      config,
      ...
    }:
    let
      osConfig = config;
    in
    {
      services.terranix = {
        files = { };

        config =
          { lib, ... }:
          {
            resource = {
              "cloudflare_dns_record"."nixbot-dns" = {
                zone_id = lib.tfRef "var.cloudflare_zone_id";
                name = host.constants.services.nixbot.domain;
                ttl = 1; # set to `1` when `proxied = true`
                type = "A";
                comment = "Nix CI (${osConfig.networking.hostName})";
                content = lib.tfRef "local.public_ip";
                proxied = true;
              };
            };
          };
      };
    };
}
