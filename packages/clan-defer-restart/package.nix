{
  writeShellApplication,
  util-linux,
  systemd,
  coreutils,
}:
writeShellApplication {
  name = "clan-defer-restart";
  runtimeInputs = [
    util-linux
    systemd
    coreutils
  ];
  text = builtins.readFile ./clan-defer-restart.sh;
  meta = {
    description = "Hold a deploy flock and schedule deferred systemctl try-restart after it releases";
    mainProgram = "clan-defer-restart";
  };
}
