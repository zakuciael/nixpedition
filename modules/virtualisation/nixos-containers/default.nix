{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  virtualisation.nixos-containers = {
    includes = [
      <virtualisation/nixos-containers/options>
      <virtualisation/nixos-containers/mapper>
    ];

    nixos =
      { config, ... }:
      {
        # NAT configuration (allows containers to reach outside network)
        networking.nat = {
          enable = true;
          enableIPv6 = true;
          internalInterfaces =
            if config.networking.firewall.backend == "nftables" then [ "ve-*" ] else [ "ve-+" ];
        };

        # Prevent Network Manager from managing container interfaces
        networking.networkmanager.unmanaged = [ "interface-name:ve-*" ];
      };
  };
}
