{
  services.reverse-proxy._.secrets.nixos =
    { config, ... }:
    {
      clan.core.vars.generators = {
        "cloudflare-api-token" = {
          files."token".secret = true;
          prompts.token = {
            description = "Your cloudflare API access token";
            type = "hidden";
            persist = true;
          };
        };
      };

      sops.templates."traefik/envs".content = ''
        CF_DNS_API_TOKEN=${config.sops.placeholder."vars/cloudflare-api-token/token"}
      '';
    };
}
