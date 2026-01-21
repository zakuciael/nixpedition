{
  lib,
  constants,
  den,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
let
  inherit (lib) mkDefault;
in
{
  den = {
    # Default home-manager user on all hosts
    homes.x86_64-linux."${constants.username}" = { };

    default = {
      includes = [
        # Include disko configurations for all hosts
        <lib/define-disks>

        # Automatically create the user on host.
        <lib/define-user>

        # Automatically set user as *primary*.
        <den/primary-user>

        # Automatically set default shell
        (<den/user-shell> "fish")

        # Provide flake-parts inputs' and self' arguments to modules
        den._.inputs'
        den._.self'

        # Automatically set hardware configuration
        <lib/define-hardware>

        # Automatically set hostname
        <lib/define-hostname>

        # Allow host to configure user and vice-versa
        <lib/aspect-router>
      ];

      nixos =
        { pkgs, ... }:
        {
          # Default bootloader
          boot.loader = {
            timeout = mkDefault 1;
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
