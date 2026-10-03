use sporespore_rapier_adapter::run_qsdk_r23d4_rapier_preflight;

fn run() -> Result<(), String> {
    for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
        let receipt = run_qsdk_r23d4_rapier_preflight("three_engine_confirmation", arm_id)?;
        println!(
            "QSDK_R23D4_RAPIER_PREFLIGHT {}",
            serde_json::to_string(&receipt).map_err(|error| error.to_string())?
        );
    }
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
