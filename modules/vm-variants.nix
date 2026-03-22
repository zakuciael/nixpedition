{ inputs, ... }:
{
  den.default.nixos =
    {
      lib,
      config,
      pkgs,
      extendModules,
      ...
    }:
    let
      vmModule = import "${inputs.clan-core}/nixosModules/clanCore/vm-base.nix";
      vmVariant = extendModules { modules = [ vmModule ]; };

      vmConfig = config.virtualisation.vmVariant;
    in
    {
      disabledModules = [ "${inputs.nixpkgs}/nixos/modules/virtualisation/build-vm.nix" ];

      options = {
        virtualisation.vmVariant = lib.mkOption {
          inherit (vmVariant) type;
          default = { };
          visible = "shallow";
        };
      };

      # Modify the clan VM config to utilize the NixOS `virtualisation.vmVariant` option
      config = {
        system = {
          build.vm = lib.mkDefault vmConfig.system.build.vm;
          clan.vm = lib.mkForce {
            create = pkgs.writeText "vm.json" (
              builtins.toJSON {
                initrd = "${vmConfig.system.build.initialRamdisk}/${vmConfig.system.boot.loader.initrdFile}";
                toplevel = vmConfig.system.build.toplevel;
                regInfo = (pkgs.closureInfo { rootPaths = vmConfig.virtualisation.additionalPaths; });
                inherit (config.clan.virtualisation)
                  memorySize
                  cores
                  graphics
                  waypipe
                  ;
              }
            );
          };
        };
      };
    };
}
