
"""Classic-MuJoCo worker for prospective QSDK-R23D6.

The worker preserves R23D3's 2,992-step turning controller and adds the
preregistered 540-step contact-state-gated restoration plus a traced 240-step
zero-actuation settle.  Model construction remains impossible without a later
single-supervisor R23D6 freeze and attempt token.
"""

from __future__ import annotations

import argparse
import copy
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
from . import qsdk_r23d6_policy_compatible_restoration as restoration
from . import selected_policy_walking_mv3 as mv3


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

import r23d6_physical_evaluator as evaluator  # noqa: E402
import r23d4_terminal_stabilization as design  # noqa: E402


PREREGISTRATION_PATH = TURNING_ROOT / "r23d6_policy_compatible_restoration_preregistration_v1.json"
IMPLEMENTATION_PATH = TURNING_ROOT / "r23d6_implementation_contract_v1.json"
PHYSICAL_EVALUATOR_PATH = TURNING_ROOT / "r23d6_physical_evaluator.py"
CLOSURE_PATH = TURNING_ROOT / "r23d6_physical_closure_v1.json"
TRACE_PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d6_trace.ps1"
WORKER_PATH = Path(__file__).resolve()
PYTHON_BINDING_PATH = SDK_ROOT / "python" / "sporespore_locomotion.py"
DESIGN_PATH = TURNING_ROOT / "r23d4_terminal_stabilization.py"

CAMPAIGN_ID = "QSDK-R23D6-POLICY-COMPATIBLE-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
GATE_ID = "QSDK-R23D6"
ENGINE_ID = "mujoco"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r23d6_mujoco_worker_preflight_v1"
REPORT_SCHEMA = evaluator.REPORT_SCHEMA
FAILURE_SCHEMA = evaluator.FAILURE_SCHEMA
SCHEDULE_ID = "qsdk_r23d6_onset_600_turn_restore_settle_v1"
FREEZE_SCHEMA = "sporespore_qsdk_r23d6_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d6_attempt_v1"
TOLERANCE = 1.0e-12

FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D6_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D6_ATTEMPT"
AUTHORIZATION_TOKEN_ENV = "SPORESPORE_QSDK_R23D6_TOKEN"
STAGE_ID_ENV = "SPORESPORE_QSDK_R23D6_STAGE"
CELL_ID_ENV = "SPORESPORE_QSDK_R23D6_CELL"
ENGINE_ID_ENV = "SPORESPORE_QSDK_R23D6_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D6_ATTEMPT_ROOT"
PYTHON_ENV = "SPORESPORE_QSDK_R23D6_PYTHON"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D6_POWERSHELL"


class R23D6MujocoError(RuntimeError):
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
        raise R23D6MujocoError(f"{code}:{type(error).__name__}") from error
    if not isinstance(value, dict):
        raise R23D6MujocoError(code)
    return value


def _contract() -> dict[str, Any]:
    contract = design.load_contract()
    declaration = _read_json(
        PREREGISTRATION_PATH, "QSDK_R23D6_MJC_DECLARATION_UNREADABLE"
    )
    schedule = contract["command_and_terminal_schedule"]
    fixture = contract["fixture"]
    if (
        declaration.get("schema_version")
        != "sporespore_qsdk_r23d6_policy_compatible_restoration_preregistration_v1"
        or declaration.get("campaign_id") != CAMPAIGN_ID
        or declaration.get("gate_id") != GATE_ID
        or declaration.get("authorization", {}).get("physical_execution_authorized")
        is not False
        or _raw_sha256(PREREGISTRATION_PATH)
        != restoration.EXPECTED_DECLARATION_SHA256
        or
        fixture.get("morphology_id") != base.MORPHOLOGY_ID
        or fixture.get("selected_policy_id") != base.POLICY_ID
        or fixture.get("selected_policy_digest") != base.POLICY_DIGEST
        or fixture.get("campaign_seed") != base.CAMPAIGN_SEED
        or fixture.get("physics_hz") != base.PHYSICS_HZ
        or fixture.get("authored_sliding_friction") != base.bridge.AUTHORED_FRICTION
        or schedule.get("turning_controller_semantic_step_count")
        != design.CONTROLLER_STEPS
        or schedule.get("terminal_restoration_step_count")
        != design.RESTORATION_STEPS
        or schedule.get("passive_settle_step_count")
        != design.PASSIVE_SETTLE_STEPS
        or schedule.get("terminal_restoration_policy_id")
        != restoration.RESTORATION_POLICY_ID
        or base.HOST_PROFILE_ID != restoration.PROFILE_ID
        or restoration.MAXIMUM_ACQUISITION_STEPS
        != design.CONTACT_ACQUISITION_STEPS
        or restoration.REQUIRED_CONSECUTIVE_CONTACT_STEPS
        != design.CONTACT_HOLD_STEPS
        or contract.get("authorization", {}).get("physical_execution_authorized")
        is not False
    ):
        raise R23D6MujocoError("QSDK_R23D6_MJC_CONTRACT_IDENTITY_INVALID")
    return contract


def _cell(stage_id: str, arm_id: str) -> design.Cell:
    candidates = (
        design.stage_a_cells()
        if stage_id == "mujoco_terminal_restoration_screen"
        else design.stage_b_cells()
        if stage_id == "three_engine_confirmation"
        else []
    )
    matches = [
        cell
        for cell in candidates
        if cell.engine_id == ENGINE_ID and cell.arm_id == arm_id
    ]
    if len(matches) != 1:
        raise R23D6MujocoError(
            f"QSDK_R23D6_MJC_CELL_IDENTITY_INVALID:{stage_id}:{arm_id}"
        )
    return matches[0]


def _heading_schedule(
    cell: design.Cell,
    semantic_step: int,
    reference_heading_rad: float,
) -> dict[str, Any]:
    phase_id, controller_step, offset = design.phase_for_trace_step(
        cell, semantic_step
    )
    if controller_step != semantic_step:
        raise R23D6MujocoError("QSDK_R23D6_MJC_CONTROLLER_PHASE_INVALID")
    return {
        "phase_id": phase_id,
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
        "command_id": f"{SCHEDULE_ID}_{heading['phase_id']}",
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


def _trace_row(
    *,
    cell: design.Cell,
    trace_step: int,
    metrics: dict[str, Any],
    contacts: dict[str, bool],
    native_application_count: int,
) -> dict[str, Any]:
    phase_id, controller_step, heading_offset = design.phase_for_trace_step(
        cell, trace_step
    )
    passive = phase_id == "passive_zero_actuation_settle"
    terminal = phase_id.startswith("terminal_")
    return {
        "schema_version": design.TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": controller_step,
        "desired_heading_offset_rad": float(heading_offset),
        "measured_yaw_rad": float(metrics["yaw_rad"]),
        "torso_height_m": float(metrics["y"]),
        "torso_tilt_rad": float(metrics["tilt_rad"]),
        "torso_ground_contact": bool(metrics["ground_contact"]),
        "ordered_foot_contacts": {
            limb_id: bool(contacts[limb_id]) for limb_id in sorted(design.LIMB_IDS)
        },
        "actuator_command_count": 0 if passive else design.ACTUATOR_COUNT,
        "native_actuation_application_count": native_application_count,
        "zero_actuation": passive,
        "command_composition_mode": (
            "passive_zero_actuation_v1"
            if passive
            else design.RESTORATION_POLICY_ID
            if terminal
            else "balanced_wave_turning_v1"
        ),
        "restoration_receipt_present": terminal,
    }


def _source_bindings_exact(freeze: dict[str, Any]) -> bool:
    expected_paths = (
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d6_policy_compatible.py",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d2_heading_response.py",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d6_policy_compatible_restoration.py",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_pose_hold_restoration_mv6.py",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_walking_mv3.py",
        "sdk/python/sporespore_locomotion.py",
        "sdk/turning/r23d4_terminal_stabilization.py",
        "sdk/turning/r23d6_physical_evaluator.py",
        "sdk/turning/r23d6_policy_compatible_restoration_preregistration_v1.json",
        "sdk/turning/r23d6_implementation_contract_v1.json",
        "sdk/publish_qsdk_r23d6_trace.ps1",
    )
    try:
        declaration = json.loads(IMPLEMENTATION_PATH.read_text(encoding="utf-8"))
        declared = tuple(
            declaration["dependency_closure"][
                "required_dependency_paths_by_worker"
            ]["mujoco"]
        )
    except (OSError, UnicodeError, json.JSONDecodeError, KeyError, TypeError):
        return False
    if declared != expected_paths:
        return False
    required = {
        path: _raw_sha256(REPO_ROOT / path)
        for path in expected_paths
        if (REPO_ROOT / path).is_file()
    }
    if len(required) != len(expected_paths):
        return False
    bindings = freeze.get("source_bindings")
    if not isinstance(bindings, list):
        return False
    observed = {
        str(item.get("path")): str(item.get("raw_sha256"))
        for item in bindings
        if isinstance(item, dict)
    }
    return all(observed.get(path) == digest for path, digest in required.items())


def _physical_authorization(
    cell: design.Cell, source_commit: str
) -> dict[str, Any]:
    if CLOSURE_PATH.is_file():
        raise R23D6MujocoError("QSDK_R23D6_MJC_CLOSED")
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
        raise R23D6MujocoError("QSDK_R23D6_MJC_PHYSICAL_AUTHORIZATION_REQUIRED")
    freeze = _read_json(freeze_path, "QSDK_R23D6_MJC_FREEZE_UNREADABLE")
    attempt = _read_json(attempt_path, "QSDK_R23D6_MJC_ATTEMPT_UNREADABLE")
    production_root = (REPO_ROOT.parent / "SporeSpore_Evidence").resolve()
    try:
        attempt_root.resolve().relative_to(production_root)
    except ValueError as error:
        raise R23D6MujocoError("QSDK_R23D6_MJC_ATTEMPT_ROOT_NOT_DURABLE") from error
    stage_ids = (
        attempt.get("ordered_stage_a_cell_ids", [])
        if cell.stage_id == "mujoco_terminal_restoration_screen"
        else attempt.get("ordered_stage_b_cell_ids", [])
    )
    if (
        freeze.get("schema_version") != FREEZE_SCHEMA
        or freeze.get("campaign_id") != CAMPAIGN_ID
        or freeze.get("gate_id") != GATE_ID
        or freeze.get("status") != "frozen_supervisor_only_physical_authorized"
        or freeze.get("preregistration_raw_sha256") != _raw_sha256(PREREGISTRATION_PATH)
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
    ):
        raise R23D6MujocoError("QSDK_R23D6_MJC_PHYSICAL_AUTHORIZATION_INVALID")
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
) -> R23D6MujocoError:
    receipt = _failure_receipt(
        cell, source_commit, stage, code, attempts, builds, trace_artifact
    )
    return R23D6MujocoError(
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
        json.dump(rows, stream, allow_nan=False, separators=(",", ":"))
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
    marker = "QSDK_R23D6_TRACE_RETAINED "
    matches = [
        line[len(marker) :]
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise R23D6MujocoError(
            "QSDK_R23D6_MJC_TRACE_RETENTION_FAILED:"
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
        raise R23D6MujocoError(
            "QSDK_R23D6_MJC_TRACE_RETENTION_RECEIPT_INVALID",
            world_attempt_count=1,
            world_build_count=1,
        )
    return receipt


def run_preflight(stage_id: str, arm_id: str) -> dict[str, Any]:
    _contract()
    cell = _cell(stage_id, arm_id)
    inherited = base.run_preflight(arm_id)
    restoration_canary = restoration.run_zero_world_preflight()
    vector_canary = (
        restoration.mv6._production_kinematic_vector_representation_canary()
    )
    trace = design.validate_trace(cell, design.synthetic_trace(cell))
    if (
        inherited.get("world_build_count") != 0
        or inherited.get("physical_acceptance_authority") is not False
        or inherited.get("native_command_count") != 64
        or inherited.get("predicate_negative_control_count") != 35
        or restoration_canary.get("signed_arm_count") != 2
        or restoration_canary.get("world_build_count") != 0
        or restoration_canary.get("model_construction_count") != 0
        or restoration_canary.get("algebra", {}).get("canary_count") != 5
        or restoration_canary.get("algebra", {}).get("mutation_control_count")
        != 8
        or not all(
            restoration_canary.get("algebra", {})
            .get("mutation_controls_rejected", {})
            .values()
        )
        or vector_canary.get("ok") is not True
        or vector_canary.get("world_build_count") != 0
        or trace.get("ok") is not True
        or trace.get("row_count") != design.TOTAL_TRACE_STEPS
        or trace.get("phase_counts") != design.expected_phase_counts()
    ):
        raise R23D6MujocoError("QSDK_R23D6_MJC_PREFLIGHT_INVALID")
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "preregistration_raw_sha256": _raw_sha256(PREREGISTRATION_PATH),
        "inherited_r23d2_zero_world_boundary_sha256": _raw_sha256(
            Path(base.__file__).resolve()
        ),
        "policy_compatible_restoration_source_sha256": _raw_sha256(
            Path(restoration.__file__).resolve()
        ),
        "inherited_native_mapping_canary_count": inherited["canary_count"],
        "inherited_predicate_negative_control_count": inherited[
            "predicate_negative_control_count"
        ],
        "terminal_restoration_algebra_canary_count": restoration_canary["algebra"][
            "canary_count"
        ],
        "terminal_restoration_mutation_control_count": restoration_canary[
            "algebra"
        ]["mutation_control_count"],
        "production_shaped_signed_arm_count": restoration_canary[
            "signed_arm_count"
        ],
        "kinematic_vector_negative_control_count": vector_canary[
            "negative_control_count"
        ],
        "fixed_controller_horizon_step_count": design.CONTROLLER_STEPS,
        "fixed_terminal_restoration_step_count": design.RESTORATION_STEPS,
        "fixed_passive_settle_step_count": design.PASSIVE_SETTLE_STEPS,
        "fixed_total_trace_step_count": design.TOTAL_TRACE_STEPS,
        "trace_phase_counts": trace["phase_counts"],
        "fixed_horizon_configuration_proved_before_fixture_insertion": True,
        "trace_retained_before_terminal_entry_required": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,

        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _observe_step(
    robot: Any,
    counters: dict[str, int],
    maximum_tilt: float,
    minimum_height: float,
) -> tuple[dict[str, Any], dict[str, bool], float, float]:
    metrics = robot.torso_metrics()
    contacts = base._foot_contacts(robot)
    values = [
        float(metrics[key]) for key in ("x", "y", "z", "tilt_rad", "yaw_rad")
    ]
    counters["nonfinite_observation_count"] += int(
        not np.isfinite(values).all()
    )

    counters["torso_ground_contact_step_count"] += int(
        bool(metrics["ground_contact"])
    )
    return (
        metrics,
        contacts,
        max(maximum_tilt, float(metrics["tilt_rad"])),
        min(minimum_height, float(metrics["y"])),
    )


def run_physical(
    stage_id: str,
    arm_id: str,
    source_commit: str,
) -> dict[str, Any]:
    cell = _cell(stage_id, arm_id)
    if not _valid_lower_hex(source_commit, 40):
        raise _raise_failure(
            cell,
            source_commit,
            "before_world",
            "QSDK_R23D6_MJC_SOURCE_COMMIT_INVALID",
            0,
            0,
        )
    try:
        _contract()
        authorization = _physical_authorization(cell, source_commit)
        run_preflight(stage_id, arm_id)
        perturbation = base._initial_perturbation(base._contracts()[2])
        core = LocomotionCore()
        compiled, profile = base._compile_boundary(core)
    except R23D6MujocoError as error:
        raise _raise_failure(
            cell, source_commit, "before_world", error.code, 0, 0
        ) from error
    except Exception as error:
        raise _raise_failure(
            cell,
            source_commit,
            "before_world",
            f"QSDK_R23D6_MJC_PREFLIGHT_ERROR:{type(error).__name__}:{error}",
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
            f"QSDK_R23D6_MJC_WORLD_CONSTRUCTION_ERROR:{type(error).__name__}:{error}",
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
            "active_safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "validated_portable_command_count": 0,
            "native_actuation_application_count": 0,
            "passive_native_actuation_application_count": 0,
            "portable_impulse_violation_count": 0,
            "torso_ground_contact_step_count": 0,
            "restoration_receipt_count": 0,
            "terminal_receipt_validation_failure_count": 0,
            "captured_pose_memory_transition_count": 0,
            "captured_pose_memory_transition_failure_count": 0,
            "heading_correction_receipt_count": 0,
        }
        maximum_tilt = -math.inf
        minimum_height = math.inf
        maximum_requested = 0.0
        maximum_held = 0.0
        maximum_restoration_joint_speed = 0.0
        turn_start_yaw: float | None = None
        turn_end_yaw: float | None = None
        rows: list[dict[str, Any]] = []

        for semantic_step in range(design.CONTROLLER_STEPS):
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
            if semantic_step == design.TURN_START_STEP:
                turn_start_yaw = float(robot.torso_metrics()["yaw_rad"])
            command = _motion_command(semantic_step, phase_mode, heading)
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
            counters["active_safe_no_actuation_count"] += int(
                actuation["safe_no_actuation"]
            )
            ordered_ids = list(compiled["morphology"]["ordered_actuator_ids"])
            if (
                receipt.get("semantic_step") != semantic_step
                or receipt.get("command_id") != command["command_id"]
                or receipt.get("policy_id") != base.POLICY_ID
                or [item["actuator_id"] for item in actuation["ordered_commands"]]
                != ordered_ids
                or len(actuation["ordered_commands"]) != design.ACTUATOR_COUNT
            ):
                raise R23D6MujocoError("QSDK_R23D6_MJC_CONTROLLER_OUTPUT_INVALID")
            expected = base._independent_oracle(state, command, profile)
            oracle_failures = base._predicate_failures(expected, receipt)
            if oracle_failures:
                raise R23D6MujocoError(
                    "QSDK_R23D6_MJC_CONTROLLER_RECEIPT_INVALID:"
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
                    "host_profile": base.bridge._mujoco_host_profile(
                        base.HOST_PROFILE_ID
                    ),
                }
            )
            if (
                mapping.get("host_profile_id") != base.HOST_PROFILE_ID
                or mapping.get("engine_id") != ENGINE_ID
                or len(mapping.get("ordered_commands", [])) != design.ACTUATOR_COUNT
                or mapping.get("independent_native_position_feedback_applied")
                is not False
                or mapping.get("native_position_stiffness") != 0.0
            ):
                raise R23D6MujocoError("QSDK_R23D6_MJC_NATIVE_MAPPING_INVALID")
            maximum_requested = max(
                maximum_requested, abs(float(receipt["requested_steering_fraction"]))
            )

            maximum_held = max(
                maximum_held, abs(float(receipt["held_steering_fraction"]))
            )
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
                application_count != design.ACTUATOR_COUNT
            )
            memory = output["next_memory"]
            robot.prepare()
            metrics, contacts, maximum_tilt, minimum_height = _observe_step(
                robot, counters, maximum_tilt, minimum_height
            )
            if semantic_step + 1 == design.TURN_START_STEP + design.TURN_DURATION_STEPS:
                turn_end_yaw = float(metrics["yaw_rad"])
            if semantic_step >= base.CONTACT_GATED_START_STEP:
                for limb, present in contacts.items():
                    if not previous_contacts[limb] and present:
                        contact_cycles[limb] += 1
                    previous_contacts[limb] = present
            rows.append(
                _trace_row(
                    cell=cell,
                    trace_step=semantic_step,
                    metrics=metrics,
                    contacts=contacts,
                    native_application_count=application_count,
                )
            )

        restoration_memory = restoration.TerminalRestorationMemory()
        independent_pose_memory: dict[str, float] = {}
        first_all_four_contact_step: int | None = None
        consecutive_hold = 0
        maximum_consecutive_hold = 0
        for restoration_step in range(design.RESTORATION_STEPS):
            trace_step = design.CONTROLLER_STEPS + restoration_step
            state = base._state_frame(
                robot, trace_step, task_origin, reference_heading_rad
            )
            heading = {
                "phase_id": design.phase_for_trace_step(cell, trace_step)[0],
                "heading_offset_rad": 0.0,
                "desired_heading_rad": reference_heading_rad,

            }
            command = _motion_command(trace_step, "contact_gated", heading)
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
            counters["active_safe_no_actuation_count"] += int(
                actuation["safe_no_actuation"]
            )
            maximum_requested = max(
                maximum_requested, abs(float(receipt["requested_steering_fraction"]))
            )
            maximum_held = max(
                maximum_held, abs(float(receipt["held_steering_fraction"]))
            )
            counters["validated_portable_command_count"] += len(
                actuation["ordered_commands"]
            )
            pre = mv3._snapshot(robot)
            stability_state = robot.stability_state(trace_step)
            kinematics = robot.endpoint_kinematics(stability_state)
            composed = restoration.terminal_restoration_composition(
                robot,
                actuation,
                profile,
                state,
                dict(pre["ordered_declared_contacts"]),
                kinematics,
                restoration_memory,
            )
            terminal_receipt = composed["terminal_receipt"]
            receipt_failures = restoration.terminal_receipt_failures(
                terminal_receipt,
                composed["canonical_actuation"],
                composed["host_mapping"],
            )
            pose_failures = restoration._terminal_pose_memory_transition_failures(
                terminal_receipt, independent_pose_memory
            )
            counters["restoration_receipt_count"] += 1
            counters["heading_correction_receipt_count"] += int(
                not receipt_failures
            )
            counters["terminal_receipt_validation_failure_count"] += len(
                receipt_failures
            )
            counters["captured_pose_memory_transition_failure_count"] += len(
                pose_failures
            )
            for limb in terminal_receipt["ordered_limb_solutions"]:
                for solution in limb["ordered_actuator_solutions"]:
                    counters["captured_pose_memory_transition_count"] += int(
                        solution["pose_capture_activated"] is True
                    )
                    maximum_restoration_joint_speed = max(
                        maximum_restoration_joint_speed,
                        abs(float(solution["desired_joint_velocity_rad_s"])),
                    )
            if receipt_failures or pose_failures:
                raise R23D6MujocoError(
                    "QSDK_R23D6_MJC_RESTORATION_RECEIPT_INVALID:"
                    + ",".join((receipt_failures + pose_failures)[:8])
                )
            application = robot.apply_host_mapping(composed["host_mapping"])
            application_count = len(application["targets"])
            counters["native_actuation_application_count"] += application_count
            counters["portable_impulse_violation_count"] += int(
                application["portable_impulse_violation_count"]
            )
            counters["actuator_application_mismatch_count"] += int(
                application_count != design.ACTUATOR_COUNT
            )
            memory = output["next_memory"]
            robot.prepare()
            metrics, contacts, maximum_tilt, minimum_height = _observe_step(
                robot, counters, maximum_tilt, minimum_height
            )
            all_four = all(contacts.values())
            if all_four and first_all_four_contact_step is None:
                first_all_four_contact_step = restoration_step
            if restoration_step >= design.CONTACT_ACQUISITION_STEPS:
                consecutive_hold = consecutive_hold + 1 if all_four else 0
                maximum_consecutive_hold = max(
                    maximum_consecutive_hold, consecutive_hold
                )
            rows.append(
                _trace_row(
                    cell=cell,
                    trace_step=trace_step,
                    metrics=metrics,
                    contacts=contacts,
                    native_application_count=application_count,
                )
            )

        for passive_step in range(design.PASSIVE_SETTLE_STEPS):
            base._zero_prepared_outer_step(robot)
            robot.prepare()
            metrics, contacts, maximum_tilt, minimum_height = _observe_step(
                robot, counters, maximum_tilt, minimum_height
            )
            rows.append(
                _trace_row(
                    cell=cell,
                    trace_step=design.ACTIVE_STEPS + passive_step,
                    metrics=metrics,
                    contacts=contacts,
                    native_application_count=0,
                )
            )

        final = robot.torso_metrics()
        final_delta = (
            np.asarray([final["x"], final["y"], final["z"]], dtype=np.float64)
            - task_origin
        )
        task_forward = np.asarray(
            [math.cos(reference_heading_rad), 0.0, math.sin(reference_heading_rad)],
            dtype=np.float64,

        )
        if turn_start_yaw is None or turn_end_yaw is None:
            raise R23D6MujocoError("QSDK_R23D6_MJC_TURN_WINDOW_INCOMPLETE")
        measurements = {
            "final_forward_displacement_m": float(final_delta @ task_forward),
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
            "active_safe_no_actuation_count": counters[
                "active_safe_no_actuation_count"
            ],
            "nonfinite_observation_count": counters["nonfinite_observation_count"],
            "actuator_application_mismatch_count": counters[
                "actuator_application_mismatch_count"
            ],
            "controller_semantic_step_count": design.CONTROLLER_STEPS,
            "terminal_restoration_step_count": design.RESTORATION_STEPS,
            "passive_settle_step_count": design.PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": counters[
                "validated_portable_command_count"
            ],
            "native_actuation_application_count": counters[
                "native_actuation_application_count"
            ],
            "passive_native_actuation_application_count": counters[
                "passive_native_actuation_application_count"
            ],
            "restoration_receipt_count": counters["restoration_receipt_count"],
            "terminal_receipt_validation_failure_count": counters[
                "terminal_receipt_validation_failure_count"
            ],
            "first_all_four_contact_restoration_step": (
                first_all_four_contact_step
                if first_all_four_contact_step is not None
                else design.CONTACT_ACQUISITION_STEPS
            ),
            "consecutive_all_four_contact_hold_step_count": maximum_consecutive_hold,
            "captured_pose_memory_transition_count": counters[
                "captured_pose_memory_transition_count"
            ],
            "captured_pose_memory_transition_failure_count": counters[
                "captured_pose_memory_transition_failure_count"
            ],
            "maximum_absolute_restoration_joint_velocity_rad_s": (
                maximum_restoration_joint_speed
            ),
            "heading_correction_receipt_count": counters[
                "heading_correction_receipt_count"
            ],
            "passive_settle_trace_row_count": design.PASSIVE_SETTLE_STEPS,
        }
        trace = _retain_trace(cell, rows, authorization["attempt_root"])
        report = {
            "schema_version": REPORT_SCHEMA,
            "campaign_id": CAMPAIGN_ID,
            "gate_id": GATE_ID,
            "stage_id": cell.stage_id,
            "cell_id": cell.cell_id,
            "engine_id": ENGINE_ID,
            "arm_id": cell.arm_id,
            "turn_heading_offset_rad": cell.turn_heading_offset_rad,
            "source_commit": source_commit,
            "trace_artifact": trace["trace_artifact"],
            "trace_summary": trace["trace_summary"],
            "execution": {
                "integrity_passed": True,
                "worker_failure_code": "",
                "controller_semantic_step_count": design.CONTROLLER_STEPS,
                "terminal_restoration_step_count": design.RESTORATION_STEPS,
                "passive_settle_step_count": design.PASSIVE_SETTLE_STEPS,
                "validated_portable_command_count": counters[
                    "validated_portable_command_count"
                ],
                "native_actuation_application_count": counters[
                    "native_actuation_application_count"
                ],
                "passive_native_actuation_application_count": counters[
                    "passive_native_actuation_application_count"
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
        json.dumps(report, allow_nan=False)
        return report
    except R23D6MujocoError as error:
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
            f"QSDK_R23D6_MJC_PHYSICAL_WORKER_ERROR:{type(error).__name__}:{error}",
            1,
            1,
        ) from error



def _arguments(arguments: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("preflight", "physical"))
    parser.add_argument("--stage-id", required=True)
    parser.add_argument("--arm-id", required=True)
    parser.add_argument("--source-commit", default="")
    return parser.parse_args(arguments)


def main(arguments: Iterable[str] | None = None) -> int:
    args = _arguments(arguments)
    try:
        if args.command == "preflight":
            receipt = run_preflight(args.stage_id, args.arm_id)
            print(
                "QSDK_R23D6_MUJOCO_PREFLIGHT "
                + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
            )
            return 0
        report = run_physical(args.stage_id, args.arm_id, args.source_commit)
        print(
            "QSDK_R23D6_TERMINAL "
            + json.dumps(report, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 0
    except R23D6MujocoError as error:
        if error.terminal_receipt is not None:
            print(
                "QSDK_R23D6_TERMINAL "
                + json.dumps(
                    error.terminal_receipt,
                    allow_nan=False,
                    separators=(",", ":"),
                    sort_keys=True,
                )
            )
        print(f"QSDK_R23D6_MUJOCO_FAILURE {error.code}", file=sys.stderr)
        return 1
    except Exception as error:
        print(
            f"QSDK_R23D6_MUJOCO_FAILURE {type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
