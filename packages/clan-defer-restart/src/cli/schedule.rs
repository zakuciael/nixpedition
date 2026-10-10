use std::{
    ffi::OsString,
    fs,
    path::{Path, PathBuf},
};

use command_run::Command;
use miette::{IntoDiagnostic, WrapErr, miette};
use shell_quote::{QuoteExt, Sh};
use tracing::{debug, info, instrument, warn};
use usage_rs::{Args, Run};

use super::hold::resolve_lock;
use crate::{
    compare::{classify_unit, normalize_unit_name, UnitComparison},
    error::Result,
};

const PROFILES_DIR: &str = "/nix/var/nix/profiles";

/// Compare units between system generations and schedule deferred restart/reload
#[derive(Args)]
pub(crate) struct Schedule {
    /// Previous system toplevel (default: previous system profile generation)
    #[usage(long)]
    old: Option<PathBuf>,

    /// New system toplevel
    #[usage(long, default = "/run/current-system")]
    new: PathBuf,

    #[usage(
        long,
        env = "CLAN_DEFER_RESTART_RUNTIME_DIR",
        default = "/run/clan-defer-restart"
    )]
    runtime_dir: PathBuf,

    #[usage(long, env = "CLAN_DEFER_RESTART_LOCK")]
    lock: Option<PathBuf>,

    /// Unit names (with or without `.service`)
    units: Vec<String>,
}

impl Run for Schedule {
    type Output = Result<()>;

    fn run(self) -> Self::Output {
        if self.units.is_empty() {
            return Err(miette!("schedule requires at least one unit name"));
        }

        let lock = resolve_lock(&self.runtime_dir, self.lock)
            .wrap_err("failed to schedule deferred restart")?;
        cmd_schedule(self.old, &self.new, &lock, &self.units)
    }
}

#[instrument(skip_all, fields(
    new = %new.display(),
    lock = %lock_file.display(),
    units = ?units,
))]
fn cmd_schedule(
    old: Option<PathBuf>,
    new: &Path,
    lock_file: &Path,
    units: &[String],
) -> Result<()> {
    let new = new
        .canonicalize()
        .into_diagnostic()
        .wrap_err_with(|| format!("failed to resolve --new {}", new.display()))?;
    debug!(new = %new.display(), "resolved --new toplevel");

    let old = match old {
        Some(path) => {
            let resolved = path
                .canonicalize()
                .into_diagnostic()
                .wrap_err_with(|| format!("failed to resolve --old {}", path.display()))?;
            debug!(old = %resolved.display(), "resolved --old toplevel");
            resolved
        }
        None => match previous_system_profile(&new)
            .wrap_err("failed to schedule deferred restart")?
        {
            Some(path) => {
                info!(old = %path.display(), "using previous system profile as --old");
                path
            }
            None => {
                warn!(
                    "no previous system profile found; nothing to defer-restart (first generation?)"
                );
                return Ok(());
            }
        },
    };

    let mut restart = Vec::new();
    let mut reload = Vec::new();

    for unit in units {
        let name = normalize_unit_name(unit)?;
        match classify_unit(&old, &new, unit)? {
            None => {
                info!(unit = %name, "skip: missing on old or new system");
            }
            Some(UnitComparison::Equal) => {
                info!(unit = %name, "skip: unchanged");
            }
            Some(UnitComparison::NeedsReload) => {
                info!(unit = %name, "classify: reload-only change");
                reload.push(name);
            }
            Some(UnitComparison::NeedsRestart) => {
                info!(unit = %name, "classify: unit changed (restart)");
                restart.push(name);
            }
        }
    }

    if restart.is_empty() && reload.is_empty() {
        info!("scheduled deferred restart: nothing changed");
        return Ok(());
    }

    let script = build_action_script(&restart, &reload);
    let unit_name = format!(
        "clan-defer-restart-{}",
        rand::random_range(0u32..u32::MAX)
    );
    debug!(
        transient_unit = %unit_name,
        script = %script.to_string_lossy(),
        "enqueueing flock-gated systemd-run oneshot"
    );

    // Transient oneshot outside the effect cgroup. flock blocks until hold
    // releases, then try-restart/reload runs. --no-block: return after enqueue.
    // flock -c runs via /bin/sh so PATH includes systemctl.
    let mut cmd = Command::with_args(
        "systemd-run",
        [
            OsString::from("--no-block"),
            OsString::from("--collect"),
            OsString::from("--property=Type=oneshot"),
            OsString::from(format!("--unit={unit_name}")),
            OsString::from("flock"),
            lock_file.as_os_str().to_owned(),
            OsString::from("-c"),
            script,
        ],
    );
    cmd.log_command = false;
    cmd.run()
        .into_diagnostic()
        .wrap_err("failed to invoke systemd-run")?;

    info!(
        transient_unit = %unit_name,
        restart = ?restart,
        reload = ?reload,
        "scheduled deferred actions"
    );
    Ok(())
}

/// Build a `/bin/sh -c` payload with properly quoted unit names (`shell-quote` / `Sh`).
fn build_action_script(restart: &[String], reload: &[String]) -> OsString {
    let mut parts: Vec<OsString> = Vec::new();

    if !restart.is_empty() {
        let mut cmd = OsString::from("systemctl try-restart");
        for unit in restart {
            cmd.push(" ");
            cmd.push_quoted(Sh, unit.as_str());
        }
        parts.push(cmd);
    }

    if !reload.is_empty() {
        let mut cmd = OsString::from("systemctl reload");
        for unit in reload {
            cmd.push(" ");
            cmd.push_quoted(Sh, unit.as_str());
        }
        parts.push(cmd);
    }

    let mut script = OsString::new();
    for (i, part) in parts.into_iter().enumerate() {
        if i > 0 {
            script.push("; ");
        }
        script.push(part);
    }
    script
}

/// Newest `system-*-link` whose resolved path differs from `new`.
#[instrument(skip_all, fields(new = %new.display()))]
fn previous_system_profile(new: &Path) -> Result<Option<PathBuf>> {
    let profiles = Path::new(PROFILES_DIR);
    if !profiles.is_dir() {
        return Err(miette!(
            "profiles directory {} does not exist",
            profiles.display()
        ));
    }

    let mut generations = Vec::new();
    for entry in fs::read_dir(profiles)
        .into_diagnostic()
        .wrap_err_with(|| format!("failed to read {}", profiles.display()))?
    {
        let entry = entry.into_diagnostic()?;
        let name = entry.file_name();
        let Some(name) = name.to_str() else {
            continue;
        };
        let Some(gen) = parse_system_generation(name) else {
            continue;
        };
        generations.push((gen, entry.path()));
    }

    generations.sort_by_key(|(gen, _)| *gen);
    generations.reverse();
    debug!(
        candidates = generations.len(),
        "scanning system profile generations"
    );

    for (gen, path) in generations {
        let Ok(resolved) = path.canonicalize() else {
            debug!(generation = gen, path = %path.display(), "skip unresolvable profile link");
            continue;
        };
        if resolved != new {
            debug!(
                generation = gen,
                path = %resolved.display(),
                "selected previous system profile"
            );
            return Ok(Some(resolved));
        }
    }

    Ok(None)
}

fn parse_system_generation(name: &str) -> Option<u64> {
    // system-42-link
    let rest = name.strip_prefix("system-")?.strip_suffix("-link")?;
    rest.parse().ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn action_script_quotes_units() {
        let script = build_action_script(
            &["sshd.service".into(), "nixbot.service".into()],
            &["niks3.service".into()],
        );
        let script = script.to_string_lossy();
        assert!(script.contains("systemctl try-restart"));
        assert!(script.contains("systemctl reload"));
        assert!(script.contains("sshd.service"));
        assert!(script.contains("niks3.service"));
        assert!(script.contains("; "));
    }
}
