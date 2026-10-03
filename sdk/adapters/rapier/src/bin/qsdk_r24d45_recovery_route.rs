use sporespore_rapier_adapter::{
    run_qsdk_r24d45_rapier_recovery_development_attempt, run_qsdk_r24d45_rapier_recovery_ghost,
    run_qsdk_r24d45_rapier_recovery_route_qualification,
};

fn run() -> Result<(), String> {
    let mut arguments = std::env::args().skip(1);
    let command = arguments
        .next()
        .ok_or_else(|| "command required: qualification|ghost|development".to_owned())?;
    let (marker, receipt) = match command.as_str() {
        "qualification" => {
            if arguments.next().is_some() {
                return Err("unexpected qualification argument".to_owned());
            }
            (
                "QSDK_R24D45_RAPIER_RECOVERY_QUALIFICATION",
                run_qsdk_r24d45_rapier_recovery_route_qualification()?,
            )
        }
        "ghost" => {
            if arguments.next().is_some() {
                return Err("unexpected ghost argument".to_owned());
            }
            (
                "QSDK_R24D45_RAPIER_RECOVERY_GHOST",
                run_qsdk_r24d45_rapier_recovery_ghost()?,
            )
        }
        "development" => {
            let runtime_qualification_sha256 = arguments.next().ok_or_else(|| {
                "development requires the official qualification receipt sha256".to_owned()
            })?;
            if arguments.next().is_some() {
                return Err("unexpected development argument".to_owned());
            }
            (
                "QSDK_R24D45_RAPIER_RECOVERY_DEVELOPMENT",
                run_qsdk_r24d45_rapier_recovery_development_attempt(&runtime_qualification_sha256)?,
            )
        }
        _ => return Err(format!("unknown command: {command}")),
    };
    println!(
        "{marker} {}",
        serde_json::to_string(&receipt).map_err(|error| error.to_string())?
    );
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
