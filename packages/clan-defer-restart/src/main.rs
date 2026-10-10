//! Hold a deploy flock, or schedule deferred systemctl try-restart/reload after it releases.
//!
//! See `clan.core.deployment.deferRestart`.

mod cli;
mod compare;
mod error;

use std::{
    fmt,
    io::{self, IsTerminal},
};

use cli::ClanDeferRestart;
use tracing::{Event, Level, Subscriber};
use tracing_subscriber::{
    EnvFilter,
    fmt::{FmtContext, FormatEvent, FormatFields, format::Writer},
    registry::LookupSpan,
};

fn main() -> miette::Result<()> {
    let cli = ClanDeferRestart::parse();
    init_tracing(cli.verbose);
    // `run_command` is generated because the root also declares flags.
    cli.run_command()
}

fn init_tracing(verbose: u8) {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| {
        EnvFilter::new(match verbose {
            0 => "info",
            1 => "debug",
            _ => "trace",
        })
    });

    // Quiet single-line logs for operators; `-v` adds span names, `-vv` adds targets.
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_writer(io::stderr)
        .with_ansi(io::stderr().is_terminal())
        .event_format(CliFormat {
            show_spans: verbose >= 1,
            show_target: verbose >= 2,
        })
        .init();
}

/// Human-oriented formatter: level + message (+ optional span/target breadcrumbs).
struct CliFormat {
    show_spans: bool,
    show_target: bool,
}

impl<S, N> FormatEvent<S, N> for CliFormat
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> FormatFields<'a> + 'static,
{
    fn format_event(
        &self,
        ctx: &FmtContext<'_, S, N>,
        mut writer: Writer<'_>,
        event: &Event<'_>,
    ) -> fmt::Result {
        write_level(&mut writer, *event.metadata().level())?;

        if self.show_target {
            write!(writer, "{}: ", event.metadata().target())?;
        }

        if self.show_spans {
            if let Some(scope) = ctx.event_scope() {
                for span in scope.from_root() {
                    write!(writer, "{}: ", span.name())?;
                }
            }
        }

        ctx.format_fields(writer.by_ref(), event)?;
        writeln!(writer)
    }
}

fn write_level(writer: &mut Writer<'_>, level: Level) -> fmt::Result {
    let (code, label) = match level {
        Level::TRACE => ("\x1b[35m", "TRACE"),
        Level::DEBUG => ("\x1b[34m", "DEBUG"),
        Level::INFO => ("\x1b[32m", "INFO"),
        Level::WARN => ("\x1b[33m", "WARN"),
        Level::ERROR => ("\x1b[31m", "ERROR"),
    };

    if writer.has_ansi_escapes() {
        write!(writer, "{code}{label}\x1b[0m ")
    } else {
        write!(writer, "{label} ")
    }
}
