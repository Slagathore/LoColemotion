#!/usr/bin/env python3
"""Zero-world source audit for the R24D14 one-step physical supervisor.

The audit verifies exact source and authority bindings. It cannot launch Godot,
allocate a model, open a world, take a solver step, or authorize physics.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / (
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_"
    "physical_supervisor_contract_v1.json"
)
MANIFEST_PATH = ROOT / (
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_"
    "physical_supervisor_manifest_v1.json"
)
PROJECTION_CLOSURE_PATH = ROOT / (
    "sdk/recovery/r24d14_godot_native_float_projection_"
    "qualification_positive_closure_v1.json"
)
PREDECESSOR_CLOSURE_PATH = ROOT / (
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_"
    "physical_attempt_closure_v1.json"
)
WORKER_PATH = ROOT / (
    "tests/test_sdk_qsdk_r24d14_godot_jolt_"
    "braking_mechanism_activation_worker.gd"
)
EVALUATOR_PATH = ROOT / (
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_"
    "physical_evaluator.py"
)
SUPERVISOR_PATH = ROOT / "sdk/run_qsdk_r24d14_braking_mechanism_activation_characterization.ps1"

EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EXPECTED_PROJECTION_SOURCE = "4f4d9f4900689bd7b452383d75b1eb8021b41e28"
EXPECTED_PROJECTION_RECEIPT = (
    "sha256:e958fad063c67043fef3a9a7570a7ae3a47d6f272d64724d76ed2da471c4ad4d"
)
EXPECTED_PROJECTION_CLOSURE = (
    "sha256:55badec51735428a10ef4b9ff18051133db2e10225e0428863fe79dac9f46ed6"
)
EXPECTED_PREDECESSOR_CLOSURE = (
    "sha256:2fa82f2a04d579612fbc34cfc62875f6b8f5acca63a41dd3a1da1d2d5bbdb725"
)
EXPECTED_CONSOLE = (
    "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
EXPECTED_ENGINE = (
    "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
EXPECTED_BINDINGS = [
    ".gitattributes",
    "sdk/recovery/r24d14_godot_native_float_projection_preregistration_v1.json",
    "sdk/recovery/r24d14_godot_native_float_projection_validation_manifest.json",
    "sdk/recovery/r24d14_godot_native_float_projection_qualification_positive_closure_v1.json",
    "tests/test_qsdk_r24d14_godot_native_float_projection_qualification_closure.py",
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json",
    "tests/test_qsdk_r24d13_braking_mechanism_activation_physical_attempt_closure.py",
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_supervisor_contract_v1.json",
    "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd",
    "scripts/lab/rigs/r24d13_godot_jolt_braking_mechanism_activation_rig.gd",
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd",
    "tests/test_sdk_qsdk_r24d14_godot_jolt_braking_mechanism_activation_worker.gd",
    "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_evaluator.py",
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_evaluator.py",
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_evaluator.py",
    "sdk/run_qsdk_r24d14_braking_mechanism_activation_characterization.ps1",
    "sdk/locomotion_operation_lock.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "sdk/content_addressed_artifact_store.ps1",
    "tests/test_qsdk_r24d14_braking_mechanism_activation_physical_supervisor_source.py",
]


def fail(code: str) -> None:
    raise SystemExit(f"QSDK-R24D14 physical supervisor source audit: {code}")


def require(condition: bool, code: str) -> None:
    if not condition:
        fail(code)


def exact(actual: Any, expected: Any, code: str) -> None:
    require(type(actual) is type(expected) and actual == expected, code)


def mapping(value: Any, code: str) -> dict[str, Any]:
    require(type(value) is dict, code)
    return value


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    return mapping(value, f"json_object:{path}")


def sha(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(ROOT), *args],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    require(result.returncode == 0, f"git:{'_'.join(args)}:{result.stderr.strip()}")
    return result.stdout.strip()


def set_path(value: dict[str, Any], path: tuple[str, ...], replacement: Any) -> None:
    target: dict[str, Any] = value
    for key in path[:-1]:
        target = mapping(target[key], "mutation_path")
    target[path[-1]] = replacement


def validate_projection_closure(value: dict[str, Any]) -> None:
    exact(
        value.get("schema_version"),
        "sporespore_qsdk_r24d14_godot_native_float_projection_qualification_positive_closure_v1",
        "projection_schema",
    )
    exact(value.get("gate_id"), "QSDK-R24D14", "projection_gate")
    exact(value.get("question_class"), "development", "projection_question")
    exact(
        value.get("status"),
        "complete_clean_pushed_zero_step_native_property_and_telemetry_projection_qualified_physical_supervisor_pending",
        "projection_status",
    )
    exact(sha(PROJECTION_CLOSURE_PATH), EXPECTED_PROJECTION_CLOSURE, "projection_closure_sha")
    source = mapping(value.get("source"), "projection_source")
    exact(source.get("commit"), EXPECTED_PROJECTION_SOURCE, "projection_source_commit")
    exact(source.get("cached_origin_main"), EXPECTED_PROJECTION_SOURCE, "projection_cached")
    exact(source.get("live_origin_main"), EXPECTED_PROJECTION_SOURCE, "projection_live")
    exact(source.get("clean_pushed_before_qualification"), True, "projection_clean")
    retained = mapping(value.get("retained_evidence"), "projection_retained")
    exact(retained.get("receipt_raw_sha256"), EXPECTED_PROJECTION_RECEIPT, "projection_receipt")
    exact(retained.get("file_count"), 18, "projection_files")
    exact(retained.get("total_byte_length"), 117384, "projection_bytes")
    qualification = mapping(value.get("qualification"), "projection_qualification")
    exact(qualification.get("native_joint_allocation_count"), 1, "projection_joint")
    exact(qualification.get("native_joint_release_call_count"), 1, "projection_joint_release")
    exact(qualification.get("native_impulse_binary64_hex"), "3f60624de0000000", "projection_impulse")
    exact(qualification.get("native_timestep_binary64_hex"), "3f81111120000000", "projection_timestep")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(qualification.get(key), 0, f"projection_{key}")
    disposition = mapping(value.get("disposition"), "projection_disposition")
    exact(disposition.get("official_qualification_consumed"), True, "projection_consumed")
    exact(
        disposition.get("same_source_official_qualification_rerun_allowed"),
        False,
        "projection_rerun",
    )
    claims = mapping(value.get("claims"), "projection_claims")
    for key in (
        "native_property_readback_projection_qualified",
        "telemetry_float32_variant_projection_qualified",
        "complete_zero_step_qualification_passed",
    ):
        exact(claims.get(key), True, f"projection_claim_{key}")
    for key in (
        "physical_supervisor_implemented",
        "physical_characterization_executed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims.get(key), False, f"projection_claim_{key}")


def validate_predecessor_closure(value: dict[str, Any]) -> None:
    exact(
        value.get("schema_version"),
        "sporespore_qsdk_r24d13_braking_mechanism_activation_physical_attempt_closure_v1",
        "predecessor_schema",
    )
    exact(value.get("gate_id"), "QSDK-R24D13", "predecessor_gate")
    exact(value.get("question_class"), "development", "predecessor_question")
    exact(
        value.get("status"),
        "closed_consumed_invalid_incomplete_after_one_world_native_float32_projection_exactness_rejection",
        "predecessor_status",
    )
    exact(sha(PREDECESSOR_CLOSURE_PATH), EXPECTED_PREDECESSOR_CLOSURE, "predecessor_sha")
    disposition = mapping(value.get("disposition"), "predecessor_disposition")
    exact(disposition.get("attempt_consumed"), True, "predecessor_consumed")
    exact(disposition.get("same_source_rerun_forbidden"), True, "predecessor_rerun")
    claims = mapping(value.get("claims"), "predecessor_claims")
    exact(claims.get("accepted_physical_characterization"), False, "predecessor_acceptance")
    exact(claims.get("release_authority"), False, "predecessor_release")


def validate_contract(value: dict[str, Any]) -> None:
    exact(
        value.get("schema_version"),
        "sporespore_qsdk_r24d14_physical_supervisor_contract_v1",
        "contract_schema",
    )
    exact(value.get("gate_id"), "QSDK-R24D14", "contract_gate")
    exact(value.get("question_class"), "development", "contract_question_class")
    exact(
        value.get("status"),
        "prospective_parent_bound_physical_supervisor_implemented_preflight_pending_physics_forbidden",
        "contract_status",
    )
    require(len(str(value.get("question", ""))) >= 250, "contract_question_detail")
    authority = mapping(value.get("authority_chain"), "authority")
    exact(
        authority.get("preregistration_path"),
        "sdk/recovery/r24d14_godot_native_float_projection_preregistration_v1.json",
        "authority_preregistration",
    )
    exact(
        authority.get("immutable_native_projection_qualification_closure_raw_sha256"),
        EXPECTED_PROJECTION_CLOSURE,
        "authority_projection_closure",
    )
    exact(
        authority.get("immutable_native_projection_qualification_source_commit"),
        EXPECTED_PROJECTION_SOURCE,
        "authority_projection_source",
    )
    exact(
        authority.get("immutable_native_projection_qualification_receipt_raw_sha256"),
        EXPECTED_PROJECTION_RECEIPT,
        "authority_projection_receipt",
    )
    exact(
        authority.get("immutable_predecessor_physical_closure_raw_sha256"),
        EXPECTED_PREDECESSOR_CLOSURE,
        "authority_predecessor",
    )
    exact(authority.get("qualification_positive_closure_exists"), False, "authority_closure")
    exact(authority.get("physical_authorization_exists"), False, "authority_authorization")
    runtime = mapping(value.get("runtime_identity"), "runtime")
    exact(runtime.get("executed_console_binary_raw_sha256"), EXPECTED_CONSOLE, "runtime_console")
    exact(runtime.get("executed_engine_binary_raw_sha256"), EXPECTED_ENGINE, "runtime_engine")
    exact(runtime.get("runtime_substitution_allowed"), False, "runtime_substitution")
    exact(runtime.get("campaign_result_reuse_allowed"), False, "runtime_result_reuse")
    exact(runtime.get("physical_evidence_reuse_allowed"), False, "runtime_evidence_reuse")
    require(len(str(runtime.get("precise_reuse_basis", ""))) >= 600, "runtime_reuse_basis")
    schedule = mapping(value.get("physical_schedule"), "schedule")
    expected_schedule = {
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
        "same_source_physical_rerun_allowed": False,
        "selective_cell_rerun_allowed": False,
        "outcome_dependent_early_stop_allowed": False,
    }
    for key, expected in expected_schedule.items():
        exact(schedule.get(key), expected, f"schedule_{key}")
    exact(
        schedule.get("cell_ids_in_order"),
        ["brake_positive", "brake_negative", "disabled_positive", "disabled_negative"],
        "schedule_cells",
    )
    interpretation = mapping(value.get("mechanism_interpretation"), "interpretation")
    exact(
        interpretation.get("positive_and_negative_results_are_both_valid_development_outcomes"),
        True,
        "interpretation_adverse",
    )
    exact(
        interpretation.get("missing_or_malformed_execution_is_invalid_not_negative"),
        True,
        "interpretation_invalid",
    )
    exact(interpretation.get("positive_result_promotes_instrumented_profile"), False, "interpretation_promotion")
    preflight = mapping(value.get("supervisor_preflight"), "preflight")
    for key in (
        "complete_native_projection_qualification_closure_recheck_required",
        "immutable_predecessor_physical_closure_recheck_required",
        "source_manifest_audit_required",
        "evaluator_self_test_and_negative_controls_required",
        "real_custom_runtime_native_property_and_telemetry_projection_worker_required",
        "source_derived_float32_projection_required",
        "template_byte_passthrough_forbidden",
        "native_serialized_report_independent_evaluation_required",
        "same_production_project_staging_required",
        "same_production_worker_required",
        "same_production_evaluator_required",
        "same_supervisor_termination_protocol_required",
        "same_content_addressed_retention_required",
        "development_preflight_allowed",
        "development_preflight_repeatable",
    ):
        exact(preflight.get(key), True, f"preflight_{key}")
    exact(
        preflight.get("development_preflight_is_official_qualification"),
        False,
        "preflight_development_not_official",
    )
    exact(preflight.get("declared_stage_count"), 7, "preflight_stage_count")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(preflight.get(key), 0, f"preflight_{key}")
    exact(preflight.get("separate_shortened_physics_ghost_required"), False, "preflight_ghost")
    require(len(str(preflight.get("ghost_adequacy_argument", ""))) >= 700, "preflight_adequacy")
    adequacy = mapping(value.get("evidence_adequacy"), "adequacy")
    for key in (
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_cohort_count",
        "population_claim_count",
    ):
        exact(adequacy.get(key), 0, f"adequacy_{key}")
    exact(adequacy.get("development_world_count"), 1, "adequacy_world")
    exact(adequacy.get("finite_fixture_cell_count"), 4, "adequacy_cells")
    authorization = mapping(value.get("authorization_boundary"), "authorization")
    exact(authorization.get("physical_execution_authorized"), False, "authorization_state")
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
        "authorization_must_bind_native_projection_qualification_receipt",
        "authorization_must_bind_native_projection_qualification_closure",
        "authorization_must_bind_predecessor_physical_closure",
        "authorization_must_bind_executed_binary_pair",
        "one_attempt_only",
    ):
        exact(authorization.get(key), True, f"authorization_{key}")
    claims = mapping(value.get("claims"), "claims")
    exact(claims.get("physical_supervisor_source_implemented"), True, "claim_source")
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


def validate_manifest(value: dict[str, Any], require_committed: bool) -> None:
    exact(
        value.get("schema_version"),
        "sporespore_qsdk_r24d14_physical_supervisor_manifest_v1",
        "manifest_schema",
    )
    exact(value.get("gate_id"), "QSDK-R24D14", "manifest_gate")
    exact(value.get("question_class"), "development", "manifest_question")
    exact(
        value.get("status"),
        "prospective_physical_supervisor_v1_parent_bound_source_frozen_preflight_pending",
        "manifest_status",
    )
    exact(value.get("includes_self"), False, "manifest_self")
    exact(
        value.get("native_projection_qualification_source_commit"),
        EXPECTED_PROJECTION_SOURCE,
        "manifest_projection_source",
    )
    exact(
        value.get("native_projection_qualification_receipt_raw_sha256"),
        EXPECTED_PROJECTION_RECEIPT,
        "manifest_projection_receipt",
    )
    exact(
        value.get("native_projection_qualification_closure_raw_sha256"),
        EXPECTED_PROJECTION_CLOSURE,
        "manifest_projection_closure",
    )
    exact(
        value.get("predecessor_physical_closure_raw_sha256"),
        EXPECTED_PREDECESSOR_CLOSURE,
        "manifest_predecessor",
    )
    exact(value.get("executed_console_binary_raw_sha256"), EXPECTED_CONSOLE, "manifest_console")
    exact(value.get("executed_engine_binary_raw_sha256"), EXPECTED_ENGINE, "manifest_engine")
    expected_counts = {
        "declared_world_count": 1,
        "declared_cell_count": 4,
        "declared_solver_step_count": 1,
        "declared_retained_sample_count": 4,
        "declared_preflight_stage_count": 7,
        "threshold_count": 0,
        "margin_count": 0,
        "held_out_cohort_count": 0,
        "population_claim_count": 0,
    }
    for key, expected in expected_counts.items():
        exact(value.get(key), expected, f"manifest_{key}")
    for key in (
        "preflight_passed",
        "physical_authorization",
        "physical_characterization_executed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(value.get(key), False, f"manifest_{key}")
    bindings = value.get("source_bindings")
    require(type(bindings) is list, "manifest_bindings")
    exact(value.get("source_binding_count"), len(EXPECTED_BINDINGS), "manifest_binding_count")
    exact([item.get("path") for item in bindings], EXPECTED_BINDINGS, "manifest_binding_order")
    for item in bindings:
        binding = mapping(item, "manifest_binding")
        relative = str(binding.get("path", ""))
        path = ROOT / relative
        require(path.is_file(), f"binding_missing:{relative}")
        exact(binding.get("raw_sha256"), sha(path), f"binding_sha:{relative}")
        exact(binding.get("byte_length"), path.stat().st_size, f"binding_bytes:{relative}")
        working_blob = git("hash-object", relative)
        exact(binding.get("git_blob_oid"), working_blob, f"binding_blob:{relative}")
        if require_committed:
            exact(git("rev-parse", f"HEAD:{relative}"), working_blob, f"binding_commit:{relative}")


def validate_worker_source(text: str) -> None:
    required = (
        '"res://scripts/lab/rigs/r24d13_godot_jolt_braking_mechanism_activation_rig.gd"',
        'mode != "zero_world_preflight" and mode != "physical"',
        "HingeJoint3D.new()",
        "HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE",
        "PackedFloat32Array([0.002])",
        "PackedFloat32Array([1.0 / 120.0])",
        "R24D14_REJECTED_R24D13_IMPULSE",
        "R24D14_REJECTED_R24D13_TIMESTEP",
        "native_projection_matches",
        '"QSDK.R24D14.godot_jolt_braking_mechanism_activation.v1"',
        "func _r24d14_run_physical(",
        "physics_frame.connect(_r24d14_on_physics_frame)",
        "PhysicsServer3D.set_active(true)",
        '"solver_step_count": 1',
        '"retained_sample_count": 4',
        "QSDK_R24D14_WORKER_ZERO_WORLD ",
        "QSDK_R24D14_PHYSICAL_RAW_REPORT ",
        "QSDK_R24D14_GODOT_SUPERVISOR_TERMINATION_READY ",
    )
    for token in required:
        require(token in text, f"worker_missing:{token}")
    for forbidden in ("apply_force(", "apply_torque(", "apply_impulse("):
        require(forbidden not in text, f"worker_forbidden:{forbidden}")


def validate_evaluator_source(text: str) -> None:
    required = (
        'BASE_PATH = HERE / "r24d13_godot_jolt_braking_mechanism_activation_evaluator.py"',
        'GATE_ID = "QSDK-R24D14"',
        'RAW_SCHEMA = "sporespore_qsdk_r24d14_godot_jolt_braking_mechanism_activation_raw_report_v1"',
        'EXPECTED_NATIVE_IMPULSE = struct.unpack("<f", bytes.fromhex("6f12033b"))[0]',
        'EXPECTED_NATIVE_TIMESTEP = struct.unpack("<f", bytes.fromhex("8988083c"))[0]',
        'parser.add_argument("--emit-zero-world-template", type=Path)',
        'choices=("synthetic_zero_world", "native_physical")',
        "BASE.synthetic_report(args.expected_source_commit, args.expected_nonce)",
        "BASE.evaluate(",
        "INVALID_MUTATION_ACCEPTED",
    )
    for token in required:
        require(token in text, f"evaluator_missing:{token}")


def validate_supervisor_source(text: str) -> None:
    required = (
        '[ValidateSet("Preflight", "Authorization", "Physical")]',
        "[switch]$DevelopmentPreflight",
        "-AllowDirty:$DevelopmentPreflight",
        "-RequireCommitted:(-not $DevelopmentPreflight)",
        'if (-not $DevelopmentPreflight) {',
        '$sourceAuditArguments += "--require-committed"',
        '$(if ($DevelopmentPreflight) { "development" } else {',
        "development_preflight = [bool]$DevelopmentPreflight",
        "official_qualification = -not [bool]$DevelopmentPreflight",
        "same_source_preflight_rerun_allowed = [bool]$DevelopmentPreflight",
        'Assert-R24D14 ($RunPhysical) "explicit_run_physical_switch_required"',
        'Assert-R24D14 (-not $RunPhysical)',
        "same_source_preflight_attempt_already_consumed",
        "same_authorization_binary_pair_physical_attempt_already_consumed",
        "r24d14_physical_supervisor_source_audit",
        "immutable_r24d14_native_projection_qualification_closure_audit",
        "immutable_r24d13_physical_closure_audit",
        "r24d14_evaluator_self_test_and_negative_controls",
        "evaluator_shaped_zero_world_template",
        "custom_runtime_native_serialization_zero_object_worker",
        "independent_native_serialization_evaluation",
        "native_joint_allocation_count = 1",
        "world_attempt_count = 1",
        "world_build_count = 1",
        "solver_step_count = 1",
        "physical_acceptance_authority = $false",
        '-WorkerMode "physical"',
        "QSDK_R24D14_PHYSICAL_SUPERVISOR_PREFLIGHT_PASS",
        "QSDK_R24D14_PHYSICAL_AUTHORIZATION_CHECK_PASS",
        "QSDK_R24D14_BRAKING_MECHANISM_PHYSICAL_RESULT",
    )
    for token in required:
        require(token in text, f"supervisor_missing:{token}")
    require("physical_acceptance_authority = $true" not in text, "supervisor_acceptance")


def mutation_controls(contract: dict[str, Any]) -> int:
    mutations: list[tuple[tuple[str, ...], Any]] = [
        (("status",), "mutated"),
        (("authority_chain", "immutable_native_projection_qualification_closure_raw_sha256"), "sha256:" + "0" * 64),
        (("authority_chain", "immutable_native_projection_qualification_source_commit"), "0" * 40),
        (("authority_chain", "immutable_native_projection_qualification_receipt_raw_sha256"), "sha256:" + "0" * 64),
        (("authority_chain", "immutable_predecessor_physical_closure_raw_sha256"), "sha256:" + "0" * 64),
        (("authority_chain", "qualification_positive_closure_exists"), True),
        (("runtime_identity", "campaign_result_reuse_allowed"), True),
        (("physical_schedule", "world_count"), 2),
        (("physical_schedule", "fixture_cell_count"), 3),
        (("physical_schedule", "solver_step_count"), 2),
        (("physical_schedule", "same_source_physical_rerun_allowed"), True),
        (("mechanism_interpretation", "missing_or_malformed_execution_is_invalid_not_negative"), False),
        (("supervisor_preflight", "declared_stage_count"), 6),
        (("supervisor_preflight", "complete_native_projection_qualification_closure_recheck_required"), False),
        (("supervisor_preflight", "source_derived_float32_projection_required"), False),
        (("supervisor_preflight", "development_preflight_allowed"), False),
        (("supervisor_preflight", "development_preflight_is_official_qualification"), True),
        (("supervisor_preflight", "development_preflight_repeatable"), False),
        (("supervisor_preflight", "world_attempt_count"), 1),
        (("supervisor_preflight", "separate_shortened_physics_ghost_required"), True),
        (("evidence_adequacy", "empirical_acceptance_threshold_count"), 1),
        (("evidence_adequacy", "population_claim_count"), 1),
        (("authorization_boundary", "physical_execution_authorized"), True),
        (("authorization_boundary", "authorization_json_must_not_embed_its_own_commit_identity"), False),
        (("authorization_boundary", "authorization_must_bind_native_projection_qualification_closure"), False),
        (("claims", "physical_supervisor_preflight_passed"), True),
        (("claims", "physical_characterization_executed"), True),
        (("claims", "release_authority"), True),
    ]
    rejected = 0
    for path, replacement in mutations:
        mutated = copy.deepcopy(contract)
        set_path(mutated, path, replacement)
        try:
            validate_contract(mutated)
        except SystemExit:
            rejected += 1
        else:
            fail(f"mutation_accepted:{'.'.join(path)}")
    return rejected


def validate_committed_boundary() -> None:
    exact(
        git("rev-parse", "--show-toplevel").replace("\\", "/"),
        str(ROOT).replace("\\", "/"),
        "repo_root",
    )
    exact(git("remote", "get-url", "origin"), EXPECTED_REMOTE, "repo_remote")
    exact(git("branch", "--show-current"), "main", "repo_branch")
    head = git("rev-parse", "HEAD")
    exact(git("rev-parse", "@{upstream}"), head, "repo_upstream")
    exact(git("rev-parse", "refs/remotes/origin/main"), head, "repo_cached")
    live = git("ls-remote", "origin", "refs/heads/main").split()[0]
    exact(live, head, "repo_live")
    exact(git("status", "--porcelain=v1"), "", "repo_dirty")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-committed", action="store_true")
    args = parser.parse_args()
    projection = read_json(PROJECTION_CLOSURE_PATH)
    predecessor = read_json(PREDECESSOR_CLOSURE_PATH)
    contract = read_json(CONTRACT_PATH)
    manifest = read_json(MANIFEST_PATH)
    validate_projection_closure(projection)
    validate_predecessor_closure(predecessor)
    validate_contract(contract)
    validate_worker_source(WORKER_PATH.read_text(encoding="utf-8"))
    validate_evaluator_source(EVALUATOR_PATH.read_text(encoding="utf-8"))
    validate_supervisor_source(SUPERVISOR_PATH.read_text(encoding="utf-8"))
    validate_manifest(manifest, args.require_committed)
    if args.require_committed:
        validate_committed_boundary()
    rejected = mutation_controls(contract)
    print(
        "QSDK_R24D14_PHYSICAL_SUPERVISOR_SOURCE_PASS "
        f"bindings={len(EXPECTED_BINDINGS)} mutations={rejected} "
        "native_joints=0 worlds=0 builds=0 solver_steps=0 "
        "physical_authority=false release_authority=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
