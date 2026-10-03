use sporespore_rapier_adapter::run_qsdk_r24d53_rapier_staging_transport_zero_world_qualification;

fn main() {
    match run_qsdk_r24d53_rapier_staging_transport_zero_world_qualification() {
        Ok(receipt) => println!(
            "QSDK_R24D53_RAPIER_STAGING_TRANSPORT_ZERO_WORLD {}",
            serde_json::to_string(&receipt).expect("R53 receipt must serialize")
        ),
        Err(error) => {
            eprintln!("QSDK_R24D53_RAPIER_STAGING_TRANSPORT_ZERO_WORLD_FAIL {error}");
            std::process::exit(1);
        }
    }
}
