{
  perSystem =
    { config, pkgs, ... }:
    let
      submod = config.terranix.terranixConfigurations.nixpedition;
      tfBinaryName = submod.result.terraformWrapper.meta.mainProgram;
    in
    {
      checks = {
        terranix-nixpedition = pkgs.writeShellApplication {
          name = "terranix-nixpedition";
          runtimeInputs = [ submod.result.terraformWrapper ];
          text = ''
            mkdir -p ${submod.workdir}
            ln -sf ${submod.result.terraformConfiguration} ${submod.workdir}/config.tf.json

            ${tfBinaryName} validate
          '';
        };
      };
    };
}
