"""Dormant classic-MuJoCo physical worker for prospective QSDK-R23D10.

The module owns the real MuJoCo loop but cannot construct a model until the
single aggregate supervisor supplies a source-exact freeze and one-shot
attempt authorization. Complete traces are validated and content-addressed
before a terminal report can be returned.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
import os
import re
import sys
from pathlib import Path
from typing import Any

import numpy as np

from sporespore_locomotion import LocomotionCore

from . import qsdk_r23d8_neutral_stance as inherited
from . import qsdk_r23d10_quiescent_taper as native


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

import r23d10_physical_evaluator as evaluator  # noqa: E402
import r23d10_physical_trace as design  # noqa: E402
import r23d10_quiescent_taper as terminal  # noqa: E402


PREREGISTRATION_PATH = TURNING_ROOT / "r23d10_quiescent_taper_preregistration_v1.json"
IMPLEMENTATION_PATH = TURNING_ROOT / "r23d10_physical_implementation_contract_v1.json"
CLOSURE_PATH = TURNING_ROOT / "r23d10_physical_closure_v1.json"
CAMPAIGN_ID = design.CAMPAIGN_ID
GATE_ID = design.GATE_ID
ENGINE_ID = "mujoco"
SCHEDULE_ID = "qsdk_r23d10_support_pose_confirmed_quiescent_taper_v1"
FREEZE_SCHEMA = "sporespore_qsdk_r23d10_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d10_attempt_v1"
FAILURE_SCHEMA = evaluator.FAILURE_SCHEMA
REPORT_SCHEMA = evaluator.REPORT_SCHEMA

FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D10_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D10_ATTEMPT"
AUTHORIZATION_TOKEN_ENV = "SPORESPORE_QSDK_R23D10_TOKEN"
STAGE_ID_ENV = "SPORESPORE_QSDK_R23D10_STAGE"
CELL_ID_ENV = "SPORESPORE_QSDK_R23D10_CELL"
ENGINE_ID_ENV = "SPORESPORE_QSDK_R23D10_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D10_ATTEMPT_ROOT"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D10_POWERSHELL"


class R23D10MujocoPhysicalError(RuntimeError):
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
        raise R23D10MujocoPhysicalError(
            f"{code}:{type(error).__name__}"
        ) from error
    if not isinstance(value, dict):
        raise R23D10MujocoPhysicalError(code)
    return value


def _cell(stage_id: str, arm_id: str) -> design.Cell:
    matches = [
        cell
        for cell in design.all_cells()
        if cell.stage_id == stage_id
        and cell.engine_id == ENGINE_ID
        and cell.arm_id == arm_id
    ]
    if len(matches) != 1:
        raise R23D10MujocoPhysicalError(
            f"QSDK_R23D10_MJC_CELL_IDENTITY_INVALID:{stage_id}:{arm_id}"
        )
    return matches[0]


def _contract() -> dict[str, Any]:
    declaration = _read_json(
        PREREGISTRATION_PATH, "QSDK_R23D10_MJC_DECLARATION_UNREADABLE"
    )
    policy = declaration.get("terminal_policy_contract", {})
    canaries, mutations = native.run_zero_world_preflight()
    if (
        declaration.get("schema_version")
        != "sporespore_qsdk_r23d10_quiescent_taper_preregistration_v1"
        or declaration.get("campaign_id") != CAMPAIGN_ID
        or declaration.get("gate_id") != GATE_ID
        or declaration.get("stage_zero_authority", {}).get(
            "physical_execution_authorized"
        )
        is not False
        or policy.get("initial_mode") != terminal.ACTIVE_MODE
        or policy.get("quiescent_mode") != terminal.TAPER_MODE
        or policy.get("passive_mode") != terminal.PASSIVE_MODE
        or policy.get("terminal_step_count") != terminal.TERMINAL_STEPS
        or policy.get("maximum_active_step_count") != terminal.MAXIMUM_ACTIVE_STEPS
        or policy.get("minimum_quiescent_taper_step_count")
        != terminal.MINIMUM_TAPER_STEPS
        or policy.get("minimum_passive_step_count") != terminal.MINIMUM_PASSIVE_STEPS
        or policy.get("ordered_actuator_count") != terminal.ACTUATOR_COUNT
        or policy.get("base_velocity_limit_rad_s") != design.BASE_VELOCITY_LIMIT_RAD_S
        or policy.get("coarse_pose_predicate")
        != "all_four_contacts and torso_tilt_rad <= 0.035 and maximum_absolute_joint_position_error_rad <= 0.32"
        or policy.get("tight_pose_predicate")
        != "all_four_contacts and torso_tilt_rad <= 0.01 and maximum_absolute_joint_position_error_rad <= 0.2"
        or policy.get(
            "taper_scale_is_applied_to_canonical_velocity_limit_before_host_mapping"
        )
        is not True
        or policy.get("taper_resets_to_acquisition_on_coarse_pose_failure")
        is not True
        or policy.get("transition_is_applied_to_next_step") is not True
        or policy.get("mode_reactivation_after_passive_handoff_permitted")
        is not False
        or policy.get("all_900_terminal_steps_execute") is not True
        or canaries != 5
        or mutations != 16
    ):
        raise R23D10MujocoPhysicalError("QSDK_R23D10_MJC_CONTRACT_IDENTITY_INVALID")
    return declaration


def _source_bindings_exact(freeze: dict[str, Any]) -> bool:
    try:
        implementation = json.loads(IMPLEMENTATION_PATH.read_text(encoding="utf-8"))
        declared = implementation["dependency_closure"][
            "required_dependency_paths_by_worker"
        ][ENGINE_ID]
    except (OSError, UnicodeError, json.JSONDecodeError, KeyError, TypeError):
        return False
    if (
        not isinstance(declared, list)
        or not declared
        or any(not isinstance(path, str) or not path for path in declared)
        or len(set(declared)) != len(declared)
    ):
        return False
    required: dict[str, str] = {}
    for relative in declared:
        path = REPO_ROOT / relative
        if not path.is_file():
            return False
        required[relative] = _raw_sha256(path)
    bindings = freeze.get("source_bindings")
    if not isinstance(bindings, list):
        return False
    observed: dict[str, str] = {}
    for item in bindings:
        if not isinstance(item, dict):
            return False
        relative = item.get("path")
        digest = item.get("raw_sha256")
        if (
            not isinstance(relative, str)
            or not isinstance(digest, str)
            or re.fullmatch(r"sha256:[0-9a-f]{64}", digest) is None
            or relative in observed
        ):
            return False
        observed[relative] = digest
    return all(observed.get(path) == digest for path, digest in required.items())


def physical_authorization(
    cell: design.Cell, source_commit: str
) -> dict[str, Any]:
    """Exercise the exact production authorization path without a world."""

    if CLOSURE_PATH.is_file():
        raise R23D10MujocoPhysicalError("QSDK_R23D10_MJC_CLOSED")
    freeze_path = Path(os.environ.get(FREEZE_PATH_ENV, ""))
    attempt_path = Path(os.environ.get(ATTEMPT_PATH_ENV, ""))
    attempt_root = Path(os.environ.get(ATTEMPT_ROOT_ENV, ""))
    token = os.environ.get(AUTHORIZATION_TOKEN_ENV, "")
    if (
        not IMPLEMENTATION_PATH.is_file()
        or not freeze_path.is_file()
        or not attempt_path.is_file()
        or not attempt_root.is_dir()
        or not _valid_lower_hex(token, 32)
    ):
        raise R23D10MujocoPhysicalError(
            "QSDK_R23D10_MJC_PHYSICAL_AUTHORIZATION_REQUIRED"
        )
    freeze = _read_json(freeze_path, "QSDK_R23D10_MJC_FREEZE_UNREADABLE")
    attempt = _read_json(attempt_path, "QSDK_R23D10_MJC_ATTEMPT_UNREADABLE")
    production_root = (REPO_ROOT.parent / "SporeSpore_Evidence").resolve()
    try:
        attempt_root.resolve().relative_to(production_root)
    except ValueError as error:
        raise R23D10MujocoPhysicalError(
            "QSDK_R23D10_MJC_ATTEMPT_ROOT_NOT_DURABLE"
        ) from error
    stage_ids = (
        attempt.get("ordered_stage_a_cell_ids", [])
        if cell.stage_id == "mujoco_quiescent_taper_screen"
        else attempt.get("ordered_stage_b_cell_ids", [])
    )
    if (
        freeze.get("schema_version") != FREEZE_SCHEMA
        or freeze.get("campaign_id") != CAMPAIGN_ID
        or freeze.get("gate_id") != GATE_ID
        or freeze.get("status") != "frozen_supervisor_only_physical_authorized"
        or freeze.get("preregistration_raw_sha256") != _raw_sha256(PREREGISTRATION_PATH)
        or freeze.get("implementation_contract_raw_sha256")
        != _raw_sha256(IMPLEMENTATION_PATH)
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
        raise R23D10MujocoPhysicalError(
            "QSDK_R23D10_MJC_PHYSICAL_AUTHORIZATION_INVALID"
        )
    return {"freeze": freeze, "attempt": attempt, "attempt_root": attempt_root}


def authorization_preflight(
    stage_id: str, arm_id: str, source_commit: str
) -> dict[str, Any]:
    cell = _cell(stage_id, arm_id)
    if not _valid_lower_hex(source_commit, 40):
        raise R23D10MujocoPhysicalError("QSDK_R23D10_MJC_SOURCE_COMMIT_INVALID")
    physical_authorization(cell, source_commit)
    return {
        "schema_version": "sporespore_qsdk_r23d10_mujoco_production_authorization_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": ENGINE_ID,
        "arm_id": cell.arm_id,
        "actual_production_authorization_function": "physical_authorization",
        "authorization_passed": True,
        "returned_before_model": True,
        "physics_adapter_start_count": 0,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _failure_receipt(
    cell: design.Cell,
    source_commit: str,
    stage: str,
    code: str,
    attempts: int,
    builds: int,
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
        "failure_stage": stage,
        "failure_code": code,
        "world_attempt_count": attempts,
        "world_build_count": builds,
        "trace_artifact": trace_artifact,
        "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
    }


def _failure(
    cell: design.Cell,
    source_commit: str,
    stage: str,
    code: str,
    attempts: int,
    builds: int,
    trace_artifact: dict[str, Any] | None = None,
) -> R23D10MujocoPhysicalError:
    return R23D10MujocoPhysicalError(
        code,
        world_attempt_count=attempts,
        world_build_count=builds,
        terminal_receipt=_failure_receipt(
            cell, source_commit, stage, code, attempts, builds, trace_artifact
        ),
    )


def _heading(
    cell: design.Cell, semantic_step: int, reference_heading_rad: float
) -> dict[str, Any]:
    phase_id, offset = design.controller_phase_for_step(cell, semantic_step)
    return {
        "phase_id": phase_id,
        "heading_offset_rad": offset,
        "desired_heading_rad": inherited.base._wrap_angle(
            reference_heading_rad + offset
        ),
    }


def _command(
    semantic_step: int, progression: str, heading: dict[str, Any]
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
        "phase_progression_mode": progression,
        "valid_from_step": semantic_step,
        "valid_through_step": semantic_step,
        "authority": "test_fixture",
    }


def _observation(
    robot: Any,
    counters: dict[str, int],
    maximum_tilt: float,
    minimum_height: float,
) -> tuple[dict[str, Any], dict[str, bool], float, float]:
    metrics = robot.torso_metrics()
    contacts = inherited.base._foot_contacts(robot)
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


def _scaled_terminal_mapping(
    robot: Any,
    base_actuation: dict[str, Any],
    composed: dict[str, Any],
    numerator: int,
    denominator: int,
) -> tuple[dict[str, Any], dict[str, Any], float]:
    """Apply the frozen taper to canonical velocity before host mapping."""

    if denominator != terminal.SCALE_DENOMINATOR or not 0 < numerator <= denominator:
        raise R23D10MujocoPhysicalError("QSDK_R23D10_MJC_TAPER_SCALE_INVALID")
    scale = float(numerator) / float(denominator)
    solutions = composed["terminal_receipt"]["ordered_actuator_solutions"]
    desired_by_actuator = {
        str(solution["actuator_id"]): float(solution["bounded_velocity_rad_s"])
        * scale
        for solution in solutions
    }
    residuals = [
        {
            "schema_version": "sporespore_canonical_velocity_residual_v1",
            "actuator_id": command["actuator_id"],
            "canonical_velocity_delta_rad_s": desired_by_actuator[
                command["actuator_id"]
            ]
            - (-float(command["target_velocity_rad_s"])),
            "command_not_measurement": True,
            "physical_acceptance_authority": False,
        }
        for command in base_actuation["ordered_commands"]
    ]
    canonical = robot.core.canonical_velocity_compose_v1(
        {
            "schema_version": "sporespore_canonical_velocity_compose_request_v1",
            "descriptor": robot.descriptor,
            "source_actuation": base_actuation,
            "ordered_stability_residuals": residuals,
        }
    )
    host = robot.core.canonical_velocity_host_map_v1(
        {
            "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
            "descriptor": robot.descriptor,
            "canonical_actuation": canonical,
            "host_profile": inherited.base.bridge._mujoco_host_profile(
                inherited.base.HOST_PROFILE_ID
            ),
        }
    )
    expected_ids = list(robot.morphology["ordered_actuator_ids"])
    canonical_commands = canonical.get("ordered_commands", [])
    host_commands = host.get("ordered_commands", [])
    if (
        [item.get("actuator_id") for item in canonical_commands] != expected_ids
        or [item.get("actuator_id") for item in host_commands] != expected_ids
    ):
        raise R23D10MujocoPhysicalError("QSDK_R23D10_MJC_TAPER_MAPPING_ORDER")
    for canonical_command, host_command in zip(
        canonical_commands, host_commands, strict=True
    ):
        actuator_id = str(canonical_command["actuator_id"])
        desired = desired_by_actuator[actuator_id]
        if (
            not math.isclose(
                float(canonical_command["combined_canonical_target_velocity_rad_s"]),
                desired,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
            or not math.isclose(
                float(host_command["host_target_velocity_rad_s"]),
                desired,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
            or host_command.get("native_target_position_rad") is not None
        ):
            raise R23D10MujocoPhysicalError(
                "QSDK_R23D10_MJC_TAPER_MAPPING_VALUE:" + actuator_id
            )
    maximum_speed = max(abs(value) for value in desired_by_actuator.values())
    return canonical, host, maximum_speed


def _controller_row(
    cell: design.Cell,
    trace_step: int,
    metrics: dict[str, Any],
    contacts: dict[str, bool],
    applications: int,
) -> dict[str, Any]:
    phase_id, offset = design.controller_phase_for_step(cell, trace_step)
    return {
        "schema_version": design.TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": trace_step,
        "desired_heading_offset_rad": float(offset),
        "measured_yaw_rad": float(metrics["yaw_rad"]),
        "torso_height_m": float(metrics["y"]),
        "torso_tilt_rad": float(metrics["tilt_rad"]),
        "torso_ground_contact": bool(metrics["ground_contact"]),
        "ordered_foot_contacts": {
            limb: bool(contacts[limb]) for limb in design.LIMB_IDS
        },
        "actuator_command_count": design.ACTUATOR_COUNT,
        "native_actuation_application_count": applications,
        "zero_actuation": False,
        "command_composition_mode": "balanced_wave_turning_v1",
        "taper_receipt_present": False,
        "pre_step_taper_count": None,
        "post_step_taper_count": None,
        "coarse_pose_satisfied": None,
        "tight_pose_satisfied": None,
        "velocity_scale_numerator": None,
        "velocity_scale_denominator": None,
        "transition_after_step": False,
        "taper_reset_after_step": False,
        "next_terminal_mode": None,
        "handoff_reason": None,
        "maximum_absolute_joint_position_error_rad": None,
        "maximum_absolute_commanded_joint_velocity_rad_s": None,
    }


def _terminal_row(
    cell: design.Cell,
    trace_step: int,
    observation: terminal.Observation,
    receipt: dict[str, Any],
    metrics: dict[str, Any],
    contacts: dict[str, bool],
    maximum_speed: float | None,
) -> dict[str, Any]:
    mode = str(receipt["mode"])
    active = mode != terminal.PASSIVE_MODE
    if mode == terminal.ACTIVE_MODE:
        phase_id = "terminal_neutral_acquisition"
        composition_mode = "neutral_stance_full_authority_v1"
    elif mode == terminal.TAPER_MODE:
        phase_id = "terminal_quiescent_taper"
        composition_mode = "neutral_stance_quiescent_taper_v1"
    elif mode == terminal.PASSIVE_MODE:
        phase_id = "terminal_irreversible_zero_actuation"
        composition_mode = "passive_zero_actuation_v1"
    else:
        raise R23D10MujocoPhysicalError("QSDK_R23D10_MJC_TERMINAL_MODE_INVALID")
    return {
        "schema_version": design.TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": None,
        "desired_heading_offset_rad": 0.0,
        "measured_yaw_rad": float(metrics["yaw_rad"]),
        "torso_height_m": float(metrics["y"]),
        "torso_tilt_rad": float(metrics["tilt_rad"]),
        "torso_ground_contact": bool(metrics["ground_contact"]),
        "ordered_foot_contacts": {
            limb: bool(contacts[limb]) for limb in design.LIMB_IDS
        },
        "actuator_command_count": design.ACTUATOR_COUNT if active else 0,
        "native_actuation_application_count": receipt["native_application_count"],
        "zero_actuation": not active,
        "command_composition_mode": composition_mode,
        "taper_receipt_present": True,
        "pre_step_taper_count": receipt["pre_step_taper_count"],
        "post_step_taper_count": receipt["post_step_taper_count"],
        "coarse_pose_satisfied": receipt["coarse_pose_satisfied"],
        "tight_pose_satisfied": receipt["tight_pose_satisfied"],
        "velocity_scale_numerator": receipt["velocity_scale_numerator"],
        "velocity_scale_denominator": receipt["velocity_scale_denominator"],
        "transition_after_step": receipt["transition_after_step"],
        "taper_reset_after_step": receipt["taper_reset_after_step"],
        "next_terminal_mode": receipt["next_mode"],
        "handoff_reason": receipt["handoff_reason"],
        "maximum_absolute_joint_position_error_rad": (
            observation.maximum_absolute_joint_position_error_rad
        ),
        "maximum_absolute_commanded_joint_velocity_rad_s": maximum_speed,
    }


def _retain_trace(
    cell: design.Cell,
    rows: list[dict[str, Any]],
    attempt_root: Path,
) -> dict[str, Any]:
    pending = attempt_root / "pending-traces"
    pending.mkdir(parents=True, exist_ok=True)
    rows_path = pending / f"{cell.stage_id}__{cell.cell_id}.rows.json"
    with rows_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(rows, stream, allow_nan=False, separators=(",", ":"))
        stream.write("\n")
    receipt = evaluator.retain_trace(
        stage_id=cell.stage_id,
        cell_id=cell.cell_id,
        rows_json_path=rows_path,
        repo_root=REPO_ROOT,
        attempt_root=attempt_root,
        powershell=os.environ.get(POWERSHELL_ENV, "pwsh"),
        test_only=False,
        evidence_root_override=None,
    )
    if (
        receipt.get("schema_version") != evaluator.TRACE_RETENTION_SCHEMA
        or receipt.get("stage_id") != cell.stage_id
        or receipt.get("cell_id") != cell.cell_id
        or receipt.get("retained_before_terminal_entry") is not True
    ):
        raise R23D10MujocoPhysicalError(
            "QSDK_R23D10_MJC_TRACE_RETENTION_RECEIPT_INVALID",
            world_attempt_count=1,
            world_build_count=1,
        )
    return receipt


def run_physical(
    stage_id: str, arm_id: str, source_commit: str
) -> dict[str, Any]:
    cell = _cell(stage_id, arm_id)
    if not _valid_lower_hex(source_commit, 40):
        raise _failure(
            cell,
            source_commit,
            "before_world",
            "QSDK_R23D10_MJC_SOURCE_COMMIT_INVALID",
            0,
            0,
        )
    try:
        _contract()
        authorization = physical_authorization(cell, source_commit)
        perturbation = inherited.base._initial_perturbation(
            inherited.base._contracts()[2]
        )
        core = LocomotionCore()
        compiled, profile = inherited.base._compile_boundary(core)
    except R23D10MujocoPhysicalError as error:
        raise _failure(cell, source_commit, "before_world", error.code, 0, 0) from error
    except Exception as error:
        raise _failure(
            cell,
            source_commit,
            "before_world",
            f"QSDK_R23D10_MJC_PREFLIGHT_ERROR:{type(error).__name__}:{error}",
            0,
            0,
        ) from error

    try:
        robot = inherited.base.bridge.MujocoBw19vRobot(
            core, inherited.base.HOST_PROFILE_ID
        )
    except Exception as error:
        raise _failure(
            cell,
            source_commit,
            "world_construction_failed",
            f"QSDK_R23D10_MJC_WORLD_CONSTRUCTION_ERROR:{type(error).__name__}:{error}",
            1,
            0,
        ) from error

    try:
        inherited.base._apply_initial_perturbation(robot, perturbation)
        for _ in range(inherited.base.SETTLE_STEPS):
            robot.prepare()
            inherited.base._zero_prepared_outer_step(robot)
        robot.prepare()
        initial = robot.torso_metrics()
        task_origin = np.asarray(
            [initial["x"], initial["y"], initial["z"]], dtype=np.float64
        )
        reference_heading_rad = float(initial["yaw_rad"])
        memory = core.balanced_wave_initial_memory()
        previous_contacts = inherited.base._foot_contacts(robot)
        contact_cycles = {limb: 0 for limb in design.LIMB_IDS}
        counters = {
            "controller_error_count": 0,
            "active_safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "validated_portable_command_count": 0,
            "native_actuation_application_count": 0,
            "portable_impulse_violation_count": 0,
            "torso_ground_contact_step_count": 0,
            "terminal_receipt_validation_failure_count": 0,
        }
        maximum_tilt = -math.inf
        minimum_height = math.inf
        maximum_requested = 0.0
        maximum_held = 0.0
        maximum_terminal_speed = 0.0
        turn_start_yaw: float | None = None
        turn_end_yaw: float | None = None
        rows: list[dict[str, Any]] = []

        for semantic_step in range(design.CONTROLLER_STEPS):
            if semantic_step == inherited.base.PHASE_OFFSET_ACTIVATION_STEP:
                inherited.base._phase_offset(
                    memory, int(perturbation["gait_phase_offset_ticks"])
                )
            if semantic_step == inherited.base.CONTACT_GATED_START_STEP:
                for limb in memory["ordered_limb_memory"]:
                    limb["evidence_gait_step_limit"] = int(limb["gait_step"]) + 1441
            progression = (
                "clocked"
                if semantic_step < inherited.base.CONTACT_GATED_START_STEP
                else "contact_gated"
            )
            state = inherited.base._state_frame(
                robot, semantic_step, task_origin, reference_heading_rad
            )
            heading = _heading(cell, semantic_step, reference_heading_rad)
            if semantic_step == design.TURN_START_STEP:
                turn_start_yaw = float(robot.torso_metrics()["yaw_rad"])
            command = _command(semantic_step, progression, heading)
            output = core.balanced_wave_policy_step(
                inherited.base.POLICY_ID,
                {
                    "descriptor": inherited.base.bridge.s169_descriptor(),
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
                or receipt.get("policy_id") != inherited.base.POLICY_ID
                or [item["actuator_id"] for item in actuation["ordered_commands"]]
                != ordered_ids
                or len(actuation["ordered_commands"]) != design.ACTUATOR_COUNT
            ):
                raise R23D10MujocoPhysicalError(
                    "QSDK_R23D10_MJC_CONTROLLER_OUTPUT_INVALID"
                )
            expected = inherited.base._independent_oracle(state, command, profile)
            oracle_failures = inherited.base._predicate_failures(expected, receipt)
            if oracle_failures:
                raise R23D10MujocoPhysicalError(
                    "QSDK_R23D10_MJC_CONTROLLER_RECEIPT_INVALID:"
                    + ",".join(oracle_failures)
                )
            canonical = core.canonical_velocity_compose_v1(
                {
                    "schema_version": "sporespore_canonical_velocity_compose_request_v1",
                    "descriptor": inherited.base.bridge.s169_descriptor(),
                    "source_actuation": actuation,
                    "ordered_stability_residuals": inherited.base._zero_residuals(
                        actuation
                    ),
                }
            )
            mapping = core.canonical_velocity_host_map_v1(
                {
                    "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
                    "descriptor": inherited.base.bridge.s169_descriptor(),
                    "canonical_actuation": canonical,
                    "host_profile": inherited.base.bridge._mujoco_host_profile(
                        inherited.base.HOST_PROFILE_ID
                    ),
                }
            )
            maximum_requested = max(
                maximum_requested,
                abs(float(receipt["requested_steering_fraction"])),
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
            metrics, contacts, maximum_tilt, minimum_height = _observation(
                robot, counters, maximum_tilt, minimum_height
            )
            if semantic_step + 1 == design.TURN_START_STEP + design.TURN_DURATION_STEPS:
                turn_end_yaw = float(metrics["yaw_rad"])
            if semantic_step >= inherited.base.CONTACT_GATED_START_STEP:
                for limb, present in contacts.items():
                    if not previous_contacts[limb] and present:
                        contact_cycles[limb] += 1
                    previous_contacts[limb] = present
            rows.append(
                _controller_row(
                    cell, semantic_step, metrics, contacts, application_count
                )
            )

        taper_state = terminal.State()
        restoration_memory = inherited.restoration.TerminalRestorationMemory()
        independent_pose_memory: dict[str, float] = {}
        for terminal_step in range(design.TERMINAL_STEPS):
            trace_step = design.CONTROLLER_STEPS + terminal_step
            pre_mode = taper_state.mode
            numerator, denominator = terminal.expected_velocity_scale_fraction(
                taper_state
            )
            maximum_speed: float | None = None
            if pre_mode != terminal.PASSIVE_MODE:
                state = inherited.base._state_frame(
                    robot, trace_step, task_origin, reference_heading_rad
                )
                heading = {
                    "phase_id": "terminal_neutral_acquisition",
                    "heading_offset_rad": 0.0,
                    "desired_heading_rad": reference_heading_rad,
                }
                command = _command(trace_step, "contact_gated", heading)
                output = core.balanced_wave_policy_step(
                    inherited.base.POLICY_ID,
                    {
                        "descriptor": inherited.base.bridge.s169_descriptor(),
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
                    maximum_requested,
                    abs(float(receipt["requested_steering_fraction"])),
                )
                maximum_held = max(
                    maximum_held,
                    abs(float(receipt["held_steering_fraction"])),
                )
                pre = inherited.mv3._snapshot(robot)
                stability_state = robot.stability_state(trace_step)
                kinematics = robot.endpoint_kinematics(stability_state)
                composed = inherited.restoration.terminal_restoration_composition(
                    robot,
                    actuation,
                    profile,
                    state,
                    dict(pre["ordered_declared_contacts"]),
                    kinematics,
                    restoration_memory,
                )
                terminal_receipt = composed["terminal_receipt"]
                receipt_failures = inherited.restoration.terminal_receipt_failures(
                    terminal_receipt,
                    composed["canonical_actuation"],
                    composed["host_mapping"],
                )
                transition_failures = (
                    inherited.restoration._terminal_pose_memory_transition_failures(
                        terminal_receipt, independent_pose_memory
                    )
                )
                counters["terminal_receipt_validation_failure_count"] += len(
                    receipt_failures
                ) + len(transition_failures)
                if receipt_failures or transition_failures:
                    raise R23D10MujocoPhysicalError(
                        "QSDK_R23D10_MJC_TERMINAL_RECEIPT_INVALID:"
                        + ",".join((receipt_failures + transition_failures)[:8])
                    )
                solutions = terminal_receipt["ordered_actuator_solutions"]
                _canonical, scaled_host, maximum_speed = _scaled_terminal_mapping(
                    robot,
                    actuation,
                    composed,
                    numerator,
                    denominator,
                )
                maximum_terminal_speed = max(maximum_terminal_speed, maximum_speed)
                counters["validated_portable_command_count"] += len(solutions)
                application = robot.apply_host_mapping(scaled_host)
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
            else:
                inherited.base._zero_prepared_outer_step(robot)
                robot.prepare()
                application_count = 0
            metrics, contacts, maximum_tilt, minimum_height = _observation(
                robot, counters, maximum_tilt, minimum_height
            )
            completed_state = inherited.base._state_frame(
                robot, trace_step, task_origin, reference_heading_rad
            )
            ordered_joint_observations = completed_state.get(
                "ordered_joint_observations", []
            )
            if len(ordered_joint_observations) != design.ACTUATOR_COUNT:
                raise R23D10MujocoPhysicalError(
                    "QSDK_R23D10_MJC_TERMINAL_OBSERVATION_COUNT"
                )
            maximum_error = max(
                abs(float(item["position_rad"]))
                for item in ordered_joint_observations
            )
            terminal_observation = terminal.Observation(
                tuple(bool(contacts[limb]) for limb in design.LIMB_IDS),
                float(metrics["tilt_rad"]),
                maximum_error,
            )
            taper_state, taper_receipt = terminal.observe_completed_step(
                taper_state,
                terminal_observation,
                application_count,
                numerator,
                denominator,
            )
            rows.append(
                _terminal_row(
                    cell,
                    trace_step,
                    terminal_observation,
                    taper_receipt,
                    metrics,
                    contacts,
                    maximum_speed,
                )
            )

        replay = terminal.outcome(taper_state)
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
            raise R23D10MujocoPhysicalError(
                "QSDK_R23D10_MJC_TURN_WINDOW_INCOMPLETE"
            )
        measurements = {
            "final_forward_displacement_m": float(final_delta @ task_forward),
            "turn_phase_yaw_delta_rad": inherited.base._wrap_angle(
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
            "terminal_quiescent_taper_step_count": design.TERMINAL_STEPS,
            "validated_portable_command_count": counters[
                "validated_portable_command_count"
            ],
            "native_actuation_application_count": counters[
                "native_actuation_application_count"
            ],
            "post_handoff_native_actuation_application_count": replay[
                "passive_native_application_count"
            ],
            "confirmation_satisfied": replay["confirmation_satisfied"],
            "handoff_after_active_step": replay["handoff_after_active_step"],
            "first_passive_step": replay["first_passive_step"],
            "handoff_reason": replay["handoff_reason"],
            "active_terminal_step_count": replay["active_step_count"],
            "quiescent_taper_step_count": replay["taper_step_count"],
            "passive_terminal_step_count": replay["passive_step_count"],
            "taper_reset_count": replay["taper_reset_count"],
            "active_terminal_native_actuation_application_count": replay[
                "active_native_application_count"
            ],
            "quiescent_taper_gate_passed": replay[
                "quiescent_taper_gate_passed"
            ],
            "first_post_handoff_contact_loss_step": replay[
                "first_post_handoff_contact_loss_step"
            ],
            "post_handoff_contact_loss_step_count": replay[
                "post_handoff_contact_loss_step_count"
            ],
            "terminal_receipt_validation_failure_count": counters[
                "terminal_receipt_validation_failure_count"
            ],
            "maximum_absolute_terminal_active_joint_velocity_rad_s": (
                maximum_terminal_speed
            ),
        }
        retained = _retain_trace(cell, rows, authorization["attempt_root"])
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
            "trace_artifact": retained["trace_artifact"],
            "trace_summary": retained["trace_summary"],
            "execution": {
                "integrity_passed": True,
                "worker_failure_code": "",
                "controller_semantic_step_count": design.CONTROLLER_STEPS,
                "terminal_quiescent_taper_step_count": design.TERMINAL_STEPS,
                "validated_portable_command_count": counters[
                    "validated_portable_command_count"
                ],
                "native_actuation_application_count": counters[
                    "native_actuation_application_count"
                ],
                "post_handoff_native_actuation_application_count": replay[
                    "passive_native_application_count"
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
            "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
        }
        json.dumps(report, allow_nan=False)
        return report
    except R23D10MujocoPhysicalError as error:
        if error.terminal_receipt is not None:
            raise
        raise _failure(
            cell, source_commit, "settlement_complete", error.code, 1, 1
        ) from error
    except Exception as error:
        raise _failure(
            cell,
            source_commit,
            "settlement_complete",
            f"QSDK_R23D10_MJC_RUNTIME_ERROR:{type(error).__name__}:{error}",
            1,
            1,
        ) from error
