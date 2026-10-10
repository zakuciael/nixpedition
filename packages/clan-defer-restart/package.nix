{
  lib,
  rustPlatform,
  util-linux,
  systemd,
  makeWrapper,
  installShellFiles,
  rustfmt,
  clippy,
}:
rustPlatform.buildRustPackage {
  pname = "clan-defer-restart";
  version = "0.1.0";

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    makeWrapper
    installShellFiles
    rustfmt
    clippy
  ];

  buildInputs = [
    util-linux
    systemd
  ];

  postInstall = ''
    wrapProgram $out/bin/clan-defer-restart \
      --prefix PATH : ${
        lib.makeBinPath [
          util-linux
          systemd
        ]
      }

    installShellCompletion --cmd clan-defer-restart \
      --bash <($out/bin/clan-defer-restart completion --shell bash) \
      --zsh <($out/bin/clan-defer-restart completion --shell zsh) \
      --fish <($out/bin/clan-defer-restart completion --shell fish)
  '';

  meta = {
    description = "Hold a deploy flock and schedule deferred systemctl try-restart/reload after unit changes";
    mainProgram = "clan-defer-restart";
  };
}
