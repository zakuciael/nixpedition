//! Unit parsing and comparison inspired by NixOS `switch-to-configuration-ng`.
//!
//! Classifies whether a deferred unit needs restart, reload, or nothing — matching
//! stc-ng semantics without copying its control flow verbatim.

use std::{
    collections::{HashMap, HashSet},
    fs,
    path::{Path, PathBuf},
};

use glob::glob;
use ini::{Ini, ParseOption};
use miette::{IntoDiagnostic, WrapErr};
use tracing::{debug, instrument, trace};

use crate::error::{InvalidUnitName, ParseUnitError, Result};

pub type UnitInfo = HashMap<String, HashMap<String, Vec<String>>>;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UnitComparison {
    Equal,
    NeedsRestart,
    NeedsReload,
}

/// `[Unit]` keys that never trigger restart/reload by themselves.
/// Sorted for `binary_search`.
const UNIT_SECTION_IGNORES: &[&str] = &[
    "AllowIsolate",
    "CollectMode",
    "Description",
    "Documentation",
    "IgnoreOnIsolate",
    "OnFailure",
    "OnFailureJobMode",
    "OnSuccess",
    "RefuseManualStart",
    "RefuseManualStop",
    "SourcePath",
    "StopWhenUnneeded",
    "X-Reload-Triggers",
];

const PARSE_OPTIONS: ParseOption = ParseOption {
    enabled_quote: true,
    enabled_indented_mutiline_value: false,
    enabled_preserve_key_leading_whitespace: false,
    enabled_escape: false,
};

/// Normalize a bare service name (`sshd`) to a unit file name (`sshd.service`).
///
/// Only `.service` units are supported. Bare names get `.service` appended;
/// anything else with a `.` that is not already a `.service` is rejected.
pub fn normalize_unit_name(name: &str) -> Result<String> {
    let name = name.trim();
    if name.is_empty()
        || name.contains('/')
        || name.contains('\\')
        || name.contains('\0')
        || name.starts_with('.')
        || name.ends_with('.')
        || (name.contains('.') && !name.ends_with(".service"))
    {
        return Err(InvalidUnitName {
            name: name.to_string(),
        }
        .into());
    }

    let normalized = if name.ends_with(".service") {
        name.to_string()
    } else {
        format!("{name}.service")
    };
    trace!(input = %name, normalized = %normalized, "normalized unit name");
    Ok(normalized)
}

fn is_ignored_unit_key(key: &str) -> bool {
    UNIT_SECTION_IGNORES.binary_search(&key).is_ok()
}

pub fn unit_path(toplevel: &Path, unit: &str) -> Result<PathBuf> {
    Ok(toplevel
        .join("etc/systemd/system")
        .join(normalize_unit_name(unit)?))
}

/// Compare old vs new unit definitions.
///
/// Returns `None` when either side is missing (new/removed units are left to
/// switch-to-configuration).
#[instrument(skip_all, fields(unit, old = %old_toplevel.display(), new = %new_toplevel.display()))]
pub fn classify_unit(
    old_toplevel: &Path,
    new_toplevel: &Path,
    unit: &str,
) -> Result<Option<UnitComparison>> {
    let old_path = unit_path(old_toplevel, unit)?;
    let new_path = unit_path(new_toplevel, unit)?;
    debug!(
        old_unit = %old_path.display(),
        new_unit = %new_path.display(),
        "comparing unit files"
    );

    if !old_path.exists() || !new_path.exists() {
        debug!(
            old_exists = old_path.exists(),
            new_exists = new_path.exists(),
            "unit missing on one side; skip classification"
        );
        return Ok(None);
    }

    let old_info = parse_unit(&old_path, &old_path)
        .wrap_err("failed to compare systemd units")?;
    let new_info = parse_unit(&new_path, &new_path)
        .wrap_err("failed to compare systemd units")?;
    let comparison = compare_units(&old_info, &new_info);
    debug!(?comparison, "unit comparison result");
    Ok(Some(comparison))
}

/// Glob for `<unit_path>.d/*.conf`, escaping glob metacharacters in the path prefix.
fn unit_dropin_paths(unit_path: &Path) -> Result<Vec<PathBuf>> {
    let prefix = glob::Pattern::escape(&format!("{}.d", unit_path.display()));
    let mut paths = glob(&format!("{prefix}/*.conf"))
        .into_diagnostic()
        .wrap_err("invalid drop-in glob pattern")?
        .filter_map(std::result::Result::ok)
        .collect::<Vec<_>>();

    // systemd applies drop-ins in lexicographic order; keep that deterministic.
    paths.sort();
    Ok(paths)
}

/// Merge drop-in overrides into `unit_data`.
fn merge_dropins(unit_data: &mut UnitInfo, unit_path: &Path) -> Result<()> {
    let dropins = unit_dropin_paths(unit_path)?;
    debug!(
        unit = %unit_path.display(),
        count = dropins.len(),
        "merging unit drop-ins"
    );
    for entry in &dropins {
        trace!(dropin = %entry.display(), "applying drop-in");
    }
    dropins
        .into_iter()
        .try_for_each(|entry| parse_systemd_ini(unit_data, &entry))
}

/// Parse a systemd unit file and its drop-ins into a nested map.
///
/// `unit_file` may differ from `base_unit_path` for template instances,
/// both drop-in directories are merged when they differ.
#[instrument(skip_all, fields(unit = %unit_file.display(), base = %base_unit_path.display()))]
pub fn parse_unit(unit_file: &Path, base_unit_path: &Path) -> Result<UnitInfo> {
    let mut unit_data = HashMap::new();

    parse_systemd_ini(&mut unit_data, base_unit_path)?;
    merge_dropins(&mut unit_data, base_unit_path)?;

    if unit_file != base_unit_path {
        merge_dropins(&mut unit_data, unit_file)?;
    }

    Ok(unit_data)
}

#[instrument(skip(data), fields(path = %path.display()))]
fn parse_systemd_ini(data: &mut UnitInfo, path: &Path) -> Result<()> {
    let path_label = path.display().to_string();
    let contents = fs::read_to_string(path)
        .into_diagnostic()
        .wrap_err_with(|| format!("failed to read unit file {path_label}"))?;
    trace!(bytes = contents.len(), "read unit file");

    let ini = Ini::load_from_str_opt(&contents, PARSE_OPTIONS).map_err(|err| {
        miette::Report::from(ParseUnitError::from_ini(&path_label, contents, err))
    })?;

    for (section, properties) in ini.iter() {
        let Some(section) = section else {
            continue;
        };

        if section == "Install" {
            continue;
        }

        let section_map = data.entry(section.to_string()).or_default();

        for (ini_key, _) in properties {
            let mut new_vals = Vec::new();
            let mut clear_existing = false;

            for val in properties.get_all(ini_key) {
                if val.is_empty() {
                    new_vals.clear();
                    clear_existing = true;
                } else {
                    new_vals.push(val.to_string());
                }
            }

            match (section_map.get_mut(ini_key), clear_existing) {
                (Some(existing_vals), false) => existing_vals.extend(new_vals),
                _ => {
                    section_map.insert(ini_key.to_string(), new_vals);
                }
            };
        }
    }

    Ok(())
}

/// How a single key-level change should be classified.
fn key_change_kind(section: &str, key: &str) -> UnitComparison {
    match (section, key) {
        ("Unit", "X-Reload-Triggers") | ("Service", "ExecReload") | ("Mount", "Options") => {
            UnitComparison::NeedsReload
        }
        ("Unit", key) if is_ignored_unit_key(key) => UnitComparison::Equal,
        _ => UnitComparison::NeedsRestart,
    }
}

fn escalate(current: UnitComparison, next: UnitComparison) -> UnitComparison {
    match (current, next) {
        (_, UnitComparison::NeedsRestart) | (UnitComparison::NeedsRestart, _) => {
            UnitComparison::NeedsRestart
        }
        (_, UnitComparison::NeedsReload) | (UnitComparison::NeedsReload, _) => {
            UnitComparison::NeedsReload
        }
        _ => UnitComparison::Equal,
    }
}

fn only_exec_reload(section: &HashMap<String, Vec<String>>) -> bool {
    section.len() == 1 && section.contains_key("ExecReload")
}

fn only_ignored_unit_keys(section: &HashMap<String, Vec<String>>) -> bool {
    section.keys().all(|key| is_ignored_unit_key(key))
}

/// Compare two parsed units (stc-ng semantics).
#[instrument(skip_all)]
pub fn compare_units(current_unit: &UnitInfo, new_unit: &UnitInfo) -> UnitComparison {
    let mut result = UnitComparison::Equal;
    let mut remaining_new: HashSet<&str> = new_unit.keys().map(String::as_str).collect();

    for (section_name, current_section) in current_unit {
        if !remaining_new.remove(section_name.as_str()) {
            // Section removed in the new unit.
            let noop = match section_name.as_str() {
                "Unit" => only_ignored_unit_keys(current_section),
                "Service" => only_exec_reload(current_section),
                _ => false,
            };
            if !noop {
                debug!(section = %section_name, "section removed → restart");
                return UnitComparison::NeedsRestart;
            }
            trace!(section = %section_name, "section removed but noop");
            continue;
        }

        let Some(new_section) = new_unit.get(section_name) else {
            debug!(section = %section_name, "section missing in new unit → restart");
            return UnitComparison::NeedsRestart;
        };

        let mut remaining_keys: HashSet<&str> = new_section.keys().map(String::as_str).collect();

        for (key, current_value) in current_section {
            remaining_keys.remove(key.as_str());

            match new_section.get(key) {
                None => {
                    // Dropping ignored `[Unit]` metadata or `ExecReload` does not
                    // affect the running process (stc-ng treats both as no-ops).
                    let removal_is_noop = (section_name == "Unit" && is_ignored_unit_key(key))
                        || (section_name == "Service" && key == "ExecReload");
                    if !removal_is_noop {
                        debug!(section = %section_name, key = %key, "key removed → restart");
                        return UnitComparison::NeedsRestart;
                    }
                    trace!(section = %section_name, key = %key, "key removed but noop");
                }
                Some(new_value) if current_value == new_value => {}
                Some(_) => {
                    let kind = key_change_kind(section_name, key);
                    debug!(section = %section_name, key = %key, ?kind, "key value changed");
                    if kind == UnitComparison::NeedsRestart {
                        return UnitComparison::NeedsRestart;
                    }
                    result = escalate(result, kind);
                }
            }
        }

        // Keys introduced in the new unit.
        for key in remaining_keys {
            let kind = key_change_kind(section_name, key);
            debug!(section = %section_name, key = %key, ?kind, "key added");
            if kind == UnitComparison::NeedsRestart {
                return UnitComparison::NeedsRestart;
            }
            result = escalate(result, kind);
        }
    }

    // Sections introduced in the new unit.
    for section_name in remaining_new {
        let Some(new_section) = new_unit.get(section_name) else {
            continue;
        };

        let noop = match section_name {
            "Unit" => only_ignored_unit_keys(new_section),
            "Service" => only_exec_reload(new_section),
            _ => false,
        };
        if noop {
            if section_name == "Unit" && new_section.contains_key("X-Reload-Triggers") {
                debug!(section = %section_name, "new Unit section with X-Reload-Triggers → reload");
                result = escalate(result, UnitComparison::NeedsReload);
            } else if section_name == "Service" {
                debug!(section = %section_name, "new Service section is ExecReload-only → reload");
                result = escalate(result, UnitComparison::NeedsReload);
            } else {
                trace!(section = %section_name, "new section is noop");
            }
            continue;
        }

        // A brand-new Unit section may mix ignored keys with reload triggers.
        if section_name == "Unit" {
            for key in new_section.keys() {
                let kind = key_change_kind(section_name, key);
                debug!(section = %section_name, key = %key, ?kind, "key in new Unit section");
                if kind == UnitComparison::NeedsRestart {
                    return UnitComparison::NeedsRestart;
                }
                result = escalate(result, kind);
            }
            continue;
        }

        debug!(section = %section_name, "new section → restart");
        return UnitComparison::NeedsRestart;
    }

    debug!(?result, "finished unit comparison");
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn write_unit(dir: &Path, name: &str, contents: &str) {
        let path = dir.join("etc/systemd/system");
        fs::create_dir_all(&path).unwrap();
        fs::write(path.join(name), contents).unwrap();
    }

    fn write_dropin(dir: &Path, unit: &str, dropin: &str, contents: &str) {
        let path = dir.join("etc/systemd/system").join(format!("{unit}.d"));
        fs::create_dir_all(&path).unwrap();
        fs::write(path.join(dropin), contents).unwrap();
    }

    #[test]
    fn normalize_appends_service() {
        assert_eq!(normalize_unit_name("sshd").unwrap(), "sshd.service");
        assert_eq!(
            normalize_unit_name("sshd.service").unwrap(),
            "sshd.service"
        );
    }

    #[test]
    fn normalize_rejects_non_service() {
        assert!(normalize_unit_name("foo.socket").is_err());
        assert!(normalize_unit_name("sshd.conf").is_err());
        assert!(normalize_unit_name("").is_err());
        assert!(normalize_unit_name("a/b").is_err());
    }

    #[test]
    fn equal_units() {
        let tmp = tempfile_dir();
        let old = tmp.join("old");
        let new = tmp.join("new");
        let body = "[Service]\nExecStart=/bin/true\n";
        write_unit(&old, "demo.service", body);
        write_unit(&new, "demo.service", body);
        assert_eq!(
            classify_unit(&old, &new, "demo").unwrap(),
            Some(UnitComparison::Equal)
        );
    }

    #[test]
    fn exec_start_change_needs_restart() {
        let tmp = tempfile_dir();
        let old = tmp.join("old");
        let new = tmp.join("new");
        write_unit(&old, "demo.service", "[Service]\nExecStart=/bin/true\n");
        write_unit(&new, "demo.service", "[Service]\nExecStart=/bin/false\n");
        assert_eq!(
            classify_unit(&old, &new, "demo").unwrap(),
            Some(UnitComparison::NeedsRestart)
        );
    }

    #[test]
    fn description_only_is_equal() {
        let tmp = tempfile_dir();
        let old = tmp.join("old");
        let new = tmp.join("new");
        write_unit(
            &old,
            "demo.service",
            "[Unit]\nDescription=Old\n[Service]\nExecStart=/bin/true\n",
        );
        write_unit(
            &new,
            "demo.service",
            "[Unit]\nDescription=New\n[Service]\nExecStart=/bin/true\n",
        );
        assert_eq!(
            classify_unit(&old, &new, "demo").unwrap(),
            Some(UnitComparison::Equal)
        );
    }

    #[test]
    fn reload_triggers_need_reload() {
        let tmp = tempfile_dir();
        let old = tmp.join("old");
        let new = tmp.join("new");
        write_unit(
            &old,
            "demo.service",
            "[Unit]\nX-Reload-Triggers=a\n[Service]\nExecStart=/bin/true\n",
        );
        write_unit(
            &new,
            "demo.service",
            "[Unit]\nX-Reload-Triggers=b\n[Service]\nExecStart=/bin/true\n",
        );
        assert_eq!(
            classify_unit(&old, &new, "demo").unwrap(),
            Some(UnitComparison::NeedsReload)
        );
    }

    #[test]
    fn dropin_change_needs_restart() {
        let tmp = tempfile_dir();
        let old = tmp.join("old");
        let new = tmp.join("new");
        let body = "[Service]\nExecStart=/bin/true\n";
        write_unit(&old, "demo.service", body);
        write_unit(&new, "demo.service", body);
        write_dropin(
            &old,
            "demo.service",
            "override.conf",
            "[Service]\nEnvironment=A=1\n",
        );
        write_dropin(
            &new,
            "demo.service",
            "override.conf",
            "[Service]\nEnvironment=A=2\n",
        );
        assert_eq!(
            classify_unit(&old, &new, "demo").unwrap(),
            Some(UnitComparison::NeedsRestart)
        );
    }

    #[test]
    fn missing_side_skips() {
        let tmp = tempfile_dir();
        let old = tmp.join("old");
        let new = tmp.join("new");
        write_unit(&new, "demo.service", "[Service]\nExecStart=/bin/true\n");
        assert_eq!(classify_unit(&old, &new, "demo").unwrap(), None);
    }

    #[test]
    fn parse_error_includes_source_span() {
        let tmp = tempfile_dir();
        let path = tmp.join("broken.service");
        fs::write(&path, "[Service\nExecStart=/bin/true\n").unwrap();
        let err = parse_systemd_ini(&mut HashMap::new(), &path).unwrap_err();
        let rendered = format!("{err:?}");
        assert!(
            rendered.contains("broken.service") || rendered.contains("parse"),
            "expected diagnostic render, got: {rendered}"
        );
    }

    fn tempfile_dir() -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "clan-defer-restart-test-{}-{}",
            std::process::id(),
            rand::random::<u64>()
        ));
        fs::create_dir_all(&dir).unwrap();
        dir
    }
}
