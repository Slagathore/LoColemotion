use std::path::PathBuf;

use sporespore_rapier_adapter::evaluate_retained_bw19v_velocity_only_early_horizon_eh1_report;

struct Arguments {
    report: PathBuf,
    output: PathBuf,
}

fn arguments() -> Result<Arguments, String> {
    let mut report = None;
    let mut output = None;
    let mut args = std::env::args().skip(1);
    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--report" => {
                report = Some(PathBuf::from(
                    args.next()
                        .ok_or_else(|| "--report requires a value".to_owned())?,
                ));
            }
            "--output" => {
                output = Some(PathBuf::from(
                    args.next()
                        .ok_or_else(|| "--output requires a value".to_owned())?,
                ));
            }
            _ => return Err(format!("unknown argument: {argument}")),
        }
    }
    Ok(Arguments {
        report: report.ok_or_else(|| "--report is required".to_owned())?,
        output: output.ok_or_else(|| "--output is required".to_owned())?,
    })
}

fn retain(path: &PathBuf, serialized: &str) -> Result<(), String> {
    if path.exists() {
        return Err(format!(
            "refusing to overwrite EH1 post-hoc diagnostic: {}",
            path.display()
        ));
    }
    let parent = path
        .parent()
        .ok_or_else(|| "post-hoc diagnostic path has no parent".to_owned())?;
    std::fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    let temporary = path.with_extension("json.tmp");
    if temporary.exists() {
        return Err(format!(
            "refusing stale EH1 post-hoc temporary file: {}",
            temporary.display()
        ));
    }
    std::fs::write(&temporary, format!("{serialized}\n")).map_err(|error| error.to_string())?;
    std::fs::rename(&temporary, path).map_err(|error| error.to_string())
}

fn run() -> Result<(), String> {
    let arguments = arguments()?;
    let retained_report_raw =
        std::fs::read_to_string(&arguments.report).map_err(|error| error.to_string())?;
    let diagnostic =
        evaluate_retained_bw19v_velocity_only_early_horizon_eh1_report(&retained_report_raw)?;
    let serialized =
        serde_json::to_string_pretty(&diagnostic).map_err(|error| error.to_string())?;
    retain(&arguments.output, &serialized)?;
    println!("{serialized}");
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
