use std::{env, process::ExitCode};

use serde_json::{Value, json};
use sporespore_rapier_adapter::{
    run_turning_route_rapier_authorization_preflight, run_turning_route_rapier_physical,
    run_turning_route_rapier_preflight,
};

const PREFLIGHT_MARKER: &str = "SPORESPORE_TURNING_ROUTE_RAPIER_PREFLIGHT ";
const AUTHORIZATION_MARKER: &str = "SPORESPORE_TURNING_ROUTE_RAPIER_AUTHORIZATION_PREFLIGHT ";
const TERMINAL_MARKER: &str = "SPORESPORE_TURNING_ROUTE_RAPIER_TERMINAL ";
const FAILURE_MARKER: &str = "SPORESPORE_TURNING_ROUTE_RAPIER_FAILURE ";

fn print_value(marker: &str, value: &Value) {
    println!(
        "{marker}{}",
        serde_json::to_string(value).unwrap_or_else(|_| {
            "{\"failure_code\":\"TURNING_ROUTE_RAP_TERMINAL_SERIALIZATION_FAILED\"}".to_owned()
        })
    );
}

fn failure(code: &str) -> Value {
    json!({
        "schema_version": "sporespore_three_engine_turning_success_transport_worker_failure_v2",
        "route_id": "sporespore_three_engine_turning_success_transport_route_v2",
        "question_class": "development",
        "engine_id": "rapier_parry",
        "cell_id": "turning_success_transport_v2__rapier_parry__s21516__positive_heading",
        "campaign_seed": 21516,
        "failure_stage": "before_world",
        "failure_code": code,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    })
}

fn main() -> ExitCode {
    let args = env::args().skip(1).collect::<Vec<_>>();
    if args == ["--preflight-only"] {
        return match run_turning_route_rapier_preflight() {
            Ok(value) => {
                print_value(PREFLIGHT_MARKER, &value);
                ExitCode::SUCCESS
            }
            Err(code) => {
                print_value(FAILURE_MARKER, &failure(&code));
                ExitCode::FAILURE
            }
        };
    }
    let (authorization_only, source_commit) = match args.as_slice() {
        [flag, source_commit] if flag == "--source-commit" => (false, source_commit.as_str()),
        [authorization, source_flag, source_commit]
            if authorization == "--authorization-preflight-only"
                && source_flag == "--source-commit" =>
        {
            (true, source_commit.as_str())
        }
        _ => {
            print_value(
                FAILURE_MARKER,
                &failure("TURNING_ROUTE_RAP_ARGUMENTS_INVALID"),
            );
            return ExitCode::FAILURE;
        }
    };
    if authorization_only {
        return match run_turning_route_rapier_authorization_preflight(source_commit) {
            Ok(value) => {
                print_value(AUTHORIZATION_MARKER, &value);
                ExitCode::SUCCESS
            }
            Err(code) => {
                print_value(FAILURE_MARKER, &failure(&code));
                ExitCode::FAILURE
            }
        };
    }
    match run_turning_route_rapier_physical(source_commit) {
        Ok(value) => {
            print_value(TERMINAL_MARKER, &value);
            ExitCode::SUCCESS
        }
        Err(value) => {
            print_value(TERMINAL_MARKER, &value);
            ExitCode::FAILURE
        }
    }
}
