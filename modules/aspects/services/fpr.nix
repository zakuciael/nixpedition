{
  # deadnix: skip
  __findFile ? __findFile
, ...
}:
{
  den.aspects.services.provides.frp = {
    nixos = rec {
      services = {
        frp = {
          enable = true;
          settings = {
            bindPort = 7000;
            auth.method = "token";
            auth.tokenSource.type = "file";
            auth.tokenSource.file.path = "/etc/frp-auth-token";
          };
          role = "server";
        };
      };

      networking.firewall = {
        allowedTCPPorts = [
          services.frp.settings.bindPort
          25565 # Minecraft server
          1500 # Piravet custom port
        ];
      };
    };
  };
}
