{
  flake.terranixModules.cloudflare =
    { lib, utils, ... }:
    {
      secrets."cf-api-token" = { };

      terraform.required_providers.cloudflare.source = "cloudflare/cloudflare";

      provider."cloudflare".api_token = utils.readSecret "cf-api-token";

      variable = {
        "cf-account-id".default = "42581ab302804a0532eb52ee78b6b18f";
      };

      data."cloudflare_account_api_token_permission_groups_list"."all" = {
        account_id = lib.tf.ref "var.cf-account-id";
      };
    };

  perSystem = { lib, ... }: {
    terranix.terranixConfigurations.nixpedition = {
      extraArgs = {
        utils = rec {
          mkCfZoneIdRefBySubdomain =
            domain:
            let
              split = lib.reverseList (lib.splitString "." domain);
            in
            mkCfZoneIdRef "${builtins.elemAt split 1}.${builtins.elemAt split 0}";
          mkCfZoneIdRef =
            name:
            "\${[for zone in data.cloudflare_zones.zones.result : zone.id if zone.name == \"${name}\"][0]}";
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
