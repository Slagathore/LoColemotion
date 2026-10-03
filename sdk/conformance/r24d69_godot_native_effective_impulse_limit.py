#!/usr/bin/env python3
"""Compact R69 inverse native-effective-limit audit over shared recovery controls."""

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
from sdk.conformance import r24d68_godot_strict_actuator_budget as r68  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d69_godot_native_effective_impulse_limit_contract_v1.json"
PREDECESSOR = ROOT / "sdk/recovery/r24d68_godot_strict_actuator_budget_behavior_invalid_closure_v1.json"
R68_CONTRACT = ROOT / "sdk/recovery/r24d68_godot_strict_actuator_budget_contract_v1.json"
R68_QUALIFICATION = ROOT / "sdk/recovery/r24d68_godot_strict_actuator_budget_zero_world_qualification_closure_v1.json"
R68_CONTROL = ROOT / "sdk/recovery/r24d68_godot_published_closure_authorization_control_closure_v1.json"
MAPPING_PROVENANCE = ROOT / "sdk/turning/r23d58_godot_terminal_trace_cap_factorial_zero_world_v1.json"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = ROOT / "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
BINDING = ROOT / "sdk/adapters/godot/gdscript/actuator_cap_profile_binding.gd"
JOLT_PATCH = ROOT / "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
CORE = ROOT / "sdk/core/src/recovery_runtime.rs"
PHYSICAL_WORKER = ROOT / "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
PHYSICAL_RUNNER = ROOT / "sdk/run_qsdk_r24d69_godot_native_effective_impulse_limit.ps1"
QUALIFICATION_RUNNER = ROOT / "sdk/run_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world_qualification.ps1"
SOURCE_MARKER = "QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_SOURCE_PASS"
SUPERVISOR_MARKER = "QSDK_R24D69_BEHAVIOR_SUPERVISOR "
NOMINAL_STEP = 1.0 / 120.0
NATIVE_STEP = 0.008333333767950535

require = r68.require
load = r68.load
markers = r68.markers

WORKER_SPECS = (
    *r68.WORKER_SPECS[:-1],
    {
        "id": "r69_native_effective_impulse_limit",
        "path": ROOT / "tests/test_sdk_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world.gd",
        "marker": "QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_ZERO_WORLD ",
        "expected": {
            "ok": True,
            "projection_control_count": 8,
            "native_effective_safe_count": 8,
            "adjacent_unsafe_count": 8,
            "binary32_maximality_count": 8,
            "source_algebra_identity_count": 8,
            "production_route_projection_count": 8,
            "production_route_safe_readback_count": 8,
            "identity_mutation_rejection_count": 4,
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
        ["git", "show", f"{commit}:{relative}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    ).stdout


def _function_block(source: str, signature: str) -> str:
    start = source.index(signature)
    end = source.index("\n\n##", start)
    return source[start:end]



def validate_contract() -> dict[str, Any]:
    contract = load(CONTRACT)
    controls.validate_development_question(contract, "QSDK-R24D69")
    controls.require_fields(
        contract["ledger_scope"],
        {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "prospective_development_contract",
            "question_class": "development",
        },
        "LEDGER_SCOPE",
    )
    require(
        contract["authored_parent_commit"]
        == "c1df9320ce6074017efe2081cfa350301c816622",
        "AUTHORED_PARENT",
    )
    closed = controls.validate_bound_predecessor(ROOT, contract, PREDECESSOR)
    require(
        closed["closure_status"]
        == "closed_consumed_invalid_candidate_step_90_one_binary32_ulp_native_effective_limit_reexpansion",
        "R68_CLOSURE_STATUS",
    )
    require(closed["next_boundary"]["gate_id"] == "QSDK-R24D69", "R68_NEXT_GATE")

    change = contract["controlled_change"]
    controls.require_fields(
        change,
        {
            "native_effective_impulse_limit_projection_added": True,
            "r68_projection_rewritten": False,
            "r68_strict_budget_predicate_changed": False,
            "native_motor_telemetry_contract_changed": False,
            "native_physics_or_jolt_patch_changed": False,
            "portable_core_changed": False,
            "published_actuator_profile_changed": False,
            "published_cap_changed": False,
            "raw_measurement_clamping_added": False,
            "controller_changed": False,
            "threshold_changed": False,
            "margin_changed": False,
            "evaluator_changed": False,
            "behavior_worker_changed": False,
            "physical_supervisor_changed": False,
            "historical_result_rewritten": False,
        },
        "CHANGE",
    )

    mapping = load(MAPPING_PROVENANCE)["godot_jolt_host_semantics_provenance"]
    provenance = contract["native_numeric_source_provenance"]
    controls.require_fields(
        provenance,
        {
            "godot_mapping_authority_path": MAPPING_PROVENANCE.relative_to(ROOT).as_posix(),
            "godot_mapping_authority_raw_sha256": _sha256(MAPPING_PROVENANCE),
            "upstream_tag_commit": mapping["upstream_tag_commit"],
            "godot_source_path": mapping["source_path"],
            "godot_source_raw_sha256": mapping["source_raw_sha256"],
            "godot_set_mapping": mapping["set_mapping"],
            "jolt_patch_path": JOLT_PATCH.relative_to(ROOT).as_posix(),
            "jolt_patch_raw_sha256": _sha256(JOLT_PATCH),
            "jolt_patch_byte_length": JOLT_PATCH.stat().st_size,
            "jolt_solver_limit_formula": (
                "float32(native_solver_step_s * native_maximum_torque_limit_nm)"
            ),
            "nominal_host_conversion_step_s": NOMINAL_STEP,
            "native_solver_step_s": NATIVE_STEP,
            "native_solver_step_binary32_hex": "0x3c088889",
            "empirical_source": False,
        },
        "PROVENANCE",
    )
    require(controls.binary32(NOMINAL_STEP) == NATIVE_STEP, "NATIVE_STEP")

    projection = contract["native_effective_impulse_limit_projection_contract"]
    controls.validate_binary32_native_effective_limit_population(
        projection, NOMINAL_STEP, NATIVE_STEP
    )
    controls.require_fields(
        projection,
        {
            "selected_effective_limit_not_above_published_count": 8,
            "immediately_higher_effective_limit_above_published_count": 8,
            "binary32_maximality_proof_count": 8,
            "published_cap_changed": False,
            "empirical_margin_added": False,
            "raw_measurement_clamped": False,
        },
        "PROJECTION",
    )
    seed_label = "QSDK-R24D69/development/godot/exact-nominal-paired-v1"
    controls.validate_finite_development_envelope(
        contract,
        seed_label,
        {"maximum_outer_steps_per_arm": 1200, "maximum_total_outer_steps": 2400},
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
            "r69_projection_control_count": 8,
            "r69_native_effective_safe_count": 8,
            "r69_adjacent_unsafe_count": 8,
            "r69_binary32_maximality_count": 8,
            "r69_source_algebra_identity_count": 8,
            "r69_production_route_projection_count": 8,
            "r69_production_route_safe_readback_count": 8,
            "r69_identity_mutation_rejection_count": 4,
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
    require(contract["finite_development_population"]["cell_seed"] == 739575220, "SEED")

    controls.require_fields(
        contract["critical_path_audit_policy"],
        {
            "complete_current_source_population_content_addressed": True,
            "exact_predecessor_closure_digest_bound": True,
            "current_zero_world_worker_count": len(WORKER_SPECS),
            "historical_closure_audits_executed_count": 0,
            "historical_closure_results_reinterpreted_count": 0,
            "unrelated_historical_regression_sweep_required_in_campaign_critical_path": False,
            "scheduled_historical_regression_cadence_replaced_or_waived": False,
        },
        "AUDIT_POLICY",
    )
    controls.require_fields(
        contract["ghost_and_canary_adequacy"],
        {
            "additional_physical_route_ghost_required": False,
            "full_seeded_physical_ghost_required": False,
            "forced_failure_zero_world_control_required": True,
            "short_native_instantiation_ghost_required": False,
        },
        "GHOST",
    )

    r68_inventory = set(load(R68_CONTRACT)["source_inventory"])
    delta = {
        R68_QUALIFICATION.relative_to(ROOT).as_posix(),
        R68_CONTROL.relative_to(ROOT).as_posix(),
        PREDECESSOR.relative_to(ROOT).as_posix(),
        "sdk/conformance/r24d69_godot_native_effective_impulse_limit.py",
        "sdk/recovery/r24d69_godot_native_effective_impulse_limit_contract_v1.json",
        "sdk/run_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world_qualification.ps1",
        "sdk/run_qsdk_r24d69_godot_native_effective_impulse_limit.ps1",
        "tests/test_sdk_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world.gd",
    }
    require(set(contract["source_inventory"]) == r68_inventory | delta,
            "SOURCE_INVENTORY_DELTA")
    controls.validate_exact_runtime_and_inventory(ROOT, contract, 124)
    return contract


def validate_sources() -> dict[str, int]:
    contract = validate_contract()
    parent = contract["authored_parent_commit"]
    world = WORLD.read_text(encoding="utf-8")
    route = ROUTE.read_text(encoding="utf-8")
    parent_world = _git_text(parent, WORLD)
    for signature in (
        "static func strict_host_impulse_cap_projection_v1(",
        "static func native_motor_telemetry_contract_v2(",
    ):
        require(_function_block(world, signature) == _function_block(parent_world, signature),
                f"R68_SOURCE_BLOCK_REWRITTEN:{signature}")
    for unchanged in (BINDING, JOLT_PATCH, CORE, PHYSICAL_WORKER):
        require(
            unchanged.read_text(encoding="utf-8") == _git_text(parent, unchanged),
            f"UNDECLARED_CHANGE:{unchanged.name}",
        )

    markers(
        WORLD,
        (
            '"godot_jolt_binary32_native_effective_impulse_limit_inverse_projection_v1"',
            "static func native_effective_impulse_limit_projection_v1(",
            "for decrement in range(4):",
            "candidate_host_cap / OUTER_STEP_DURATION_S",
            "candidate_torque * native_solver_step",
            "next_projected_native_effective_limit <= published_cap_nms",
            '"configured_to_next_binary32_ulp_distance": 1',
            '"native_effective_limit_not_above_published"',
        ),
    )
    markers(
        ROUTE,
        (
            "NativeWorldScript.native_effective_impulse_limit_projection_v1(",
            '"native_effective_limit_not_above_published"',
            '"sporespore_qsdk_r24d69_godot_native_effective_limit_guard_receipt_v1"',
        ),
    )
    markers(
        JOLT_PATCH,
        (
            "mMotorTelemetryMaxTorqueLimit = mMotorSettings.mMaxTorqueLimit;",
            (
                "inDeltaTime * mMotorSettings.mMinTorqueLimit, "
                "inDeltaTime * mMotorSettings.mMaxTorqueLimit"
            ),
        ),
    )
    markers(
        PHYSICAL_RUNNER,
        (
            'GateId = "QSDK-R24D69"',
            'PhysicalQuestionKind = "behavior_development"',
            "MaximumWorldBuildCount = 2",
            "MaximumOuterSolverSteps = 2400",
            "ExpectedBehaviorEvaluatorInvocationCount = 1",
            "& $shared @arguments",
        ),
    )
    markers(
        QUALIFICATION_RUNNER,
        (
            "run_qsdk_core_zero_world_qualification.ps1",
            'GateId = "QSDK-R24D69"',
            "ProspectivePhysicalQuestionDeclared = $true",
            "& $shared @arguments",
        ),
    )
    require(world.count("native_effective_impulse_limit_projection_v1(") == 2,
            "WORLD_R69_CALL_COUNT")
    require(route.count("native_effective_impulse_limit_projection_v1(") == 2,
            "ROUTE_R69_CALL_COUNT")
    require(route.count("strict_host_impulse_cap_projection_v1(") == 0,
            "ROUTE_R68_CALL_RETAINED")
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": 1,
        "current_zero_world_worker_count": len(WORKER_SPECS),
        "historical_closure_audits_executed_count": 0,
        "projection_control_count": 8,
        "native_effective_safe_count": 8,
        "adjacent_unsafe_count": 8,
        "binary32_maximality_count": 8,
        "source_algebra_identity_count": 8,
        "production_route_projection_count": 8,
        "production_route_safe_readback_count": 8,
        "identity_mutation_rejection_count": 4,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    contract = load(CONTRACT)
    executable = Path(contract["exact_runtime"]["console_path"])
    receipts = controls.run_zero_world_worker_specs(ROOT, executable, WORKER_SPECS)
    r69_receipt = receipts["r69_native_effective_impulse_limit"]
    rear = r69_receipt["ordered_projection_receipts"][4]
    require(
        rear["configured_host_cap_binary32_hex"] == "0x3d66e827"
        and rear["projected_native_torque_limit_binary32_hex"] == "0x40d879a5"
        and rear["projected_native_effective_limit_binary32_hex"] == "0x3d66e828"
        and rear["next_binary32_host_cap_binary32_hex"] == "0x3d66e828"
        and rear["next_native_effective_limit_above_published"] is True,
        "REAR_PROJECTION_RECEIPT",
    )
    supervisor = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D69"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D69",
        "sporespore_qsdk_r24d69_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(supervisor)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": (
            "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_preflight_v1"
        ),
        "gate_id": "QSDK-R24D69",
        "ok": True,
        "runtime_id": "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_v1",
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
        counts = validate_sources()
        print(SOURCE_MARKER, " ".join(f"{key}={value}" for key, value in counts.items()))
        return 0
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
        print(
            f"QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
