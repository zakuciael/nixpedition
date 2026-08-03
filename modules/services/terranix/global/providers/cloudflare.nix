{
  flake.terranixModules.cloudflare =
    { lib, utils, ... }:
    {
      secrets."cf-api-token" = { };

      terraform.required_providers.cloudflare.source = "cloudflare/cloudflare";

      provider."cloudflare".api_token = utils.readSecret "cf-api-token";

      variable = {
        "cf-account-id".default = "42581ab302804a0532eb52ee78b6b18f";
        "cf-zone-id".default = "080f668443e1f922480f39fea7606c1b";
      };

      data."cloudflare_account_api_token_permission_groups_list"."all" = {
        account_id = lib.tf.ref "var.cf-account-id";
      };
    };

  perSystem = {
    terranix.terranixConfigurations.nixpedition = {
      extraArgs = {
        utils = rec {
          mkCfPermGroupRef =
            name:
            "\${[for pg in data.cloudflare_account_api_token_permission_groups_list.all.result : pg.id if pg.name == \"${name}\"][0]}";
          mkTokenPolicy =
            {
              effect,
              permission_groups,
              resources,
            }:
            {
              inherit effect;
              permission_groups =
                permission_groups
                |> map (name: {
                  id = mkCfPermGroupRef name;
                });

              resources = builtins.toJSON resources;
            };
        };
      };
    };
  };
}
