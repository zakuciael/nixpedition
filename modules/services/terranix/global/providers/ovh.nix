{
  flake.terranixModules.ovh =
    { lib, utils, ... }:
    {
      secrets = {
        "ovh-client-id" = { };
        "ovh-client-secret" = { };
        "ovh-francois-service-name" = { };
      };

      terraform.required_providers.ovh.source = "ovh/ovh";

      provider."ovh" = {
        endpoint = "ovh-eu";
        client_id = utils.readSecret "ovh-client-id";
        client_secret = utils.readSecret "ovh-client-secret";
      };

      data."ovh_vps"."francois".service_name = utils.readSecret "ovh-francois-service-name";

      locals."machine-francois-ipv4" =
        lib.tf.ref "[for cidr in data.ovh_vps.francois.ips : cidr if ! can(regex(\"::\", cidr))][0]";
    };
}
