mod completion;
mod hold;
mod schedule;

use completion::Completion;
use hold::Hold;
use schedule::Schedule;
use usage_rs::{Cli, Subcommands};

/// Hold a deploy flock and schedule deferred systemctl try-restart/reload after it releases
#[derive(Cli)]
#[usage(bin = "clan-defer-restart", version = "0.1.0", completion, run)]
pub(crate) struct ClanDeferRestart {
    /// Increase log verbosity (-v = debug, -vv = trace); overridden by `RUST_LOG`
    #[usage(short = 'v', long, count, global)]
    pub(crate) verbose: u8,

    #[usage(subcommand)]
    pub(crate) command: Commands,
}

#[derive(Subcommands)]
#[usage(run)]
pub(crate) enum Commands {
    Hold(Hold),
    Schedule(Schedule),
    Completion(Completion),
}
