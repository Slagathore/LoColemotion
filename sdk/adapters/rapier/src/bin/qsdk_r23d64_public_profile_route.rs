use sporespore_rapier_adapter::run_qsdk_r23d64_rapier_public_profile_route_preflight;

fn main() {
    match run_qsdk_r23d64_rapier_public_profile_route_preflight() {
        Ok(receipt) => {
            println!(
                "QSDK_R23D64_RAPIER_PUBLIC_PROFILE_ROUTE {}",
                serde_json::to_string(&receipt).expect("route receipt must serialize")
            );
        }
        Err(error) => {
            eprintln!("QSDK_R23D64_RAPIER_PUBLIC_PROFILE_ROUTE_FAILURE {error}");
            std::process::exit(1);
        }
    }
}
