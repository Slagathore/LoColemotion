use std::io::{BufRead, BufReader, BufWriter, Write};
use std::net::TcpStream;
use std::sync::mpsc::{Receiver, RecvTimeoutError, channel};
use std::sync::{Mutex, OnceLock};
use std::thread;
use std::time::{Duration, Instant};

use serde_json::{Value, json};

use crate::locomotion::live_explorer_scene;

pub const LIVE_EXPLORER_PROTOCOL_VERSION: &str = "sporespore_live_explorer_protocol_v1";

struct LiveTransport {
    writer: BufWriter<TcpStream>,
    command_receiver: Receiver<Value>,
    pending_impulses: Vec<PendingImpulse>,
    session_id: String,
    frame_index: u64,
    started_at: Instant,
    physics_started_at: Option<Instant>,
    next_frame_at: Instant,
    frame_period: Option<Duration>,
    wait_for_start: bool,
    start_gate_satisfied: bool,
}

#[derive(Clone)]
pub(crate) struct PendingImpulse {
    pub command_id: String,
    pub target_body_id: String,
    pub apply_at_frame: u64,
    pub x_n_s: f32,
    pub y_n_s: f32,
    pub z_n_s: f32,
}

static LIVE_TRANSPORT: OnceLock<Mutex<Option<LiveTransport>>> = OnceLock::new();

fn transport_slot() -> &'static Mutex<Option<LiveTransport>> {
    LIVE_TRANSPORT.get_or_init(|| Mutex::new(None))
}

fn validate_session_id(session_id: &str) -> Result<(), String> {
    if session_id.is_empty()
        || session_id.len() > 96
        || !session_id
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
    {
        return Err("LIVE_EXPLORER_SESSION_ID_INVALID".to_owned());
    }
    Ok(())
}

fn send(transport: &mut LiveTransport, value: &Value) -> Result<(), String> {
    serde_json::to_writer(&mut transport.writer, value).map_err(|error| error.to_string())?;
    transport
        .writer
        .write_all(b"\n")
        .map_err(|error| error.to_string())?;
    transport.writer.flush().map_err(|error| error.to_string())
}

fn read_commands(stream: TcpStream, sender: std::sync::mpsc::Sender<Value>) {
    let reader = BufReader::new(stream);
    for line in reader.lines() {
        let Ok(line) = line else {
            break;
        };
        let Ok(value) = serde_json::from_str::<Value>(&line) else {
            break;
        };
        if sender.send(value).is_err() {
            break;
        }
    }
}

pub fn configure_live_explorer(
    connect_address: &str,
    session_id: &str,
    realtime: bool,
    wait_for_start: bool,
    source_commit: Option<&str>,
) -> Result<(), String> {
    validate_session_id(session_id)?;
    if source_commit.is_some_and(|commit| {
        commit.len() != 40 || !commit.bytes().all(|byte| byte.is_ascii_hexdigit())
    }) {
        return Err("LIVE_EXPLORER_SOURCE_COMMIT_INVALID".to_owned());
    }
    let stream = TcpStream::connect(connect_address)
        .map_err(|error| format!("LIVE_EXPLORER_CONNECT_FAILED:{error}"))?;
    stream
        .set_nodelay(true)
        .map_err(|error| format!("LIVE_EXPLORER_NODELAY_FAILED:{error}"))?;
    let reader_stream = stream
        .try_clone()
        .map_err(|error| format!("LIVE_EXPLORER_STREAM_CLONE_FAILED:{error}"))?;
    let (command_sender, command_receiver) = channel();
    thread::spawn(move || read_commands(reader_stream, command_sender));
    let now = Instant::now();
    let mut transport = LiveTransport {
        writer: BufWriter::new(stream),
        command_receiver,
        pending_impulses: Vec::new(),
        session_id: session_id.to_owned(),
        frame_index: 0,
        started_at: now,
        physics_started_at: None,
        next_frame_at: now,
        frame_period: realtime.then_some(Duration::from_secs_f64(1.0 / 120.0)),
        wait_for_start,
        start_gate_satisfied: !wait_for_start,
    };
    let hello = json!({
        "schema_version": LIVE_EXPLORER_PROTOCOL_VERSION,
        "message_type": "hello",
        "session_id": session_id,
        "engine_id": "rapier_parry",
        "engine_name": "Rapier 3D / Parry",
        "engine_version": rapier3d::VERSION,
        "native_physics": true,
        "replay": false,
        "development_authority": true,
        "scientific_evidence_authority": false,
        "physics_hz": 120,
        "realtime_pacing_requested": realtime,
        "source_commit": source_commit,
        "command_capabilities": {
            "scheduled_canonical_torso_impulse": true,
            "coordinated_start_gate": true,
            "maximum_impulse_magnitude_n_s": 8.0,
            "native_application": "RigidBody::apply_impulse",
        },
        "scene": live_explorer_scene()?,
    });
    send(&mut transport, &hello)?;
    *transport_slot()
        .lock()
        .map_err(|_| "LIVE_EXPLORER_TRANSPORT_LOCK_POISONED".to_owned())? = Some(transport);
    Ok(())
}

pub(crate) fn wait_for_live_explorer_start() -> Result<(), String> {
    let mut guard = transport_slot()
        .lock()
        .map_err(|_| "LIVE_EXPLORER_TRANSPORT_LOCK_POISONED".to_owned())?;
    let Some(transport) = guard.as_mut() else {
        return Ok(());
    };
    if !transport.wait_for_start || transport.start_gate_satisfied {
        return Ok(());
    }
    send(
        transport,
        &json!({
            "schema_version": LIVE_EXPLORER_PROTOCOL_VERSION,
            "message_type": "ready_to_start",
            "session_id": transport.session_id,
            "engine_id": "rapier_parry",
            "native_physics": true,
            "replay": false,
            "scientific_evidence_authority": false,
        }),
    )?;
    let value = match transport
        .command_receiver
        .recv_timeout(Duration::from_secs(300))
    {
        Ok(value) => value,
        Err(RecvTimeoutError::Timeout) => {
            return Err("LIVE_EXPLORER_START_GATE_TIMEOUT".to_owned());
        }
        Err(RecvTimeoutError::Disconnected) => {
            return Err("LIVE_EXPLORER_START_GATE_DISCONNECTED".to_owned());
        }
    };
    if value["schema_version"] != LIVE_EXPLORER_PROTOCOL_VERSION
        || value["message_type"] != "start"
        || value["session_id"] != transport.session_id
    {
        return Err("LIVE_EXPLORER_START_ENVELOPE_INVALID".to_owned());
    }
    transport.start_gate_satisfied = true;
    send(
        transport,
        &json!({
            "schema_version": LIVE_EXPLORER_PROTOCOL_VERSION,
            "message_type": "started",
            "session_id": transport.session_id,
            "engine_id": "rapier_parry",
            "native_physics": true,
            "replay": false,
            "scientific_evidence_authority": false,
        }),
    )
}

fn parse_impulse(transport: &LiveTransport, value: &Value) -> Result<PendingImpulse, String> {
    if value["schema_version"] != LIVE_EXPLORER_PROTOCOL_VERSION
        || value["message_type"] != "apply_impulse"
        || value["session_id"] != transport.session_id
    {
        return Err("LIVE_EXPLORER_IMPULSE_ENVELOPE_INVALID".to_owned());
    }
    let command_id = value["command_id"]
        .as_str()
        .ok_or_else(|| "LIVE_EXPLORER_IMPULSE_COMMAND_ID_MISSING".to_owned())?;
    validate_session_id(command_id)?;
    let target_body_id = value["target_body_id"]
        .as_str()
        .ok_or_else(|| "LIVE_EXPLORER_IMPULSE_TARGET_MISSING".to_owned())?;
    if target_body_id != "torso" {
        return Err("LIVE_EXPLORER_IMPULSE_ONLY_TORSO_SUPPORTED".to_owned());
    }
    let apply_at_frame = value["apply_at_frame"]
        .as_u64()
        .ok_or_else(|| "LIVE_EXPLORER_IMPULSE_FRAME_INVALID".to_owned())?;
    let component = |name: &str| {
        value["impulse_n_s"][name]
            .as_f64()
            .filter(|number| number.is_finite())
            .map(|number| number as f32)
            .ok_or_else(|| format!("LIVE_EXPLORER_IMPULSE_COMPONENT_INVALID:{name}"))
    };
    let x_n_s = component("x")?;
    let y_n_s = component("y")?;
    let z_n_s = component("z")?;
    let magnitude = (x_n_s * x_n_s + y_n_s * y_n_s + z_n_s * z_n_s).sqrt();
    if magnitude <= f32::EPSILON || magnitude > 8.0 {
        return Err("LIVE_EXPLORER_IMPULSE_MAGNITUDE_OUT_OF_BOUNDS".to_owned());
    }
    Ok(PendingImpulse {
        command_id: command_id.to_owned(),
        target_body_id: target_body_id.to_owned(),
        apply_at_frame,
        x_n_s,
        y_n_s,
        z_n_s,
    })
}

pub(crate) fn take_due_rapier_impulses() -> Result<Vec<PendingImpulse>, String> {
    let mut guard = transport_slot()
        .lock()
        .map_err(|_| "LIVE_EXPLORER_TRANSPORT_LOCK_POISONED".to_owned())?;
    let Some(transport) = guard.as_mut() else {
        return Ok(Vec::new());
    };
    while let Ok(value) = transport.command_receiver.try_recv() {
        let pending = parse_impulse(transport, &value)?;
        if pending.apply_at_frame <= transport.frame_index {
            return Err("LIVE_EXPLORER_IMPULSE_FRAME_ALREADY_PASSED".to_owned());
        }
        send(
            transport,
            &json!({
                "schema_version": LIVE_EXPLORER_PROTOCOL_VERSION,
                "message_type": "command_scheduled",
                "session_id": transport.session_id,
                "engine_id": "rapier_parry",
                "command_id": pending.command_id,
                "apply_at_frame": pending.apply_at_frame,
                "scientific_evidence_authority": false,
            }),
        )?;
        transport.pending_impulses.push(pending);
        transport
            .pending_impulses
            .sort_by_key(|impulse| impulse.apply_at_frame);
    }
    let next_frame = transport.frame_index + 1;
    let split = transport
        .pending_impulses
        .partition_point(|impulse| impulse.apply_at_frame <= next_frame);
    let due = transport
        .pending_impulses
        .drain(..split)
        .collect::<Vec<_>>();
    if due
        .iter()
        .any(|impulse| impulse.apply_at_frame != next_frame)
    {
        return Err("LIVE_EXPLORER_IMPULSE_SCHEDULE_MISSED".to_owned());
    }
    Ok(due)
}

pub(crate) fn emit_rapier_frame(mut native_state: Value) -> Result<(), String> {
    let mut guard = transport_slot()
        .lock()
        .map_err(|_| "LIVE_EXPLORER_TRANSPORT_LOCK_POISONED".to_owned())?;
    let Some(transport) = guard.as_mut() else {
        return Ok(());
    };
    if transport.physics_started_at.is_none() {
        let now = Instant::now();
        transport.physics_started_at = Some(now);
        transport.next_frame_at = now;
    }
    transport.frame_index += 1;
    native_state["schema_version"] = json!(LIVE_EXPLORER_PROTOCOL_VERSION);
    native_state["message_type"] = json!("frame");
    native_state["session_id"] = json!(transport.session_id);
    native_state["engine_id"] = json!("rapier_parry");
    native_state["native_physics"] = json!(true);
    native_state["replay"] = json!(false);
    native_state["frame_index"] = json!(transport.frame_index);
    native_state["simulation_time_s"] = json!(transport.frame_index as f64 / 120.0);
    native_state["wall_time_s"] = json!(transport.started_at.elapsed().as_secs_f64());
    native_state["physics_wall_time_s"] = json!(
        transport
            .physics_started_at
            .expect("set before frame")
            .elapsed()
            .as_secs_f64()
    );
    send(transport, &native_state)?;

    if let Some(frame_period) = transport.frame_period {
        transport.next_frame_at += frame_period;
        let now = Instant::now();
        if transport.next_frame_at > now {
            thread::sleep(transport.next_frame_at - now);
        } else if now.duration_since(transport.next_frame_at) > Duration::from_secs(1) {
            // Avoid an unbounded catch-up burst after a debugger pause.
            transport.next_frame_at = now;
        }
    }
    Ok(())
}

pub fn finish_live_explorer(ok: bool, outcome: &str, summary: Value) -> Result<(), String> {
    let mut guard = transport_slot()
        .lock()
        .map_err(|_| "LIVE_EXPLORER_TRANSPORT_LOCK_POISONED".to_owned())?;
    let Some(mut transport) = guard.take() else {
        return Err("LIVE_EXPLORER_TRANSPORT_NOT_CONFIGURED".to_owned());
    };
    let message = json!({
        "schema_version": LIVE_EXPLORER_PROTOCOL_VERSION,
        "message_type": "completed",
        "session_id": transport.session_id,
        "engine_id": "rapier_parry",
        "native_physics": transport.frame_index > 0,
        "replay": false,
        "ok": ok,
        "outcome": outcome,
        "frame_count": transport.frame_index,
        "wall_time_s": transport.started_at.elapsed().as_secs_f64(),
        "physics_wall_time_s": transport
            .physics_started_at
            .map(|started| started.elapsed().as_secs_f64())
            .unwrap_or(0.0),
        "scientific_evidence_authority": false,
        "summary": summary,
    });
    send(&mut transport, &message)
}
