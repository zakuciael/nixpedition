{
  services.nixbot.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:
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
      };

      sops.templates."nixbot-nixpedition-effects" = {
        file = pkgs.writers.writeJSON "nixpedition-effects.json" {
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
      };

      services.nixbot.effects.perRepoSecretFiles = {
        "github:zakuciael/nixpedition" = config.sops.templates."nixbot-nixpedition-effects".path;
      };
    };
}
