use serde_json::{Value, json};
use sporespore_rapier_adapter::run_qsdk_r23d14_rapier_temporal_preflight;

fn failure(code: &str) -> Value {
    json!({
        "schema_version": "sporespore_qsdk_r23d14_native_temporal_failure_v1",
        "engine_id": "rapier_parry",
        "failure_stage": "before_model",
        "failure_code": code,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    })
}

fn emit(prefix: &str, value: &Value) -> Result<(), String> {
    println!(
        "{prefix}{}",
        serde_json::to_string(value).map_err(|error| error.to_string())?
    );
    Ok(())
}

fn run() -> Result<(), String> {
    let arguments = std::env::args().skip(1).collect::<Vec<String>>();
    if arguments.len() != 1 {
        return Err("exactly one command required".to_owned());
    }
    match arguments[0].as_str() {
        "preflight" => match run_qsdk_r23d14_rapier_temporal_preflight() {
            Ok(receipt) => emit("QSDK_R23D14_RAPIER_TEMPORAL_PREFLIGHT ", &receipt),
            Err(error) => {
                emit("QSDK_R23D14_RAPIER_TEMPORAL_FAILURE ", &failure(&error))?;
                Err(error)
            }
        },
        "physical" => {
            let code = "QSDK_R23D14_RAP_PHYSICAL_ROUTE_NOT_IMPLEMENTED";
            emit("QSDK_R23D14_RAPIER_TEMPORAL_FAILURE ", &failure(code))?;
            Err(code.to_owned())
        }
        command => Err(format!("unknown command: {command}")),
    }
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
