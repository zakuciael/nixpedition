# shellcheck shell=bash
# Hold a flock for the life of a CI effect, or schedule a restart that
# waits for that flock to release. See clan.core.deployment.deferRestart.
set -euo pipefail

runtimeDir="${CLAN_DEFER_RESTART_RUNTIME_DIR:-/run/clan-defer-restart}"
lockFile="${CLAN_DEFER_RESTART_LOCK:-$runtimeDir/deploy.lock}"

usage() {
  cat <<'EOF'
Usage:
  clan-defer-restart hold
  clan-defer-restart schedule UNIT [UNIT...]

hold     Acquire an exclusive flock on the deploy lock and sleep until
         the process is killed (typically when the CI effect exits and
         its SSH session drops).

schedule Start a transient systemd unit that waits for that flock, then
         runs systemctl try-restart on the given units.
EOF
}

ensure_runtime_dir() {
  mkdir -p "$runtimeDir"
}

cmd_hold() {
  if (($#)); then
    echo "hold takes no arguments" >&2
    usage >&2
    exit 2
  fi
  ensure_runtime_dir
  # flock keeps the lock for the lifetime of sleep; SSH death ends this.
  exec flock "$lockFile" sleep infinity
}

cmd_schedule() {
  local units=()
  while (($#)); do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        echo "unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
      *)
        units+=("$1")
        shift
        ;;
    esac
  done

  if ((${#units[@]} == 0)); then
    echo "schedule requires at least one unit name" >&2
    usage >&2
    exit 2
  fi

  ensure_runtime_dir

  local restartCmd unitName
  printf -v restartCmd 'systemctl try-restart'
  local u
  for u in "${units[@]}"; do
    printf -v restartCmd '%s %q' "$restartCmd" "$u"
  done

  unitName="clan-defer-restart-${RANDOM}${RANDOM}"

  # Transient oneshot outside the nixbot cgroup. flock blocks until hold
  # releases, then try-restart runs immediately (no grace delay).
  systemd-run \
    --collect \
    --property=Type=oneshot \
    --unit="$unitName" \
    flock "$lockFile" -c "$restartCmd"

  echo "scheduled deferred restart ($unitName): ${units[*]}"
}

main() {
  if (($# < 1)); then
    usage >&2
    exit 2
  fi

  case "$1" in
    hold)
      shift
      cmd_hold "$@"
      ;;
    schedule)
      shift
      cmd_schedule "$@"
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "unknown command: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
