{ lib, inputs, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.dendritic
  ];

  # Enable debug flag in flake-parts
  flake-file.outputs = lib.mkForce /* nix */ ''
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      imports = [
        (inputs.import-tree [
          ./nix
          ./modules
        ])
      ];
    }
  '';
}
