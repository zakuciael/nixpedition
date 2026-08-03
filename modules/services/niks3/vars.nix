{
  services.niks3.nixos =
    {
      host,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.services.niks3;
    in
    {
      clan.core.vars.generators = {
        niks3-constants = {
          files = {
            port.secret = false;
            domain.secret = false;
            "s3.bucket_name".secret = false;
            "s3.endpoint".secret = false;
          };

          prompts = {
            port = {
              description = "Port for the niks3 server";
              persist = true;
              type = "line";
            };
            domain = {
              description = "Domain for the niks3 server";
              persist = true;
              type = "line";
            };
            "s3.bucket_name" = {
              description = "S3 Bucket name for the niks3 server";
              persist = true;
              type = "line";
            };
            "s3.endpoint" = {
              description = "S3 Endpoint for the niks3 server";
              persist = true;
              type = "line";
            };
          };
        };

        niks3-api-token = {
          files."token" = {
            secret = true;
            owner = cfg.user;
            inherit (cfg) group;
          };

          script = /* bash */ ''
            openssl rand -base64 32 > $out/token
          '';

          runtimeInputs = [
            pkgs.openssl
          ];
        };
        niks3-signing-key = {
          files = {
            "key" = {
              secret = true;
              owner = cfg.user;
              inherit (cfg) group;
            };
            "key.pub".secret = false;
          };

          script = /* bash */ ''
            nix --extra-experimental-features "nix-command flakes" \
              key generate-secret --key-name "${host.constants.services.binary-cache.domain}-1" > $out/key
            nix --extra-experimental-features "nix-command flakes" \
              key convert-secret-to-public < $out/key > $out/key.pub
          '';

          runtimeInputs = [
            pkgs.nix
          ];
        };
        niks3-s3 = {
          files."access-key" = {
            secret = true;
            owner = cfg.user;
            inherit (cfg) group;
          };
          files."secret-key" = {
            secret = true;
            owner = cfg.user;
            inherit (cfg) group;
          };
          script = ''
            echo "niks3-s3 credentials are populated by terraform, not generated" >&2
            exit 1
          '';
        };
      };
    };
}
