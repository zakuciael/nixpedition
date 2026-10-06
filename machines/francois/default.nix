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

      # 8 vCPU / 22 GiB, parallelize attrs without
      # oversubscribing every compile across all cores.
      nix.settings = {
        max-jobs = 4;
        cores = 2;

        # Keep workers × eval-cores near host capacity. With Determinate
        # parallel eval, prefer fewer workers and more threads per worker
        # (heavy NixOS attrs benefit more than tiny package attrs).
        eval-cores = 4;
      };

      nixos-containers = {
        hostAddress = "10.0.0.1";
        hostAddress6 = "fc00::1";
      };
    };
  };
}
