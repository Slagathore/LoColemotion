use serde_json::{Value, json};
use sporespore_rapier_adapter::{run_qsdk_r23d1_rapier_physical, run_qsdk_r23d1_rapier_preflight};

const ENGINE_ID: &str = "rapier_parry";

#[derive(Debug)]
struct Arguments {
    arm_id: String,
    preflight_only: bool,
    source_commit: Option<String>,
}

fn usage() -> String {
    "usage: qsdk_r23d1_heading_response --arm <reference_zero|positive_heading|negative_heading> \
     (--preflight-only | --source-commit <40-lower-hex>)"
        .to_owned()
}

fn arguments() -> Result<Arguments, String> {
    let mut arm_id = None::<String>;
    let mut preflight_only = false;
    let mut source_commit = None::<String>;
    let mut args = std::env::args().skip(1);
    while let Some(argument) = args.next() {
        match argument.as_str() {
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
    let arm_id = arm_id.ok_or_else(|| format!("--arm is required\n{}", usage()))?;
    if preflight_only == source_commit.is_some() {
        return Err(format!(
            "select exactly one of --preflight-only or --source-commit\n{}",
            usage()
        ));
    }
    Ok(Arguments {
        arm_id,
        preflight_only,
        source_commit,
    })
}

fn failure(error: &str, arm_id: Option<&str>) -> Value {
    json!({
        "schema_version": "sporespore_qsdk_r23d1_rapier_worker_failure_v1",
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "failure_code": error,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
        "release_authorized": false,
    })
}

fn run() -> Result<(), String> {
    let arguments = match arguments() {
        Ok(arguments) => arguments,
        Err(error) => {
            println!(
                "QSDK_R23D1_RAPIER_FAILURE {}",
                serde_json::to_string(&failure(&error, None))
                    .map_err(|json_error| json_error.to_string())?
            );
            return Err(error);
        }
    };
    let result = if arguments.preflight_only {
        run_qsdk_r23d1_rapier_preflight(&arguments.arm_id)
    } else {
        run_qsdk_r23d1_rapier_physical(
            &arguments.arm_id,
            arguments
                .source_commit
                .as_deref()
                .expect("physical source commit selected by argument validation"),
        )
    };
    match result {
        Ok(report) => {
            let prefix = if arguments.preflight_only {
                "QSDK_R23D1_RAPIER_PREFLIGHT "
            } else {
                "QSDK_R23D1_RAPIER_CELL "
            };
            println!(
                "{prefix}{}",
                serde_json::to_string(&report).map_err(|error| error.to_string())?
            );
            Ok(())
        }
        Err(error) => {
            println!(
                "QSDK_R23D1_RAPIER_FAILURE {}",
                serde_json::to_string(&failure(&error, Some(&arguments.arm_id)))
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
