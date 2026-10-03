use serde_json::{Value, json};
use sporespore_rapier_adapter::{
    R23D78_CAMPAIGN_ID, R23D78_CAMPAIGN_SEED, R23D78_GATE_ID, R23D78_STAGE_ID,
    run_qsdk_r23d78_rapier_authorization_preflight, run_qsdk_r23d78_rapier_physical,
    run_qsdk_r23d78_rapier_preflight,
};

fn failure(code: &str) -> Value {
    json!({
        "schema_version": "sporespore_qsdk_r23d78_worker_failure_v1",
        "campaign_id": R23D78_CAMPAIGN_ID,
        "gate_id": R23D78_GATE_ID,
        "question_class": "finite_decision",
        "stage_id": R23D78_STAGE_ID,
        "engine_id": "rapier_parry",
        "campaign_seed": R23D78_CAMPAIGN_SEED,
        "failure_stage": "before_world",
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
    let mut onset_id = None::<String>;
    let mut campaign_seed = None::<u64>;
    let mut profile_id = None::<String>;
    let mut arm_id = None::<String>;
    let mut source_commit = None::<String>;
    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--stage" if stage_id.is_none() => stage_id = args.next(),
            "--onset" if onset_id.is_none() => onset_id = args.next(),
            "--seed" if campaign_seed.is_none() => {
                campaign_seed = args
                    .next()
                    .ok_or_else(|| "--seed value required".to_owned())?
                    .parse::<u64>()
                    .ok()
            }
            "--profile" if profile_id.is_none() => profile_id = args.next(),
            "--arm" if arm_id.is_none() => arm_id = args.next(),
            "--source-commit" if source_commit.is_none() => source_commit = args.next(),
            _ => return Err(format!("unknown or duplicate argument: {argument}")),
        }
    }
    let stage_id = stage_id.ok_or_else(|| "--stage required".to_owned())?;
    let onset_id = onset_id.ok_or_else(|| "--onset required".to_owned())?;
    let campaign_seed = campaign_seed.ok_or_else(|| "--seed required or invalid".to_owned())?;
    let profile_id = profile_id.ok_or_else(|| "--profile required".to_owned())?;
    let arm_id = arm_id.ok_or_else(|| "--arm required".to_owned())?;
    let result = match command.as_str() {
        "preflight" => run_qsdk_r23d78_rapier_preflight(
            &stage_id,
            &onset_id,
            campaign_seed,
            &profile_id,
            &arm_id,
        )
        .map(|value| ("QSDK_R23D78_RAPIER_PREFLIGHT", value)),
        "authorization-preflight" => {
            let source_commit =
                source_commit.ok_or_else(|| "--source-commit required".to_owned())?;
            run_qsdk_r23d78_rapier_authorization_preflight(
                &stage_id,
                &onset_id,
                campaign_seed,
                &profile_id,
                &arm_id,
                &source_commit,
            )
            .map(|value| ("QSDK_R23D78_RAPIER_AUTHORIZATION", value))
        }
        "physical" => {
            let source_commit =
                source_commit.ok_or_else(|| "--source-commit required".to_owned())?;
            return match run_qsdk_r23d78_rapier_physical(
                &stage_id,
                &onset_id,
                campaign_seed,
                &profile_id,
                &arm_id,
                &source_commit,
            ) {
                Ok(value) => {
                    println!(
                        "QSDK_R23D78_RAPIER_TERMINAL {}",
                        serde_json::to_string(&value).map_err(|error| error.to_string())?
                    );
                    Ok(())
                }
                Err(value) => {
                    let code = value["failure_code"]
                        .as_str()
                        .unwrap_or("QSDK_R23D78_RAP_PHYSICAL_FAILED")
                        .to_owned();
                    println!(
                        "QSDK_R23D78_RAPIER_TERMINAL {}",
                        serde_json::to_string(&value).map_err(|error| error.to_string())?
                    );
                    Err(code)
                }
            };
        }
        _ => return Err(format!("unknown command: {command}")),
    };
    match result {
        Ok((marker, value)) => {
            println!(
                "{marker} {}",
                serde_json::to_string(&value).map_err(|error| error.to_string())?
            );
            Ok(())
        }
        Err(error) => {
            println!(
                "QSDK_R23D78_RAPIER_FAILURE {}",
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
