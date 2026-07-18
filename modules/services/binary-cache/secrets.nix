{
  services.binary-cache.nixos =
    {
      config,
      pkgs,
      constants,
      ...
    }:
    let
      cfg = config.services.niks3;
    in
    {
      clan.core.vars.generators = {
        "binary-cache-api-token" = {
          files."token" = {
            secret = true;
            owner = cfg.user;
            inherit (cfg) group;
          };

          script = /* bash */ ''
            openssl rand -base64 32 > $out/token
          '';

          runtimeInputs = [
            pkgs.openssl
          ];
        };
        "binary-cache-signing-key" = {
          files = {
            "key" = {
              secret = true;
              owner = cfg.user;
              inherit (cfg) group;
            };
            "key.pub".secret = false;
          };

          script = /* bash */ ''
            nix --extra-experimental-features "nix-command flakes" \
              key generate-secret --key-name "${constants.services.binary-cache.domain}-1" > $out/key
            nix --extra-experimental-features "nix-command flakes" \
              key convert-secret-to-public < $out/key > $out/key.pub
          '';

          runtimeInputs = [
            pkgs.nix
          ];
        };
      };
    };
}
