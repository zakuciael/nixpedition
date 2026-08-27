{
  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      tofuStateCompletion = pkgs.stdenvNoCC.mkDerivation {
        pname = "tofu-fish-completions";
        version = "0.0.0";

        dontUnpack = true;

        installPhase = ''
          mkdir -p $out/share/fish/vendor_conf.d
          cat > $out/share/fish/vendor_conf.d/tofu-state.fish <<'EOF'
          function __tofu_state_list_cached
              set -l ttl 10 # seconds
              set -l key (string sub -l 32 (echo -n $PWD | sha256sum | string split ' ')[1])
              set -l cache_dir "/tmp/tofu-state-completion-cache"
              set -l cache_file "$cache_dir/$key"

              mkdir -p $cache_dir

              if test -f $cache_file
                  set -l age (math (date +%s) - (stat -c %Y $cache_file 2>/dev/null; or stat -f %m $cache_file))
                  if test $age -lt $ttl
                      cat $cache_file
                      return
                  end
              end

              tofu state list 2>/dev/null | tee $cache_file
          end

          complete -c tofu -n "__fish_seen_subcommand_from state" -fa "(__tofu_state_list_cached)"
          EOF
        '';
      };
    in
    {
      terranix.exportDevShells = false;

      devShells =
        config.terranix.terranixConfigurations
        |> lib.mapAttrs (
          name: cfg:
          pkgs.mkShell {
            name = name + "-tf";

            buildInputs = [ tofuStateCompletion ];
            inputsFrom = [
              cfg.result.devShell
            ];

            shellHook = ''
              export XDG_DATA_DIRS="${tofuStateCompletion}/share:$XDG_DATA_DIRS"
            '';
          }
        );
    };
}
