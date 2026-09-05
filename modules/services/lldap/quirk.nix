{ lib, ... }:
{
  den.quirks.lldap = {
    description = "LLDAP server dynamic configuration";
  };

  services.lldap =
    let
      mkPasswordGeneratorName = user_name: "lldap-user-${user_name}-password";
      mergeQuirk = lib.foldl lib.recursiveUpdate { };
    in
    {
      nixos =
        { lldap, ... }:
        let
          cfg = mergeQuirk lldap;
        in
        {
          clan.core.vars.generators =
            cfg.users or { }
            |> lib.mapAttrs' (
              name: userCfg: {
                name = mkPasswordGeneratorName name;
                value =
                  let
                    passwordType = userCfg.passwordType or "generate";
                  in
                  assert lib.assertMsg
                    (builtins.elem passwordType [
                      "prompt"
                      "generate"
                    ])
                    ''lldap.users."${name}".passwordType can be set to either "prompt" or "generate", but received "${passwordType}".'';
                  if (passwordType == "prompt") then
                    {
                      files."password".secret = true;
                      prompts."password" = {
                        description = "Password for the ${name} LDAP user";
                        persist = true;
                        type = "hidden";
                      };
                    }
                  else
                    {
                      files."password".secret = true;

                      script = /* bash */ ''
                        tr -dc 'A-Za-z0-9~_-' < /dev/urandom | head -c 20 > $out/password || true
                      '';
                    };
              }
            );
        };

      terranix =
        { lldap, ... }:
        let
          cfg = mergeQuirk lldap;
        in
        {
          local =
            { osConfig, ... }:
            {
              variables =
                cfg.users or { }
                |> lib.mapAttrs' (
                  name: _: {
                    name = mkPasswordGeneratorName name;
                    value = {
                      type = "string";
                      secret = true;
                      value = osConfig.sops.placeholder."vars/${mkPasswordGeneratorName name}/password";
                    };
                  }
                );

              configuration =
                { lib, ... }:
                let
                  findGroupIdByDisplayName =
                    display_name:
                    lib.tf.ref ''[for g in data.lldap_groups.groups.groups : g.id if g.display_name == "${display_name}"][0]'';
                in
                {
                  resource = {
                    lldap_user =
                      cfg.users or { }
                      |> lib.mapAttrs (
                        name: userCfg: {
                          inherit (userCfg) username email;

                          display_name = userCfg.display_name or "";
                          last_name = userCfg.last_name or "";
                          first_name = userCfg.first_name or "";
                          avatar =
                            if (userCfg.avatar or null) != null then (lib.tf.ref ''filebase64("${userCfg.avatar}")'') else "";

                          password = lib.tf.ref "var.${mkPasswordGeneratorName name}";
                        }
                      );

                    lldap_group =
                      cfg.groups or { }
                      |> lib.mapAttrs (
                        _: groupCfg: {
                          inherit (groupCfg) display_name;
                        }
                      );

                    lldap_member =
                      cfg.users
                      |> lib.attrsToList
                      |> map (
                        { name, value }:
                        (value.groups or [ ])
                        |> map (group: {
                          name = "${name}-${group.name}";
                          value = {
                            user_id = lib.tf.ref "lldap_user.${name}.id";
                            group_id =
                              if (group.custom or false) then
                                (lib.tf.ref "lldap_group.${group.name}.id")
                              else
                                (findGroupIdByDisplayName group.name);
                          };
                        })
                        |> lib.listToAttrs
                      )
                      |> lib.foldl lib.recursiveUpdate { };
                  };
                };
            };
        };
    };
}
