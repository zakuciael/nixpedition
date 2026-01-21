{ inputs, ... }:
{
  imports = [
    (inputs.den.namespace "hardware" false)
  ];
}
