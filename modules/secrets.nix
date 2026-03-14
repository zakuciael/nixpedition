{
  flake.clan = {
    # Clan secret store settings
    vars.settings = {
      publicStore = "in_repo";
      secretStore = "sops";
    };

    # Add YubiKey plugin to clan's age binary
    secrets.age.plugins = [
      "age-plugin-yubikey"
    ];
  };

  den.default.nixos = {
    clan.core.sops.defaultGroups = [
      "admins"
    ];
  };

  # Add YubiKey age plugin to the devshell
  perSystem =
    { pkgs, ... }:
    {
      clan.devShellPackages = with pkgs; [
        age
        age-plugin-yubikey
      ];
    };
}
