"""Classic-MuJoCo worker for the prospective QSDK-R23D3 campaign.

The worker reuses the already-commissioned R23D2 MuJoCo fixture and native
mapping helpers without reopening that consumed campaign.  R23D3 supplies a
new identity, onset schedule, diagnostic trace, terminal schemas, and physical
authorization chain.  No model can be constructed unless a later frozen
R23D3 source identity and single-use supervisor attempt are both supplied.
"""

from __future__ import annotations

import argparse
import copy
from dataclasses import dataclass
import hashlib
import json
import math
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Iterable

import numpy as np

from sporespore_locomotion import LocomotionCore

from . import qsdk_r23d2_heading_response as base


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

import r23d3_phase_balanced as design  # noqa: E402
import r23d3_physical_evaluator as evaluator  # noqa: E402


PREREGISTRATION_PATH = TURNING_ROOT / "r23d3_phase_balanced_preregistration_v1.json"
PHYSICAL_EVALUATOR_PATH = TURNING_ROOT / "r23d3_physical_evaluator.py"
CLOSURE_PATH = TURNING_ROOT / "r23d3_physical_closure_v1.json"
TRACE_PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d3_trace.ps1"
WORKER_PATH = (
    SDK_ROOT
    / "adapters"
    / "mujoco"
    / "sporespore_mujoco_adapter"
    / "qsdk_r23d3_phase_balanced.py"
)

CAMPAIGN_ID = design.CAMPAIGN_ID
GATE_ID = design.GATE_ID
ENGINE_ID = "mujoco"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r23d3_mujoco_worker_preflight_v1"
REPORT_SCHEMA = evaluator.REPORT_SCHEMA
FAILURE_SCHEMA = evaluator.FAILURE_SCHEMA
SCHEDULE_ID = "qsdk_r23d3_selected_onset_turn_return_v1"
FREEZE_SCHEMA = "sporespore_qsdk_r23d3_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d3_attempt_v1"

CONTROLLER_STEPS = design.CONTROLLER_STEPS
ACTUATOR_COUNT = design.ACTUATOR_COUNT
TURN_DURATION_STEPS = design.TURN_DURATION_STEPS
TERMINAL_SETTLE_STEPS = base.TERMINAL_SETTLE_STEPS
TOLERANCE = 1.0e-12
FORWARD_DISPLACEMENT_MEASUREMENT_ORIGIN_SCHEMA = (
    "sporespore_forward_displacement_measurement_origin_receipt_v1"
)
LEGACY_TASK_FRAME_MEASUREMENT_ORIGIN_POLICY_ID = (
    "mutable_task_frame_origin_legacy_v1"
)
EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID = (
    "evidence_window_start_semantic_step_v1"
)
EVIDENCE_WINDOW_START_SEMANTIC_STEP = 472

FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D3_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D3_ATTEMPT"
AUTHORIZATION_TOKEN_ENV = "SPORESPORE_QSDK_R23D3_TOKEN"
STAGE_ID_ENV = "SPORESPORE_QSDK_R23D3_STAGE"
CELL_ID_ENV = "SPORESPORE_QSDK_R23D3_CELL"
ENGINE_ID_ENV = "SPORESPORE_QSDK_R23D3_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D3_ATTEMPT_ROOT"
PYTHON_ENV = "SPORESPORE_QSDK_R23D3_PYTHON"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D3_POWERSHELL"


class R23D3MujocoError(RuntimeError):
    def __init__(
        self,
        code: str,
        *,
        world_attempt_count: int = 0,
        world_build_count: int = 0,
        terminal_receipt: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(code)
        self.code = code
        self.world_attempt_count = world_attempt_count
        self.world_build_count = world_build_count
        self.terminal_receipt = terminal_receipt


@dataclass(frozen=True)
class ForwardDisplacementMeasurementOriginPlan:
    """Select terminal-advance origin without changing controller task state."""

    policy_id: str
    semantic_step: int | None


LEGACY_FORWARD_DISPLACEMENT_MEASUREMENT_ORIGIN_PLAN = (
    ForwardDisplacementMeasurementOriginPlan(
        policy_id=LEGACY_TASK_FRAME_MEASUREMENT_ORIGIN_POLICY_ID,
        semantic_step=None,
    )
)


def evidence_window_forward_displacement_measurement_origin_plan(
    semantic_step: int = EVIDENCE_WINDOW_START_SEMANTIC_STEP,
) -> ForwardDisplacementMeasurementOriginPlan:
    return ForwardDisplacementMeasurementOriginPlan(
        policy_id=EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID,
        semantic_step=semantic_step,
    )


def _validated_forward_displacement_measurement_origin_plan(
    plan: ForwardDisplacementMeasurementOriginPlan | None,
    *,
    controller_steps: int,
) -> ForwardDisplacementMeasurementOriginPlan:
    selected = plan or LEGACY_FORWARD_DISPLACEMENT_MEASUREMENT_ORIGIN_PLAN
    if not isinstance(selected, ForwardDisplacementMeasurementOriginPlan):
        raise R23D3MujocoError("QSDK_MJC_FORWARD_MEASUREMENT_PLAN_TYPE_INVALID")
    if selected.policy_id == LEGACY_TASK_FRAME_MEASUREMENT_ORIGIN_POLICY_ID:
        valid = selected.semantic_step is None
    elif selected.policy_id == EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID:
        valid = (
            isinstance(selected.semantic_step, int)
            and not isinstance(selected.semantic_step, bool)
            and 0 <= selected.semantic_step < controller_steps
        )
    else:
        valid = False
    if not valid:
        raise R23D3MujocoError("QSDK_MJC_FORWARD_MEASUREMENT_PLAN_INVALID")
    return selected


def _project_forward_displacement_measurement(
    *,
    plan: ForwardDisplacementMeasurementOriginPlan,
    mutable_task_origin_world_m: np.ndarray,
    evidence_window_origin_world_m: np.ndarray | None,
    final_position_world_m: np.ndarray,
    reference_heading_rad: float,
) -> tuple[float, dict[str, Any] | None]:
    vectors = (
        mutable_task_origin_world_m,
        final_position_world_m,
    )
    if any(value.shape != (3,) or not np.isfinite(value).all() for value in vectors):
        raise R23D3MujocoError("QSDK_MJC_FORWARD_MEASUREMENT_VECTOR_INVALID")
    if not math.isfinite(reference_heading_rad):
        raise R23D3MujocoError("QSDK_MJC_FORWARD_MEASUREMENT_HEADING_INVALID")

    if plan.policy_id == LEGACY_TASK_FRAME_MEASUREMENT_ORIGIN_POLICY_ID:
        if evidence_window_origin_world_m is not None:
            raise R23D3MujocoError(
                "QSDK_MJC_FORWARD_MEASUREMENT_LEGACY_CAPTURE_AMBIGUOUS"
            )
        origin = mutable_task_origin_world_m
        receipt = None
    elif plan.policy_id == EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID:
        if (
            evidence_window_origin_world_m is None
            or evidence_window_origin_world_m.shape != (3,)
            or not np.isfinite(evidence_window_origin_world_m).all()
            or plan.semantic_step is None
        ):
            raise R23D3MujocoError(
                "QSDK_MJC_FORWARD_MEASUREMENT_EVIDENCE_CAPTURE_MISSING"
            )
        origin = evidence_window_origin_world_m
        receipt = {
            "schema_version": FORWARD_DISPLACEMENT_MEASUREMENT_ORIGIN_SCHEMA,
            "policy_id": plan.policy_id,
            "semantic_step": plan.semantic_step,
            "origin_world_m": [float(value) for value in origin],
            "captured_before_controller_step": True,
            "task_frame_reanchors_change_measurement_origin": False,
            "physical_acceptance_authority": False,
        }
    else:
        raise R23D3MujocoError("QSDK_MJC_FORWARD_MEASUREMENT_POLICY_INVALID")

    task_forward = np.asarray(
        [math.cos(reference_heading_rad), 0.0, math.sin(reference_heading_rad)],
        dtype=np.float64,
    )
    return float((final_position_world_m - origin) @ task_forward), receipt


def run_forward_displacement_measurement_origin_preflight(
    plan: ForwardDisplacementMeasurementOriginPlan,
    *,
    controller_steps: int = CONTROLLER_STEPS,
) -> dict[str, Any]:
    """Exercise measurement semantics and negatives without constructing a model."""

    selected = _validated_forward_displacement_measurement_origin_plan(
        plan,
        controller_steps=controller_steps,
    )
    task_origin = np.asarray([1.9, 0.42, 0.02], dtype=np.float64)
    evidence_origin = np.asarray([0.4, 0.42, -0.01], dtype=np.float64)
    final_position = np.asarray([1.901, 0.42, 0.02], dtype=np.float64)
    displacement, receipt = _project_forward_displacement_measurement(
        plan=selected,
        mutable_task_origin_world_m=task_origin,
        evidence_window_origin_world_m=evidence_origin,
        final_position_world_m=final_position,
        reference_heading_rad=0.0,
    )
    if receipt is None or abs(displacement - 1.501) > TOLERANCE:
        raise R23D3MujocoError("QSDK_MJC_FORWARD_MEASUREMENT_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_mujoco_forward_displacement_measurement_origin_preflight_v1",
        "engine_id": ENGINE_ID,
        "measurement_origin": receipt,
        "synthetic_final_forward_displacement_m": displacement,
        "controller_task_origin_unchanged": bool(np.array_equal(task_origin, [1.9, 0.42, 0.02])),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


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
        raise R23D3MujocoError(f"{code}:{type(error).__name__}") from error
    if not isinstance(value, dict):
        raise R23D3MujocoError(code)
    return value


def _contract() -> dict[str, Any]:
    contract = _read_json(PREREGISTRATION_PATH, "QSDK_R23D3_MJC_CONTRACT_UNREADABLE")
    if (
        contract.get("schema_version")
        != "sporespore_qsdk_r23d3_phase_balanced_preregistration_v1"
        or contract.get("campaign_id") != CAMPAIGN_ID
        or contract.get("gate_id") != GATE_ID
        or contract.get("fixture", {}).get("morphology_id") != base.MORPHOLOGY_ID
        or contract.get("fixture", {}).get("selected_policy_id") != base.POLICY_ID
        or contract.get("fixture", {}).get("selected_policy_digest")
        != base.POLICY_DIGEST
        or contract.get("fixture", {}).get("campaign_seed") != base.CAMPAIGN_SEED
        or contract.get("fixture", {}).get("physics_hz") != base.PHYSICS_HZ
        or contract.get("fixture", {}).get("authored_sliding_friction")
        != base.bridge.AUTHORED_FRICTION
        or contract.get("command_schedule", {}).get(
            "controller_semantic_step_count"
        )
        != CONTROLLER_STEPS
        or contract.get("command_schedule", {}).get("turn_duration_steps")
        != TURN_DURATION_STEPS
        or contract.get("authorization", {}).get("physical_execution_authorized")
        is not False
    ):
        raise R23D3MujocoError("QSDK_R23D3_MJC_CONTRACT_IDENTITY_INVALID")
    return contract


def _cell(stage_id: str, onset_id: str, arm_id: str) -> design.Cell:
    candidates = (
        design.stage_a_cells()
        if stage_id == "mujoco_onset_screen"
        else design.stage_b_cells(onset_id)
        if stage_id == "three_engine_confirmation"
        else []
    )
    matches = [
        cell
        for cell in candidates
        if cell.engine_id == ENGINE_ID
        and cell.onset_id == onset_id
        and cell.arm_id == arm_id
    ]
    if len(matches) != 1:
        raise R23D3MujocoError(
            f"QSDK_R23D3_MJC_CELL_IDENTITY_INVALID:{stage_id}:{onset_id}:{arm_id}"
        )
    return matches[0]


def _heading_schedule(
    cell: design.Cell,
    semantic_step: int,
    reference_heading_rad: float,
) -> dict[str, Any]:
    segment_id, offset = design.segment_for_step(cell, semantic_step)
    return {
        "segment_id": segment_id,
        "heading_offset_rad": offset,
        "desired_heading_rad": base._wrap_angle(reference_heading_rad + offset),
    }


def _motion_command(
    semantic_step: int,
    phase_progression_mode: str,
    heading: dict[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_motion_command_v2",
        "command_id": f"{SCHEDULE_ID}_{heading['segment_id']}",
        "desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
        "desired_heading_rad": heading["desired_heading_rad"],
        "desired_yaw_rate_rad_s": None,
        "gait_family_id": "lateral_wave",
        "speed_class": "walk",
        "gait_amplitude": 1.0,
        "phase_progression_mode": phase_progression_mode,
        "valid_from_step": semantic_step,
        "valid_through_step": semantic_step,
        "authority": "test_fixture",
    }


def _limb_phase(memory: dict[str, Any]) -> list[dict[str, Any]]:
    offsets = dict(zip(design.LIMB_IDS, design.PHASE_OFFSETS, strict=True))
    result: list[dict[str, Any]] = []
    for expected_limb, limb in zip(
        design.LIMB_IDS, memory["ordered_limb_memory"], strict=True
    ):
        if limb.get("limb_id") != expected_limb:
            raise R23D3MujocoError("QSDK_R23D3_MJC_LIMB_MEMORY_ORDER_INVALID")
        gait_step = int(limb["gait_step"])
        result.append(
            {
                "limb_id": expected_limb,
                "gait_step": gait_step,
                "local_phase_step": (
                    gait_step + design.GAIT_CYCLE_STEPS - offsets[expected_limb]
                )
                % design.GAIT_CYCLE_STEPS,
                "release_hold_step_count": int(limb["release_hold_step_count"]),
            }
        )
    return result


def _trace_row(
    *,
    cell: design.Cell,
    semantic_step: int,
    heading: dict[str, Any],
    receipt: dict[str, Any],
    metrics: dict[str, Any],
    limb_phase_before: list[dict[str, Any]],
    contacts_before: dict[str, bool],
    contacts_after: dict[str, bool],
    native_application_count: int,
) -> dict[str, Any]:
    requested = float(receipt["requested_steering_fraction"])
    held = float(receipt["held_steering_fraction"])
    return {
        "schema_version": design.TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "semantic_step": semantic_step,
        "segment_id": heading["segment_id"],
        "desired_heading_offset_rad": float(heading["heading_offset_rad"]),
        "measured_yaw_rad": float(metrics["yaw_rad"]),
        "desired_heading_error_rad": float(receipt["desired_heading_error_rad"]),
        "yaw_tracking_error_rad": float(receipt["yaw_tracking_error_rad"]),
        "requested_steering_fraction": requested,
        "held_steering_fraction": held,
        "steering_saturated": (
            abs(requested) >= 0.4 - TOLERANCE or abs(held) >= 0.4 - TOLERANCE
        ),
        "torso_position_world_m": [
            float(metrics["x"]),
            float(metrics["y"]),
            float(metrics["z"]),
        ],
        "torso_height_m": float(metrics["y"]),
        "torso_tilt_rad": float(metrics["tilt_rad"]),
        "torso_ground_contact": bool(metrics["ground_contact"]),
        "ordered_limb_phase_before": limb_phase_before,
        "ordered_foot_contacts_before": contacts_before,
        "ordered_foot_contacts_after": contacts_after,
        "validated_portable_command_count": ACTUATOR_COUNT,
        "native_actuation_application_count": native_application_count,
        "oracle_passed": True,
    }


def _source_bindings_exact(freeze: dict[str, Any]) -> bool:
    required = {
        str(WORKER_PATH.relative_to(REPO_ROOT)).replace("\\", "/"): _raw_sha256(
            WORKER_PATH
        ),
        str(PREREGISTRATION_PATH.relative_to(REPO_ROOT)).replace("\\", "/"):
            _raw_sha256(PREREGISTRATION_PATH),
        str(PHYSICAL_EVALUATOR_PATH.relative_to(REPO_ROOT)).replace("\\", "/"):
            _raw_sha256(PHYSICAL_EVALUATOR_PATH),
        str(TRACE_PUBLISHER_PATH.relative_to(REPO_ROOT)).replace("\\", "/"):
            _raw_sha256(TRACE_PUBLISHER_PATH),
        str(Path(base.__file__).resolve().relative_to(REPO_ROOT)).replace("\\", "/"):
            _raw_sha256(Path(base.__file__).resolve()),
    }
    bindings = freeze.get("source_bindings")
    if not isinstance(bindings, list):
        return False
    observed = {
        str(item.get("path")): str(item.get("raw_sha256"))
        for item in bindings
        if isinstance(item, dict)
    }
    return all(observed.get(path) == digest for path, digest in required.items())


def _physical_authorization(cell: design.Cell, source_commit: str) -> dict[str, Any]:
    if CLOSURE_PATH.is_file():
        raise R23D3MujocoError("QSDK_R23D3_MJC_CLOSED")
    freeze_path = Path(os.environ.get(FREEZE_PATH_ENV, ""))
    attempt_path = Path(os.environ.get(ATTEMPT_PATH_ENV, ""))
    token = os.environ.get(AUTHORIZATION_TOKEN_ENV, "")
    attempt_root = Path(os.environ.get(ATTEMPT_ROOT_ENV, ""))
    if (
        not freeze_path.is_file()
        or not attempt_path.is_file()
        or not attempt_root.is_dir()
        or not _valid_lower_hex(token, 32)
    ):
        raise R23D3MujocoError("QSDK_R23D3_MJC_PHYSICAL_AUTHORIZATION_REQUIRED")
    freeze = _read_json(freeze_path, "QSDK_R23D3_MJC_FREEZE_UNREADABLE")
    attempt = _read_json(attempt_path, "QSDK_R23D3_MJC_ATTEMPT_UNREADABLE")
    production_root = (REPO_ROOT.parent / "SporeSpore_Evidence").resolve()
    try:
        attempt_root.resolve().relative_to(production_root)
    except ValueError as error:
        raise R23D3MujocoError("QSDK_R23D3_MJC_ATTEMPT_ROOT_NOT_DURABLE") from error
    stage_ids = (
        attempt.get("ordered_stage_a_cell_ids", [])
        if cell.stage_id == "mujoco_onset_screen"
        else attempt.get("ordered_stage_b_cell_ids", [])
    )
    if (
        freeze.get("schema_version") != FREEZE_SCHEMA
        or freeze.get("campaign_id") != CAMPAIGN_ID
        or freeze.get("gate_id") != GATE_ID
        or freeze.get("status") != "frozen_supervisor_only_physical_authorized"
        or freeze.get("preregistration_raw_sha256")
        != _raw_sha256(PREREGISTRATION_PATH)
        or freeze.get("source_commit") != source_commit
        or freeze.get("physical_execution_authorized") is not True
        or not _source_bindings_exact(freeze)
        or attempt.get("schema_version") != ATTEMPT_SCHEMA
        or attempt.get("campaign_id") != CAMPAIGN_ID
        or attempt.get("gate_id") != GATE_ID
        or attempt.get("freeze_raw_sha256") != _raw_sha256(freeze_path)
        or attempt.get("source_commit") != source_commit
        or attempt.get("authorization_token") != token
        or not _valid_lower_hex(attempt.get("attempt_id"), 32)
        or attempt.get("physical_execution_authorized") is not True
        or attempt.get("single_use_supervisor_authorization") is not True
        or attempt.get("source_worktree_clean") is not True
        or attempt.get("source_matches_live_github_main") is not True
        or attempt.get("operation_lock_held") is not True
        or attempt.get("full_godot_attestation_valid") is not True
        or attempt.get("content_addressed_inputs_retained") is not True
        or attempt.get("one_shot_attempt_unconsumed") is not True
        or Path(str(attempt.get("attempt_root", ""))).resolve()
        != attempt_root.resolve()
        or os.environ.get(STAGE_ID_ENV, "") != cell.stage_id
        or os.environ.get(CELL_ID_ENV, "") != cell.cell_id
        or os.environ.get(ENGINE_ID_ENV, "") != ENGINE_ID
        or cell.cell_id not in stage_ids
        or (
            cell.stage_id == "three_engine_confirmation"
            and attempt.get("selected_onset_id") != cell.onset_id
        )
    ):
        raise R23D3MujocoError("QSDK_R23D3_MJC_PHYSICAL_AUTHORIZATION_INVALID")
    return {"freeze": freeze, "attempt": attempt, "attempt_root": attempt_root}


def _failure_receipt(
    cell: design.Cell,
    source_commit: str,
    failure_stage: str,
    code: str,
    world_attempt_count: int,
    world_build_count: int,
    trace_artifact: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "schema_version": FAILURE_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": ENGINE_ID,
        "onset_id": cell.onset_id,
        "turn_start_semantic_step": cell.turn_start_semantic_step,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "raw_sdk_authority_summary": None,
        "godot_execution_predicates": None,
        "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
    }


def _raise_failure(
    cell: design.Cell,
    source_commit: str,
    stage: str,
    code: str,
    attempts: int,
    builds: int,
    trace_artifact: dict[str, Any] | None = None,
) -> R23D3MujocoError:
    receipt = _failure_receipt(
        cell, source_commit, stage, code, attempts, builds, trace_artifact
    )
    return R23D3MujocoError(
        code,
        world_attempt_count=attempts,
        world_build_count=builds,
        terminal_receipt=receipt,
    )


def _retain_trace(
    cell: design.Cell,
    rows: list[dict[str, Any]],
    attempt_root: Path,
) -> dict[str, Any]:
    pending_root = attempt_root / "pending-traces"
    pending_root.mkdir(parents=True, exist_ok=True)
    rows_path = pending_root / f"{cell.stage_id}__{cell.cell_id}.rows.json"
    with rows_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(rows, stream, allow_nan=False, separators=(",", ":"), sort_keys=True)
        stream.write("\n")
    python = os.environ.get(PYTHON_ENV, sys.executable)
    powershell = os.environ.get(POWERSHELL_ENV, "pwsh")
    process = subprocess.run(
        [
            python,
            str(PHYSICAL_EVALUATOR_PATH),
            "retain-trace",
            "--stage-id",
            cell.stage_id,
            "--cell-id",
            cell.cell_id,
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
        timeout=180,
    )
    marker = "QSDK_R23D3_TRACE_RETAINED "
    matches = [
        line[len(marker) :]
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise R23D3MujocoError(
            "QSDK_R23D3_MJC_TRACE_RETENTION_FAILED:"
            + str(process.returncode)
            + ":"
            + process.stderr[-500:],
            world_attempt_count=1,
            world_build_count=1,
        )
    receipt = json.loads(matches[0])
    if (
        receipt.get("schema_version") != evaluator.TRACE_RETENTION_SCHEMA
        or receipt.get("stage_id") != cell.stage_id
        or receipt.get("cell_id") != cell.cell_id
        or receipt.get("retained_before_terminal_entry") is not True
        or receipt.get("world_attempt_count") != 0
        or receipt.get("world_build_count") != 0
    ):
        raise R23D3MujocoError(
            "QSDK_R23D3_MJC_TRACE_RETENTION_RECEIPT_INVALID",
            world_attempt_count=1,
            world_build_count=1,
        )
    return receipt


def run_preflight(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    *,
    forward_displacement_measurement_origin_plan: (
        ForwardDisplacementMeasurementOriginPlan | None
    ) = None,
) -> dict[str, Any]:
    contract = _contract()
    cell = _cell(stage_id, onset_id, arm_id)
    inherited = base.run_preflight(arm_id)
    schedule = [design.segment_for_step(cell, step) for step in range(CONTROLLER_STEPS)]
    segment_counts = {
        segment: sum(item[0] == segment for item in schedule)
        for segment in design.expected_segment_counts(cell)
    }
    if (
        inherited.get("world_build_count") != 0
        or inherited.get("physical_acceptance_authority") is not False
        or inherited.get("native_command_count") != 64
        or inherited.get("predicate_negative_control_count") != 35
        or segment_counts != design.expected_segment_counts(cell)
        or len(schedule) != CONTROLLER_STEPS
        or contract["command_schedule"][
            "all_engine_physical_workers_must_execute_exact_fixed_controller_horizon"
        ]
        is not True
    ):
        raise R23D3MujocoError("QSDK_R23D3_MJC_PREFLIGHT_INVALID")
    receipt = {
        "schema_version": PREFLIGHT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "onset_id": cell.onset_id,
        "turn_start_semantic_step": cell.turn_start_semantic_step,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "preregistration_raw_sha256": _raw_sha256(PREREGISTRATION_PATH),
        "inherited_r23d2_zero_world_boundary_sha256": _raw_sha256(
            Path(base.__file__).resolve()
        ),
        "inherited_native_mapping_canary_count": inherited["canary_count"],
        "inherited_predicate_negative_control_count": inherited[
            "predicate_negative_control_count"
        ],
        "segment_counts": segment_counts,
        "fixed_controller_horizon_step_count": CONTROLLER_STEPS,
        "fixed_horizon_configuration_proved_before_fixture_insertion": True,
        "trace_retained_before_terminal_entry_required": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }
    if forward_displacement_measurement_origin_plan is not None:
        measurement_plan = _validated_forward_displacement_measurement_origin_plan(
            forward_displacement_measurement_origin_plan,
            controller_steps=CONTROLLER_STEPS,
        )
        measurement_preflight = run_forward_displacement_measurement_origin_preflight(
            measurement_plan,
            controller_steps=CONTROLLER_STEPS,
        )
        receipt["forward_displacement_measurement_origin"] = measurement_preflight[
            "measurement_origin"
        ]
        receipt["forward_displacement_measurement_origin_preflight_passed"] = True
    return receipt


def run_physical(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    source_commit: str,
    *,
    forward_displacement_measurement_origin_plan: (
        ForwardDisplacementMeasurementOriginPlan | None
    ) = None,
) -> dict[str, Any]:
    cell = _cell(stage_id, onset_id, arm_id)
    if not _valid_lower_hex(source_commit, 40):
        raise _raise_failure(
            cell,
            source_commit,
            "before_world",
            "QSDK_R23D3_MJC_SOURCE_COMMIT_INVALID",
            0,
            0,
        )
    try:
        measurement_plan = _validated_forward_displacement_measurement_origin_plan(
            forward_displacement_measurement_origin_plan,
            controller_steps=CONTROLLER_STEPS,
        )
        _contract()
        authorization = _physical_authorization(cell, source_commit)
        run_preflight(
            stage_id,
            onset_id,
            arm_id,
            forward_displacement_measurement_origin_plan=(
                forward_displacement_measurement_origin_plan
            ),
        )
        perturbation = base._initial_perturbation(base._contracts()[2])
        core = LocomotionCore()
        compiled, profile = base._compile_boundary(core)
    except R23D3MujocoError as error:
        raise _raise_failure(
            cell, source_commit, "before_world", error.code, 0, 0
        ) from error
    except Exception as error:
        raise _raise_failure(
            cell,
            source_commit,
            "before_world",
            f"QSDK_R23D3_MJC_PREFLIGHT_ERROR:{type(error).__name__}:{error}",
            0,
            0,
        ) from error

    try:
        robot = base.bridge.MujocoBw19vRobot(core, base.HOST_PROFILE_ID)
    except Exception as error:
        raise _raise_failure(
            cell,
            source_commit,
            "world_construction_failed",
            f"QSDK_R23D3_MJC_WORLD_CONSTRUCTION_ERROR:{type(error).__name__}:{error}",
            1,
            0,
        ) from error

    try:
        base._apply_initial_perturbation(robot, perturbation)
        for _ in range(base.SETTLE_STEPS):
            robot.prepare()
            base._zero_prepared_outer_step(robot)
        robot.prepare()
        initial = robot.torso_metrics()
        task_origin = np.asarray(
            [initial["x"], initial["y"], initial["z"]], dtype=np.float64
        )
        reference_heading_rad = float(initial["yaw_rad"])
        memory = core.balanced_wave_initial_memory()
        previous_contacts = base._foot_contacts(robot)
        contact_cycles = {limb: 0 for limb in design.LIMB_IDS}
        counters = {
            "controller_error_count": 0,
            "safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "validated_portable_command_count": 0,
            "native_actuation_application_count": 0,
            "portable_impulse_violation_count": 0,
            "torso_ground_contact_step_count": 0,
        }
        maximum_tilt = float(initial["tilt_rad"])
        minimum_height = float(initial["y"])
        maximum_requested = 0.0
        maximum_held = 0.0
        turn_start_yaw: float | None = None
        turn_end_yaw: float | None = None
        rows: list[dict[str, Any]] = []
        evidence_window_measurement_origin: np.ndarray | None = None

        for semantic_step in range(CONTROLLER_STEPS):
            if semantic_step == base.PHASE_OFFSET_ACTIVATION_STEP:
                base._phase_offset(memory, int(perturbation["gait_phase_offset_ticks"]))
            if semantic_step == base.CONTACT_GATED_START_STEP:
                for limb in memory["ordered_limb_memory"]:
                    limb["evidence_gait_step_limit"] = int(limb["gait_step"]) + 1 + 1_440
            phase_mode = (
                "clocked"
                if semantic_step < base.CONTACT_GATED_START_STEP
                else "contact_gated"
            )
            state = base._state_frame(
                robot, semantic_step, task_origin, reference_heading_rad
            )
            heading = _heading_schedule(cell, semantic_step, reference_heading_rad)
            if semantic_step == cell.turn_start_semantic_step:
                turn_start_yaw = float(robot.torso_metrics()["yaw_rad"])
            command = _motion_command(semantic_step, phase_mode, heading)
            limb_before = _limb_phase(memory)
            contacts_before = base._foot_contacts(robot)
            metrics_before = robot.torso_metrics()
            if measurement_plan.semantic_step == semantic_step:
                if evidence_window_measurement_origin is not None:
                    raise R23D3MujocoError(
                        "QSDK_MJC_FORWARD_MEASUREMENT_CAPTURE_DUPLICATE"
                    )
                evidence_window_measurement_origin = np.asarray(
                    [
                        metrics_before["x"],
                        metrics_before["y"],
                        metrics_before["z"],
                    ],
                    dtype=np.float64,
                )
            output = core.balanced_wave_policy_step(
                base.POLICY_ID,
                {
                    "descriptor": base.bridge.s169_descriptor(),
                    "memory": memory,
                    "state": state,
                    "command": command,
                },
            )
            actuation = output["actuation"]
            receipt = actuation["receipt"]
            counters["controller_error_count"] += int(
                receipt["controller_error"] is not None
            ) + len(actuation["failure_codes"])
            counters["safe_no_actuation_count"] += int(actuation["safe_no_actuation"])
            ordered_ids = list(compiled["morphology"]["ordered_actuator_ids"])
            if (
                receipt.get("semantic_step") != semantic_step
                or receipt.get("command_id") != command["command_id"]
                or receipt.get("policy_id") != base.POLICY_ID
                or [item["actuator_id"] for item in actuation["ordered_commands"]]
                != ordered_ids
                or len(actuation["ordered_commands"]) != ACTUATOR_COUNT
            ):
                raise R23D3MujocoError("QSDK_R23D3_MJC_CONTROLLER_OUTPUT_INVALID")
            expected = base._independent_oracle(state, command, profile)
            oracle_failures = base._predicate_failures(expected, receipt)
            if oracle_failures:
                raise R23D3MujocoError(
                    "QSDK_R23D3_MJC_CONTROLLER_RECEIPT_INVALID:"
                    + ",".join(oracle_failures)
                )
            canonical = core.canonical_velocity_compose_v1(
                {
                    "schema_version": "sporespore_canonical_velocity_compose_request_v1",
                    "descriptor": base.bridge.s169_descriptor(),
                    "source_actuation": actuation,
                    "ordered_stability_residuals": base._zero_residuals(actuation),
                }
            )
            mapping = core.canonical_velocity_host_map_v1(
                {
                    "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
                    "descriptor": base.bridge.s169_descriptor(),
                    "canonical_actuation": canonical,
                    "host_profile": base.bridge._mujoco_host_profile(base.HOST_PROFILE_ID),
                }
            )
            if (
                mapping.get("host_profile_id") != base.HOST_PROFILE_ID
                or mapping.get("engine_id") != ENGINE_ID
                or len(mapping.get("ordered_commands", [])) != ACTUATOR_COUNT
                or mapping.get("independent_native_position_feedback_applied") is not False
                or mapping.get("native_position_stiffness") != 0.0
            ):
                raise R23D3MujocoError("QSDK_R23D3_MJC_NATIVE_MAPPING_INVALID")
            requested = float(receipt["requested_steering_fraction"])
            held = float(receipt["held_steering_fraction"])
            maximum_requested = max(maximum_requested, abs(requested))
            maximum_held = max(maximum_held, abs(held))
            counters["validated_portable_command_count"] += len(
                actuation["ordered_commands"]
            )
            application = robot.apply_host_mapping(mapping)
            application_count = len(application["targets"])
            counters["native_actuation_application_count"] += application_count
            counters["portable_impulse_violation_count"] += int(
                application["portable_impulse_violation_count"]
            )
            counters["actuator_application_mismatch_count"] += int(
                application_count != ACTUATOR_COUNT
            )
            memory = output["next_memory"]
            robot.prepare()
            metrics = robot.torso_metrics()
            contacts_after = base._foot_contacts(robot)
            if semantic_step + 1 == cell.turn_start_semantic_step + TURN_DURATION_STEPS:
                turn_end_yaw = float(metrics["yaw_rad"])
            values = [
                float(metrics[key])
                for key in ("x", "y", "z", "tilt_rad", "yaw_rad")
            ]
            counters["nonfinite_observation_count"] += int(
                not np.isfinite(values).all()
            )
            maximum_tilt = max(maximum_tilt, float(metrics["tilt_rad"]))
            minimum_height = min(minimum_height, float(metrics["y"]))
            counters["torso_ground_contact_step_count"] += int(
                bool(metrics["ground_contact"])
            )
            if semantic_step >= base.CONTACT_GATED_START_STEP:
                for limb, present in contacts_after.items():
                    if not previous_contacts[limb] and present:
                        contact_cycles[limb] += 1
                    previous_contacts[limb] = present
            rows.append(
                _trace_row(
                    cell=cell,
                    semantic_step=semantic_step,
                    heading=heading,
                    receipt=receipt,
                    metrics=metrics_before,
                    limb_phase_before=limb_before,
                    contacts_before=contacts_before,
                    contacts_after=contacts_after,
                    native_application_count=application_count,
                )
            )

        for _ in range(TERMINAL_SETTLE_STEPS):
            base._zero_prepared_outer_step(robot)
            robot.prepare()
            metrics = robot.torso_metrics()
            maximum_tilt = max(maximum_tilt, float(metrics["tilt_rad"]))
            minimum_height = min(minimum_height, float(metrics["y"]))
            counters["torso_ground_contact_step_count"] += int(
                bool(metrics["ground_contact"])
            )

        final = robot.torso_metrics()
        final_forward_displacement_m, measurement_origin_receipt = (
            _project_forward_displacement_measurement(
                plan=measurement_plan,
                mutable_task_origin_world_m=task_origin,
                evidence_window_origin_world_m=evidence_window_measurement_origin,
                final_position_world_m=np.asarray(
                    [final["x"], final["y"], final["z"]],
                    dtype=np.float64,
                ),
                reference_heading_rad=reference_heading_rad,
            )
        )
        if turn_start_yaw is None or turn_end_yaw is None:
            raise R23D3MujocoError("QSDK_R23D3_MJC_TURN_WINDOW_INCOMPLETE")
        measurements = {
            "final_forward_displacement_m": final_forward_displacement_m,
            "turn_phase_yaw_delta_rad": base._wrap_angle(
                turn_end_yaw - turn_start_yaw
            ),
            "maximum_absolute_requested_steering_fraction": maximum_requested,
            "maximum_absolute_held_steering_fraction": maximum_held,
            "maximum_tilt_rad": maximum_tilt,
            "minimum_torso_height_m": minimum_height,
            "contact_cycle_count_by_limb": contact_cycles,
            "torso_ground_contact_step_count": counters[
                "torso_ground_contact_step_count"
            ],
            "controller_error_count": counters["controller_error_count"],
            "safe_no_actuation_count": counters["safe_no_actuation_count"],
            "nonfinite_observation_count": counters["nonfinite_observation_count"],
            "actuator_application_mismatch_count": counters[
                "actuator_application_mismatch_count"
            ],
            "controller_semantic_step_count": len(rows),
            "validated_portable_command_count": counters[
                "validated_portable_command_count"
            ],
            "native_actuation_application_count": counters[
                "native_actuation_application_count"
            ],
        }
        trace = _retain_trace(cell, rows, authorization["attempt_root"])
        report = {
            "schema_version": REPORT_SCHEMA,
            "campaign_id": CAMPAIGN_ID,
            "gate_id": GATE_ID,
            "stage_id": cell.stage_id,
            "cell_id": cell.cell_id,
            "engine_id": ENGINE_ID,
            "onset_id": cell.onset_id,
            "turn_start_semantic_step": cell.turn_start_semantic_step,
            "arm_id": cell.arm_id,
            "turn_heading_offset_rad": cell.turn_heading_offset_rad,
            "source_commit": source_commit,
            "trace_artifact": trace["trace_artifact"],
            "trace_summary": trace["trace_summary"],
            "execution": {
                "integrity_passed": True,
                "worker_failure_code": "",
                "controller_semantic_step_count": len(rows),
                "validated_portable_command_count": counters[
                    "validated_portable_command_count"
                ],
                "native_actuation_application_count": counters[
                    "native_actuation_application_count"
                ],
                "portable_impulse_violation_count": counters[
                    "portable_impulse_violation_count"
                ],
                "world_attempt_count": 1,
                "world_build_count": 1,
                "trace_retained_before_terminal_entry": True,
                "fixed_horizon_configuration_proved_before_fixture_insertion": True,
            },
            "measurements": measurements,
            "godot_execution_predicates": None,
            "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
        }
        if measurement_origin_receipt is not None:
            report["forward_displacement_measurement_origin"] = (
                measurement_origin_receipt
            )
        json.dumps(report, allow_nan=False)
        return report
    except R23D3MujocoError as error:
        if error.terminal_receipt is not None:
            raise
        raise _raise_failure(
            cell,
            source_commit,
            "settlement_complete",
            error.code,
            1,
            1,
        ) from error
    except Exception as error:
        raise _raise_failure(
            cell,
            source_commit,
            "settlement_complete",
            f"QSDK_R23D3_MJC_PHYSICAL_WORKER_ERROR:{type(error).__name__}:{error}",
            1,
            1,
        ) from error


def _arguments(arguments: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", required=True)
    parser.add_argument("--onset", required=True)
    parser.add_argument("--arm", required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight-only", action="store_true")
    mode.add_argument("--source-commit")
    return parser.parse_args(arguments)


def main(arguments: Iterable[str] | None = None) -> int:
    args = _arguments(arguments)
    try:
        value = (
            run_preflight(args.stage, args.onset, args.arm)
            if args.preflight_only
            else run_physical(args.stage, args.onset, args.arm, args.source_commit)
        )
    except R23D3MujocoError as error:
        cell: design.Cell | None = None
        try:
            cell = _cell(args.stage, args.onset, args.arm)
        except R23D3MujocoError:
            pass
        receipt = error.terminal_receipt
        if receipt is None and cell is not None:
            receipt = _failure_receipt(
                cell,
                args.source_commit or "0" * 40,
                "before_world",
                error.code,
                error.world_attempt_count,
                error.world_build_count,
            )
        print(
            "QSDK_R23D3_MUJOCO_FAILURE "
            + json.dumps(receipt or {"failure_code": error.code}, sort_keys=True)
        )
        return 1
    prefix = (
        "QSDK_R23D3_MUJOCO_PREFLIGHT "
        if args.preflight_only
        else "QSDK_R23D3_MUJOCO_CELL "
    )
    print(prefix + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
