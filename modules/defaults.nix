{
  lib,
  den,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
let
  inherit (den.lib) parametric;
  inherit (lib) mkDefault;
in
{
  den.ctx.host.includes = [
    (
      { host }:
      {
        nixos.clan.core.networking.targetHost = host.hostName;
      }
    )
  ];

  # Default Home-Manager settings
  den.default.homeManager = {
    # State version
    home.stateVersion = "25.11";
  };

  # Default host config if Home-Manager is present
  den.ctx.hm-host.nixos.home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  # Default includes for all hosts
  den.default.includes = [
    # Provide flake-parts inputs' and self' arguments to modules
    den._.inputs'
    den._.self'

    # This aspect wires bidirectional providers between hosts and users automatically
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

  # Default host config
  den.default.nixos =
    { pkgs, ... }:
    {
      clan = {
        # Disable graphics for VMs (make it opt-in)
        virtualisation.graphics = lib.mkDefault false;
        core = {
          # Enable clan's default system configuration
          enableRecommendedDefaults = true;
          # Disable clan's `state-version` var
          settings.state-version.enable = false;
        };
      };

      # Bootloader settings
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

      # Nix settings
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

      # Terminfo support
      environment.enableAllTerminfo = true;

      # State version
      system.stateVersion = "25.11";
    };
}
