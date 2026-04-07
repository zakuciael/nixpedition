# VPS configuration
{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  den.hosts.x86_64-linux.francois.users = {
    "zakuciael" = { };
    "wittano" = { };
  };

  den.aspects.francois = {
    includes = [
      <virtualisation/nixos-containers>
      <services/openssh>
      <services/frp>
    ];

    nixos =
      { constants, ... }:
      {
        clan.core.sops.defaultGroups = [
          "francois"
        ];

        nixos-containers = {
          hostAddress = constants.containers.hostAddress;
          hostAddress6 = constants.containers.hostAddress6;
        };
      };
  };
}
