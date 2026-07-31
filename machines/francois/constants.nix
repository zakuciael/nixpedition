{
  den.aspects.francois.nixos = {
    _module.args.constants = {
      # The default host address for all containers.
      containers = {
        hostAddress = "10.0.0.1";
        hostAddress6 = "fc00::1";
      };

      services = {
        binary-cache = {
          port = 5751;
          domain = "cache.zakku.eu";
        };
        nixbot = {
          port = 8010;
          domain = "ci.zakku.eu";
          settings = {
            eval = {
              worker_count = 6;
              memory_limit = 3072;
            };
            build = {
              concurrency = 6;
              systems = [
                "x86_64-linux"
                "aarch64-linux"
                "aarch64-darwin"
              ];
            };

            github = {
              appId = 4430921;
              oauthId = "Iv23liJZTjKA89uNvkRT";
            };
          };
        };
      };
    };
  };
}
