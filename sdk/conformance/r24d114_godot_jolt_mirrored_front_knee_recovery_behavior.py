#!/usr/bin/env python3
"""Compact R114 finite-behavior declaration and production preflight."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    load,
    require,
    sha256,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)
from sdk.conformance.versioned_recovery_controller_target_gate import (  # noqa: E402
    validate_authored_delta,
    validate_source_inventory,
)

CONTRACT_RELATIVE_PATH = (
    "sdk/recovery/r24d114_godot_jolt_mirrored_front_knee_recovery_behavior_"
    "contract_v1.json"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d114_godot_jolt_mirrored_front_knee_recovery_"
    "behavior_contract_v1"
)
PROSPECTIVE_STATUS = (
    "prospective_finite_mirrored_front_knee_recovery_behavior_complete_zero_"
    "world_qualification_required_physics_blocked"
)
R113_STATUS = (
    "closed_complete_zero_world_versioned_mirrored_front_knee_controller_"
    "qualified_successor_physical_declaration_required"
)
PASS_MARKER = "QSDK_R24D114_GODOT_JOLT_MIRRORED_FRONT_KNEE_BEHAVIOR_SOURCE_PASS"
FAIL_MARKER = "QSDK_R24D114_GODOT_JOLT_MIRRORED_FRONT_KNEE_BEHAVIOR_SOURCE_FAIL"


def _verify_bound_json(
    binding: dict[str, object], status_key: str
) -> dict[str, object]:
    path = ROOT / str(binding["path"])
    raw = path.read_bytes()
    exact(len(raw), int(binding["byte_length"]), f"BOUND_LENGTH:{path.name}")
    exact(sha256(raw), binding["raw_sha256"], f"BOUND_HASH:{path.name}")
    value = load(path)
    expected_status = binding.get("closure_status", binding.get("status"))
    require(expected_status is not None, f"BOUND_STATUS_DECLARATION:{path.name}")
    exact(value[status_key], expected_status, f"BOUND_STATUS:{path.name}")
    return value


def validate_contract(contract: dict[str, object]) -> None:
    verify_exact_paths(
        contract,
        {
            "schema_version": CONTRACT_SCHEMA,
            "gate_id": "QSDK-R24D114",
            "status": PROSPECTIVE_STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": (
                "prospective_single_finite_mirrored_front_knee_behavior_" "development"
            ),
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "controlled_change.scientific_behavior_question_changed": True,
            "controlled_change.recovery_controller_changed": True,
            "controlled_change.target_pose_changed": True,
            "controlled_change.portable_command_changed": True,
            "controlled_change.changed_target_count": 2,
            "controlled_change.changed_target_indices": [1, 3],
            "controlled_change.physics_semantics_changed": False,
            "controlled_change.actuator_caps_changed": False,
            "controlled_change.actuator_mode_changed": False,
            "controlled_change.behavior_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.seed_value_changed_from_r24d111": False,
            "controlled_change.arm_order_changed": False,
            "controlled_change.horizon_changed": False,
            "controlled_change.held_out_cells_opened": False,
            "finite_development_population.cell_seed": 278151771,
            "finite_development_population.seed_sha256": (
                "sha256:b6d6311097c4616a2cfafc3abed5a77df923c04a07230c824ba668dc05c373b1"
            ),
            "finite_development_population.held_out": False,
            "finite_development_population.cell_count": 1,
            "finite_development_population.arm_count": 2,
            "finite_development_population.world_count": 2,
            "finite_development_population.ordered_arms": [
                "candidate_command",
                "matched_zero_command",
            ],
            "finite_development_population.maximum_world_attempt_count": 2,
            "finite_development_population.maximum_world_build_count": 2,
            "finite_development_population.maximum_total_outer_steps": 2400,
            "finite_development_population.maximum_outer_steps_per_arm": 1200,
            "finite_development_population.physics_ticks_per_second": 120,
            "finite_development_population.behavior_evaluator_invocation_count": 1,
            "finite_development_population.same_source_attempt_limit": 1,
            "finite_development_population.same_identity_rerun_permitted": False,
            "finite_development_population.recovery_success_required_for_valid_result": False,
            "behavior_execution_contract.recovery_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v2"
            ),
            "behavior_execution_contract.support_command_sha256": (
                "sha256:b2ac422515763c5c42acd5a6dcf943bb267f5a3ab4b234be783d83b4e284e2d9"
            ),
            "behavior_execution_contract.actuator_mode": (
                "force_based_order_neutral_joint_space_effective_inertia_"
                "native_angular_velocity_guarded_v3"
            ),
            "behavior_execution_contract.all_in_run_physical_invariants_required": True,
            "threshold_and_margin_provenance.threshold_change_count": 0,
            "threshold_and_margin_provenance.margin_change_count": 0,
            "threshold_and_margin_provenance.new_behavior_threshold_count": 0,
            "threshold_and_margin_provenance.held_out_cell_access_count": 0,
            "complete_zero_world_gate.must_pass_before_physics": True,
            "complete_zero_world_gate.official_qualification_must_start_clean_pushed_equal": True,
            "complete_zero_world_gate.official_qualification_attempt_limit_per_source_commit": 1,
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.additional_physical_ghost_count": 0,
            "complete_zero_world_gate.additional_physical_canary_count": 0,
            "complete_zero_world_gate.model_construction_count": 0,
            "complete_zero_world_gate.world_attempt_count": 0,
            "complete_zero_world_gate.world_build_count": 0,
            "complete_zero_world_gate.solver_step_count": 0,
            "complete_zero_world_gate.physics_state_modified": False,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "physical_authorization_projection.physical_execution_authorized": False,
            "physical_authorization_projection.maximum_world_attempt_count": 0,
            "physical_authorization_projection.maximum_solver_step_count": 0,
            "claim_boundary.zero_world_qualification_complete": False,
            "claim_boundary.physical_execution_authorized": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": False,
        },
        "R114_CONTRACT",
    )
    validate_source_inventory(ROOT, contract)
    validate_authored_delta(ROOT, contract)

    qualified = [str(item) for item in contract["qualified_physical_paths"]]
    exact(len(qualified), len(set(qualified)), "QUALIFIED_PHYSICAL_PATHS_UNIQUE")
    exact(len(qualified), 49, "QUALIFIED_PHYSICAL_PATHS_COUNT")
    require(
        set(qualified).issubset(set(contract["source_inventory"])),
        "QUALIFIED_PHYSICAL_PATHS_SOURCE_SUBSET",
    )
    require(
        not set(contract["authored_source_paths"]) - set(contract["source_inventory"]),
        "AUTHORED_SOURCE_INVENTORY_SUBSET",
    )

    predecessor = _verify_bound_json(contract["bound_predecessor"], "closure_status")
    verify_exact_paths(
        predecessor,
        {
            "gate_id": "QSDK-R24D113",
            "closure_status": R113_STATUS,
            "source.source_freeze_commit": ("f4a0e709860e8ff81cc2201c02c541445ff6339a"),
            "decision.complete_zero_world_gate_passed": True,
            "decision.physical_execution_authorized": False,
            "decision.r24d114_distinct_physical_declaration_required": True,
            "claim_boundary.versioned_mirrored_front_knee_controller_mechanics_qualified": True,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R113_PREDECESSOR",
    )
    bindings = contract["development_evidence_bindings"]
    exact(len(bindings), 2, "DEVELOPMENT_BINDING_COUNT")
    r111 = _verify_bound_json(bindings[0], "closure_status")
    verify_exact_paths(
        r111,
        {
            "gate_id": "QSDK-R24D111",
            "physical_attempt.status": "valid_complete_behavior_development",
            "physical_attempt.scientific_outcome": "negative",
            "physical_attempt.solver_step_count": 536,
            "physical_attempt.recovery_success_observed": False,
            "physical_attempt.prone_to_standing_claimed": False,
            "decision.same_identity_rerun_permitted": False,
        },
        "R111_BOUND_NEGATIVE",
    )
    r112 = _verify_bound_json(bindings[1], "status")
    verify_exact_paths(
        r112,
        {
            "gate_id": "QSDK-R24D112",
            "computed_projection.selected_front_knee_target_rad": -1.05,
            "computed_projection.selected_rear_knee_target_rad": 1.05,
            "computed_projection.execution_counts.world_attempt_count": 0,
            "decision.physical_execution_authorized": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R112_BOUND_DIAGNOSIS",
    )

    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d114_contract_path",
        expected={
            "r24d114_question_class_declared": True,
            "r24d114_question_class": "development",
            "r24d114_source_status": PROSPECTIVE_STATUS,
            "r24d114_physical_question_declared": True,
            "r24d114_physical_execution_authorized": False,
            "r24d114_contract_path": CONTRACT_RELATIVE_PATH,
            "r24d114_recovery_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v2"
            ),
            "r24d114_support_command_sha256": (
                "sha256:b2ac422515763c5c42acd5a6dcf943bb267f5a3ab4b234be783d83b4e284e2d9"
            ),
            "r24d114_seed": 278151771,
            "r24d114_seed_sha256": (
                "sha256:b6d6311097c4616a2cfafc3abed5a77df923c04a07230c824ba668dc05c373b1"
            ),
            "r24d114_declared_world_count": 2,
            "r24d114_maximum_outer_solver_steps": 2400,
            "r24d114_zero_world_qualification_required": True,
            "r24d114_zero_world_qualification_complete": False,
            "r24d114_r113_qualification_bound": True,
            "r24d114_additional_physical_ghost_count": 0,
            "r24d114_bespoke_physical_canary_count": 0,
            "r24d114_prone_to_standing_claimed": False,
            "r24d114_sdk1_milestone_advanced": False,
            "physical_execution_blocked_pending_r24d114_declaration": False,
            "physical_execution_blocked_until_r24d114_zero_world_qualification": True,
        },
        prefix="LIVE_R114_PROSPECTIVE",
    )


def run() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    try:
        contract = load(ROOT / CONTRACT_RELATIVE_PATH)
        validate_contract(contract)
        if args.core_library is None:
            runtime_version = "source_only"
        else:
            runtime = args.core_library.resolve()
            require(runtime.is_file(), "CORE_LIBRARY_MISSING")
            runtime_version = sha256(runtime.read_bytes())
        print(PASS_MARKER)
        print(
            json.dumps(
                {
                    "schema_version": (
                        "sporespore_qsdk_r24d114_mirrored_front_knee_behavior_"
                        "preflight_v1"
                    ),
                    "gate_id": "QSDK-R24D114",
                    "ok": True,
                    "runtime_id": "sporespore_locomotion_core_debug_dll",
                    "runtime_version": runtime_version,
                    "prospective_physical_question_declared": True,
                    "physical_execution_authorized": False,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "physics_state_modified": False,
                    "physical_question_opened": False,
                    "prone_to_standing_claimed": False,
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        return 0
    except (ClosureAuditError, KeyError, OSError, TypeError, ValueError) as error:
        print(f"{FAIL_MARKER}:{error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(run())
