fn main() {
    match sporespore_rapier_adapter::
        run_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_qualification()
    {
        Ok(receipt) => println!(
            "QSDK_R24D52_RAPIER_DISCRETE_STAGING_LEDGER_ZERO_WORLD {}",
            serde_json::to_string(&receipt).expect("R24D52 receipt must serialize")
        ),
        Err(error) => {
            eprintln!("QSDK_R24D52_RAPIER_DISCRETE_STAGING_LEDGER_ZERO_WORLD_FAIL {error}");
            std::process::exit(1);
        }
    }
}
