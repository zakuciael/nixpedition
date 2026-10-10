{ self, inputs, ... }:
{
  hci-effects =
    {
      lib,
      config',
      hci-effects,
      pkgs,
      system,
      ...
    }:
    let
      inherit (lib)
        concatMapAttrsStringSep
        concatStringsSep
        escapeShellArgs
        filterAttrs
        getExe'
        mapAttrs
        optionalString
        ;

      knownHostsName = "deploy.known_hosts";
      tfCfg = config'.terranix.terranixConfigurations.nixpedition;
      tfBinaryName = tfCfg.result.terraformWrapper.meta.mainProgram;

      terraformScript = pkgs.writeShellApplication {
        name = "nixpedition-apply";
        runtimeInputs = [ tfCfg.result.terraformWrapper ];

        text = /* bash */ ''
          mkdir -p ${tfCfg.workdir}
          ln -sf ${tfCfg.result.terraformConfiguration} ${tfCfg.workdir}/config.tf.json

          ${tfBinaryName} init
          ${tfBinaryName} apply -auto-approve
        '';
      };

      deferRestarts =
        self.nixosConfigurations
        |> mapAttrs (
          _: nixos:
          let
            cfg = nixos.config.clan.core.deployment;
            net = nixos.config.clan.core.networking;
          in
          {
            units = cfg.deferRestart;
            inherit (net) targetHost;
            include = !cfg.requireExplicitUpdate && net.targetHost != null && cfg.deferRestart != [ ];
          }
        )
        |> filterAttrs (_: m: m.include)
        |> mapAttrs (_: m: { inherit (m) units targetHost; });

      sshRemote =
        targetHost: opts: remoteCommands:
        let
          matched = builtins.match "([^@]+)@([^:]+):([0-9]+)" targetHost;
          user = builtins.elemAt matched 0;
          host = builtins.elemAt matched 1;
          port = builtins.elemAt matched 2;
        in
        hci-effects.ssh (
          {
            destination = "${user}@${host}";
            sshOptions = "-o BatchMode=yes -o StrictHostKeyChecking=accept-new -p ${port}";
          }
          // opts
        ) remoteCommands;

      holdDeferredRestarts =
        deferRestarts
        |> concatMapAttrsStringSep "\n" (
          machine:
          { targetHost, ... }:
          /* bash */ ''
            echo "Holding defer-restart flock on ${machine}"
            _defer_hold_unit="clan-defer-restart-hold-${machine}-$$"
            ${sshRemote targetHost { inheritVariables = [ "_defer_hold_unit" ]; } ''
              mkdir -p /run/clan-defer-restart
              systemd-run \
                --no-block \
                --collect \
                --unit="$_defer_hold_unit" \
                ${getExe' pkgs.util-linux "flock"} /run/clan-defer-restart/deploy.lock \
                ${getExe' pkgs.coreutils "sleep"} infinity \
                >/dev/null
            ''}
            defer_restart_hold_unit_${machine}="$_defer_hold_unit"
          ''
        );

      cleanupDeferredRestartHolds =
        deferRestarts
        |> concatMapAttrsStringSep "\n" (
          machine:
          { targetHost, ... }:
          /* bash */ ''
            _defer_hold_unit="''${defer_restart_hold_unit_${machine}-}"
            if [ -n "$_defer_hold_unit" ]; then
              echo "Releasing defer-restart flock on ${machine} ($_defer_hold_unit)"
              ${
                sshRemote targetHost { inheritVariables = [ "_defer_hold_unit" ]; } ''
                  systemctl stop "$_defer_hold_unit" 2>/dev/null || true
                ''
              } || true
            fi
          ''
        );

      # The hold above is started asynchronously; poll until its flock is held
      # (flock -n fails ⇒ lock busy) or give up.
      assertDeferredRestartHolds =
        deferRestarts
        |> concatMapAttrsStringSep "\n" (
          machine:
          { targetHost, ... }:
          /* bash */ ''
            held=0
            for _ in $(seq 1 50); do
              if ! ${
                sshRemote targetHost { } ''
                  flock -n /run/clan-defer-restart/deploy.lock -c :
                ''
              }; then
                held=1
                break
              fi
              sleep 0.2
            done
            if [ "$held" -ne 1 ]; then
              echo "defer-restart hold is not active on ${machine}" >&2
              exit 1
            fi
          ''
        );

      scheduleDeferredRestarts =
        deferRestarts
        |> concatMapAttrsStringSep "\n" (
          machine:
          { units, targetHost }:
          /* bash */ ''
            echo "Scheduling deferred restart on ${machine}: ${units |> concatStringsSep ", "}"
            ${sshRemote targetHost { } ''
              clan-defer-restart schedule ${escapeShellArgs units}
            ''}
          ''
        );
    in
    {
      jobs = {
        deploy = {
          on.push = {
            branches = [ "main" ];
          };

          effect = hci-effects.mkEffect {
            name = "deploy";
            lock = "production";

            checkout = true;
            inputs = [
              inputs.clan-core.packages.${system}.clan-cli
              terraformScript

              pkgs.openssh
              pkgs.git
            ];

            # Envs
            NIX_CONFIG = "experimental-features = nix-command flakes pipe-operators";
            TF_INPUT = "false";
            CLAN_NO_COMMIT = "1";

            secretsMap = {
              "ssh" = "ci-ssh-keys";
              "age" = "ci-age-key";
              "git-author" = "git-author";
            };

            getStateScript = ''
              mkdir -p ~/.ssh
              getStateFile "${knownHostsName}" ~/.ssh/known_hosts
              touch ~/.ssh/known_hosts
            '';
            putStateScript = ''
              putStateFile "${knownHostsName}" ~/.ssh/known_hosts
            '';

            userSetupScript = /* bash */ ''
              writeAgeKey
              writeSSHKey
              setupGit
            '';

            effectScript = /* bash */ ''
              # Hold host flocks for the whole effect via remote systemd
              # units; stop those units on EXIT so the flock is released even
              # when teardown does not kill a background SSH hold.
              cleanup_defer_restart_holds() {
                ${cleanupDeferredRestartHolds}
              }
              trap cleanup_defer_restart_holds EXIT INT TERM
              ${holdDeferredRestarts}
              ${optionalString (deferRestarts != { }) assertDeferredRestartHolds}

              echo "Applying Terraform configuration"
              ${lib.getExe terraformScript}

              echo "Checking and commiting secrets"
              git add vars/ sops/
              if ! git diff --cached --quiet; then
                git commit -m "chore(vars): sync secrets from terraform"
                git push origin HEAD:refs/heads/main
              fi

              echo "Updating clan machines"
              clan machines update \
                --host-key-check accept-new

              # Queue change-gated restarts/reloads that block on the flocks held above
              ${scheduleDeferredRestarts}
            '';
          };
        };
      };
    };
}
