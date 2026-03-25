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
      <virtualisation/podman>
      <services/openssh>
      <services/frp>
      <services/reverse-proxy>
      <services/zitadel>
    ];

    _.to-users.includes = [
      <virtualisation/podman>
    ];

    nixos.clan.core.sops.defaultGroups = [
      "francois"
    ];
  };
}
