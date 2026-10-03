use serde_json::{Value, json};
use sporespore_rapier_adapter::{
    run_qsdk_r23d10_rapier_authorization_preflight, run_qsdk_r23d10_rapier_physical,
    run_qsdk_r23d10_rapier_preflight,
};

fn failure(code: &str) -> Value {
    json!({
        "schema_version": "sporespore_qsdk_r23d10_worker_failure_v1",
        "engine_id": "rapier_parry",
        "failure_stage": "before_model",
        "failure_code": code,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    })
}

fn run() -> Result<(), String> {
    let mut args = std::env::args().skip(1);
    let command = args.next().ok_or_else(|| "command required".to_owned())?;
    let mut stage_id = None::<String>;
    let mut arm_id = None::<String>;
    let mut source_commit = None::<String>;
    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--stage" if stage_id.is_none() => stage_id = args.next(),
            "--arm" if arm_id.is_none() => arm_id = args.next(),
            "--source-commit" if source_commit.is_none() => source_commit = args.next(),
            _ => return Err(format!("unknown or duplicate argument: {argument}")),
        }
    }
    let stage_id = stage_id.ok_or_else(|| "--stage required".to_owned())?;
    let arm_id = arm_id.ok_or_else(|| "--arm required".to_owned())?;
    if command == "preflight" {
        match run_qsdk_r23d10_rapier_preflight(&stage_id, &arm_id) {
            Ok(receipt) => {
                println!(
                    "QSDK_R23D10_RAPIER_PREFLIGHT {}",
                    serde_json::to_string(&receipt).map_err(|error| error.to_string())?
                );
                Ok(())
            }
            Err(error) => {
                println!(
                    "QSDK_R23D10_RAPIER_FAILURE {}",
                    serde_json::to_string(&failure(&error))
                        .map_err(|json_error| json_error.to_string())?
                );
                Err(error)
            }
        }
    } else if command == "authorization-preflight" {
        let source_commit = source_commit.ok_or_else(|| "--source-commit required".to_owned())?;
        match run_qsdk_r23d10_rapier_authorization_preflight(&stage_id, &arm_id, &source_commit) {
            Ok(receipt) => {
                println!(
                    "QSDK_R23D10_RAPIER_AUTHORIZATION_PREFLIGHT {}",
                    serde_json::to_string(&receipt).map_err(|error| error.to_string())?
                );
                Ok(())
            }
            Err(error) => {
                println!(
                    "QSDK_R23D10_RAPIER_FAILURE {}",
                    serde_json::to_string(&failure(&error))
                        .map_err(|json_error| json_error.to_string())?
                );
                Err(error)
            }
        }
    } else if command == "physical" {
        let source_commit = source_commit.ok_or_else(|| "--source-commit required".to_owned())?;
        match run_qsdk_r23d10_rapier_physical(&stage_id, &arm_id, &source_commit) {
            Ok(receipt) => {
                println!(
                    "QSDK_R23D10_RAPIER_TERMINAL {}",
                    serde_json::to_string(&receipt).map_err(|error| error.to_string())?
                );
                Ok(())
            }
            Err(receipt) => {
                let code = receipt["failure_code"]
                    .as_str()
                    .unwrap_or("QSDK_R23D10_RAP_PHYSICAL_FAILED")
                    .to_owned();
                println!(
                    "QSDK_R23D10_RAPIER_TERMINAL {}",
                    serde_json::to_string(&receipt).map_err(|error| error.to_string())?
                );
                Err(code)
            }
        }
    } else {
        Err(format!("unknown command: {command}"))
    }
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
