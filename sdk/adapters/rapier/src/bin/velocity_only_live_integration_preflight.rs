use sporespore_rapier_adapter::run_velocity_only_live_integration_preflight;

fn main() {
    let result = run_velocity_only_live_integration_preflight().and_then(|report| {
        serde_json::to_string_pretty(&report)
            .map_err(|error| format!("Rapier v4 live-integration serialization: {error}"))
    });
    match result {
        Ok(serialized) => println!("{serialized}"),
        Err(failure) => {
            eprintln!("{failure}");
            std::process::exit(1);
        }
    }
}
