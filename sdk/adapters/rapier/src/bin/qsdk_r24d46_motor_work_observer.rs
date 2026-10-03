#[cfg(feature = "sporespore-rapier-motor-work")]
fn main() {
    match sporespore_rapier_adapter::run_qsdk_r24d46_rapier_motor_work_zero_world_qualification() {
        Ok(receipt) => println!(
            "QSDK_R24D46_RAPIER_MOTOR_WORK_ZERO_WORLD {}",
            serde_json::to_string(&receipt).expect("R24D46 receipt must serialize")
        ),
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(1);
        }
    }
}

#[cfg(not(feature = "sporespore-rapier-motor-work"))]
fn main() {
    eprintln!("QSDK_R24D46_PATCHED_RAPIER_FEATURE_REQUIRED");
    std::process::exit(1);
}
