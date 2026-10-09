{
  den.default.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        genAttrs
        mkIf
        mkOption
        types
        ;
      cfg = config.clan.core.deployment;
    in
    {
      options.clan.core.deployment = {
        deferRestart = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "sshd" ];
          description = ''
            Systemd service names (without `.service`) that must not be
            restarted by `switch-to-configuration` during a deploy.

            Use this for services that run the deploy effect itself, or
            whose bounce would abort remote activation (e.g. sshd). The
            deploy effect holds a host flock for its lifetime and schedules
            a `systemctl try-restart` that runs only after that flock is
            released (effect sandbox gone).

            Multiple modules may append; duplicates are removed.
          '';
          apply = lib.unique;
        };
      };

      config = mkIf (cfg.deferRestart != [ ]) {
        environment.systemPackages = [ pkgs.clan-defer-restart ];

        systemd.tmpfiles.rules = [
          "d /run/clan-defer-restart 0755 root root -"
        ];

        systemd.services = genAttrs cfg.deferRestart (_: {
          restartIfChanged = false;
        });
      };
    };
}
