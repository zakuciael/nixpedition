{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  services.ollama = {
    includes = [
      (<den/unfree> [ "open-webui" ])
    ];

    provides.vulkan.nixos = {
      services.ollama.acceleration = "vulkan";
    };

    nixos = {
      services = {
        open-webui.enable = true;
        ollama = {
          enable = true;
        };
      };
    };
  };
}
