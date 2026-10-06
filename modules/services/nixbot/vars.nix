{
  services.nixbot.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib)
        mapAttrs
        mapAttrs'
        removePrefix
        replaceStrings
        ;

      effectsTemplateName =
        repo: "nixbot-effects-${replaceStrings [ "/" ] [ "-" ] (removePrefix "github:" repo)}";

      git-author =
        let
          username = config.clan.core.vars.generators.nixbot-constants.files."github.app_user_name".value;
          app_id = config.clan.core.vars.generators.nixbot-constants.files."github.app_user_id".value;
        in
        {
          kind = "Secret";
          data = {
            inherit username;
            email = "${app_id}+${username}@users.noreply.github.com";
          };
        };

      sharedEffectsSecrets = {
        inherit git-author;
      };

      mkEffectsSecrets = extras: sharedEffectsSecrets // extras;

      effectRepos = {
        "github:zakuciael/nixpedition" = mkEffectsSecrets {
          "ci-ssh-keys" = {
            kind = "Secret";
            data = {
              privateKey = config.sops.placeholder."vars/ci-ssh-keys/private-key-json";
              publicKey = config.clan.core.vars.generators.ci-ssh-keys.files.authorized-key.value;
            };
          };
          "ci-age-key" = {
            kind = "Secret";
            data = {
              privateKey = config.sops.placeholder."vars/ci-age-key/private-key";
              publicKey = config.clan.core.vars.generators.ci-age-key.files.public-key.value;
            };
          };
        };
        "github:zakuciael/nixos-dotfiles" = mkEffectsSecrets { };
      };
    in
    {
      clan.core.vars.generators = {
        "nixbot-constants" = {
          files =
            [
              "port"
              "domain"
              "eval.worker_count"
              "eval.memory_limit"
              "build.concurrency"
              "build.systems"
              "github.app_id"
              "github.oauth_id"
              "github.app_user_name"
              "github.app_user_id"
            ]
            |> map (name: {
              inherit name;
              value = {
                secret = false;
              };
            })
            |> lib.listToAttrs;

          prompts = {
            port = {
              description = "Port for the nixbot server";
              type = "line";
              persist = true;
            };
            domain = {
              description = "Domain for the nixbot server";
              type = "line";
              persist = true;
            };
            "eval.worker_count" = {
              description = "Number of eval workers for nixbot server";
              type = "line";
              persist = true;
            };
            "eval.memory_limit" = {
              description = "Eval worker's memory limit for nixbot server";
              type = "line";
              persist = true;
            };
            "build.concurrency" = {
              description = "Number of concurrent builds for nixbot server";
              type = "line";
              persist = true;
            };
            "build.systems" = {
              description = "A comma-separated list of build systems for nixbot server";
              type = "line";
              persist = true;
            };
            "github.app_id" = {
              description = "GitHub App Id for nixbot server";
              type = "line";
              persist = true;
            };
            "github.oauth_id" = {
              description = "GitHub OAuth Id for nixbot server";
              type = "line";
              persist = true;
            };
            "github.app_user_name" = {
              description = "GitHub App Username for nixbot server";
              type = "line";
              persist = true;
            };
            "github.app_user_id" = {
              description = "GitHub App User Id for nixbot server";
              type = "line";
              persist = true;
            };
          };
        };

        "nixbot-webhook-secret" = {
          files."secret" = {
            secret = true;
          };

          script = /* bash */ ''
            openssl rand -base64 32 > $out/secret
          '';

          runtimeInputs = [
            pkgs.openssl
          ];
        };
        "nixbot-github-oauth-secret" = {
          files."secret" = {
            secret = true;
          };
          prompts."secret" = {
            description = "NixBot's GitHub App OAuth Secret";
            type = "hidden";
            persist = true;
          };
        };
        "nixbot-github-app-private-key" = {
          files."private_key" = {
            secret = true;
          };
          prompts."private_key" = {
            description = "NixBot's GitHub App Private Key";
            type = "hidden";
            persist = true;
          };
        };
        "nixbot-access-tokens" = {
          files."nix.conf" = {
            secret = true;
            group = "nixbot";
            mode = "0440";
          };
          prompts."tokens" = {
            description = "nix access-tokens for private flake inputs (host=token …)";
            type = "hidden";
            persist = true;
          };
          script = /* bash */ ''
            echo "access-tokens = $(cat "$prompts/tokens")" > "$out/nix.conf"
          '';
        };
      };

      sops.templates = mapAttrs' (repo: secrets: {
        name = effectsTemplateName repo;
        value.file = pkgs.writers.writeJSON "${effectsTemplateName repo}.json" secrets;
      }) effectRepos;

      services.nixbot.effects.perRepoSecretFiles = mapAttrs (
        repo: _: config.sops.templates.${effectsTemplateName repo}.path
      ) effectRepos;
    };
}
