{ inputs, ... }:
{
  imports = [
    (inputs.den.namespace "virtualisation" false)
  ];
}
