{
  virtualisation.containers.nixos =
    {
      options,
      config,
      lib,
      constants,
      ...
    }:
    let
      inherit (lib)
        mkDefault
        mkOption
        mkMerge
        mkIf
        types
        mapAttrs
        attrValues
        flatten
        filter
        foldl'
        lists
        recursiveUpdate
        concatStringsSep
        ;

      lazyAttrsOfSubmodule = options: types.lazyAttrsOf (types.submodule { inherit options; });
      filterBindsWithUsers = binds: binds |> filter (v: v ? user);
      filterUniqueUsers =
        binds:
        binds
        |> foldl' (
          acc: bind:
          if acc |> lists.any (item: item.user.name == bind.user.name) then acc else acc ++ [ bind ]
        ) [ ];
      bindsToUsersCfg =
        binds:
        binds
        |> map (bind: {
          users."${bind.user.name}" = {
            isSystemUser = true;
            name = bind.user.name;
            uid = bind.user.uid;
            group = bind.user.name;
          };
          groups."${bind.user.name}".gid = bind.user.gid;
        })
        |> foldl' (acc: cfg: recursiveUpdate acc cfg) { };

      containerOpts = options.containers.type.getSubOptions "";
      allBindsWithUsers =
        config.containers-utils
        |> attrValues
        |> map (v: v.binds)
        |> map attrValues
        |> flatten
        |> filterBindsWithUsers;
    in
    {
      options.containers-utils = mkOption {
        description = "A set of utility options for defining NixOS Containers.";
        default = { };
        type = lazyAttrsOfSubmodule {
          privateNetwork = mkOption {
            description = "This enables the `containers.<name>.privateNetwork` option and apply additional options.";
            type = types.bool;
            default = false;
          };
          binds = mkOption {
            description = "Define container binds that automatically create the required paths on the host system.";
            default = { };
            type = lazyAttrsOfSubmodule {
              hostPath = mkOption { type = types.str; };
              mountPoint = mkOption { type = types.str; };
              isReadOnly = mkOption {
                type = types.bool;
                default = true;
              };
              user = mkOption {
                default = null;
                type = types.nullOr (
                  types.submodule {
                    options = {
                      name = mkOption { type = types.str; };
                      uid = mkOption { type = types.int; };
                      gid = mkOption { type = types.int; };
                    };
                  }
                );
              };
            };
          };
        };
      };

      config = {
        # Create users for bind mounts of all containers
        users = allBindsWithUsers |> filterUniqueUsers |> bindsToUsersCfg;

        # Create bind mounts directories for all containers
        system.activationScripts."create-container-bind-mounts-dirs" =
          allBindsWithUsers
          |> map (bind: ''
            mkdir -p ${bind.hostPath}
            chown ${toString bind.user.uid}:${toString bind.user.gid} ${bind.hostPath}
            chmod 750 ${bind.hostPath}
          '')
          |> concatStringsSep "\n";

        containers =
          config.containers-utils
          |> mapAttrs (
            name: cfg: {
              # Add bind mounts to the corresponding container
              bindMounts =
                cfg.binds
                |> mapAttrs (
                  _: bind: {
                    inherit (bind) mountPoint hostPath isReadOnly;
                  }
                );

              privateNetwork = cfg.privateNetwork;
              hostAddress = mkDefault (
                if cfg.privateNetwork then constants.containers.hostAddress else containerOpts.hostAddress.value
              );
              hostAddress6 = mkDefault (
                if cfg.privateNetwork then constants.containers.hostAddress6 else containerOpts.hostAddress6.value
              );

              config = mkMerge [
                {
                  # Create users required for all the bind mounts
                  users = cfg.binds |> attrValues |> filterBindsWithUsers |> filterUniqueUsers |> bindsToUsersCfg;
                }
                (mkIf cfg.privateNetwork {
                  # Use systemd-resolved inside the container
                  # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
                  networking.useHostResolvConf = lib.mkForce false;
                  services.resolved.enable = true;
                })
              ];
            }
          );
      };
    };
}
