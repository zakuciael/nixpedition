{ lib, ... }:
{
  services.openssh.nixos.services.openssh = {
    enable = true;
    ports = lib.mkForce [ 2222 ];
    openFirewall = true;
    settings = {
      TCPKeepAlive = true;
      ClientAliveInterval = 60;
      ClientAliveCountMax = 3;

      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };
}
