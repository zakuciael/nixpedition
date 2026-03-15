{
  services.frp.nixos =
    { config, pkgs, ... }:
    {
      clan.core.vars.generators."frp-auth-token" = {
        files."token" = {
          secret = true;
          restartUnits = [ "frp.service" ];
        };

        script = /* bash */ ''
          dd if=/dev/urandom bs=512 count=1 2>/dev/null | base64 -i -w 0 > $out/token
        '';
        runtimeInputs = [ pkgs.coreutils ];
      };

      services = {
        frp = {
          enable = true;
          settings = {
            bindPort = 7000;
            auth = {
              method = "token";
              tokenSource = {
                type = "file";
                file.path = "{{ .Envs.CREDENTIALS_DIRECTORY }}/frp-auth-token";
              };
            };
          };
          role = "server";
        };
      };

      systemd.services."frp".serviceConfig = {
        LoadCredential = "frp-auth-token:${
          config.clan.core.vars.generators."frp-auth-token".files.token.path
        }";
      };

      networking.firewall = {
        allowedTCPPorts = [
          config.services.frp.settings.bindPort
          25565 # Minecraft server
          1500 # Piravet custom port
        ];
      };
    };
}
