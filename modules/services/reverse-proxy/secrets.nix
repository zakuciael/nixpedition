{
  services.reverse-proxy.provides.secrets.nixos =
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

      security.acme.defaults.credentialFiles = {
        CF_DNS_API_TOKEN_FILE = config.clan.core.vars.generators."cloudflare-api-token".files.token.path;
      };
    };
}
