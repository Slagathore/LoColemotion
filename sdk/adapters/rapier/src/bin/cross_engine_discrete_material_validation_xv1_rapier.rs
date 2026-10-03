use std::path::PathBuf;

use sporespore_rapier_adapter::{
    evaluate_cross_engine_discrete_material_validation_xv1_rapier_report,
    run_cross_engine_discrete_material_validation_xv1_rapier,
    run_cross_engine_discrete_material_validation_xv1_rapier_preflight,
};

struct Arguments {
    preflight_only: bool,
    evaluate_report: Option<PathBuf>,
    source_commit: Option<String>,
    cell_id: Option<String>,
    authored_friction: Option<f64>,
    material_profile_id: Option<String>,
    output: Option<PathBuf>,
}

fn usage() -> String {
    "usage: cross_engine_discrete_material_validation_xv1_rapier \
     --preflight-only | --evaluate-report <report.json> | \
     --source-commit <40-hex> --cell-id <id> \
     --authored-friction <value> --material-profile-id <id> \
     --output <report.json>"
        .to_owned()
}

fn arguments() -> Result<Arguments, String> {
    let mut parsed = Arguments {
        preflight_only: false,
        evaluate_report: None,
        source_commit: None,
        cell_id: None,
        authored_friction: None,
        material_profile_id: None,
        output: None,
    };
    let mut args = std::env::args().skip(1);
    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--preflight-only" => parsed.preflight_only = true,
            "--evaluate-report" => {
                parsed.evaluate_report =
                    Some(PathBuf::from(args.next().ok_or_else(|| {
                        "--evaluate-report requires a value".to_owned()
                    })?));
            }
            "--source-commit" => {
                parsed.source_commit = Some(
                    args.next()
                        .ok_or_else(|| "--source-commit requires a value".to_owned())?,
                );
            }
            "--cell-id" => {
                parsed.cell_id = Some(
                    args.next()
                        .ok_or_else(|| "--cell-id requires a value".to_owned())?,
                );
            }
            "--authored-friction" => {
                let value = args
                    .next()
                    .ok_or_else(|| "--authored-friction requires a value".to_owned())?;
                parsed.authored_friction = Some(value.parse::<f64>().map_err(|error| {
                    format!("--authored-friction must be a finite number: {error}")
                })?);
            }
            "--material-profile-id" => {
                parsed.material_profile_id = Some(
                    args.next()
                        .ok_or_else(|| "--material-profile-id requires a value".to_owned())?,
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
    if parsed.preflight_only || parsed.evaluate_report.is_some() {
        if parsed.source_commit.is_some()
            || parsed.cell_id.is_some()
            || parsed.authored_friction.is_some()
            || parsed.material_profile_id.is_some()
            || parsed.output.is_some()
            || (parsed.preflight_only && parsed.evaluate_report.is_some())
        {
            return Err(format!(
                "nonphysical modes cannot be combined with each other or physical arguments\n{}",
                usage()
            ));
        }
    } else if parsed.source_commit.is_none()
        || parsed.cell_id.is_none()
        || parsed.authored_friction.is_none()
        || parsed.material_profile_id.is_none()
        || parsed.output.is_none()
    {
        return Err(format!("all physical arguments are required\n{}", usage()));
    }
    Ok(parsed)
}

fn retain_report(path: &PathBuf, serialized: &str) -> Result<(), String> {
    if path.exists() {
        return Err(format!(
            "refusing to overwrite XV1 Rapier cell report: {}",
            path.display()
        ));
    }
    let parent = path
        .parent()
        .ok_or_else(|| "XV1 Rapier report path has no parent".to_owned())?;
    std::fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    let temporary = path.with_extension("json.tmp");
    if temporary.exists() {
        return Err(format!(
            "refusing stale XV1 Rapier temporary report: {}",
            temporary.display()
        ));
    }
    std::fs::write(&temporary, format!("{serialized}\n")).map_err(|error| error.to_string())?;
    std::fs::rename(&temporary, path).map_err(|error| error.to_string())
}

fn run() -> Result<(), String> {
    let arguments = arguments()?;
    let report = if arguments.preflight_only {
        run_cross_engine_discrete_material_validation_xv1_rapier_preflight()?
    } else if let Some(path) = arguments.evaluate_report.as_ref() {
        let raw = std::fs::read_to_string(path).map_err(|error| error.to_string())?;
        let candidate: serde_json::Value =
            serde_json::from_str(&raw).map_err(|error| error.to_string())?;
        let failures =
            evaluate_cross_engine_discrete_material_validation_xv1_rapier_report(&candidate);
        serde_json::json!({
            "schema_version":
                "sporespore_cross_engine_c6_bw19v_xv1_rapier_cold_evaluation_v1",
            "ok": failures.is_empty(),
            "campaign_id": candidate["campaign_id"],
            "gate_id": candidate["gate_id"],
            "cell_id": candidate["cell_id"],
            "failure_codes": failures,
            "world_build_count": 0,
            "physics_state_mutation_count": 0,
            "physical_acceptance_authority": false,
        })
    } else {
        run_cross_engine_discrete_material_validation_xv1_rapier(
            arguments.source_commit.as_deref().expect("source commit"),
            arguments.cell_id.as_deref().expect("cell id"),
            arguments.authored_friction.expect("authored friction"),
            arguments
                .material_profile_id
                .as_deref()
                .expect("material profile id"),
        )?
    };
    let serialized = serde_json::to_string_pretty(&report).map_err(|error| error.to_string())?;
    if let Some(path) = arguments.output.as_ref() {
        retain_report(path, &serialized)?;
    }
    println!("{serialized}");
    if report["ok"] != true {
        return Err("C6-XE-BW19V-XV1 Rapier operation returned a negative result".to_owned());
    }
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
