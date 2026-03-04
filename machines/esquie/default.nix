# Homelab configuration
{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  den.hosts.x86_64-linux.esquie.users = {
    "zakuciael" = { };
  };

  den.aspects.esquie = {
    includes = [
      <hardware/amdgpu>
      <hardware/amdgpu/sea-islands>
      <services/openssh>
      <services/ollama>
      <services/ollama/vulkan>
    ];
  };
}
