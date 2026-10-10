use miette::{Diagnostic, NamedSource, SourceOffset, SourceSpan};
use thiserror::Error;

pub type Result<T> = miette::Result<T>;

#[derive(Debug, Error, Diagnostic)]
#[error("invalid systemd unit name `{name}`")]
#[diagnostic(
    code(clan_defer_restart::invalid_unit_name),
    help("pass a bare service name (e.g. sshd) or a `.service` unit (e.g. sshd.service)")
)]
pub struct InvalidUnitName {
    pub name: String,
}

#[derive(Debug, Error, Diagnostic)]
#[error("failed to parse systemd unit file")]
#[diagnostic(code(clan_defer_restart::parse_unit))]
pub struct ParseUnitError {
    #[source_code]
    pub src: NamedSource<String>,

    #[label("{message}")]
    pub span: SourceSpan,

    pub message: String,
}

impl ParseUnitError {
    /// Build a labeled diagnostic from a `rust-ini` parse error and the file contents.
    pub fn from_ini(path: &str, contents: String, err: ini::ParseError) -> Self {
        let offset = SourceOffset::from_location(&contents, err.line, err.col);
        Self {
            src: NamedSource::new(path, contents),
            span: SourceSpan::new(offset, 1usize),
            message: err.msg.into_owned(),
        }
    }
}
