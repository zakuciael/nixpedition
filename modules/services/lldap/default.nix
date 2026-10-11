{ lib, ... }:
{
  services.lldap.nixos =
    { host, config, ... }:
    let
      inherit (lib) concatStringsSep;
      inherit (host.constants.services.lldap)
        http_port
        ldap_port
        base_dn
        admin_dn
        admin_email
        ;
    in
    {
      services.lldap = {
        enable = true;

        database = {
          type = "postgresql";
          createLocally = true;
        };

        settings = {
          inherit http_port ldap_port;

          key_file = "";
          ldap_base_dn = concatStringsSep "," base_dn;
          ldap_user_dn = if builtins.isString admin_dn then admin_dn else concatStringsSep "," admin_dn;
          ldap_user_email = admin_email;
          ldap_user_pass_file = config.clan.core.vars.generators.lldap-admin-password.files.password.path;
          force_ldap_user_pass_reset = "always";
        };

        environment = {
          LLDAP_JWT_SECRET_FILE = config.clan.core.vars.generators.lldap-jwt-secret.files.secret.path;
          LLDAP_KEY_SEED_FILE = config.clan.core.vars.generators.lldap-key-seed.files.seed.path;
        };
      };

      # DynamicUser screws up sops-nix ownership because
      # the user doesn't exist outside of runtime.
      systemd.services.lldap.serviceConfig.DynamicUser = lib.mkForce false;

      users = {
        users.lldap = {
          group = "lldap";
          isSystemUser = true;
        };
        groups.lldap = { };
      };
    };
}
