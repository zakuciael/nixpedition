{ inputs, ... }:
{
  imports = [
    (inputs.den.namespace "services" false)
  ];
}
