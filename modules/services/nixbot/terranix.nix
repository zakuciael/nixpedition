{
  services.nixbot.terranix =
    { host, ... }:
    {
      global =
        { lib, ... }:
        let
          inherit (host.constants.services.nixbot) domain;
        in
        {
          resource."cloudflare_dns_record"."nixbot" = {
            zone_id = lib.tf.ref "var.cf-zone-id";
            name = domain;
            type = "A";
            proxied = true;
            ttl = 1; # set to `1` when `proxied = true`
            comment = "nixbot";
            content = lib.tf.ref "local.machine-${host.hostName}-ipv4";
          };
        };
    };
}
