"""R24D44 launcher-compatible continuation of the unchanged R43 question."""

from __future__ import annotations

import argparse
from copy import deepcopy
import json
from pathlib import Path
import shutil
import subprocess
import traceback
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import qsdk_r24d18_recovery_development_worker as shared
from . import qsdk_r24d43_exclusive_stance_completion_worker as r43

GATE_ID = "QSDK-R24D44"
CAMPAIGN_ID = "QSDK-R24D44-MUJOCO-EXCLUSIVE-STANCE-COMPLETION-LAUNCH-REPAIR"
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_contract_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_preflight_v1"
)
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_"
    "zero_world_receipt_v1"
)
TRACE_INVARIANTS_SCHEMA = (
    "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_"
    "trace_invariants_v1"
)
FULL_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_full_result_v1"
)
COMPACT_PROJECTION_SCHEMA = (
    "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_"
    "compact_projection_v1"
)
MANIFEST_SCHEMA = (
    "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_manifest_v1"
)
INVALID_SCHEMA = (
    "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_invalid_v1"
)
LAUNCHER_VALIDATION_SCHEMA = (
    "sporespore_shared_physical_launcher_contract_validation_v1"
)

EXPECTED_CELL_ID = r43.EXPECTED_CELL_ID
EXPECTED_SEED = r43.EXPECTED_SEED
EXPECTED_MAXIMUM_HORIZON_STEPS = r43.EXPECTED_MAXIMUM_HORIZON_STEPS
EXPECTED_PAIRED_ARM_COUNT = r43.EXPECTED_PAIRED_ARM_COUNT
EXPECTED_SOURCE_INVENTORY_COUNT = 52
EXPECTED_CONTROL_COUNT = 11
EXPECTED_FORCED_FAILURE_COUNT = 14

REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d44_stance_completion_launcher_compatibility_contract_v1.json"
)
R43_CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d43_exclusive_stance_completion_contract_v1.json"
)
R43_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/"
    "r24d43_exclusive_stance_completion_launch_invalid_closure_v1.json"
)
R43_CLOSURE_AUDIT_PATH = (
    REPO_ROOT
    / "tests/test_qsdk_r24d43_exclusive_stance_completion_launch_invalid_closure.py"
)
SHARED_PHYSICAL_RUNNER_PATH = (
    REPO_ROOT / "sdk/run_qsdk_r24d18_mujoco_native_recovery_development.ps1"
)
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
PHYSICAL_DIRECTORY_PREFIX = "qsdk-r24d44-mujoco-exclusive-stance-completion-"


class R24D44WorkerError(RuntimeError):
    """Stable fail-closed R24D44 worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D44WorkerError(code)


def load_contract_v1(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    """Load R44 while proving it changes only launcher-contract compatibility."""

    contract = shared._load_json(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "QUESTION_CLASS")
    _require(
        contract.get("physical_question_declared") is True
        and contract.get("behavior_question_declared") is True,
        "QUESTION_DECLARATION",
    )
    _require(
        contract.get("superiority_question_declared") is False
        and contract.get("equivalence_or_non_inferiority_question_declared") is False
        and contract.get("population_inference_declared") is False,
        "QUESTION_SCOPE",
    )

    lineage = contract["lineage"]
    _require(
        lineage["predecessor_gate_id"] == r43.GATE_ID
        and lineage["predecessor_source_commit"]
        == "53e624f3fc493e3096815ea6f4f978f382a3c9fc"
        and lineage["predecessor_contract_path"]
        == R43_CONTRACT_PATH.relative_to(REPO_ROOT).as_posix()
        and lineage["predecessor_launch_invalid_closure_path"]
        == R43_CLOSURE_PATH.relative_to(REPO_ROOT).as_posix()
        and lineage["predecessor_launch_invalid_closure_raw_sha256"]
        == shared._sha256_path(R43_CLOSURE_PATH)
        and lineage["predecessor_closure_audit_path"]
        == R43_CLOSURE_AUDIT_PATH.relative_to(REPO_ROOT).as_posix()
        and lineage["predecessor_closure_audit_raw_sha256"]
        == shared._sha256_path(R43_CLOSURE_AUDIT_PATH)
        and lineage["predecessor_official_qualification_passed"] is True
        and lineage["predecessor_physical_attempt_reserved"] is False
        and lineage["predecessor_model_world_and_solver_counts"] == 0
        and lineage["predecessor_result_is_immutable"] is True
        and lineage["predecessor_reinterpreted"] is False
        and lineage["predecessor_reopened"] is False
        and lineage["predecessor_may_rerun_or_requalify"] is False,
        "R43_LINEAGE",
    )
    r43_contract = shared._load_json(R43_CONTRACT_PATH)
    cell = contract["selected_development_cell"]
    predecessor_cell = r43_contract["selected_development_cell"]
    _require(
        {key: value for key, value in cell.items() if key != "selection_provenance"}
        == {
            key: value
            for key, value in predecessor_cell.items()
            if key != "selection_provenance"
        },
        "SELECTED_CELL_CHANGED",
    )
    horizon = contract["ghost_horizon"]
    predecessor_horizon = r43_contract["natural_stop_horizon"]
    _require(
        horizon["outer_steps_per_arm"]
        == horizon["maximum_steps_per_arm"]
        == predecessor_horizon["maximum_steps_per_arm"]
        == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon["paired_arm_count"]
        == predecessor_horizon["paired_arm_count"]
        == EXPECTED_PAIRED_ARM_COUNT
        and horizon["maximum_total_outer_steps"]
        == predecessor_horizon["maximum_total_outer_steps"]
        and horizon["maximum_total_native_solver_steps"]
        == predecessor_horizon["maximum_total_native_solver_steps"]
        and set(horizon["terminal_stop_phases"])
        == set(predecessor_horizon["terminal_stop_phases"]),
        "HORIZON_CHANGED",
    )
    held_out = contract["held_out_seal"]
    _require(
        held_out["held_out_cell_access_count"] == 0
        and held_out["held_out_selector_invocation_count"] == 0
        and held_out["held_out_cells_remain_sealed"] is True,
        "HELD_OUT_SEAL",
    )
    change = contract["prospective_change"]
    prohibited_changes = [
        key
        for key, value in change.items()
        if key.endswith("_changed") and value is not False
    ]
    _require(not prohibited_changes, "SCIENTIFIC_CHANGE")
    gate = contract["complete_zero_world_gate"]
    _require(
        gate["required_control_count"] == EXPECTED_CONTROL_COUNT
        and gate["required_forced_failure_count"] == EXPECTED_FORCED_FAILURE_COUNT
        and len(gate["controls"]) == EXPECTED_CONTROL_COUNT
        and len(gate["forced_failure_families"])
        == EXPECTED_FORCED_FAILURE_COUNT,
        "ZERO_WORLD_COUNTS",
    )
    _require(
        len(contract["source_inventory"]) == EXPECTED_SOURCE_INVENTORY_COUNT
        and len(set(contract["source_inventory"]))
        == EXPECTED_SOURCE_INVENTORY_COUNT,
        "SOURCE_INVENTORY",
    )
    return contract


def _launcher_arguments(mutation: str | None = None) -> list[str]:
    pwsh = shutil.which("pwsh")
    _require(pwsh is not None, "POWERSHELL_MISSING")
    arguments = [
        pwsh,
        "-NoProfile",
        "-File",
        str(SHARED_PHYSICAL_RUNNER_PATH),
        "-ContractValidationOnly",
        "-CoreBuildProfile",
        "release",
        "-GateId",
        GATE_ID,
        "-CampaignId",
        CAMPAIGN_ID,
        "-ContractRelativePath",
        CONTRACT_PATH.relative_to(REPO_ROOT).as_posix(),
        "-ContractSchema",
        CONTRACT_SCHEMA,
        "-ExpectedCellId",
        EXPECTED_CELL_ID,
        "-ExpectedSeed",
        str(EXPECTED_SEED),
        "-ExpectedHorizonSteps",
        str(EXPECTED_MAXIMUM_HORIZON_STEPS),
        "-ExpectedPairedArmCount",
        str(EXPECTED_PAIRED_ARM_COUNT),
    ]
    if mutation is not None:
        arguments.extend(["-ContractValidationMutation", mutation])
    return arguments


def _run_launcher_contract_controls() -> dict[str, Any]:
    before = sorted(path.name for path in EVIDENCE_ROOT.glob(f"{PHYSICAL_DIRECTORY_PREFIX}*"))
    positive = subprocess.run(
        _launcher_arguments(),
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    _require(positive.returncode == 0, "LAUNCHER_POSITIVE_EXIT")
    lines = [line for line in positive.stdout.splitlines() if line.strip()]
    _require(len(lines) == 1, "LAUNCHER_POSITIVE_OUTPUT")
    receipt = json.loads(lines[0])
    _require(
        receipt == {
            "schema_version": LAUNCHER_VALIDATION_SCHEMA,
            "ok": True,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "contract_path": CONTRACT_PATH.relative_to(REPO_ROOT).as_posix(),
            "contract_raw_sha256": shared._sha256_path(CONTRACT_PATH),
            "selected_cell_id": EXPECTED_CELL_ID,
            "selected_seed": EXPECTED_SEED,
            "horizon_steps_per_arm": EXPECTED_MAXIMUM_HORIZON_STEPS,
            "paired_arm_count": EXPECTED_PAIRED_ARM_COUNT,
            "held_out_cell_access_count": 0,
            "held_out_selector_invocation_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
        },
        "LAUNCHER_POSITIVE_RECEIPT",
    )
    failures: dict[str, bool] = {}
    for mutation in ("missing_ghost_horizon", "missing_held_out_seal"):
        result = subprocess.run(
            _launcher_arguments(mutation),
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        combined = result.stdout + result.stderr
        failures[mutation] = (
            result.returncode != 0
            and "QSDK_R24D18_CONTRACT_SELECTOR_INVALID" in combined
        )
    after = sorted(path.name for path in EVIDENCE_ROOT.glob(f"{PHYSICAL_DIRECTORY_PREFIX}*"))
    _require(before == after, "LAUNCHER_VALIDATION_WROTE_PHYSICAL_EVIDENCE")
    _require(all(failures.values()), "LAUNCHER_NEGATIVE_CONTROL")
    return {
        "positive_receipt": receipt,
        "forced_failures": failures,
        "physical_evidence_population_unchanged": True,
        "physical_evidence_directory_count_before": len(before),
        "physical_evidence_directory_count_after": len(after),
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    """Replay R43 mechanics and exercise the actual shared launcher selector."""

    contract = load_contract_v1()
    inherited = r43.run_zero_world_preflight(core)
    launcher = _run_launcher_contract_controls()
    controls = dict(inherited["exclusive_stance_completion_controls"])
    controls["physical_launcher_contract_validation_exact"] = (
        launcher["positive_receipt"]["ok"] is True
        and all(launcher["forced_failures"].values())
        and launcher["physical_evidence_population_unchanged"] is True
    )
    _require(
        set(controls) == set(contract["complete_zero_world_gate"]["controls"]),
        "CONTROL_SET",
    )
    _require(all(controls.values()), "CONTROL_FAILURE")
    forced_failure_count = (
        inherited["forced_failure_count"] + len(launcher["forced_failures"])
    )
    _require(len(controls) == EXPECTED_CONTROL_COUNT, "CONTROL_COUNT")
    _require(
        forced_failure_count == EXPECTED_FORCED_FAILURE_COUNT,
        "FORCED_FAILURE_COUNT",
    )
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "question_class": "non_physical_source_conformance",
            "control_count": len(controls),
            "controls_passed": sum(controls.values()),
            "forced_failure_count": forced_failure_count,
            "exclusive_stance_completion_controls": controls,
            "launcher_contract_validation": launcher,
            "inherited_r24d43_control_count": inherited["control_count"],
            "inherited_r24d43_forced_failure_count": inherited[
                "forced_failure_count"
            ],
            "development_integration_smoke_executed": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "exact_nominal_mujoco_prone_to_standing_observed": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    )
    return receipt


def compact_projection_v1(
    result: Mapping[str, Any], trace_invariants: Mapping[str, Any]
) -> dict[str, Any]:
    projection = r43.compact_projection_v1(result, trace_invariants)
    projection.update(
        {
            "schema_version": COMPACT_PROJECTION_SCHEMA,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "ledger_scope": {
                "subsystem": "recovery_stance_completion",
                "engine_scope": ["mujoco_native"],
                "authority_mode": "one_exact_paired_natural_stop_development_attempt",
                "question_class": "development",
            },
            "predecessor_gate_id": r43.GATE_ID,
            "launcher_schema_repair_only": True,
        }
    )
    projection["trace_invariants"] = deepcopy(trace_invariants)
    return projection


def run_and_publish_v1(
    *,
    core_library: Path,
    contract_path: Path,
    output_directory: Path,
    source_commit: str,
    qualification_receipt_path: Path,
    operation_lock_receipt_path: Path,
) -> dict[str, Any]:
    _require(output_directory.is_dir(), "OUTPUT_DIRECTORY")
    contract = load_contract_v1(contract_path)
    qualification = shared._load_json(qualification_receipt_path)
    operation_lock = shared._load_json(operation_lock_receipt_path)
    _require(
        qualification["schema_version"] == QUALIFICATION_RECEIPT_SCHEMA
        and qualification["gate_id"] == GATE_ID
        and qualification["ok"] is True
        and qualification["mode"] == "qualification"
        and qualification["source_commit"] == source_commit,
        "QUALIFICATION_RECEIPT",
    )
    _require(
        operation_lock["acquired"] is True
        and operation_lock["role"] == "physical"
        and operation_lock["test_only"] is False,
        "OPERATION_LOCK",
    )
    result, invariants = r43._run_route(core_library, contract)
    invariants = deepcopy(invariants)
    invariants["schema_version"] = TRACE_INVARIANTS_SCHEMA
    invariants["gate_id"] = GATE_ID
    projection = compact_projection_v1(result, invariants)
    envelope = {
        "schema_version": FULL_RESULT_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "ledger_scope": deepcopy(contract["ledger_scope"]),
        "source_commit": source_commit,
        "contract_path": contract_path.as_posix(),
        "contract_raw_sha256": shared._sha256_path(contract_path),
        "qualification_receipt_path": str(qualification_receipt_path),
        "qualification_receipt_raw_sha256": shared._sha256_path(
            qualification_receipt_path
        ),
        "operation_lock": operation_lock,
        "predecessor_gate_id": r43.GATE_ID,
        "result": result,
        "trace_invariants": invariants,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "repeatability_rate_claimed": False,
        "population_claimed": False,
        "cross_engine_recovery_claimed": False,
        "cross_engine_equivalence_claimed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    full_path = output_directory / "paired_full_result.json"
    full_sha256 = shared._write_json_exclusive(full_path, envelope)
    projection["source_commit"] = source_commit
    projection["full_result_path"] = full_path.name
    projection["full_result_raw_sha256"] = full_sha256
    summary_path = output_directory / "paired_summary.json"
    summary_sha256 = shared._write_json_exclusive(summary_path, projection)
    manifest = {
        "schema_version": MANIFEST_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "artifacts": [
            {
                "path": full_path.name,
                "raw_sha256": full_sha256,
                "byte_length": full_path.stat().st_size,
            },
            {
                "path": summary_path.name,
                "raw_sha256": summary_sha256,
                "byte_length": summary_path.stat().st_size,
            },
        ],
        "execution_valid": projection["execution_valid"],
        "decision_positive": projection["decision_positive"],
        "complete_trace_retained": True,
        "compact_projection_retained": True,
        "held_out_cell_access_count": 0,
        "repeatability_rate_claimed": False,
        "population_claimed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    manifest_path = output_directory / "manifest.json"
    manifest_sha256 = shared._write_json_exclusive(manifest_path, manifest)
    return {
        "ok": bool(projection["execution_valid"]),
        "execution_valid": bool(projection["execution_valid"]),
        "decision_positive": bool(projection["decision_positive"]),
        "summary_path": str(summary_path),
        "summary_raw_sha256": summary_sha256,
        "manifest_path": str(manifest_path),
        "manifest_raw_sha256": manifest_sha256,
        "exact_nominal_mujoco_prone_to_standing_observed": bool(
            projection["exact_nominal_mujoco_prone_to_standing_observed"]
        ),
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _publish_invalid(
    error: Exception, *, output_directory: Path, source_commit: str
) -> dict[str, Any]:
    invalid = {
        "schema_version": INVALID_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "error_type": type(error).__name__,
        "error": str(error),
        "traceback": traceback.format_exc(),
        "invalid_or_incomplete_retained": True,
        "valid_behavior_result_observed": False,
        "valid_physical_behavior_result_observed": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "repeatability_rate_claimed": False,
        "population_claimed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if output_directory.is_dir():
        shared._write_json_exclusive(output_directory / "invalid_result.json", invalid)
    return invalid


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    preflight = commands.add_parser("preflight")
    preflight.add_argument("--core-library", type=Path, required=True)
    run = commands.add_parser("run")
    run.add_argument("--core-library", type=Path, required=True)
    run.add_argument("--contract", type=Path, required=True)
    run.add_argument("--output-directory", type=Path, required=True)
    run.add_argument("--source-commit", required=True)
    run.add_argument("--qualification-receipt", type=Path, required=True)
    run.add_argument("--operation-lock-receipt", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    if arguments.command == "preflight":
        receipt = run_zero_world_preflight(
            LocomotionCore(arguments.core_library.resolve())
        )
        print(json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    try:
        completion = run_and_publish_v1(
            core_library=arguments.core_library.resolve(),
            contract_path=arguments.contract.resolve(),
            output_directory=arguments.output_directory.resolve(),
            source_commit=str(arguments.source_commit),
            qualification_receipt_path=arguments.qualification_receipt.resolve(),
            operation_lock_receipt_path=arguments.operation_lock_receipt.resolve(),
        )
        print(json.dumps(completion, allow_nan=False, sort_keys=True))
        return 0 if completion["ok"] else 3
    except Exception as error:
        invalid = _publish_invalid(
            error,
            output_directory=arguments.output_directory.resolve(),
            source_commit=str(arguments.source_commit),
        )
        print(json.dumps(invalid, allow_nan=False, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
