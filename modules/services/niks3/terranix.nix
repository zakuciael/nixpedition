{
  services.niks3 = {
    terranix =
      { host, ... }:
      {
        global =
          {
            lib,
            utils,
            ...
          }:
          let
            account_id = lib.tf.ref "var.cf-account-id";
            zone_id = lib.tf.ref "var.cf-zone-id";

            inherit (host.constants.services.niks3) domain s3;
          in
          {
            resource = {
              cloudflare_dns_record."niks3" = {
                inherit zone_id;
                name = domain;
                type = "A";
                proxied = true;
                ttl = 1; # set to `1` when `proxied = true`
                comment = "niks3";
                content = lib.tf.ref "local.machine-${host.hostName}-ipv4";
              };

              cloudflare_r2_bucket."nisk3" = {
                inherit account_id;
                name = s3.bucket_name;
                location = "eeur";
                storage_class = "Standard";
              };

              cloudflare_account_token."niks3" = {
                inherit account_id;
                name = "niks3";

                policies = [
                  (utils.mkTokenPolicy {
                    effect = "allow";
                    permission_groups = [
                      "Workers R2 Storage Bucket Item Write"
                    ];

                    resources = {
                      "com.cloudflare.edge.r2.bucket.${account_id}_default_${s3.bucket_name}" = "*";
                    };
                  })
                ];
              }
              // (utils.writeSecrets [
                {
                  inherit (host) hostName;
                  secret = "niks3-s3/access-key";
                  ref = "self.id";
                }
                {
                  inherit (host) hostName;
                  secret = "niks3-s3/secret-key";
                  ref = "sha256(self.value)";
                }
              ]);
            };
          };
      };
  };
}
