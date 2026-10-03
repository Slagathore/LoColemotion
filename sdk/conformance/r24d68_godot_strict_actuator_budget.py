#!/usr/bin/env python3
"""Compact R68 strict-budget audit over reusable Godot recovery controls."""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402
from sdk.conformance import r24d67_godot_portable_contact_identity as r67  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d68_godot_strict_actuator_budget_contract_v1.json"
PREDECESSOR = ROOT / "sdk/recovery/r24d67_godot_portable_contact_identity_behavior_invalid_closure_v1.json"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = ROOT / "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
BINDING = ROOT / "sdk/adapters/godot/gdscript/actuator_cap_profile_binding.gd"
JOLT_PATCH = ROOT / "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
CORE = ROOT / "sdk/core/src/recovery_runtime.rs"
PHYSICAL_WORKER = ROOT / "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
PHYSICAL_RUNNER = ROOT / "sdk/run_qsdk_r24d68_godot_strict_actuator_budget.ps1"
QUALIFICATION_RUNNER = ROOT / "sdk/run_qsdk_r24d68_godot_strict_actuator_budget_zero_world_qualification.ps1"
SOURCE_MARKER = "QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_SOURCE_PASS"
SUPERVISOR_MARKER = "QSDK_R24D68_BEHAVIOR_SUPERVISOR "

require = r67.require
load = r67.load
markers = r67.markers

WORKER_SPECS = (
    {
        "id": "r63_historical_v1_telemetry_contract",
        "path": ROOT / "tests/test_sdk_qsdk_r24d63_godot_structured_motor_telemetry_failure_receipt_zero_world.gd",
        "marker": "QSDK_R24D63_GODOT_STRUCTURED_TELEMETRY_FAILURE_ZERO_WORLD ",
        "expected": {
            "ok": True, "positive_control_count": 4,
            "exact_failure_receipt_count": 22, "mutation_count": 22,
            "native_runtime_observation_collection_executed": False,
            "physical_question_opened": False,
        },
    },
    *r67.WORKER_SPECS,
    {
        "id": "r68_strict_actuator_budget",
        "path": ROOT / "tests/test_sdk_qsdk_r24d68_godot_strict_actuator_budget_zero_world.gd",
        "marker": "QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_ZERO_WORLD ",
        "expected": {
            "ok": True, "host_projection_control_count": 8,
            "rear_binary32_floor_guard_count": 2,
            "host_cap_not_above_published_count": 8,
            "strict_boundary_case_count": 8,
            "native_acceptance_count": 4, "native_rejection_count": 4,
            "core_acceptance_count": 4, "core_rejection_count": 4,
            "exact_diagnostic_count": 8, "native_core_agreement_count": 8,
            "nonfinite_rejection_count": 1,
            "identity_order_mutation_rejection_count": 6,
            "disagreement_mutation_rejection_count": 1,
            "native_runtime_observation_collection_executed": False,
            "physical_question_opened": False,
        },
    },
)


def _sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _git_text(commit: str, path: Path) -> str:
    relative = path.relative_to(ROOT).as_posix()
    return subprocess.run(
        ["git", "show", f"{commit}:{relative}"], cwd=ROOT,
        capture_output=True, text=True, encoding="utf-8", check=True,
    ).stdout


def _function_block(source: str, signature: str) -> str:
    start = source.index(signature)
    end = source.index("\n\n##", start)
    return source[start:end]


def _f32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", value))[0]


def _f32_bits(value: float) -> int:
    return struct.unpack("<I", struct.pack("<f", value))[0]


def validate_contract() -> dict[str, Any]:
    contract = load(CONTRACT)
    controls.validate_development_question(contract, "QSDK-R24D68")
    closed = controls.validate_bound_predecessor(ROOT, contract, PREDECESSOR)
    require(
        closed["closure_status"]
        == "closed_consumed_invalid_candidate_step_90_actuator_budget_predicate_mismatch",
        "R67_CLOSURE_STATUS",
    )
    require(closed["next_boundary"]["gate_id"] == "QSDK-R24D68", "R67_NEXT_GATE")

    change = contract["controlled_change"]
    controls.require_fields(change, {
        "host_cap_representation_mapping_changed": True,
        "native_motor_telemetry_contract_changed": True,
        "native_motor_telemetry_v1_rewritten": False,
        "strict_zero_tolerance_budget_predicate_added": True,
        "exact_rejected_budget_diagnostics_added": True,
        "raw_measurement_clamping_added": False,
        "published_actuator_profile_changed": False,
        "published_cap_changed": False,
        "portable_core_changed": False,
        "threshold_changed": False, "margin_changed": False,
        "controller_changed": False, "evaluator_changed": False,
        "behavior_worker_changed": True, "behavior_semantics_changed": False,
        "physical_supervisor_changed": False, "historical_result_rewritten": False,
    }, "CHANGE")

    population = contract["finite_development_population"]
    seed_label = "QSDK-R24D68/development/godot/exact-nominal-paired-v1"
    controls.validate_finite_development_envelope(
        contract, seed_label,
        {"maximum_outer_steps_per_arm": 1200, "maximum_total_outer_steps": 2400},
        {
            "profile_sha256": "sha256:3081621eb53f4d67bc1d8dc0f3a7d3ad7ae5ed829f902bce60b01ba1530bfb34",
            "maximum_energy_balance_residual_j": 0.25,
            "required_stance_dwell_steps": 60, "stance_dwell_timeout_steps": 240,
            "quaternion_norm_squared_tolerance": 1.0e-9,
            "threshold_change_count": 0, "margin_change_count": 0,
        },
        {
            "r68_host_projection_control_count": 8,
            "r68_rear_binary32_floor_guard_count": 2,
            "r68_strict_boundary_case_count": 8,
            "r68_native_core_agreement_count": 8,
            "r68_identity_order_mutation_rejection_count": 6,
            "r68_disagreement_mutation_rejection_count": 1,
            "supervisor_forced_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
        },
        {
            "maximum_model_construction_attempt_count": 2,
            "maximum_model_construction_count": 2,
            "maximum_world_attempt_count": 2, "maximum_world_build_count": 2,
            "maximum_outer_solver_steps": 2400, "physics_ticks_per_second": 120,
        },
    )
    require(population["cell_seed"] == 368340612, "SEED")

    projection = contract["host_cap_projection_contract"]
    published = projection["ordered_published_caps_nms"]
    nearest = [_f32(value) for value in published]
    configured = [
        value if value <= source
        else struct.unpack("<f", struct.pack("<I", _f32_bits(value) - 1))[0]
        for source, value in zip(published, nearest, strict=True)
    ]
    expected_hex = [f"0x{_f32_bits(value):08x}" for value in configured]
    require(nearest == projection["ordered_nearest_binary32_caps_nms"],
            "NEAREST_BINARY32")
    require(configured == projection["ordered_configured_host_caps_nms"],
            "CONFIGURED_BINARY32_FLOOR")
    require(expected_hex == projection["ordered_configured_binary32_hex"],
            "CONFIGURED_BINARY32_HEX")
    require(all(value <= source for source, value in
                zip(published, configured, strict=True)), "HOST_CAP_ABOVE_PUBLISHED")
    require(math.nextafter(published[4], math.inf) == 0.056373748293126996,
            "REAR_BINARY64_UPPER")
    require(math.nextafter(published[4], -math.inf) == 0.05637374829312698,
            "REAR_BINARY64_LOWER")
    require(projection["published_cap_changed"] is False
            and projection["empirical_margin_added"] is False
            and projection["raw_measurement_clamped"] is False,
            "PROJECTION_CLAIM")

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
        "short_native_instantiation_ghost_required": False,
    }, "GHOST")

    r67_inventory = set(load(
        ROOT / "sdk/recovery/r24d67_godot_portable_contact_identity_contract_v1.json"
    )["source_inventory"])
    delta = {
        "sdk/conformance/r24d68_godot_strict_actuator_budget.py",
        "sdk/recovery/r24d67_godot_portable_contact_identity_zero_world_qualification_closure_v1.json",
        "sdk/recovery/r24d67_godot_published_closure_authorization_control_closure_v1.json",
        "sdk/recovery/r24d67_godot_portable_contact_identity_behavior_invalid_closure_v1.json",
        "sdk/recovery/r24d68_godot_strict_actuator_budget_contract_v1.json",
        "sdk/run_qsdk_r24d68_godot_strict_actuator_budget_zero_world_qualification.ps1",
        "sdk/run_qsdk_r24d68_godot_strict_actuator_budget.ps1",
        "tests/test_sdk_qsdk_r24d68_godot_strict_actuator_budget_zero_world.gd",
    }
    inventory = contract["source_inventory"]
    require(set(inventory) == r67_inventory | delta, "SOURCE_INVENTORY_DELTA")
    controls.validate_exact_runtime_and_inventory(ROOT, contract, 116)
    return contract


def validate_sources() -> dict[str, int]:
    contract = validate_contract()
    parent = contract["authored_parent_commit"]
    world = WORLD.read_text(encoding="utf-8")
    parent_world = _git_text(parent, WORLD)
    v1_signature = "static func native_motor_telemetry_contract_v1("
    require(_function_block(world, v1_signature)
            == _function_block(parent_world, v1_signature),
            "HISTORICAL_V1_REWRITTEN")
    for unchanged in (BINDING, JOLT_PATCH, CORE):
        require(unchanged.read_text(encoding="utf-8")
                == _git_text(parent, unchanged), f"UNDECLARED_CHANGE:{unchanged.name}")

    markers(WORLD, (
        '"godot_jolt_binary32_floor_strict_published_impulse_cap_v1"',
        "static func strict_host_impulse_cap_projection_v1(",
        "configured_host_cap > published_cap_nms",
        "static func native_motor_telemetry_contract_v2(",
        "absolute_impulse <= maximum_outer_step_impulse_nms",
        '"effective_tolerance_nms": 0.0',
        '"raw_measurement_modified": false',
        "var telemetry_contract := native_motor_telemetry_contract_v2(",
    ))
    markers(ROUTE, (
        "NativeWorldScript.strict_host_impulse_cap_projection_v1(",
        '!= float(host_cap_projection["configured_host_maximum_impulse_nms"])',
        '"strict_host_cap_guard_receipt"',
    ))
    markers(CORE, (
        "if item.applied_angular_impulse_nms.abs() > cap.maximum_outer_step_impulse_nms",
        '"published_actuator_budget_exceeded:{}"',
    ))
    markers(PHYSICAL_WORKER, (
        '"all_in_run_physical_invariants_passed": true',
        '"strict_host_cap_projection_by_actuator_id"',
        "_model.get(\"host_cap_projection_by_actuator_id\", {})",
    ))
    prior_worker = _git_text(parent, PHYSICAL_WORKER).splitlines()
    current_worker = PHYSICAL_WORKER.read_text(encoding="utf-8").splitlines()
    diff = list(difflib.ndiff(prior_worker, current_worker))
    require(sum(line.startswith("+ ") for line in diff) == 10, "WORKER_ADD_SCOPE")
    require(sum(line.startswith("- ") for line in diff) == 0, "WORKER_DELETE_SCOPE")
    markers(PHYSICAL_RUNNER, (
        'GateId = "QSDK-R24D68"', 'PhysicalQuestionKind = "behavior_development"',
        "MaximumWorldBuildCount = 2", "MaximumOuterSolverSteps = 2400",
        "ExpectedBehaviorEvaluatorInvocationCount = 1", "& $shared @arguments",
    ))
    markers(QUALIFICATION_RUNNER, (
        "run_qsdk_core_zero_world_qualification.ps1", 'GateId = "QSDK-R24D68"',
        "ProspectivePhysicalQuestionDeclared = $true", "& $shared @arguments",
    ))
    require(world.count("var telemetry_contract := native_motor_telemetry_contract_v2(") == 1,
            "PRODUCTION_V2_CALL_COUNT")
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": 1,
        "current_zero_world_worker_count": len(WORKER_SPECS),
        "historical_closure_audits_executed_count": 0,
        "host_projection_control_count": 8,
        "rear_binary32_floor_guard_count": 2,
        "strict_boundary_case_count": 8,
        "native_core_agreement_count": 8,
        "identity_order_mutation_rejection_count": 6,
        "disagreement_mutation_rejection_count": 1,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    contract = load(CONTRACT)
    executable = Path(contract["exact_runtime"]["console_path"])
    receipts = controls.run_zero_world_worker_specs(ROOT, executable, WORKER_SPECS)
    r68_receipt = receipts["r68_strict_actuator_budget"]
    diagnostic = r68_receipt["r67_like_upward_binary32_rejection_diagnostic"]
    require(diagnostic["signed_motor_impulse_nms"] == 0.05637374892830849,
            "R67_LIKE_MEASUREMENT")
    require(diagnostic["absolute_budget_delta_nms"] == 6.351814976768289e-10,
            "R67_LIKE_DELTA")
    require(diagnostic["legacy_v1_budget_predicate_decision"] is True
            and diagnostic["native_v2_strict_budget_decision"] is False
            and diagnostic["projected_core_strict_budget_decision"] is False
            and diagnostic["raw_measurement_modified"] is False,
            "R67_LIKE_DIAGNOSTIC")
    supervisor = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D68")
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D68",
        "sporespore_qsdk_r24d68_missing_physical_switch_refusal_v1")
    controls.require_zero_authority(supervisor)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d68_godot_strict_actuator_budget_preflight_v1",
        "gate_id": "QSDK-R24D68", "ok": True,
        "runtime_id": "sporespore_qsdk_r24d68_godot_strict_actuator_budget_v1",
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
        print(f"QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
