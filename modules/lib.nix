{
  lib,
  den,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
let
  inherit (den.lib) take parametric;
  inherit (builtins) pathExists substring stringLength;
in
{

  den.aspects.lib.provides = {
    define-hostname = parametric.exactly {
      description = ''
        Automatically set hostname using den's host configuration
      '';

      includes = [
        (
          { OS, host }:
          take.unused OS {
            nixos.networking.hostName = host.hostName;
          }
        )
      ];
    };

    define-hardware = parametric.exactly {
      description = ''
        Automatically set hardware configuration using nixos-facter
      '';

      includes = [
        (
          { OS, host }:
          take.unused OS {
            nixos =
              let
                reportPath = ./hosts/${host.hostName}/facter.json;
                reportPathOrNull = if (pathExists reportPath) then reportPath else null;
                relReportPath = "." + substring (stringLength (toString ./.)) (-1) (toString reportPath);
              in
              {
                hardware.facter.reportPath = lib.warnIf (reportPathOrNull == null) ''
                  The nixos-facter report file for host "${host.hostName}" is missing.
                  Please generate it in the following path: "${relReportPath}"
                '' reportPathOrNull;
              };
          }
        )
      ];
    };

    aspect-router = (
      let
        mutual = from: to: den.aspects.${from.aspect}._.${to.aspect} or { };
      in
      { host, user, ... }@ctx:
      parametric.fixedTo ctx {
        description = ''
          Creates an aspect router, allowing host to configure user and vice-versa.
        '';

        includes = [
          (mutual user host)
          (mutual host user)
        ];
      }
    );
  };
}
