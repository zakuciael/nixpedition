{
  services.reverse-proxy.secrets.nixos =
    { config, ... }:
    {
      clan.core.vars.generators = {
        "traefik-cf-token" = {
          files."token".secret = true;
          prompts.token = {
            description = "Cloudflare API token for Traefik";
            type = "hidden";
            persist = true;
          };
        };
      };

      sops.templates."traefik/envs".content = ''
        CF_DNS_API_TOKEN=${config.sops.placeholder."vars/traefik-cf-token/token"}
      '';
    };
}
