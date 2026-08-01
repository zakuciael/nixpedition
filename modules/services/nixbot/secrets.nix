{
  services.nixbot.nixos =
    {
      config,
      pkgs,
      constants,
      ...
    }:
    {
      clan.core.vars.generators = {
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
