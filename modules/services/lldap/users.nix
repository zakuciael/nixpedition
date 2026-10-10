{ den, lib, ... }: {
  den = {
    schema = {
      host.includes = [ den.aspects.lldap-users ];

      user =
        { user, lib, ... }:
        let
          inherit (lib) mkOption types;
        in
        {
          options.lldap = {
            create = mkOption {
              description = "Whether to create an LDAP user";
              type = types.bool;
              default = false;
            };
            name = mkOption {
              description = "The name of the LDAP user";
              type = types.str;
              default = user.userName;
            };
            email = mkOption {
              description = "The email address of the LDAP user";
              type = types.str;
            };
            avatar = mkOption {
              description = "The path to the avatar of the LDAP user";
              type = types.nullOr types.path;
              default = null;
            };
            displayName = mkOption {
              description = "The display name of the LDAP user";
              type = types.nullOr types.str;
              default = null;
            };
            firstName = mkOption {
              description = "The first name of the LDAP user";
              type = types.nullOr types.str;
              default = null;
            };
            lastName = mkOption {
              description = "The last name of the LDAP user";
              type = types.nullOr types.str;
              default = null;
            };
            groups = mkOption {
              description = "A list of groups the the LDAP user will be a part of";
              type = types.listOf (
                types.submodule {
                  options = {
                    name = mkOption {
                      description = "The name of the LDAP group";
                      type = types.str;
                    };
                    custom = mkOption {
                      description = "Whether the group is custom made or a default one";
                      type = types.bool;
                      default = false;
                    };
                  };
                }
              );
              default = [ ];
            };
          };
        };
    };

    aspects.lldap-users =
      { host, ... }:
      let
        inherit (lib) filterAttrs mapAttrs';
      in
      {
        lldap = {
          users =
            host.users
            |> filterAttrs (_: cfg: cfg.lldap.create or false)
            |> mapAttrs' (
              _: { lldap, ... }: {
                inherit (lldap) name;
                value = {
                  inherit (lldap) email avatar groups;
                  username = lldap.name;
                  display_name = lldap.displayName;
                  last_name = lldap.lastName;
                  first_name = lldap.firstName;
                  passwordType = "prompt";
                };
              }
            );
        };
      };
  };
}
