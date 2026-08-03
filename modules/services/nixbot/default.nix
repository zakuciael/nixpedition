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
      host,
      config,
      lib,
      inputs',
      ...
    }:
    let
      inherit (lib) mkIf;

      serviceCfgs = host.constants.services;
      inherit (serviceCfgs.nixbot)
        domain
        build
        eval
        github
        ;
    in
    {
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

        buildSystems = build.systems;
        buildConcurrency = build.concurrency;

        evalWorkerCount = eval.worker_count;
        evalMaxMemorySize = eval.memory_limit;

        github = {
          enable = true;

          # GitHub App configuration.
          appId = github.app_id;
          appSecretKeyFile =
            config.clan.core.vars.generators.nixbot-github-app-private-key.files.private_key.path;

          # The webhook secret configured in the GitHub App settings.
          webhookSecretFile = config.clan.core.vars.generators.nixbot-webhook-secret.files.secret.path;
          #  OAuth credentials for the login button (from the same GitHub App).
          oauthId = github.oauth_id;
          oauthSecretFile = config.clan.core.vars.generators.nixbot-github-oauth-secret.files.secret.path;

          # All repositories with this topic will be built.
          topic = "nixbot";
        };

        niks3 = mkIf config.services.niks3.enable (
          let
            inherit (serviceCfgs.niks3) domain;
            cfg = config.services.niks3;
          in
          {
            enable = true;
            serverUrl = "https://${domain}";
            package = inputs'.niks3.packages.default;
            authTokenFile = cfg.apiTokenFile;
          }
        );
      };
    };
}
