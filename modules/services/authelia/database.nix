{
  services.authelia.nixos = {
    services = {
      authelia.instances."".settings.storage.postgres = {
        address = "unix:///run/postgresql";
        database = "authelia";
        username = "authelia";
      };
      postgresql = {
        enable = true;
        ensureDatabases = [ "authelia" ];
        ensureUsers = [
          {
            name = "authelia";
            ensureDBOwnership = true;
          }
        ];
      };
    };
  };
}
