#!/usr/bin/env python3
"""Reusable closure audit for a versioned recovery-controller qualification."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    load,
    require,
    sha256,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)


@dataclass(frozen=True)
class VersionedRecoveryControllerQualificationSpec:
    gate_id: str
    authority_prefix: str
    source_commit: str
    source_subject: str
    closure_relative_path: str
    closure_schema: str
    qualified_status: str
    closure_authority_mode: str
    predecessor_status: str
    attempt_schema: str
    receipt_schema: str
    qualification_directory_prefix: str
    source_audit_marker: str
    native_zero_world_marker: str
    source_inventory_count: int
    authored_source_path_count: int
    prospective_status: str
    change_kind: str
    historical_controller_id: str
    successor_controller_id: str
    historical_profile_sha256: str
    successor_profile_sha256: str
    historical_command_sha256: str
    successor_command_sha256: str
    changed_indices: tuple[int, ...]
    historical_regression_receipt_field: str
    historical_regression_qualification_field: str
    preserved_receipt_field: str
    preflight_schema: str
    core_runtime_sha256: str
    qualified_claim_field: str
    adequacy_field: str
    decision_result: str
    next_gate_id: str
    next_declaration_required_field: str
    historical_maximum_target_speed_rad_s: float | None = None
    successor_maximum_target_speed_rad_s: float | None = None
    raise_body_phase_steps: tuple[int, ...] = ()
    historical_raise_command_sha256: tuple[str, ...] = ()
    successor_raise_command_sha256: tuple[str, ...] = ()
    command_mutation_refusal_count: int = 0
    historical_preservation_contract_field: str = "historical_v1_v3_preserved"
    historical_actuator_mode: str | None = None
    successor_actuator_mode: str | None = None
    historical_actuation_realization_id: str | None = None
    successor_actuation_realization_id: str | None = None
    realization_mismatch_refusal_count: int = 0
    production_worker_pairing_control_count: int = 0
    additional_checkout_only_paths: tuple[str, ...] = ()


EXPECTED_CHECKS = (
    "source_manifest_frozen",
    "core_dynamic_library_rebuilt",
    "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed",
    "godot_adapter_debug_build_passed",
    "godot_production_worker_parse_passed",
    "native_zero_world_gate_passed",
    "python_binding_smoke_passed",
    "versioning_conformance_passed",
    "source_contract_audit_passed",
    "production_preflight_passed",
    "worktree_unchanged",
)
CHECKOUT_ONLY_PATHS = (
    "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd",
    "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
    "sdk/python/test_ctypes_smoke.py",
    "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd",
)
SOURCE_BINDING_NAMES = (
    "source_audit",
    "versioned_controller_gate",
    "shared_closure_helper",
    "qualification_runner",
    "native_zero_world_test",
    "production_worker",
)
GODOT_RUNTIME_SHA256 = (
    "sha256:19dc32b39400d200b5e5273f541ac41aa72a82110bb2fd338726a7fd465e0fa8"
)


def _contract_expectations(
    spec: VersionedRecoveryControllerQualificationSpec,
) -> dict[str, Any]:
    expected: dict[str, Any] = {
        "status": spec.prospective_status,
        "question_class": "development",
        "physical_question_declared": False,
        "controller_version_contract.change_kind": spec.change_kind,
        "controller_version_contract.historical_controller_id": (
            spec.historical_controller_id
        ),
        "controller_version_contract.successor_controller_id": (
            spec.successor_controller_id
        ),
        "controller_version_contract.historical_controller_profile_sha256": (
            spec.historical_profile_sha256
        ),
        "controller_version_contract.successor_controller_profile_sha256": (
            spec.successor_profile_sha256
        ),
        "controller_version_contract.historical_support_command_sha256": (
            spec.historical_command_sha256
        ),
        "controller_version_contract.successor_support_command_sha256": (
            spec.successor_command_sha256
        ),
        "complete_zero_world_gate.cross_version_refusal_count": 2,
        "complete_zero_world_gate.unregistered_controller_refusal_count": 3,
        "claim_boundary.physical_execution_authorized": False,
        "claim_boundary.prone_to_standing_claimed": False,
    }
    if spec.change_kind == "maximum_target_speed":
        require(
            spec.historical_maximum_target_speed_rad_s is not None
            and spec.successor_maximum_target_speed_rad_s is not None
            and spec.successor_maximum_target_speed_rad_s
            > spec.historical_maximum_target_speed_rad_s,
            "SPEED_SPEC",
        )
        expected.update(
            {
                "controller_version_contract.historical_maximum_target_speed_rad_s": (
                    spec.historical_maximum_target_speed_rad_s
                ),
                "controller_version_contract.successor_maximum_target_speed_rad_s": (
                    spec.successor_maximum_target_speed_rad_s
                ),
                "controller_version_contract.changed_target_count": 0,
                "controller_version_contract.changed_maximum_speed_command_count": len(
                    spec.changed_indices
                ),
                "controller_version_contract.changed_maximum_speed_command_indices": list(
                    spec.changed_indices
                ),
                "controller_version_contract.historical_v1_v2_preserved": True,
                "controller_version_contract.target_positions_preserved": True,
                "controller_version_contract.non_speed_command_fields_preserved": True,
            }
        )
    elif spec.change_kind == "target_positions":
        expected.update(
            {
                "controller_version_contract.changed_target_count": len(
                    spec.changed_indices
                ),
                "controller_version_contract.changed_target_indices": list(
                    spec.changed_indices
                ),
                "controller_version_contract.historical_v1_preserved": True,
                "controller_version_contract.non_target_command_fields_preserved": True,
            }
        )
    elif spec.change_kind == "raise_body_maximum_target_speed":
        require(
            spec.historical_maximum_target_speed_rad_s is not None
            and spec.successor_maximum_target_speed_rad_s is not None
            and spec.successor_maximum_target_speed_rad_s
            > spec.historical_maximum_target_speed_rad_s
            and spec.raise_body_phase_steps
            and len(spec.historical_raise_command_sha256)
            == len(spec.raise_body_phase_steps)
            and len(spec.successor_raise_command_sha256)
            == len(spec.raise_body_phase_steps)
            and spec.command_mutation_refusal_count == 2,
            "RAISE_BODY_SPEED_SPEC",
        )
        expected.update(
            {
                "controller_version_contract.historical_maximum_target_speed_rad_s": (
                    spec.historical_maximum_target_speed_rad_s
                ),
                "controller_version_contract.successor_maximum_target_speed_rad_s": (
                    spec.successor_maximum_target_speed_rad_s
                ),
                "controller_version_contract.changed_target_count": 0,
                "controller_version_contract.raise_body_sampled_command_count": len(
                    spec.changed_indices
                ),
                "controller_version_contract.changed_maximum_speed_command_count": len(
                    spec.changed_indices
                ),
                (
                    "controller_version_contract."
                    f"{spec.historical_preservation_contract_field}"
                ): True,
                "controller_version_contract.support_pose_preserved": True,
                "controller_version_contract.support_commands_preserved": True,
                "controller_version_contract.stance_pose_versioned": True,
                "controller_version_contract.stance_target_positions_preserved": True,
                "controller_version_contract.non_speed_command_fields_preserved": True,
                "controller_version_contract.raise_body_phase_steps": list(
                    spec.raise_body_phase_steps
                ),
                "controller_version_contract.historical_raise_body_command_sha256": list(
                    spec.historical_raise_command_sha256
                ),
                "controller_version_contract.successor_raise_body_command_sha256": list(
                    spec.successor_raise_command_sha256
                ),
                "complete_zero_world_gate.command_mutation_refusal_count": (
                    spec.command_mutation_refusal_count
                ),
            }
        )
    elif spec.change_kind == "actuation_realization":
        require(
            not spec.changed_indices
            and spec.raise_body_phase_steps
            and len(spec.historical_raise_command_sha256)
            == len(spec.raise_body_phase_steps)
            and len(spec.successor_raise_command_sha256)
            == len(spec.raise_body_phase_steps)
            and spec.command_mutation_refusal_count == 2
            and spec.realization_mismatch_refusal_count == 2
            and spec.production_worker_pairing_control_count == 4
            and spec.historical_actuator_mode is not None
            and spec.successor_actuator_mode is not None
            and spec.historical_actuator_mode != spec.successor_actuator_mode
            and spec.historical_actuation_realization_id is not None
            and spec.successor_actuation_realization_id is not None
            and spec.historical_actuation_realization_id
            != spec.successor_actuation_realization_id,
            "ACTUATION_REALIZATION_SPEC",
        )
        expected.update(
            {
                "controller_version_contract.changed_target_count": 0,
                "controller_version_contract.changed_target_indices": [],
                (
                    "controller_version_contract."
                    f"{spec.historical_preservation_contract_field}"
                ): True,
                "controller_version_contract.portable_profile_fields_preserved_except_identity": True,
                "controller_version_contract.portable_commands_preserved": True,
                "controller_version_contract.support_pose_preserved": True,
                "controller_version_contract.stance_pose_preserved": True,
                "controller_version_contract.raise_body_ramp_preserved": True,
                "controller_version_contract.phase_gates_preserved": True,
                "controller_version_contract.thresholds_preserved": True,
                "controller_version_contract.evaluator_preserved": True,
                "controller_version_contract.actuator_caps_preserved": True,
                "controller_version_contract.actuator_route_preserved": False,
                "controller_version_contract.godot_actuation_realization_changed": True,
                "controller_version_contract.historical_actuator_mode": (
                    spec.historical_actuator_mode
                ),
                "controller_version_contract.successor_actuator_mode": (
                    spec.successor_actuator_mode
                ),
                "controller_version_contract.historical_actuation_realization_id": (
                    spec.historical_actuation_realization_id
                ),
                "controller_version_contract.successor_actuation_realization_id": (
                    spec.successor_actuation_realization_id
                ),
                "controller_version_contract.native_contact_solver_coupled": True,
                "controller_version_contract.pre_solver_direct_body_impulse_write_count": 0,
                "controller_version_contract.morphology_preserved": True,
                "controller_version_contract.cohort_preserved": True,
                "controller_version_contract.seed_preserved": True,
                "controller_version_contract.arm_order_preserved": True,
                "controller_version_contract.horizon_preserved": True,
                "controller_version_contract.raise_body_phase_steps": list(
                    spec.raise_body_phase_steps
                ),
                "controller_version_contract.historical_raise_body_command_sha256": list(
                    spec.historical_raise_command_sha256
                ),
                "controller_version_contract.successor_raise_body_command_sha256": list(
                    spec.successor_raise_command_sha256
                ),
                "complete_zero_world_gate.command_mutation_refusal_count": (
                    spec.command_mutation_refusal_count
                ),
                "complete_zero_world_gate.realization_mismatch_refusal_count": (
                    spec.realization_mismatch_refusal_count
                ),
                "complete_zero_world_gate.production_worker_pairing_control_count": (
                    spec.production_worker_pairing_control_count
                ),
            }
        )
    else:
        raise ClosureAuditError(f"CHANGE_KIND:{spec.change_kind}")
    return expected


def _receipt_expectations(
    spec: VersionedRecoveryControllerQualificationSpec,
) -> dict[str, Any]:
    expected: dict[str, Any] = {
        "declared_question_class": "development",
        "prospective_physical_question_declared": False,
        "native_zero_world.historical_controller_id": spec.historical_controller_id,
        "native_zero_world.successor_controller_id": spec.successor_controller_id,
        "native_zero_world.historical_controller_profile_sha256": (
            spec.historical_profile_sha256
        ),
        "native_zero_world.successor_controller_profile_sha256": (
            spec.successor_profile_sha256
        ),
        f"native_zero_world.{spec.historical_regression_receipt_field}": True,
        f"native_zero_world.{spec.preserved_receipt_field}": True,
        "native_zero_world.cross_version_observation_refusal_count": 2,
        "native_zero_world.unregistered_controller_refusal_count": 3,
        "native_zero_world.zero_world_bootstrap_application_passed": True,
        "native_zero_world.zero_world_application_passed": True,
        "native_zero_world.model_construction_count": 0,
        "native_zero_world.world_attempt_count": 0,
        "native_zero_world.world_build_count": 0,
        "native_zero_world.solver_step_count": 0,
        "native_zero_world.physics_state_modified": False,
        "native_zero_world.prone_to_standing_claimed": False,
        "native_zero_world.physical_acceptance_authority": False,
        "native_zero_world.release_authority": False,
        "native_zero_world_runtime.raw_sha256": GODOT_RUNTIME_SHA256,
    }
    if spec.change_kind in {"maximum_target_speed", "target_positions"}:
        expected.update(
            {
                "native_zero_world.historical_command_sha256": (
                    spec.historical_command_sha256
                ),
                "native_zero_world.successor_command_sha256": (
                    spec.successor_command_sha256
                ),
            }
        )
        changed_name = (
            "changed_speed"
            if spec.change_kind == "maximum_target_speed"
            else "changed_target"
        )
        expected[f"native_zero_world.{changed_name}_count"] = len(spec.changed_indices)
        expected[f"native_zero_world.{changed_name}_indices"] = list(
            spec.changed_indices
        )
    elif spec.change_kind == "raise_body_maximum_target_speed":
        expected.update(
            {
                "native_zero_world.support_command_sha256": (
                    spec.successor_command_sha256
                ),
                "native_zero_world.support_commands_preserved": True,
                "native_zero_world.raise_body_phase_steps": list(
                    spec.raise_body_phase_steps
                ),
                "native_zero_world.historical_raise_body_command_sha256": list(
                    spec.historical_raise_command_sha256
                ),
                "native_zero_world.successor_raise_body_command_sha256": list(
                    spec.successor_raise_command_sha256
                ),
                "native_zero_world.changed_speed_count": len(spec.changed_indices),
                "native_zero_world.command_mutation_refusal_count": (
                    spec.command_mutation_refusal_count
                ),
            }
        )
    elif spec.change_kind == "actuation_realization":
        expected.update(
            {
                "native_zero_world.support_command_sha256": (
                    spec.successor_command_sha256
                ),
                "native_zero_world.support_commands_preserved": True,
                "native_zero_world.portable_commands_preserved": True,
                "native_zero_world.non_speed_command_fields_identical": True,
                "native_zero_world.raise_body_phase_steps": list(
                    spec.raise_body_phase_steps
                ),
                "native_zero_world.historical_raise_body_command_sha256": list(
                    spec.historical_raise_command_sha256
                ),
                "native_zero_world.successor_raise_body_command_sha256": list(
                    spec.successor_raise_command_sha256
                ),
                "native_zero_world.changed_speed_count": 0,
                "native_zero_world.command_mutation_refusal_count": (
                    spec.command_mutation_refusal_count
                ),
                "native_zero_world.actuation_realization_id": (
                    spec.successor_actuation_realization_id
                ),
                "native_zero_world.solver_coupled_realization_binding_passed": True,
                "native_zero_world.realization_mismatch_refusal_count": (
                    spec.realization_mismatch_refusal_count
                ),
                "native_zero_world.production_worker_pairing_control_count": (
                    spec.production_worker_pairing_control_count
                ),
            }
        )
    else:
        raise ClosureAuditError(f"CHANGE_KIND:{spec.change_kind}")
    return expected


def _closure_expectations(
    spec: VersionedRecoveryControllerQualificationSpec,
    audit_relative_path: str,
) -> dict[str, Any]:
    expected: dict[str, Any] = {
        "ledger_scope.subsystem": "recovery",
        "ledger_scope.engine_scope": "godot_jolt",
        "ledger_scope.authority_mode": spec.closure_authority_mode,
        "ledger_scope.question_class": "development",
        "source.branch": "main",
        "source.remote": "https://github.com/Slagathore/sporespore.git",
        "source.upstream_equal_at_qualification": True,
        "source.live_remote_equal_at_qualification": True,
        "source.worktree_clean_at_qualification_start_and_end": True,
        "qualification.check_count": len(EXPECTED_CHECKS),
        "qualification.checks_passed": len(EXPECTED_CHECKS),
        "qualification.source_inventory_count": spec.source_inventory_count,
        "qualification.authored_source_path_count": spec.authored_source_path_count,
        f"qualification.{spec.historical_regression_qualification_field}": 1,
        "qualification.cross_version_observation_refusal_count": 2,
        "qualification.unregistered_controller_refusal_count": 3,
        "qualification.historical_closure_audits_executed_count": 0,
        "qualification.bespoke_physical_canary_count": 0,
        "qualification.full_seeded_ghost_count": 0,
        "qualification.model_construction_count": 0,
        "qualification.world_attempt_count": 0,
        "qualification.world_build_count": 0,
        "qualification.solver_step_count": 0,
        "decision.result": spec.decision_result,
        "decision.successor_controller_id": spec.successor_controller_id,
        "decision.successor_support_command_sha256": spec.successor_command_sha256,
        "decision.complete_zero_world_gate_passed": True,
        "decision.physical_question_declared": False,
        "decision.physical_execution_authorized": False,
        f"decision.{spec.next_declaration_required_field}": True,
        "decision.prone_to_standing_claimed": False,
        f"adequacy_and_limits.{spec.adequacy_field}": True,
        "next_boundary.physical_question_declared": False,
        "next_boundary.physical_execution_authorized": False,
        "next_boundary.maximum_world_attempt_count": 0,
        "next_boundary.maximum_solver_step_count": 0,
        "claim_boundary.complete_zero_world_gate_passed": True,
        f"claim_boundary.{spec.qualified_claim_field}": True,
        "claim_boundary.physical_attempted": False,
        "claim_boundary.prone_to_standing_claimed": False,
        "claim_boundary.sdk1_milestone_advanced": False,
        "claim_boundary.physical_acceptance_authority": False,
        "claim_boundary.release_authority": False,
        "sdk_status.sdk1_completed_steps": 11,
        "sdk_status.sdk1_total_steps": 20,
        "sdk_status.full_program_completed_steps": 11,
        "sdk_status.full_program_total_steps": 25,
        "closure_audit_path": audit_relative_path,
    }
    if spec.change_kind == "maximum_target_speed":
        expected.update(
            {
                "decision.changed_maximum_speed_command_count": len(
                    spec.changed_indices
                ),
                "decision.changed_maximum_speed_command_indices": list(
                    spec.changed_indices
                ),
                "decision.target_positions_preserved": True,
                "decision.non_speed_command_fields_preserved": True,
            }
        )
    elif spec.change_kind == "target_positions":
        expected.update(
            {
                "decision.changed_target_count": len(spec.changed_indices),
                "decision.changed_target_indices": list(spec.changed_indices),
            }
        )
    elif spec.change_kind == "raise_body_maximum_target_speed":
        expected.update(
            {
                "qualification.command_mutation_refusal_count": (
                    spec.command_mutation_refusal_count
                ),
                "decision.changed_maximum_speed_command_count": len(
                    spec.changed_indices
                ),
                "decision.raise_body_phase_steps": list(spec.raise_body_phase_steps),
                "decision.support_commands_preserved": True,
                "decision.stance_target_positions_preserved": True,
                "decision.non_speed_command_fields_preserved": True,
                "decision.command_mutation_refusal_count": (
                    spec.command_mutation_refusal_count
                ),
            }
        )
    elif spec.change_kind == "actuation_realization":
        expected.update(
            {
                "qualification.command_mutation_refusal_count": (
                    spec.command_mutation_refusal_count
                ),
                "qualification.realization_mismatch_refusal_count": (
                    spec.realization_mismatch_refusal_count
                ),
                "qualification.production_worker_pairing_control_count": (
                    spec.production_worker_pairing_control_count
                ),
                "decision.changed_target_count": 0,
                "decision.portable_commands_preserved": True,
                "decision.support_commands_preserved": True,
                "decision.non_speed_command_fields_preserved": True,
                "decision.raise_body_phase_steps": list(spec.raise_body_phase_steps),
                "decision.historical_raise_body_command_sha256": list(
                    spec.historical_raise_command_sha256
                ),
                "decision.successor_raise_body_command_sha256": list(
                    spec.successor_raise_command_sha256
                ),
                "decision.historical_actuator_mode": spec.historical_actuator_mode,
                "decision.successor_actuator_mode": spec.successor_actuator_mode,
                "decision.historical_actuation_realization_id": (
                    spec.historical_actuation_realization_id
                ),
                "decision.successor_actuation_realization_id": (
                    spec.successor_actuation_realization_id
                ),
                "decision.godot_actuation_realization_changed": True,
                "decision.solver_coupled_realization_binding_passed": True,
                "decision.pre_solver_direct_body_impulse_write_count": 0,
                "decision.command_mutation_refusal_count": (
                    spec.command_mutation_refusal_count
                ),
                "decision.realization_mismatch_refusal_count": (
                    spec.realization_mismatch_refusal_count
                ),
                "decision.production_worker_pairing_control_count": (
                    spec.production_worker_pairing_control_count
                ),
            }
        )
    else:
        raise ClosureAuditError(f"CHANGE_KIND:{spec.change_kind}")
    return expected


def validate_versioned_recovery_controller_qualification(
    *,
    root: Path,
    spec: VersionedRecoveryControllerQualificationSpec,
    audit_relative_path: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    checkout_only_paths = CHECKOUT_ONLY_PATHS + spec.additional_checkout_only_paths
    require(
        len(checkout_only_paths) == len(set(checkout_only_paths)),
        "CHECKOUT_ONLY_PATHS_UNIQUE",
    )
    checkout_metadata = tuple(
        {
            "path": path,
            "cause": "existing_windows_checkout_mixed_line_ending_materialization",
            "git_attribute": "text eol=lf",
        }
        for path in checkout_only_paths
    )
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=root,
            closure_path=root / spec.closure_relative_path,
            schema_version=spec.closure_schema,
            gate_id=spec.gate_id,
            closure_status=spec.qualified_status,
            source_commit=spec.source_commit,
            source_subject=spec.source_subject,
            source_binding_names=SOURCE_BINDING_NAMES,
            predecessor_status=spec.predecessor_status,
            attempt_schema=spec.attempt_schema,
            receipt_schema=spec.receipt_schema,
            qualification_directory_prefix=spec.qualification_directory_prefix,
            expected_checks=EXPECTED_CHECKS,
            checkout_only_metadata=checkout_metadata,
            retained_log_markers={
                "source_audit.log": spec.source_audit_marker,
                "native_zero_world.log": spec.native_zero_world_marker,
            },
            physical_question_declared=False,
        )
    )
    require(
        len(contract["source_inventory"])
        == len(set(contract["source_inventory"]))
        == spec.source_inventory_count,
        "FROZEN_SOURCE_INVENTORY",
    )
    verify_exact_paths(
        contract,
        _contract_expectations(spec),
        "FROZEN_CONTRACT",
    )

    evidence_root = Path(closure["qualification"]["evidence_root"])
    attempt = load(evidence_root / closure["qualification"]["attempt_path"])
    verify_exact_paths(
        attempt,
        {
            "prospective_physical_question_declared": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
        },
        "ATTEMPT_SEMANTICS",
    )
    verify_exact_paths(
        receipt,
        _receipt_expectations(spec),
        "RECEIPT_SEMANTICS",
    )
    verify_exact_paths(
        preflight,
        {
            "schema_version": spec.preflight_schema,
            "ok": True,
            "runtime_id": "sporespore_locomotion_core_debug_dll",
            "runtime_version": spec.core_runtime_sha256,
            "physical_question_opened": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "PREFLIGHT_SEMANTICS",
    )
    verify_exact_paths(
        closure,
        _closure_expectations(spec, audit_relative_path),
        "CLOSURE_SEMANTICS",
    )

    closure_raw = (root / spec.closure_relative_path).read_bytes()
    prefix = spec.authority_prefix
    live_expected = {
        f"{prefix}_source_status": spec.qualified_status,
        f"{prefix}_source_commit": spec.source_commit,
        f"{prefix}_zero_world_qualified": True,
        f"{prefix}_zero_world_qualification_complete": True,
        f"{prefix}_zero_world_closure_path": spec.closure_relative_path,
        f"{prefix}_zero_world_closure_raw_sha256": sha256(closure_raw),
        f"{prefix}_zero_world_closure_byte_length": len(closure_raw),
        f"{prefix}_zero_world_evidence_root": closure["qualification"]["evidence_root"],
        f"{prefix}_qualification_attempt_raw_sha256": closure["qualification"][
            "attempt_raw_sha256"
        ],
        f"{prefix}_qualification_receipt_raw_sha256": closure["qualification"][
            "receipt_raw_sha256"
        ],
        f"{prefix}_qualification_check_count": len(EXPECTED_CHECKS),
        f"{prefix}_qualification_checks_passed": len(EXPECTED_CHECKS),
        f"{prefix}_qualification_model_construction_count": 0,
        f"{prefix}_qualification_world_attempt_count": 0,
        f"{prefix}_qualification_world_build_count": 0,
        f"{prefix}_qualification_solver_step_count": 0,
        f"{prefix}_physical_question_declared": False,
        f"{prefix}_physical_execution_authorized": False,
        f"{prefix}_prone_to_standing_claimed": False,
        f"{prefix}_sdk1_milestone_advanced": False,
        spec.next_declaration_required_field: True,
        f"physical_execution_blocked_until_{prefix}_zero_world_qualification": False,
        f"physical_execution_blocked_pending_{spec.next_gate_id}_declaration": True,
        f"{prefix}_qualification_closure_audit_path": audit_relative_path,
    }
    verify_legacy_live_authority_projection(
        root,
        closure["live_authority_paths"],
        record_key=f"{prefix}_contract_path",
        expected=live_expected,
        prefix=f"LIVE_{prefix.upper()}_QUALIFICATION",
    )
    return closure, receipt


def run_versioned_recovery_controller_qualification_audit(
    *,
    root: Path,
    spec: VersionedRecoveryControllerQualificationSpec,
    audit_relative_path: str,
    marker: str,
) -> int:
    try:
        closure, receipt = validate_versioned_recovery_controller_qualification(
            root=root,
            spec=spec,
            audit_relative_path=audit_relative_path,
        )
    except (ClosureAuditError, KeyError, OSError, TypeError, ValueError) as error:
        print(f"{marker}_FAIL {error}")
        return 1
    print(
        marker
        + " "
        + json.dumps(
            {
                "gate_id": closure["gate_id"],
                "ok": True,
                "source_commit": spec.source_commit,
                "retained_file_count": closure["qualification"]["retained_tree"][
                    "file_count"
                ],
                "check_count": len(receipt["checks"]),
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physical_execution_authorized": False,
            },
            sort_keys=True,
        )
    )
    return 0
