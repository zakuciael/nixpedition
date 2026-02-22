# Homelab configuration
{
  constants,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  den.hosts.x86_64-linux.esquie.users."${constants.username}" = {
    hashedPassword = "$6$vXLBClpt6i1iA3Hg$/wFwk63aLPfi1M7QMftb9uyj9XbKQN5x7xbMQYbjYpYgNy/ew.aKaV7A.6FqQBQGp2D1EWtPydv2gs5O4t1KU.";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHZ2QhV4wnRcSXY+Qe7w2F2kK4+VWi28ddknFnErN9wq"
    ];
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
