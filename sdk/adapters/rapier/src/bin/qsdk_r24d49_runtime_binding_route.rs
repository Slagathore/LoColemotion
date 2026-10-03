#[cfg(feature = "sporespore-rapier-energy-exchange")]
fn run() -> Result<(), String> {
    let mut arguments = std::env::args().skip(1);
    let command = arguments
        .next()
        .ok_or_else(|| "command required: zero-world|ghost|development".to_owned())?;
    let (marker, receipt) = match command.as_str() {
        "zero-world" => {
            if arguments.next().is_some() {
                return Err("unexpected zero-world argument".to_owned());
            }
            (
                "QSDK_R24D49_RAPIER_RUNTIME_BINDING_ZERO_WORLD",
                sporespore_rapier_adapter::run_qsdk_r24d49_rapier_runtime_binding_zero_world_qualification()?,
            )
        }
        "ghost" | "development" => {
            let runtime_binding_sha256 = arguments
                .next()
                .ok_or_else(|| format!("{command} requires runtime_binding_sha256"))?;
            if arguments.next().is_some() {
                return Err(format!("unexpected {command} argument"));
            }
            if command == "ghost" {
                (
                    "QSDK_R24D49_RAPIER_RECOVERY_ENERGY_V2_GHOST",
                    sporespore_rapier_adapter::run_qsdk_r24d49_rapier_recovery_energy_v2_ghost(
                        &runtime_binding_sha256,
                    )?,
                )
            } else {
                (
                    "QSDK_R24D49_RAPIER_RECOVERY_ENERGY_V2_DEVELOPMENT",
                    sporespore_rapier_adapter::run_qsdk_r24d49_rapier_recovery_energy_v2_development_attempt(
                        &runtime_binding_sha256,
                    )?,
                )
            }
        }
        _ => return Err(format!("unknown command: {command}")),
    };
    println!(
        "{marker} {}",
        serde_json::to_string(&receipt).map_err(|error| error.to_string())?
    );
    Ok(())
}

#[cfg(feature = "sporespore-rapier-energy-exchange")]
fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

#[cfg(not(feature = "sporespore-rapier-energy-exchange"))]
fn main() {
    eprintln!("QSDK_R24D49_PATCHED_RAPIER_FEATURE_REQUIRED");
    std::process::exit(1);
}
