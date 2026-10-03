#!/usr/bin/env python3
"""Compact R70 receipt-consumer audit over shared Godot recovery controls."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d70_godot_behavior_receipt_acceptance_contract_v1.json"
PREDECESSOR = ROOT / "sdk/recovery/r24d69_godot_behavior_evaluator_receipt_invalid_closure_v1.json"
ROUTE = ROOT / "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
BINDING = ROOT / "sdk/adapters/godot/gdscript/actuator_cap_profile_binding.gd"
JOLT_PATCH = ROOT / "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
CORE = ROOT / "sdk/core/src/recovery.rs"
CORE_RUNTIME = ROOT / "sdk/core/src/recovery_runtime.rs"
PHYSICAL_WORKER = ROOT / "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
ZERO_WORKER = ROOT / "tests/test_sdk_qsdk_r24d70_godot_behavior_receipt_acceptance_zero_world.gd"
PHYSICAL_RUNNER = ROOT / "sdk/run_qsdk_r24d70_godot_behavior_receipt_acceptance.ps1"
QUALIFICATION_RUNNER = ROOT / "sdk/run_qsdk_r24d70_godot_behavior_receipt_acceptance_zero_world_qualification.ps1"
SOURCE_MARKER = "QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_SOURCE_PASS"
SUPERVISOR_MARKER = "QSDK_R24D70_BEHAVIOR_SUPERVISOR "
PARENT = "6db52f606f74cea6a7bfeeaa1370c52e504deb53"
SEED_LABEL = "QSDK-R24D70/development/godot/exact-nominal-receipt-successor-paired-v1"


def _spec(
    worker_id: str,
    relative: str,
    marker: str,
    expected: dict[str, Any],
) -> dict[str, Any]:
    return {
        "id": worker_id,
        "path": ROOT / relative,
        "marker": marker,
        "expected": {
            "ok": True,
            "native_runtime_observation_collection_executed": False,
            "physical_question_opened": False,
            **expected,
        },
    }


WORKER_SPECS = (
    _spec(
        "r63_v1_telemetry_compatibility",
        "tests/test_sdk_qsdk_r24d63_godot_structured_motor_telemetry_failure_receipt_zero_world.gd",
        "QSDK_R24D63_GODOT_STRUCTURED_TELEMETRY_FAILURE_ZERO_WORLD ",
        {"positive_control_count": 4, "exact_failure_receipt_count": 22,
         "mutation_count": 22},
    ),
    _spec(
        "r65_behavior_composition",
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior_zero_world.gd",
        "QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_ZERO_WORLD ",
        {"positive_control_count": 4, "positive_controls_passed": 4,
         "mutation_rejection_count": 4},
    ),
    _spec(
        "r66_quaternion_projection",
        "tests/test_sdk_qsdk_r24d66_godot_quaternion_projection_zero_world.gd",
        "QSDK_R24D66_GODOT_QUATERNION_PROJECTION_ZERO_WORLD ",
        {"projection_case_count": 4, "projected_core_acceptance_count": 4,
         "raw_core_refusal_count": 3, "zero_projection_refusal_count": 1,
         "diagnostic_retention_count": 1},
    ),
    _spec(
        "r67_contact_identity",
        "tests/test_sdk_qsdk_r24d67_godot_portable_contact_identity_zero_world.gd",
        "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_ZERO_WORLD ",
        {"observed_projection_exact_count": 1,
         "historical_mismatch_reproduction_count": 1,
         "raw_core_refusal_count": 1, "projected_core_acceptance_count": 1,
         "empty_projection_control_count": 1, "collision_tricky_control_count": 1,
         "utf8_projection_control_count": 1, "mutation_rejection_count": 3},
    ),
    _spec(
        "r69_native_effective_limit",
        "tests/test_sdk_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world.gd",
        "QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_ZERO_WORLD ",
        {"projection_control_count": 8, "native_effective_safe_count": 8,
         "adjacent_unsafe_count": 8, "binary32_maximality_count": 8,
         "source_algebra_identity_count": 8,
         "production_route_projection_count": 8,
         "production_route_safe_readback_count": 8,
         "identity_mutation_rejection_count": 4},
    ),
    _spec(
        "r70_receipt_acceptance",
        "tests/test_sdk_qsdk_r24d70_godot_behavior_receipt_acceptance_zero_world.gd",
        "QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_ZERO_WORLD ",
        {"acceptance_fixture_count": 3, "positive_acceptance_count": 1,
         "negative_acceptance_count": 1, "incomplete_acceptance_count": 1,
         "r69_failure_shape_accepted": True, "refusal_rejection_count": 1,
         "receipt_mutation_rejection_count": 17,
         "receipt_common_check_count": 22, "receipt_verdict_check_count": 9,
         "terminal_summary_fixture_count": 3, "full_summary_arm_count": 2,
         "full_summary_invariant_count": 5,
         "summary_mutation_rejection_count": 6,
         "content_mutation_digest_change_count": 1,
         "dictionary_order_invariance_count": 1},
    ),
)


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    controls.require(isinstance(value, dict), f"JSON_ROOT:{path.name}")
    return value


def _git_blob(path: Path, commit: str | None = None) -> str:
    relative = path.relative_to(ROOT).as_posix()
    arguments = ["git", "rev-parse", f"{commit}:{relative}"] if commit else [
        "git", "hash-object", "--", relative
    ]
    return subprocess.run(
        arguments, cwd=ROOT, capture_output=True, text=True,
        encoding="utf-8", check=True,
    ).stdout.strip()


def _git_text(path: Path, commit: str) -> str:
    relative = path.relative_to(ROOT).as_posix()
    return subprocess.run(
        ["git", "show", f"{commit}:{relative}"], cwd=ROOT,
        capture_output=True, text=True, encoding="utf-8", check=True,
    ).stdout


def _function(source: str, name: str) -> str:
    start = source.index(f"static func {name}(")
    candidates = [
        value for value in (
            source.find("\n\n##", start + 1),
            source.find("\n\nstatic func ", start + 1),
        ) if value >= 0
    ]
    end = min(candidates) if candidates else -1
    return source[start:] if end < 0 else source[start:end]


def _worker_function(source: str, name: str) -> str:
    start = source.index(f"func {name}(")
    end = source.find("\n\nfunc ", start + 1)
    return source[start:] if end < 0 else source[start:end]


def validate_sources() -> dict[str, int]:
    contract = _load(CONTRACT)
    controls.validate_development_question(contract, "QSDK-R24D70")
    controls.require_fields(contract["ledger_scope"], {
        "subsystem": "recovery", "engine_scope": "godot_jolt",
        "authority_mode": "prospective_development_contract",
        "question_class": "development",
    }, "LEDGER_SCOPE")
    controls.require(contract["authored_parent_commit"] == PARENT, "PARENT")
    predecessor = controls.validate_bound_predecessor(ROOT, contract, PREDECESSOR)
    controls.require_fields(predecessor, {
        "closure_status": "closed_consumed_invalid_positive_only_worker_evaluator_receipt_acceptance_predicate",
        "question_class": "development",
    }, "PREDECESSOR_CLOSURE")
    controls.require(predecessor["next_boundary"]["gate_id"] == "QSDK-R24D70",
                     "PREDECESSOR_NEXT_GATE")

    controls.require_fields(contract["controlled_change"], {
        "worker_evaluation_receipt_consumer_predicate_changed": True,
        "route_receipt_validator_added": True,
        "terminal_arm_invariant_summary_added": True,
        "invalid_terminal_paths_retain_summary": True,
        "portable_core_changed": False,
        "portable_evaluator_changed": False,
        "recovery_controller_changed": False,
        "stance_controller_changed": False,
        "behavior_threshold_changed": False,
        "actuator_profile_changed": False,
        "actuator_cap_changed": False,
        "native_world_changed": False,
        "native_physics_or_jolt_patch_changed": False,
        "initializer_changed": False,
        "morphology_changed": False,
        "selector_changed": False,
        "physical_envelope_changed": False,
        "historical_result_rewritten": False,
    }, "CONTROLLED_CHANGE")
    controls.require_fields(contract["receipt_acceptance_contract"], {
        "accepted_verdicts": ["physical_development_passed",
                              "physical_development_failed",
                              "physical_development_incomplete"],
        "common_check_count": 22, "verdict_check_count": 9,
        "refusal_fixture_count": 1, "malformed_mutation_count": 17,
        "exact_r69_failed_receipt_shape_is_positive_control": True,
    }, "RECEIPT_CONTRACT")
    controls.require_fields(contract["terminal_invariant_summary_contract"], {
        "present_on_valid_and_invalid_worker_terminal_paths": True,
        "partial_current_arm_population_retained_when_observations_exist": True,
        "terminal_summary_fixture_count": 3, "summary_mutation_count": 6,
        "content_mutation_control_count": 1, "dictionary_order_control_count": 1,
    }, "SUMMARY_CONTRACT")
    controls.require_fields(contract["critical_path_audit_policy"], {
        "current_zero_world_worker_count": len(WORKER_SPECS),
        "historical_closure_audits_executed_count": 0,
        "historical_closure_results_reinterpreted_count": 0,
        "bespoke_campaign_source_audit_mechanics_added_count": 0,
        "shared_process_control_module_reused": True,
        "data_driven_successor_worker_added_count": 1,
    }, "CRITICAL_PATH")
    controls.validate_finite_development_envelope(
        contract, SEED_LABEL,
        {"cell_id": "r24d70_godot_development_exact_nominal",
         "maximum_outer_steps_per_arm": 1200,
         "maximum_total_outer_steps": 2400},
        {"threshold_change_count": 0, "margin_change_count": 0},
        {"current_worker_count": 6, "accepted_outcome_fixture_count": 3,
         "refusal_rejection_count": 1, "receipt_mutation_rejection_count": 17,
         "terminal_summary_fixture_count": 3,
         "summary_mutation_rejection_count": 6,
         "supervisor_forced_failure_control_count": 1,
         "missing_physical_switch_refusal_count": 1},
        {"schema_version": "sporespore_qsdk_physical_route_authorization_projection_v1",
         "gate_id": "QSDK-R24D70", "question_class": "development",
         "held_out": False, "maximum_model_construction_attempt_count": 2,
         "maximum_model_construction_count": 2,
         "maximum_world_attempt_count": 2, "maximum_world_build_count": 2,
         "maximum_outer_solver_steps": 2400, "physics_ticks_per_second": 120,
         "outer_step_duration_s": 1.0 / 120.0},
    )
    controls.require_fields(
        contract["finite_development_population"]["seed_selection_provenance"],
        {"initial_unsigned_seed": 3497110284,
         "initial_label_rejected_before_freeze": True,
         "selected_replacement_candidate_index": 0,
         "selected_before_any_physical_result": True,
         "selected_from_behavior_outcome": False},
        "SEED_SELECTION_PROVENANCE",
    )
    inventory_count = contract["source_inventory_strategy"]["source_inventory_count"]
    controls.require(inventory_count == 147, "INVENTORY_DECLARATION")
    controls.validate_exact_runtime_and_inventory(ROOT, contract, inventory_count)

    # Entire frozen producer/runtime/world seams remain byte-identical.
    for path in (CORE, CORE_RUNTIME, WORLD, BINDING, JOLT_PATCH):
        controls.require(_git_blob(path) == _git_blob(path, PARENT),
                         f"FROZEN_FILE:{path.name}")
    route = ROUTE.read_text(encoding="utf-8")
    parent_route = _git_text(ROUTE, PARENT)
    for name in (
        "exact_base_descriptor_v1", "prepare_context_v1",
        "initial_behavior_application_v1", "initialize_behavior_arm_v1",
        "advance_behavior_v4", "evaluate_behavior_v4",
        "apply_behavior_control_v1", "_apply_active_control_commands_v1",
        "_apply_no_actuation_control_v1",
    ):
        controls.require(_function(route, name) == _function(parent_route, name),
                         f"FROZEN_ROUTE_FUNCTION:{name}")
    controls.require(route.count("validate_physical_evaluation_receipt_v1(") == 1,
                     "RECEIPT_VALIDATOR_COUNT")
    controls.require(route.count("compact_behavior_arm_invariant_summary_v1(") == 1,
                     "SUMMARY_HELPER_COUNT")

    worker = PHYSICAL_WORKER.read_text(encoding="utf-8")
    parent_worker = _git_text(PHYSICAL_WORKER, PARENT)
    for name in (
        "_start_arm", "_on_physics_frame", "_capture_completed_step",
        "_complete_current_arm", "_invariant_receipt_valid",
        "_load_campaign_binding",
    ):
        controls.require(_worker_function(worker, name) == _worker_function(parent_worker, name),
                         f"FROZEN_WORKER_FUNCTION:{name}")
    finalize = _worker_function(worker, "_finalize_pair")
    controls.require(finalize.count("validate_physical_evaluation_receipt_v1(") == 1,
                     "WORKER_VALIDATOR_WIRING")
    controls.require("or not bool(evaluation.get(\"all_negative_control_requirements_enforced\"" not in finalize,
                     "POSITIVE_ONLY_PREDICATE_RETAINED")
    controls.require(worker.count("compact_behavior_arm_invariant_summary_v1(") == 2,
                     "WORKER_SUMMARY_WIRING")
    controls.require("func _terminal_summary_arm_results()" in worker,
                     "PARTIAL_SUMMARY_WIRING")

    zero_worker = ZERO_WORKER.read_text(encoding="utf-8")
    for marker in (
        "acceptance_fixture_count", "receipt_mutation_rejection_count",
        "terminal_summary_fixture_count", "summary_mutation_rejection_count",
        "dictionary_order_invariance_count",
    ):
        controls.require(marker in zero_worker, f"ZERO_WORKER_MARKER:{marker}")
    runner = PHYSICAL_RUNNER.read_text(encoding="utf-8")
    qualifier = QUALIFICATION_RUNNER.read_text(encoding="utf-8")
    for marker in ("QSDK-R24D70", "Seed = 278151771", SEED_LABEL,
                   "MaximumOuterSolverSteps = 2400"):
        controls.require(marker in runner, f"PHYSICAL_RUNNER:{marker}")
    controls.require("QSDK-R24D70" in qualifier and
                     "ProspectivePhysicalQuestionDeclared = $true" in qualifier,
                     "QUALIFICATION_RUNNER")
    return {
        "source_inventory_count": inventory_count,
        "bound_predecessor_count": 1,
        "current_zero_world_worker_count": len(WORKER_SPECS),
        "historical_closure_audits_executed_count": 0,
        "accepted_outcome_fixture_count": 3,
        "receipt_mutation_rejection_count": 17,
        "terminal_summary_fixture_count": 3,
        "summary_mutation_rejection_count": 6,
        "frozen_route_function_count": 9,
        "frozen_worker_function_count": 6,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    controls.require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    contract = _load(CONTRACT)
    executable = Path(contract["exact_runtime"]["console_path"])
    receipts = controls.run_zero_world_worker_specs(ROOT, executable, WORKER_SPECS)
    r70 = receipts["r70_receipt_acceptance"]
    controls.require(
        r70["ordered_acceptance_receipts"][1]["scientific_outcome"] == "negative"
        and r70["full_summary"]["summarized_solver_step_count"] == 5
        and r70["full_summary"]["completed_arm_count"] == 2,
        "R70_DETAILED_RECEIPT",
    )
    supervisor = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D70"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D70",
        "sporespore_qsdk_r24d70_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(supervisor)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d70_godot_behavior_receipt_acceptance_preflight_v1",
        "gate_id": "QSDK-R24D70", "ok": True,
        "runtime_id": "sporespore_qsdk_r24d70_godot_behavior_receipt_acceptance_v1",
        "runtime_version": "godot_4_7_jolt_instrumented_v2_exact_binary_pair",
        **counts,
        **{f"{key}_receipt": value for key, value in receipts.items()},
        "supervisor_projection_receipt": supervisor,
        "missing_physical_switch_refusal_receipt": refusal,
        "supervisor_forced_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "additional_physical_route_ghost_required": False,
        "full_seeded_physical_ghost_required": False,
        "native_runtime_observation_collection_executed": False,
        "held_out_cell_access_count": 0,
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "physics_state_modified": False, "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False, "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    if args.core_library is None:
        counts = validate_sources()
        print(SOURCE_MARKER, " ".join(f"{key}={value}" for key, value in counts.items()))
        return 0
    print(json.dumps(run_preflight(args.core_library.resolve()), allow_nan=False,
                     separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
