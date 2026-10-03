use serde_json::{Value, json};
use sporespore_rapier_adapter::{run_qsdk_r23d5_rapier_physical, run_qsdk_r23d5_rapier_preflight};

const ENGINE_ID: &str = "rapier_parry";

#[derive(Debug)]
struct Arguments {
    stage_id: String,
    arm_id: String,
    preflight_only: bool,
    source_commit: Option<String>,
}

fn usage() -> String {
    "usage: qsdk_r23d5_dependency_closed --stage <stage> --arm <arm> \
     (--preflight-only | --source-commit <40-lower-hex>)"
        .to_owned()
}

fn arguments() -> Result<Arguments, String> {
    let mut stage_id = None::<String>;
    let mut arm_id = None::<String>;
    let mut preflight_only = false;
    let mut source_commit = None::<String>;
    let mut args = std::env::args().skip(1);
    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--stage" if stage_id.is_none() => {
                stage_id = Some(
                    args.next()
                        .ok_or_else(|| "--stage requires a value".to_owned())?,
                );
            }
            "--arm" if arm_id.is_none() => {
                arm_id = Some(
                    args.next()
                        .ok_or_else(|| "--arm requires a value".to_owned())?,
                );
            }
            "--preflight-only" if !preflight_only => preflight_only = true,
            "--source-commit" if source_commit.is_none() => {
                source_commit = Some(
                    args.next()
                        .ok_or_else(|| "--source-commit requires a value".to_owned())?,
                );
            }
            _ => {
                return Err(format!(
                    "unknown or duplicate argument: {argument}\n{}",
                    usage()
                ));
            }
        }
    }
    if preflight_only == source_commit.is_some() {
        return Err(format!(
            "select exactly one of --preflight-only or --source-commit\n{}",
            usage()
        ));
    }
    Ok(Arguments {
        stage_id: stage_id.ok_or_else(|| format!("--stage is required\n{}", usage()))?,
        arm_id: arm_id.ok_or_else(|| format!("--arm is required\n{}", usage()))?,
        preflight_only,
        source_commit,
    })
}

fn argument_failure(error: &str) -> Value {
    json!({
        "schema_version": "sporespore_qsdk_r23d5_worker_failure_v1",
        "engine_id": ENGINE_ID,
        "failure_code": error,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    })
}

fn run() -> Result<(), String> {
    let arguments = match arguments() {
        Ok(arguments) => arguments,
        Err(error) => {
            println!(
                "QSDK_R23D5_RAPIER_FAILURE {}",
                serde_json::to_string(&argument_failure(&error))
                    .map_err(|json_error| json_error.to_string())?
            );
            return Err(error);
        }
    };
    if arguments.preflight_only {
        match run_qsdk_r23d5_rapier_preflight(&arguments.stage_id, &arguments.arm_id) {
            Ok(receipt) => {
                println!(
                    "QSDK_R23D5_RAPIER_PREFLIGHT {}",
                    serde_json::to_string(&receipt).map_err(|error| error.to_string())?
                );
                Ok(())
            }
            Err(error) => {
                println!(
                    "QSDK_R23D5_RAPIER_FAILURE {}",
                    serde_json::to_string(&argument_failure(&error))
                        .map_err(|json_error| json_error.to_string())?
                );
                Err(error)
            }
        }
    } else {
        let source_commit = arguments
            .source_commit
            .as_deref()
            .expect("physical source commit selected by argument validation");
        match run_qsdk_r23d5_rapier_physical(&arguments.stage_id, &arguments.arm_id, source_commit)
        {
            Ok(report) => {
                println!(
                    "QSDK_R23D5_RAPIER_CELL {}",
                    serde_json::to_string(&report).map_err(|error| error.to_string())?
                );
                Ok(())
            }
            Err(failure) => {
                let error = failure["failure_code"]
                    .as_str()
                    .unwrap_or("QSDK_R23D5_RAP_FAILURE_RECEIPT_INVALID")
                    .to_owned();
                println!(
                    "QSDK_R23D5_RAPIER_FAILURE {}",
                    serde_json::to_string(&failure).map_err(|error| error.to_string())?
                );
                Err(error)
            }
        }
    }
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
