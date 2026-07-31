{
  den,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  den = {
    # Ensure users are immutable (otherwise the config might be ignored)
    default.nixos.users.mutableUsers = false;

    schema.host.includes = [
      den.aspects.user-secrets
      den.aspects.root-secrets
    ];

    aspects = {
      user-secrets =
        { user }:
        {
          nixos =
            { config, pkgs, ... }:
            {
              clan.core.vars.generators = {
                "${user.userName}-password" = {
                  prompts.password = {
                    description = "${user.userName}'s password";
                    type = "hidden";
                  };
                  files.hash.secret = false;

                  script = ''
                    mkpasswd -m sha-512 < $prompts/password > $out/hash
                  '';
                  runtimeInputs = [ pkgs.mkpasswd ];
                };

                "${user.userName}-authorized-key" = {
                  prompts = {
                    authorized-key = {
                      description = "${user.userName}'s SSH public key";
                      type = "line";
                      persist = true;
                    };
                  };
                  files."authorized-key".secret = false;
                };
              };

              users.users."${user.userName}" = {
                hashedPasswordFile = config.clan.core.vars.generators."${user.userName}-password".files.hash.path;
                openssh.authorizedKeys.keyFiles = [
                  config.clan.core.vars.generators."${user.userName}-authorized-key".files.authorized-key.path
                ];
              };
            };
        };

      root-secrets =
        let
          aspectModule = den.lib.aspects.resolve "nixos" (
            den.aspects.user-secrets { user.userName = "root"; }
          );
        in
        {
          nixos.imports = [ aspectModule ];
        };
    };
  };
}
