"""Genuine MuJoCo worker for the bounded three-engine turning route.

The route binds a fresh instance of the established fixed-horizon MuJoCo
kernel to a two-step development specification.  The closed R23D65 campaign
module is imported only as immutable production plumbing; scoped in-memory
bindings select the route seed and horizon and are restored after every call.
"""

from __future__ import annotations

import argparse
import copy
from contextlib import contextmanager
from dataclasses import dataclass
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
from types import ModuleType, SimpleNamespace
from typing import Any, Iterator, Mapping, Sequence

import numpy as np

SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
SDK_PYTHON = SDK_ROOT / "python"
if str(SDK_PYTHON) not in sys.path:
    sys.path.insert(0, str(SDK_PYTHON))
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from . import qsdk_r23d2_heading_response as inherited_base
from . import qsdk_r23d65_selected_profile_turning as production
from .actuator_cap_profile import HOST_MAPPING_ID, PROFILE_ID, PROFILE_SHA256


CONTRACT_PATH = TURNING_ROOT / "three_engine_turning_success_transport_route_v2.json"
EVALUATOR_PATH = TURNING_ROOT / "three_engine_turning_route_evaluator.py"
WORKER_PATH = Path(__file__).resolve()

ROUTE_ID = "sporespore_three_engine_turning_success_transport_route_v2"
ENGINE_ID = "mujoco"
CELL_ID = "turning_success_transport_v2__mujoco__s21516__positive_heading"
STAGE_ID = "turning_3e_success_transport_development_ghost"
ONSET_ID = "route_turn_start_0"
CAMPAIGN_SEED = 21_516
ARM_ID = "positive_heading"
HEADING_OFFSET_RAD = 0.2
CONTROLLER_STEPS = 2
ACTUATOR_COUNT = 8
POLICY_ID = production.POLICY_ID
MEMORY_SCHEMA = "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
TRACE_ROW_SCHEMA = "sporespore_three_engine_turning_success_transport_trace_row_v2"
REPORT_SCHEMA = "sporespore_three_engine_turning_success_transport_cell_report_v2"
FAILURE_SCHEMA = "sporespore_three_engine_turning_success_transport_worker_failure_v2"
RETENTION_SCHEMA = "sporespore_three_engine_turning_success_transport_trace_retention_v2"
PREFLIGHT_SCHEMA = (
    "sporespore_three_engine_turning_success_transport_mujoco_preflight_v2"
)
AUTHORIZATION_SCHEMA = (
    "sporespore_three_engine_turning_success_transport_mujoco_authorization_v2"
)
FREEZE_SCHEMA = "sporespore_three_engine_turning_success_transport_freeze_v2"
ATTEMPT_SCHEMA = "sporespore_three_engine_turning_success_transport_attempt_v2"
HORIZON_POLICY_ID = "sporespore_turning_route_two_step_horizon_v1"
HORIZON_POLICY_SHA256 = (
    "sha256:51c63281ddf18e22b3b68e19db2352dd9b0731e62fc1fb748f756ce3949b41b9"
)
TRACE_POLICY_ID = "sporespore_turning_route_two_step_trace_v1"
TRACE_POLICY_SHA256 = (
    "sha256:eaeba8aea37e27d91f1f2e4af8ba6a76ed4d7d2e2a98eb5778d5c1edf7fc81df"
)

FREEZE_PATH_ENV = "SPORESPORE_TURNING_ROUTE_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_TURNING_ROUTE_ATTEMPT"
TOKEN_ENV = "SPORESPORE_TURNING_ROUTE_TOKEN"
ATTEMPT_ROOT_ENV = "SPORESPORE_TURNING_ROUTE_ATTEMPT_ROOT"
AUTHORITY_REPO_ROOT_ENV = "SPORESPORE_TURNING_ROUTE_AUTHORITY_REPO_ROOT"
ENGINE_ENV = "SPORESPORE_TURNING_ROUTE_ENGINE"
CELL_ENV = "SPORESPORE_TURNING_ROUTE_CELL"
PYTHON_ENV = "SPORESPORE_TURNING_ROUTE_PYTHON"
POWERSHELL_ENV = "SPORESPORE_TURNING_ROUTE_POWERSHELL"

INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.0008292800048366189,
    "fixture_yaw_rad": -0.0031932652927935123,
    "initial_linear_velocity_world_m_s": [
        0.0030934750102460384,
        0.0,
        -0.0007665741723030806,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        -0.0007512527517974377,
        0.0010391897521913052,
        0.0010421534534543753,
    ],
    "gait_phase_offset_ticks": 0,
}

FALSE_CLAIMS = {
    "turning_established": False,
    "portable_basic_turning": False,
    "cross_engine_equivalence": False,
    "arbitrary_quadruped_coverage": False,
    "q_sdk_r23_satisfied": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}

LEDGER_SCOPE = {
    "subsystem": "turning",
    "engine_scope": "3e",
    "authority_mode": "development_ghost",
    "question_class": "development",
}

_BINDING_LOCK = threading.Lock()


def _json_native(value: Any) -> Any:
    """Project NumPy scalar observations to their lossless JSON-native values."""

    if isinstance(value, np.generic):
        return value.item()
    if isinstance(value, dict):
        return {key: _json_native(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_native(item) for item in value]
    return value


def _load_private_core() -> ModuleType:
    source = Path(__file__).with_name("qsdk_r23d3_phase_balanced.py")
    specification = importlib.util.spec_from_file_location(
        "sporespore_mujoco_adapter._turning_three_engine_route_core",
        source,
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("TURNING_ROUTE_MJC_INHERITED_WORKER_UNAVAILABLE")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


_core = _load_private_core()


@dataclass(frozen=True)
class _Cell:
    stage_id: str = STAGE_ID
    cell_id: str = CELL_ID
    engine_id: str = ENGINE_ID
    onset_id: str = ONSET_ID
    turn_start_semantic_step: int = 0
    arm_id: str = ARM_ID
    turn_heading_offset_rad: float = HEADING_OFFSET_RAD
    campaign_seed: int = CAMPAIGN_SEED
    profile_id: str = PROFILE_ID
    host_mapping_id: str = HOST_MAPPING_ID


def _cell(stage_id: str, onset_id: str, arm_id: str) -> _Cell:
    if (stage_id, onset_id, arm_id) != (STAGE_ID, ONSET_ID, ARM_ID):
        raise _core.R23D3MujocoError(
            f"TURNING_ROUTE_MJC_CELL_IDENTITY_INVALID:{stage_id}:{onset_id}:{arm_id}"
        )
    return _Cell()


def _segment_for_step(item: _Cell, semantic_step: int) -> tuple[str, float]:
    if item != _Cell() or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise _core.R23D3MujocoError(
            f"TURNING_ROUTE_MJC_SEMANTIC_STEP_INVALID:{semantic_step}"
        )
    return "commanded_turn", HEADING_OFFSET_RAD


def _expected_segment_counts(_item: _Cell | None = None) -> dict[str, int]:
    return {"commanded_turn": CONTROLLER_STEPS}


_design = SimpleNamespace(
    CAMPAIGN_ID=ROUTE_ID,
    GATE_ID=ROUTE_ID,
    Cell=_Cell,
    ACTUATOR_COUNT=ACTUATOR_COUNT,
    CONTROLLER_STEPS=CONTROLLER_STEPS,
    TURN_DURATION_STEPS=CONTROLLER_STEPS,
    GAIT_CYCLE_STEPS=production.startup.GAIT_CYCLE_STEPS,
    LIMB_IDS=tuple(production.LIMB_IDS),
    PHASE_OFFSETS=tuple(production.PHASE_OFFSETS),
    TRACE_ROW_SCHEMA=TRACE_ROW_SCHEMA,
    segment_for_step=_segment_for_step,
    expected_segment_counts=_expected_segment_counts,
    stage_a_cells=lambda: [],
    stage_b_cells=lambda _onset: [_Cell()],
)

_evaluator = SimpleNamespace(
    REPORT_SCHEMA=REPORT_SCHEMA,
    FAILURE_SCHEMA=FAILURE_SCHEMA,
    TRACE_RETENTION_SCHEMA=RETENTION_SCHEMA,
    FALSE_CLAIMS=FALSE_CLAIMS,
)


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _valid_lower_hex(value: Any, length: int) -> bool:
    return (
        isinstance(value, str)
        and len(value) == length
        and all(character in "0123456789abcdef" for character in value)
    )


def _read_json(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise _core.R23D3MujocoError(f"{code}:{type(error).__name__}") from error
    if not isinstance(value, dict):
        raise _core.R23D3MujocoError(code)
    return value


def _expected_cell_ids() -> list[str]:
    return [
        "turning_success_transport_v2__godot_jolt__s21516__positive_heading",
        "turning_success_transport_v2__rapier_parry__s21516__positive_heading",
        "turning_success_transport_v2__mujoco__s21516__positive_heading",
    ]


def _validate_contract_value(contract: Mapping[str, Any]) -> None:
    ghost = contract.get("development_ghost", {})
    semantics = contract.get("canonical_semantics", {})
    thresholds = contract.get("route_integrity_thresholds", {})
    transport = contract.get("trace_transport_contract", {})
    claims = contract.get("claims", {})
    exact = (
        contract.get("schema_version") == ROUTE_ID
        and contract.get("route_id") == ROUTE_ID
        and contract.get("status") == "prospective_zero_world_only"
        and contract.get("ledger_scope") == LEDGER_SCOPE
        and ghost.get("development_seed") == CAMPAIGN_SEED
        and ghost.get("ordered_engine_ids") == ["godot_jolt", "rapier_parry", "mujoco"]
        and ghost.get("arm_id") == ARM_ID
        and ghost.get("turn_heading_offset_rad") == HEADING_OFFSET_RAD
        and ghost.get("controller_step_count") == CONTROLLER_STEPS
        and ghost.get("turn_start_semantic_step") == 0
        and ghost.get("turn_duration_steps") == CONTROLLER_STEPS
        and ghost.get("recovery_duration_steps") == 0
        and ghost.get("terminal_step_count") == 0
        and ghost.get("expected_actuator_count") == ACTUATOR_COUNT
        and ghost.get("expected_native_actuation_application_count") == 16
        and ghost.get("fixed_horizon_policy_id") == HORIZON_POLICY_ID
        and ghost.get("fixed_horizon_policy_sha256") == HORIZON_POLICY_SHA256
        and ghost.get("trace_policy_id") == TRACE_POLICY_ID
        and ghost.get("trace_policy_sha256") == TRACE_POLICY_SHA256
        and ghost.get("trace_row_schema") == TRACE_ROW_SCHEMA
        and ghost.get("cell_report_schema") == REPORT_SCHEMA
        and ghost.get("worker_failure_schema") == FAILURE_SCHEMA
        and ghost.get("trace_retention_schema") == RETENTION_SCHEMA
        and semantics.get("controller_policy_id") == POLICY_ID
        and semantics.get("controller_memory_schema") == MEMORY_SCHEMA
        and semantics.get("actuator_cap_profile_id") == PROFILE_ID
        and semantics.get("actuator_cap_profile_sha256") == PROFILE_SHA256
        and thresholds.get("exact_cell_count") == 3
        and thresholds.get("exact_controller_step_count_per_cell")
        == CONTROLLER_STEPS
        and thresholds.get("exact_trace_row_count_per_cell") == CONTROLLER_STEPS
        and thresholds.get("exact_world_attempt_count_per_cell") == 1
        and thresholds.get("exact_world_build_count_per_cell") == 1
        and thresholds.get("minimum_nonzero_turn_command_step_count_per_cell") == 1
        and thresholds.get("exact_required_artifact_transport_field_count") == 4
        and thresholds.get("exact_terminal_question_class_count") == 3
        and thresholds.get("physical_behavior_thresholds_applied") is False
        and transport.get("trace_transport_id")
        == "sporespore_three_engine_turning_success_transport_v2"
        and transport.get("artifact_schema_version")
        == "sporespore_content_addressed_artifact_receipt_v1"
        and transport.get("canonical_ndjson") is True
        and transport.get("full_precision") is True
        and transport.get("terminal_question_class") == "development"
        and claims.get("route_implemented") is False
        and claims.get("development_ghost_opened") is False
        and claims.get("physical_acceptance_authority") is False
    )
    if not exact:
        raise _core.R23D3MujocoError("TURNING_ROUTE_MJC_CONTRACT_INVALID")


def _contract() -> dict[str, Any]:
    contract = _read_json(CONTRACT_PATH, "TURNING_ROUTE_MJC_CONTRACT_UNREADABLE")
    _validate_contract_value(contract)
    return contract


def _same_path(candidate: Any, expected: Path) -> bool:
    if not isinstance(candidate, str) or not candidate:
        return False
    try:
        return Path(candidate).resolve(strict=True) == expected
    except OSError:
        return False


def _physical_authorization(item: _Cell, source_commit: str) -> dict[str, Any]:
    if item != _Cell() or not _valid_lower_hex(source_commit, 40):
        raise _core.R23D3MujocoError("TURNING_ROUTE_MJC_SELECTOR_INVALID")
    freeze_path = Path(os.environ.get(FREEZE_PATH_ENV, ""))
    attempt_path = Path(os.environ.get(ATTEMPT_PATH_ENV, ""))
    attempt_root = Path(os.environ.get(ATTEMPT_ROOT_ENV, ""))
    authority_root_raw = os.environ.get(AUTHORITY_REPO_ROOT_ENV, "")
    token = os.environ.get(TOKEN_ENV, "")
    if (
        not freeze_path.is_file()
        or not attempt_path.is_file()
        or not attempt_root.is_dir()
        or not authority_root_raw
        or not _valid_lower_hex(token, 32)
    ):
        raise _core.R23D3MujocoError(
            "TURNING_ROUTE_MJC_PHYSICAL_AUTHORIZATION_REQUIRED"
        )
    try:
        authority_root = Path(authority_root_raw).resolve(strict=True)
        canonical_attempt_root = attempt_root.resolve(strict=True)
        evidence_root = (REPO_ROOT.parent / "SporeSpore_Evidence").resolve(strict=True)
        canonical_attempt_root.relative_to(evidence_root)
    except (OSError, ValueError) as error:
        raise _core.R23D3MujocoError(
            "TURNING_ROUTE_MJC_AUTHORIZATION_PATH_INVALID"
        ) from error
    freeze = _read_json(freeze_path, "TURNING_ROUTE_MJC_FREEZE_UNREADABLE")
    attempt = _read_json(attempt_path, "TURNING_ROUTE_MJC_ATTEMPT_UNREADABLE")
    exact = (
        authority_root == REPO_ROOT.resolve(strict=True)
        and freeze.get("schema_version") == FREEZE_SCHEMA
        and freeze.get("route_id") == ROUTE_ID
        and freeze.get("authority_mode") == "development_ghost"
        and freeze.get("source_commit") == source_commit
        and freeze.get("origin_main_commit") == source_commit
        and freeze.get("live_github_main_commit") == source_commit
        and freeze.get("contract_raw_sha256") == _raw_sha256(CONTRACT_PATH)
        and freeze.get("source_worktree_clean") is True
        and freeze.get("complete_zero_world_gate_passed") is True
        and freeze.get("declared_world_count") == 3
        and freeze.get("ordered_cell_ids") == _expected_cell_ids()
        and freeze.get("serial_execution_required") is True
        and freeze.get("physical_execution_authorized") is True
        and freeze.get("physical_behavior_thresholds_applied") is False
        and attempt.get("schema_version") == ATTEMPT_SCHEMA
        and attempt.get("route_id") == ROUTE_ID
        and attempt.get("source_commit") == source_commit
        and attempt.get("freeze_raw_sha256") == _raw_sha256(freeze_path)
        and attempt.get("authorization_token") == token
        and _valid_lower_hex(attempt.get("attempt_id"), 32)
        and _same_path(attempt.get("attempt_root"), canonical_attempt_root)
        and attempt.get("ordered_cell_ids") == _expected_cell_ids()
        and attempt.get("single_use_supervisor_authorization") is True
        and attempt.get("operation_lock_held") is True
        and attempt.get("one_shot_attempt_unconsumed") is True
        and attempt.get("physical_execution_authorized") is True
        and os.environ.get(ENGINE_ENV) == ENGINE_ID
        and os.environ.get(CELL_ENV) == CELL_ID
    )
    if not exact:
        raise _core.R23D3MujocoError(
            "TURNING_ROUTE_MJC_PHYSICAL_AUTHORIZATION_INVALID"
        )
    return {
        "freeze": freeze,
        "attempt": attempt,
        "attempt_root": canonical_attempt_root,
    }


def _retain_trace(
    item: _Cell,
    rows: list[dict[str, Any]],
    attempt_root: Path,
) -> dict[str, Any]:
    projected = []
    for semantic_step, value in enumerate(rows):
        row = _json_native(copy.deepcopy(value))
        if (
            row.get("segment_id") != "commanded_turn"
            or row.get("desired_heading_offset_rad") != HEADING_OFFSET_RAD
        ):
            raise _core.R23D3MujocoError(
                "TURNING_ROUTE_MJC_NONZERO_SCHEDULE_NOT_OBSERVED",
                world_attempt_count=1,
                world_build_count=1,
            )
        row.update(
            schema_version=TRACE_ROW_SCHEMA,
            route_id=ROUTE_ID,
            engine_id=ENGINE_ID,
            cell_id=CELL_ID,
            campaign_seed=CAMPAIGN_SEED,
            semantic_step=semantic_step,
            trace_step=semantic_step,
            phase_id="commanded_turn",
            segment_id="commanded_turn",
            desired_heading_offset_rad=HEADING_OFFSET_RAD,
            native_step_completed=(
                row.get("native_actuation_application_count") == ACTUATOR_COUNT
            ),
        )
        projected.append(row)
    pending_root = attempt_root / "pending-traces"
    pending_root.mkdir(parents=True, exist_ok=True)
    rows_path = pending_root / f"{CELL_ID}.rows.json"
    with rows_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(
            projected,
            stream,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
        stream.write("\n")
    python = os.environ.get(PYTHON_ENV, sys.executable)
    powershell = os.environ.get(POWERSHELL_ENV, "pwsh")
    process = subprocess.run(
        [
            python,
            str(EVALUATOR_PATH),
            "retain-trace",
            "--engine-id",
            ENGINE_ID,
            "--cell-id",
            CELL_ID,
            "--rows-json",
            str(rows_path),
            "--repo-root",
            str(REPO_ROOT),
            "--attempt-root",
            str(attempt_root),
            "--powershell",
            powershell,
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        check=False,
        text=True,
        timeout=240,
    )
    marker = "SPORESPORE_TURNING_ROUTE_TRACE_RETAINED "
    matches = [
        line.removeprefix(marker)
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise _core.R23D3MujocoError(
            "TURNING_ROUTE_MJC_TRACE_RETENTION_FAILED:"
            f"exit={process.returncode}:markers={len(matches)}:"
            f"stdout={process.stdout[-2000:]}:stderr={process.stderr[-2000:]}",
            world_attempt_count=1,
            world_build_count=1,
        )
    receipt = json.loads(matches[0])
    if (
        receipt.get("schema_version") != RETENTION_SCHEMA
        or receipt.get("route_id") != ROUTE_ID
        or receipt.get("engine_id") != ENGINE_ID
        or receipt.get("cell_id") != CELL_ID
        or receipt.get("campaign_seed") != CAMPAIGN_SEED
        or receipt.get("row_count") != CONTROLLER_STEPS
        or receipt.get("retained_before_terminal_entry") is not True
    ):
        raise _core.R23D3MujocoError(
            "TURNING_ROUTE_MJC_TRACE_RETENTION_RECEIPT_INVALID",
            world_attempt_count=1,
            world_build_count=1,
        )
    return receipt


def _trace_row(**kwargs: Any) -> dict[str, Any]:
    row = _json_native(production._trace_row(**kwargs))
    semantic_step = int(kwargs["semantic_step"])
    if (
        row.get("segment_id") != "commanded_turn"
        or row.get("desired_heading_offset_rad") != HEADING_OFFSET_RAD
    ):
        raise RuntimeError("TURNING_ROUTE_MJC_NONZERO_SCHEDULE_NOT_OBSERVED")
    row.update(
        schema_version=TRACE_ROW_SCHEMA,
        route_id=ROUTE_ID,
        engine_id=ENGINE_ID,
        cell_id=CELL_ID,
        campaign_seed=CAMPAIGN_SEED,
        semantic_step=semantic_step,
        trace_step=semantic_step,
        phase_id="commanded_turn",
        segment_id="commanded_turn",
        desired_heading_offset_rad=HEADING_OFFSET_RAD,
    )
    return row


@contextmanager
def _route_bindings() -> Iterator[None]:
    if not _BINDING_LOCK.acquire(blocking=False):
        raise _core.R23D3MujocoError("TURNING_ROUTE_MJC_CONCURRENT_BINDING_REFUSED")
    saved = {
        "runtime": production._RUNTIME,
        "ramp": production._RAMP,
        "campaign_seed": production.CAMPAIGN_SEED,
        "reanchor_steps": production.EXPECTED_REANCHOR_STEPS,
        "design_steps": production.public_design.CONTROLLER_STEPS,
        "design_perturbation": production.public_design.INITIAL_PERTURBATION,
        "bound_seed": production._bound_base.CAMPAIGN_SEED,
    }
    try:
        production._RUNTIME = production._RuntimeCapture()
        production._RUNTIME.reset()
        production._RAMP = production._StartupRampRun()
        production.CAMPAIGN_SEED = CAMPAIGN_SEED
        production.EXPECTED_REANCHOR_STEPS = ()
        production.public_design.CONTROLLER_STEPS = CONTROLLER_STEPS
        production.public_design.INITIAL_PERTURBATION = copy.deepcopy(
            INITIAL_PERTURBATION
        )
        production._bound_base.CAMPAIGN_SEED = CAMPAIGN_SEED
        yield
    finally:
        production._RUNTIME = saved["runtime"]
        production._RAMP = saved["ramp"]
        production.CAMPAIGN_SEED = saved["campaign_seed"]
        production.EXPECTED_REANCHOR_STEPS = saved["reanchor_steps"]
        production.public_design.CONTROLLER_STEPS = saved["design_steps"]
        production.public_design.INITIAL_PERTURBATION = saved[
            "design_perturbation"
        ]
        production._bound_base.CAMPAIGN_SEED = saved["bound_seed"]
        _BINDING_LOCK.release()


def _run_preflight_bound() -> dict[str, Any]:
    contract = _contract()
    core = production._R23D65Core(production.CORE_LIBRARY)
    compiled, profile = production._bound_base._compile_boundary(core)
    memory = core.balanced_wave_initial_memory()
    schedule = [_segment_for_step(_Cell(), step) for step in range(CONTROLLER_STEPS)]
    if (
        compiled.get("morphology_id") != MORPHOLOGY_ID
        or profile.get("policy_id") != POLICY_ID
        or memory.get("schema_version") != MEMORY_SCHEMA
        or schedule != [("commanded_turn", HEADING_OFFSET_RAD)] * CONTROLLER_STEPS
        or production._RUNTIME.route is None
    ):
        raise _core.R23D3MujocoError("TURNING_ROUTE_MJC_PREFLIGHT_INVALID")
    wrong_horizon = copy.deepcopy(contract)
    wrong_horizon["development_ghost"]["controller_step_count"] = 3
    wrong_population = copy.deepcopy(contract)
    wrong_population["development_ghost"]["ordered_engine_ids"] = [
        "godot_jolt",
        "mujoco",
    ]
    rejected = 0
    for candidate in (wrong_horizon, wrong_population):
        try:
            _validate_contract_value(candidate)
        except _core.R23D3MujocoError:
            rejected += 1
    if rejected != 2:
        raise _core.R23D3MujocoError(
            "TURNING_ROUTE_MJC_NEGATIVE_CONTROL_NOT_REJECTED"
        )
    route = production._RUNTIME.route
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "ok": True,
        "failure_code": "",
        "route_id": ROUTE_ID,
        "ledger_scope": copy.deepcopy(LEDGER_SCOPE),
        "question_class": "development",
        "engine_id": ENGINE_ID,
        "cell_id": CELL_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "controller_step_count": CONTROLLER_STEPS,
        "nonzero_turn_command_compiled": True,
        "public_profile_route_compiled": True,
        "production_model_xml_sha256": route.model_xml_sha256,
        "production_model_xml_byte_length": len(route.model_xml_bytes),
        "negative_control_count": 2,
        "negative_controls_rejected": 2,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_behavior_thresholds_applied": False,
        "physical_acceptance_authority": False,
    }


def run_preflight() -> dict[str, Any]:
    with _route_bindings():
        return _run_preflight_bound()


def _inherited_preflight_bridge(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    **_kwargs: Any,
) -> dict[str, Any]:
    _cell(stage_id, onset_id, arm_id)
    return _run_preflight_bound()


for _name, _value in {
    "design": _design,
    "evaluator": _evaluator,
    "base": production._bound_base,
    "LocomotionCore": production._R23D65Core,
    "PREREGISTRATION_PATH": CONTRACT_PATH,
    "PHYSICAL_EVALUATOR_PATH": EVALUATOR_PATH,
    "CLOSURE_PATH": TURNING_ROOT / "three_engine_turning_route_never_closed_here.json",
    "WORKER_PATH": WORKER_PATH,
    "CAMPAIGN_ID": ROUTE_ID,
    "GATE_ID": ROUTE_ID,
    "REPORT_SCHEMA": REPORT_SCHEMA,
    "FAILURE_SCHEMA": FAILURE_SCHEMA,
    "FREEZE_SCHEMA": FREEZE_SCHEMA,
    "ATTEMPT_SCHEMA": ATTEMPT_SCHEMA,
    "SCHEDULE_ID": "sporespore_turning_route_positive_two_step_schedule_v1",
    "CONTROLLER_STEPS": CONTROLLER_STEPS,
    "ACTUATOR_COUNT": ACTUATOR_COUNT,
    "TURN_DURATION_STEPS": CONTROLLER_STEPS,
    "TERMINAL_SETTLE_STEPS": 0,
    "FREEZE_PATH_ENV": FREEZE_PATH_ENV,
    "ATTEMPT_PATH_ENV": ATTEMPT_PATH_ENV,
    "AUTHORIZATION_TOKEN_ENV": TOKEN_ENV,
    "STAGE_ID_ENV": "SPORESPORE_TURNING_ROUTE_STAGE",
    "CELL_ID_ENV": CELL_ENV,
    "ENGINE_ID_ENV": ENGINE_ENV,
    "ATTEMPT_ROOT_ENV": ATTEMPT_ROOT_ENV,
    "PYTHON_ENV": PYTHON_ENV,
    "POWERSHELL_ENV": POWERSHELL_ENV,
    "_cell": _cell,
    "_contract": _contract,
    "_source_bindings_exact": lambda *_args: False,
    "_physical_authorization": _physical_authorization,
    "_retain_trace": _retain_trace,
    "run_preflight": _inherited_preflight_bridge,
}.items():
    setattr(_core, _name, _value)
_core._trace_row = _trace_row


def _failure(
    code: str,
    source_commit: str = "",
    *,
    world_attempt_count: int = 0,
    world_build_count: int = 0,
) -> dict[str, Any]:
    return {
        "schema_version": FAILURE_SCHEMA,
        "campaign_id": ROUTE_ID,
        "gate_id": ROUTE_ID,
        "route_id": ROUTE_ID,
        "ledger_scope": copy.deepcopy(LEDGER_SCOPE),
        "question_class": "development",
        "stage_id": STAGE_ID,
        "engine_id": ENGINE_ID,
        "cell_id": CELL_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "profile_id": PROFILE_ID,
        "profile_sha256": PROFILE_SHA256,
        "host_mapping_id": HOST_MAPPING_ID,
        "arm_id": ARM_ID,
        "turn_heading_offset_rad": HEADING_OFFSET_RAD,
        "source_commit": source_commit,
        "failure_stage": "before_world",
        "failure_code": code,
        "model_construction_count": world_build_count,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "physical_behavior_thresholds_applied": False,
        "claims": copy.deepcopy(FALSE_CLAIMS),
        "physical_acceptance_authority": False,
    }


def _normalize_failure(value: Mapping[str, Any], source_commit: str) -> dict[str, Any]:
    attempts = int(value.get("world_attempt_count", 0))
    builds = int(value.get("world_build_count", 0))
    result = dict(value)
    result.update(
        _failure(
            str(value.get("failure_code", "TURNING_ROUTE_MJC_WORKER_FAILURE")),
            source_commit,
            world_attempt_count=attempts,
            world_build_count=builds,
        )
    )
    result["failure_stage"] = value.get("failure_stage", "before_world")
    if "trace_artifact" in value:
        result["trace_artifact"] = copy.deepcopy(value["trace_artifact"])
    return result


def run_authorization_preflight(source_commit: str) -> dict[str, Any]:
    _contract()
    authorization = _physical_authorization(_Cell(), source_commit)
    return {
        "schema_version": AUTHORIZATION_SCHEMA,
        "ok": True,
        "failure_code": "",
        "route_id": ROUTE_ID,
        "ledger_scope": copy.deepcopy(LEDGER_SCOPE),
        "engine_id": ENGINE_ID,
        "cell_id": CELL_ID,
        "attempt_root": str(authorization["attempt_root"]),
        "authorization_passed": True,
        "returned_before_model": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def run_physical(source_commit: str) -> dict[str, Any]:
    with _route_bindings():
        report = _core.run_physical(STAGE_ID, ONSET_ID, ARM_ID, source_commit)
        if production._RUNTIME.route is None or production._RUNTIME.physical_binding is None:
            raise _core.R23D3MujocoError(
                "TURNING_ROUTE_MJC_PUBLIC_PROFILE_EVIDENCE_MISSING",
                world_attempt_count=1,
                world_build_count=1,
            )
        startup_summary = production._RAMP.summary()
        runtime_integrity = (
            not production._RUNTIME.controller_commands
            and not production._RUNTIME.native_applications
            and not production._RUNTIME.task_origins
            and production._RUNTIME.task_origin_reanchor_count == 0
        )
        trace_summary = report.get("trace_summary", {})
        nonzero_steps = int(trace_summary.get("nonzero_turn_command_step_count", -1))
        report.update(
            schema_version=REPORT_SCHEMA,
            campaign_id=ROUTE_ID,
            gate_id=ROUTE_ID,
            route_id=ROUTE_ID,
            ledger_scope=copy.deepcopy(LEDGER_SCOPE),
            question_class="development",
            stage_id=STAGE_ID,
            engine_id=ENGINE_ID,
            cell_id=CELL_ID,
            campaign_seed=CAMPAIGN_SEED,
            profile_id=PROFILE_ID,
            profile_sha256=PROFILE_SHA256,
            host_mapping_id=HOST_MAPPING_ID,
            arm_id=ARM_ID,
            turn_heading_offset_rad=HEADING_OFFSET_RAD,
            source_commit=source_commit,
            physical_behavior_thresholds_applied=False,
            claims=copy.deepcopy(FALSE_CLAIMS),
            physical_acceptance_authority=False,
        )
        report["actuator_cap_profile_resolution_receipt"] = copy.deepcopy(
            production._RUNTIME.route.resolution_receipt
        )
        report["actuator_cap_profile_host_mapping_receipt"] = copy.deepcopy(
            production._RUNTIME.route.host_mapping_receipt
        )
        report["actuator_cap_profile_physical_binding_receipt"] = copy.deepcopy(
            production._RUNTIME.physical_binding
        )
        report["measurements"].update(startup_summary)
        report["execution"].update(startup_summary)
        report["execution"].update(
            nonzero_turn_command_step_count=nonzero_steps,
            public_profile_model_xml_sha256=(
                production._RUNTIME.route.model_xml_sha256
            ),
            public_profile_model_xml_consumed_directly=True,
            physical_binding_completed_before_first_solver_step=True,
            task_frame_origin_reanchor_count=0,
            runtime_capture_integrity_passed=runtime_integrity,
        )
        report["execution"]["integrity_passed"] = bool(
            report["execution"]["integrity_passed"]
            and startup_summary["startup_ramp_composition_integrity_passed"]
            and startup_summary["startup_transform_composition_integrity_passed"]
            and runtime_integrity
            and nonzero_steps >= 1
        )
        report["trace_retention"] = {
            "schema_version": RETENTION_SCHEMA,
            "route_id": ROUTE_ID,
            "ledger_scope": copy.deepcopy(LEDGER_SCOPE),
            "question_class": "development",
            "engine_id": ENGINE_ID,
            "cell_id": CELL_ID,
            "campaign_seed": CAMPAIGN_SEED,
            "row_count": trace_summary.get("row_count"),
            "first_semantic_step": trace_summary.get("first_semantic_step"),
            "last_semantic_step": trace_summary.get("last_semantic_step"),
            "nonzero_turn_command_step_count": nonzero_steps,
            "canonical_ndjson": True,
            "retained_before_terminal_entry": True,
            "trace_artifact": copy.deepcopy(report.get("trace_artifact")),
            "physical_behavior_thresholds_applied": False,
            "physical_acceptance_authority": False,
        }
        report.pop("model_construction_count", None)
        report.pop("world_attempt_count", None)
        report.pop("world_build_count", None)
        json.dumps(report, allow_nan=False)
        return report


def _arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    authorization = commands.add_parser("authorization-preflight")
    authorization.add_argument("--source-commit", required=True)
    physical = commands.add_parser("physical")
    physical.add_argument("--source-commit", required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(argv)
    try:
        if arguments.command == "preflight":
            value = run_preflight()
            marker = "SPORESPORE_TURNING_ROUTE_MUJOCO_PREFLIGHT "
        elif arguments.command == "authorization-preflight":
            value = run_authorization_preflight(arguments.source_commit)
            marker = "SPORESPORE_TURNING_ROUTE_MUJOCO_AUTHORIZATION_PREFLIGHT "
        else:
            value = run_physical(arguments.source_commit)
            marker = "SPORESPORE_TURNING_ROUTE_MUJOCO_TERMINAL "
        print(
            marker
            + json.dumps(
                value,
                allow_nan=False,
                ensure_ascii=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 0
    except (
        production.R23D65MujocoRouteError,
        _core.R23D3MujocoError,
        KeyError,
        OSError,
        TypeError,
        ValueError,
    ) as error:
        if isinstance(error, _core.R23D3MujocoError):
            source = getattr(arguments, "source_commit", "")
            value = _normalize_failure(
                error.terminal_receipt or {
                    "failure_code": error.code,
                    "world_attempt_count": error.world_attempt_count,
                    "world_build_count": error.world_build_count,
                },
                source,
            )
        else:
            value = _failure(
                f"TURNING_ROUTE_MJC_WORKER_ERROR:{type(error).__name__}:{error}",
                getattr(arguments, "source_commit", ""),
            )
        print(
            "SPORESPORE_TURNING_ROUTE_MUJOCO_TERMINAL "
            + json.dumps(
                value,
                allow_nan=False,
                ensure_ascii=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
