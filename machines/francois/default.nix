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
      <virtualisation/podman>
      <services/openssh>
      <services/frp>
      <services/traefik>
      <services/terranix>
      <services/niks3>
      <services/nixbot>
    ];

    _.to-users.includes = [
      <virtualisation/podman>
    ];

    nixos = {
      clan.core = {
        sops.defaultGroups = [ "francois" ];
        networking.targetHost = "root@51.83.129.177:2222";
      };

      nixos-containers = {
        hostAddress = "10.0.0.1";
        hostAddress6 = "fc00::1";
      };
    };
  };
}
