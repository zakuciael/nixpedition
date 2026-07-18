{
  services.binary-cache.nixos =
    { config, constants, ... }:
    let
      osConfig = config;
    in
    {
      services.terranix = {
        files = {
          "binary-cache-access-key-id" = {
            path = "/run/secrets/terranix/binary-cache-access-key-id";
            content = "\${cloudflare_account_token.binary-cache-access-token.id}";
            owner = osConfig.services.niks3.user;
            group = osConfig.services.niks3.group;
          };
          "binary-cache-access-key-secret" = {
            path = "/run/secrets/terranix/binary-cache-access-key-secret";
            content = "\${sha256(cloudflare_account_token.binary-cache-access-token.value)}";
            secret = true;
            owner = osConfig.services.niks3.user;
            group = osConfig.services.niks3.group;
          };
        };

        config =
          { lib, utils, ... }:
          {
            resource = {
              "cloudflare_dns_record"."binary-cache-dns" = {
                zone_id = lib.tfRef "var.cloudflare_zone_id";
                name = constants.services.binary-cache.domain;
                ttl = 1; # set to `1` when `proxied = true`
                type = "A";
                comment = "Nix binary cache (${osConfig.networking.hostName})";
                content = lib.tfRef "local.public_ip";
                proxied = true;
              };
              "cloudflare_r2_bucket"."binary-cache-bucket" = {
                account_id = lib.tfRef "var.cloudflare_account_id";
                name = "binary-cache";
                location = "eeur";
                storage_class = "Standard";
              };
              "cloudflare_account_token"."binary-cache-access-token" = {
                account_id = lib.tfRef "var.cloudflare_account_id";
                name = "Binary Cache (${osConfig.networking.hostName})";

                policies = [
                  {
                    effect = "allow";
                    permission_groups = [
                      { id = utils.mkCloudflarePermGroupIdRef "Workers R2 Storage Bucket Item Write"; }
                    ];
                    resources = {
                      "com.cloudflare.edge.r2.bucket.${lib.tfRef "var.cloudflare_account_id"}_default_${lib.tfRef "cloudflare_r2_bucket.binary-cache-bucket.name"}" =
                        "*";
                    };
                  }
                ];
              };
            };
          };
      };
    };
}
