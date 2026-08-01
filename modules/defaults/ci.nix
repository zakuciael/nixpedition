{
  den,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  den.default.nixos =
    {
      host,
      config,
      pkgs,
      lib,
      ...
    }:
    {
      clan.core.vars.generators = {
        "ci-ssh-keys" = {
          share = true;

          files = {
            "authorized-key".secret = false;
            "private-key".secret = true;
            "private-key-json".secret = true;
          };

          runtimeInputs = [
            pkgs.openssh
          ];

          script = ''
            ssh-keygen -q -t ed25519 -N "" -C "" -f $out/private-key
            mv $out/private-key.pub $out/authorized-key
            cat $out/private-key | sed 's/$/\\\n/g' | tr -d '\n' > $out/private-key-json
          '';
        };
        "ci-age-key" = {
          share = true;

          files = {
            "public-key".secret = false;
            "private-key".secret = true;
          };

          runtimeInputs = [
            pkgs.age
          ];

          script = ''
            age-keygen -o $out/private-key
            age-keygen -y $out/private-key > $out/public-key
          '';
        };
      };

      users.users."root".openssh.authorizedKeys.keyFiles = [
        config.clan.core.vars.generators."ci-ssh-keys".files.authorized-key.path
      ];

      clan.core = {
        sops.defaultGroups = [ "ci" ];
        networking = {
          # buildHost = "localhost";
          targetHost = lib.mkDefault host.hostName;
        };
      };
    };
}
