{
  den.aspects.francois.nixos = {
    _module.args.constants = {
      # The default host address for all containers.
      containers = {
        hostAddress = "10.0.0.1";
        hostAddress6 = "fc00::1";
      };
    };
  };
}
