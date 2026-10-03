use sporespore_rapier_adapter::run_c2_c5_conformance;
use std::path::PathBuf;

fn main() {
    match run_c2_c5_conformance() {
        Ok(report) => {
            let serialized = serde_json::to_string_pretty(&report)
                .expect("Rapier conformance report must serialize");
            if let Err(failure) = retain_if_requested(&serialized) {
                eprintln!("{failure}");
                std::process::exit(1);
            }
            println!("{serialized}");
        }
        Err(failure_code) => {
            eprintln!("{failure_code}");
            std::process::exit(1);
        }
    }
}

fn retain_if_requested(serialized: &str) -> Result<(), String> {
    let mut args = std::env::args_os().skip(1);
    let Some(flag) = args.next() else {
        return Ok(());
    };
    if flag != "--output" {
        return Err("usage: conformance [--output <report.json>]".to_owned());
    }
    let path = PathBuf::from(
        args.next()
            .ok_or_else(|| "missing path after --output".to_owned())?,
    );
    if args.next().is_some() {
        return Err("usage: conformance [--output <report.json>]".to_owned());
    }
    if path.file_name().and_then(|name| name.to_str()) != Some("report.json") {
        return Err("Rapier conformance output must be named report.json".to_owned());
    }
    let parent = path
        .parent()
        .ok_or_else(|| "Rapier conformance output requires a parent directory".to_owned())?;
    std::fs::create_dir_all(parent)
        .map_err(|error| format!("failed to create evidence directory: {error}"))?;
    let temporary = parent.join("report.json.tmp");
    std::fs::write(&temporary, format!("{serialized}\n"))
        .map_err(|error| format!("failed to write temporary evidence report: {error}"))?;
    std::fs::rename(&temporary, &path)
        .map_err(|error| format!("failed to retain evidence report atomically: {error}"))?;
    eprintln!("retained Rapier C2-C5 report: {}", path.display());
    Ok(())
}
