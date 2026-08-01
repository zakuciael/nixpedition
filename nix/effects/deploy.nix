{
  self,
  config,
  withSystem,
  ...
}:
let
  flakeConfig = config;
in
{
  herculesCI =
    { config, ... }:
    {
      onPush.default.outputs = {
        effects.deploy = withSystem flakeConfig.defaultEffectSystem (
          {
            hci-effects,
            pkgs,
            inputs',
            ...
          }:
          hci-effects.runIf (config.repo.branch == "main") (
            hci-effects.mkEffect {
              name = "deploy";
              lock = "production";

              inputs = [
                inputs'.clan-core.packages.clan-cli
                pkgs.openssh
              ];

              src = self;

              secretsMap = {
                "ssh" = "ci-ssh-keys";
                "age-key" = "ci-age-key";
              };

              userSetupScript = ''
                # Read Age Key from `age-key` secret and write it to ~/.config/sops/age/keys.txt file
                mkdir -p ~/.config/sops/age/
                readSecretString "age-key" ".privateKey" > ~/.config/sops/age/keys.txt

                # Read SSH key from `ssh` secret and write it to ~/.ssh directory
                writeSSHKey
              '';

              effectScript = ''
                clan machines update \
                  --option extra-experimental-features 'nix-command flakes pipe-operators' \
                  --host-key-check accept-new
              '';
            }
          )
        );
      };
    };
}
