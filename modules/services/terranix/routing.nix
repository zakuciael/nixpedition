{
  den,
  lib,
  inputs,
  ...
}:
let
  inherit (den.lib) policy;
  inherit (lib) evalModules mkOption types;
  inherit (import ./_types.nix { inherit lib inputs; }) globalModule mkLocalOption;

  # den.quirks inject collision-validator modules that assign `warnings`
  # (and may use `assertions`). NixOS defines these; our private
  # evalModules scaffolds must too or quirk-consuming terranix modules fail.
  denCompatOptions = {
    options = {
      warnings = mkOption {
        type = types.listOf types.str;
        default = [ ];
        internal = true;
      };
      assertions = mkOption {
        type = types.listOf types.unspecified;
        default = [ ];
        internal = true;
      };
    };
  };

  # When collecting `.global` only, keep `.local` deferred so modules that
  # close over the host `nixos` config are not forced during flake instantiation.
  evalGlobal =
    modules:
    (evalModules {
      modules = modules ++ [
        denCompatOptions
        {
          options = {
            global = globalModule;
            local = mkOption {
              type = types.deferredModule;
              default = { };
            };
          };
        }
      ];
    }).config.global;

  # Evaluate `.local` with `localModule`'s declarations so assignments are
  # type-checked. Host NixOS config is `nixos` (`config` is reserved).
  evalLocal =
    {
      pkgs,
      osConfig,
      modules,
    }:
    (evalModules {
      specialArgs = { inherit pkgs osConfig; };
      modules = modules ++ [
        denCompatOptions
        {
          options = {
            global = globalModule;
            local = mkLocalOption pkgs { inherit pkgs osConfig; };
          };
        }
      ];
    }).config.local;

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

      guard = { options, ... }: options.services ? terranix;
      adaptArgs = { pkgs, config, ... }: {
        inherit pkgs;
        osConfig = config;
      };
      mapModule =
        _item: sourceModule:
        { pkgs, osConfig, ... }:
        {
          config = evalLocal {
            inherit pkgs osConfig;
            modules = sourceModule.imports;
          };
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
          instantiate = { modules, ... }: evalGlobal modules;
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
