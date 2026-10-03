use std::path::PathBuf;

use sporespore_rapier_adapter::{
    run_bw19v_velocity_only_contact_restoration_tr1,
    run_bw19v_velocity_only_contact_restoration_tr1_preflight,
};

struct Arguments {
    preflight_only: bool,
    source_commit: Option<String>,
    output: Option<PathBuf>,
}

fn usage() -> String {
    "usage: bw19v_velocity_only_contact_restoration_tr1 --preflight-only | \
     --source-commit <40-hex> [--output <report.json>]"
        .to_owned()
}

fn arguments() -> Result<Arguments, String> {
    let mut parsed = Arguments {
        preflight_only: false,
        source_commit: None,
        output: None,
    };
    let mut args = std::env::args().skip(1);
    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--preflight-only" => parsed.preflight_only = true,
            "--source-commit" => {
                parsed.source_commit = Some(
                    args.next()
                        .ok_or_else(|| "--source-commit requires a value".to_owned())?,
                );
            }
            "--output" => {
                parsed.output = Some(PathBuf::from(
                    args.next()
                        .ok_or_else(|| "--output requires a value".to_owned())?,
                ));
            }
            _ => return Err(format!("unknown argument: {argument}\n{}", usage())),
        }
    }
    if parsed.preflight_only {
        if parsed.source_commit.is_some() || parsed.output.is_some() {
            return Err(format!(
                "--preflight-only cannot be combined with physical arguments\n{}",
                usage()
            ));
        }
    } else if parsed.source_commit.is_none() {
        return Err(format!("--source-commit is required\n{}", usage()));
    }
    Ok(parsed)
}

fn retain_report(path: &PathBuf, serialized: &str) -> Result<(), String> {
    if path.exists() {
        return Err(format!(
            "refusing to overwrite TR1 report: {}",
            path.display()
        ));
    }
    let parent = path
        .parent()
        .ok_or_else(|| "TR1 report path has no parent".to_owned())?;
    std::fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    let temporary = path.with_extension("json.tmp");
    if temporary.exists() {
        return Err(format!(
            "refusing stale TR1 temporary report: {}",
            temporary.display()
        ));
    }
    std::fs::write(&temporary, format!("{serialized}\n")).map_err(|error| error.to_string())?;
    std::fs::rename(&temporary, path).map_err(|error| error.to_string())
}

fn run() -> Result<(), String> {
    let arguments = arguments()?;
    let report = if arguments.preflight_only {
        run_bw19v_velocity_only_contact_restoration_tr1_preflight()?
    } else {
        run_bw19v_velocity_only_contact_restoration_tr1(
            arguments
                .source_commit
                .as_deref()
                .expect("physical source commit"),
        )?
    };
    let serialized = serde_json::to_string_pretty(&report).map_err(|error| error.to_string())?;
    if let Some(path) = arguments.output.as_ref() {
        retain_report(path, &serialized)?;
    }
    println!("{serialized}");
    if !arguments.preflight_only && report["ok"] != true {
        return Err("C6-RAP-BW19V-V4-TR1 retained a negative report".to_owned());
    }
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
