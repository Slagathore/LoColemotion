"""MuJoCo binding of the shared full-horizon turning kernel for R23D70.

The native model, controller loop, public-profile mapping, startup transform,
task-origin logic, and trace construction remain in the accepted R23D65
production module.  This process-local adapter changes only the prospectively
frozen campaign identity, seed, schedule labels, authorization documents, and
evaluator endpoint.  Preflight and authorization controls construct no
``MjModel`` or ``MjData``.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, Mapping, Sequence

from . import qsdk_r23d65_selected_profile_turning as production


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

import r23d70_production_route_runtime as design  # noqa: E402
import r23d70_production_route_three_engine_turning_evaluator as evaluator  # noqa: E402
from r23d70_receipt_contract import validate_retention_receipt  # noqa: E402


WORKER_PATH = Path(__file__).resolve()
PREREGISTRATION_PATH = design.DECLARATION_PATH
IMPLEMENTATION_PATH = (
    TURNING_ROOT
    / "r23d70_production_route_three_engine_turning_implementation_v1.json"
)
EVALUATOR_PATH = (
    TURNING_ROOT
    / "r23d70_production_route_three_engine_turning_evaluator.py"
)
CLOSURE_PATH = (
    TURNING_ROOT
    / "r23d70_production_route_three_engine_turning_validation_closure_v1.json"
)

CAMPAIGN_ID = design.CAMPAIGN_ID
GATE_ID = design.GATE_ID
STAGE_ID = design.STAGE_ID
ENGINE_ID = "mujoco"
ONSET_ID = "onset_600"
CAMPAIGN_SEED = design.CAMPAIGN_SEED
PROFILE_ID = design.PROFILE_ID
PROFILE_SHA256 = design.PROFILE_SHA256
HOST_MAPPING_ID = design.HOST_MAPPING_IDS[ENGINE_ID]
POLICY_ID = design.POLICY_ID
TASK_ORIGIN_POLICY_ID = design.TASK_ORIGIN_POLICY_ID

PREFLIGHT_SCHEMA = "sporespore_qsdk_r23d70_mujoco_worker_preflight_v1"
AUTHORIZATION_SCHEMA = "sporespore_qsdk_r23d70_mujoco_authorization_v1"
REPORT_SCHEMA = evaluator.REPORT_SCHEMA
FAILURE_SCHEMA = evaluator.FAILURE_SCHEMA
TRACE_RETENTION_SCHEMA = evaluator.TRACE_RETENTION_SCHEMA
TRACE_ROW_SCHEMA = evaluator.TRACE_ROW_SCHEMA
FREEZE_SCHEMA = "sporespore_qsdk_r23d70_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d70_physical_attempt_v1"

FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D70_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D70_ATTEMPT"
TOKEN_ENV = "SPORESPORE_QSDK_R23D70_TOKEN"
STAGE_ENV = "SPORESPORE_QSDK_R23D70_STAGE"
CELL_ENV = "SPORESPORE_QSDK_R23D70_CELL"
ENGINE_ENV = "SPORESPORE_QSDK_R23D70_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D70_ATTEMPT_ROOT"
AUTHORITY_REPO_ROOT_ENV = "SPORESPORE_QSDK_R23D70_AUTHORITY_REPO_ROOT"
PYTHON_ENV = "SPORESPORE_QSDK_R23D70_PYTHON"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D70_POWERSHELL"

FALSE_CLAIMS = copy.deepcopy(evaluator.FALSE_CLAIMS)


def _raw_sha256(path: Path) -> str:
    return design.raw_sha256(path)


def _read_json(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise production._core.R23D3MujocoError(
            f"{code}:{type(error).__name__}"
        ) from error
    if not isinstance(value, dict):
        raise production._core.R23D3MujocoError(code)
    return value


def _valid_lower_hex(value: Any, length: int) -> bool:
    return (
        isinstance(value, str)
        and len(value) == length
        and all(character in "0123456789abcdef" for character in value)
    )


def _expected_cell_ids() -> list[str]:
    return [item.cell_id for item in design.cells()]


def _segment_for_step(
    item: production._Cell,
    semantic_step: int,
) -> tuple[str, float]:
    selected = design.cell(item.engine_id, item.arm_id)
    return design.segment_for_step(selected, semantic_step)


def _expected_segment_counts(
    _item: production._Cell | None = None,
) -> dict[str, int]:
    return design.expected_segment_counts()


def _implementation_contract() -> dict[str, Any]:
    design.validate_runtime_projection()
    if CLOSURE_PATH.is_file():
        raise production._core.R23D3MujocoError("QSDK_R23D70_MJC_CLOSED")
    value = _read_json(
        IMPLEMENTATION_PATH,
        "QSDK_R23D70_MJC_IMPLEMENTATION_UNREADABLE",
    )
    worker = value.get("workers", {}).get(ENGINE_ID, {})
    exact = (
        value.get("schema_version")
        == "sporespore_qsdk_r23d70_production_route_three_engine_turning_implementation_v1"
        and value.get("status")
        == (
            "implementation_complete_complete_zero_world_gate_passed_"
            "physical_not_authorized"
        )
        and value.get("campaign_id") == CAMPAIGN_ID
        and value.get("gate_id") == GATE_ID
        and value.get("question_class") == "finite_decision"
        and value.get("preregistration_path")
        == PREREGISTRATION_PATH.relative_to(REPO_ROOT).as_posix()
        and value.get("preregistration_raw_sha256")
        == _raw_sha256(PREREGISTRATION_PATH)
        and value.get("declared_cell_count") == 9
        and value.get("declared_world_count") == 9
        and value.get("ordered_cell_ids") == _expected_cell_ids()
        and isinstance(worker, dict)
        and worker.get("path") == WORKER_PATH.relative_to(REPO_ROOT).as_posix()
        and worker.get("raw_sha256") == _raw_sha256(WORKER_PATH)
        and worker.get("shared_native_kernel_path")
        == (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d65_selected_profile_turning.py"
        )
        and worker.get("shared_native_kernel_reused") is True
        and worker.get("implementation_complete") is True
        and value.get("claims", {}).get("implementation_complete") is True
        and value.get("claims", {}).get("complete_zero_world_gate_passed")
        is True
        and value.get("claims", {}).get("physical_campaign_opened") is False
        and value.get("claims", {}).get("q_sdk_r23_satisfied") is False
        and value.get("claims", {}).get("release_authorized") is False
    )
    if not exact:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D70_MJC_IMPLEMENTATION_IDENTITY_INVALID"
        )
    return value


def _dependencies_exact(implementation: Mapping[str, Any]) -> bool:
    values = implementation.get("dependency_digests", {})
    return (
        isinstance(values, dict)
        and len(values) > 0
        and all(
            isinstance(relative, str)
            and relative
            and isinstance(digest, str)
            and (REPO_ROOT / relative).is_file()
            and _raw_sha256(REPO_ROOT / relative) == digest
            for relative, digest in values.items()
        )
    )


def _same_path(value: Any, expected: Path) -> bool:
    if not isinstance(value, str) or not value:
        return False
    try:
        return Path(value).resolve(strict=True) == expected.resolve(strict=True)
    except OSError:
        return False


def _physical_authorization(
    item: production._Cell,
    source_commit: str,
) -> dict[str, Any]:
    implementation = _implementation_contract()
    freeze_path = Path(os.environ.get(FREEZE_PATH_ENV, ""))
    attempt_path = Path(os.environ.get(ATTEMPT_PATH_ENV, ""))
    attempt_root = Path(os.environ.get(ATTEMPT_ROOT_ENV, ""))
    authority_raw = os.environ.get(AUTHORITY_REPO_ROOT_ENV, "")
    token = os.environ.get(TOKEN_ENV, "")
    if (
        not freeze_path.is_file()
        or not attempt_path.is_file()
        or not attempt_root.is_dir()
        or not authority_raw
        or not _valid_lower_hex(token, 32)
        or not _valid_lower_hex(source_commit, 40)
    ):
        raise production._core.R23D3MujocoError(
            "QSDK_R23D70_MJC_PHYSICAL_AUTHORIZATION_REQUIRED"
        )
    try:
        authority_root = Path(authority_raw).resolve(strict=True)
        canonical_attempt_root = attempt_root.resolve(strict=True)
        evidence_root = (authority_root.parent / "SporeSpore_Evidence").resolve(
            strict=True
        )
        canonical_attempt_root.relative_to(evidence_root)
    except (OSError, ValueError) as error:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D70_MJC_AUTHORIZATION_PATH_INVALID"
        ) from error
    freeze = _read_json(freeze_path, "QSDK_R23D70_MJC_FREEZE_UNREADABLE")
    attempt = _read_json(attempt_path, "QSDK_R23D70_MJC_ATTEMPT_UNREADABLE")
    environment_key = freeze.get("dependency_toolchain_environment_key")
    exact = (
        authority_root == REPO_ROOT.resolve(strict=True)
        and item.cell_id in _expected_cell_ids()
        and freeze.get("schema_version") == FREEZE_SCHEMA
        and freeze.get("status") == "frozen_supervisor_only_physical_authorized"
        and freeze.get("campaign_id") == CAMPAIGN_ID
        and freeze.get("gate_id") == GATE_ID
        and freeze.get("preregistration_raw_sha256")
        == _raw_sha256(PREREGISTRATION_PATH)
        and freeze.get("implementation_contract_raw_sha256")
        == _raw_sha256(IMPLEMENTATION_PATH)
        and freeze.get("source_commit") == source_commit
        and freeze.get("origin_main_commit") == source_commit
        and freeze.get("live_github_main_commit") == source_commit
        and _valid_lower_hex(freeze.get("source_tree_git_oid"), 40)
        and freeze.get("source_worktree_clean") is True
        and freeze.get("complete_zero_world_gate_passed") is True
        and freeze.get("implementation_dependency_digests")
        == implementation.get("dependency_digests")
        and _dependencies_exact(implementation)
        and _valid_lower_hex(environment_key, 64)
        and freeze.get("declared_world_count") == 9
        and freeze.get("ordered_cell_ids") == _expected_cell_ids()
        and freeze.get("serial_execution_required") is True
        and freeze.get("all_cells_run_regardless_of_intermediate_outcome") is True
        and freeze.get("physical_behavior_thresholds_applied") is True
        and freeze.get("physical_execution_authorized") is True
        and freeze.get("physical_acceptance_authority") is False
        and attempt.get("schema_version") == ATTEMPT_SCHEMA
        and attempt.get("campaign_id") == CAMPAIGN_ID
        and attempt.get("gate_id") == GATE_ID
        and attempt.get("source_commit") == source_commit
        and attempt.get("freeze_raw_sha256") == _raw_sha256(freeze_path)
        and attempt.get("authorization_token") == token
        and _valid_lower_hex(attempt.get("attempt_id"), 32)
        and attempt.get("dependency_toolchain_environment_key") == environment_key
        and attempt.get("ordered_cell_ids") == _expected_cell_ids()
        and attempt.get("single_use_supervisor_authorization") is True
        and attempt.get("operation_lock_held") is True
        and attempt.get("one_shot_attempt_unconsumed") is True
        and attempt.get("physical_execution_authorized") is True
        and attempt.get("physical_acceptance_authority") is False
        and _same_path(attempt.get("attempt_root"), canonical_attempt_root)
        and _same_path(attempt.get("authority_repo_root"), authority_root)
        and os.environ.get(STAGE_ENV) == item.stage_id
        and os.environ.get(CELL_ENV) == item.cell_id
        and os.environ.get(ENGINE_ENV) == ENGINE_ID
    )
    if not exact:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D70_MJC_PHYSICAL_AUTHORIZATION_INVALID"
        )
    return {
        "freeze": freeze,
        "attempt": attempt,
        "attempt_root": canonical_attempt_root,
    }


def _retain_trace(
    item: production._Cell,
    rows: list[dict[str, Any]],
    attempt_root: Path,
) -> dict[str, Any]:
    pending_root = attempt_root / "pending-traces"
    pending_root.mkdir(parents=True, exist_ok=True)
    rows_path = pending_root / f"{item.stage_id}__{item.cell_id}.rows.json"
    with rows_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(
            rows,
            stream,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
        stream.write("\n")
    process = subprocess.run(
        [
            os.environ.get(PYTHON_ENV, sys.executable),
            str(EVALUATOR_PATH),
            "retain-trace",
            "--stage-id",
            item.stage_id,
            "--cell-id",
            item.cell_id,
            "--rows-json",
            str(rows_path),
            "--repo-root",
            str(REPO_ROOT),
            "--attempt-root",
            str(attempt_root),
            "--powershell",
            os.environ.get(POWERSHELL_ENV, "pwsh"),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        check=False,
        text=True,
        timeout=240,
    )
    marker = "QSDK_R23D70_TRACE_RETAINED "
    matches = [
        line.removeprefix(marker)
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D70_MJC_TRACE_RETENTION_FAILED:"
            f"{process.returncode}:{process.stderr[-1000:]}",
            world_attempt_count=1,
            world_build_count=1,
        )
    receipt = json.loads(matches[0])
    failures = validate_retention_receipt(
        receipt,
        expected_schema=TRACE_RETENTION_SCHEMA,
        expected_stage_id=item.stage_id,
        expected_cell_id=item.cell_id,
        expected_engine_id=ENGINE_ID,
        expected_campaign_seed=CAMPAIGN_SEED,
        expected_profile_id=PROFILE_ID,
        expected_host_mapping_id=HOST_MAPPING_ID,
        expected_row_count=design.CONTROLLER_STEPS,
        expected_test_only=False,
    )
    if failures:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D70_MJC_TRACE_RETENTION_RECEIPT_INVALID:"
            + ",".join(failures),
            world_attempt_count=1,
            world_build_count=1,
        )
    return receipt


def _configure_shared_kernel() -> None:
    production.public_design = design
    production.evaluator = evaluator
    production.CAMPAIGN_ID = CAMPAIGN_ID
    production.GATE_ID = GATE_ID
    production.STAGE_ID = STAGE_ID
    production.CAMPAIGN_SEED = CAMPAIGN_SEED
    production.POLICY_ID = POLICY_ID
    production.TASK_ORIGIN_POLICY_ID = TASK_ORIGIN_POLICY_ID
    production.TRACE_TRANSPORT_ID = evaluator.TRACE_TRANSPORT_ID
    production.PREFLIGHT_SCHEMA = PREFLIGHT_SCHEMA
    production.AUTHORIZATION_PREFLIGHT_SCHEMA = AUTHORIZATION_SCHEMA
    production.REPORT_SCHEMA = REPORT_SCHEMA
    production.FAILURE_SCHEMA = FAILURE_SCHEMA
    production.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
    production.TRACE_ROW_SCHEMA = TRACE_ROW_SCHEMA
    production.PREREGISTRATION_PATH = PREREGISTRATION_PATH
    production.IMPLEMENTATION_PATH = IMPLEMENTATION_PATH
    production.CLOSURE_PATH = CLOSURE_PATH
    production.EVALUATOR_PATH = EVALUATOR_PATH
    production.WORKER_PATH = WORKER_PATH
    production.FREEZE_SCHEMA = FREEZE_SCHEMA
    production.ATTEMPT_SCHEMA = ATTEMPT_SCHEMA
    production.FREEZE_PATH_ENV = FREEZE_PATH_ENV
    production.ATTEMPT_PATH_ENV = ATTEMPT_PATH_ENV
    production.TOKEN_ENV = TOKEN_ENV
    production.STAGE_ENV = STAGE_ENV
    production.CELL_ENV = CELL_ENV
    production.ENGINE_ENV = ENGINE_ENV
    production.ATTEMPT_ROOT_ENV = ATTEMPT_ROOT_ENV
    production.AUTHORITY_REPO_ROOT_ENV = AUTHORITY_REPO_ROOT_ENV
    production.PYTHON_ENV = PYTHON_ENV
    production.POWERSHELL_ENV = POWERSHELL_ENV
    production.EXPECTED_REANCHOR_STEPS = (600, 1_800, 2_400)
    production._segment_for_step = _segment_for_step
    production._expected_segment_counts = _expected_segment_counts
    production._contract = _implementation_contract
    production._physical_authorization = _physical_authorization
    production._retain_trace = _retain_trace

    production._design.CAMPAIGN_ID = CAMPAIGN_ID
    production._design.GATE_ID = GATE_ID
    production._design.CONTROLLER_STEPS = design.CONTROLLER_STEPS
    production._design.TURN_DURATION_STEPS = (
        design.TURN_END_STEP_EXCLUSIVE - design.TURN_START_STEP
    )
    production._design.TRACE_ROW_SCHEMA = TRACE_ROW_SCHEMA
    production._design.segment_for_step = _segment_for_step
    production._design.expected_segment_counts = _expected_segment_counts
    production._evaluator.REPORT_SCHEMA = REPORT_SCHEMA
    production._evaluator.FAILURE_SCHEMA = FAILURE_SCHEMA
    production._evaluator.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
    production._evaluator.FALSE_CLAIMS = FALSE_CLAIMS
    production._bound_base.CAMPAIGN_SEED = CAMPAIGN_SEED

    bindings = {
        "design": production._design,
        "evaluator": production._evaluator,
        "base": production._bound_base,
        "PREREGISTRATION_PATH": PREREGISTRATION_PATH,
        "PHYSICAL_EVALUATOR_PATH": EVALUATOR_PATH,
        "CLOSURE_PATH": CLOSURE_PATH,
        "WORKER_PATH": WORKER_PATH,
        "CAMPAIGN_ID": CAMPAIGN_ID,
        "GATE_ID": GATE_ID,
        "REPORT_SCHEMA": REPORT_SCHEMA,
        "FAILURE_SCHEMA": FAILURE_SCHEMA,
        "FREEZE_SCHEMA": FREEZE_SCHEMA,
        "ATTEMPT_SCHEMA": ATTEMPT_SCHEMA,
        "SCHEDULE_ID": "qsdk_r23d70_selected_profile_turn_return_v1",
        "CONTROLLER_STEPS": design.CONTROLLER_STEPS,
        "ACTUATOR_COUNT": design.ACTUATOR_COUNT,
        "TURN_DURATION_STEPS": (
            design.TURN_END_STEP_EXCLUSIVE - design.TURN_START_STEP
        ),
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
        "_contract": _implementation_contract,
        "_physical_authorization": _physical_authorization,
        "_retain_trace": _retain_trace,
        "run_preflight": production._inherited_physical_entry_preflight_bridge,
    }
    for name, value in bindings.items():
        setattr(production._core, name, value)
    production._core._trace_row = production._trace_row


def _arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("preflight", "authorization-preflight", "physical"),
    )
    parser.add_argument("--stage", required=True)
    parser.add_argument("--onset", required=True)
    parser.add_argument("--campaign-seed", required=True, type=int)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--arm", required=True)
    parser.add_argument("--source-commit", default="")
    return parser.parse_args(argv)


def _failure_terminal(
    code: str,
    arguments: argparse.Namespace,
) -> dict[str, Any]:
    arm_offsets = dict(design.ARMS)
    exact_arm = arguments.arm in arm_offsets
    selected = (
        design.cell(ENGINE_ID, arguments.arm) if exact_arm else None
    )
    return {
        "schema_version": FAILURE_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": "finite_decision",
        "stage_id": arguments.stage,
        "cell_id": selected.cell_id if selected is not None else None,
        "engine_id": ENGINE_ID,
        "campaign_seed": arguments.campaign_seed,
        "profile_id": arguments.profile,
        "host_mapping_id": HOST_MAPPING_ID,
        "arm_id": arguments.arm,
        "turn_heading_offset_rad": arm_offsets.get(arguments.arm),
        "source_commit": arguments.source_commit,
        "failure_stage": "before_world",
        "failure_code": code,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "claims": copy.deepcopy(FALSE_CLAIMS),
        "physical_acceptance_authority": False,
    }


def _project_failure_terminal(
    error: BaseException,
    arguments: argparse.Namespace,
) -> dict[str, Any]:
    if isinstance(error, production._core.R23D3MujocoError):
        if isinstance(error.terminal_receipt, dict):
            terminal = copy.deepcopy(error.terminal_receipt)
        else:
            terminal = _failure_terminal(error.code, arguments)
        inner_failure_code = str(terminal.get("failure_code", error.code))
        terminal["failure_code"] = (
            f"QSDK_R23D70_MJC_WORKER_FAILURE:{type(error).__name__}:"
            f"{inner_failure_code}"
        )
        terminal.setdefault("model_construction_count", error.world_build_count)
        terminal.setdefault("world_attempt_count", error.world_attempt_count)
        terminal.setdefault("world_build_count", error.world_build_count)
    else:
        terminal = _failure_terminal(
            f"QSDK_R23D70_MJC_WORKER_FAILURE:{type(error).__name__}:{error}",
            arguments,
        )
    arm_offsets = dict(design.ARMS)
    selected = design.cell(ENGINE_ID, arguments.arm) if arguments.arm in arm_offsets else None
    terminal.update(
        schema_version=FAILURE_SCHEMA,
        campaign_id=CAMPAIGN_ID,
        gate_id=GATE_ID,
        question_class="finite_decision",
        stage_id=arguments.stage,
        cell_id=selected.cell_id if selected is not None else None,
        engine_id=ENGINE_ID,
        campaign_seed=arguments.campaign_seed,
        profile_id=arguments.profile,
        host_mapping_id=HOST_MAPPING_ID,
        arm_id=arguments.arm,
        turn_heading_offset_rad=arm_offsets.get(arguments.arm),
        source_commit=arguments.source_commit,
        claims=copy.deepcopy(FALSE_CLAIMS),
        physical_acceptance_authority=False,
    )
    terminal.setdefault("failure_stage", "before_world")
    terminal.setdefault("model_construction_count", 0)
    terminal.setdefault("world_attempt_count", 0)
    terminal.setdefault("world_build_count", 0)
    json.dumps(terminal, allow_nan=False)
    return terminal


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(argv)
    _configure_shared_kernel()
    try:
        if arguments.command == "preflight":
            value = production.run_preflight(
                arguments.stage,
                arguments.onset,
                arguments.campaign_seed,
                arguments.profile,
                arguments.arm,
            )
            marker = "QSDK_R23D70_MUJOCO_PREFLIGHT "
        elif arguments.command == "authorization-preflight":
            value = production.run_authorization_preflight(
                arguments.stage,
                arguments.onset,
                arguments.campaign_seed,
                arguments.profile,
                arguments.arm,
                arguments.source_commit,
            )
            # All three engines expose one exact common positive projection.
            # R23D66's MuJoCo producer omitted this field even though native
            # authorization passed; the common supervisor contract now makes
            # the Boolean explicit before any model or world can exist.
            value.update(
                ok=True,
                failure_code="",
                schema_version=AUTHORIZATION_SCHEMA,
                campaign_id=CAMPAIGN_ID,
                gate_id=GATE_ID,
                stage_id=STAGE_ID,
                cell_id=design.cell(ENGINE_ID, arguments.arm).cell_id,
                engine_id=ENGINE_ID,
                authorization_passed=True,
                returned_before_model=True,
                model_construction_count=0,
                world_attempt_count=0,
                world_build_count=0,
                physical_acceptance_authority=False,
            )
            marker = "QSDK_R23D70_MUJOCO_AUTHORIZATION "
        else:
            value = production.run_physical(
                arguments.stage,
                arguments.onset,
                arguments.campaign_seed,
                arguments.profile,
                arguments.arm,
                arguments.source_commit,
            )
            value.update(
                schema_version=REPORT_SCHEMA,
                campaign_id=CAMPAIGN_ID,
                gate_id=GATE_ID,
                stage_id=STAGE_ID,
                source_commit=arguments.source_commit,
                claims=copy.deepcopy(FALSE_CLAIMS),
                physical_acceptance_authority=False,
            )
            marker = "QSDK_R23D70_MUJOCO_TERMINAL "
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
        production._core.R23D3MujocoError,
        design.DeclarationError,
        KeyError,
        OSError,
        TypeError,
        ValueError,
    ) as error:
        value = _project_failure_terminal(error, arguments)
        print(
            "QSDK_R23D70_MUJOCO_FAILURE "
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 1



if __name__ == "__main__":
    raise SystemExit(main())
