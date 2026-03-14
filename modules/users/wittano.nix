{
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  den.aspects.wittano = {
    includes = [
      <den/primary-user>
      (<den/user-shell> "bash")
    ];
  };
}
