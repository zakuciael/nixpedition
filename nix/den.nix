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

    # Import the default flake-module from the `machines/**/default.nix` file.
    (inputs.import-tree.filter (lib.hasSuffix "default.nix") ../machines)
  ];

  options = {
    flake.test = lib.mkOption {
      type = lib.types.raw;
      default = { };
    };
  };

  config = {
    flake-file.inputs = {
      den.url = "github:vic/den?rev=3d9be07e0dbe1813f7e51352df3d86a8ece8ac12";
      flake-aspects.url = "github:vic/flake-aspects/v0.5.0";
    };

    # Enable the angle-brackets support
    _module.args.__findFile = den.lib.__findFile;

    # Integrate den's host configurations with clan
    flake.clan.machines = build osConfiguration config.den.hosts;

    # Generate home-manager standalone configurations from den's homes.
    flake.homeConfigurations = build homeConfiguration config.den.homes;
  };
}
