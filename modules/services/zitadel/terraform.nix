{
  services.zitadel._.terraform.nixos =
    {
      constants,
      ...
    }:
    let
      inherit (constants.services.zitadel) domain dataDir;
    in
    {
      services.terranix = {
        wait.endpoints = ''
          https://${domain}/debug/ready
        '';

        config = {
          terraform.required_providers.zitadel = {
            source = "zitadel/zitadel";
            version = "2.12.5";
          };

          provider."zitadel" = {
            inherit domain;
            insecure = false;
            jwt_profile_file = "${dataDir}/service-account-key.json";
          };

          data = {
            "zitadel_orgs"."default" = {
              name = "sso";
              name_method = "TEXT_QUERY_METHOD_EQUALS_IGNORE_CASE";
              state = "ORG_STATE_ACTIVE";
            };

            "zitadel_org"."default" = {
              id = "\${ data.zitadel_orgs.default.ids[0] }";
            };
          };
        };
      };

      virtualisation.vmVariant.services.terranix.config = {
        provider."zitadel".insecure_skip_verify_tls = true;
      };
    };
}
