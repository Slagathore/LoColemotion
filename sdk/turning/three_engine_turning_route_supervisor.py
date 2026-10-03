"""Serialized supervisor for the bounded three-engine turning route.

The supervisor has two deliberately separate jobs:

* ``preflight`` exercises every production entrypoint and its authorization
  refusal without constructing a physics world.
* ``run`` repeats that complete zero-world gate from an exact clean, pushed
  source, freezes one append-only development attempt, proves every worker
  accepts the freeze before model construction, and only then opens the three
  declared native worlds in order.

This is development-route evidence.  It applies no locomotion threshold and
cannot authorize turning, cross-engine equivalence, QSDK-R23, or a release.
"""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import importlib.metadata
import json
import os
import platform
import queue
import secrets
import shutil
import subprocess
import sys
import threading
import time
import uuid
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
TURNING_ROOT = REPO_ROOT / "sdk/turning"
CONTRACT_PATH = TURNING_ROOT / "three_engine_turning_success_transport_route_v2.json"
EVALUATOR_PATH = TURNING_ROOT / "three_engine_turning_route_evaluator.py"
SUPERVISOR_PATH = Path(__file__).resolve()
GODOT_WORKER_PATH = REPO_ROOT / "tests/test_sdk_turning_three_engine_route_godot_jolt_worker.gd"
RAPIER_ROOT = REPO_ROOT / "sdk/adapters/rapier"
RAPIER_SOURCE_PATH = RAPIER_ROOT / "src/turning_three_engine_route.rs"
RAPIER_BIN_SOURCE_PATH = RAPIER_ROOT / "src/bin/turning_three_engine_route.rs"
RAPIER_BINARY_PATH = REPO_ROOT / "sdk/target/debug/turning_three_engine_route.exe"
MUJOCO_ROOT = REPO_ROOT / "sdk/adapters/mujoco"
MUJOCO_WORKER_PATH = (
    MUJOCO_ROOT
    / "sporespore_mujoco_adapter/turning_three_engine_route.py"
)
OPERATION_LOCK_SOURCE_PATH = REPO_ROOT / "sdk/locomotion_operation_lock.ps1"
DEFAULT_EVIDENCE_ROOT = REPO_ROOT.parent / "SporeSpore_Evidence"
DEFAULT_GODOT = Path(
    r"C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
)
DEFAULT_MUJOCO_PYTHON = MUJOCO_ROOT / ".venv/Scripts/python.exe"
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EXPECTED_BRANCH = "main"
ROUTE_ENV_PREFIX = "SPORESPORE_TURNING_ROUTE_"
GODOT_SUPERVISED_TERMINATION_ENV = "SPORESPORE_QSDK_R23D65_SUPERVISED_TERMINATION"
GODOT_TERMINATION_NONCE_ENV = "SPORESPORE_QSDK_R23D65_TERMINATION_NONCE"
GODOT_READY_MARKER = "QSDK_R23D65_GODOT_SUPERVISOR_TERMINATION_READY "
OPERATION_MUTEX_NAME = r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"

SUPERVISOR_PREFLIGHT_MARKER = "SPORESPORE_TURNING_ROUTE_SUPERVISOR_PREFLIGHT "
SUPERVISOR_RESULT_MARKER = "SPORESPORE_TURNING_ROUTE_SUPERVISOR_RESULT "
SUPERVISOR_ERROR_MARKER = "SPORESPORE_TURNING_ROUTE_SUPERVISOR_ERROR "

FREEZE_SCHEMA = "sporespore_three_engine_turning_success_transport_freeze_v2"
ATTEMPT_SCHEMA = "sporespore_three_engine_turning_success_transport_attempt_v2"
WORKER_FAILURE_SCHEMA = (
    "sporespore_three_engine_turning_success_transport_worker_failure_v2"
)
CELL_REPORT_SCHEMA = (
    "sporespore_three_engine_turning_success_transport_cell_report_v2"
)


class RouteSupervisorError(RuntimeError):
    """A fail-closed production-route or evidence-integrity error."""


def _load_contract() -> dict[str, Any]:
    try:
        value = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_CONTRACT_UNREADABLE:{type(error).__name__}"
        ) from error
    if not isinstance(value, dict):
        raise RouteSupervisorError("TURNING_ROUTE_SUPERVISOR_CONTRACT_NOT_OBJECT")
    return value


CONTRACT = _load_contract()
ROUTE_ID = str(CONTRACT["route_id"])
GHOST = CONTRACT["development_ghost"]
ENGINE_IDS = tuple(str(value) for value in GHOST["ordered_engine_ids"])
DEVELOPMENT_SEED = int(GHOST["development_seed"])
ARM_ID = str(GHOST["arm_id"])
LEDGER_SCOPE = dict(CONTRACT["ledger_scope"])


def expected_cell_id(engine_id: str) -> str:
    if engine_id not in ENGINE_IDS:
        raise RouteSupervisorError(f"TURNING_ROUTE_SUPERVISOR_ENGINE_UNKNOWN:{engine_id}")
    return (
        f"turning_success_transport_v2__{engine_id}__"
        f"s{DEVELOPMENT_SEED}__{ARM_ID}"
    )


ORDERED_CELL_IDS = tuple(expected_cell_id(engine_id) for engine_id in ENGINE_IDS)


@dataclass(frozen=True)
class RuntimePaths:
    """Resolved applications used by the exact route invocation."""

    python_host: Path
    mujoco_python: Path
    godot: Path
    powershell: Path
    cargo: Path
    rapier_binary: Path = RAPIER_BINARY_PATH


@dataclass(frozen=True)
class WorkerSpec:
    engine_id: str
    cell_id: str
    cwd: Path
    preflight_command: tuple[str, ...]
    negative_physical_command: tuple[str, ...]
    authorization_command: tuple[str, ...]
    physical_command: tuple[str, ...]
    preflight_marker: str
    preflight_schema: str
    authorization_marker: str
    authorization_schema: str
    terminal_marker: str


ProcessRunner = Callable[..., dict[str, Any]]


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _sha256_file(path: Path) -> str:
    try:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return "sha256:" + digest.hexdigest()
    except OSError as error:
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_ARTIFACT_UNREADABLE:{path}:{type(error).__name__}"
        ) from error


def _artifact(path: Path) -> dict[str, Any]:
    resolved = path.absolute()
    if not resolved.is_file():
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_ARTIFACT_MISSING:{resolved}"
        )
    return {
        "path": str(resolved),
        "sha256": _sha256_file(resolved),
        "byte_length": resolved.stat().st_size,
    }


def _is_lower_hex(value: Any, length: int) -> bool:
    return (
        isinstance(value, str)
        and len(value) == length
        and all(character in "0123456789abcdef" for character in value)
    )


def _resolve_application(value: str | Path, label: str) -> Path:
    raw = str(value)
    candidate = Path(raw)
    if not candidate.is_absolute():
        located = shutil.which(raw)
        if located is None:
            raise RouteSupervisorError(
                f"TURNING_ROUTE_SUPERVISOR_APPLICATION_MISSING:{label}:{raw}"
            )
        candidate = Path(located)
    resolved = candidate.absolute()
    if not resolved.is_file():
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_APPLICATION_MISSING:{label}:{resolved}"
        )
    # Preserve the executable shim name.  In a rustup installation cargo.exe
    # may resolve to rustup.exe; executing the target path changes argv[0] and
    # makes ``build`` look like an invalid rustup toolchain selector.
    return resolved


def resolve_runtime_paths(arguments: argparse.Namespace) -> RuntimePaths:
    return RuntimePaths(
        python_host=_resolve_application(arguments.python_host, "python_host"),
        mujoco_python=_resolve_application(arguments.mujoco_python, "mujoco_python"),
        godot=_resolve_application(arguments.godot, "godot"),
        powershell=_resolve_application(arguments.powershell, "powershell"),
        cargo=_resolve_application(arguments.cargo, "cargo"),
        rapier_binary=Path(arguments.rapier_binary).resolve(),
    )


def _clean_worker_environment(additions: Mapping[str, str] | None = None) -> dict[str, str]:
    environment = {
        name: value
        for name, value in os.environ.items()
        if not name.startswith(ROUTE_ENV_PREFIX)
        and name
        not in {
            GODOT_SUPERVISED_TERMINATION_ENV,
            GODOT_TERMINATION_NONCE_ENV,
        }
    }
    environment["PYTHONUTF8"] = "1"
    if additions is not None:
        environment.update({str(name): str(value) for name, value in additions.items()})
    return environment


def _run_process(
    *,
    name: str,
    command: Sequence[str],
    cwd: Path,
    environment: Mapping[str, str],
    timeout_seconds: int,
) -> dict[str, Any]:
    started = _utc_now()
    try:
        completed = subprocess.run(
            [str(value) for value in command],
            cwd=cwd,
            env=dict(environment),
            capture_output=True,
            check=False,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout_seconds,
        )
        return {
            "name": name,
            "command": [str(value) for value in command],
            "cwd": str(cwd.resolve()),
            "exit_code": completed.returncode,
            "timed_out": False,
            "stdout": completed.stdout,
            "stderr": completed.stderr,
            "started_utc": started,
            "completed_utc": _utc_now(),
        }
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout or ""
        stderr = error.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        return {
            "name": name,
            "command": [str(value) for value in command],
            "cwd": str(cwd.resolve()),
            "exit_code": 124,
            "timed_out": True,
            "stdout": stdout,
            "stderr": stderr,
            "started_utc": started,
            "completed_utc": _utc_now(),
        }
    except OSError as error:
        return {
            "name": name,
            "command": [str(value) for value in command],
            "cwd": str(cwd.resolve()),
            "exit_code": 127,
            "timed_out": False,
            "stdout": "",
            "stderr": f"{type(error).__name__}:{error}",
            "started_utc": started,
            "completed_utc": _utc_now(),
        }


def _process_is_self_or_descendant(root_process_id: int, candidate_process_id: int) -> bool:
    if root_process_id <= 0 or candidate_process_id <= 0:
        return False
    if root_process_id == candidate_process_id:
        return True
    if os.name != "nt":
        return False
    from ctypes import wintypes

    class ProcessEntry32(ctypes.Structure):
        _fields_ = (
            ("dwSize", wintypes.DWORD),
            ("cntUsage", wintypes.DWORD),
            ("th32ProcessID", wintypes.DWORD),
            ("th32DefaultHeapID", ctypes.c_size_t),
            ("th32ModuleID", wintypes.DWORD),
            ("cntThreads", wintypes.DWORD),
            ("th32ParentProcessID", wintypes.DWORD),
            ("pcPriClassBase", wintypes.LONG),
            ("dwFlags", wintypes.DWORD),
            ("szExeFile", wintypes.WCHAR * 260),
        )

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateToolhelp32Snapshot.argtypes = (wintypes.DWORD, wintypes.DWORD)
    kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel32.Process32FirstW.argtypes = (wintypes.HANDLE, ctypes.POINTER(ProcessEntry32))
    kernel32.Process32FirstW.restype = wintypes.BOOL
    kernel32.Process32NextW.argtypes = (wintypes.HANDLE, ctypes.POINTER(ProcessEntry32))
    kernel32.Process32NextW.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)
    kernel32.CloseHandle.restype = wintypes.BOOL
    snapshot = kernel32.CreateToolhelp32Snapshot(0x00000002, 0)
    if not snapshot or snapshot == wintypes.HANDLE(-1).value:
        return False
    parents: dict[int, int] = {}
    try:
        entry = ProcessEntry32()
        entry.dwSize = ctypes.sizeof(ProcessEntry32)
        present = bool(kernel32.Process32FirstW(snapshot, ctypes.byref(entry)))
        while present:
            parents[int(entry.th32ProcessID)] = int(entry.th32ParentProcessID)
            present = bool(kernel32.Process32NextW(snapshot, ctypes.byref(entry)))
    finally:
        kernel32.CloseHandle(snapshot)
    current = candidate_process_id
    for _depth in range(16):
        if current == root_process_id:
            return True
        current = parents.get(current, 0)
        if current <= 0:
            return False
    return False


def _validate_godot_ready_receipt(
    value: Mapping[str, Any], *, nonce: str, process_id: int
) -> None:
    exact = (
        value.get("schema_version")
        == "sporespore_godot_supervised_termination_ready_v1"
        and value.get("termination_protocol_id")
        == "godot_4_7_gdscript_shutdown_containment_v1"
        and value.get("termination_nonce") == nonce
        and type(value.get("process_id")) is int
        and _process_is_self_or_descendant(process_id, int(value["process_id"]))
        and type(value.get("requested_exit_code")) is int
        and value.get("requested_exit_code") in {0, 1}
        and value.get("worker_receipt_emitted") is True
        and value.get("drained_process_frame_count") == 2
        and value.get("physics_evidence_authority") is False
    )
    if not exact:
        raise RouteSupervisorError(
            "TURNING_ROUTE_SUPERVISOR_GODOT_READY_BINDING_INVALID"
        )


def _terminate_process_tree(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return
    try:
        completed = subprocess.run(
            ["taskkill", "/PID", str(process.pid), "/T", "/F"],
            capture_output=True,
            check=False,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
        )
        if completed.returncode == 0:
            return
    except (OSError, subprocess.TimeoutExpired):
        pass
    try:
        process.kill()
    except OSError:
        pass


def _run_godot_receipt_terminated_process(
    *,
    name: str,
    command: Sequence[str],
    cwd: Path,
    environment: Mapping[str, str],
    timeout_seconds: int,
) -> dict[str, Any]:
    """Contain Godot 4.7 teardown after its bound terminal receipt."""

    started = _utc_now()
    nonce = secrets.token_hex(16)
    child_environment = dict(environment)
    child_environment[GODOT_SUPERVISED_TERMINATION_ENV] = "1"
    child_environment[GODOT_TERMINATION_NONCE_ENV] = nonce
    try:
        process = subprocess.Popen(
            [str(value) for value in command],
            cwd=cwd,
            env=child_environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
    except OSError as error:
        return {
            "name": name,
            "command": [str(value) for value in command],
            "cwd": str(cwd.resolve()),
            "exit_code": 127,
            "host_exit_code": 127,
            "timed_out": False,
            "stdout": "",
            "stderr": f"{type(error).__name__}:{error}",
            "started_utc": started,
            "completed_utc": _utc_now(),
            "supervisor_terminated": False,
            "termination_protocol_valid": False,
            "termination_protocol_failure_code": "GODOT_PROCESS_START_FAILED",
            "termination_ready_receipt": None,
        }

    stdout_lines: list[str] = []
    stderr_lines: list[str] = []
    ready_lines: queue.Queue[str] = queue.Queue()

    def read_stdout() -> None:
        assert process.stdout is not None
        for line in process.stdout:
            normalized = line.rstrip("\r\n")
            stdout_lines.append(normalized)
            if normalized.startswith(GODOT_READY_MARKER):
                ready_lines.put(normalized)

    def read_stderr() -> None:
        assert process.stderr is not None
        for line in process.stderr:
            stderr_lines.append(line.rstrip("\r\n"))

    stdout_thread = threading.Thread(target=read_stdout, daemon=True)
    stderr_thread = threading.Thread(target=read_stderr, daemon=True)
    stdout_thread.start()
    stderr_thread.start()
    deadline = time.monotonic() + timeout_seconds
    ready_receipt: dict[str, Any] | None = None
    protocol_failure = ""
    timed_out = False
    supervisor_terminated = False
    while time.monotonic() < deadline:
        try:
            ready_line = ready_lines.get(timeout=0.05)
        except queue.Empty:
            if process.poll() is not None:
                break
            continue
        try:
            ready_receipt = _marker_json(ready_line, GODOT_READY_MARKER)
            _validate_godot_ready_receipt(
                ready_receipt, nonce=nonce, process_id=process.pid
            )
        except RouteSupervisorError as error:
            protocol_failure = str(error)
            break
        _terminate_process_tree(process)
        supervisor_terminated = True
        break
    else:
        timed_out = True

    if process.poll() is None:
        _terminate_process_tree(process)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        protocol_failure = protocol_failure or "GODOT_PROCESS_TREE_DID_NOT_TERMINATE"
    stdout_thread.join(timeout=2)
    stderr_thread.join(timeout=2)
    ready_count = sum(line.startswith(GODOT_READY_MARKER) for line in stdout_lines)
    if ready_count != 1 and not protocol_failure:
        protocol_failure = f"GODOT_READY_MARKER_COUNT_INVALID:{ready_count}"
    protocol_valid = bool(
        not timed_out
        and not protocol_failure
        and ready_receipt is not None
        and supervisor_terminated
        and ready_count == 1
    )
    host_exit_code = process.returncode if process.returncode is not None else 124
    semantic_exit_code = (
        int(ready_receipt["requested_exit_code"])
        if protocol_valid and ready_receipt is not None
        else (124 if timed_out else host_exit_code)
    )
    return {
        "name": name,
        "command": [str(value) for value in command],
        "cwd": str(cwd.resolve()),
        "exit_code": semantic_exit_code,
        "host_exit_code": host_exit_code,
        "timed_out": timed_out,
        "stdout": "\n".join(stdout_lines) + ("\n" if stdout_lines else ""),
        "stderr": "\n".join(stderr_lines) + ("\n" if stderr_lines else ""),
        "started_utc": started,
        "completed_utc": _utc_now(),
        "process_id": process.pid,
        "worker_process_id": (
            int(ready_receipt.get("process_id", 0)) if ready_receipt is not None else 0
        ),
        "supervisor_terminated": supervisor_terminated,
        "termination_protocol_valid": protocol_valid,
        "termination_protocol_failure_code": protocol_failure,
        "termination_ready_receipt": ready_receipt,
    }


def _invoke_process(
    process_runner: ProcessRunner,
    *,
    godot: bool,
    name: str,
    command: Sequence[str],
    cwd: Path,
    environment: Mapping[str, str],
    timeout_seconds: int,
) -> dict[str, Any]:
    if godot and process_runner is _run_process:
        return _run_godot_receipt_terminated_process(
            name=name,
            command=command,
            cwd=cwd,
            environment=environment,
            timeout_seconds=timeout_seconds,
        )
    return process_runner(
        name=name,
        command=command,
        cwd=cwd,
        environment=environment,
        timeout_seconds=timeout_seconds,
    )


def _marker_json(stdout: str, marker: str) -> dict[str, Any]:
    matches = [line[len(marker) :] for line in stdout.splitlines() if line.startswith(marker)]
    if len(matches) != 1:
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_MARKER_COUNT_INVALID:{marker.strip()}:{len(matches)}"
        )
    try:
        value = json.loads(matches[0])
    except json.JSONDecodeError as error:
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_MARKER_JSON_INVALID:{marker.strip()}"
        ) from error
    if not isinstance(value, dict):
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_MARKER_VALUE_INVALID:{marker.strip()}"
        )
    return value


def _require_process_success(receipt: Mapping[str, Any], label: str) -> None:
    if receipt.get("exit_code") != 0 or receipt.get("timed_out") is not False:
        stdout = str(receipt.get("stdout", ""))[-2000:].replace("\r", " ").replace("\n", " ")
        stderr = str(receipt.get("stderr", ""))[-2000:].replace("\r", " ").replace("\n", " ")
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_PROCESS_FAILED:{label}:"
            f"exit={receipt.get('exit_code')}:timeout={receipt.get('timed_out')}:"
            f"stdout={stdout}:stderr={stderr}"
        )


def _validate_zero_counts(value: Mapping[str, Any], label: str) -> None:
    if any(
        type(value.get(field)) is not int or value.get(field) != 0
        for field in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
        )
    ):
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_ZERO_WORLD_COUNT_INVALID:{label}"
        )


def _worker_specs(runtime: RuntimePaths, source_commit: str) -> tuple[WorkerSpec, ...]:
    godot_prefix = (
        str(runtime.godot),
        "--headless",
        "--path",
        str(REPO_ROOT),
        "--script",
        "res://tests/test_sdk_turning_three_engine_route_godot_jolt_worker.gd",
        "--",
    )
    rapier_prefix = (str(runtime.rapier_binary),)
    mujoco_prefix = (
        str(runtime.mujoco_python),
        "-m",
        "sporespore_mujoco_adapter.turning_three_engine_route",
    )
    definitions = (
        (
            "godot_jolt",
            REPO_ROOT,
            godot_prefix + ("--preflight-only",),
            godot_prefix + ("--source-commit", source_commit),
            godot_prefix
            + ("--authorization-preflight-only", "--source-commit", source_commit),
            godot_prefix + ("--source-commit", source_commit),
            "SPORESPORE_TURNING_ROUTE_GODOT_PREFLIGHT ",
            "sporespore_three_engine_turning_success_transport_godot_jolt_preflight_v2",
            "SPORESPORE_TURNING_ROUTE_GODOT_AUTHORIZATION_PREFLIGHT ",
            "sporespore_three_engine_turning_success_transport_godot_authorization_v2",
            "SPORESPORE_TURNING_ROUTE_GODOT_TERMINAL ",
        ),
        (
            "rapier_parry",
            REPO_ROOT,
            rapier_prefix + ("--preflight-only",),
            rapier_prefix + ("--source-commit", source_commit),
            rapier_prefix
            + ("--authorization-preflight-only", "--source-commit", source_commit),
            rapier_prefix + ("--source-commit", source_commit),
            "SPORESPORE_TURNING_ROUTE_RAPIER_PREFLIGHT ",
            "sporespore_three_engine_turning_success_transport_rapier_preflight_v2",
            "SPORESPORE_TURNING_ROUTE_RAPIER_AUTHORIZATION_PREFLIGHT ",
            "sporespore_three_engine_turning_success_transport_rapier_authorization_v2",
            "SPORESPORE_TURNING_ROUTE_RAPIER_TERMINAL ",
        ),
        (
            "mujoco",
            MUJOCO_ROOT,
            mujoco_prefix + ("preflight",),
            mujoco_prefix + ("physical", "--source-commit", source_commit),
            mujoco_prefix
            + ("authorization-preflight", "--source-commit", source_commit),
            mujoco_prefix + ("physical", "--source-commit", source_commit),
            "SPORESPORE_TURNING_ROUTE_MUJOCO_PREFLIGHT ",
            "sporespore_three_engine_turning_success_transport_mujoco_preflight_v2",
            "SPORESPORE_TURNING_ROUTE_MUJOCO_AUTHORIZATION_PREFLIGHT ",
            "sporespore_three_engine_turning_success_transport_mujoco_authorization_v2",
            "SPORESPORE_TURNING_ROUTE_MUJOCO_TERMINAL ",
        ),
    )
    return tuple(
        WorkerSpec(
            engine_id=engine_id,
            cell_id=expected_cell_id(engine_id),
            cwd=cwd,
            preflight_command=preflight,
            negative_physical_command=negative,
            authorization_command=authorization,
            physical_command=physical,
            preflight_marker=preflight_marker,
            preflight_schema=preflight_schema,
            authorization_marker=authorization_marker,
            authorization_schema=authorization_schema,
            terminal_marker=terminal_marker,
        )
        for (
            engine_id,
            cwd,
            preflight,
            negative,
            authorization,
            physical,
            preflight_marker,
            preflight_schema,
            authorization_marker,
            authorization_schema,
            terminal_marker,
        ) in definitions
    )


def _validate_worker_preflight(spec: WorkerSpec, value: Mapping[str, Any]) -> None:
    expected_negative_control_count = 3 if spec.engine_id == "godot_jolt" else 2
    exact = (
        value.get("schema_version") == spec.preflight_schema
        and value.get("ok") is True
        and value.get("failure_code") == ""
        and value.get("route_id") == ROUTE_ID
        and value.get("ledger_scope") == LEDGER_SCOPE
        and value.get("engine_id") == spec.engine_id
        and value.get("cell_id") == spec.cell_id
        and value.get("campaign_seed") == DEVELOPMENT_SEED
        and value.get("controller_step_count") == int(GHOST["controller_step_count"])
        and value.get("nonzero_turn_command_compiled") is True
        and value.get("public_profile_route_compiled") is True
        and value.get("negative_control_count") == expected_negative_control_count
        and value.get("negative_controls_rejected") == expected_negative_control_count
        and (
            spec.engine_id != "godot_jolt"
            or value.get("integral_json_artifact_length_projection_checked") is True
        )
        and (
            spec.engine_id != "rapier_parry"
            or value.get("success_trace_retention_question_class_checked") is True
        )
        and value.get("physical_execution_authorized") is False
        and value.get("physical_behavior_thresholds_applied") is False
        and value.get("physical_acceptance_authority") is False
    )
    if not exact:
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_WORKER_PREFLIGHT_INVALID:{spec.engine_id}"
        )
    _validate_zero_counts(value, f"preflight:{spec.engine_id}")


def _validate_evaluator_preflight(value: Mapping[str, Any]) -> None:
    exact = (
        value.get("schema_version")
        == "sporespore_three_engine_turning_success_transport_evaluator_preflight_v2"
        and value.get("route_id") == ROUTE_ID
        and value.get("ledger_scope") == LEDGER_SCOPE
        and value.get("contract_raw_sha256") == _sha256_file(CONTRACT_PATH)
        and value.get("terminal_positive_control_count") == 3
        and value.get("terminal_negative_control_count") == 6
        and value.get("artifact_negative_control_count") == 8
        and value.get("negative_control_count") == 14
        and len(value.get("negative_controls_rejected", [])) == 6
        and len(value.get("artifact_negative_controls_rejected", [])) == 8
        and value.get("physical_behavior_thresholds_applied") is False
        and value.get("physical_acceptance_authority") is False
    )
    if not exact:
        raise RouteSupervisorError("TURNING_ROUTE_SUPERVISOR_EVALUATOR_PREFLIGHT_INVALID")
    _validate_zero_counts(value, "preflight:evaluator")


def _validate_negative_terminal(spec: WorkerSpec, value: Mapping[str, Any], source: str) -> None:
    claims = value.get("claims")
    exact = (
        value.get("schema_version") == WORKER_FAILURE_SCHEMA
        and value.get("route_id") == ROUTE_ID
        and value.get("engine_id") == spec.engine_id
        and value.get("cell_id") == spec.cell_id
        and value.get("campaign_seed") == DEVELOPMENT_SEED
        and value.get("source_commit") == source
        and isinstance(value.get("failure_code"), str)
        and "AUTHORIZATION" in str(value.get("failure_code"))
        and value.get("physical_behavior_thresholds_applied") is False
        and value.get("physical_acceptance_authority") is False
        and (
            claims is None
            or (
                isinstance(claims, Mapping)
                and all(claim is False for claim in claims.values())
            )
        )
    )
    if not exact:
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_AUTHORIZATION_NEGATIVE_INVALID:{spec.engine_id}"
        )
    _validate_zero_counts(value, f"authorization_negative:{spec.engine_id}")


def _dependency_artifacts(runtime: RuntimePaths) -> list[dict[str, Any]]:
    paths = [
        CONTRACT_PATH,
        EVALUATOR_PATH,
        SUPERVISOR_PATH,
        GODOT_WORKER_PATH,
        RAPIER_SOURCE_PATH,
        RAPIER_BIN_SOURCE_PATH,
        runtime.rapier_binary,
        MUJOCO_WORKER_PATH,
        OPERATION_LOCK_SOURCE_PATH,
        runtime.python_host,
        runtime.mujoco_python,
        runtime.godot,
        runtime.powershell,
        runtime.cargo,
    ]
    if "_console" in runtime.godot.stem:
        engine_path = runtime.godot.with_name(
            runtime.godot.name.replace("_console", "", 1)
        )
        if engine_path.is_file():
            paths.append(engine_path)
    unique: dict[str, Path] = {}
    for path in paths:
        unique.setdefault(os.path.normcase(str(path.absolute())), path)
    return [_artifact(path) for path in unique.values()]


def _package_version(name: str) -> str:
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return "not-installed-in-supervisor-host"


def run_complete_zero_world_gate(
    runtime: RuntimePaths,
    *,
    process_runner: ProcessRunner = _run_process,
    timeout_seconds: int = 600,
) -> dict[str, Any]:
    """Run the complete source-independent gate; never authorize physics."""

    source = "1" * 40
    records: list[dict[str, Any]] = []
    worker_negative_control_count = 0
    build = process_runner(
        name="rapier_build",
        command=(str(runtime.cargo), "build", "--quiet", "--bin", "turning_three_engine_route"),
        cwd=RAPIER_ROOT,
        environment=_clean_worker_environment(),
        timeout_seconds=timeout_seconds,
    )
    records.append(build)
    _require_process_success(build, "rapier_build")
    if not runtime.rapier_binary.is_file():
        raise RouteSupervisorError("TURNING_ROUTE_SUPERVISOR_RAPIER_BINARY_MISSING_AFTER_BUILD")

    evaluator = process_runner(
        name="evaluator_preflight",
        command=(str(runtime.python_host), str(EVALUATOR_PATH), "preflight"),
        cwd=REPO_ROOT,
        environment=_clean_worker_environment(),
        timeout_seconds=timeout_seconds,
    )
    records.append(evaluator)
    _require_process_success(evaluator, "evaluator_preflight")
    evaluator_preflight = _marker_json(
        str(evaluator["stdout"]),
        "SPORESPORE_TURNING_ROUTE_EVALUATOR_PREFLIGHT ",
    )
    _validate_evaluator_preflight(evaluator_preflight)
    evaluator_negative_count = int(evaluator_preflight["negative_control_count"])

    specs = _worker_specs(runtime, source)
    for spec in specs:
        receipt = _invoke_process(
            process_runner,
            godot=spec.engine_id == "godot_jolt",
            name=f"{spec.engine_id}_preflight",
            command=spec.preflight_command,
            cwd=spec.cwd,
            environment=_clean_worker_environment(),
            timeout_seconds=timeout_seconds,
        )
        records.append(receipt)
        _require_process_success(receipt, f"{spec.engine_id}_preflight")
        preflight = _marker_json(str(receipt["stdout"]), spec.preflight_marker)
        _validate_worker_preflight(spec, preflight)
        worker_negative_control_count += int(preflight["negative_control_count"])

    for spec in specs:
        receipt = _invoke_process(
            process_runner,
            godot=spec.engine_id == "godot_jolt",
            name=f"{spec.engine_id}_authorization_negative",
            command=spec.negative_physical_command,
            cwd=spec.cwd,
            environment=_clean_worker_environment(),
            timeout_seconds=timeout_seconds,
        )
        records.append(receipt)
        if receipt.get("exit_code") == 0 or receipt.get("timed_out") is not False:
            raise RouteSupervisorError(
                f"TURNING_ROUTE_SUPERVISOR_AUTHORIZATION_NEGATIVE_PROCESS_INVALID:{spec.engine_id}"
            )
        terminal = _marker_json(str(receipt["stdout"]), spec.terminal_marker)
        _validate_negative_terminal(spec, terminal, source)

    return {
        "schema_version": (
            "sporespore_three_engine_turning_success_transport_"
            "supervisor_preflight_v2"
        ),
        "route_id": ROUTE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "configuration_id": GHOST["configuration_id"],
        "ordered_engine_ids": list(ENGINE_IDS),
        "ordered_cell_ids": list(ORDERED_CELL_IDS),
        "contract_raw_sha256": _sha256_file(CONTRACT_PATH),
        "complete_zero_world_gate_passed": True,
        "process_count": len(records),
        "worker_preflight_count": len(specs),
        "evaluator_preflight_count": 1,
        "authorization_negative_count": len(specs),
        "embedded_negative_control_count": (
            evaluator_negative_count + worker_negative_control_count
        ),
        "total_negative_control_count": (
            evaluator_negative_count + worker_negative_control_count + len(specs)
        ),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_behavior_thresholds_applied": False,
        "physical_acceptance_authority": False,
        "environment": {
            "os_name": os.name,
            "platform": platform.platform(),
            "python_version": platform.python_version(),
            "mujoco_package_version_in_supervisor_host": _package_version("mujoco"),
            "processor_architecture": os.environ.get("PROCESSOR_ARCHITECTURE", ""),
        },
        "dependency_artifacts": _dependency_artifacts(runtime),
        "process_records": records,
    }


def _git(arguments: Sequence[str]) -> str:
    completed = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        capture_output=True,
        check=False,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise RouteSupervisorError(
            "TURNING_ROUTE_SUPERVISOR_GIT_FAILED:"
            f"{' '.join(arguments)}:{completed.stderr.strip()}"
        )
    return completed.stdout.strip()


def verify_exact_source_state() -> dict[str, Any]:
    try:
        root = Path(_git(("rev-parse", "--show-toplevel"))).resolve(strict=True)
    except OSError as error:
        raise RouteSupervisorError("TURNING_ROUTE_SUPERVISOR_REPO_ROOT_UNREADABLE") from error
    remote = _git(("remote", "get-url", "origin"))
    branch = _git(("branch", "--show-current"))
    status = _git(("status", "--porcelain=v1", "--untracked-files=all"))
    head = _git(("rev-parse", "HEAD"))
    origin_main = _git(("rev-parse", "origin/main"))
    tree = _git(("rev-parse", "HEAD^{tree}"))
    live_rows = _git(("ls-remote", "origin", "refs/heads/main")).splitlines()
    live_parts = live_rows[0].split() if len(live_rows) == 1 else []
    live = live_parts[0] if len(live_parts) == 2 else ""
    exact = (
        root == REPO_ROOT.resolve(strict=True)
        and remote == EXPECTED_REMOTE
        and branch == EXPECTED_BRANCH
        and status == ""
        and _is_lower_hex(head, 40)
        and head == origin_main
        and head == live
        and _is_lower_hex(tree, 40)
    )
    if not exact:
        raise RouteSupervisorError(
            "TURNING_ROUTE_SUPERVISOR_SOURCE_STATE_INVALID:"
            f"root={root}:remote={remote}:branch={branch}:dirty={bool(status)}:"
            f"head={head}:origin={origin_main}:live={live}"
        )
    return {
        "repo_root": str(root),
        "origin_url": remote,
        "branch": branch,
        "source_commit": head,
        "origin_main_commit": origin_main,
        "live_github_main_commit": live,
        "source_tree": tree,
        "source_worktree_clean": True,
        "local_remote_live_equal": True,
    }


class LocomotionOperationMutex:
    """Hold the repository's existing machine-wide physical/conformance mutex."""

    def __init__(self, role: str) -> None:
        if role not in {"conformance", "physical"}:
            raise ValueError("invalid operation-lock role")
        self.role = role
        self.handle: int | None = None
        self.receipt: dict[str, Any] | None = None

    def __enter__(self) -> dict[str, Any]:
        if os.name != "nt":
            raise RouteSupervisorError("TURNING_ROUTE_SUPERVISOR_WINDOWS_MUTEX_REQUIRED")
        from ctypes import wintypes

        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.CreateMutexW.argtypes = (wintypes.LPVOID, wintypes.BOOL, wintypes.LPCWSTR)
        kernel32.CreateMutexW.restype = wintypes.HANDLE
        kernel32.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
        kernel32.WaitForSingleObject.restype = wintypes.DWORD
        kernel32.ReleaseMutex.argtypes = (wintypes.HANDLE,)
        kernel32.ReleaseMutex.restype = wintypes.BOOL
        kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)
        kernel32.CloseHandle.restype = wintypes.BOOL

        handle = kernel32.CreateMutexW(None, False, OPERATION_MUTEX_NAME)
        if not handle:
            raise RouteSupervisorError(
                f"TURNING_ROUTE_SUPERVISOR_MUTEX_CREATE_FAILED:{ctypes.get_last_error()}"
            )
        created_new = ctypes.get_last_error() != 183  # ERROR_ALREADY_EXISTS
        wait_result = int(kernel32.WaitForSingleObject(handle, 0))
        abandoned = wait_result == 0x00000080
        if wait_result not in {0x00000000, 0x00000080}:
            kernel32.CloseHandle(handle)
            raise RouteSupervisorError(
                f"TURNING_ROUTE_SUPERVISOR_OPERATION_LOCK_UNAVAILABLE:{wait_result}"
            )
        self.handle = int(handle)
        self.receipt = {
            "schema_version": "sporespore_locomotion_operation_lock_receipt_v1",
            "acquired": True,
            "role": self.role,
            "mutex_name": OPERATION_MUTEX_NAME,
            "created_new": created_new,
            "abandoned_owner_recovered": abandoned,
            "owner_process_id": os.getpid(),
            "acquired_utc": _utc_now(),
            "test_only": False,
            "physical_acceptance_authority": False,
        }
        return dict(self.receipt)

    def __exit__(self, exc_type: Any, exc: Any, traceback: Any) -> None:
        if self.handle is None:
            return
        from ctypes import wintypes

        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.ReleaseMutex.argtypes = (wintypes.HANDLE,)
        kernel32.ReleaseMutex.restype = wintypes.BOOL
        kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)
        kernel32.CloseHandle.restype = wintypes.BOOL
        handle = wintypes.HANDLE(self.handle)
        try:
            if not kernel32.ReleaseMutex(handle):
                raise RouteSupervisorError(
                    f"TURNING_ROUTE_SUPERVISOR_MUTEX_RELEASE_FAILED:{ctypes.get_last_error()}"
                )
        finally:
            kernel32.CloseHandle(handle)
            self.handle = None


def _write_new_json(path: Path, value: Any) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(
                value,
                stream,
                allow_nan=False,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
            stream.write("\n")
    except FileExistsError as error:
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_REFUSES_OVERWRITE:{path}"
        ) from error
    return _artifact(path)


def _write_new_text(path: Path, value: str) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open("x", encoding="utf-8", newline="\n") as stream:
            stream.write(value)
    except FileExistsError as error:
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_REFUSES_OVERWRITE:{path}"
        ) from error
    return _artifact(path)


def _canonical_path_text(value: str | Path) -> str:
    raw = str(value)
    if raw.startswith("\\\\?\\UNC\\"):
        raw = "\\\\" + raw[8:]
    elif raw.startswith("\\\\?\\"):
        raw = raw[4:]
    resolved = str(Path(raw).resolve(strict=True))
    if resolved.startswith("\\\\?\\UNC\\"):
        resolved = "\\\\" + resolved[8:]
    elif resolved.startswith("\\\\?\\"):
        resolved = resolved[4:]
    return os.path.normcase(os.path.normpath(resolved))


def _same_canonical_path(left: str | Path, right: str | Path) -> bool:
    try:
        return _canonical_path_text(left) == _canonical_path_text(right)
    except OSError:
        return False


def _retain_process(root: Path, index: int, receipt: Mapping[str, Any]) -> dict[str, Any]:
    directory = root / f"{index:02d}__{receipt['name']}"
    directory.mkdir(parents=True, exist_ok=False)
    stdout = _write_new_text(directory / "stdout.txt", str(receipt.get("stdout", "")))
    stderr = _write_new_text(directory / "stderr.txt", str(receipt.get("stderr", "")))
    public = {key: value for key, value in receipt.items() if key not in {"stdout", "stderr"}}
    public["stdout_artifact"] = stdout
    public["stderr_artifact"] = stderr
    process_artifact = _write_new_json(directory / "process.json", public)
    public["process_artifact"] = process_artifact
    return public


def _retain_processes(root: Path, receipts: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    root.mkdir(parents=True, exist_ok=False)
    return [_retain_process(root, index, receipt) for index, receipt in enumerate(receipts)]


def _physical_environment(
    runtime: RuntimePaths,
    *,
    freeze_path: Path,
    attempt_path: Path,
    attempt_root: Path,
    token: str,
    spec: WorkerSpec,
) -> dict[str, str]:
    return _clean_worker_environment(
        {
            "SPORESPORE_TURNING_ROUTE_FREEZE": str(freeze_path.resolve()),
            "SPORESPORE_TURNING_ROUTE_ATTEMPT": str(attempt_path.resolve()),
            "SPORESPORE_TURNING_ROUTE_TOKEN": token,
            "SPORESPORE_TURNING_ROUTE_ATTEMPT_ROOT": str(attempt_root.resolve()),
            "SPORESPORE_TURNING_ROUTE_AUTHORITY_REPO_ROOT": str(REPO_ROOT.resolve()),
            "SPORESPORE_TURNING_ROUTE_ENGINE": spec.engine_id,
            "SPORESPORE_TURNING_ROUTE_CELL": spec.cell_id,
            "SPORESPORE_TURNING_ROUTE_PYTHON": str(runtime.python_host),
            "SPORESPORE_TURNING_ROUTE_POWERSHELL": str(runtime.powershell),
        }
    )


def _freeze_document(
    source: Mapping[str, Any], zero_world_gate_artifact: Mapping[str, Any]
) -> dict[str, Any]:
    return {
        "schema_version": FREEZE_SCHEMA,
        "route_id": ROUTE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "authority_mode": "development_ghost",
        "source_commit": source["source_commit"],
        "origin_main_commit": source["origin_main_commit"],
        "live_github_main_commit": source["live_github_main_commit"],
        "source_tree": source["source_tree"],
        "contract_raw_sha256": _sha256_file(CONTRACT_PATH),
        "source_worktree_clean": True,
        "complete_zero_world_gate_passed": True,
        "zero_world_gate_artifact": dict(zero_world_gate_artifact),
        "declared_world_count": len(ENGINE_IDS),
        "ordered_cell_ids": list(ORDERED_CELL_IDS),
        "serial_execution_required": True,
        "physical_execution_authorized": True,
        "physical_behavior_thresholds_applied": False,
        "claims": {key: False for key in CONTRACT["claims"]},
        "physical_acceptance_authority": False,
    }


def _attempt_document(
    *,
    source_commit: str,
    freeze_raw_sha256: str,
    token: str,
    attempt_id: str,
    attempt_root: Path,
) -> dict[str, Any]:
    if (
        not _is_lower_hex(source_commit, 40)
        or not freeze_raw_sha256.startswith("sha256:")
        or not _is_lower_hex(freeze_raw_sha256.removeprefix("sha256:"), 64)
        or not _is_lower_hex(token, 32)
        or not _is_lower_hex(attempt_id, 32)
    ):
        raise RouteSupervisorError("TURNING_ROUTE_SUPERVISOR_ATTEMPT_IDENTITY_INVALID")
    return {
        "schema_version": ATTEMPT_SCHEMA,
        "route_id": ROUTE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "source_commit": source_commit,
        "freeze_raw_sha256": freeze_raw_sha256,
        "authorization_token": token,
        "attempt_id": attempt_id,
        "attempt_root": str(attempt_root.resolve(strict=True)),
        "ordered_cell_ids": list(ORDERED_CELL_IDS),
        "single_use_supervisor_authorization": True,
        "operation_lock_held": True,
        "one_shot_attempt_unconsumed": True,
        "physical_execution_authorized": True,
        "physical_behavior_thresholds_applied": False,
        "physical_acceptance_authority": False,
    }


def _validate_authorization_receipt(
    spec: WorkerSpec, value: Mapping[str, Any], attempt_root: Path
) -> None:
    exact = (
        value.get("schema_version") == spec.authorization_schema
        and value.get("ok") is True
        and value.get("failure_code") == ""
        and value.get("route_id") == ROUTE_ID
        and value.get("ledger_scope") == LEDGER_SCOPE
        and value.get("engine_id") == spec.engine_id
        and value.get("cell_id") == spec.cell_id
        and _same_canonical_path(str(value.get("attempt_root", "")), attempt_root)
        and value.get("authorization_passed") is True
        and value.get("returned_before_model") is True
        and value.get("physical_acceptance_authority") is False
    )
    if not exact:
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_AUTHORIZATION_PREFLIGHT_INVALID:{spec.engine_id}"
        )
    _validate_zero_counts(value, f"authorization_preflight:{spec.engine_id}")


def _validate_physical_terminal(
    spec: WorkerSpec, value: Mapping[str, Any], source_commit: str
) -> bool:
    identity = (
        value.get("route_id") == ROUTE_ID
        and value.get("ledger_scope") == LEDGER_SCOPE
        and value.get("question_class") == "development"
        and value.get("engine_id") == spec.engine_id
        and value.get("cell_id") == spec.cell_id
        and value.get("campaign_seed") == DEVELOPMENT_SEED
        and value.get("source_commit") == source_commit
        and value.get("physical_behavior_thresholds_applied") is False
        and value.get("physical_acceptance_authority") is False
    )
    if not identity:
        raise RouteSupervisorError(
            f"TURNING_ROUTE_SUPERVISOR_TERMINAL_IDENTITY_INVALID:{spec.engine_id}"
        )
    schema = value.get("schema_version")
    if schema == CELL_REPORT_SCHEMA:
        if any(
            field in value
            for field in (
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
            )
        ):
            raise RouteSupervisorError(
                f"TURNING_ROUTE_SUPERVISOR_SUCCESS_ROOT_COUNTS_FORBIDDEN:{spec.engine_id}"
            )
        execution = value.get("execution")
        if not isinstance(execution, Mapping) or any(
            type(execution.get(field)) is not int or execution.get(field) != expected
            for field, expected in (
                ("world_attempt_count", 1),
                ("world_build_count", 1),
                ("controller_semantic_step_count", int(GHOST["controller_step_count"])),
            )
        ):
            raise RouteSupervisorError(
                f"TURNING_ROUTE_SUPERVISOR_SUCCESS_EXECUTION_COUNTS_INVALID:{spec.engine_id}"
            )
        return True
    if schema == WORKER_FAILURE_SCHEMA:
        for field in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
        ):
            if type(value.get(field)) is not int or int(value[field]) < 0:
                raise RouteSupervisorError(
                    f"TURNING_ROUTE_SUPERVISOR_FAILURE_COUNTS_INVALID:{spec.engine_id}"
                )
        return False
    raise RouteSupervisorError(
        f"TURNING_ROUTE_SUPERVISOR_TERMINAL_SCHEMA_INVALID:{spec.engine_id}:{schema}"
    )


def _supervisor_cell_failure(
    spec: WorkerSpec, source_commit: str, code: str, process: Mapping[str, Any]
) -> dict[str, Any]:
    return {
        "schema_version": (
            "sporespore_three_engine_turning_success_transport_"
            "supervisor_cell_failure_v2"
        ),
        "route_id": ROUTE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "question_class": "development",
        "engine_id": spec.engine_id,
        "cell_id": spec.cell_id,
        "campaign_seed": DEVELOPMENT_SEED,
        "source_commit": source_commit,
        "failure_code": code,
        "worker_terminal_observed": False,
        "model_construction_count": None,
        "world_attempt_count": None,
        "world_build_count": None,
        "process_exit_code": process.get("exit_code"),
        "process_timed_out": process.get("timed_out"),
        "physical_behavior_thresholds_applied": False,
        "physical_acceptance_authority": False,
    }


def _attempt_root(evidence_root: Path, attempt_id: str) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    return (
        evidence_root
        / "turning/success-transport-ghost-v2"
        / f"{stamp}__{attempt_id}"
    )


def run_physical_route(
    runtime: RuntimePaths,
    *,
    evidence_root: Path = DEFAULT_EVIDENCE_ROOT,
    process_runner: ProcessRunner = _run_process,
    timeout_seconds: int = 600,
) -> dict[str, Any]:
    """Freeze and execute one append-only, three-world development attempt."""

    evidence_root = evidence_root.resolve()
    with LocomotionOperationMutex("physical") as operation_lock:
        source = verify_exact_source_state()
        evidence_root.mkdir(parents=True, exist_ok=True)
        source_commit = str(source["source_commit"])
        attempt_id = uuid.uuid4().hex
        token = secrets.token_hex(16)
        attempt_root = _attempt_root(evidence_root, attempt_id)
        attempt_root.mkdir(parents=True, exist_ok=False)
        reservation = {
            "schema_version": (
                "sporespore_three_engine_turning_success_transport_"
                "operation_reservation_v2"
            ),
            "route_id": ROUTE_ID,
            "ledger_scope": dict(LEDGER_SCOPE),
            "attempt_id": attempt_id,
            "attempt_root": str(attempt_root.resolve()),
            "source_commit": source_commit,
            "reserved_utc": _utc_now(),
            "create_new_reservation": True,
            "operation_lock": operation_lock,
            "physical_behavior_thresholds_applied": False,
            "physical_acceptance_authority": False,
        }
        reservation_artifact = _write_new_json(
            attempt_root / "operation-reservation.json", reservation
        )

        try:
            zero_world = run_complete_zero_world_gate(
                runtime,
                process_runner=process_runner,
                timeout_seconds=timeout_seconds,
            )
            zero_world["process_records"] = _retain_processes(
                attempt_root / "zero-world/processes", zero_world["process_records"]
            )
            zero_world_artifact = _write_new_json(
                attempt_root / "zero-world/complete-gate.json", zero_world
            )
            source_after_gate = verify_exact_source_state()
            if source_after_gate != source:
                raise RouteSupervisorError("TURNING_ROUTE_SUPERVISOR_SOURCE_DRIFT_AFTER_GATE")

            freeze = _freeze_document(source, zero_world_artifact)
            freeze_path = attempt_root / "physical-freeze.json"
            freeze_artifact = _write_new_json(freeze_path, freeze)
            attempt = _attempt_document(
                source_commit=source_commit,
                freeze_raw_sha256=str(freeze_artifact["sha256"]),
                token=token,
                attempt_id=attempt_id,
                attempt_root=attempt_root,
            )
            attempt_path = attempt_root / "attempt-authorization.json"
            attempt_artifact = _write_new_json(attempt_path, attempt)
            specs = _worker_specs(runtime, source_commit)

            authorization_receipts: list[dict[str, Any]] = []
            authorization_processes: list[dict[str, Any]] = []
            authorization_process_root = (
                attempt_root / "authorization-preflight/processes"
            )
            authorization_process_root.mkdir(parents=True, exist_ok=False)
            for index, spec in enumerate(specs):
                process = _invoke_process(
                    process_runner,
                    godot=spec.engine_id == "godot_jolt",
                    name=f"{spec.engine_id}_authorization_preflight",
                    command=spec.authorization_command,
                    cwd=spec.cwd,
                    environment=_physical_environment(
                        runtime,
                        freeze_path=freeze_path,
                        attempt_path=attempt_path,
                        attempt_root=attempt_root,
                        token=token,
                        spec=spec,
                    ),
                    timeout_seconds=timeout_seconds,
                )
                authorization_processes.append(
                    _retain_process(authorization_process_root, index, process)
                )
                _require_process_success(process, f"{spec.engine_id}_authorization_preflight")
                receipt = _marker_json(str(process["stdout"]), spec.authorization_marker)
                _validate_authorization_receipt(spec, receipt, attempt_root)
                authorization_receipts.append(receipt)
            authorization_matrix = {
                "schema_version": (
                    "sporespore_three_engine_turning_success_transport_"
                    "authorization_matrix_v2"
                ),
                "route_id": ROUTE_ID,
                "source_commit": source_commit,
                "ordered_cell_ids": list(ORDERED_CELL_IDS),
                "receipt_count": len(authorization_receipts),
                "all_workers_authorized_before_model": True,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "worker_receipts": authorization_receipts,
                "process_records": authorization_processes,
                "physical_behavior_thresholds_applied": False,
                "physical_acceptance_authority": False,
            }
            authorization_artifact = _write_new_json(
                attempt_root / "authorization-preflight/complete-matrix.json",
                authorization_matrix,
            )
            if verify_exact_source_state() != source:
                raise RouteSupervisorError(
                    "TURNING_ROUTE_SUPERVISOR_SOURCE_DRIFT_BEFORE_PHYSICAL"
                )

            terminal_paths: list[str] = []
            physical_records: list[dict[str, Any]] = []
            worker_success_count = 0
            source_drift = False
            for index, spec in enumerate(specs):
                try:
                    if verify_exact_source_state() != source:
                        raise RouteSupervisorError(
                            f"TURNING_ROUTE_SUPERVISOR_SOURCE_DRIFT_BEFORE_CELL:{spec.engine_id}"
                        )
                except RouteSupervisorError:
                    source_drift = True
                    raise
                process = _invoke_process(
                    process_runner,
                    godot=spec.engine_id == "godot_jolt",
                    name=f"{spec.engine_id}_physical",
                    command=spec.physical_command,
                    cwd=spec.cwd,
                    environment=_physical_environment(
                        runtime,
                        freeze_path=freeze_path,
                        attempt_path=attempt_path,
                        attempt_root=attempt_root,
                        token=token,
                        spec=spec,
                    ),
                    timeout_seconds=timeout_seconds,
                )
                process_root = attempt_root / "physical" / f"{index:02d}__{spec.engine_id}"
                process_root.mkdir(parents=True, exist_ok=False)
                process_public = {
                    key: value
                    for key, value in process.items()
                    if key not in {"stdout", "stderr"}
                }
                process_public["stdout_artifact"] = _write_new_text(
                    process_root / "stdout.txt", str(process.get("stdout", ""))
                )
                process_public["stderr_artifact"] = _write_new_text(
                    process_root / "stderr.txt", str(process.get("stderr", ""))
                )
                process_public["process_artifact"] = _write_new_json(
                    process_root / "process.json", process_public
                )
                physical_records.append(process_public)
                try:
                    terminal = _marker_json(str(process.get("stdout", "")), spec.terminal_marker)
                    success = _validate_physical_terminal(spec, terminal, source_commit)
                except RouteSupervisorError as error:
                    terminal = _supervisor_cell_failure(
                        spec, source_commit, str(error), process
                    )
                    success = False
                if success and process.get("exit_code") == 0 and process.get("timed_out") is False:
                    worker_success_count += 1
                elif success:
                    terminal = _supervisor_cell_failure(
                        spec,
                        source_commit,
                        "TURNING_ROUTE_SUPERVISOR_SUCCESS_TERMINAL_PROCESS_INVALID",
                        process,
                    )
                terminal_path = process_root / "terminal.json"
                _write_new_json(terminal_path, terminal)
                terminal_paths.append(str(terminal_path.resolve()))

            manifest_path = attempt_root / "terminal-manifest.json"
            manifest_artifact = _write_new_json(manifest_path, terminal_paths)
            evaluation_process = process_runner(
                name="complete_evaluator",
                command=(
                    str(runtime.python_host),
                    str(EVALUATOR_PATH),
                    "evaluate-complete",
                    "--manifest",
                    str(manifest_path),
                    "--expected-source-commit",
                    source_commit,
                ),
                cwd=REPO_ROOT,
                environment=_clean_worker_environment(),
                timeout_seconds=timeout_seconds,
            )
            retained_evaluation = _retain_process(
                attempt_root / "evaluation/processes", 0, evaluation_process
            )
            evaluation: dict[str, Any] | None = None
            if (
                evaluation_process.get("exit_code") == 0
                and evaluation_process.get("timed_out") is False
            ):
                evaluation = _marker_json(
                    str(evaluation_process["stdout"]),
                    "SPORESPORE_TURNING_ROUTE_EVALUATION ",
                )
                _write_new_json(attempt_root / "evaluation/evaluation.json", evaluation)
            route_execution_valid = bool(
                evaluation is not None
                and evaluation.get("route_execution_valid") is True
                and worker_success_count == len(specs)
                and not source_drift
            )
            result = {
                "schema_version": (
                    "sporespore_three_engine_turning_success_transport_"
                    "supervisor_result_v2"
                ),
                "route_id": ROUTE_ID,
                "ledger_scope": dict(LEDGER_SCOPE),
                "authority_mode": "development_ghost",
                "source_commit": source_commit,
                "attempt_id": attempt_id,
                "attempt_root": str(attempt_root.resolve()),
                "route_execution_valid": route_execution_valid,
                "outcome_class": (
                    "execution_valid_development_success_transport_ghost"
                    if route_execution_valid
                    else (
                        "infrastructure_invalid_or_incomplete_development_"
                        "success_transport_ghost"
                    )
                ),
                "declared_world_count": len(specs),
                "physical_worker_process_count": len(physical_records),
                "execution_valid_worker_count": worker_success_count,
                "complete_evaluator_invocation_count": 1,
                "reservation_artifact": reservation_artifact,
                "zero_world_gate_artifact": zero_world_artifact,
                "freeze_artifact": freeze_artifact,
                "attempt_authorization_artifact": attempt_artifact,
                "authorization_matrix_artifact": authorization_artifact,
                "terminal_manifest_artifact": manifest_artifact,
                "physical_process_records": physical_records,
                "evaluation_process_record": retained_evaluation,
                "evaluation": evaluation,
                "physical_behavior_thresholds_applied": False,
                "claims": {key: False for key in CONTRACT["claims"]},
                "physical_acceptance_authority": False,
            }
            result_artifact = _write_new_json(attempt_root / "supervisor-result.json", result)
            result["result_artifact"] = result_artifact
            return result
        except Exception as error:
            failure = {
                "schema_version": (
                    "sporespore_three_engine_turning_success_transport_"
                    "supervisor_incomplete_v2"
                ),
                "route_id": ROUTE_ID,
                "ledger_scope": dict(LEDGER_SCOPE),
                "authority_mode": "development_ghost",
                "source_commit": source_commit,
                "attempt_id": attempt_id,
                "attempt_root": str(attempt_root.resolve()),
                "failure_code": f"{type(error).__name__}:{error}",
                "route_execution_valid": False,
                "physical_behavior_thresholds_applied": False,
                "claims": {key: False for key in CONTRACT["claims"]},
                "physical_acceptance_authority": False,
            }
            try:
                _write_new_json(attempt_root / "supervisor-incomplete.json", failure)
            except RouteSupervisorError:
                pass
            raise


def _arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--python-host", default=sys.executable)
    parser.add_argument("--mujoco-python", default=str(DEFAULT_MUJOCO_PYTHON))
    parser.add_argument("--godot", default=str(DEFAULT_GODOT))
    parser.add_argument("--powershell", default=shutil.which("pwsh") or "pwsh")
    parser.add_argument("--cargo", default=shutil.which("cargo") or "cargo")
    parser.add_argument("--rapier-binary", default=str(RAPIER_BINARY_PATH))
    parser.add_argument("--timeout-seconds", type=int, default=600)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    run = commands.add_parser("run")
    run.add_argument("--evidence-root", type=Path, default=DEFAULT_EVIDENCE_ROOT)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(argv)
    try:
        if not 1 <= arguments.timeout_seconds <= 7200:
            raise RouteSupervisorError("TURNING_ROUTE_SUPERVISOR_TIMEOUT_INVALID")
        runtime = resolve_runtime_paths(arguments)
        if arguments.command == "preflight":
            with LocomotionOperationMutex("conformance"):
                value = run_complete_zero_world_gate(
                    runtime, timeout_seconds=arguments.timeout_seconds
                )
            print(
                SUPERVISOR_PREFLIGHT_MARKER
                + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
            )
            return 0
        value = run_physical_route(
            runtime,
            evidence_root=arguments.evidence_root,
            timeout_seconds=arguments.timeout_seconds,
        )
        print(
            SUPERVISOR_RESULT_MARKER
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 0 if value.get("route_execution_valid") is True else 1
    except (RouteSupervisorError, OSError, UnicodeError, ValueError) as error:
        print(
            SUPERVISOR_ERROR_MARKER
            + json.dumps(
                {
                    "schema_version": (
                        "sporespore_three_engine_turning_success_transport_"
                        "supervisor_error_v2"
                    ),
                    "route_id": ROUTE_ID,
                    "failure_code": f"{type(error).__name__}:{error}",
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "physical_acceptance_authority": False,
                },
                allow_nan=False,
                separators=(",", ":"),
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
