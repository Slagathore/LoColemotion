#[cfg(feature = "sporespore-rapier-energy-exchange")]
fn main() {
    match sporespore_rapier_adapter::run_qsdk_r24d47_rapier_energy_exchange_zero_world_qualification(
    ) {
        Ok(receipt) => println!(
            "QSDK_R24D47_RAPIER_ENERGY_EXCHANGE_ZERO_WORLD {}",
            serde_json::to_string(&receipt).expect("R24D47 receipt must serialize")
        ),
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(1);
        }
    }
}

#[cfg(not(feature = "sporespore-rapier-energy-exchange"))]
fn main() {
    eprintln!("QSDK_R24D47_PATCHED_RAPIER_FEATURE_REQUIRED");
    std::process::exit(1);
}
