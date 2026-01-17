{
  lib,
  constants,
  den,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
let
  inherit (lib) mkDefault optionals;
  inherit (den.lib) take parametric;
in
{
  den = {
    # Default home-manager user on all hosts
    homes.x86_64-linux."${constants.username}" = { };

    default = {
      includes = [
        # Include disko configurations for all hosts
        <disko/define-disks>

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
        (take.exactly (
          { OS, host }:
          take.unused OS {
            nixos =
              let
                inherit (builtins) pathExists substring stringLength;
                reportPath = ./hosts/${host.hostName}/facter.json;
                reportPathOrNull = if (pathExists reportPath) then reportPath else null;
                relReportPath = "." + substring (stringLength (toString ./.)) (-1) (toString reportPath);
              in
              {
                hardware.facter.reportPath = lib.warnIf (reportPathOrNull == null) ''
                  The nixos-facter report file for host "${host.hostName}" is missing.
                  Please generate it in the following path: "${relReportPath}"
                '' reportPathOrNull;
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
          parametric.fixedTo ctx {
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
