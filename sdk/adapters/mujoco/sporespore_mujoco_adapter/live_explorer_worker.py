"""Live, non-authoritative MuJoCo worker for the SporeSpore Explorer.

The worker wraps the existing MV6 host application at runtime.  It does not
edit the frozen MV6 implementation, retain a campaign report, or grant evidence
authority.  Every emitted frame is sampled from the fresh native ``MjData``
immediately after the real five-substep actuator application.
"""

from __future__ import annotations

import argparse
import json
import math
import queue
import socket
import sys
import threading
import time
from typing import Any

import mujoco
import numpy as np

from . import selected_policy_development as bridge
from . import selected_policy_pose_hold_restoration_mv6 as mv6


PROTOCOL_VERSION = "sporespore_live_explorer_protocol_v1"
PHYSICS_HZ = 120
STREAM_HZ = 30
STREAM_STRIDE = PHYSICS_HZ // STREAM_HZ


class LiveTransport:
    def __init__(
        self,
        connect_address: str,
        session_id: str,
        realtime: bool,
        wait_for_start: bool,
        source_commit: str | None,
    ) -> None:
        if (
            not session_id
            or len(session_id) > 96
            or any(not (character.isalnum() or character in "-_") for character in session_id)
        ):
            raise ValueError("LIVE_EXPLORER_SESSION_ID_INVALID")
        host, separator, port_text = connect_address.rpartition(":")
        if not separator or not host or not port_text.isdigit():
            raise ValueError("LIVE_EXPLORER_CONNECT_ADDRESS_INVALID")
        self.socket = socket.create_connection((host, int(port_text)), timeout=10.0)
        # The timeout bounds connection establishment only. Explorer preflights
        # intentionally run longer than ten seconds with no inbound commands.
        self.socket.settimeout(None)
        self.socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.writer = self.socket.makefile("w", encoding="utf-8", newline="\n")
        self.reader = self.socket.makefile("r", encoding="utf-8", newline="\n")
        self.command_queue: queue.Queue[dict[str, Any] | BaseException] = queue.Queue()
        self.session_id = session_id
        self.realtime = realtime
        self.frame_index = 0
        self.streamed_frame_count = 0
        self.connected_at = time.perf_counter()
        self.physics_started_at: float | None = None
        self.scene_sent = False
        self.pending_impulses: list[dict[str, Any]] = []
        self.wait_for_start_gate = wait_for_start
        self.start_gate_satisfied = not wait_for_start
        self.source_commit = source_commit
        self.reader_thread = threading.Thread(target=self._read_commands, daemon=True)
        self.reader_thread.start()

    def _read_commands(self) -> None:
        try:
            for line in self.reader:
                if line.strip():
                    value = json.loads(line)
                    if not isinstance(value, dict):
                        raise TypeError("LIVE_EXPLORER_COMMAND_NOT_OBJECT")
                    self.command_queue.put(value)
        except BaseException as error:
            self.command_queue.put(error)

    def send(self, message: dict[str, Any]) -> None:
        self.writer.write(json.dumps(message, separators=(",", ":"), allow_nan=False))
        self.writer.write("\n")
        self.writer.flush()

    def hello(self) -> None:
        self.send(
            {
                "schema_version": PROTOCOL_VERSION,
                "message_type": "hello",
                "session_id": self.session_id,
                "engine_id": "mujoco",
                "engine_name": "MuJoCo",
                "engine_version": mujoco.__version__,
                "native_physics": True,
                "replay": False,
                "development_authority": True,
                "scientific_evidence_authority": False,
                "physics_hz": 120,
                "stream_hz": STREAM_HZ,
                "native_substeps_per_outer_step": bridge.INTERNAL_STEPS_PER_OUTER,
                "realtime_pacing_requested": self.realtime,
                "source_commit": self.source_commit,
                "command_capabilities": {
                    "scheduled_canonical_torso_impulse": True,
                    "coordinated_start_gate": True,
                    "maximum_impulse_magnitude_n_s": 8.0,
                    "native_application": "xfrc_applied_over_outer_step",
                },
            }
        )

    def wait_for_start(self) -> None:
        if not self.wait_for_start_gate or self.start_gate_satisfied:
            return
        self.send(
            {
                "schema_version": PROTOCOL_VERSION,
                "message_type": "ready_to_start",
                "session_id": self.session_id,
                "engine_id": "mujoco",
                "native_physics": True,
                "replay": False,
                "scientific_evidence_authority": False,
            }
        )
        try:
            value = self.command_queue.get(timeout=300.0)
        except queue.Empty as error:
            raise RuntimeError("LIVE_EXPLORER_START_GATE_TIMEOUT") from error
        if isinstance(value, BaseException):
            raise RuntimeError(f"LIVE_EXPLORER_START_GATE_STREAM_FAILED:{value}")
        if (
            value.get("schema_version") != PROTOCOL_VERSION
            or value.get("message_type") != "start"
            or value.get("session_id") != self.session_id
        ):
            raise RuntimeError("LIVE_EXPLORER_START_ENVELOPE_INVALID")
        self.start_gate_satisfied = True
        self.send(
            {
                "schema_version": PROTOCOL_VERSION,
                "message_type": "started",
                "session_id": self.session_id,
                "engine_id": "mujoco",
                "native_physics": True,
                "replay": False,
                "scientific_evidence_authority": False,
            }
        )

    def scene(self, robot: bridge.MujocoBw19vRobot) -> None:
        if self.scene_sent:
            raise RuntimeError("LIVE_EXPLORER_MUJOCO_DUPLICATE_SCENE")
        self.scene_sent = True
        self.send(
            {
                "schema_version": PROTOCOL_VERSION,
                "message_type": "scene",
                "session_id": self.session_id,
                "engine_id": "mujoco",
                "native_physics": True,
                "replay": False,
                "scene": {
                    "descriptor": robot.descriptor,
                    "morphology_spec": robot.spec,
                    "coordinate_frame": "canonical_x_forward_y_up_z_right",
                },
            }
        )

    def take_due_impulses(self) -> list[dict[str, Any]]:
        while True:
            try:
                value = self.command_queue.get_nowait()
            except queue.Empty:
                break
            if isinstance(value, BaseException):
                raise RuntimeError(f"LIVE_EXPLORER_COMMAND_STREAM_FAILED:{value}")
            if (
                value.get("schema_version") != PROTOCOL_VERSION
                or value.get("message_type") != "apply_impulse"
                or value.get("session_id") != self.session_id
            ):
                raise RuntimeError("LIVE_EXPLORER_IMPULSE_ENVELOPE_INVALID")
            command_id = value.get("command_id")
            if (
                not isinstance(command_id, str)
                or not command_id
                or len(command_id) > 96
                or any(
                    not (character.isalnum() or character in "-_")
                    for character in command_id
                )
            ):
                raise RuntimeError("LIVE_EXPLORER_IMPULSE_COMMAND_ID_INVALID")
            if value.get("target_body_id") != "torso":
                raise RuntimeError("LIVE_EXPLORER_IMPULSE_ONLY_TORSO_SUPPORTED")
            apply_at_frame = value.get("apply_at_frame")
            if not isinstance(apply_at_frame, int) or apply_at_frame <= self.frame_index:
                raise RuntimeError("LIVE_EXPLORER_IMPULSE_FRAME_INVALID")
            vector = value.get("impulse_n_s")
            if not isinstance(vector, dict):
                raise RuntimeError("LIVE_EXPLORER_IMPULSE_VECTOR_INVALID")
            components = [vector.get(axis) for axis in ("x", "y", "z")]
            if any(
                not isinstance(component, (float, int))
                or isinstance(component, bool)
                or not math.isfinite(float(component))
                for component in components
            ):
                raise RuntimeError("LIVE_EXPLORER_IMPULSE_COMPONENT_INVALID")
            magnitude = math.sqrt(sum(float(component) ** 2 for component in components))
            if magnitude <= sys.float_info.epsilon or magnitude > 8.0:
                raise RuntimeError("LIVE_EXPLORER_IMPULSE_MAGNITUDE_OUT_OF_BOUNDS")
            pending = {
                "command_id": command_id,
                "target_body_id": "torso",
                "apply_at_frame": apply_at_frame,
                "impulse_n_s": {
                    axis: float(vector[axis]) for axis in ("x", "y", "z")
                },
            }
            self.pending_impulses.append(pending)
            self.pending_impulses.sort(key=lambda impulse: impulse["apply_at_frame"])
            self.send(
                {
                    "schema_version": PROTOCOL_VERSION,
                    "message_type": "command_scheduled",
                    "session_id": self.session_id,
                    "engine_id": "mujoco",
                    "command_id": command_id,
                    "apply_at_frame": apply_at_frame,
                    "scientific_evidence_authority": False,
                }
            )
        next_frame = self.frame_index + 1
        split = 0
        while (
            split < len(self.pending_impulses)
            and self.pending_impulses[split]["apply_at_frame"] <= next_frame
        ):
            split += 1
        due = self.pending_impulses[:split]
        del self.pending_impulses[:split]
        if any(impulse["apply_at_frame"] != next_frame for impulse in due):
            raise RuntimeError("LIVE_EXPLORER_IMPULSE_SCHEDULE_MISSED")
        return due

    def frame(
        self,
        robot: bridge.MujocoBw19vRobot,
        applied_impulses: list[dict[str, Any]],
    ) -> None:
        now = time.perf_counter()
        if self.physics_started_at is None:
            self.physics_started_at = now
        self.frame_index += 1
        should_stream = (
            self.frame_index == 1
            or self.frame_index % STREAM_STRIDE == 0
            or bool(applied_impulses)
        )
        if should_stream:
            ordered_bodies: list[dict[str, Any]] = []
            ordered_contacts: list[dict[str, Any]] = []
            for body_id in robot.morphology["ordered_body_ids"]:
                pose, twist = robot._body_pose_twist(body_id)
                ordered_bodies.append(
                    {
                        "body_id": body_id,
                        **pose,
                        **twist,
                    }
                )
                contact = robot._contact({"body_id": body_id})
                ordered_contacts.append(
                    {
                        "body_id": body_id,
                        "present": bool(contact["present"]),
                    }
                )
            physics_wall_time = now - self.physics_started_at
            self.streamed_frame_count += 1
            self.send(
                {
                    "schema_version": PROTOCOL_VERSION,
                    "message_type": "frame",
                    "session_id": self.session_id,
                    "engine_id": "mujoco",
                    "native_physics": True,
                    "replay": False,
                    "frame_index": self.frame_index,
                    "simulation_time_s": self.frame_index / PHYSICS_HZ,
                    "wall_time_s": time.perf_counter() - self.connected_at,
                    "physics_wall_time_s": physics_wall_time,
                    "ordered_bodies": ordered_bodies,
                    "ordered_body_ground_contacts": ordered_contacts,
                    "applied_impulses": applied_impulses,
                }
            )
        if self.realtime:
            target = self.physics_started_at + self.frame_index / PHYSICS_HZ
            remaining = target - time.perf_counter()
            if remaining > 0.0:
                time.sleep(remaining)

    def completed(
        self,
        ok: bool,
        outcome: str,
        summary: dict[str, Any],
    ) -> None:
        physics_wall_time = (
            0.0
            if self.physics_started_at is None
            else time.perf_counter() - self.physics_started_at
        )
        self.send(
            {
                "schema_version": PROTOCOL_VERSION,
                "message_type": "completed",
                "session_id": self.session_id,
                "engine_id": "mujoco",
                "native_physics": self.frame_index > 0,
                "replay": False,
                "ok": ok,
                "outcome": outcome,
                "frame_count": self.frame_index,
                "streamed_frame_count": self.streamed_frame_count,
                "wall_time_s": time.perf_counter() - self.connected_at,
                "physics_wall_time_s": physics_wall_time,
                "scientific_evidence_authority": False,
                "summary": summary,
            }
        )

    def error(self, error: BaseException) -> None:
        self.send(
            {
                "schema_version": PROTOCOL_VERSION,
                "message_type": "error",
                "session_id": self.session_id,
                "engine_id": "mujoco",
                "native_physics": self.frame_index > 0,
                "replay": False,
                "error": f"{type(error).__name__}:{error}",
                "frame_count": self.frame_index,
                "scientific_evidence_authority": False,
            }
        )

    def close(self) -> None:
        # Wake the blocking command reader before closing either file wrapper;
        # closing the wrapper first can wait on the reader's internal lock.
        try:
            self.socket.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        self.reader_thread.join(timeout=2.0)
        for stream in (self.writer, self.reader):
            try:
                stream.close()
            except OSError:
                pass
        self.socket.close()


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--connect", required=True)
    parser.add_argument("--session", required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--validate-only", action="store_true")
    mode.add_argument("--source-commit")
    parser.add_argument("--realtime", action="store_true")
    parser.add_argument("--wait-for-start", action="store_true")
    arguments = parser.parse_args()
    if arguments.validate_only and arguments.realtime:
        parser.error("--realtime is invalid with --validate-only")
    if arguments.validate_only and arguments.wait_for_start:
        parser.error("--wait-for-start is invalid with --validate-only")
    if arguments.source_commit is not None and (
        len(arguments.source_commit) != 40
        or any(
            character not in "0123456789abcdefABCDEF"
            for character in arguments.source_commit
        )
    ):
        parser.error("--source-commit must be a full 40-hex Git object ID")
    return arguments


def _run(arguments: argparse.Namespace, transport: LiveTransport) -> None:
    transport.hello()
    if arguments.validate_only:
        preflight = mv6.run_preflight()
        ok = bool(preflight.get("ok")) and preflight.get("world_build_count") == 0
        transport.completed(ok, "preflight_only", preflight)
        if not ok:
            raise RuntimeError("LIVE_EXPLORER_MUJOCO_PREFLIGHT_FAILED")
        return

    original_init = bridge.MujocoBw19vRobot.__init__
    original_apply = bridge.MujocoBw19vRobot.apply_host_mapping

    def live_init(robot: bridge.MujocoBw19vRobot, *args: Any, **kwargs: Any) -> None:
        original_init(robot, *args, **kwargs)
        transport.scene(robot)

    def live_apply(
        robot: bridge.MujocoBw19vRobot,
        mapping: dict[str, Any],
    ) -> dict[str, Any]:
        transport.wait_for_start()
        due = transport.take_due_impulses()
        previous_external_force = None
        applied_impulses: list[dict[str, Any]] = []
        if due:
            torso = robot.model.body("torso").id
            previous_external_force = np.asarray(
                robot.data.xfrc_applied[torso], dtype=np.float64
            ).copy()
            canonical_impulse = np.sum(
                [
                    [
                        impulse["impulse_n_s"]["x"],
                        impulse["impulse_n_s"]["y"],
                        impulse["impulse_n_s"]["z"],
                    ]
                    for impulse in due
                ],
                axis=0,
                dtype=np.float64,
            )
            canonical_force = canonical_impulse / bridge.CONTROLLER_DT_S
            robot.data.xfrc_applied[torso, :3] += bridge._canonical_to_mujoco(
                canonical_force
            )
            for impulse in due:
                applied_impulses.append(
                    {
                        **impulse,
                        "native_application": "xfrc_applied_over_outer_step",
                        "outer_step_duration_s": bridge.CONTROLLER_DT_S,
                    }
                )
        try:
            result = original_apply(robot, mapping)
        finally:
            if previous_external_force is not None:
                robot.data.xfrc_applied[torso] = previous_external_force
        transport.frame(robot, applied_impulses)
        return result

    bridge.MujocoBw19vRobot.__init__ = live_init
    bridge.MujocoBw19vRobot.apply_host_mapping = live_apply
    try:
        report = mv6.run_campaign(arguments.source_commit)
    finally:
        bridge.MujocoBw19vRobot.__init__ = original_init
        bridge.MujocoBw19vRobot.apply_host_mapping = original_apply

    report_ok = bool(report.get("ok"))
    transport.completed(
        True,
        "positive" if report_ok else "negative",
        {
            "walking": report_ok,
            "trace_step_count": report.get("trace_step_count"),
            "metrics": report.get("metrics"),
            "gate_failures": report.get("gate_failures"),
            "development_authority": True,
            "scientific_evidence_authority": False,
        },
    )


def main() -> int:
    arguments = _arguments()
    transport: LiveTransport | None = None
    try:
        transport = LiveTransport(
            arguments.connect,
            arguments.session,
            arguments.realtime,
            arguments.wait_for_start,
            arguments.source_commit,
        )
        _run(arguments, transport)
        return 0
    except BaseException as error:
        if transport is not None:
            try:
                transport.error(error)
            except BaseException:
                pass
        print(f"{type(error).__name__}:{error}", file=sys.stderr)
        return 1
    finally:
        if transport is not None:
            transport.close()


if __name__ == "__main__":
    raise SystemExit(main())
