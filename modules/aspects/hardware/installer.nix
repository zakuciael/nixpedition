{
  hardware.installer.nixos =
    { modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-graphical-base.nix") ];
    };
}
