use serde_json::json;
use sporespore_rapier_adapter::{
    configure_live_explorer, finish_live_explorer,
    run_bw19v_velocity_only_pose_hold_restoration_ph1,
    run_bw19v_velocity_only_pose_hold_restoration_ph1_preflight,
};

struct Arguments {
    connect: String,
    session_id: String,
    source_commit: Option<String>,
    validate_only: bool,
    realtime: bool,
    wait_for_start: bool,
}

fn usage() -> String {
    "usage: locomotion_live_explorer --connect <host:port> --session <id> \
     [--validate-only | --source-commit <40-hex>] [--realtime] [--wait-for-start]"
        .to_owned()
}

fn arguments() -> Result<Arguments, String> {
    let mut connect = None;
    let mut session_id = None;
    let mut source_commit = None;
    let mut validate_only = false;
    let mut realtime = false;
    let mut wait_for_start = false;
    let mut args = std::env::args().skip(1);
    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--connect" => connect = args.next(),
            "--session" => session_id = args.next(),
            "--source-commit" => source_commit = args.next(),
            "--validate-only" => validate_only = true,
            "--realtime" => realtime = true,
            "--wait-for-start" => wait_for_start = true,
            _ => return Err(format!("unknown argument: {argument}\n{}", usage())),
        }
    }
    let parsed = Arguments {
        connect: connect.ok_or_else(usage)?,
        session_id: session_id.ok_or_else(usage)?,
        source_commit,
        validate_only,
        realtime,
        wait_for_start,
    };
    if parsed.validate_only == parsed.source_commit.is_some() {
        return Err(format!(
            "select exactly one of --validate-only or --source-commit\n{}",
            usage()
        ));
    }
    if parsed.validate_only && parsed.realtime {
        return Err("--realtime is invalid with --validate-only".to_owned());
    }
    if parsed.validate_only && parsed.wait_for_start {
        return Err("--wait-for-start is invalid with --validate-only".to_owned());
    }
    Ok(parsed)
}

fn run() -> Result<(), String> {
    let arguments = arguments()?;
    configure_live_explorer(
        &arguments.connect,
        &arguments.session_id,
        arguments.realtime,
        arguments.wait_for_start,
        arguments.source_commit.as_deref(),
    )?;
    if arguments.validate_only {
        let preflight = run_bw19v_velocity_only_pose_hold_restoration_ph1_preflight()?;
        let ok = preflight["ok"] == true && preflight["world_build_count"] == 0;
        finish_live_explorer(ok, "preflight_only", preflight)?;
        return if ok {
            Ok(())
        } else {
            Err("LIVE_EXPLORER_RAPIER_PREFLIGHT_FAILED".to_owned())
        };
    }
    let report = run_bw19v_velocity_only_pose_hold_restoration_ph1(
        arguments
            .source_commit
            .as_deref()
            .expect("validated source commit"),
    )?;
    let ok = report["ok"] == true;
    let outcome = if ok { "positive" } else { "negative" };
    finish_live_explorer(
        true,
        outcome,
        json!({
            "walking": ok,
            "trace_step_count": report["trace_step_count"],
            "metrics": report["metrics"],
            "gate_failures": report["gate_failures"],
            "development_authority": true,
            "scientific_evidence_authority": false,
        }),
    )
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
