{
  inputs,
  ...
}:
{
  flake-file.inputs.niks3 = {
    url = "github:Mic92/niks3";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      treefmt-nix.follows = "treefmt-nix";
    };
  };

  services.niks3.nixos =
    {
      host,
      config,
      lib,
      ...
    }:
    let
      inherit (host.constants.services.niks3) domain port s3;
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

        apiTokenFile = config.clan.core.vars.generators.niks3-api-token.files.token.path;
        signKeyFiles = [ config.clan.core.vars.generators.niks3-signing-key.files.key.path ];

        s3 = {
          inherit (s3) endpoint;
          bucket = s3.bucket_name;
          region = "auto";

          useSSL = true;

          accessKeyFile = config.clan.core.vars.generators.niks3-s3.files."access-key".path;
          secretKeyFile = config.clan.core.vars.generators.niks3-s3.files."secret-key".path;
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
    };
}
