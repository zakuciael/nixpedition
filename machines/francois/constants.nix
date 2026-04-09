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
          port = 8080;
          dataDir = "/var/lib/zitadel";
          containerAddress = "10.0.0.2";
          containerAddress6 = "fc00::2";
          domain = "sso.zakku.eu";
          user = {
            uid = 328;
            gid = 328;
            name = "zitadel";
          };
        };
      };
    };
  };
}
