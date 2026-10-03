"""One-shot classic-MuJoCo worker for the prospective QSDK-R23D34 matrix.

The real world loop is the already qualified fixed-horizon R23D3 worker.  This
module loads it privately, binds the unchanged R23D29 controller and its
policy-specific memory, and removes the unrelated post-horizon passive settle.
"""

from __future__ import annotations

import argparse
import copy
import importlib.util
import json
import os
from pathlib import Path
import sys
from types import ModuleType
from typing import Any, Sequence

from sporespore_locomotion import LocomotionCore


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from . import qsdk_r23d2_heading_response as inherited_base  # noqa: E402

import r23d34_native_r23d29_transfer as design  # noqa: E402
import r23d34_native_r23d29_transfer_evaluator as evaluator  # noqa: E402


def _load_private_worker() -> ModuleType:
    source = Path(__file__).with_name("qsdk_r23d3_phase_balanced.py")
    specification = importlib.util.spec_from_file_location(
        "sporespore_mujoco_adapter._qsdk_r23d34_fixed_horizon_core",
        source,
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("QSDK_R23D34_MJC_INHERITED_WORKER_UNAVAILABLE")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


_core = _load_private_worker()
# Retain the predecessor callable only for the zero-world regression control.
# The live physical entrypoint is rebound below and must never use this object.
INHERITED_PREFLIGHT_NEGATIVE_CONTROL = _core.run_preflight
PREREGISTRATION_PATH = TURNING_ROOT / "r23d34_native_r23d29_transfer_preregistration_v1.json"
IMPLEMENTATION_PATH = TURNING_ROOT / "r23d34_native_r23d29_transfer_implementation_v1.json"
CLOSURE_PATH = TURNING_ROOT / "r23d34_native_r23d29_transfer_closure_v1.json"
WORKER_PATH = Path(__file__).resolve()
FREEZE_SCHEMA = "sporespore_qsdk_r23d34_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d34_attempt_v1"
FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D34_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D34_ATTEMPT"
TOKEN_ENV = "SPORESPORE_QSDK_R23D34_TOKEN"
STAGE_ENV = "SPORESPORE_QSDK_R23D34_STAGE"
CELL_ENV = "SPORESPORE_QSDK_R23D34_CELL"
ENGINE_ENV = "SPORESPORE_QSDK_R23D34_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D34_ATTEMPT_ROOT"
PYTHON_ENV = "SPORESPORE_QSDK_R23D34_PYTHON"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D34_POWERSHELL"
ENGINE_ID = "mujoco"
REQUIRED_SOURCE_PATHS = (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d34_physical.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d3_phase_balanced.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d2_heading_response.py",
    "sdk/turning/r23d34_native_r23d29_transfer.py",
    "sdk/turning/r23d34_native_r23d29_transfer_evaluator.py",
    "sdk/turning/r23d34_native_r23d29_transfer_preregistration_v1.json",
    "sdk/turning/r23d34_native_r23d29_transfer_implementation_v1.json",
    "sdk/publish_qsdk_r23d34_trace.ps1",
    "sdk/python/sporespore_locomotion.py",
)


class _R23D34Core(LocomotionCore):
    """Make the inherited loop request memory for its explicitly bound policy."""

    def balanced_wave_initial_memory(self) -> dict[str, Any]:
        return self.balanced_wave_policy_initial_memory(
            design.POLICY_ID,
            inherited_base.bridge.s169_descriptor(),
        )


class _PolicyBoundBase:
    POLICY_ID = design.POLICY_ID
    CAMPAIGN_SEED = design.CAMPAIGN_SEED

    def __init__(self, base: ModuleType) -> None:
        self._base = base

    def __getattr__(self, name: str) -> Any:
        return getattr(self._base, name)

    def _compile_boundary(self, core: LocomotionCore) -> tuple[dict[str, Any], dict[str, Any]]:
        return self._base._compile_boundary(core, policy_id=design.POLICY_ID)

    def _initial_perturbation(self, _development: dict[str, Any]) -> dict[str, Any]:
        return copy.deepcopy(design.INITIAL_PERTURBATION)


_bound_base = _PolicyBoundBase(inherited_base)


def _cell(stage_id: str, onset_id: str, arm_id: str) -> design.Cell:
    if onset_id != "onset_600":
        raise _core.R23D3MujocoError(
            f"QSDK_R23D34_MJC_ONSET_INVALID:{onset_id}"
        )
    try:
        return design.cell(stage_id, ENGINE_ID, arm_id)
    except ValueError as error:
        raise _core.R23D3MujocoError(str(error)) from error


def _contract() -> dict[str, Any]:
    declaration = evaluator.load_declaration()
    if CLOSURE_PATH.is_file():
        raise _core.R23D3MujocoError("QSDK_R23D34_MJC_CLOSED")
    return declaration


def _source_bindings_exact(freeze: dict[str, Any]) -> bool:
    bindings = freeze.get("source_bindings")
    if not isinstance(bindings, list):
        return False
    observed = {
        str(item.get("path")): str(item.get("raw_sha256"))
        for item in bindings
        if isinstance(item, dict)
    }
    return all(
        observed.get(relative) == evaluator.raw_sha256(REPO_ROOT / relative)
        for relative in REQUIRED_SOURCE_PATHS
    )


def _physical_authorization(item: design.Cell, source_commit: str) -> dict[str, Any]:
    freeze_path = Path(os.environ.get(FREEZE_PATH_ENV, ""))
    attempt_path = Path(os.environ.get(ATTEMPT_PATH_ENV, ""))
    attempt_root = Path(os.environ.get(ATTEMPT_ROOT_ENV, ""))
    token = os.environ.get(TOKEN_ENV, "")
    if (
        not freeze_path.is_file()
        or not attempt_path.is_file()
        or not attempt_root.is_dir()
        or not _core._valid_lower_hex(token, 32)
    ):
        raise _core.R23D3MujocoError("QSDK_R23D34_MJC_AUTHORIZATION_REQUIRED")
    freeze = _core._read_json(freeze_path, "QSDK_R23D34_MJC_FREEZE_UNREADABLE")
    attempt = _core._read_json(attempt_path, "QSDK_R23D34_MJC_ATTEMPT_UNREADABLE")
    try:
        attempt_root.resolve().relative_to((REPO_ROOT.parent / "SporeSpore_Evidence").resolve())
    except ValueError as error:
        raise _core.R23D3MujocoError("QSDK_R23D34_MJC_ATTEMPT_ROOT_NOT_DURABLE") from error
    invalid = (
        freeze.get("schema_version") != FREEZE_SCHEMA
        or freeze.get("campaign_id") != design.CAMPAIGN_ID
        or freeze.get("gate_id") != design.GATE_ID
        or freeze.get("status") != "frozen_supervisor_only_physical_authorized"
        or freeze.get("source_commit") != source_commit
        or freeze.get("preregistration_raw_sha256") != evaluator.raw_sha256(PREREGISTRATION_PATH)
        or freeze.get("implementation_contract_raw_sha256") != evaluator.raw_sha256(IMPLEMENTATION_PATH)
        or freeze.get("physical_execution_authorized") is not True
        or not _source_bindings_exact(freeze)
        or attempt.get("schema_version") != ATTEMPT_SCHEMA
        or attempt.get("campaign_id") != design.CAMPAIGN_ID
        or attempt.get("gate_id") != design.GATE_ID
        or attempt.get("source_commit") != source_commit
        or attempt.get("freeze_raw_sha256") != evaluator.raw_sha256(freeze_path)
        or attempt.get("authorization_token") != token
        or attempt.get("ordered_matrix_cell_ids") != [cell.cell_id for cell in design.cells()]
        or attempt.get("physical_execution_authorized") is not True
        or attempt.get("single_use_supervisor_authorization") is not True
        or attempt.get("source_worktree_clean") is not True
        or attempt.get("source_matches_live_github_main") is not True
        or attempt.get("operation_lock_held") is not True
        or attempt.get("campaign_attestation_adoption_valid") is not True
        or attempt.get("content_addressed_inputs_retained") is not True
        or attempt.get("one_shot_attempt_unconsumed") is not True
        or Path(str(attempt.get("attempt_root", ""))).resolve() != attempt_root.resolve()
        or os.environ.get(STAGE_ENV) != item.stage_id
        or os.environ.get(CELL_ENV) != item.cell_id
        or os.environ.get(ENGINE_ENV) != ENGINE_ID
    )
    if invalid:
        raise _core.R23D3MujocoError("QSDK_R23D34_MJC_AUTHORIZATION_INVALID")
    return {"freeze": freeze, "attempt": attempt, "attempt_root": attempt_root}


def _retain_trace(
    item: design.Cell,
    rows: list[dict[str, Any]],
    attempt_root: Path,
) -> dict[str, Any]:
    pending = attempt_root / "pending-traces"
    pending.mkdir(parents=True, exist_ok=True)
    rows_path = pending / f"{item.cell_id}.rows.json"
    with rows_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(rows, stream, allow_nan=False, separators=(",", ":"), sort_keys=True)
        stream.write("\n")
    return evaluator.retain_trace(
        stage_id=item.stage_id,
        cell_id=item.cell_id,
        rows_json_path=rows_path,
        repo_root=REPO_ROOT,
        attempt_root=attempt_root,
        powershell=os.environ.get(POWERSHELL_ENV, "pwsh"),
    )


def run_preflight(stage_id: str, onset_id: str, arm_id: str) -> dict[str, Any]:
    _contract()
    item = _cell(stage_id, onset_id, arm_id)
    schedule = [design.segment_for_step(item, step) for step in range(design.CONTROLLER_STEPS)]
    core = _R23D34Core()
    compiled, profile = _bound_base._compile_boundary(core)
    memory = core.balanced_wave_initial_memory()
    legacy = core._call_no_input("ss_balanced_wave_initial_memory_json")
    if (
        compiled.get("morphology_id") != design.MORPHOLOGY_ID
        or profile.get("policy_id") != design.POLICY_ID
        or memory.get("schema_version")
        != "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
        or memory.get("steering_guard_floor_hold_steps_remaining") != 0
        or legacy.get("schema_version") != "sporespore_balanced_wave_memory_v1"
        or len(schedule) != design.CONTROLLER_STEPS
    ):
        raise _core.R23D3MujocoError("QSDK_R23D34_MJC_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d34_mujoco_worker_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "engine_id": ENGINE_ID,
        "stage_id": item.stage_id,
        "cell_id": item.cell_id,
        "arm_id": item.arm_id,
        "controller_policy_id": design.POLICY_ID,
        "controller_memory_schema": memory["schema_version"],
        "legacy_memory_schema": legacy["schema_version"],
        "fixed_controller_horizon_step_count": design.CONTROLLER_STEPS,
        "terminal_restoration_or_taper_invoked": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


for name, value in {
    "design": design,
    "evaluator": evaluator,
    "base": _bound_base,
    "LocomotionCore": _R23D34Core,
    "PREREGISTRATION_PATH": PREREGISTRATION_PATH,
    "PHYSICAL_EVALUATOR_PATH": evaluator.__file__,
    "CLOSURE_PATH": CLOSURE_PATH,
    "WORKER_PATH": WORKER_PATH,
    "CAMPAIGN_ID": design.CAMPAIGN_ID,
    "GATE_ID": design.GATE_ID,
    "REPORT_SCHEMA": evaluator.REPORT_SCHEMA,
    "FAILURE_SCHEMA": evaluator.FAILURE_SCHEMA,
    "FREEZE_SCHEMA": FREEZE_SCHEMA,
    "ATTEMPT_SCHEMA": ATTEMPT_SCHEMA,
    "SCHEDULE_ID": "qsdk_r23d34_onset600_turn_return_v1",
    "CONTROLLER_STEPS": design.CONTROLLER_STEPS,
    "ACTUATOR_COUNT": design.ACTUATOR_COUNT,
    "TURN_DURATION_STEPS": design.TURN_DURATION_STEPS,
    "TERMINAL_SETTLE_STEPS": 0,
    "FREEZE_PATH_ENV": FREEZE_PATH_ENV,
    "ATTEMPT_PATH_ENV": ATTEMPT_PATH_ENV,
    "AUTHORIZATION_TOKEN_ENV": TOKEN_ENV,
    "STAGE_ID_ENV": STAGE_ENV,
    "CELL_ID_ENV": CELL_ENV,
    "ENGINE_ID_ENV": ENGINE_ENV,
    "ATTEMPT_ROOT_ENV": ATTEMPT_ROOT_ENV,
    "PYTHON_ENV": PYTHON_ENV,
    "POWERSHELL_ENV": POWERSHELL_ENV,
    "_cell": _cell,
    "_contract": _contract,
    "_source_bindings_exact": _source_bindings_exact,
    "_physical_authorization": _physical_authorization,
    "_retain_trace": _retain_trace,
    # The inherited physical loop resolves this name from its private module
    # globals.  Bind the wrapper preflight explicitly so the physical entrypoint
    # traverses the same generated-schedule gate that direct preflight uses.
    "run_preflight": run_preflight,
}.items():
    setattr(_core, name, value)


def run_physical(stage_id: str, onset_id: str, arm_id: str, source_commit: str) -> dict[str, Any]:
    return _core.run_physical(stage_id, onset_id, arm_id, source_commit)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("preflight", "physical"))
    parser.add_argument("--stage", required=True)
    parser.add_argument("--onset", default="onset_600")
    parser.add_argument("--arm", required=True)
    parser.add_argument("--source-commit", default="")
    args = parser.parse_args(argv)
    try:
        if args.command == "preflight":
            value = run_preflight(args.stage, args.onset, args.arm)
            marker = "QSDK_R23D34_MUJOCO_PREFLIGHT "
        else:
            value = run_physical(args.stage, args.onset, args.arm, args.source_commit)
            marker = "QSDK_R23D34_MUJOCO_TERMINAL "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except _core.R23D3MujocoError as error:
        value = error.terminal_receipt or {"failure_code": error.code}
        print(
            "QSDK_R23D34_MUJOCO_TERMINAL "
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
