{ inputs, lib, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      inherit (pkgs) stdenv;
      inherit (pkgs.python3Packages) buildPythonPackage hatchling httpx;

      nixbot-effects = buildPythonPackage {
        name = "nixbot-effects";
        pyproject = true;
        src = "${inputs.nixbot}/nixbot_effects";
        build-system = [
          hatchling
        ];

        # Dirty patch to fix local eval by adding `shallow=1` to the flake url
        postPatch = /* bash */ ''
          substituteInPlace ./nixbot_effects/eval.py \
            --replace-fail 'return f"git+file://{opts.path}?rev={rev}#"' 'return f"git+file://{opts.path}?shallow=1&rev={rev}#"'
        '';
      };

      nixbot-cli = buildPythonPackage {
        name = "nixbot-cli";
        pyproject = true;
        src = "${inputs.nixbot}/nixbot_cli";
        build-system = [ hatchling ];
        dependencies = [
          httpx
          nixbot-effects
        ];

        # `nbo effects run` sandboxes the effect with bwrap. The sandbox only
        # exists on Linux and bubblewrap does not evaluate on Darwin.
        makeWrapperArgs = lib.optionals stdenv.hostPlatform.isLinux [
          "--prefix PATH : ${lib.makeBinPath [ pkgs.bubblewrap ]}"
        ];

        meta = {
          description = "Command-line client (nbo) for the nixbot CI service";
          homepage = "https://github.com/nix-community/nixbot";
          license = lib.licenses.mit;
          maintainers = [ lib.maintainers.mic92 ];
          mainProgram = "nbo";
        };
      };
    in
    {
      devShells = {
        default = pkgs.mkShell {
          name = "nixpedition";

          inputsFrom = [
            config.pre-commit.devShell or { }
            config.clan.devShell or { }
          ];
          packages = with pkgs; [
            statix
            deadnix
            nixfmt
            nixd

            nixbot-cli
          ];

          shellHook = ''
            ${config.pre-commit.settings.shellHook}

            echo "Welcome to the \`nixpedition\` direnv shell!"
            echo ""

            echo "NOTE: In order run VMs you need to add \`virt-viewer\` to your systems pkgs."
            echo "      This is due to the \`spice\` URL protocol not being registered in the system."
            echo ""

            echo "To run a VM use \`clan vms run <machine> -p 2222:2222\` command."
            echo "If you need to register system protected ports (ports below 1024) run the above command with \`sudo -E\`."
            echo ""
          '';
        };
      };
    };
}
