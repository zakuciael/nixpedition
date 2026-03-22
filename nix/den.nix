{
  lib,
  config,
  inputs,
  den,
  ...
}:
let
  build =
    builder: cfg:
    cfg
    |> lib.attrValues
    |> map lib.attrValues
    |> lib.flatten
    |> map (item: {
      inherit (item) name;
      value = builder item;
    })
    |> lib.listToAttrs;

  osConfiguration = host: {
    imports = [
      host.mainModule
      { nixpkgs.hostPlatform = lib.mkDefault host.system; }
    ];
  };

  homeConfiguration =
    home:
    home.instantiate {
      pkgs = home.pkgs;
      modules = [ home.mainModule ];
    };
in
{
  disabledModules = [
    # Fixes a conflict with `clan` in which both try to generate the `nixosConfigurations` option.
    # Might not be future-proof tho...
    "${inputs.den}/modules/config.nix"
  ];

  imports = [
    inputs.den.flakeModule

    # Import all non-clan files in the `machines/<host>` directory as flake-modules.
    (inputs.import-tree.matchNot ".*/(disko|configuration|hardware-configuration)\.nix" ../machines)
  ];

  options = {
    flake.test = lib.mkOption {
      type = lib.types.raw;
      default = { };
    };
  };

  config = {
    flake-file.inputs = {
      den.url = "github:vic/den?rev=ece9f9ec1647e82c96e4c21bb9c7060678e21d43";
      flake-aspects.url = "github:vic/flake-aspects/v0.7.0";
    };

    # Enable the angle-brackets support
    _module.args.__findFile = den.lib.__findFile;

    # Integrate den's host configurations with clan
    flake.clan.machines = build osConfiguration config.den.hosts;

    # Generate home-manager standalone configurations from den's homes.
    flake.homeConfigurations = build homeConfiguration config.den.homes;
  };
}
