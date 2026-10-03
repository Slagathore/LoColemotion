#!/usr/bin/env python3
"""Differential R67 audit composed from reusable recovery controls."""

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
from sdk.conformance import r24d66_godot_exact_quaternion_projection as r66  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d67_godot_portable_contact_identity_contract_v1.json"
PREDECESSOR = ROOT / "sdk/recovery/r24d66_godot_exact_quaternion_projection_behavior_invalid_closure_v1.json"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
PROTOCOL = ROOT / "sdk/core/src/protocol.rs"
PHYSICAL_WORKER = ROOT / "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
PHYSICAL_RUNNER = ROOT / "sdk/run_qsdk_r24d67_godot_portable_contact_identity.ps1"
QUALIFICATION_RUNNER = ROOT / "sdk/run_qsdk_r24d67_godot_portable_contact_identity_zero_world_qualification.ps1"
SOURCE_MARKER = "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_SOURCE_PASS"
SUPERVISOR_MARKER = "QSDK_R24D67_BEHAVIOR_SUPERVISOR "

require = r66.require
load = r66.load
markers = r66.markers

WORKER_SPECS = (
    {
        "id": "r65_current_behavior_composition",
        "path": ROOT / "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior_zero_world.gd",
        "marker": "QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_ZERO_WORLD ",
        "expected": {
            "ok": True, "positive_control_count": 4,
            "positive_controls_passed": 4, "mutation_rejection_count": 4,
            "native_runtime_observation_collection_executed": False,
            "physical_question_opened": False,
        },
    },
    {
        "id": "r66_current_quaternion_projection",
        "path": ROOT / "tests/test_sdk_qsdk_r24d66_godot_quaternion_projection_zero_world.gd",
        "marker": "QSDK_R24D66_GODOT_QUATERNION_PROJECTION_ZERO_WORLD ",
        "expected": {
            "ok": True, "projection_case_count": 4,
            "projected_core_acceptance_count": 4, "raw_core_refusal_count": 3,
            "zero_projection_refusal_count": 1, "diagnostic_retention_count": 1,
            "native_runtime_observation_collection_executed": False,
            "physical_question_opened": False,
        },
    },
    {
        "id": "r67_portable_contact_identity",
        "path": ROOT / "tests/test_sdk_qsdk_r24d67_godot_portable_contact_identity_zero_world.gd",
        "marker": "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_ZERO_WORLD ",
        "expected": {
            "ok": True, "observed_projection_exact_count": 1,
            "historical_mismatch_reproduction_count": 1,
            "raw_core_refusal_count": 1, "projected_core_acceptance_count": 1,
            "empty_projection_control_count": 1,
            "collision_tricky_control_count": 1,
            "utf8_projection_control_count": 1, "mutation_rejection_count": 3,
            "native_runtime_observation_collection_executed": False,
            "physical_question_opened": False,
        },
    },
)


def validate_contract() -> dict[str, Any]:
    contract = load(CONTRACT)
    controls.validate_development_question(contract, "QSDK-R24D67")
    closed = controls.validate_bound_predecessor(ROOT, contract, PREDECESSOR)
    require(closed["closure_status"] ==
            "closed_consumed_invalid_candidate_step_81_engine_contact_identity_validation_refusal",
            "R66_CLOSURE_STATUS")
    require(closed["next_boundary"]["gate_id"] == "QSDK-R24D67",
            "R66_NEXT_GATE")

    change = contract["controlled_change"]
    controls.require_fields(change, {
        "native_observation_mapping_changed": True,
        "native_observation_mapping_change_scope": "engine_contact_identity_projection_only",
        "contact_identity_projection_changed": True,
        "lossless_utf8_hex_projection_added": True,
        "raw_to_portable_diagnostics_added": True, "collision_refusal_added": True,
    }, "CHANGE")
    for key in (
        "world_geometry_changed", "canonical_prone_initializer_changed",
        "native_physics_or_jolt_patch_changed", "native_telemetry_projection_changed",
        "quaternion_projection_changed", "actuator_profile_changed",
        "controller_changed", "stance_controller_changed", "threshold_changed",
        "margin_changed", "evaluator_changed", "morphology_changed",
        "selector_changed", "portable_identity_grammar_changed",
        "historical_result_rewritten", "behavior_worker_changed",
        "physical_supervisor_changed",
    ):
        require(change[key] is False, f"FORBIDDEN_CHANGE:{key}")

    seed_label = "QSDK-R24D67/development/godot/exact-nominal-paired-v1"
    projection = contract["contact_identity_projection_contract"]
    raw_id = "rear_left_distal:0|floor:0"
    raw_hex = raw_id.encode().hex()
    controls.require_fields(projection, {
        "function": "native_contact_identity_projection_v2",
        "method_id": "godot_utf8_hex_portable_contact_identity_v1",
        "portable_prefix": "godot_contact_",
        "injective_for_distinct_utf8_byte_sequences": True,
        "hash_or_truncation_used": False, "raw_identity_retained": True,
        "raw_to_portable_pairs_retained": True,
        "raw_deduplication_precedes_encoding": True,
        "stable_first_observation_order_preserved": True,
        "portable_collision_checked_and_refused": True,
        "physical_sampler_calls_exact_function_for_foot_and_nonfoot_buckets": True,
        "portable_core_identity_grammar_changed": False,
        "observed_raw_identity": raw_id, "observed_raw_utf8_hex": raw_hex,
        "observed_portable_identity": f"godot_contact_{raw_hex}",
        "empty_bucket_projection_control_count": 1,
        "collision_tricky_control_count": 1,
        "non_ascii_utf8_projection_control_count": 1,
        "invalid_input_rejection_count": 3,
    }, "PROJECTION")

    policy = contract["critical_path_audit_policy"]
    controls.require_fields(policy, {
        "complete_current_source_population_content_addressed": True,
        "exact_predecessor_closure_digest_bound": True,
        "current_zero_world_worker_count": len(WORKER_SPECS),
        "historical_closure_audits_executed_count": 0,
        "historical_closure_results_reinterpreted_count": 0,
        "unrelated_historical_regression_sweep_required_in_campaign_critical_path": False,
        "scheduled_historical_regression_cadence_replaced_or_waived": False,
    }, "AUDIT_POLICY")
    controls.require_fields(contract["ghost_and_canary_adequacy"], {
        "additional_physical_route_ghost_required": False,
        "full_seeded_physical_ghost_required": False,
        "forced_failure_zero_world_control_required": True,
    }, "GHOST")

    controls.validate_finite_development_envelope(
        contract,
        seed_label,
        {
            "maximum_outer_steps_per_arm": 1200,
            "maximum_total_outer_steps": 2400,
        },
        {
            "profile_sha256": "sha256:3081621eb53f4d67bc1d8dc0f3a7d3ad7ae5ed829f902bce60b01ba1530bfb34",
            "maximum_energy_balance_residual_j": 0.25,
            "required_stance_dwell_steps": 60,
            "stance_dwell_timeout_steps": 240,
            "quaternion_norm_squared_tolerance": 1.0e-9,
            "threshold_change_count": 0,
            "margin_change_count": 0,
        },
        {
            "supervisor_forced_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
        },
        {
            "maximum_model_construction_attempt_count": 2,
            "maximum_model_construction_count": 2,
            "maximum_world_attempt_count": 2,
            "maximum_world_build_count": 2,
            "maximum_outer_solver_steps": 2400,
            "physics_ticks_per_second": 120,
        },
    )
    controls.validate_exact_runtime_and_inventory(ROOT, contract, 108)
    return contract


def validate_sources() -> dict[str, int]:
    contract = validate_contract()
    source_markers = {
        WORLD: (
            "static func portable_contact_identity_v1(",
            'var portable_id := "godot_contact_%s" % raw_utf8_hex',
            "static func native_contact_identity_projection_v2(",
            '"portable_identity_collision_count": 0',
            '"raw_to_portable_identity_pairs"',
            "static func portable_identity_grammar_valid_v1(",
        ),
        PROTOCOL: (
            "fn valid_id(value: &str) -> bool {",
            "matches!(characters.next(), Some('a'..='z'))",
            "character.is_ascii_lowercase() || character.is_ascii_digit()",
        ),
        PHYSICAL_WORKER: (
            'GENERIC_GATE_ID_ENV := "SPORESPORE_GODOT_RECOVERY_GATE_ID"',
            "RouteScript.advance_behavior_v4(",
            '"all_in_run_physical_invariants_passed": true',
        ),
        PHYSICAL_RUNNER: (
            'GateId = "QSDK-R24D67"', 'PhysicalQuestionKind = "behavior_development"',
            "MaximumWorldBuildCount = 2", "MaximumOuterSolverSteps = 2400",
            "ExpectedBehaviorEvaluatorInvocationCount = 1", "& $shared @arguments",
        ),
        QUALIFICATION_RUNNER: (
            "run_qsdk_core_zero_world_qualification.ps1", 'GateId "QSDK-R24D67"',
            "-ProspectivePhysicalQuestionDeclared", "exit $LASTEXITCODE",
        ),
    }
    for path, expected in source_markers.items():
        markers(path, expected)
    for spec in WORKER_SPECS:
        require(Path(spec["path"]).is_file(), f"WORKER_MISSING:{spec['id']}")
    world = WORLD.read_text(encoding="utf-8")
    require(world.count("native_contact_identity_projection_v2(raw_ids)") == 2,
            "PRODUCTION_V2_CALL_COUNT")
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": 1,
        "current_zero_world_worker_count": len(WORKER_SPECS),
        "historical_closure_audits_executed_count": 0,
        "r65_positive_control_count": 4,
        "r65_mutation_rejection_count": 4,
        "r66_quaternion_projection_case_count": 4,
        "r67_observed_projection_exact_count": 1,
        "r67_empty_bucket_projection_control_count": 1,
        "r67_collision_tricky_control_count": 1,
        "r67_non_ascii_utf8_projection_control_count": 1,
        "r67_mutation_rejection_count": 3,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    contract = load(CONTRACT)
    executable = Path(contract["exact_runtime"]["console_path"])
    worker_receipts = controls.run_zero_world_worker_specs(
        ROOT, executable, WORKER_SPECS)

    r67_receipt = worker_receipts["r67_portable_contact_identity"]
    require(r67_receipt["raw_core_refusal_reason"] ==
            "state_frame_invalid:IDENTITY_INVALID:engine_contact_id:rear_left_distal:0|floor:0",
            "R67_RAW_REFUSAL")
    require(r67_receipt["observed_portable_engine_contact_id"] ==
            contract["contact_identity_projection_contract"]["observed_portable_identity"],
            "R67_PROJECTED_ID")

    supervisor = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D67")
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D67",
        "sporespore_qsdk_r24d67_missing_physical_switch_refusal_v1")
    controls.require_zero_authority(supervisor)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d67_godot_portable_contact_identity_preflight_v1",
        "gate_id": "QSDK-R24D67", "ok": True,
        "runtime_id": "sporespore_qsdk_r24d67_godot_portable_contact_identity_v1",
        "runtime_version": "godot_4_7_jolt_instrumented_v2_exact_binary_pair",
        **counts, **{f"{key}_receipt": value for key, value in worker_receipts.items()},
        "supervisor_projection_receipt": supervisor,
        "missing_physical_switch_refusal_receipt": refusal,
        "supervisor_forced_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "additional_physical_route_ghost_required": False,
        "full_seeded_physical_ghost_required": False,
        "prospective_physical_question_declared": True,
        "native_runtime_observation_collection_executed": False,
        "held_out_cell_access_count": 0, "model_construction_count": 0,
        "world_attempt_count": 0, "world_build_count": 0,
        "solver_step_count": 0, "physics_state_modified": False,
        "physical_question_opened": False, "prone_to_standing_claimed": False,
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
    print(json.dumps(run_preflight(args.core_library.resolve()),
                     allow_nan=False, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
