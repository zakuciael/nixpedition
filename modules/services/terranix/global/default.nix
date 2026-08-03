{
  config,
  lib,
  ...
}:
let
  inherit (lib) attrValues;
in
{
  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.nixpedition =
        let
          modules = (config.flake.terranixModules or { }) |> attrValues;
        in
        {
          inherit modules;
          terraformWrapper.package = pkgs.opentofu;
        };
    };
}
