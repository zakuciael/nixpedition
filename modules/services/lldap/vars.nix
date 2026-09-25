{
  services.lldap.nixos =
    { config, pkgs, ... }:
    let
      lldapCfg = config.systemd.services.lldap.serviceConfig;
    in
    {
      clan.core.vars.generators = {
        lldap-constants = {
          files = {
            "domain".secret = false;
            "http_port".secret = false;
            "ldap_port".secret = false;
            "base_dn".secret = false;
            "admin_dn".secret = false;
            "admin_email".secret = false;
          };

          prompts = {
            "http_port" = {
              description = "HTTP port for the LLDAP server";
              persist = true;
              type = "line";
            };
            "ldap_port" = {
              description = "LDAP port for the LLDAP server";
              persist = true;
              type = "line";
            };
            "domain" = {
              description = "Domain for the LLDAP server";
              persist = true;
              type = "line";
            };
            "base_dn" = {
              description = "Base DN for the LLDAP server";
              persist = true;
              type = "line";
            };
            "admin_dn" = {
              description = "Admin DN for the LLDAP server";
              persist = true;
              type = "line";
            };
            "admin_email" = {
              description = "Admin email address for the LLDAP server";
              persist = true;
              type = "line";
            };
          };
        };

        lldap-admin-password = {
          files."password" = {
            secret = true;
            owner = lldapCfg.User;
            group = lldapCfg.Group;
          };

          script = /* bash */ ''
            tr -dc 'A-Za-z0-9~_-' < /dev/urandom | head -c 20 > $out/password || true
          '';
        };
        lldap-jwt-secret = {
          files."secret" = {
            secret = true;
            owner = lldapCfg.User;
            group = lldapCfg.Group;
          };

          script = /* bash */ ''
            openssl rand -hex -out $out/secret 64
          '';

          runtimeInputs = [
            pkgs.openssl
          ];
        };
        lldap-key-seed = {
          files."seed" = {
            secret = true;
            owner = lldapCfg.User;
            group = lldapCfg.Group;
          };

          script = /* bash */ ''
            openssl rand -base64 32 > $out/seed
          '';

          runtimeInputs = [
            pkgs.openssl
          ];
        };
      };
    };
}
