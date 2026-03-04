{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      devShells = {
        default = pkgs.mkShell {
          name = "nixpedition";

          inputsFrom = [
            config.pre-commit.devShell or { }
            config.clan.devShell or { }
          ];
          packages = with pkgs; [
            nixfmt
            nixd
          ];

          shellHook = ''
            ${config.pre-commit.settings.shellHook}

            echo "Welcome to the \`nixpedition\` direnv shell!"
            echo ""

            echo "NOTE: In order run VMs you need to add \`virt-viewer\` to your systems pkgs."
            echo "      This is due to the \`spice\` URL protocol not being registered in the system."
            echo ""

            echo "To run a VM use \`clan vms run <machine> -p 2222:22\` command."
            echo ""
          '';
        };
      };
    };
}
