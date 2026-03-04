{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  den.aspects.zakuciael = {
    includes = [
      <den/primary-user>
      (<den/user-shell> "fish")
    ];
  };
}
