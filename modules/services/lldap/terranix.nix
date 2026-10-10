{ lib, ... }: {
  services.lldap = {
    terranix =
      { host, ... }:
      let
        inherit (lib) concatStringsSep;
        inherit (host.constants.services.lldap)
          http_port
          ldap_port
          admin_dn
          base_dn
          ;
      in
      {
        local = { osConfig, ... }: {
          envs."LLDAP_PASSWORD".value = osConfig.sops.placeholder."vars/lldap-admin-password/password";

          wait = {
            services = [ "lldap.service" ];
            resources."lldap" = {
              type = "http";
              target = "http://localhost:${toString http_port}";
              timeout = "30s";
            };
          };

          configuration = {
            terraform.required_providers.lldap = {
              source = "tasansga/lldap";
              version = "0.4.2";
            };

            provider."lldap" = {
              http_url = "http://localhost:${toString http_port}";
              ldap_url = "ldap://localhost:${toString ldap_port}";
              username = if builtins.isString admin_dn then admin_dn else concatStringsSep "," admin_dn;
              base_dn = concatStringsSep "," base_dn;
            };

            data.lldap_groups."groups" = { };
          };
        };
      };
  };
}
