{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  virtualisation.podman = {
    includes = [
      <virtualisation/podman/user-groups>
    ];

    user-groups =
      { user, ... }:
      {
        nixos.users.users."${user.userName}" = {
          extraGroups = [ "podman" ];
        };
      };

    nixos =
      { config, pkgs, ... }:
      {
        virtualisation = {
          oci-containers.backend = "podman";
          podman = {
            enable = true;
            dockerCompat = true;
            dockerSocket.enable = true;
            autoPrune = {
              enable = true;
              dates = "weekly";
              flags = [
                "--filter=until=24h"
                "--filter=label!important"
              ];
            };

            # Ensure the default network has DNS enabled
            defaultNetwork.settings.dns_enabled = true;
          };
        };

        # Enable container name DNS for all Podman networks.
        networking.firewall.interfaces =
          let
            matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
          in
          {
            "${matchAll}".allowedUDPPorts = [ 53 ];
          };

        environment.systemPackages = with pkgs; [
          # A tool for exploring docker image layers
          dive
          # A tool for displaying status of the containers in the terminal
          podman-tui
        ];
      };
  };
}
