#!/usr/bin/env python3
"""Compact R79 finite command-transport audit and zero-world preflight."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402
from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    load,
    require,
    resolve_prospective_source_freeze,
    sha256,
    source_bytes,
    verify_declared_source_inventory,
    verify_exact_paths,
)

CONTRACT = ROOT / "sdk/recovery/r24d79_recovery_command_transport_population_contract_v1.json"
CLOSURE = ROOT / (
    "sdk/recovery/r24d79_recovery_command_transport_population_"
    "zero_world_qualification_closure_v1.json"
)
PREDECESSOR = ROOT / (
    "sdk/recovery/r24d78_godot_jolt_host_real_recovery_behavior_"
    "incomplete_closure_v1.json"
)
WORKER = ROOT / "tests/test_sdk_recovery_command_digest_population_development_probe.gd"
SOURCE_MARKER = "QSDK_R24D79_RECOVERY_COMMAND_TRANSPORT_POPULATION_SOURCE_PASS"
WORKER_MARKER = "QSDK_RECOVERY_COMMAND_DIGEST_POPULATION_DEVELOPMENT_PROBE "

COMMAND_POPULATION_SPEC = {
    "id": "r79_command_transport_population",
    "path": WORKER,
    "marker": WORKER_MARKER,
    "expected": {
        "schema_version": (
            "sporespore_recovery_command_digest_population_development_probe_v3"
        ),
        "ok": True,
        "status": "transport_stable",
        "active_command_cell_count": 603,
        "recovery_active_command_cell_count": 602,
        "stance_command_shape_cell_count": 1,
        "synthetic_stance_handoff_fixture_count": 1,
        "application_pass_count": 603,
        "validated_command_count": 4824,
        "host_write_count": 4824,
        "host_readback_count": 4824,
        "digest_mismatch_count": 0,
        "unique_expected_digest_count": 362,
        "unique_recomputed_digest_count": 362,
        "population_sha256": (
            "sha256:0285fcd60dd739084fa6131d58ce7d389d556a9da1d4dae1239d98293228dc46"
        ),
        "forced_digest_failure_rejected": True,
        "native_runtime_observation_collection_executed": False,
        "physical_question_opened": False,
    },
}


def _contains(path: Path, *markers: str) -> None:
    value = path.read_text(encoding="utf-8")
    require(all(marker in value for marker in markers), f"MARKERS:{path.name}")


def _verify_predecessor(contract: dict[str, Any]) -> None:
    value = controls.validate_bound_predecessor(ROOT, contract, PREDECESSOR)
    predecessor = contract["bound_predecessors"][0]
    raw = source_bytes(ROOT, predecessor["closure_commit"], predecessor["path"])
    exact(
        (len(raw), sha256(raw)),
        (predecessor["byte_length"], predecessor["raw_sha256"]),
        "PREDECESSOR_CONTENT",
    )
    exact(
        git(ROOT, "rev-parse", f"{predecessor['closure_commit']}:{predecessor['path']}"),
        predecessor["git_blob_oid"],
        "PREDECESSOR_BLOB",
    )
    verify_exact_paths(
        value,
        {
            "closure_status": predecessor["closure_status"],
            "physical_attempt.solver_step_count": 393,
            "physical_attempt.behavior_evaluator_invocation_count": 0,
            "partial_physical_observation.in_run_invariant_receipt_count": 393,
            "partial_physical_observation.all_in_run_physical_invariants_passed": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.scientific_positive_observed": False,
            "decision.scientific_negative_observed": False,
        },
        "R78",
    )


def validate_sources() -> tuple[dict[str, Any], dict[str, int]]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d79_recovery_command_transport_population_contract_v1"
            ),
            "gate_id": "QSDK-R24D79",
            "status": (
                "prospective_complete_finite_command_transport_qualification_required_"
                "physics_blocked"
            ),
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": False,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "controlled_change.guarded_transport_projection_significant_decimal_digits": 13,
            "controlled_change.canonical_digest_significant_decimal_digits": 14,
            "controlled_change.guard_digit_count": 1,
            "controlled_change.portable_recovery_phase_or_threshold_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.physical_envelope_changed": False,
            "transport_projection_adequacy.physical_threshold_count_added": 0,
            "transport_projection_adequacy.equivalence_margin_count_added": 0,
            "finite_command_population.total_active_command_cell_count": 603,
            "finite_command_population.total_validated_command_count": 4824,
            "finite_command_population.expected_unique_command_digest_count": 362,
            "critical_path_audit_policy.focused_source_inventory_count": 32,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "authorization_boundary.maximum_physical_steps_authorized": 0,
            "sdk_status.sdk1_completed_steps": 11,
        },
        "CONTRACT",
    )
    _verify_predecessor(contract)

    for commit in contract["implementation_commits"]:
        git(ROOT, "merge-base", "--is-ancestor", commit, "HEAD")
    runtime = contract["exact_runtime"]
    for prefix in ("console", "engine"):
        path = Path(runtime[f"{prefix}_path"])
        require(path.is_file(), f"RUNTIME_MISSING:{prefix}")
        exact(
            (path.stat().st_size, sha256(path.read_bytes())),
            (runtime[f"{prefix}_byte_length"], runtime[f"{prefix}_sha256"]),
            f"RUNTIME_CONTENT:{prefix}",
        )

    inventory = contract["source_inventory"]
    authored = contract["authored_source_paths"]
    verify_declared_source_inventory(ROOT, inventory)
    verify_declared_source_inventory(ROOT, authored)
    exact((len(inventory), len(set(inventory))), (32, 32), "SOURCE_COUNT")
    exact((len(authored), len(set(authored))), (5, 5), "AUTHORED_COUNT")
    _source, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d79_recovery_command_transport_population_"
            "zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D79",
    )

    _contains(
        ROOT / "sdk/core/src/canonical.rs",
        "GUARDED_CANONICAL_SIGNIFICANT_DECIMAL_DIGITS_V1",
        "project_binary64_to_guarded_canonical_number_v1",
        "guarded_projection_absorbs_the_observed_one_ulp_parser_shifts",
    )
    _contains(
        ROOT / "sdk/core/src/recovery_runtime.rs",
        "project_binary64_to_guarded_canonical_number_v1(target)?",
        "complete_active_recovery_population_has_transport_stable_command_identity",
    )
    _contains(
        ROOT / "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd",
        "QSDK_R24D57_COMMAND_DIGEST_INVALID",
        "_command_digest_mismatch_diagnostic_v1",
        '"host_write_count": 0',
    )
    _contains(
        WORKER,
        "RouteScript.apply_behavior_control_v1(",
        "RuntimeScript.plan_stance_control_v3(",
        'cell_specs.size() == 603',
        'validated_command_count == 4824',
        '"forced_digest_failure_rejected"',
    )
    return contract, {
        "focused_source_inventory_count": len(inventory),
        "authored_source_path_count": len(authored),
        "bound_predecessor_count": 1,
        "current_zero_world_worker_count": 1,
        "historical_closure_audits_executed_count": 0,
        "published_closure_observed": int(published),
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    contract, counts = validate_sources()
    require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    executable = controls.validate_exact_runtime_and_inventory(ROOT, contract, 32)
    receipts = controls.run_zero_world_worker_specs(
        ROOT, executable, (COMMAND_POPULATION_SPEC,)
    )
    population = receipts["r79_command_transport_population"]
    forced = population["forced_digest_failure_detail"]
    controls.require_fields(
        forced,
        {
            "failure_code": "QSDK_R24D57_COMMAND_DIGEST_INVALID",
            "expected_command_sha256": "sha256:" + "0" * 64,
            "host_write_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
        "FORCED_DIGEST_FAILURE",
    )
    return {
        "schema_version": (
            "sporespore_qsdk_r24d79_recovery_command_transport_population_preflight_v1"
        ),
        "gate_id": "QSDK-R24D79",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["collector_id"],
        "runtime_version": contract["exact_runtime"]["runtime_profile_id"],
        **counts,
        "command_population_receipt": population,
        "active_command_cell_count": population["active_command_cell_count"],
        "application_pass_count": population["application_pass_count"],
        "forced_digest_failure_rejection_count": 1,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    if args.core_library is None:
        _contract, counts = validate_sources()
        print(SOURCE_MARKER, " ".join(f"{key}={value}" for key, value in counts.items()))
    else:
        print(
            json.dumps(
                run_preflight(args.core_library.resolve()),
                allow_nan=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"QSDK_R24D79_RECOVERY_COMMAND_TRANSPORT_POPULATION_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
