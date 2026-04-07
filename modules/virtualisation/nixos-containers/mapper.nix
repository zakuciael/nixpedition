{
  virtualisation.nixos-containers.provides.mapper.nixos =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib)
        mkIf
        mapAttrs
        attrValues
        flatten
        filter
        foldl'
        recursiveUpdate
        lists
        ;

      cfg = config.nixos-containers;

      allBinds = cfg.containers |> attrValues |> map (v: v.binds) |> map attrValues |> flatten;

      filterUniqueBindsByKey =
        key: binds:
        binds
        |> filter (bind: (bind."${key}" or null) != null)
        |> map (bind: bind."${key}")
        |> filterUnique (last: curr: last.name == curr.name);
      filterUnique =
        f: foldl' (acc: elem: if acc |> lists.any (curr: f elem curr) then acc else acc ++ [ elem ]) [ ];

      mkUserCfgFromBinds =
        binds:
        let
          users =
            binds
            |> filterUniqueBindsByKey "user"
            |> foldl' (
              acc: user:
              recursiveUpdate acc {
                "${user.name}" = {
                  inherit (user) name uid;
                  group = user.name;
                };
              }
            ) { };
          groups =
            binds
            |> filterUniqueBindsByKey "group"
            |> foldl' (
              acc: group:
              recursiveUpdate acc {
                "${group.name}" = {
                  inherit (group) name gid;
                };
              }
            ) { };
          userGroups = users |> lib.mapAttrs (name: _: { inherit name; });
        in
        {
          inherit users;
          groups = recursiveUpdate userGroups groups;
        };
      mkTmpfilesRule =
        bind:
        let
          type = if bind.type == "file" then "z" else "d";
          mode =
            if bind.type == "file" then
              (if bind.isReadOnly then "550" else "770")
            else
              (if bind.isReadOnly then "551" else "771");
          user = bind.user.name or "root";
          group = bind.group.name or "root";
        in
        # Type | Path | Mode | User | Group | Age | Argument
        "${type} ${bind.hostPath} ${mode} ${user} ${group} - -";
    in
    {
      containers =
        cfg.containers
        |> mapAttrs (
          name: containerDef:
          let
            allBinds = containerDef.binds |> attrValues;
          in
          {
            inherit (containerDef)
              specialArgs
              ephemeral
              autoStart
              restartIfChanged
              timeoutStartSec
              extraFlags
              privateNetwork
              privateUsers
              allowedDevices
              localAddress
              localAddress6
              forwardPorts
              ;
            inherit (cfg) hostAddress hostAddress6;

            # Re-map the bind mounts back to the container options.
            bindMounts =
              containerDef.binds
              |> mapAttrs (
                _: bind: {
                  inherit (bind) hostPath mountPoint isReadOnly;
                }
              );

            config = {
              imports = [
                cfg.defaultConfig
                containerDef.config

                {
                  # Set the state version to the same as the host system.
                  system.stateVersion = config.system.stateVersion;

                  # Use the hosts nixpkgs `config` and `overlays` in the container.
                  nixpkgs = {
                    inherit (config.nixpkgs) config overlays;
                  };

                  # Create users and groups used in the bind mounts
                  users = mkUserCfgFromBinds allBinds;
                }

                (mkIf containerDef.privateNetwork {
                  # Use systemd-resolved inside the container
                  # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
                  networking.useHostResolvConf = lib.mkForce false;
                  services.resolved.enable = true;
                })
              ];
            };
          }
        );

      # Create folders or update files used in the bind mounts
      systemd.tmpfiles.rules = allBinds |> map mkTmpfilesRule;

      # Create users and groups used in the bind mounts
      users = mkUserCfgFromBinds allBinds;
    };
}
