"""One-shot classic-MuJoCo worker for QSDK-R23D24.

The real physical loop remains the qualified R23D13/R23D23 loop. This wrapper
changes only the campaign identity and opts the terminal composition into the
fully validated R23D21 forward-velocity receipt contract.
"""

from __future__ import annotations

import argparse
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

from . import qsdk_r23d23_physical as inherited
from . import qsdk_r23d23_postclosure_forward_receipt_compatibility as repair
from . import qsdk_r23d8_neutral_stance_composition as restoration

import r23d24_mujoco_receipt_recovery_evaluator as evaluator  # noqa: E402
import r23d24_mujoco_receipt_recovery_trace as design  # noqa: E402


_core = inherited._core
PREREGISTRATION_PATH = (
    TURNING_ROOT / "r23d24_mujoco_receipt_recovery_preregistration_v1.json"
)
IMPLEMENTATION_PATH = (
    TURNING_ROOT / "r23d24_mujoco_receipt_recovery_implementation_v1.json"
)
CLOSURE_PATH = TURNING_ROOT / "r23d24_mujoco_receipt_recovery_closure_v1.json"
CAMPAIGN_ID = design.CAMPAIGN_ID
GATE_ID = design.GATE_ID
ENGINE_ID = "mujoco"
CONTROLLER_POLICY_ID = design.CONTROLLER_POLICY_ID
SOURCE_CONTRACT_ID = restoration.R23D21_FORWARD_VELOCITY_SOURCE_CONTRACT_ID
FREEZE_SCHEMA = "sporespore_qsdk_r23d24_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d24_attempt_v1"
FAILURE_SCHEMA = evaluator.FAILURE_SCHEMA
REPORT_SCHEMA = evaluator.REPORT_SCHEMA
FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D24_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D24_ATTEMPT"
AUTHORIZATION_TOKEN_ENV = "SPORESPORE_QSDK_R23D24_TOKEN"
STAGE_ID_ENV = "SPORESPORE_QSDK_R23D24_STAGE"
CELL_ID_ENV = "SPORESPORE_QSDK_R23D24_CELL"
ENGINE_ID_ENV = "SPORESPORE_QSDK_R23D24_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D24_ATTEMPT_ROOT"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D24_POWERSHELL"


class R23D24MujocoPhysicalError(RuntimeError):
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
        return self._inherited.terminal_restoration_composition(*args, **kwargs)

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
        return value.replace("R23D13", "R23D24").replace(
            "QSDK-R23D13", "QSDK-R23D24"
        )
    if isinstance(value, list):
        return [_translate(item) for item in value]
    if isinstance(value, tuple):
        return tuple(_translate(item) for item in value)
    if isinstance(value, dict):
        return {key: _translate(item) for key, item in value.items()}
    return value


def _fail(code: str) -> None:
    raise R23D24MujocoPhysicalError(code)


def _cell(stage_id: str, arm_id: str) -> design.Cell:
    matches = [
        cell
        for cell in design.matrix_cells()
        if cell.stage_id == stage_id and cell.arm_id == arm_id
    ]
    if len(matches) != 1:
        _fail(f"QSDK_R23D24_MJC_CELL_IDENTITY_INVALID:{stage_id}:{arm_id}")
    return matches[0]


def _contract() -> dict[str, Any]:
    declaration = evaluator._load_declaration()
    receipt_preflight = repair.run_zero_world_preflight()
    native_canaries, native_mutations = inherited.native.run_zero_world_preflight()
    diagnostic = inherited.diagnostics.preflight()
    authority = inherited.authority_native.preflight()
    temporal = inherited.temporal_native.preflight()
    compiled, profile = _core.inherited.base._compile_boundary(LocomotionCore())
    if (
        receipt_preflight.get("status")
        != "zero_world_compatibility_repair_passed"
        or receipt_preflight.get("mutation_control_count") != 22
        or receipt_preflight.get("source_forward_velocity_contract_id")
        != SOURCE_CONTRACT_ID
        or receipt_preflight.get("historical_r23d8_default_preserved") is not True
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
        _fail("QSDK_R23D24_MJC_CONTRACT_IDENTITY_INVALID")
    return declaration


def physical_authorization(
    cell: design.Cell, source_commit: str
) -> dict[str, Any]:
    if CLOSURE_PATH.is_file():
        _fail("QSDK_R23D24_MJC_CLOSED")
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
        _fail("QSDK_R23D24_MJC_PHYSICAL_AUTHORIZATION_REQUIRED")
    freeze = _core._read_json(freeze_path, "QSDK_R23D24_MJC_FREEZE_UNREADABLE")
    attempt = _core._read_json(
        attempt_path, "QSDK_R23D24_MJC_ATTEMPT_UNREADABLE"
    )
    try:
        attempt_root.resolve().relative_to(
            (REPO_ROOT.parent / "SporeSpore_Evidence").resolve()
        )
    except ValueError as error:
        raise R23D24MujocoPhysicalError(
            "QSDK_R23D24_MJC_ATTEMPT_ROOT_NOT_DURABLE"
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
        _fail("QSDK_R23D24_MJC_PHYSICAL_AUTHORIZATION_INVALID")
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
    "R23D13MujocoPhysicalError": R23D24MujocoPhysicalError,
    "_cell": _cell,
    "_contract": _contract,
    "physical_authorization": physical_authorization,
}.items():
    setattr(_core, _name, _value)


def worker_preflight(stage_id: str, arm_id: str) -> dict[str, Any]:
    cell = _cell(stage_id, arm_id)
    _contract()
    return {
        "schema_version": "sporespore_qsdk_r23d24_mujoco_worker_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": ENGINE_ID,
        "arm_id": cell.arm_id,
        "controller_policy_id": CONTROLLER_POLICY_ID,
        "source_forward_velocity_contract_id": SOURCE_CONTRACT_ID,
        "physical_worker_implemented": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def run_physical(stage_id: str, arm_id: str, source_commit: str) -> dict[str, Any]:
    try:
        return _translate(_core.run_physical(stage_id, arm_id, source_commit))
    except R23D24MujocoPhysicalError as error:
        raise R23D24MujocoPhysicalError(
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
            marker = "QSDK_R23D24_MUJOCO_PREFLIGHT "
        else:
            receipt = run_physical(
                arguments.stage_id, arguments.arm_id, arguments.source_commit
            )
            marker = "QSDK_R23D24_TERMINAL "
        print(marker + json.dumps(receipt, allow_nan=False, separators=(",", ":")))
        return 0
    except R23D24MujocoPhysicalError as error:
        if error.terminal_receipt is not None:
            print(
                "QSDK_R23D24_TERMINAL "
                + json.dumps(error.terminal_receipt, allow_nan=False, separators=(",", ":"))
            )
        else:
            print("QSDK_R23D24_MUJOCO_FAILURE " + json.dumps({"failure_code": error.code}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
