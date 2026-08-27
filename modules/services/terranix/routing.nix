{
  den,
  lib,
  inputs,
  withSystem,
  ...
}:
let
  inherit (den.lib) policy;
  inherit (lib) evalModules;
  inherit (import ./_types.nix { inherit lib inputs; }) globalModule localModule;

  containerModule =
    { pkgs, ... }:
    {
      options = {
        global = globalModule;
        local = localModule pkgs;
      };
    };

  evalContainer =
    { pkgs, modules }:
    (evalModules {
      modules = modules ++ [
        containerModule
        { _module.args = { inherit pkgs; }; }
      ];
    }).config;

  fwd =
    { host }:
    { aspect-chain, ... }:
    den.batteries.forward {
      each = [ true ];
      fromClass = _: "terranix";
      intoClass = _: host.class;
      intoPath = _: [
        "services"
        "terranix"
      ];
      fromAspect = _: lib.head aspect-chain;
      evalConfig = true;

      guard = { options, ... }: options.services ? terranix;
      adaptArgs = { pkgs, ... }: { inherit pkgs; };
      mapModule =
        _item: sourceModule:
        { pkgs, ... }:
        {
          config =
            (evalContainer {
              inherit pkgs;
              modules = sourceModule.imports;
            }).local;
        };
    };
in
{
  den = {
    classes.terranix = { };

    policies.host-to-terranix =
      { host, ... }:
      [
        (policy.instantiate {
          name = "${host.name}-tf";
          class = "terranix";
          instantiate =
            { modules, ... }:
            withSystem host.system (
              { pkgs, ... }:
              (evalContainer {
                inherit pkgs modules;
              }).global
            );
          intoAttr = [
            "terranixModules"
            host.name
          ];
        })
      ];

    schema.host.includes = [
      den.policies.host-to-terranix
      fwd
    ];
  };
}
