{
  services.authelia.nixos =
    { host, config, ... }:
    let
      inherit (host.constants.services.authelia) redis;
      cfg = config.services.redis.servers."authelia";
    in
    {
      services = {
        authelia.instances."".settings.session.redis.host = cfg.unixSocket;
        redis.servers."authelia" = {
          enable = true;
          inherit (redis) port;
        };
      };

      # Give Authelia access to the Redis socket
      users.users."authelia".extraGroups = [ "redis-authelia" ];
    };
}
