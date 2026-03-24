{ den, ... }:
let
  inherit (den.lib)
    parametric
    perHost
    perUser
    ;

  # Configure podman and set it as OCI containers backend
  configurePodman = perHost {
    nixos =
      { pkgs, ... }:
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

            # Required for containers under podman-compose to be able to talk to each other.
            defaultNetwork.settings.dns_enabled = true;
          };
        };

        environment.systemPackages = with pkgs; [
          # A tool for exploring docker image layers
          dive
          # A tool for displaying status of the containers in the terminal
          podman-tui
        ];
      };
  };

  # Add all users to the "podman" group
  addUserToGroup = perUser (
    { user, ... }:
    {
      nixos = {
        users.users."${user.userName}" = {
          extraGroups = [ "podman" ];
        };
      };
    }
  );
in
{
  virtualisation.podman = parametric {
    includes = [
      configurePodman
      addUserToGroup
    ];
  };
}
