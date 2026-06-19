{
  inputs,
  den,
  ...
}:
{
  imports = [
    inputs.den.flakeModule

    # Import all non-clan files in the `machines/<host>` directory as flake-modules.
    (inputs.import-tree.matchNot ".*/(disko|configuration|hardware-configuration)\.nix" ../machines)
  ];

  flake-file.inputs = {
    den.url = "github:vic/den/v0.17.0";
    flake-aspects.url = "github:vic/flake-aspects/v0.7.0";
  };

  # Modify how hosts are instantiated so that it desn't collide with clan
  den.schema.host =
    { host, ... }:
    {
      instantiate = args: { imports = args.modules; };
      intoAttr = [
        "clan"
        "machines"
        host.name
      ];
    };

  # Enable the angle-brackets support
  _module.args.__findFile = den.lib.__findFile;
}
