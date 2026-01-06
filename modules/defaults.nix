{
  constants,
  den,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  den = {
    # Default home-manager user on all hosts
    homes.x86_64-linux."${constants.username}" = { };

    default = {
      includes = [
        # Include disko configurations for all hosts
        <den/define-disks>

        # Automatically create the user on host.
        <den/define-user>

        # Automatically set user as *primary*.
        <den/primary-user>

        # Automatically set default shell
        (<den/user-shell> "fish")

        # Provide flake-parts inputs' and self' arguments to modules
        den._.inputs'
        den._.self'

        # Automatically set hostname and hardware configuration
        (den.lib.take.exactly (
          { OS, host }:
          den.lib.take.unused OS {
            nixos = {
              imports = [
                { hardware.facter.reportPath = ./hosts/${host.hostName}/facter.json; }
              ];
              networking.hostName = host.hostName;
            };
          }
        ))

        # Create an aspect "routing" pattern.
        (
          let
            mutual = from: to: den.aspects.${from.aspect}._.${to.aspect} or { };
          in
          { host, user, ... }@ctx:
          den.lib.parametric.fixedTo ctx {
            includes = [
              (mutual user host)
              (mutual host user)
            ];
          }
        )
      ];

      nixos =
        { pkgs, ... }:
        {
          # Default bootloader
          boot.loader = {
            grub = {
              efiSupport = true;
              efiInstallAsRemovable = true;
              device = "nodev";
            };
          };

          # Default packages
          environment.systemPackages = with pkgs; [
            curl
            git
            neovim
            pciutils
          ];

          # Default nix settings
          nix = {
            settings = {
              auto-optimise-store = true;
              trusted-users = [
                "@wheel"
              ];
            };
            extraOptions = ''
              experimental-features = nix-command flakes pipe-operators
            '';
          };

          # NixOS state version
          system.stateVersion = "25.11";
        };

      # Home-Manager state version
      homeManager.home.stateVersion = "25.11";
    };
  };
}
