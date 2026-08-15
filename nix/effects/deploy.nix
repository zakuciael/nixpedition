{
  hci-effects =
    {
      config,
      hci-effects,
      ...
    }:
    let
      NIX_CONFIG = "experimental-features = nix-command flakes pipe-operators";
    in
    {
      jobs = {
        deploy = {
          on.push = config.repo.branch == "main";

          steps = {
            default = hci-effects.mkEffect {
              name = "deploy";
              lock = "production";

              checkout = true;

              # Envs
              inherit NIX_CONFIG;

              # Secrets
              secretsMap = {
                "ssh" = "ci-ssh-keys";
                "age" = "ci-age-key";
              };

              # State
              knownHostsName = "deploy.known_hosts";

              getStateScript = ''
                mkdir -p ~/.ssh
                getStateFile "$knownHostsName" ~/.ssh/known_hosts
                touch ~/.ssh/known_hosts
              '';
              putStateScript = ''
                putStateFile "$knownHostsName" ~/.ssh/known_hosts
              '';

              userSetupScript = /* bash */ ''
                writeAgeKey
                writeSSHKey
              '';

              effectScript = /* bash */ ''
                clan machines update \
                  --host-key-check accept-new
              '';
            };
          };
        };
      };
    };
}
