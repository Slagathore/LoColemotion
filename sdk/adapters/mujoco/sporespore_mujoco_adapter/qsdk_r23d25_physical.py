"""One-shot classic-MuJoCo worker for prospective QSDK-R23D25.

The walking and turning loop remains the qualified R23D13/R23D23 loop.  This
successor keeps the R23D24 receipt compatibility repair, but fixes the command
role at the terminal boundary: ``terminal_neutral_acquisition`` now requests
zero forward speed instead of inheriting the walking request of 0.2 m/s.

The real R23D21 forward-velocity receipt is checked on every active terminal
step.  Desired speed, normalized error, and every applied foot-placement
correction must all be exact zero.  The audit counts are retained in the cell
report, so the physical run proves that the new semantic reached the controller
rather than merely existing in source.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path
import sys
from typing import Any, Sequence

from sporespore_locomotion import LocomotionCore


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from . import qsdk_r23d23_physical as inherited  # noqa: E402
from . import qsdk_r23d23_postclosure_forward_receipt_compatibility as repair  # noqa: E402
from . import qsdk_r23d8_neutral_stance_composition as restoration  # noqa: E402

import r23d25_mujoco_terminal_zero_forward_evaluator as evaluator  # noqa: E402
import r23d25_mujoco_terminal_zero_forward_trace as design  # noqa: E402


_core = inherited._core
PREREGISTRATION_PATH = (
    TURNING_ROOT / "r23d25_mujoco_terminal_zero_forward_preregistration_v1.json"
)
IMPLEMENTATION_PATH = (
    TURNING_ROOT / "r23d25_mujoco_terminal_zero_forward_implementation_v1.json"
)
CLOSURE_PATH = TURNING_ROOT / "r23d25_mujoco_terminal_zero_forward_closure_v1.json"
CAMPAIGN_ID = design.CAMPAIGN_ID
GATE_ID = design.GATE_ID
ENGINE_ID = "mujoco"
CONTROLLER_POLICY_ID = design.CONTROLLER_POLICY_ID
SOURCE_CONTRACT_ID = restoration.R23D21_FORWARD_VELOCITY_SOURCE_CONTRACT_ID
TERMINAL_PHASE_ID = "terminal_neutral_acquisition"
TERMINAL_DESIRED_FORWARD_VELOCITY_M_S = 0.0
FREEZE_SCHEMA = "sporespore_qsdk_r23d25_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d25_attempt_v1"
FAILURE_SCHEMA = evaluator.FAILURE_SCHEMA
REPORT_SCHEMA = evaluator.REPORT_SCHEMA
FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D25_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D25_ATTEMPT"
AUTHORIZATION_TOKEN_ENV = "SPORESPORE_QSDK_R23D25_TOKEN"
STAGE_ID_ENV = "SPORESPORE_QSDK_R23D25_STAGE"
CELL_ID_ENV = "SPORESPORE_QSDK_R23D25_CELL"
ENGINE_ID_ENV = "SPORESPORE_QSDK_R23D25_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D25_ATTEMPT_ROOT"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D25_POWERSHELL"


class R23D25MujocoPhysicalError(RuntimeError):
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


_terminal_audit: dict[str, int | float] = {}


def _reset_terminal_audit() -> None:
    _terminal_audit.clear()
    _terminal_audit.update(
        {
            "terminal_zero_forward_command_count": 0,
            "terminal_zero_forward_receipt_count": 0,
            "terminal_nonzero_forward_command_count": 0,
            "terminal_forward_receipt_violation_count": 0,
            "maximum_absolute_terminal_desired_forward_velocity_m_s": 0.0,
            "maximum_absolute_terminal_normalized_forward_velocity_error": 0.0,
            "maximum_absolute_terminal_forward_hip_correction_rad": 0.0,
        }
    )


_reset_terminal_audit()
_inherited_command = _core._command


def _terminal_zero_forward_command(
    semantic_step: int,
    progression: str,
    heading: dict[str, Any],
) -> dict[str, Any]:
    """Preserve walking commands and zero only the explicitly terminal role."""

    command = _inherited_command(semantic_step, progression, heading)
    desired = command.get("desired_planar_velocity_task_m_s")
    if not isinstance(desired, dict):
        raise R23D25MujocoPhysicalError(
            "QSDK_R23D25_MJC_DESIRED_VELOCITY_SHAPE_INVALID"
        )
    if heading.get("phase_id") == TERMINAL_PHASE_ID:
        if desired.get("x") != 0.2 or desired.get("y") != 0.0 or desired.get("z") != 0.0:
            raise R23D25MujocoPhysicalError(
                "QSDK_R23D25_MJC_INHERITED_TERMINAL_COMMAND_DRIFT"
            )
        desired["x"] = TERMINAL_DESIRED_FORWARD_VELOCITY_M_S
        _terminal_audit["terminal_zero_forward_command_count"] += 1
        _terminal_audit[
            "maximum_absolute_terminal_desired_forward_velocity_m_s"
        ] = max(
            float(
                _terminal_audit[
                    "maximum_absolute_terminal_desired_forward_velocity_m_s"
                ]
            ),
            abs(float(desired["x"])),
        )
        if desired["x"] != 0.0:
            _terminal_audit["terminal_nonzero_forward_command_count"] += 1
    return command


_core._command = _terminal_zero_forward_command


def _validate_terminal_zero_forward_receipt(receipt: Any) -> None:
    """Reject any active-terminal receipt that retains locomotion intent."""

    forward = (
        receipt.get("forward_velocity_foot_placement")
        if isinstance(receipt, dict)
        else None
    )
    corrections = (
        forward.get("ordered_limb_corrections")
        if isinstance(forward, dict)
        else None
    )
    valid = (
        isinstance(forward, dict)
        and forward.get("desired_forward_velocity_task_m_s") == 0.0
        and forward.get("normalized_forward_velocity_error") == 0.0
        and isinstance(corrections, list)
        and len(corrections) == 4
        and all(
            isinstance(item, dict)
            and item.get("applied_hip_target_correction_rad") == 0.0
            for item in corrections
        )
    )
    if not valid:
        _terminal_audit["terminal_forward_receipt_violation_count"] += 1
        raise R23D25MujocoPhysicalError(
            "QSDK_R23D25_MJC_TERMINAL_ZERO_FORWARD_RECEIPT_INVALID"
        )
    _terminal_audit["terminal_zero_forward_receipt_count"] += 1
    _terminal_audit[
        "maximum_absolute_terminal_normalized_forward_velocity_error"
    ] = max(
        float(
            _terminal_audit[
                "maximum_absolute_terminal_normalized_forward_velocity_error"
            ]
        ),
        abs(float(forward["normalized_forward_velocity_error"])),
    )
    _terminal_audit["maximum_absolute_terminal_forward_hip_correction_rad"] = max(
        float(
            _terminal_audit[
                "maximum_absolute_terminal_forward_hip_correction_rad"
            ]
        ),
        max(
            abs(float(item["applied_hip_target_correction_rad"]))
            for item in corrections
        ),
    )


def _zero_forward_receipt_mutations(valid_receipt: dict[str, Any]) -> int:
    mutations: list[dict[str, Any]] = []
    for path, value in (
        (("forward_velocity_foot_placement", "desired_forward_velocity_task_m_s"), 0.2),
        (("forward_velocity_foot_placement", "normalized_forward_velocity_error"), 1.0),
        (
            (
                "forward_velocity_foot_placement",
                "ordered_limb_corrections",
                0,
                "applied_hip_target_correction_rad",
            ),
            0.01,
        ),
    ):
        mutated = copy.deepcopy(valid_receipt)
        target: Any = mutated
        for member in path[:-1]:
            target = target[member]
        target[path[-1]] = value
        mutations.append(mutated)
    missing = copy.deepcopy(valid_receipt)
    del missing["forward_velocity_foot_placement"]
    mutations.append(missing)

    rejected = 0
    for mutation in mutations:
        before = int(_terminal_audit["terminal_forward_receipt_violation_count"])
        try:
            _validate_terminal_zero_forward_receipt(mutation)
        except R23D25MujocoPhysicalError:
            rejected += 1
        finally:
            _terminal_audit["terminal_forward_receipt_violation_count"] = before
    return rejected


def run_terminal_zero_forward_preflight() -> dict[str, Any]:
    """Exercise the real controller and receipt without constructing a model."""

    _reset_terminal_audit()
    core, compiled, profile, state, _walking_actuation = repair._source_fixture(
        "reference_zero"
    )
    terminal_command = _terminal_zero_forward_command(
        0,
        "contact_gated",
        {
            "phase_id": TERMINAL_PHASE_ID,
            "heading_offset_rad": 0.0,
            "desired_heading_rad": 0.0,
        },
    )
    terminal_output = core.balanced_wave_policy_step(
        CONTROLLER_POLICY_ID,
        {
            "descriptor": repair.base.bridge.s169_descriptor(),
            "memory": core.balanced_wave_initial_memory(),
            "state": state,
            "command": terminal_command,
        },
    )
    terminal_actuation = terminal_output["actuation"]
    _validate_terminal_zero_forward_receipt(terminal_actuation.get("receipt"))
    composed = _core.inherited.restoration.terminal_restoration_composition(
        restoration._ZeroWorldRobot(core, compiled),
        terminal_actuation,
        profile,
        state,
        {
            site_id: True
            for site_id in compiled["morphology"]["ordered_contact_site_ids"]
        },
        repair.prior_shape._production_kinematics(compiled),
        restoration.TerminalRestorationMemory(),
    )
    receipt = terminal_actuation["receipt"]
    mutation_count = _zero_forward_receipt_mutations(receipt)
    walking_command = _inherited_command(
        0,
        "contact_gated",
        {
            "phase_id": "reference_warmup",
            "heading_offset_rad": 0.0,
            "desired_heading_rad": 0.0,
        },
    )
    if (
        terminal_command["desired_planar_velocity_task_m_s"]["x"] != 0.0
        or walking_command["desired_planar_velocity_task_m_s"]["x"] != 0.2
        or composed["terminal_receipt"].get(
            "source_forward_velocity_contract_id"
        )
        != SOURCE_CONTRACT_ID
        or mutation_count != 4
    ):
        raise R23D25MujocoPhysicalError(
            "QSDK_R23D25_MJC_TERMINAL_ZERO_FORWARD_PREFLIGHT_INVALID"
        )
    return {
        "schema_version": "sporespore_qsdk_r23d25_terminal_zero_forward_preflight_v1",
        "valid_canary_count": 4,
        "mutation_control_count": mutation_count,
        "terminal_desired_forward_velocity_m_s": 0.0,
        "walking_desired_forward_velocity_m_s": 0.2,
        "real_controller_receipt_validated": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


class _ReceiptBoundRestoration:
    """Opt into the exact R23D21 receipt shape at both validation layers."""

    def __init__(self, inherited_restoration: Any) -> None:
        self._inherited = inherited_restoration

    def __getattr__(self, name: str) -> Any:
        return getattr(self._inherited, name)

    def terminal_restoration_composition(
        self, *args: Any, **kwargs: Any
    ) -> dict[str, Any]:
        kwargs["supported_policy_id"] = CONTROLLER_POLICY_ID
        kwargs["source_forward_velocity_contract_id"] = SOURCE_CONTRACT_ID
        base_actuation = args[1] if len(args) > 1 else kwargs.get("base_actuation")
        if not isinstance(base_actuation, dict):
            raise R23D25MujocoPhysicalError(
                "QSDK_R23D25_MJC_TERMINAL_SOURCE_ACTUATION_MISSING"
            )
        composed = self._inherited.terminal_restoration_composition(*args, **kwargs)
        _validate_terminal_zero_forward_receipt(base_actuation.get("receipt"))
        return composed

    def terminal_receipt_failures(
        self, *args: Any, **kwargs: Any
    ) -> list[str]:
        kwargs["supported_policy_id"] = CONTROLLER_POLICY_ID
        kwargs["source_forward_velocity_contract_id"] = SOURCE_CONTRACT_ID
        return self._inherited.terminal_receipt_failures(*args, **kwargs)


_core.inherited.restoration = _ReceiptBoundRestoration(
    _core.inherited.restoration
)


def _translate(value: Any) -> Any:
    if isinstance(value, str):
        return value.replace("R23D13", "R23D25").replace(
            "QSDK-R23D13", "QSDK-R23D25"
        )
    if isinstance(value, list):
        return [_translate(item) for item in value]
    if isinstance(value, tuple):
        return tuple(_translate(item) for item in value)
    if isinstance(value, dict):
        return {key: _translate(item) for key, item in value.items()}
    return value


def _fail(code: str) -> None:
    raise R23D25MujocoPhysicalError(code)


def _cell(stage_id: str, arm_id: str) -> design.Cell:
    matches = [
        cell
        for cell in design.matrix_cells()
        if cell.stage_id == stage_id and cell.arm_id == arm_id
    ]
    if len(matches) != 1:
        _fail(f"QSDK_R23D25_MJC_CELL_IDENTITY_INVALID:{stage_id}:{arm_id}")
    return matches[0]


def _contract() -> dict[str, Any]:
    declaration = evaluator._load_declaration()
    trace_preflight = design.zero_world_receipt()
    receipt_preflight = repair.run_zero_world_preflight()
    zero_forward_preflight = run_terminal_zero_forward_preflight()
    native_canaries, native_mutations = inherited.native.run_zero_world_preflight()
    diagnostic = inherited.diagnostics.preflight()
    authority = inherited.authority_native.preflight()
    temporal = inherited.temporal_native.preflight()
    compiled, profile = _core.inherited.base._compile_boundary(LocomotionCore())
    if (
        trace_preflight.get("matrix_cell_count") != 3
        or trace_preflight.get("trace_row_count_per_cell") != 3952
        or trace_preflight.get("model_construction_count") != 0
        or trace_preflight.get("world_build_count") != 0
        or receipt_preflight.get("status")
        != "zero_world_compatibility_repair_passed"
        or receipt_preflight.get("mutation_control_count") != 22
        or receipt_preflight.get("source_forward_velocity_contract_id")
        != SOURCE_CONTRACT_ID
        or receipt_preflight.get("historical_r23d8_default_preserved") is not True
        or zero_forward_preflight.get("valid_canary_count") != 4
        or zero_forward_preflight.get("mutation_control_count") != 4
        or zero_forward_preflight.get("real_controller_receipt_validated") is not True
        or native_canaries != 7
        or native_mutations != 18
        or diagnostic.get("valid_canary_count") != 7
        or diagnostic.get("mutation_control_count") != 14
        or authority.get("valid_canary_count") != 10
        or authority.get("mutation_control_count") != 20
        or temporal.get("valid_canary_count") != 12
        or temporal.get("mutation_control_count") != 14
        or compiled.get("world_build_count") != 0
        or profile.get("policy_id") != CONTROLLER_POLICY_ID
        or profile.get("yaw_error_stride_gain_per_rad") != 1.0
        or profile.get("cross_track_frame_mode_id")
        != design.CROSS_TRACK_FRAME_MODE_ID
    ):
        _fail("QSDK_R23D25_MJC_CONTRACT_IDENTITY_INVALID")
    _reset_terminal_audit()
    return declaration


def physical_authorization(
    cell: design.Cell, source_commit: str
) -> dict[str, Any]:
    if CLOSURE_PATH.is_file():
        _fail("QSDK_R23D25_MJC_CLOSED")
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
        _fail("QSDK_R23D25_MJC_PHYSICAL_AUTHORIZATION_REQUIRED")
    freeze = _core._read_json(freeze_path, "QSDK_R23D25_MJC_FREEZE_UNREADABLE")
    attempt = _core._read_json(
        attempt_path, "QSDK_R23D25_MJC_ATTEMPT_UNREADABLE"
    )
    try:
        attempt_root.resolve().relative_to(
            (REPO_ROOT.parent / "SporeSpore_Evidence").resolve()
        )
    except ValueError as error:
        raise R23D25MujocoPhysicalError(
            "QSDK_R23D25_MJC_ATTEMPT_ROOT_NOT_DURABLE"
        ) from error
    ordered_ids = [item.cell_id for item in design.matrix_cells()]
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
        or attempt.get("ordered_matrix_cell_ids") != ordered_ids
        or attempt.get("single_use_supervisor_authorization") is not True
        or attempt.get("source_worktree_clean") is not True
        or attempt.get("source_matches_live_github_main") is not True
        or attempt.get("content_addressed_inputs_retained") is not True
        or attempt.get("one_shot_attempt_unconsumed") is not True
        or Path(str(attempt.get("attempt_root", ""))).resolve()
        != attempt_root.resolve()
        or os.environ.get(STAGE_ID_ENV) != cell.stage_id
        or os.environ.get(CELL_ID_ENV) != cell.cell_id
        or os.environ.get(ENGINE_ID_ENV) != ENGINE_ID
    ):
        _fail("QSDK_R23D25_MJC_PHYSICAL_AUTHORIZATION_INVALID")
    return {"freeze": freeze, "attempt": attempt, "attempt_root": attempt_root}


for _name, _value in {
    "design": design,
    "evaluator": evaluator,
    "PREREGISTRATION_PATH": PREREGISTRATION_PATH,
    "IMPLEMENTATION_PATH": IMPLEMENTATION_PATH,
    "CLOSURE_PATH": CLOSURE_PATH,
    "CAMPAIGN_ID": CAMPAIGN_ID,
    "GATE_ID": GATE_ID,
    "ENGINE_ID": ENGINE_ID,
    "FREEZE_SCHEMA": FREEZE_SCHEMA,
    "ATTEMPT_SCHEMA": ATTEMPT_SCHEMA,
    "FAILURE_SCHEMA": FAILURE_SCHEMA,
    "REPORT_SCHEMA": REPORT_SCHEMA,
    "FREEZE_PATH_ENV": FREEZE_PATH_ENV,
    "ATTEMPT_PATH_ENV": ATTEMPT_PATH_ENV,
    "AUTHORIZATION_TOKEN_ENV": AUTHORIZATION_TOKEN_ENV,
    "STAGE_ID_ENV": STAGE_ID_ENV,
    "CELL_ID_ENV": CELL_ID_ENV,
    "ENGINE_ID_ENV": ENGINE_ID_ENV,
    "ATTEMPT_ROOT_ENV": ATTEMPT_ROOT_ENV,
    "POWERSHELL_ENV": POWERSHELL_ENV,
    "R23D13MujocoPhysicalError": R23D25MujocoPhysicalError,
    "_cell": _cell,
    "_contract": _contract,
    "physical_authorization": physical_authorization,
}.items():
    setattr(_core, _name, _value)


def worker_preflight(stage_id: str, arm_id: str) -> dict[str, Any]:
    cell = _cell(stage_id, arm_id)
    _contract()
    return {
        "schema_version": "sporespore_qsdk_r23d25_mujoco_worker_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": ENGINE_ID,
        "arm_id": cell.arm_id,
        "controller_policy_id": CONTROLLER_POLICY_ID,
        "source_forward_velocity_contract_id": SOURCE_CONTRACT_ID,
        "terminal_desired_forward_velocity_m_s": 0.0,
        "terminal_zero_forward_canary_count": 4,
        "terminal_zero_forward_mutation_control_count": 4,
        "physical_worker_implemented": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def run_physical(stage_id: str, arm_id: str, source_commit: str) -> dict[str, Any]:
    try:
        report = _core.run_physical(stage_id, arm_id, source_commit)
        measurements = report.get("measurements")
        if not isinstance(measurements, dict):
            _fail("QSDK_R23D25_MJC_MEASUREMENTS_MISSING")
        active_count = measurements.get("active_terminal_step_count")
        if (
            _terminal_audit["terminal_zero_forward_command_count"] != active_count
            or _terminal_audit["terminal_zero_forward_receipt_count"] != active_count
            or _terminal_audit["terminal_nonzero_forward_command_count"] != 0
            or _terminal_audit["terminal_forward_receipt_violation_count"] != 0
        ):
            _fail("QSDK_R23D25_MJC_TERMINAL_ZERO_FORWARD_AUDIT_MISMATCH")
        measurements.update(copy.deepcopy(_terminal_audit))
        return _translate(report)
    except R23D25MujocoPhysicalError as error:
        raise R23D25MujocoPhysicalError(
            str(_translate(error.code)),
            world_attempt_count=error.world_attempt_count,
            world_build_count=error.world_build_count,
            terminal_receipt=_translate(error.terminal_receipt),
        ) from error


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    for command in (commands.add_parser("preflight"), commands.add_parser("physical")):
        command.add_argument("--stage-id", required=True)
        command.add_argument("--arm-id", required=True)
        command.add_argument("--source-commit", default="")
    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "preflight":
            receipt = worker_preflight(arguments.stage_id, arguments.arm_id)
            marker = "QSDK_R23D25_MUJOCO_PREFLIGHT "
        else:
            receipt = run_physical(
                arguments.stage_id, arguments.arm_id, arguments.source_commit
            )
            marker = "QSDK_R23D25_TERMINAL "
        print(marker + json.dumps(receipt, allow_nan=False, separators=(",", ":")))
        return 0
    except R23D25MujocoPhysicalError as error:
        if error.terminal_receipt is not None:
            print(
                "QSDK_R23D25_TERMINAL "
                + json.dumps(error.terminal_receipt, allow_nan=False, separators=(",", ":"))
            )
        else:
            print("QSDK_R23D25_MUJOCO_FAILURE " + json.dumps({"failure_code": error.code}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
