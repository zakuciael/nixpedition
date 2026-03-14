{
  services.openssh.nixos.services = {
    openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };
  };
}
