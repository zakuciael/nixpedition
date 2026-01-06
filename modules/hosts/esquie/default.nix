# Homelab configuration
{
  constants,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  den.hosts.x86_64-linux.esquie.users."${constants.username}" = { };

  den.aspects.esquie = {
    includes = [
      <hardware/amdgpu>
      <hardware/amdgpu/sea-islands>
      <services/ollama>
      <services/ollama/vulkan>
    ];

    nixos.services.openssh.enable = true;

    provides."${constants.username}" =
      { user, ... }:
      {
        nixos.users.users.${user.name} = {
          hashedPassword = "$6$vXLBClpt6i1iA3Hg$/wFwk63aLPfi1M7QMftb9uyj9XbKQN5x7xbMQYbjYpYgNy/ew.aKaV7A.6FqQBQGp2D1EWtPydv2gs5O4t1KU.";
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHZ2QhV4wnRcSXY+Qe7w2F2kK4+VWi28ddknFnErN9wq"
          ];
        };
      };
  };
}
