{
  services.terranix.providers.cloudflare.nixos =
    { config, pkgs, ... }:
    {
      # Secrets
      clan.core.vars.generators = {
        "terranix-cf-token" = {
          files."token".secret = true;
          prompts.token = {
            description = "Cloudflare API token for Terranix";
            type = "hidden";
            persist = true;
          };
        };
        "terranix-cf-zone-id" = {
          files."zone_id".secret = true;
          prompts.zone_id = {
            description = "Cloudflare Zone ID for Terranix";
            type = "hidden";
            persist = true;
          };
        };
        "terranix-cf-account-id" = {
          files."account_id".secret = false;
          prompts.account_id = {
            description = "Cloudflare Account ID for Terranix";
            type = "line";
            persist = true;
          };
        };
      };

      # Terranix configuration
      services.terranix = {
        terraform.providers = with pkgs.terraform-providers; [ cloudflare_cloudflare ];

        variables = {
          cloudflare_api_token = {
            type = "string";
            placeholder = config.sops.placeholder."vars/terranix-cf-token/token";
            secret = true;
          };
          cloudflare_account_id = {
            type = "string";
            text = config.clan.core.vars.generators."terranix-cf-account-id".files."account_id".value;
            secret = false;
          };
          cloudflare_zone_id = {
            type = "string";
            placeholder = config.sops.placeholder."vars/terranix-cf-zone-id/zone_id";
            secret = true;
          };
        };

        extraArgs.utils.mkCloudflarePermGroupIdRef =
          name:
          "\${[for pg in data.cloudflare_account_api_token_permission_groups_list.all.result : pg.id if pg.name == \"${name}\"][0]}";

        config =
          { lib, ... }:
          {
            terraform.required_providers.cloudflare.source = "cloudflare/cloudflare";
            provider."cloudflare".api_token = lib.tfRef "var.cloudflare_api_token";

            data."cloudflare_account_api_token_permission_groups_list"."all" = {
              account_id = lib.tfRef "var.cloudflare_account_id";
            };
          };
      };
    };
}
