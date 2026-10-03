use serde_json::{Value, json};
use sporespore_rapier_adapter::{
    run_qsdk_r23d50_rapier_authorization_preflight, run_qsdk_r23d50_rapier_physical,
    run_qsdk_r23d50_rapier_preflight,
};
use std::path::{Path, PathBuf};

fn failure(code: &str) -> Value {
    json!({
        "schema_version": "sporespore_qsdk_r23d50_worker_failure_v1",
        "engine_id": "rapier_parry",
        "failure_stage": "before_model",
        "failure_code": code,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    })
}

fn bounded(bytes: &[u8]) -> String {
    let mut characters = String::from_utf8_lossy(bytes)
        .replace('\0', "\\0")
        .chars()
        .rev()
        .take(2_000)
        .collect::<Vec<_>>();
    characters.reverse();
    characters.into_iter().collect()
}

#[allow(clippy::too_many_arguments)]
fn production_retention_preflight(
    stage_id: &str,
    candidate_id: &str,
    arm_id: &str,
    source_root: &Path,
    repo_root: &Path,
    attempt_root: &Path,
    python: &Path,
    powershell: &Path,
) -> Result<Value, String> {
    let worker = run_qsdk_r23d50_rapier_preflight(stage_id, candidate_id, arm_id)?;
    if worker["model_construction_count"] != 0
        || worker["world_attempt_count"] != 0
        || worker["world_build_count"] != 0
    {
        return Err("QSDK_R23D50_RETENTION_PREFLIGHT_WORKER_NOT_ZERO_WORLD".to_owned());
    }
    let evaluator = source_root
        .join("sdk")
        .join("turning")
        .join("r23d50_rapier_cas_path_identity_replay_evaluator.py");
    if !evaluator.is_file() || !python.is_file() || !powershell.is_file() {
        return Err("QSDK_R23D50_RETENTION_PREFLIGHT_INPUT_MISSING".to_owned());
    }
    let output = std::process::Command::new(python)
        .current_dir(source_root)
        .arg(&evaluator)
        .arg("production-retention-preflight")
        .arg("--source-root")
        .arg(source_root)
        .arg("--repo-root")
        .arg(repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D50_RETENTION_PREFLIGHT_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = "QSDK_R23D50_PRODUCTION_RETENTION_PREFLIGHT ";
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D50_RETENTION_PREFLIGHT_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            bounded(&output.stdout),
            bounded(&output.stderr),
        ));
    }
    let mut receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D50_RETENTION_PREFLIGHT_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != "sporespore_qsdk_r23d50_production_retention_preflight_v1"
        || receipt["campaign_id"] != "QSDK-R23D50-RAPIER-CAS-PATH-IDENTITY-REPLAY"
        || receipt["gate_id"] != "QSDK-R23D50"
        || receipt["synthetic_trace_row_count"] != 2_992
        || receipt["process_scoped_execution_policy_bypass_exercised"] != true
        || receipt["complete_cas_binding_verifier_exercised"] != true
        || receipt["ordinary_and_windows_extended_path_spelling_positive_control_count"] != 1
        || receipt["wrong_existing_file_rejection_count"] != 1
        || receipt["model_construction_count"] != 0
        || receipt["world_attempt_count"] != 0
        || receipt["world_build_count"] != 0
        || receipt["physical_acceptance_authority"] != false
    {
        return Err("QSDK_R23D50_RETENTION_PREFLIGHT_RECEIPT_MISMATCH".to_owned());
    }
    let object = receipt
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D50_RETENTION_PREFLIGHT_RECEIPT_NOT_OBJECT".to_owned())?;
    object.insert(
        "exact_rust_to_python_to_powershell_to_artifact_store_route_exercised".to_owned(),
        Value::Bool(true),
    );
    object.insert(
        "rust_worker_outer_route_validated".to_owned(),
        Value::Bool(true),
    );
    Ok(receipt)
}

fn run() -> Result<(), String> {
    let mut args = std::env::args().skip(1);
    let command = args.next().ok_or_else(|| "command required".to_owned())?;
    let mut stage_id = None::<String>;
    let mut candidate_id = None::<String>;
    let mut arm_id = None::<String>;
    let mut source_commit = None::<String>;
    let mut source_root = None::<PathBuf>;
    let mut repo_root = None::<PathBuf>;
    let mut attempt_root = None::<PathBuf>;
    let mut python = None::<PathBuf>;
    let mut powershell = None::<PathBuf>;
    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--stage" if stage_id.is_none() => stage_id = args.next(),
            "--candidate" if candidate_id.is_none() => candidate_id = args.next(),
            "--arm" if arm_id.is_none() => arm_id = args.next(),
            "--source-commit" if source_commit.is_none() => source_commit = args.next(),
            "--source-root" if source_root.is_none() => {
                source_root = args.next().map(PathBuf::from)
            }
            "--repo-root" if repo_root.is_none() => repo_root = args.next().map(PathBuf::from),
            "--attempt-root" if attempt_root.is_none() => {
                attempt_root = args.next().map(PathBuf::from)
            }
            "--python" if python.is_none() => python = args.next().map(PathBuf::from),
            "--powershell" if powershell.is_none() => powershell = args.next().map(PathBuf::from),
            _ => return Err(format!("unknown or duplicate argument: {argument}")),
        }
    }
    let stage_id = stage_id.ok_or_else(|| "--stage required".to_owned())?;
    let candidate_id = candidate_id.ok_or_else(|| "--candidate required".to_owned())?;
    let arm_id = arm_id.ok_or_else(|| "--arm required".to_owned())?;
    let result = match command.as_str() {
        "preflight" => run_qsdk_r23d50_rapier_preflight(&stage_id, &candidate_id, &arm_id)
            .map(|receipt| ("QSDK_R23D50_RAPIER_PREFLIGHT", receipt)),
        "authorization-preflight" => {
            let source_commit =
                source_commit.ok_or_else(|| "--source-commit required".to_owned())?;
            run_qsdk_r23d50_rapier_authorization_preflight(
                &stage_id,
                &candidate_id,
                &arm_id,
                &source_commit,
            )
            .map(|receipt| ("QSDK_R23D50_RAPIER_AUTHORIZATION_PREFLIGHT", receipt))
        }
        "retention-preflight" => production_retention_preflight(
            &stage_id,
            &candidate_id,
            &arm_id,
            &source_root.ok_or_else(|| "--source-root required".to_owned())?,
            &repo_root.ok_or_else(|| "--repo-root required".to_owned())?,
            &attempt_root.ok_or_else(|| "--attempt-root required".to_owned())?,
            &python.ok_or_else(|| "--python required".to_owned())?,
            &powershell.ok_or_else(|| "--powershell required".to_owned())?,
        )
        .map(|receipt| ("QSDK_R23D50_PRODUCTION_RETENTION_PREFLIGHT", receipt)),
        "physical" => {
            let source_commit =
                source_commit.ok_or_else(|| "--source-commit required".to_owned())?;
            return match run_qsdk_r23d50_rapier_physical(
                &stage_id,
                &candidate_id,
                &arm_id,
                &source_commit,
            ) {
                Ok(receipt) => {
                    println!(
                        "QSDK_R23D50_RAPIER_TERMINAL {}",
                        serde_json::to_string(&receipt).map_err(|error| error.to_string())?
                    );
                    Ok(())
                }
                Err(receipt) => {
                    let code = receipt["failure_code"]
                        .as_str()
                        .unwrap_or("QSDK_R23D50_RAP_PHYSICAL_FAILED")
                        .to_owned();
                    println!(
                        "QSDK_R23D50_RAPIER_TERMINAL {}",
                        serde_json::to_string(&receipt).map_err(|error| error.to_string())?
                    );
                    Err(code)
                }
            };
        }
        _ => return Err(format!("unknown command: {command}")),
    };
    match result {
        Ok((marker, receipt)) => {
            println!(
                "{marker} {}",
                serde_json::to_string(&receipt).map_err(|error| error.to_string())?
            );
            Ok(())
        }
        Err(error) => {
            println!(
                "QSDK_R23D50_RAPIER_FAILURE {}",
                serde_json::to_string(&failure(&error))
                    .map_err(|json_error| json_error.to_string())?
            );
            Err(error)
        }
    }
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
