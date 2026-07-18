{
  services.terranix.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) mkOption types;
      cfg = config.services.terranix;

      waitTimeout = 300;
      waitInterval = 5;

      waitScript = pkgs.writeShellApplication {
        name = "wait-for-endpoints.sh";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          mkdir -p ${cfg.terraform.workdir}
          ln -sf ${cfg.result.endpointsFile} ${cfg.terraform.workdir}/wait-endpoints.conf

          ENDPOINTS_FILE="${cfg.terraform.workdir}/wait-endpoints.conf"
          TIMEOUT=${toString waitTimeout}
          INTERVAL=${toString waitInterval}
          elapsed=0

          while IFS= read -r url || [[ -n "$url" ]]; do
            # skip empty lines and comments
            [[ -z "$url" || "$url" == \#* ]] && continue

            echo "Waiting for $url..."
            while ! curl -sf --max-time 3 "$url" > /dev/null 2>&1; do
              if [ "$elapsed" -ge "$TIMEOUT" ]; then
                echo "Timeout waiting for $url"
                exit 1
              fi
              sleep "$INTERVAL"
              elapsed=$((elapsed + INTERVAL))
            done
            echo "$url is up."
          done < "$ENDPOINTS_FILE"

          echo "All services are ready."
        '';
      };
    in
    {
      options.services.terranix = {
        result = {
          waitScript = mkOption {
            readOnly = true;
            type = types.package;
            default = waitScript;
          };
          endpointsFile = mkOption {
            readOnly = true;
            type = types.package;
            default = pkgs.writeText "wait-endpoints.conf" cfg.wait.endpoints;
          };
        };

        wait = {
          services = mkOption {
            description = ''
              A list of systemd services that is required to start successfully before running terranix.
            '';
            type = types.listOf types.str;
            example = [ "zitadel.service" ];
            default = [ ];
          };
          endpoints = mkOption {
            description = ''
              A list of HTTP endpoints to check before running terranix.
            '';
            type = types.lines;
            example = ''
              http://zitadel:8080/debug/ready
            '';
            default = "";
          };
        };
      };

      config = {
        systemd.services = {
          "terranix-wait-online" = {
            after = [ "network.target" ];
            before = [ config.systemd.services."terranix".name ];
            bindsTo = [ config.systemd.services."terranix".name ];

            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe waitScript}";
              TimeoutStartSec = waitTimeout + 20;
            };
          };

          "terranix" = {
            after = [ config.systemd.services."terranix-wait-online".name ];
            requires = [ config.systemd.services."terranix-wait-online".name ];
            restartTriggers = [ "${cfg.terraform.workdir}/wait-endpoints.conf" ];
          };
        };
      };
    };
}
