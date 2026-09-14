{
  services.nixbot.terranix =
    { host, ... }:
    {
      global =
        { lib, utils, ... }:
        let
          inherit (host.constants.services.nixbot) domain;
        in
        {
          resource."cloudflare_dns_record"."nixbot" = {
            zone_id = utils.mkCfZoneIdRefBySubdomain domain;
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
