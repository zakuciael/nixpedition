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
            inherit (host.constants.services.niks3) domain cacheDomain s3;

            account_id = lib.tf.ref "var.cf-account-id";
            zone_id = utils.mkCfZoneIdRefBySubdomain domain;
          in
          {
            data.cloudflare_zones.zones = {
              account.id = account_id;
              order = "name";
              status = "active";
            };

            # Fix typo in the `cloudflare_r2_bucket` resource name. (nisk3 -> niks3)
            moved = [
              {
                from = "cloudflare_r2_bucket.nisk3";
                to = "cloudflare_r2_bucket.niks3";
              }
            ];

            resource = {
              cloudflare_dns_record."niks3" = {
                inherit zone_id;
                name = domain;
                type = "A";
                proxied = true;
                ttl = 1; # set to `1` when `proxied = true`
                comment = "niks3 write/API host";
                content = lib.tf.ref "local.machine-${host.hostName}-ipv4";
              };

              cloudflare_r2_bucket."niks3" = {
                inherit account_id;
                name = s3.bucket_name;
                location = "eeur";
                storage_class = "Standard";
              };

              # Public reads for the binary cache via R2 custom domain.
              # Created after the write-host DNS record update so cacheDomain
              # is no longer bound to the francois A record.
              cloudflare_r2_custom_domain."niks3-cache" = {
                inherit account_id zone_id;
                inherit (s3) bucket_name;
                domain = cacheDomain;
                enabled = true;

                depends_on = [
                  "cloudflare_dns_record.niks3"
                  "cloudflare_r2_bucket.niks3"
                ];
              };

              # Serve the landing page at / on the public cache host.
              cloudflare_ruleset."niks3-cache-index" = {
                inherit zone_id;
                name = "niks3 cache root to index.html";
                kind = "zone";
                phase = "http_request_transform";
                rules = [
                  {
                    ref = "cache-root-to-index";
                    description = "Serve landing page at /";
                    expression = ''(http.host eq "${cacheDomain}" and http.request.uri.path eq "/")'';
                    action = "rewrite";
                    action_parameters.uri.path.value = "/index.html";
                  }
                ];
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
