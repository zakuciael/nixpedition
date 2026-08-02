{
  services.binary-cache.nixos =
    {
      host,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.services.niks3;
    in
    {
      clan.core.vars.generators = {
        "binary-cache-constants" = {
          files = {
            port.secret = false;
            domain.secret = false;
          };

          prompts = {
            port = {
              description = "Port for the niks3 server";
              persist = true;
              type = "line";
            };
            domain = {
              description = "Domain for the niks3 server";
              persist = true;
              type = "line";
            };
          };
        };
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
              key generate-secret --key-name "${host.constants.services.binary-cache.domain}-1" > $out/key
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
