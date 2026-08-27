{
  services.terranix.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        optionalString
        concatStringsSep
        getExe
        mapAttrs'
        attrValues
        ;
      cfg = config.services.terranix;

      waitForConfig = pkgs.writers.writeYAML ".wait-for.yaml" {
        targets =
          cfg.wait.resources
          |> mapAttrs' (
            _: target: {
              inherit (target) name;
              value = {
                inherit (target) type target timeout;
                http-client-status-pattern = target.httpStatusPattern;
                http-client-timeout = target.httpClientTimeout;
              };
            }
          );
      };
    in
    {
      systemd.services = {
        "terranix-wait-online" = {
          after = [ "network.target" ];
          before = [ config.systemd.services."terranix".name ];
          bindsTo = [ config.systemd.services."terranix".name ];

          serviceConfig = {
            Type = "oneshot";
            ExecStart = ''
              ${getExe pkgs.wait-for} \
                --config ${waitForConfig} \
                ${optionalString (cfg.wait.resources != { }) (
                  cfg.wait.resources |> attrValues |> map (target: target.name) |> concatStringsSep " "
                )}
            '';
          };
        };

        "terranix" = {
          after = [ config.systemd.services."terranix-wait-online".name ] ++ cfg.wait.services;
          requires = [ config.systemd.services."terranix-wait-online".name ] ++ cfg.wait.services;
          restartTriggers = [ waitForConfig ];
        };
      };
    };
}
