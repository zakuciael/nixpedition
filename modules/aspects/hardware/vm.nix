{ den, ... }:
{
  hardware.vm = {
    nixos =
      { modulesPath, ... }:
      {
        imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

        # Use host TTY as the serial console
        boot.kernelParams = [
          "console=tty1"
          "console=ttyS0,115200"
        ];
      };
  };
}
