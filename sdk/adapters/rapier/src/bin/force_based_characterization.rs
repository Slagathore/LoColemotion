use std::path::PathBuf;

use sporespore_rapier_adapter::{
    run_force_based_host_characterization, run_force_based_host_characterization_preflight,
};

struct Arguments {
    preflight_only: bool,
    source_commit: Option<String>,
    output: Option<PathBuf>,
}

fn usage() -> String {
    "usage: force_based_characterization --preflight-only | \
     --source-commit <40-hex> [--output <report.json>]"
        .to_owned()
}

fn arguments() -> Result<Arguments, String> {
    let mut parsed = Arguments {
        preflight_only: false,
        source_commit: None,
        output: None,
    };
    let mut args = std::env::args_os().skip(1);
    while let Some(argument) = args.next() {
        match argument.to_str() {
            Some("--preflight-only") if !parsed.preflight_only => {
                parsed.preflight_only = true;
            }
            Some("--source-commit") if parsed.source_commit.is_none() => {
                parsed.source_commit = Some(
                    args.next()
                        .and_then(|value| value.into_string().ok())
                        .ok_or_else(usage)?,
                );
            }
            Some("--output") if parsed.output.is_none() => {
                parsed.output = Some(PathBuf::from(args.next().ok_or_else(usage)?));
            }
            _ => return Err(usage()),
        }
    }
    if parsed.preflight_only {
        if parsed.source_commit.is_some() || parsed.output.is_some() {
            return Err(usage());
        }
    } else if parsed.source_commit.is_none() {
        return Err(usage());
    }
    Ok(parsed)
}

fn retain(serialized: &str, path: &PathBuf) -> Result<(), String> {
    if path.file_name().and_then(|name| name.to_str()) != Some("report.json") {
        return Err("Force-based characterization output must be named report.json".to_owned());
    }
    if path.exists() {
        return Err(format!(
            "refusing to overwrite force-based characterization report: {}",
            path.display()
        ));
    }
    let parent = path
        .parent()
        .ok_or_else(|| "force-based characterization output needs a parent".to_owned())?;
    std::fs::create_dir_all(parent)
        .map_err(|error| format!("failed to create evidence directory: {error}"))?;
    let temporary = parent.join("report.json.tmp");
    if temporary.exists() {
        return Err(format!(
            "refusing stale force-based characterization temporary file: {}",
            temporary.display()
        ));
    }
    std::fs::write(&temporary, format!("{serialized}\n"))
        .map_err(|error| format!("failed to write force-based report: {error}"))?;
    std::fs::rename(&temporary, path)
        .map_err(|error| format!("failed to retain force-based report atomically: {error}"))?;
    eprintln!("retained Rapier C6-RAP-HC-FB1 report: {}", path.display());
    Ok(())
}

fn main() {
    let result = arguments().and_then(|arguments| {
        let report = if arguments.preflight_only {
            run_force_based_host_characterization_preflight()
        } else {
            run_force_based_host_characterization(
                arguments
                    .source_commit
                    .as_deref()
                    .expect("validated source commit"),
            )
        }?;
        let serialized = serde_json::to_string_pretty(&report)
            .map_err(|error| format!("force-based report serialization: {error}"))?;
        let report_ok = report["ok"].as_bool() == Some(true);
        if let Some(path) = arguments.output {
            retain(&serialized, &path)?;
        }
        println!("{serialized}");
        if !report_ok {
            return Err("Rapier C6-RAP-HC-FB1 retained a complete negative report".to_owned());
        }
        Ok(())
    });
    if let Err(failure) = result {
        eprintln!("{failure}");
        std::process::exit(1);
    }
}
