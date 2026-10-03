#!/usr/bin/env python3
"""Compact R87 source audit and zero-world qualification preflight."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import platform
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    load,
    matching_evidence_roots,
    resolve_prospective_source_freeze,
    sha256,
    source_bytes,
    verify_bound_source_markers,
    verify_declared_source_inventory,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_retained_file_tree,
    verify_source_receipt_manifest,
)

CONTRACT = (
    ROOT / "sdk/recovery/r24d87_godot_force_based_recovery_actuator_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d87_godot_force_based_recovery_actuator_"
    "zero_world_qualification_closure_v1.json"
)
R86 = (
    ROOT
    / "sdk/recovery/r24d86_godot_jolt_raise_body_control_and_energy_diagnosis_v1.json"
)
R57 = ROOT / "sdk/recovery/r24d57_godot_jolt_native_recovery_route_contract_v1.json"
SOURCE_MARKER = "QSDK_R24D87_GODOT_FORCE_BASED_RECOVERY_ACTUATOR_SOURCE_PASS"
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d87_godot_force_based_recovery_actuator_contract_v1"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d87_godot_force_based_recovery_actuator_"
    "zero_world_qualification_closure_v1"
)
CLOSURE_GIT_BLOB_BYTE_LENGTH = 8522
CLOSURE_GIT_BLOB_RAW_SHA256 = (
    "sha256:47a1b02f3d830ab03f104baf5cf1786e9c1c43bbb27839daada42e4581b4d446"
)


def _verify_r86(contract: dict[str, Any]) -> None:
    declaration = contract["bound_predecessor"]
    raw = R86.read_bytes()
    exact(
        (len(raw), sha256(raw)),
        (declaration["byte_length"], declaration["raw_sha256"]),
        "R86_BYTES",
    )
    report = json.loads(raw)
    verify_exact_paths(
        report,
        {
            "gate_id": "QSDK-R24D86",
            "closure_status": declaration["closure_status"],
            "decision.r87_distinct_adapter_successor_required": True,
            "decision.r87_controller_change_permitted": False,
            "decision.r87_pose_or_ramp_change_permitted": False,
            "decision.r87_threshold_change_permitted": False,
            "decision.r87_actuator_cap_change_permitted": False,
            "decision.r87_evaluator_change_permitted": False,
            "decision.r87_adapter_actuator_mapping_change_required": True,
            "decision.r87_actuator_work_source_change_required": True,
            "decision.r87_residual_balancing_permitted": False,
            "decision.physical_execution_authorized": False,
            "next_boundary.gate_id": "QSDK-R24D87",
            "next_boundary.physical_question_declared": False,
            "next_boundary.mapping_contract.velocity_error_gain_nm_s_per_rad": 10.0,
            "next_boundary.mapping_contract.hard_constraint_velocity_motor_disabled_for_recovery_route": True,
            "next_boundary.physical_execution_blocked": True,
        },
        "R86",
    )


def _verify_native_runtime(contract: dict[str, Any]) -> None:
    declaration = contract["native_runtime"]
    path = Path(str(declaration["path"]))
    raw = path.read_bytes()
    exact(len(raw), declaration["byte_length"], "GODOT_RUNTIME_LENGTH")
    exact(sha256(raw), declaration["raw_sha256"], "GODOT_RUNTIME_HASH")


def _verify_published_closure(contract: dict[str, Any], source_commit: str) -> None:
    closure_raw = CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    exact(
        (len(closure_raw), sha256(closure_raw)),
        (CLOSURE_GIT_BLOB_BYTE_LENGTH, CLOSURE_GIT_BLOB_RAW_SHA256),
        "R87_CLOSURE_GIT_BLOB",
    )
    closure = json.loads(closure_raw)
    verify_exact_paths(
        closure,
        {
            "schema_version": CLOSURE_SCHEMA,
            "gate_id": "QSDK-R24D87",
            "closure_status": (
                "closed_complete_zero_world_force_based_recovery_actuator_"
                "mapping_qualified_physics_blocked"
            ),
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": False,
            "source.commit": source_commit,
            "source.source_freeze_commit": source_commit,
            "source.source_manifest_entry_count": 45,
            "qualification_evidence.official_attempt_count": 1,
            "qualification_evidence.exact_source_attempt_count": 1,
            "qualification.ok": True,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "qualification.physics_state_modified": False,
            "qualification.physical_question_opened": False,
            "decision.r87_mapping_implemented": True,
            "decision.r87_complete_zero_world_gate_passed": True,
            "decision.r87_zero_world_qualified": True,
            "decision.production_route_constructed_or_stepped": False,
            "decision.controller_physical_viability_proven": False,
            "decision.recovery_success_observed": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "decision.physical_execution_authorized": False,
            "decision.physical_acceptance_authority": False,
            "decision.release_authority": False,
            "next_boundary.gate_id": "QSDK-R24D88",
            "next_boundary.question_class": "development",
            "next_boundary.physical_question_declared": False,
            "next_boundary.full_seeded_ghost_required": False,
            "next_boundary.additional_seed_required": False,
            "next_boundary.physical_execution_blocked": True,
            "next_boundary.maximum_world_attempt_count": 0,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "R87_CLOSURE",
    )

    evidence = closure["qualification_evidence"]
    evidence_root = Path(str(evidence["root"])).resolve()
    exact(
        matching_evidence_roots(
            evidence_root.parent,
            "qsdk-r24d87-godot-force-based-recovery-actuator-qualification-",
            "qualification_attempt.json",
            "QSDK-R24D87",
            source_commit,
        ),
        [evidence_root],
        "R87_EXACT_SOURCE_ATTEMPT_ROOTS",
    )
    verify_retained_file_tree(evidence_root, evidence["retained_file_tree"])

    attempt = load(evidence_root / evidence["qualification_attempt_path"])
    verify_exact_paths(
        attempt,
        {
            "gate_id": "QSDK-R24D87",
            "mode": "qualification",
            "source_commit": source_commit,
            "upstream_commit": source_commit,
            "live_remote_commit": source_commit,
            "worktree_clean_at_start": True,
            "operation_lock.acquired": True,
            "operation_lock.role": "conformance",
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "prospective_physical_question_declared": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "R87_ATTEMPT",
    )

    receipt_path = evidence_root / evidence["qualification_receipt_path"]
    receipt_raw = receipt_path.read_bytes()
    exact(
        len(receipt_raw),
        evidence["qualification_receipt_byte_length"],
        "R87_RECEIPT_LENGTH",
    )
    exact(
        sha256(receipt_raw),
        evidence["qualification_receipt_raw_sha256"],
        "R87_RECEIPT_HASH",
    )
    receipt = json.loads(receipt_raw)
    verify_exact_paths(
        receipt,
        {
            "gate_id": "QSDK-R24D87",
            "mode": "qualification",
            "ok": True,
            "source_commit": source_commit,
            "upstream_commit": source_commit,
            "live_remote_commit": source_commit,
            "operation_lock.acquired": True,
            "operation_lock.role": "conformance",
            "operation_lock_released": True,
            "declared_question_class": "development",
            "prospective_physical_question_declared": False,
            "held_out_cell_access_count": 0,
            "held_out_selector_invocation_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "controller_physical_viability_proven": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "R87_RECEIPT",
    )
    exact(
        receipt["checks"],
        {
            "core_dynamic_library_rebuilt": True,
            "core_targeted_tests_passed": True,
            "godot_adapter_binding_check_passed": True,
            "godot_adapter_debug_build_passed": True,
            "godot_production_worker_parse_passed": True,
            "native_zero_world_gate_passed": True,
            "python_binding_smoke_passed": True,
            "versioning_conformance_passed": True,
            "source_contract_audit_passed": True,
            "production_preflight_passed": True,
            "worktree_unchanged": True,
        },
        "R87_RECEIPT_CHECKS",
    )
    verify_exact_paths(
        receipt["native_zero_world"],
        {
            "projection_control_count": 8,
            "retained_receipt_validation_count": 8,
            "equal_and_opposite_count": 8,
            "published_cap_respected_count": 8,
            "positive_sign_count": 4,
            "negative_sign_count": 4,
            "saturation_count": 4,
            "representation_projection_count": 2,
            "centered_work_control_count": 8,
            "positive_work_count": 6,
            "absorbed_work_count": 2,
            "zero_error_control": True,
            "invalid_projection_rejection_count": 8,
            "retained_receipt_mutation_rejection_count": 4,
            "invalid_work_rejection_count": 5,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "R87_NATIVE_ZERO_WORLD_RECEIPT",
    )
    exact(len(receipt["source_manifest"]), 45, "R87_RECEIPT_SOURCE_COUNT")
    verify_source_receipt_manifest(
        ROOT,
        source_commit,
        receipt["source_manifest"],
        raw_representation="observed_checkout_plus_git_blob",
    )


def _verify_live_authority(published: bool, contract: dict[str, Any]) -> None:
    if published:
        expected = {
            "r24d87_distinct_successor_required": False,
            "r24d87_question_class": "development",
            "r24d87_physical_question_declared": False,
            "r24d87_source_status": (
                "closed_complete_zero_world_force_based_recovery_actuator_"
                "mapping_qualified_physics_blocked"
            ),
            "r24d87_mapping_implemented": True,
            "r24d87_zero_world_qualified": True,
            "r24d87_contract_path": (
                "sdk/recovery/"
                "r24d87_godot_force_based_recovery_actuator_contract_v1.json"
            ),
            "r24d87_contract_byte_length": 11912,
            "r24d87_contract_raw_sha256": (
                "sha256:cf562c1b9317a6ed79c1f60a6a7ad2d8f79b80ab54f20ca56c102d"
                "de964dd7f0"
            ),
            "r24d87_source_commit": (
                "b77d1aa0261177ffff8a9ffbde8391f0dc0d6ab1"
            ),
            "r24d87_qualification_closure_path": (
                "sdk/recovery/r24d87_godot_force_based_recovery_actuator_"
                "zero_world_qualification_closure_v1.json"
            ),
            "r24d87_qualification_closure_byte_length": (
                CLOSURE_GIT_BLOB_BYTE_LENGTH
            ),
            "r24d87_qualification_closure_raw_sha256": (
                CLOSURE_GIT_BLOB_RAW_SHA256
            ),
            "r24d87_qualification_evidence_root": (
                "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
                "qsdk-r24d87-godot-force-based-recovery-actuator-"
                "qualification-20260831T093945244Z-b77d1aa0"
            ),
            "r24d87_official_qualification_attempt_count": 1,
            "r24d87_source_inventory_count": 45,
            "r24d87_model_construction_count": 0,
            "r24d87_world_attempt_count": 0,
            "r24d87_world_build_count": 0,
            "r24d87_solver_step_count": 0,
            "r24d87_physical_execution_authorized": False,
            "r24d87_sdk1_milestone_advanced": False,
            "physical_execution_blocked_pending_r24d87_declaration": False,
            "physical_execution_blocked_until_r24d87_zero_world_qualification": False,
            "held_out_cells_remain_sealed": True,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    else:
        expected = {
            "r24d86_diagnosis_closed": True,
            "r24d87_distinct_successor_required": True,
            "r24d87_question_class": "development",
            "r24d87_physical_question_declared": False,
            "physical_execution_blocked_pending_r24d87_declaration": True,
            "physical_execution_blocked_until_r24d87_zero_world_qualification": True,
            "held_out_cells_remain_sealed": True,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    verify_legacy_live_authority_projection(
        ROOT,
        contract["live_authority_paths"],
        record_key="r24d86_diagnosis_closed",
        expected=expected,
        prefix="R87_LIVE",
    )


def audit() -> tuple[str, bool]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": CONTRACT_SCHEMA,
            "gate_id": "QSDK-R24D87",
            "question_class": "development",
            "physical_question_declared": False,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "controlled_change.recovery_only_godot_adapter_mapping_changed": True,
            "controlled_change.portable_controller_changed": False,
            "controlled_change.canonical_target_changed": False,
            "controlled_change.pose_ramp_timeout_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.published_actuator_cap_changed": False,
            "controlled_change.recovery_evaluator_changed": False,
            "controlled_change.recovery_morphology_changed": False,
            "controlled_change.initializer_changed": False,
            "controlled_change.turning_or_non_recovery_route_changed": False,
            "mapping_contract.velocity_error_gain_nm_s_per_rad": 10.0,
            "mapping_contract.hard_constraint_velocity_motor_enabled_count": 0,
            "mapping_contract.axis_unit_length_squared_tolerance": 9.5367431640625e-7,
            "mapping_contract.maximum_representation_projection_iterations": 16,
            "mapping_contract.representation_projection_is_empirical_margin": False,
            "mapping_contract.mechanical_energy_residual_used_as_work_source": False,
            "threshold_margin_cohort_and_population_adequacy.new_physical_threshold_count": 0,
            "threshold_margin_cohort_and_population_adequacy.new_equivalence_margin_count": 0,
            "threshold_margin_cohort_and_population_adequacy.new_physical_cohort_count": 0,
            "threshold_margin_cohort_and_population_adequacy.population_claim_count": 0,
            "complete_zero_world_gate.projection_control_count": 8,
            "complete_zero_world_gate.retained_receipt_validation_count": 8,
            "complete_zero_world_gate.equal_and_opposite_count": 8,
            "complete_zero_world_gate.published_cap_respected_count": 8,
            "complete_zero_world_gate.invalid_projection_rejection_count": 8,
            "complete_zero_world_gate.retained_receipt_mutation_rejection_count": 4,
            "complete_zero_world_gate.invalid_work_rejection_count": 5,
            "complete_zero_world_gate.production_worker_parse_count": 1,
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.model_construction_count": 0,
            "complete_zero_world_gate.world_attempt_count": 0,
            "complete_zero_world_gate.world_build_count": 0,
            "complete_zero_world_gate.solver_step_count": 0,
            "physical_authorization_projection.physical_execution_authorized": False,
            "physical_authorization_projection.maximum_physical_steps_authorized": 0,
            "claim_boundary.complete_zero_world_gate_passed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
        },
        "CONTRACT",
    )
    exact(len(contract["authored_source_paths"]), 8, "AUTHORED_PATH_COUNT")
    exact(len(contract["source_inventory"]), 45, "SOURCE_INVENTORY_COUNT")
    verify_declared_source_inventory(ROOT, contract["source_inventory"])
    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=CLOSURE_SCHEMA,
        gate_id="QSDK-R24D87",
    )

    marker_paths = (
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
        "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd",
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd",
        "tests/test_sdk_qsdk_r24d87_godot_force_based_recovery_actuator_zero_world.gd",
        "sdk/run_qsdk_core_zero_world_qualification.ps1",
        "sdk/run_qsdk_r24d87_godot_force_based_recovery_actuator_zero_world_qualification.ps1",
        "sdk/core/src/recovery_runtime.rs",
        "sdk/adapters/rapier/src/velocity_only_live_integration.rs",
        "sdk/adapters/rapier/src/qsdk_r24d45_recovery_route.rs",
    )
    bound = {path: source_bytes(ROOT, source_commit, path) for path in marker_paths}
    verify_bound_source_markers(
        bound,
        {
            marker_paths[0]: (
                "godot_jolt_r24d87_source_measured_force_based_joint_impulse_v1",
                "FORCE_BASED_VELOCITY_ERROR_GAIN_NM_S_PER_RAD := 10.0",
                "force_based_joint_impulse_projection_v1",
                "validate_force_based_joint_impulse_projection_v1",
                "force_based_joint_work_projection_v1",
                'mechanical_energy_residual_used_as_work_source": false',
            ),
            marker_paths[1]: (
                "apply_behavior_control_force_based_v2",
                "RigidBody3D.apply_torque_impulse",
                'hard_constraint_motor_target_write_count": 0',
                'body_impulse_write_count": 16',
            ),
            marker_paths[2]: (
                "apply_behavior_control_force_based_v2",
                "FORCE_BASED_ACTUATOR_MAPPING_ID",
                'body_impulse_write_count", -1)) == 16',
            ),
            marker_paths[3]: (
                "projection_control_count == 8",
                "representation_projection_count == 2",
                "invalid_projection_rejection_count == 8",
                "retained_receipt_mutation_rejection_count == 4",
                "invalid_work_rejection_count == 5",
            ),
            marker_paths[4]: (
                "NativeZeroWorldScriptRelativePath",
                "--check-only --script",
                "native_zero_world_gate_passed",
            ),
            marker_paths[5]: (
                "QSDK-R24D87",
                "QSDK_R24D87_GODOT_FORCE_BASED_RECOVERY_ACTUATOR_ZERO_WORLD ",
            ),
            marker_paths[6]: (
                "const STANCE_TARGETS_RAD: [f64; 8] = [0.0; 8];",
                "const RAISE_BODY_RAMP_STEPS: u32 = 360;",
                "minimum_com_height_gain_m: 0.22",
                "maximum_energy_balance_residual_j: 0.25",
            ),
            marker_paths[7]: (
                "VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD: f32 = 10.0",
                "MotorModel::ForceBased",
            ),
            marker_paths[8]: (
                "let centered_velocity_rad_s =",
                "let actuator_work_j = signed_impulse_nms * centered_velocity_rad_s;",
            ),
        },
        "R87_SOURCE",
    )

    r57 = load(R57)
    verify_exact_paths(
        r57,
        {
            "energy_mapping_provenance.unclosed_residual_preserved": True,
            "energy_mapping_provenance.mechanical_energy_residual_used_as_work_source": False,
            "energy_mapping_provenance.constraint_and_passive_partition_claimed_complete": False,
            "energy_mapping_provenance.physical_energy_balance_claimed_by_this_gate": False,
        },
        "R57_ENERGY",
    )
    _verify_r86(contract)
    _verify_native_runtime(contract)
    if published:
        _verify_published_closure(contract, source_commit)
    _verify_live_authority(published, contract)
    return source_commit, published


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library")
    args = parser.parse_args()
    try:
        source_commit, published = audit()
        print(SOURCE_MARKER)
        if args.core_library:
            library = Path(args.core_library)
            raw = library.read_bytes()
            print(
                json.dumps(
                    {
                        "schema_version": "sporespore_qsdk_r24d87_source_preflight_v1",
                        "gate_id": "QSDK-R24D87",
                        "ok": True,
                        "runtime_id": "python_source_and_shared_native_zero_world_preflight",
                        "runtime_version": platform.python_version(),
                        "source_commit": source_commit,
                        "publication_closure_present": published,
                        "core_library_byte_length": len(raw),
                        "core_library_raw_sha256": sha256(raw),
                        "native_zero_world_execution_delegated_to_shared_runner": True,
                        "production_worker_parse_delegated_to_shared_runner": True,
                        "historical_closure_audits_executed_count": 0,
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
    except (ClosureAuditError, KeyError, OSError, ValueError) as error:
        print(f"QSDK_R24D87_GODOT_FORCE_BASED_RECOVERY_ACTUATOR_SOURCE_FAIL:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
