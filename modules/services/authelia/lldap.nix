{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  services.authelia = {
    includes = [
      <services/lldap>
    ];

    nixos =
      {
        host,
        config,
        lib,
        ...
      }:
      let
        inherit (host.constants.services.lldap) base_dn ldap_port;
      in
      {
        # Make sure the `authelia` LLDAP user password can be accessed by Authelia.
        clan.core.vars.generators."lldap-user-authelia-password".files.password = {
          owner = "authelia";
          group = "authelia";
        };

        services.authelia.instances."" = {
          settings.authentication_backend.ldap = {
            implementation = "lldap";
            address = "ldap://localhost:${toString ldap_port}";
            base_dn = lib.concatStringsSep "," base_dn;
            user = lib.concatStringsSep "," (
              [
                "uid=authelia"
                "ou=people"
              ]
              ++ base_dn
            );
          };

          environmentVariables =
            let
              inherit (config.clan.core.vars) generators;
            in
            {
              AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE =
                generators."lldap-user-authelia-password".files.password.path;
            };
        };
      };

    lldap =
      { host, ... }:
      let
        inherit (host.constants.services.authelia) root_domain;
      in
      {
        users.authelia = {
          username = "authelia";
          email = "authelia@${root_domain}";
          display_name = "Authelia";
          groups = [
            {
              name = "lldap_password_manager";
              custom = false;
            }
          ];
        };
      };
  };
}
