"""Cold probe for the Explorer's native Rapier and MuJoCo live workers."""

from __future__ import annotations

import argparse
import json
import socket
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


PROTOCOL_VERSION = "sporespore_live_explorer_protocol_v1"
EXPECTED_ENGINES = {"rapier_parry", "mujoco"}


@dataclass
class StreamRecord:
    engine_id: str
    messages: list[dict[str, Any]] = field(default_factory=list)
    error: str | None = None


def _arguments() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--validate-only", action="store_true")
    mode.add_argument("--source-commit")
    parser.add_argument("--realtime", action="store_true")
    parser.add_argument("--kick", action="store_true")
    parser.add_argument("--coordinated-start", action="store_true")
    parser.add_argument(
        "--rapier-worker",
        type=Path,
        default=repo_root / "sdk" / "target" / "debug" / "locomotion_live_explorer.exe",
    )
    parser.add_argument(
        "--mujoco-python",
        type=Path,
        default=(
            repo_root
            / "sdk"
            / "adapters"
            / "mujoco"
            / ".venv"
            / "Scripts"
            / "python.exe"
        ),
    )
    parser.add_argument("--timeout-s", type=float, default=180.0)
    arguments = parser.parse_args()
    if arguments.validate_only and arguments.realtime:
        parser.error("--realtime is invalid with --validate-only")
    if arguments.validate_only and arguments.kick:
        parser.error("--kick is invalid with --validate-only")
    if arguments.validate_only and arguments.coordinated_start:
        parser.error("--coordinated-start is invalid with --validate-only")
    if arguments.source_commit is not None and (
        len(arguments.source_commit) != 40
        or any(character not in "0123456789abcdefABCDEF" for character in arguments.source_commit)
    ):
        parser.error("--source-commit must be a full 40-hex Git object ID")
    return arguments


def _reader(
    connection: socket.socket,
    records: dict[str, StreamRecord],
    kick: bool,
    coordinated_start: bool,
    start_barrier: threading.Barrier | None,
) -> None:
    engine_id = "unidentified"
    try:
        with connection, connection.makefile("r", encoding="utf-8", newline="\n") as reader:
            first_line = reader.readline()
            if not first_line:
                raise RuntimeError("LIVE_EXPLORER_STREAM_EMPTY")
            hello = json.loads(first_line)
            engine_id = str(hello.get("engine_id", ""))
            if engine_id not in EXPECTED_ENGINES:
                raise RuntimeError(f"LIVE_EXPLORER_ENGINE_UNEXPECTED:{engine_id}")
            if engine_id in records:
                raise RuntimeError(f"LIVE_EXPLORER_ENGINE_DUPLICATE:{engine_id}")
            record = StreamRecord(engine_id=engine_id, messages=[hello])
            records[engine_id] = record
            kick_sent = False
            for line in reader:
                if line.strip():
                    message = json.loads(line)
                    record.messages.append(message)
                    if (
                        coordinated_start
                        and message.get("message_type") == "ready_to_start"
                    ):
                        if start_barrier is None:
                            raise RuntimeError("LIVE_EXPLORER_START_BARRIER_MISSING")
                        start_barrier.wait(timeout=300.0)
                        start_command = {
                            "schema_version": PROTOCOL_VERSION,
                            "message_type": "start",
                            "session_id": hello["session_id"],
                            "command_id": "probe_coordinated_start",
                        }
                        connection.sendall(
                            (
                                json.dumps(start_command, separators=(",", ":"))
                                + "\n"
                            ).encode("utf-8")
                        )
                    if (
                        kick
                        and not kick_sent
                        and message.get("message_type") == "frame"
                        and message.get("frame_index") == 720
                    ):
                        command = {
                            "schema_version": PROTOCOL_VERSION,
                            "message_type": "apply_impulse",
                            "session_id": hello["session_id"],
                            "command_id": "probe_kick_750",
                            "target_body_id": "torso",
                            "apply_at_frame": 750,
                            "impulse_n_s": {"x": 0.0, "y": 0.0, "z": 3.5},
                        }
                        connection.sendall(
                            (json.dumps(command, separators=(",", ":")) + "\n").encode(
                                "utf-8"
                            )
                        )
                        kick_sent = True
    except ConnectionResetError as error:
        record = records.get(engine_id)
        terminal_count = (
            sum(
                message.get("message_type") == "completed"
                for message in record.messages
            )
            if record is not None
            else 0
        )
        if terminal_count != 1:
            if record is not None:
                record.error = f"{type(error).__name__}:{error}"
            else:
                records[engine_id] = StreamRecord(
                    engine_id=engine_id,
                    error=f"{type(error).__name__}:{error}",
                )
    except BaseException as error:
        if engine_id in records:
            records[engine_id].error = f"{type(error).__name__}:{error}"
        else:
            records[engine_id] = StreamRecord(
                engine_id=engine_id,
                error=f"{type(error).__name__}:{error}",
            )


def _torso_x(frame: dict[str, Any]) -> float:
    torso = next(
        body for body in frame.get("ordered_bodies", []) if body.get("body_id") == "torso"
    )
    return float(torso["position_m"]["x"])


def _validate_stream(
    record: StreamRecord,
    validate_only: bool,
    realtime: bool,
    kick: bool,
    coordinated_start: bool,
    source_commit: str | None,
) -> dict[str, Any]:
    if record.error:
        raise RuntimeError(f"{record.engine_id}:{record.error}")
    if not record.messages:
        raise RuntimeError(f"{record.engine_id}:LIVE_EXPLORER_MESSAGES_MISSING")
    hello = record.messages[0]
    if (
        hello.get("schema_version") != PROTOCOL_VERSION
        or hello.get("message_type") != "hello"
        or hello.get("native_physics") is not True
        or hello.get("replay") is not False
        or hello.get("scientific_evidence_authority") is not False
        or hello.get("physics_hz") != 120
        or hello.get("source_commit") != source_commit
    ):
        raise RuntimeError(f"{record.engine_id}:LIVE_EXPLORER_HELLO_INVALID")
    completed = [
        message for message in record.messages if message.get("message_type") == "completed"
    ]
    errors = [message for message in record.messages if message.get("message_type") == "error"]
    frames = [message for message in record.messages if message.get("message_type") == "frame"]
    if len(completed) != 1 or errors:
        raise RuntimeError(
            f"{record.engine_id}:LIVE_EXPLORER_TERMINAL_MESSAGE_INVALID:"
            f"completed={len(completed)} errors={len(errors)}"
        )
    terminal = completed[0]
    if terminal.get("ok") is not True or terminal.get("replay") is not False:
        raise RuntimeError(f"{record.engine_id}:LIVE_EXPLORER_COMPLETION_INVALID")
    if terminal.get("scientific_evidence_authority") is not False:
        raise RuntimeError(f"{record.engine_id}:LIVE_EXPLORER_AUTHORITY_INFLATION")

    if validate_only:
        if (
            frames
            or terminal.get("frame_count") != 0
            or terminal.get("native_physics") is not False
        ):
            raise RuntimeError(f"{record.engine_id}:LIVE_EXPLORER_PREFLIGHT_OPENED_WORLD")
        summary = terminal.get("summary", {})
        if summary.get("world_build_count") != 0:
            raise RuntimeError(f"{record.engine_id}:LIVE_EXPLORER_PREFLIGHT_WORLD_COUNT_INVALID")
        return {
            "engine_id": record.engine_id,
            "engine_version": hello.get("engine_version"),
            "preflight": True,
            "frames": 0,
        }

    ready_messages = [
        message
        for message in record.messages
        if message.get("message_type") == "ready_to_start"
    ]
    started_messages = [
        message for message in record.messages if message.get("message_type") == "started"
    ]
    if coordinated_start:
        if len(ready_messages) != 1 or len(started_messages) != 1:
            raise RuntimeError(
                f"{record.engine_id}:LIVE_EXPLORER_COORDINATED_START_INVALID:"
                f"ready={len(ready_messages)} started={len(started_messages)}"
            )
    elif ready_messages or started_messages:
        raise RuntimeError(f"{record.engine_id}:LIVE_EXPLORER_UNEXPECTED_START_GATE")

    expected_frames = 3172 if record.engine_id == "rapier_parry" else 2992
    expected_streamed_frames = (
        expected_frames
        if record.engine_id == "rapier_parry"
        else 1 + expected_frames // 4 + (1 if kick else 0)
    )
    if (
        len(frames) != expected_streamed_frames
        or terminal.get("frame_count") != expected_frames
        or terminal.get("streamed_frame_count", len(frames)) != expected_streamed_frames
    ):
        raise RuntimeError(
            f"{record.engine_id}:LIVE_EXPLORER_FRAME_COUNT_INVALID:"
            f"stream={len(frames)}/{expected_streamed_frames} "
            f"physics={terminal.get('frame_count')}/{expected_frames}"
        )
    if terminal.get("native_physics") is not True:
        raise RuntimeError(f"{record.engine_id}:LIVE_EXPLORER_NATIVE_PHYSICS_MISSING")
    if any(
        frame.get("native_physics") is not True or frame.get("replay") is not False
        for frame in frames
    ):
        raise RuntimeError(f"{record.engine_id}:LIVE_EXPLORER_FRAME_PROVENANCE_INVALID")
    displacement = _torso_x(frames[-1]) - _torso_x(frames[0])
    if not displacement > 0.5:
        raise RuntimeError(
            f"{record.engine_id}:LIVE_EXPLORER_TORSO_DID_NOT_ADVANCE:{displacement}"
        )
    physics_wall_time = float(terminal.get("physics_wall_time_s", 0.0))
    simulation_time = expected_frames / 120.0
    realtime_ratio = simulation_time / physics_wall_time if physics_wall_time > 0.0 else 0.0
    if realtime and not 0.90 <= realtime_ratio <= 1.10:
        raise RuntimeError(
            f"{record.engine_id}:LIVE_EXPLORER_REALTIME_RATIO_INVALID:{realtime_ratio}"
        )
    kick_applied = False
    if kick:
        scheduled = [
            message
            for message in record.messages
            if message.get("message_type") == "command_scheduled"
            and message.get("command_id") == "probe_kick_750"
        ]
        target_frames = [frame for frame in frames if frame.get("frame_index") == 750]
        kick_applied = (
            len(scheduled) == 1
            and len(target_frames) == 1
            and any(
                receipt.get("command_id") == "probe_kick_750"
                for receipt in target_frames[0].get("applied_impulses", [])
            )
        )
        if not kick_applied:
            raise RuntimeError(f"{record.engine_id}:LIVE_EXPLORER_KICK_NOT_APPLIED")
    return {
        "engine_id": record.engine_id,
        "engine_version": hello.get("engine_version"),
        "preflight": False,
        "frames": expected_frames,
        "streamed_frames": expected_streamed_frames,
        "torso_forward_displacement_m": displacement,
        "physics_wall_time_s": physics_wall_time,
        "simulation_to_wall_ratio": realtime_ratio,
        "outcome": terminal.get("outcome"),
        "kick_applied": kick_applied,
        "coordinated_start": coordinated_start,
    }


def main() -> int:
    arguments = _arguments()
    repo_root = Path(__file__).resolve().parents[2]
    mujoco_root = repo_root / "sdk" / "adapters" / "mujoco"
    for path in (arguments.rapier_worker, arguments.mujoco_python):
        if not path.is_file():
            raise FileNotFoundError(path)

    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", 0))
    listener.listen(2)
    listener.settimeout(20.0)
    address = f"127.0.0.1:{listener.getsockname()[1]}"
    session_stem = f"probe_{int(time.time() * 1000)}"
    common_mode = (
        ["--validate-only"]
        if arguments.validate_only
        else ["--source-commit", arguments.source_commit]
    )
    realtime = ["--realtime"] if arguments.realtime else []
    wait_for_start = ["--wait-for-start"] if arguments.coordinated_start else []
    creation_flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    processes = [
        subprocess.Popen(
            [
                str(arguments.rapier_worker),
                "--connect",
                address,
                "--session",
                f"{session_stem}_rapier",
                *common_mode,
                *realtime,
                *wait_for_start,
            ],
            cwd=repo_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            creationflags=creation_flags,
        ),
        subprocess.Popen(
            [
                str(arguments.mujoco_python),
                "-m",
                "sporespore_mujoco_adapter.live_explorer_worker",
                "--connect",
                address,
                "--session",
                f"{session_stem}_mujoco",
                *common_mode,
                *realtime,
                *wait_for_start,
            ],
            cwd=mujoco_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            creationflags=creation_flags,
        ),
    ]
    records: dict[str, StreamRecord] = {}
    threads: list[threading.Thread] = []
    start_barrier = threading.Barrier(2) if arguments.coordinated_start else None
    deadline = time.monotonic() + arguments.timeout_s
    try:
        for _index in range(2):
            connection, _peer = listener.accept()
            thread = threading.Thread(
                target=_reader,
                args=(
                    connection,
                    records,
                    arguments.kick,
                    arguments.coordinated_start,
                    start_barrier,
                ),
                daemon=True,
            )
            thread.start()
            threads.append(thread)
        for thread in threads:
            remaining = deadline - time.monotonic()
            if remaining <= 0.0:
                raise TimeoutError("LIVE_EXPLORER_STREAM_TIMEOUT")
            thread.join(remaining)
            if thread.is_alive():
                raise TimeoutError("LIVE_EXPLORER_STREAM_TIMEOUT")
        process_results = []
        for process in processes:
            remaining = max(0.1, deadline - time.monotonic())
            stdout, stderr = process.communicate(timeout=remaining)
            process_results.append((process.returncode, stdout, stderr))
        failures = [
            f"process[{index}] exit={code} stdout={stdout!r} stderr={stderr!r}"
            for index, (code, stdout, stderr) in enumerate(process_results)
            if code != 0
        ]
        if failures:
            raise RuntimeError("; ".join(failures))
        if set(records) != EXPECTED_ENGINES:
            raise RuntimeError(f"LIVE_EXPLORER_ENGINE_SET_INVALID:{sorted(records)}")
        summaries = [
            _validate_stream(
                records[engine_id],
                arguments.validate_only,
                arguments.realtime,
                arguments.kick,
                arguments.coordinated_start,
                arguments.source_commit,
            )
            for engine_id in sorted(EXPECTED_ENGINES)
        ]
        print(
            "LOCOMOTION_LIVE_EXPLORER_NATIVE_PROBE_PASS "
            + json.dumps(
                {
                    "mode": "preflight" if arguments.validate_only else "physical",
                    "realtime": arguments.realtime,
                    "kick": arguments.kick,
                    "coordinated_start": arguments.coordinated_start,
                    "engines": summaries,
                    "scientific_evidence_authority": False,
                },
                separators=(",", ":"),
            )
        )
        return 0
    finally:
        listener.close()
        for process in processes:
            if process.poll() is None:
                process.terminate()
        for process in processes:
            if process.poll() is None:
                try:
                    process.wait(timeout=5.0)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5.0)


if __name__ == "__main__":
    try:
        exit_code = main()
    except Exception as error:
        print(
            "LOCOMOTION_LIVE_EXPLORER_NATIVE_PROBE_ERROR "
            f"{type(error).__name__}:{error}",
            file=sys.stderr,
        )
        raise SystemExit(1)
    raise SystemExit(exit_code)
