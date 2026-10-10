use std::{
    fs,
    os::unix::fs::OpenOptionsExt,
    path::{Path, PathBuf},
    thread,
    time::Duration,
};

use miette::{IntoDiagnostic, WrapErr};
use nix::fcntl::{Flock, FlockArg};
use tracing::{debug, info, instrument};
use usage_rs::{Args, Run};

use crate::error::Result;

const DEFAULT_LOCK_NAME: &str = "deploy.lock";

/// Acquire an exclusive flock on the deploy lock and sleep until killed
#[derive(Args)]
pub(crate) struct Hold {
    #[usage(
        long,
        env = "CLAN_DEFER_RESTART_RUNTIME_DIR",
        default = "/run/clan-defer-restart"
    )]
    runtime_dir: PathBuf,

    #[usage(long, env = "CLAN_DEFER_RESTART_LOCK")]
    lock: Option<PathBuf>,
}

impl Run for Hold {
    type Output = Result<()>;

    fn run(self) -> Self::Output {
        let lock = resolve_lock(&self.runtime_dir, self.lock)
            .wrap_err("failed to hold deploy lock")?;
        cmd_hold(&lock)
    }
}

#[instrument(skip(lock), fields(runtime_dir = %runtime_dir.display()))]
pub(crate) fn resolve_lock(runtime_dir: &Path, lock: Option<PathBuf>) -> Result<PathBuf> {
    fs::create_dir_all(runtime_dir)
        .into_diagnostic()
        .wrap_err_with(|| {
            format!(
                "failed to create runtime directory {}",
                runtime_dir.display()
            )
        })?;
    let path = lock.unwrap_or_else(|| runtime_dir.join(DEFAULT_LOCK_NAME));
    debug!(lock = %path.display(), "resolved deploy lock path");
    Ok(path)
}

#[instrument(skip_all, fields(lock = %lock_file.display()))]
fn cmd_hold(lock_file: &Path) -> Result<()> {
    let file = fs::OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .mode(0o644)
        .open(lock_file)
        .into_diagnostic()
        .wrap_err_with(|| format!("failed to open lock {}", lock_file.display()))?;

    info!("acquiring exclusive deploy flock");
    let _guard = Flock::lock(file, FlockArg::LockExclusive)
        .map_err(|(_, err)| err)
        .into_diagnostic()
        .wrap_err_with(|| format!("failed to lock {}", lock_file.display()))?;
    info!("deploy flock held; sleeping until killed");

    loop {
        thread::sleep(Duration::from_secs(3600));
    }
}
