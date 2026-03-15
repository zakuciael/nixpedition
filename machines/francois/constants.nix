{
  den.aspects.francois.nixos = {
    _module.args.constants = {
      # The default host address for all containers.
      containers = {
        hostAddress = "10.0.0.1";
        hostAddress6 = "fc00::1";
      };

      services = {
        zitadel = {
          version = "4.13.0";
          ports = {
            api = 8080;
            login = 3000;
          };
          dataDir = "/var/lib/zitadel";
          domain = "sso.zakku.eu";
        };
      };
    };
  };
}
