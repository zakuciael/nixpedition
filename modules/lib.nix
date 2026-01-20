{
  lib,
  den,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
let
  inherit (lib) optionalAttrs;
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

    define-user = parametric {
      description = ''
        Defines a user at OS and Home levels and automatically sets authorized keys and user password.
      '';

      includes = [
        <den/define-user>
        (
          { host, user, ... }:
          take.unused host {
            nixos.users.users.${user.userName} =
              { }
              // optionalAttrs (user ? authorizedKeys) {
                openssh.authorizedKeys.keys = user.authorizedKeys;
              }
              // optionalAttrs (user ? initialHashedPassword) {
                inherit (user) initialHashedPassword;
              }
              // optionalAttrs (user ? hashedPassword) {
                inherit (user) hashedPassword;
              }
              // optionalAttrs (user ? hashedPasswordFile) {
                inherit (user) hashedPasswordFile;
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
