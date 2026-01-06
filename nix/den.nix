{ inputs, den, ... }:
{
  imports = [ inputs.den.flakeModules.dendritic ];

  flake-file.inputs = {
    den.url = "github:vic/den";
  };

  _module.args.__findFile = den.lib.__findFile;
}
