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
      <virtualisation/containers>
      <services/openssh>
      <services/frp>
    ];

    nixos = {
      clan.core.sops.defaultGroups = [
        "francois"
      ];
    };
  };
}
