use sporespore_rapier_adapter::run_qsdk_r23d15_rapier_inherited_composition_preflight;

fn main() {
    let mut args = std::env::args().skip(1);
    let stage_id = args.next().unwrap_or_default();
    let arm_id = args.next().unwrap_or_default();
    if args.next().is_some() {
        eprintln!("R23D15_RAP_ARGUMENT_COUNT_INVALID");
        std::process::exit(1);
    }
    match run_qsdk_r23d15_rapier_inherited_composition_preflight(&stage_id, &arm_id) {
        Ok(receipt) => println!(
            "QSDK_R23D15_RAPIER_COMPOSITION_RECOVERY {}",
            serde_json::to_string(&receipt).expect("receipt must serialize")
        ),
        Err(code) => {
            println!(
                "QSDK_R23D15_RAPIER_COMPOSITION_FAILURE {}",
                serde_json::to_string(&serde_json::json!({
                    "schema_version": "sporespore_qsdk_r23d15_rapier_composition_failure_v1",
                    "failure_code": code,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "physical_acceptance_authority": false,
                }))
                .expect("failure must serialize")
            );
            std::process::exit(1);
        }
    }
}
