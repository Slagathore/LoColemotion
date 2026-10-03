"""Dormant classic-MuJoCo physical worker for prospective QSDK-R23D17.

The real adapter loop is the already frozen R23D13 implementation, loaded
under a private module identity and rebound to the R23D17 direct-matrix trace,
evaluator, and tight-gated 600-active/960-total temporal policy.  The private
load keeps both campaign implementations isolated when imported together.

No model can be constructed until the common production authorization path
accepts a clean, pushed source freeze and a single-use authorization for the
complete ordered nine-cell matrix.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys
from types import ModuleType
from typing import Any, Sequence


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from . import qsdk_r23d11_stability_assisted_taper as native
from . import qsdk_r23d12_measurement_semantics as diagnostics
from . import qsdk_r23d13_residual_pose_authority as authority_native
from . import qsdk_r23d14_tight_gated_horizon as temporal_native

import r23d17_physical_evaluator as evaluator  # noqa: E402
import r23d17_physical_trace as design  # noqa: E402
import r23d14_tight_gated_horizon as terminal  # noqa: E402


def _load_private_worker_core() -> ModuleType:
    source = Path(__file__).with_name(
        "qsdk_r23d13_residual_pose_authority_physical.py"
    )
    specification = importlib.util.spec_from_file_location(
        "sporespore_mujoco_adapter._qsdk_r23d17_inherited_physical_core",
        source,
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("QSDK_R23D17_MJC_INHERITED_WORKER_UNAVAILABLE")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


_core = _load_private_worker_core()

PREREGISTRATION_PATH = (
    TURNING_ROOT / "r23d17_live_composition_recovery_preregistration_v1.json"
)
TEMPORAL_PREREGISTRATION_PATH = (
    TURNING_ROOT / "r23d14_tight_gated_horizon_preregistration_v1.json"
)
IMPLEMENTATION_PATH = TURNING_ROOT / "r23d17_physical_implementation_contract_v1.json"
CLOSURE_PATH = TURNING_ROOT / "r23d17_physical_closure_v1.json"
CAMPAIGN_ID = design.CAMPAIGN_ID
GATE_ID = design.GATE_ID
ENGINE_ID = "mujoco"
SCHEDULE_ID = "qsdk_r23d17_composition_recovery_v1"
FREEZE_SCHEMA = "sporespore_qsdk_r23d17_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d17_attempt_v1"
FAILURE_SCHEMA = evaluator.FAILURE_SCHEMA
REPORT_SCHEMA = evaluator.REPORT_SCHEMA
# These are stable report-schema field names, not policy identities. R23D17
# preserves their R23D14 values and replay law under a distinct evidence schema.
TERMINAL_STEP_COUNT_FIELD = "terminal_quiescent_taper_step_count"
TAPER_STEP_COUNT_FIELD = "quiescent_taper_step_count"
TAPER_GATE_FIELD = "quiescent_taper_gate_passed"

FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D17_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D17_ATTEMPT"
AUTHORIZATION_TOKEN_ENV = "SPORESPORE_QSDK_R23D17_TOKEN"
STAGE_ID_ENV = "SPORESPORE_QSDK_R23D17_STAGE"
CELL_ID_ENV = "SPORESPORE_QSDK_R23D17_CELL"
ENGINE_ID_ENV = "SPORESPORE_QSDK_R23D17_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D17_ATTEMPT_ROOT"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D17_POWERSHELL"


class R23D17MujocoPhysicalError(RuntimeError):
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


def _translate(value: Any) -> Any:
    if isinstance(value, str):
        return value.replace("R23D13", "R23D17").replace(
            "QSDK-R23D13", "QSDK-R23D17"
        )
    if isinstance(value, list):
        return [_translate(item) for item in value]
    if isinstance(value, tuple):
        return tuple(_translate(item) for item in value)
    if isinstance(value, dict):
        return {key: _translate(item) for key, item in value.items()}
    return value


def _fail(code: str) -> None:
    raise R23D17MujocoPhysicalError(code)


def _cell(stage_id: str, arm_id: str) -> design.Cell:
    matches = [
        cell
        for cell in design.matrix_cells()
        if cell.stage_id == stage_id
        and cell.engine_id == ENGINE_ID
        and cell.arm_id == arm_id
    ]
    if len(matches) != 1:
        _fail(f"QSDK_R23D17_MJC_CELL_IDENTITY_INVALID:{stage_id}:{arm_id}")
    return matches[0]


def _contract() -> dict[str, Any]:
    """Validate the R23D17 law and every inherited native semantic layer."""

    declaration = _core._read_json(
        PREREGISTRATION_PATH, "QSDK_R23D17_MJC_DECLARATION_UNREADABLE"
    )
    # Exercise the independently qualified evaluator's stricter declaration
    # projection as well as the worker's complete campaign identity checks.
    evaluator._load_declaration()
    temporal_declaration = _core._read_json(
        TEMPORAL_PREREGISTRATION_PATH,
        "QSDK_R23D17_MJC_TEMPORAL_DECLARATION_UNREADABLE",
    )
    frozen = declaration.get("frozen_scientific_question", {})
    matrix = declaration.get("prospective_matrix", {})
    policy = temporal_declaration.get("terminal_policy_contract", {})
    composition = temporal_declaration.get("inherited_whole_body_composition", {})
    authority_contract = temporal_declaration.get(
        "inherited_residual_pose_authority", {}
    )
    native_canaries, native_mutations = native.run_zero_world_preflight()
    diagnostic_receipt = diagnostics.preflight()
    authority_receipt = authority_native.preflight()
    temporal_receipt = temporal_native.preflight()
    if (
        declaration.get("schema_version")
        != "sporespore_qsdk_r23d17_implementation_recovery_preregistration_v1"
        or declaration.get("campaign_id") != CAMPAIGN_ID
        or declaration.get("gate_id") != GATE_ID
        or declaration.get("zero_world_qualification", {}).get(
            "physical_execution_authorized"
        )
        is not False
        or temporal_declaration.get("schema_version")
        != "sporespore_qsdk_r23d14_tight_gated_horizon_preregistration_v1"
        or temporal_declaration.get("campaign_id")
        != "QSDK-R23D14-TIGHT-GATED-HORIZON-THREE-ENGINE-TURN-CONFIRMATION"
        or frozen.get("changed_from_r23d16") is not False
        or frozen.get("selected_policy_id") != terminal.POLICY_ID
        or frozen.get("controller_step_count") != design.CONTROLLER_STEPS
        or frozen.get("terminal_step_count") != terminal.TERMINAL_STEPS
        or frozen.get("total_trace_row_count_per_cell")
        != design.TOTAL_TRACE_STEPS
        or frozen.get("maximum_active_neutral_acquisition_step_count")
        != terminal.MAXIMUM_ACTIVE_STEPS
        or frozen.get("minimum_confirmed_taper_step_count")
        != terminal.MINIMUM_TAPER_STEPS
        or frozen.get("minimum_post_handoff_zero_actuation_step_count")
        != terminal.MINIMUM_PASSIVE_STEPS
        or frozen.get("coarse_maximum_torso_tilt_rad")
        != terminal.COARSE_MAXIMUM_TILT_RAD
        or frozen.get("coarse_maximum_joint_position_error_rad")
        != terminal.COARSE_MAXIMUM_JOINT_ERROR_RAD
        or frozen.get("tight_maximum_torso_tilt_rad")
        != terminal.TIGHT_MAXIMUM_TILT_RAD
        or frozen.get("tight_maximum_joint_position_error_rad")
        != terminal.TIGHT_MAXIMUM_JOINT_ERROR_RAD
        or frozen.get("walking_turning_controller_changed") is not False
        or frozen.get("fixture_changed") is not False
        or frozen.get("morphology_changed") is not False
        or frozen.get("threshold_changed") is not False
        or frozen.get("horizon_changed") is not False
        or frozen.get("gain_changed") is not False
        or matrix.get("stage_id") != design.MATRIX_STAGE_ID
        or matrix.get("ordered_engine_ids") != list(design.MATRIX_ENGINES)
        or matrix.get("ordered_arm_ids") != list(design.MATRIX_ARMS)
        or matrix.get("declared_cell_count") != 9
        or matrix.get("serialized_execution_required") is not True
        or matrix.get("all_cells_run_without_outcome_early_stop") is not True
        or matrix.get("selective_replacement_or_rerun_permitted") is not False
        or policy.get("policy_id") != terminal.POLICY_ID
        or policy.get("initial_mode") != terminal.ACTIVE_MODE
        or policy.get("quiescent_mode") != terminal.TAPER_MODE
        or policy.get("passive_mode") != terminal.PASSIVE_MODE
        or policy.get("terminal_step_count") != terminal.TERMINAL_STEPS
        or policy.get("maximum_active_step_count") != terminal.MAXIMUM_ACTIVE_STEPS
        or policy.get("minimum_quiescent_taper_step_count")
        != terminal.MINIMUM_TAPER_STEPS
        or policy.get("minimum_passive_step_count") != terminal.MINIMUM_PASSIVE_STEPS
        or policy.get("coarse_maximum_torso_tilt_rad")
        != terminal.COARSE_MAXIMUM_TILT_RAD
        or policy.get("coarse_maximum_joint_position_error_rad")
        != terminal.COARSE_MAXIMUM_JOINT_ERROR_RAD
        or policy.get("tight_maximum_torso_tilt_rad")
        != terminal.TIGHT_MAXIMUM_TILT_RAD
        or policy.get("tight_maximum_joint_position_error_rad")
        != terminal.TIGHT_MAXIMUM_JOINT_ERROR_RAD
        or policy.get("tight_pose_loss_resets_to_full_acquisition") is not True
        or policy.get("deadline_forced_handoff_can_pass") is not False
        or policy.get("mode_reactivation_after_passive_handoff_permitted") is not False
        or policy.get("every_post_handoff_step_requires_all_four_contacts") is not True
        or policy.get("every_post_handoff_step_requires_zero_native_actuation")
        is not True
        or policy.get("all_960_terminal_steps_execute") is not True
        or composition.get("ordered_actuator_count") != terminal.ACTUATOR_COUNT
        or composition.get("maximum_absolute_stability_velocity_delta_rad_s")
        != native.MAXIMUM_STABILITY_DELTA
        or composition.get("neutral_base_velocity_limit_rad_s")
        != native.MAXIMUM_NEUTRAL_VELOCITY
        or composition.get("maximum_pre_taper_combined_velocity_magnitude_rad_s")
        != native.MAXIMUM_COMBINED_VELOCITY
        or composition.get("complete_neutral_plus_stability_command_is_feedback_scaled")
        is not True
        or composition.get("host_mapping_applied_once_after_feedback_scale") is not True
        or authority_contract.get("scale_denominator")
        != authority_native.SCALE_DENOMINATOR
        or authority_contract.get("maximum_floor_numerator")
        != authority_native.SCALE_DENOMINATOR
        or authority_contract.get(
            "authority_floor_may_never_reduce_temporal_authority"
        )
        is not True
        or authority_contract.get(
            "complete_combined_velocity_scaled_once_before_host_mapping"
        )
        is not True
        or native_canaries != 7
        or native_mutations != 18
        or diagnostic_receipt.get("engine_id") != ENGINE_ID
        or diagnostic_receipt.get("valid_canary_count") != 7
        or diagnostic_receipt.get("active_cross_product_count") != 6
        or diagnostic_receipt.get("mutation_control_count") != 14
        or authority_receipt.get("valid_canary_count") != 10
        or authority_receipt.get("mutation_control_count") != 20
        or temporal_receipt.get("engine_id") != ENGINE_ID
        or temporal_receipt.get("valid_canary_count") != 12
        or temporal_receipt.get("mutation_control_count") != 14
        or temporal_receipt.get("physical_execution_authorized") is not False
    ):
        _fail("QSDK_R23D17_MJC_CONTRACT_IDENTITY_INVALID")
    return declaration


def physical_authorization(
    cell: design.Cell, source_commit: str
) -> dict[str, Any]:
    """Exercise the exact production authorization path without a world."""

    if CLOSURE_PATH.is_file():
        _fail("QSDK_R23D17_MJC_CLOSED")
    freeze_path = Path(os.environ.get(FREEZE_PATH_ENV, ""))
    attempt_path = Path(os.environ.get(ATTEMPT_PATH_ENV, ""))
    attempt_root = Path(os.environ.get(ATTEMPT_ROOT_ENV, ""))
    token = os.environ.get(AUTHORIZATION_TOKEN_ENV, "")
    if (
        not IMPLEMENTATION_PATH.is_file()
        or not freeze_path.is_file()
        or not attempt_path.is_file()
        or not attempt_root.is_dir()
        or not _core._valid_lower_hex(token, 32)
    ):
        _fail("QSDK_R23D17_MJC_PHYSICAL_AUTHORIZATION_REQUIRED")
    freeze = _core._read_json(freeze_path, "QSDK_R23D17_MJC_FREEZE_UNREADABLE")
    attempt = _core._read_json(attempt_path, "QSDK_R23D17_MJC_ATTEMPT_UNREADABLE")
    production_root = (REPO_ROOT.parent / "SporeSpore_Evidence").resolve()
    try:
        attempt_root.resolve().relative_to(production_root)
    except ValueError as error:
        raise R23D17MujocoPhysicalError(
            "QSDK_R23D17_MJC_ATTEMPT_ROOT_NOT_DURABLE"
        ) from error
    ordered_cell_ids = [cell.cell_id for cell in design.matrix_cells()]
    if (
        freeze.get("schema_version") != FREEZE_SCHEMA
        or freeze.get("campaign_id") != CAMPAIGN_ID
        or freeze.get("gate_id") != GATE_ID
        or freeze.get("status") != "frozen_supervisor_only_physical_authorized"
        or freeze.get("preregistration_raw_sha256")
        != _core._raw_sha256(PREREGISTRATION_PATH)
        or freeze.get("implementation_contract_raw_sha256")
        != _core._raw_sha256(IMPLEMENTATION_PATH)
        or freeze.get("source_commit") != source_commit
        or freeze.get("physical_execution_authorized") is not True
        or not _core._source_bindings_exact(freeze)
        or attempt.get("schema_version") != ATTEMPT_SCHEMA
        or attempt.get("campaign_id") != CAMPAIGN_ID
        or attempt.get("gate_id") != GATE_ID
        or attempt.get("freeze_raw_sha256") != _core._raw_sha256(freeze_path)
        or attempt.get("source_commit") != source_commit
        or attempt.get("authorization_token") != token
        or not _core._valid_lower_hex(attempt.get("attempt_id"), 32)
        or attempt.get("physical_execution_authorized") is not True
        or attempt.get("single_use_supervisor_authorization") is not True
        or attempt.get("matrix_authorization_immutable_before_first_world") is not True
        or attempt.get("ordered_matrix_cell_ids") != ordered_cell_ids
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
    ):
        _fail("QSDK_R23D17_MJC_PHYSICAL_AUTHORIZATION_INVALID")
    return {"freeze": freeze, "attempt": attempt, "attempt_root": attempt_root}


# Rebind every semantic global used by the inherited real-physics loop.  These
# mutations are private to the module instance loaded above.
for _name, _value in {
    "design": design,
    "evaluator": evaluator,
    "terminal": terminal,
    "PREREGISTRATION_PATH": PREREGISTRATION_PATH,
    "IMPLEMENTATION_PATH": IMPLEMENTATION_PATH,
    "CLOSURE_PATH": CLOSURE_PATH,
    "CAMPAIGN_ID": CAMPAIGN_ID,
    "GATE_ID": GATE_ID,
    "ENGINE_ID": ENGINE_ID,
    "SCHEDULE_ID": SCHEDULE_ID,
    "FREEZE_SCHEMA": FREEZE_SCHEMA,
    "ATTEMPT_SCHEMA": ATTEMPT_SCHEMA,
    "FAILURE_SCHEMA": FAILURE_SCHEMA,
    "REPORT_SCHEMA": REPORT_SCHEMA,
    "TERMINAL_STEP_COUNT_FIELD": TERMINAL_STEP_COUNT_FIELD,
    "TAPER_STEP_COUNT_FIELD": TAPER_STEP_COUNT_FIELD,
    "TAPER_GATE_FIELD": TAPER_GATE_FIELD,
    "FREEZE_PATH_ENV": FREEZE_PATH_ENV,
    "ATTEMPT_PATH_ENV": ATTEMPT_PATH_ENV,
    "AUTHORIZATION_TOKEN_ENV": AUTHORIZATION_TOKEN_ENV,
    "STAGE_ID_ENV": STAGE_ID_ENV,
    "CELL_ID_ENV": CELL_ID_ENV,
    "ENGINE_ID_ENV": ENGINE_ID_ENV,
    "ATTEMPT_ROOT_ENV": ATTEMPT_ROOT_ENV,
    "POWERSHELL_ENV": POWERSHELL_ENV,
    "R23D13MujocoPhysicalError": R23D17MujocoPhysicalError,
    "_cell": _cell,
    "_contract": _contract,
    "physical_authorization": physical_authorization,
}.items():
    setattr(_core, _name, _value)


def authorization_preflight(
    stage_id: str, arm_id: str, source_commit: str
) -> dict[str, Any]:
    cell = _cell(stage_id, arm_id)
    if not _core._valid_lower_hex(source_commit, 40):
        _fail("QSDK_R23D17_MJC_SOURCE_COMMIT_INVALID")
    physical_authorization(cell, source_commit)
    return {
        "schema_version": "sporespore_qsdk_r23d17_mujoco_production_authorization_preflight_v1",
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


def worker_preflight(stage_id: str, arm_id: str) -> dict[str, Any]:
    cell = _cell(stage_id, arm_id)
    _contract()
    return {
        "schema_version": "sporespore_qsdk_r23d17_mujoco_physical_worker_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": ENGINE_ID,
        "arm_id": cell.arm_id,
        "inherited_r23d11_controller_and_physics": True,
        "inherited_r23d13_residual_pose_authority": True,
        "r23d14_tight_gated_horizon_inherited_unchanged": True,
        "r23d17_composition_recovery_identity_enabled": True,
        "command_time_feedback_is_previous_completed_step": True,
        "physical_worker_implemented": True,
        "physical_worker_dormant_behind_supervisor_authorization": True,
        "physical_execution_authorized": False,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def run_physical(stage_id: str, arm_id: str, source_commit: str) -> dict[str, Any]:
    try:
        return _translate(_core.run_physical(stage_id, arm_id, source_commit))
    except R23D17MujocoPhysicalError as error:
        raise R23D17MujocoPhysicalError(
            str(_translate(error.code)),
            world_attempt_count=error.world_attempt_count,
            world_build_count=error.world_build_count,
            terminal_receipt=_translate(error.terminal_receipt),
        ) from error


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    for command_parser in (
        commands.add_parser("preflight"),
        commands.add_parser("authorization-preflight"),
        commands.add_parser("physical"),
    ):
        command_parser.add_argument("--stage-id", required=True)
        command_parser.add_argument("--arm-id", required=True)
        command_parser.add_argument("--source-commit", default="")
    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "preflight":
            receipt = worker_preflight(arguments.stage_id, arguments.arm_id)
            marker = "QSDK_R23D17_MUJOCO_PREFLIGHT "
        elif arguments.command == "authorization-preflight":
            receipt = authorization_preflight(
                arguments.stage_id, arguments.arm_id, arguments.source_commit
            )
            marker = "QSDK_R23D17_MUJOCO_AUTHORIZATION_PREFLIGHT "
        else:
            receipt = run_physical(
                arguments.stage_id, arguments.arm_id, arguments.source_commit
            )
            marker = "QSDK_R23D17_TERMINAL "
        print(marker + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except R23D17MujocoPhysicalError as error:
        if error.terminal_receipt is not None:
            marker = "QSDK_R23D17_TERMINAL "
            receipt = error.terminal_receipt
        else:
            marker = "QSDK_R23D17_MUJOCO_FAILURE "
            receipt = {"failure_code": error.code}
        print(marker + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
