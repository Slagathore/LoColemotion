#!/usr/bin/env python3
"""Zero-world source audit for the R24D13 production supervisor.

This audit reads declarations, immutable closure metadata, source, and manifest
bytes only. It never launches Godot, creates a physics object, or opens a world.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, NoReturn


ROOT = Path(__file__).resolve().parents[1]
DECLARATION_REL = (
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_"
    "preregistration_v1.json"
)
VALIDATION_MANIFEST_REL = (
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_"
    "validation_manifest.json"
)
CONTRACT_REL = (
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_"
    "physical_supervisor_contract_v1.json"
)
MANIFEST_REL = (
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_"
    "physical_supervisor_manifest_v1.json"
)
SUPERVISOR_REL = (
    "sdk/run_qsdk_r24d13_braking_mechanism_activation_characterization.ps1"
)
ZERO_CLOSURE_REL = (
    "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_"
    "zero_world_positive_closure_v1.json"
)
PREDECESSOR_PHYSICAL_CLOSURE_REL = (
    "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_"
    "physical_attempt_closure_v1.json"
)
EXPECTED_ZERO_SOURCE = "7b807819a6ed1d1864f5a5410bbb9b17667624e1"
EXPECTED_ZERO_RECEIPT = (
    "sha256:f8fd379f95f89197b1742efeeed41b55d0c71948634aaaf6d7a62d661f3aeb77"
)
EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE = (
    "sha256:2dbb9683d2848d1f42fbfa1b598c75169842a1d50423e8e3d3ca4c30ee42d629"
)
EXPECTED_CONSOLE = (
    "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
EXPECTED_ENGINE = (
    "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
EXPECTED_BINDINGS = {
    ".gitattributes",
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_"
    "preregistration_v1.json",
    ZERO_CLOSURE_REL,
    "tests/test_qsdk_r24d12_braking_mechanism_activation_"
    "zero_world_positive_closure.py",
    PREDECESSOR_PHYSICAL_CLOSURE_REL,
    "tests/test_qsdk_r24d12_braking_mechanism_activation_"
    "physical_attempt_closure.py",
    CONTRACT_REL,
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_"
    "validation_manifest.json",
    "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd",
    "scripts/lab/rigs/r24d13_godot_jolt_braking_mechanism_activation_rig.gd",
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_"
    "worker.gd",
    "tests/test_sdk_qsdk_r24d13_godot_jolt_braking_mechanism_activation_"
    "worker.gd",
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_"
    "evaluator.py",
    SUPERVISOR_REL,
    "sdk/locomotion_operation_lock.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "sdk/content_addressed_artifact_store.ps1",
    "tests/test_qsdk_r24d13_braking_mechanism_activation_"
    "physical_supervisor_source.py",
}
EXPECTED_VALIDATION_BINDINGS = [
    ".gitattributes",
    "sdk/adapters/godot/engine_patches/"
    "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch",
    "sdk/recovery/r24d5_godot_jolt_one_hinge_telemetry_"
    "physical_failure_closure_v1.json",
    "sdk/recovery/r24d6_godot_jolt_one_hinge_telemetry_"
    "characterization_preregistration_v1.json",
    "sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_"
    "characterization_preregistration_v1.json",
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "zero_world_positive_closure_v1.json",
    "sdk/recovery/r24d11_godot_jolt_instrumented_profile_"
    "promotion_decision_v1.json",
    ZERO_CLOSURE_REL,
    "tests/test_qsdk_r24d12_braking_mechanism_activation_"
    "zero_world_positive_closure.py",
    PREDECESSOR_PHYSICAL_CLOSURE_REL,
    "tests/test_qsdk_r24d12_braking_mechanism_activation_"
    "physical_attempt_closure.py",
    DECLARATION_REL,
    "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd",
    "scripts/lab/rigs/r24d13_godot_jolt_braking_mechanism_activation_rig.gd",
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_"
    "worker.gd",
    "tests/test_sdk_qsdk_r24d13_godot_jolt_braking_mechanism_activation_"
    "worker.gd",
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_"
    "evaluator.py",
    SUPERVISOR_REL,
    CONTRACT_REL,
    "sdk/locomotion_operation_lock.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "sdk/content_addressed_artifact_store.ps1",
    "tests/test_qsdk_r24d13_braking_mechanism_activation_"
    "physical_supervisor_source.py",
]


def fail(code: str) -> NoReturn:
    raise SystemExit(f"QSDK-R24D13 physical supervisor source audit: {code}")


def exact(value: Any, expected: Any, code: str) -> None:
    if type(value) is not type(expected) or value != expected:
        fail(code)


def mapping(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(code)
    return value


def load_json(relative: str) -> dict[str, Any]:
    try:
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"json:{relative}:{exc}")
    return mapping(value, f"json_object:{relative}")


def git(*arguments: str) -> str:
    run = subprocess.run(
        ["git", "-C", str(ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if run.returncode != 0:
        fail(f"git:{'_'.join(arguments)}:{run.stderr.strip()}")
    return run.stdout.strip()


def raw_receipt(path: Path) -> tuple[str, int]:
    try:
        payload = path.read_bytes()
    except OSError as exc:
        fail(f"file:{path}:{exc}")
    return "sha256:" + hashlib.sha256(payload).hexdigest(), len(payload)


def validate_zero_closure(closure: dict[str, Any]) -> None:
    exact(
        closure.get("schema_version"),
        "sporespore_qsdk_r24d12_braking_mechanism_activation_"
        "zero_world_positive_closure_v1",
        "zero_closure_schema",
    )
    exact(closure.get("gate_id"), "QSDK-R24D12", "zero_closure_gate")
    exact(closure.get("question_class"), "development", "zero_closure_question")
    exact(
        closure.get("status"),
        "complete_zero_world_gate_passed_physical_execution_still_"
        "forbidden_pending_explicit_separate_authorization",
        "zero_closure_status",
    )
    source = mapping(closure.get("source"), "zero_source")
    exact(source.get("commit"), EXPECTED_ZERO_SOURCE, "zero_source_commit")
    exact(source.get("clean_pushed_before_qualification"), True, "zero_clean")
    qualification = mapping(
        closure.get("zero_world_qualification"), "zero_qualification"
    )
    exact(
        qualification.get("receipt_raw_sha256"),
        EXPECTED_ZERO_RECEIPT,
        "zero_receipt",
    )
    exact(qualification.get("world_attempt_count"), 0, "zero_worlds")
    exact(qualification.get("world_build_count"), 0, "zero_builds")
    exact(qualification.get("solver_step_count"), 0, "zero_steps")
    claims = mapping(closure.get("claims"), "zero_claims")
    exact(claims.get("complete_zero_world_gate_passed"), True, "zero_pass")
    exact(claims.get("physical_characterization_executed"), False, "zero_physical")
    exact(claims.get("release_authority"), False, "zero_release")


def validate_predecessor_physical_closure(closure: dict[str, Any]) -> None:
    exact(
        closure.get("schema_version"),
        "sporespore_qsdk_r24d12_braking_mechanism_activation_"
        "physical_attempt_closure_v1",
        "predecessor_schema",
    )
    exact(closure.get("gate_id"), "QSDK-R24D12", "predecessor_gate")
    exact(closure.get("question_class"), "development", "predecessor_question")
    exact(
        closure.get("status"),
        "closed_consumed_invalid_incomplete_after_one_world_"
        "float32_readback_exactness_rejection",
        "predecessor_status",
    )
    exact(
        raw_receipt(ROOT / PREDECESSOR_PHYSICAL_CLOSURE_REL)[0],
        EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE,
        "predecessor_sha",
    )
    disposition = mapping(closure.get("disposition"), "predecessor_disposition")
    exact(disposition.get("attempt_consumed"), True, "predecessor_consumed")
    exact(
        disposition.get("same_source_rerun_forbidden"),
        True,
        "predecessor_rerun",
    )
    claims = mapping(closure.get("claims"), "predecessor_claims")
    exact(
        claims.get("accepted_physical_characterization"),
        False,
        "predecessor_accepted",
    )
    exact(
        claims.get("native_braking_mechanism_activation_observed"),
        False,
        "predecessor_mechanism",
    )
    exact(claims.get("release_authority"), False, "predecessor_release")


def validate_declaration(declaration: dict[str, Any]) -> None:
    exact(
        declaration.get("schema_version"),
        "sporespore_qsdk_r24d13_godot_jolt_braking_mechanism_"
        "activation_preregistration_v1",
        "declaration_schema",
    )
    exact(declaration.get("gate_id"), "QSDK-R24D13", "declaration_gate")
    exact(declaration.get("question_class"), "development", "declaration_question")
    exact(
        declaration.get("status"),
        "prospective_native_serialization_correction_implemented_"
        "zero_world_qualification_pending",
        "declaration_status",
    )
    predecessor = mapping(declaration.get("predecessor"), "declaration_predecessor")
    exact(predecessor.get("gate_id"), "QSDK-R24D12", "declaration_parent_gate")
    exact(
        predecessor.get("closure_raw_sha256"),
        EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE,
        "declaration_parent_sha",
    )
    exact(predecessor.get("attempt_consumed"), True, "declaration_consumed")
    exact(predecessor.get("same_source_rerun_forbidden"), True, "declaration_rerun")
    exact(
        predecessor.get("result_rewritten_rethresholded_or_selectively_re_evaluated"),
        False,
        "declaration_parent_rewrite",
    )
    representation = mapping(
        declaration.get("exact_representation_contract"),
        "declaration_representation",
    )
    exact(representation.get("ieee_754_binary32_hex"), "3d4ccccd", "representation_f32")
    exact(
        representation.get("binary32_promoted_to_binary64_hex"),
        "0x3fa99999a0000000",
        "representation_f64",
    )
    exact(
        representation.get("full_precision_json_text"),
        "0.05000000074505806",
        "representation_json",
    )
    exact(
        representation.get("evaluator_numeric_value"),
        0.05000000074505806,
        "representation_value",
    )
    exact(
        representation.get("comparison_is_exact_not_toleranced"),
        True,
        "representation_exact",
    )
    exact(representation.get("tolerance"), 0.0, "representation_tolerance")
    correction = mapping(declaration.get("prospective_correction"), "correction")
    exact(correction.get("physical_rig_semantics_changed_from_r24d12"), False, "rig_change")
    exact(correction.get("physical_schedule_changed_from_r24d12"), False, "schedule_change")
    exact(correction.get("mechanism_witness_rule_changed_from_r24d12"), False, "witness_change")
    exact(correction.get("evaluator_fixture_inertia_identity_changed"), True, "evaluator_change")
    exact(correction.get("native_zero_object_serializer_gate_added"), True, "serializer_gate")
    exact(correction.get("template_byte_passthrough_allowed"), False, "template_passthrough")
    fixture = mapping(declaration.get("fixture_freeze"), "declaration_fixture")
    exact(
        fixture.get("child_inertia_native_readback_diagonal_kg_m2"),
        [0.05000000074505806] * 3,
        "fixture_native_inertia",
    )
    exact(fixture.get("isolated_cell_count"), 4, "fixture_cells")
    exact(fixture.get("maximum_physics_step_count"), 1, "fixture_steps")
    exact(fixture.get("retained_sample_count"), 4, "fixture_samples")
    adequacy = mapping(declaration.get("adequacy"), "declaration_adequacy")
    for key in (
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_validation_cohort_count",
        "population_claim_count",
    ):
        exact(adequacy.get(key), 0, f"declaration_adequacy_{key}")
    boundary = mapping(declaration.get("execution_boundary"), "declaration_boundary")
    exact(boundary.get("physical_execution_authorized_now"), False, "declaration_physical")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(boundary.get(key), 0, f"declaration_{key}")
    claims = mapping(declaration.get("claims"), "declaration_claims")
    for key in (
        "prospective_development_question_declared",
        "predecessor_result_preserved",
        "source_derived_representation_correction_declared",
        "native_serializer_zero_object_gate_implemented",
    ):
        exact(claims.get(key), True, f"declaration_claim_{key}")
    for key, value in claims.items():
        if key not in {
            "prospective_development_question_declared",
            "predecessor_result_preserved",
            "source_derived_representation_correction_declared",
            "native_serializer_zero_object_gate_implemented",
        }:
            exact(value, False, f"declaration_claim_{key}")


def validate_validation_manifest(
    manifest: dict[str, Any], *, require_committed: bool
) -> None:
    exact(
        manifest.get("schema_version"),
        "sporespore_qsdk_r24d13_godot_jolt_braking_mechanism_"
        "activation_validation_manifest_v1",
        "validation_manifest_schema",
    )
    exact(manifest.get("gate_id"), "QSDK-R24D13", "validation_manifest_gate")
    exact(manifest.get("question_class"), "development", "validation_manifest_question")
    exact(
        manifest.get("status"),
        "prospective_native_serialization_source_bytes_bound_"
        "zero_world_qualification_pending",
        "validation_manifest_status",
    )
    exact(manifest.get("includes_self"), False, "validation_manifest_self")
    exact(
        manifest.get("predecessor_physical_closure_raw_sha256"),
        EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE,
        "validation_manifest_predecessor",
    )
    exact(manifest.get("native_inertia_binary32_hex"), "3d4ccccd", "validation_manifest_f32")
    exact(
        manifest.get("native_inertia_full_precision_json_text"),
        "0.05000000074505806",
        "validation_manifest_json",
    )
    exact(manifest.get("evaluator_invalid_mutation_rejection_count"), 28, "validation_manifest_mutations")
    exact(manifest.get("accepted_adverse_finite_outcome_count"), 4, "validation_manifest_adverse")
    bindings = manifest.get("source_bindings")
    if not isinstance(bindings, list):
        fail("validation_manifest_bindings")
    exact(
        manifest.get("source_binding_count"),
        len(EXPECTED_VALIDATION_BINDINGS),
        "validation_manifest_binding_count",
    )
    exact(
        [mapping(item, "validation_binding").get("path") for item in bindings],
        EXPECTED_VALIDATION_BINDINGS,
        "validation_manifest_binding_order",
    )
    head = git("rev-parse", "HEAD")
    for item in bindings:
        binding = mapping(item, "validation_binding")
        relative = str(binding.get("path"))
        sha, length = raw_receipt(ROOT / relative)
        exact(binding.get("raw_sha256"), sha, f"validation_binding_sha:{relative}")
        exact(binding.get("byte_length"), length, f"validation_binding_bytes:{relative}")
        working_blob = git("hash-object", relative)
        exact(binding.get("git_blob_oid"), working_blob, f"validation_binding_blob:{relative}")
        if require_committed:
            exact(
                git("rev-parse", f"{head}:{relative}"),
                working_blob,
                f"validation_binding_commit:{relative}",
            )
    for key in (
        "official_zero_world_qualification_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(manifest.get(key), 0, f"validation_manifest_{key}")
    for key in (
        "complete_zero_world_gate_passed",
        "physical_authorization",
        "physical_characterization_executed",
        "native_braking_mechanism_characterized",
        "native_braking_mechanism_activation_observed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(manifest.get(key), False, f"validation_manifest_{key}")


def validate_contract(contract: dict[str, Any]) -> None:
    exact(
        contract.get("schema_version"),
        "sporespore_qsdk_r24d13_physical_supervisor_contract_v1",
        "contract_schema",
    )
    exact(contract.get("gate_id"), "QSDK-R24D13", "contract_gate")
    exact(contract.get("question_class"), "development", "contract_question")
    exact(
        contract.get("status"),
        "prospective_parent_bound_physical_supervisor_implemented_"
        "preflight_pending_physics_forbidden",
        "contract_status",
    )
    if len(str(contract.get("question", ""))) < 250:
        fail("contract_question_detail")

    authority = mapping(contract.get("authority_chain"), "authority")
    exact(
        authority.get("immutable_zero_world_source_commit"),
        EXPECTED_ZERO_SOURCE,
        "authority_zero_source",
    )
    exact(
        authority.get("immutable_zero_world_receipt_raw_sha256"),
        EXPECTED_ZERO_RECEIPT,
        "authority_zero_receipt",
    )
    exact(
        authority.get("immutable_predecessor_physical_closure_raw_sha256"),
        EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE,
        "authority_predecessor_closure",
    )
    exact(authority.get("qualification_positive_closure_exists"), False, "closure")
    exact(authority.get("physical_authorization_exists"), False, "authorization")

    runtime = mapping(contract.get("runtime_identity"), "runtime")
    exact(runtime.get("executed_console_binary_raw_sha256"), EXPECTED_CONSOLE, "console")
    exact(runtime.get("executed_engine_binary_raw_sha256"), EXPECTED_ENGINE, "engine")
    exact(runtime.get("runtime_substitution_allowed"), False, "runtime_substitution")
    exact(runtime.get("solver_setting_substitution_allowed"), False, "solver_substitution")
    exact(runtime.get("campaign_result_reuse_allowed"), False, "result_reuse")
    exact(runtime.get("physical_evidence_reuse_allowed"), False, "evidence_reuse")
    if len(str(runtime.get("precise_reuse_basis", ""))) < 350:
        fail("precise_reuse_basis")

    schedule = mapping(contract.get("physical_schedule"), "schedule")
    for key, expected in {
        "world_count": 1,
        "world_build_count": 1,
        "fixture_cell_count": 4,
        "solver_step_count": 1,
        "first_retained_space_step_sequence": 1,
        "last_retained_space_step_sequence": 1,
        "retained_sample_count": 4,
        "pre_sample_physics_frame_count": 0,
        "terminal_physics_server_deactivation_count": 1,
        "same_authorization_physical_attempt_limit": 1,
    }.items():
        exact(schedule.get(key), expected, f"schedule_{key}")
    exact(
        schedule.get("cell_ids_in_order"),
        ["brake_positive", "brake_negative", "disabled_positive", "disabled_negative"],
        "schedule_cells",
    )
    for key in (
        "same_source_physical_rerun_allowed",
        "selective_cell_rerun_allowed",
        "outcome_dependent_early_stop_allowed",
    ):
        exact(schedule.get(key), False, f"schedule_{key}")

    interpretation = mapping(contract.get("mechanism_interpretation"), "interpretation")
    exact(
        interpretation.get("positive_result"),
        "complete_valid_finite_native_braking_mechanism_activation_positive",
        "positive_result",
    )
    exact(
        interpretation.get("negative_result"),
        "complete_valid_finite_native_braking_mechanism_activation_negative",
        "negative_result",
    )
    exact(
        interpretation.get("positive_and_negative_results_are_both_valid_development_outcomes"),
        True,
        "valid_outcomes",
    )
    exact(
        interpretation.get("missing_or_malformed_execution_is_invalid_not_negative"),
        True,
        "invalid_boundary",
    )
    exact(
        interpretation.get("positive_result_promotes_instrumented_profile"),
        False,
        "no_promotion",
    )

    preflight = mapping(contract.get("supervisor_preflight"), "preflight")
    for key in (
        "complete_zero_world_closure_recheck_required",
        "immutable_predecessor_physical_closure_recheck_required",
        "source_manifest_audit_required",
        "evaluator_self_test_and_negative_controls_required",
        "real_custom_runtime_native_serialization_zero_object_worker_required",
        "source_derived_float32_projection_required",
        "template_byte_passthrough_forbidden",
        "native_serialized_report_independent_evaluation_required",
        "same_production_project_staging_required",
        "same_production_worker_required",
        "same_production_evaluator_required",
        "same_supervisor_termination_protocol_required",
        "same_content_addressed_retention_required",
    ):
        exact(preflight.get(key), True, f"preflight_{key}")
    exact(preflight.get("declared_stage_count"), 6, "preflight_stages")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(preflight.get(key), 0, f"preflight_{key}")
    exact(preflight.get("separate_shortened_physics_ghost_required"), False, "ghost")
    if len(str(preflight.get("ghost_adequacy_argument", ""))) < 450:
        fail("ghost_adequacy_argument")

    adequacy = mapping(contract.get("evidence_adequacy"), "adequacy")
    for key in (
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_cohort_count",
        "population_claim_count",
    ):
        exact(adequacy.get(key), 0, f"adequacy_{key}")
    exact(adequacy.get("development_world_count"), 1, "adequacy_worlds")
    exact(adequacy.get("finite_fixture_cell_count"), 4, "adequacy_cells")
    if len(str(adequacy.get("adequacy_argument", ""))) < 400:
        fail("adequacy_argument")

    authorization = mapping(contract.get("authorization_boundary"), "auth_boundary")
    exact(authorization.get("physical_execution_authorized"), False, "physical_auth")
    for key in (
        "clean_pushed_supervisor_freeze_required",
        "complete_supervisor_preflight_required",
        "immutable_preflight_closure_required",
        "separate_exact_authorization_commit_required",
        "authorization_commit_must_be_direct_single_parent_child_of_qualified_source",
        "authorization_commit_identity_derived_from_current_head",
        "authorization_json_must_not_embed_its_own_commit_identity",
        "production_authorization_only_check_supported_before_attempt",
        "authorization_must_bind_supervisor_blob_across_parent_edge",
        "authorization_must_bind_manifest_blob_across_parent_edge",
        "authorization_must_bind_preflight_receipt",
        "authorization_must_bind_preflight_closure",
        "authorization_must_bind_zero_world_receipt",
        "authorization_must_bind_predecessor_physical_closure",
        "authorization_must_bind_executed_binary_pair",
        "one_attempt_only",
    ):
        exact(authorization.get(key), True, f"authorization_{key}")

    claims = mapping(contract.get("claims"), "claims")
    exact(claims.get("physical_supervisor_source_implemented"), True, "source_claim")
    for key in (
        "physical_supervisor_preflight_passed",
        "physical_authorization",
        "physical_characterization_executed",
        "native_braking_mechanism_characterized",
        "native_braking_mechanism_activation_observed",
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims.get(key), False, f"claim_{key}")


def validate_manifest(
    manifest: dict[str, Any], *, require_committed: bool
) -> None:
    exact(
        manifest.get("schema_version"),
        "sporespore_qsdk_r24d13_physical_supervisor_manifest_v1",
        "manifest_schema",
    )
    exact(manifest.get("gate_id"), "QSDK-R24D13", "manifest_gate")
    exact(manifest.get("question_class"), "development", "manifest_question")
    exact(
        manifest.get("status"),
        "prospective_physical_supervisor_v1_parent_bound_source_frozen_"
        "preflight_pending",
        "manifest_status",
    )
    exact(manifest.get("includes_self"), False, "manifest_self")
    exact(manifest.get("zero_world_source_commit"), EXPECTED_ZERO_SOURCE, "manifest_zero")
    exact(
        manifest.get("zero_world_receipt_raw_sha256"),
        EXPECTED_ZERO_RECEIPT,
        "manifest_zero_receipt",
    )
    exact(
        manifest.get("predecessor_physical_closure_raw_sha256"),
        EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE,
        "manifest_predecessor",
    )
    exact(
        manifest.get("executed_console_binary_raw_sha256"),
        EXPECTED_CONSOLE,
        "manifest_console",
    )
    exact(
        manifest.get("executed_engine_binary_raw_sha256"),
        EXPECTED_ENGINE,
        "manifest_engine",
    )
    for key, expected in {
        "declared_world_count": 1,
        "declared_cell_count": 4,
        "declared_solver_step_count": 1,
        "declared_retained_sample_count": 4,
        "declared_preflight_stage_count": 6,
        "threshold_count": 0,
        "margin_count": 0,
        "held_out_cohort_count": 0,
        "population_claim_count": 0,
    }.items():
        exact(manifest.get(key), expected, f"manifest_{key}")
    for key in (
        "preflight_passed",
        "physical_authorization",
        "physical_characterization_executed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(manifest.get(key), False, f"manifest_{key}")

    bindings = manifest.get("source_bindings")
    if not isinstance(bindings, list):
        fail("manifest_bindings")
    exact(manifest.get("source_binding_count"), len(bindings), "binding_count")
    paths = [str(mapping(item, "binding_object").get("path")) for item in bindings]
    if len(paths) != len(set(paths)) or set(paths) != EXPECTED_BINDINGS:
        fail("binding_population")
    head = git("rev-parse", "HEAD")
    for item in bindings:
        binding = mapping(item, "binding")
        relative = str(binding.get("path"))
        sha, length = raw_receipt(ROOT / relative)
        exact(binding.get("raw_sha256"), sha, f"binding_sha:{relative}")
        exact(binding.get("byte_length"), length, f"binding_bytes:{relative}")
        working_blob = git("hash-object", relative)
        exact(binding.get("git_blob_oid"), working_blob, f"binding_blob:{relative}")
        if require_committed:
            committed_blob = git("rev-parse", f"{head}:{relative}")
            exact(committed_blob, working_blob, f"binding_commit:{relative}")


def validate_supervisor_source(text: str) -> None:
    required = (
        '[ValidateSet("Preflight", "Authorization", "Physical")]',
        "physical_supervisor_contract_v1.json",
        "physical_supervisor_manifest_v1.json",
        "physical_supervisor_qualification_positive_closure_v1.json",
        "physical_authorization_v1.json",
        "Assert-R24D13SupervisorManifest",
        "Assert-R24D13ZeroWorldClosure",
        "Assert-R24D13PredecessorPhysicalClosure",
        "Assert-R24D13QualificationReceipt",
        "Assert-R24D13QualificationClosure",
        "Assert-R24D13PhysicalAuthorization",
        "authorization_commit_must_have_exactly_one_parent",
        "authorization_commit_derived_from_current_head",
        '-not $authorization.Contains("authorization_commit")',
        "$parentSupervisorBlob -ceq $currentSupervisorBlob",
        "$parentManifestBlob -ceq $currentManifestBlob",
        "explicit_run_physical_switch_required",
        "physical_switch_forbidden_in_authorization_check",
        "same_source_preflight_attempt_already_consumed",
        "same_authorization_binary_pair_physical_attempt_already_consumed",
        "Invoke-SporeSporeGodotReceiptTerminatedProcess",
        "Publish-SporeSporeContentAddressedArtifact",
        "QSDK_R24D13_PHYSICAL_SUPERVISOR_PREFLIGHT_PASS",
        "QSDK_R24D13_PHYSICAL_AUTHORIZATION_CHECK_PASS",
        "QSDK_R24D13_BRAKING_MECHANISM_PHYSICAL_RESULT",
        '--mode=$WorkerMode',
        'ValidateSet("zero_world_preflight", "physical")',
        '"--expected-evidence-kind", $EvidenceKind',
        "consumed_before_worker_launch",
        "failed_or_incomplete_retained",
        "complete_valid_finite_native_braking_mechanism_activation_positive",
        "complete_valid_finite_native_braking_mechanism_activation_negative",
        "custom_runtime_native_serialization_zero_object_worker",
        "native_serializer_path_exercised",
        "native_float32_inertia_readback_matches",
        "template_byte_passthrough",
    )
    for token in required:
        if token not in text:
            fail(f"supervisor_token:{token}")
    guard = re.compile(
        r'if \(\$Mode -ceq "Physical"\) \{\s*'
        r'Assert-R24D13 \(\$RunPhysical\) "explicit_run_physical_switch_required"\s*'
        r'\} else \{\s*Assert-R24D13 \(-not \$RunPhysical\) \(\s*'
        r'"physical_switch_forbidden_in_authorization_check"\s*\)\s*\}',
        re.MULTILINE,
    )
    if guard.search(text) is None:
        fail("supervisor_mode_switch_guard")
    for token in (
        "QSDK_R24D13_PHYSICAL_SUPERVISOR_PREFLIGHT_PASS",
        "QSDK_R24D13_PHYSICAL_AUTHORIZATION_CHECK_PASS",
        "QSDK_R24D13_BRAKING_MECHANISM_PHYSICAL_RESULT",
    ):
        if text.count(token) != 1:
            fail(f"supervisor_unique_token:{token}:{text.count(token)}")
    if "world_attempt_count = 1" not in text:
        fail("supervisor_world_count")
    if "solver_step_count = 1" not in text:
        fail("supervisor_step_count")
    if "retained_sample_count = 4" not in text:
        fail("supervisor_sample_count")
    if "physical_acceptance_authority = $false" not in text:
        fail("supervisor_nonclaim")
    for forbidden in (
        '"--mode=physical"',
        "physical_acceptance_authority = $true",
        "release_authority = $true",
    ):
        if forbidden in text:
            fail(f"supervisor_forbidden:{forbidden}")


def mutation_controls(contract: dict[str, Any]) -> int:
    mutations: list[tuple[tuple[str, ...], Any]] = [
        (("question_class",), "finite_decision"),
        (("authority_chain", "qualification_positive_closure_exists"), True),
        (("authority_chain", "physical_authorization_exists"), True),
        (("runtime_identity", "runtime_substitution_allowed"), True),
        (("runtime_identity", "campaign_result_reuse_allowed"), True),
        (("physical_schedule", "world_count"), 2),
        (("physical_schedule", "fixture_cell_count"), 3),
        (("physical_schedule", "solver_step_count"), 2),
        (("physical_schedule", "same_source_physical_rerun_allowed"), True),
        (("mechanism_interpretation", "positive_result_promotes_instrumented_profile"), True),
        (("mechanism_interpretation", "missing_or_malformed_execution_is_invalid_not_negative"), False),
        (("supervisor_preflight", "declared_stage_count"), 5),
        (("supervisor_preflight", "source_derived_float32_projection_required"), False),
        (("supervisor_preflight", "template_byte_passthrough_forbidden"), False),
        (("supervisor_preflight", "world_attempt_count"), 1),
        (("supervisor_preflight", "separate_shortened_physics_ghost_required"), True),
        (("evidence_adequacy", "empirical_acceptance_threshold_count"), 1),
        (("evidence_adequacy", "population_claim_count"), 1),
        (("authorization_boundary", "physical_execution_authorized"), True),
        (("authorization_boundary", "authorization_commit_must_be_direct_single_parent_child_of_qualified_source"), False),
        (("authorization_boundary", "authorization_json_must_not_embed_its_own_commit_identity"), False),
        (("authorization_boundary", "authorization_must_bind_zero_world_receipt"), False),
        (("authorization_boundary", "authorization_must_bind_predecessor_physical_closure"), False),
        (("claims", "physical_supervisor_preflight_passed"), True),
        (("claims", "physical_characterization_executed"), True),
        (("claims", "release_authority"), True),
    ]
    rejected = 0
    for path, replacement in mutations:
        candidate = copy.deepcopy(contract)
        target: dict[str, Any] = candidate
        for key in path[:-1]:
            target = mapping(target[key], "mutation_path")
        target[path[-1]] = replacement
        try:
            validate_contract(candidate)
        except SystemExit:
            rejected += 1
        else:
            fail(f"mutation_accepted:{'.'.join(path)}")
    return rejected


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-committed", action="store_true")
    args = parser.parse_args()

    exact(Path(git("rev-parse", "--show-toplevel")).resolve(), ROOT.resolve(), "root")
    exact(
        git("remote", "get-url", "origin"),
        "https://github.com/Slagathore/sporespore.git",
        "remote",
    )
    contract = load_json(CONTRACT_REL)
    closure = load_json(ZERO_CLOSURE_REL)
    predecessor = load_json(PREDECESSOR_PHYSICAL_CLOSURE_REL)
    manifest = load_json(MANIFEST_REL)
    declaration = load_json(DECLARATION_REL)
    validation_manifest = load_json(VALIDATION_MANIFEST_REL)
    validate_zero_closure(closure)
    validate_predecessor_physical_closure(predecessor)
    validate_declaration(declaration)
    validate_validation_manifest(
        validation_manifest,
        require_committed=args.require_committed,
    )
    validate_contract(contract)
    validate_manifest(manifest, require_committed=args.require_committed)
    validate_supervisor_source((ROOT / SUPERVISOR_REL).read_text(encoding="utf-8"))
    rejected = mutation_controls(contract)
    print(
        "QSDK_R24D13_PHYSICAL_SUPERVISOR_SOURCE_PASS "
        f"bindings={len(EXPECTED_BINDINGS)} mutations={rejected} "
        "worlds=0 builds=0 solver_steps=0 physical_authority=false"
    )


if __name__ == "__main__":
    main()
