{ lib, ... }:
{
  services.openssh.nixos.services = {
    openssh = {
      enable = true;
      ports = lib.mkForce [ 2222 ];
      openFirewall = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };
  };
}
