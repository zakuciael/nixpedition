{ inputs, ... }:
{
  flake-file.inputs.nixbot = {
    url = "github:Mic92/nixbot";
    inputs = {
      # nixpkgs.follows = "nixpkgs";
      treefmt-nix.follows = "treefmt-nix";
    };
  };

  services.nixbot.nixos =
    {
      config,
      lib,
      pkgs,
      inputs',
      constants,
      ...
    }:
    let
      inherit (constants.services.nixbot) domain;
      inherit (constants.services.nixbot.github) oauthId appId;
    in
    {
      # TODO: Configure this sevice in a NixOS container
      # TODO: Figure out how to fix the build fail for `nixbot` package when overriding `nixpkgs`

      imports = [ inputs.nixbot.nixosModules.nixbot ];

      nix.settings.trusted-users = [ "nixbot" ];

      services.nixbot = {
        enable = true;
        inherit domain;
        useHTTPS = true;

        packages = { inherit (inputs'.nixbot.packages) nixbot; };

        # Users in this list are allowed to trigger builds and change settings.
        admins = [
          "github:zakuciael"
          "github:Wittano"
        ];

        # Disable nginx since it's enabled when using `useHTTPS` option
        nginx.enable = false;

        github = {
          enable = true;

          # GitHub App configuration.
          inherit appId;
          appSecretKeyFile =
            config.clan.core.vars.generators.nixbot-github-app-private-key.files.private_key.path;

          # The webhook secret configured in the GitHub App settings.
          webhookSecretFile = config.clan.core.vars.generators.nixbot-webhook-secret.files.secret.path;
          #  OAuth credentials for the login button (from the same GitHub App).
          inherit oauthId;
          oauthSecretFile = config.clan.core.vars.generators.nixbot-github-oauth-secret.files.secret.path;

          # All repositories with this topic will be built.
          topic = "nixbot";
        };

        niks3 = {
          enable = true;
          serverUrl = "https://${constants.services.binary-cache.domain}";
          package = inputs'.niks3.packages.default;

          authTokenFile = config.clan.core.vars.generators.binary-cache-api-token.files.token.path;
        };
      };
    };
}
