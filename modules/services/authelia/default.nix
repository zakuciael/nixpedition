{
  services.authelia.nixos =
    {
      host,
      config,
      lib,
      ...
    }:
    let
      inherit (lib) mkAfter;
      inherit (host.constants.services.authelia)
        domain
        root_domain
        access_control
        ;
    in
    {
      services = {
        authelia.instances."" = {
          enable = true;
          settings = {
            theme = "dark";
            log.level = "info";

            access_control = {
              default_policy = "deny";
              # We want this rule to be low priority so it doesn't override the others
              rules = mkAfter [
                access_control.default
              ];
            };

            session.cookies = [
              {
                domain = root_domain;
                authelia_url = "https://${domain}";
                default_redirection_url = "https://www.${root_domain}";
                # The period of time the user can be inactive for before the session is destroyed
                inactivity = "1M";
                # The period of time before the cookie expires and the session is destroyed
                expiration = "3M";
                # The period of time before the cookie expires and the session is destroyed
                # when the remember me box is checked
                remember_me = "1y";
              }
            ];

            # TODO: Configure SMTP to send 2FA registration messages.
            notifier = {
              disable_startup_check = false;
              filesystem.filename = "/var/lib/authelia/notification.txt";
            };

            webauthn.enable_passkey_login = true;
          };

          secrets =
            let
              inherit (config.clan.core.vars) generators;
            in
            {
              jwtSecretFile = generators."authelia-jwt-secret".files.secret.path;
              storageEncryptionKeyFile = generators."authelia-storage-encryption-key".files.key.path;
              sessionSecretFile = generators."authelia-session-secret".files.secret.path;

              # TODO: Figure out what does secrets do
              # oidcHmacSecretFile = "";
              # oidcIssuerPrivateKeyFile = "";
            };

          # TODO: Use when generating OIDC configuration
          settingsFiles = [ ];
        };
      };

      # TODO: Generate OIDC configuration from `den`'s quirks/classes

      # Setup service dependencies
      systemd.services.authelia =
        let
          dependencies = with config.systemd.services; [
            lldap.name
            redis-authelia.name
            postgresql.name
          ];
        in
        {
          after = dependencies ++ [ config.systemd.services.terranix.name ];
          requires = dependencies;
        };
    };
}
