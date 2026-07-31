{
  services.nixbot.nixos =
    {
      config,
      pkgs,
      constants,
      ...
    }:
    {
      clan.core.vars.generators = {
        "nixbot-webhook-secret" = {
          files."secret" = {
            secret = true;
          };

          script = /* bash */ ''
            openssl rand -base64 32 > $out/secret
          '';

          runtimeInputs = [
            pkgs.openssl
          ];
        };
        "nixbot-github-oauth-secret" = {
          files."secret" = {
            secret = true;
          };
          prompts."secret" = {
            description = "NixBot's GitHub App OAuth Secret";
            type = "hidden";
            persist = true;
          };
        };
        "nixbot-github-app-private-key" = {
          files."private_key" = {
            secret = true;
          };
          prompts."private_key" = {
            description = "NixBot's GitHub App Private Key";
            type = "hidden";
            persist = true;
          };
        };
      };
    };
}
