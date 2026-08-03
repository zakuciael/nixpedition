{
  services.terranix.nixos =
    { config, lib, ... }:
    let
      inherit (lib)
        mkIf
        attrsToList
        concatLines
        toShellVar
        ;

      cfg = config.services.terranix;
    in
    {
      sops.templates = {
        "terranix/envs" = mkIf (cfg.envs != { }) {
          content =
            cfg.envs
            |> attrsToList
            |> map ({ value, ... }: toShellVar value.name value.value)
            |> concatLines;
        };
      };

      systemd.services."terranix".serviceConfig.EnvironmentFile = mkIf (
        cfg.envs != { }
      ) config.sops.templates."terranix/envs".path;
    };
}
