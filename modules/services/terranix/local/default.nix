{ inputs, ... }:
{
  services.terranix.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../_types.nix { inherit lib inputs; }) localModule;
      cfg = config.services.terranix;
    in
    {
      options.services.terranix = localModule pkgs;

      config.systemd.services.terranix = {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        environment = {
          TF_LOG = "debug";
          TF_INPUT = "false"; # Disable user input
        };

        restartTriggers = [ "${cfg.workdir}/config.tf.json" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe cfg.result.scripts.apply}";
        };
      };
    };
}
