{
  lib,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
let
  inherit (lib) mkDefault getExe;
in
{
  den = {
    schema = {
      host.includes = [
        <den/mutual-provider>
        <den/define-user>
      ];

      # Enable Home-Manager as default for all users, unless they specify other classes.
      user.classes = mkDefault [ "homeManager" ];
    };

    default = {
      nixos =
        { host, pkgs, ... }:
        {
          system.stateVersion = "25.11";
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
          };

          clan = {
            # Disable graphics for VMs (make it opt-in)
            virtualisation.graphics = mkDefault false;
            core = {
              networking.targetHost = host.hostName;
              enableRecommendedDefaults = true;
              # Disable clan's `state-version` var
              settings.state-version.enable = false;
            };
          };

          boot.loader = {
            timeout = mkDefault 1;
            grub = {
              efiSupport = true;
              efiInstallAsRemovable = true;
              device = "nodev";
            };
          };

          networking = {
            # Explicitly ensure that the Firewall is enabled.
            firewall.enable = true;

            # Set `nftables` as the default Firewall backend.
            nftables.enable = true;
          };

          environment = {
            enableAllTerminfo = true;
            systemPackages = with pkgs; [
              curl
              git
              neovim
              pciutils
            ];
          };

          nix = {
            settings = {
              auto-optimise-store = true;
              trusted-users = [ "@wheel" ];
            };
            extraOptions = ''
              experimental-features = nix-command flakes pipe-operators
            '';
          };

          time.timeZone = "Europe/Warsaw";
          services.xserver.xkb.layout = "pl";
          console.useXkbConfig = true;
          i18n = {
            defaultLocale = "en_US.UTF-8";
            extraLocaleSettings = {
              LC_ADDRESS = "pl_PL.UTF-8";
              LC_IDENTIFICATION = "pl_PL.UTF-8";
              LC_MEASUREMENT = "pl_PL.UTF-8";
              LC_MONETARY = "pl_PL.UTF-8";
              LC_NAME = "pl_PL.UTF-8";
              LC_NUMERIC = "pl_PL.UTF-8";
              LC_PAPER = "pl_PL.UTF-8";
              LC_TELEPHONE = "pl_PL.UTF-8";
              LC_TIME = "pl_PL.UTF-8";
            };
          };
        };

      homeManager =
        { pkgs, ... }:
        {
          home = {
            shellAliases."vim" = "${getExe pkgs.neovim}";
            stateVersion = "25.11";
          };
        };
    };
  };
}
