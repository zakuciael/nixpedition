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
    # Automatically set machine hostname
    define-hostname = take.exactly (
      { host }:
      {
        nixos.networking.hostName = host.hostName;
      }
    );

    # Automatically set hardware configuration using nixos-facter
    define-hardware = take.exactly (
      { host }:
      let
        reportPath = ../hosts/${host.hostName}/facter.json;
        reportPathOrNull = if (pathExists reportPath) then reportPath else null;
        relReportPath = "." + substring (stringLength (toString ./.)) (-1) (toString reportPath);
      in
      {
        nixos.hardware.facter.reportPath = lib.warnIf (reportPathOrNull == null) ''
          The nixos-facter report file for host "${host.hostName}" is missing.
          Please generate it in the following path: "${relReportPath}"
        '' reportPathOrNull;
      }
    );

    # Define user's authorized keys and password
    define-user = take.exactly (
      { host, user }:
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
    );

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
