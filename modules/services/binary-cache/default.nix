{
  inputs,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  flake-file.inputs = {
    niks3 = {
      url = "github:Mic92/niks3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  services.binary-cache.nixos =
    {
      config,
      lib,
      constants,
      ...
    }:
    let
      inherit (constants.services.binary-cache) port;

      terranixConfig = config.services.terranix;
      terraformConfig = terranixConfig.result.terraformConfig.passthru.config;

      domain = terraformConfig.resource."cloudflare_dns_record"."binary-cache-dns".name;
    in
    {
      imports = [ inputs.niks3.nixosModules.default ];

      virtualisation.vmVariant = {
        networking.firewall.allowedTCPPorts = [ port ];
        services.niks3.httpAddr = "0.0.0.0:${toString port}";
      };

      services.niks3 = {
        enable = true;
        httpAddr = lib.mkDefault "127.0.0.1:${toString port}";

        cacheUrl = "https://${domain}";
        readProxy.enable = true;
        nginx.enable = false;

        apiTokenFile = config.clan.core.vars.generators.binary-cache-api-token.files.token.path;
        signKeyFiles = [ config.clan.core.vars.generators.binary-cache-signing-key.files.key.path ];

        s3 =
          let
            cloudflare_account_id =
              config.clan.core.vars.generators."terranix-cf-account-id".files."account_id".value;
          in
          {
            endpoint = "${cloudflare_account_id}.r2.cloudflarestorage.com";
            bucket = terraformConfig.resource."cloudflare_r2_bucket"."binary-cache-bucket".name;
            region = "auto";

            useSSL = true;

            accessKeyFile = terranixConfig.files."binary-cache-access-key-id".path;
            secretKeyFile = terranixConfig.files."binary-cache-access-key-secret".path;
          };

        gc = {
          enable = true;
          olderThan = "336h"; # 14 days
          failedUploadsOlderThan = "6h"; # 6 hours
          schedule = "daily"; # Run at midnight daily
          randomizedDelaySec = 1800; # Add 0-30 min random delay
        };

        oidc.providers.github = {
          issuer = "https://token.actions.githubusercontent.com";
          audience = "https://${domain}";
          boundClaims = {
            repository_owner = [
              "zakuciael"
              "Wittano"
            ];
          };
        };
      };

      # Make sure the `niks3` service is run only after the Terraform configuration has been applied.
      systemd.services."niks3".after = [ config.systemd.services."terranix".name ];
    };
}
