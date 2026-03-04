let
  user-password-secrets =
    { user, ... }:
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
in
{
  den.ctx.user.includes = [
    user-password-secrets
  ];

  den.ctx.host.includes = [
    (
      { host }:
      user-password-secrets {
        inherit host;
        user = {
          userName = "root";
        };
      }
    )
  ];

  # Ensure users are immutable (otherwise the config might be ignored)
  den.default.nixos.users.mutableUsers = false;
}
