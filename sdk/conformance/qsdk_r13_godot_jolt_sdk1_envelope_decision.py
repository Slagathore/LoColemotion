#!/usr/bin/env python3
"""Audit the zero-world QSDK-R13 / SDK1-M08 Godot/Jolt envelope decision.

The decision composes already-consumed finite evidence.  This audit reads the
retained bytes and used semantics directly; it never invokes an engine, model,
world, native physics read, historical evaluator, selector, or solver step.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import itertools
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable


REPO_ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = "C:/Users/Cole/CodeStuff/games/SporeSpore"
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
DECISION_PARENT = "6abb0acd0af73785852fb36194069266d679c7e3"
DECISION_PARENT_TREE = "7fa6b4f0ed9958d602a3bca3fff0ed4c8c367db6"
DECISION_PATH = "sdk/release/qsdk_r13_godot_jolt_sdk1_envelope_decision_v1.json"
DECISION_BYTES = 25195
DECISION_SHA256 = "sha256:fec621b0437c58ebfbb92b666ab2391e0b500f11e7ee0f09bee0b301a05531a6"
CONTRACT_PATH = "sdk/release/quadruped_release_contract.json"
SUPPORT_MATRIX_PATH = "sdk/release/quadruped_support_matrix.json"
MAPPING_PATH = "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"
FULL_COMPILER_PATH = "sdk/compile_quadruped_sdk_release_readiness.ps1"
SDK1_COMPILER_PATH = "sdk/compile_quadruped_sdk1_milestone_readiness.ps1"
POLICY_ID = "sporespore_balanced_wave_bw5r_b_v1"
POLICY_DIGEST = "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
PASS_MARKER = "QSDK_R13_GODOT_JOLT_SDK1_ENVELOPE_DECISION_PASS "
FAIL_MARKER = "QSDK_R13_GODOT_JOLT_SDK1_ENVELOPE_DECISION_FAIL "

EXPECTED_ENDPOINTS = [
    {
        "axis": "torso_length_scale",
        "plain_language": "torso length relative to the reference body",
        "reference_value": 1.0,
        "low": {
            "generator_index": 217,
            "morphology_id": "qsdk_r05e_axis_star_torso_length_low_s217",
            "value": 0.975,
        },
        "high": {
            "generator_index": 218,
            "morphology_id": "qsdk_r05e_axis_star_torso_length_high_s218",
            "value": 1.025,
        },
    },
    {
        "axis": "torso_width_scale",
        "plain_language": "torso width relative to the reference body",
        "reference_value": 1.0,
        "low": {
            "generator_index": 219,
            "morphology_id": "qsdk_r05e_axis_star_torso_width_low_s219",
            "value": 0.975,
        },
        "high": {
            "generator_index": 220,
            "morphology_id": "qsdk_r05e_axis_star_torso_width_high_s220",
            "value": 1.025,
        },
    },
    {
        "axis": "upper_length_fraction",
        "plain_language": "upper-segment share of total limb length",
        "reference_value": 0.5142857142857142,
        "low": {
            "generator_index": 221,
            "morphology_id": "qsdk_r05e_axis_star_upper_fraction_low_s221",
            "value": 0.5107142857142857,
        },
        "high": {
            "generator_index": 222,
            "morphology_id": "qsdk_r05e_axis_star_upper_fraction_high_s222",
            "value": 0.5232142857142856,
        },
    },
    {
        "axis": "hip_span_scale",
        "plain_language": "left-to-right hip spacing relative to the reference body",
        "reference_value": 1.0,
        "low": {
            "generator_index": 223,
            "morphology_id": "qsdk_r05e_axis_star_hip_span_low_s223",
            "value": 0.975,
        },
        "high": {
            "generator_index": 224,
            "morphology_id": "qsdk_r05e_axis_star_hip_span_high_s224",
            "value": 1.025,
        },
    },
    {
        "axis": "foot_radius_scale",
        "plain_language": "foot radius relative to the reference body",
        "reference_value": 1.0,
        "low": {
            "generator_index": 225,
            "morphology_id": "qsdk_r05e_axis_star_foot_radius_low_s225",
            "value": 0.99375,
        },
        "high": {
            "generator_index": 226,
            "morphology_id": "qsdk_r05e_axis_star_foot_radius_high_s226",
            "value": 1.025,
        },
    },
    {
        "axis": "front_limb_mass_scale",
        "plain_language": "front-limb mass relative to the reference body",
        "reference_value": 1.0,
        "low": {
            "generator_index": 227,
            "morphology_id": "qsdk_r05e_axis_star_front_limb_mass_low_s227",
            "value": 0.975,
        },
        "high": {
            "generator_index": 228,
            "morphology_id": "qsdk_r05e_axis_star_front_limb_mass_high_s228",
            "value": 1.0125,
        },
    },
]
EXPECTED_MORPHOLOGY_IDS = [
    endpoint[side]["morphology_id"]
    for endpoint in EXPECTED_ENDPOINTS
    for side in ("low", "high")
]
EXPECTED_GENERATOR_INDICES = [
    endpoint[side]["generator_index"]
    for endpoint in EXPECTED_ENDPOINTS
    for side in ("low", "high")
]
EXPECTED_MATERIAL_PROFILES = [
    {
        "profile_id": "godot_jolt_bw5c_mu012_v1",
        "authored_friction": 0.12,
        "characterized_friction_coefficient": 0.1,
    },
    {
        "profile_id": "godot_jolt_bw5c_mu048_v1",
        "authored_friction": 0.48,
        "characterized_friction_coefficient": 0.45,
    },
    {
        "profile_id": "godot_jolt_bw5c_mu095_v1",
        "authored_friction": 0.95,
        "characterized_friction_coefficient": 0.94,
    },
    {
        "profile_id": "godot_jolt_bw5c_mu150_v1",
        "authored_friction": 1.5,
        "characterized_friction_coefficient": 1.0,
    },
]
EXPECTED_UNSUPPORTED = [
    "morphology_by_material_cartesian_product",
    "multi_axis_morphology_combinations",
    "morphology_or_material_interpolation",
    "morphology_or_material_extrapolation",
    "arbitrary_or_continuous_quadruped_coverage",
    "zero_friction_locomotion",
    "rough_or_variable_terrain_robustness",
    "sensor_noise_or_latency_robustness",
    "native_external_push_or_kick_recovery",
    "force_aware_continuous_recovery",
    "general_self_righting",
    "turning_or_recovery_repeatability_rates",
    "formal_cross_engine_equivalence_or_non_inferiority",
    "physical_acceptance_authority",
    "release_or_publication_authority",
]


class DecisionAuditError(RuntimeError):
    """Raised when one exact M08 decision invariant fails."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise DecisionAuditError(message)


def git(*arguments: str, check: bool = True) -> str:
    completed = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if check:
        require(
            completed.returncode == 0,
            f"GIT_FAILED:{' '.join(arguments)}:{completed.stderr.strip()}",
        )
    return completed.stdout.strip()


def git_bytes(commit: str, relative_path: str) -> bytes:
    completed = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "show", f"{commit}:{relative_path}"],
        check=False,
        capture_output=True,
    )
    require(
        completed.returncode == 0,
        f"GIT_SHOW_FAILED:{commit}:{relative_path}",
    )
    return completed.stdout


def sha256(payload: bytes) -> str:
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def raw_identity(path: Path) -> tuple[int, str]:
    payload = path.read_bytes()
    return len(payload), sha256(payload)


def read_json_path(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise DecisionAuditError(f"JSON_UNREADABLE:{path}:{exc}") from exc
    require(isinstance(value, dict), f"JSON_OBJECT_REQUIRED:{path}")
    return value


def read_repo_json(relative_path: str) -> dict[str, Any]:
    return read_json_path(REPO_ROOT / relative_path)


def get_path(value: dict[str, Any], dotted_path: str) -> Any:
    current: Any = value
    for component in dotted_path.split("."):
        require(
            isinstance(current, dict) and component in current,
            f"MISSING_PATH:{dotted_path}",
        )
        current = current[component]
    return current


def set_path(value: dict[str, Any], dotted_path: str, replacement: Any) -> None:
    components = dotted_path.split(".")
    current: Any = value
    for component in components[:-1]:
        current = current[component]
    current[components[-1]] = replacement


def require_exact(value: dict[str, Any], expected: dict[str, Any], label: str) -> None:
    for dotted_path, expected_value in expected.items():
        actual = get_path(value, dotted_path)
        require(
            actual == expected_value and type(actual) is type(expected_value),
            f"{label}:{dotted_path}:expected={expected_value!r}:actual={actual!r}",
        )


def verify_repo_binding(binding: dict[str, Any]) -> None:
    relative = binding["path"]
    path = REPO_ROOT / relative
    require(path.is_file(), f"REPO_BINDING_MISSING:{relative}")
    length, digest = raw_identity(path)
    require(length == binding["byte_length"], f"REPO_BINDING_BYTES:{relative}")
    require(digest == binding["raw_sha256"], f"REPO_BINDING_SHA:{relative}")
    blob = git("rev-parse", f"{DECISION_PARENT}:{relative}")
    require(blob == binding["git_blob_oid"], f"REPO_BINDING_BLOB:{relative}")
    historical_payload = git_bytes(DECISION_PARENT, relative)
    require(len(historical_payload) == length, f"REPO_BINDING_PARENT_BYTES:{relative}")
    require(sha256(historical_payload) == digest, f"REPO_BINDING_PARENT_SHA:{relative}")


def verify_external_binding(binding: dict[str, Any]) -> Path:
    path = Path(binding["path"])
    require(path.is_file(), f"EXTERNAL_BINDING_MISSING:{path}")
    length, digest = raw_identity(path)
    require(length == binding["byte_length"], f"EXTERNAL_BINDING_BYTES:{path}")
    require(digest == binding["raw_sha256"], f"EXTERNAL_BINDING_SHA:{path}")
    return path


def find_gate(contract: dict[str, Any], gate_id: str) -> dict[str, Any]:
    matches = [gate for gate in contract["gates"] if gate.get("gate_id") == gate_id]
    require(len(matches) == 1, f"GATE_UNIQUE:{gate_id}:{len(matches)}")
    return matches[0]


def find_milestone(mapping: dict[str, Any], milestone_id: str) -> dict[str, Any]:
    matches = [
        milestone
        for milestone in mapping["sdk1_contract"]["milestones"]
        if milestone.get("milestone_id") == milestone_id
    ]
    require(len(matches) == 1, f"MILESTONE_UNIQUE:{milestone_id}:{len(matches)}")
    return matches[0]


def validate_decision_shape(decision: dict[str, Any]) -> None:
    require_exact(
        decision,
        {
            "schema_version": "sporespore_qsdk_r13_godot_jolt_sdk1_envelope_decision_v1",
            "decision_id": "SPORESPORE-QSDK-R13-GODOT-JOLT-SDK1-ENVELOPE-DECISION-V1",
            "gate_id": "QSDK-R13",
            "sdk1_milestone_id": "SDK1-M08",
            "status": (
                "closed_zero_world_exact_finite_godot_jolt_sdk1_envelope_"
                "positive_qsdk_r13_satisfied_sdk1_m08_passed"
            ),
            "ledger_scope.subsystem": "release",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": (
                "zero_world_exact_finite_evidence_composition_and_release_gate_adoption"
            ),
            "ledger_scope.question_class": "finite decision",
            "question_class": "finite_decision",
            "physical_question_declared": False,
            "new_physical_evidence_collected": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source_boundary.decision_parent_commit": DECISION_PARENT,
            "source_boundary.decision_parent_tree_git_oid": DECISION_PARENT_TREE,
            "source_boundary.historical_closure_audits_reexecuted_count": 0,
            "source_boundary.historical_evidence_files_verified_directly_by_exact_identity_and_semantics": True,
            "source_boundary.model_construction_count": 0,
            "source_boundary.physics_engine_process_count": 0,
            "source_boundary.world_attempt_count": 0,
            "source_boundary.world_build_count": 0,
            "source_boundary.native_physics_read_count": 0,
            "source_boundary.solver_step_count": 0,
            "source_boundary.physics_state_modified": False,
            "selected_walking_policy.candidate_id": "BW5R-B",
            "selected_walking_policy.policy_id": POLICY_ID,
            "selected_walking_policy.policy_digest": POLICY_DIGEST,
            "selected_walking_policy.branch_surface_count": 0,
            "selected_walking_policy.identity_source_claim_fields_are_historical_freeze_time_fields_not_current_release_dispositions": True,
            "selected_walking_policy.policy_reselected_for_m08": False,
            "selected_walking_policy.policy_threshold_changed_for_m08": False,
            "evidence_slices.interface_passive_and_actuator_foundation.authority_role": "bounded_foundation_only_not_standalone_milestone_authority",
            "evidence_slices.interface_passive_and_actuator_foundation.observed.reported_test_pass_count": 20,
            "evidence_slices.interface_passive_and_actuator_foundation.observed.reported_test_fail_count": 0,
            "evidence_slices.interface_passive_and_actuator_foundation.observed.fixture_world_build_count": 3,
            "evidence_slices.interface_passive_and_actuator_foundation.original_formal_milestone_acceptance_authorized": False,
            "evidence_slices.interface_passive_and_actuator_foundation.original_encyclopedia_admission_authorized": False,
            "evidence_slices.exact_finite_morphology_and_walking.support_topology": "exact_finite_six_axis_local_star_not_a_box_or_interpolation_domain",
            "evidence_slices.exact_finite_morphology_and_walking.observed.morphology_count": 12,
            "evidence_slices.exact_finite_morphology_and_walking.observed.world_count": 36,
            "evidence_slices.exact_finite_morphology_and_walking.observed.walking_pass_count": 36,
            "evidence_slices.exact_finite_morphology_and_walking.observed.integrity_pass_count": 36,
            "evidence_slices.exact_finite_morphology_and_walking.observed.walking_boolean_count": 972,
            "evidence_slices.exact_finite_morphology_and_walking.observed.false_walking_boolean_count": 0,
            "evidence_slices.exact_finite_morphology_and_walking.observed.sdk_step_count": 97862,
            "evidence_slices.exact_finite_morphology_and_walking.observed.validated_command_count": 782896,
            "evidence_slices.exact_finite_morphology_and_walking.observed.native_motor_write_count": 782896,
            "evidence_slices.exact_finite_morphology_and_walking.observed.direct_body_write_count": 0,
            "evidence_slices.exact_finite_morphology_and_walking.claim_boundary.all_twelve_exact_points_under_all_three_exact_seeds": True,
            "evidence_slices.exact_finite_morphology_and_walking.claim_boundary.all_points_between_endpoints": False,
            "evidence_slices.exact_finite_morphology_and_walking.claim_boundary.multi_axis_combinations": False,
            "evidence_slices.exact_finite_morphology_and_walking.claim_boundary.interpolation": False,
            "evidence_slices.exact_finite_morphology_and_walking.claim_boundary.extrapolation": False,
            "evidence_slices.exact_finite_morphology_and_walking.claim_boundary.arbitrary_or_continuous_morphology": False,
            "evidence_slices.bounded_discrete_material_walking.terrain": "flat",
            "evidence_slices.bounded_discrete_material_walking.external_pushes": False,
            "evidence_slices.bounded_discrete_material_walking.sensor_faults": False,
            "evidence_slices.bounded_discrete_material_walking.observed.total_world_count": 17,
            "evidence_slices.bounded_discrete_material_walking.observed.treatment_world_count": 12,
            "evidence_slices.bounded_discrete_material_walking.observed.treatment_pass_count": 12,
            "evidence_slices.bounded_discrete_material_walking.observed.pair_pass_count": 4,
            "evidence_slices.bounded_discrete_material_walking.observed.zero_friction_safety_pass_count": 1,
            "evidence_slices.bounded_discrete_material_walking.observed.passed_gate_count": 28,
            "evidence_slices.bounded_discrete_material_walking.observed.failed_gate_count": 0,
            "evidence_slices.bounded_discrete_material_walking.observed.integrity_failure_count": 0,
            "evidence_slices.bounded_discrete_material_walking.observed.treatment_sdk_step_count": 18168,
            "evidence_slices.bounded_discrete_material_walking.observed.treatment_validated_command_count": 145344,
            "evidence_slices.bounded_discrete_material_walking.observed.treatment_native_actuation_application_count": 145344,
            "evidence_slices.bounded_discrete_material_walking.observed.treatment_direct_body_write_count": 0,
            "evidence_slices.bounded_discrete_material_walking.claim_boundary.four_exact_authored_material_values_on_reference_fixture": True,
            "evidence_slices.bounded_discrete_material_walking.claim_boundary.zero_friction_locomotion_support": False,
            "evidence_slices.bounded_discrete_material_walking.claim_boundary.continuous_friction_coverage": False,
            "evidence_slices.bounded_discrete_material_walking.claim_boundary.arbitrary_material_coverage": False,
            "evidence_slices.bounded_current_capabilities.basic_turning.godot_jolt_gate_passed": True,
            "evidence_slices.bounded_current_capabilities.basic_turning.formal_cross_engine_equivalence": False,
            "evidence_slices.bounded_current_capabilities.basic_turning.repeatability_or_population_claim": False,
            "evidence_slices.bounded_current_capabilities.exact_nominal_prone_to_standing.exact_nominal_gate_passed": True,
            "evidence_slices.bounded_current_capabilities.exact_nominal_prone_to_standing.kick_or_push_entry_tested": False,
            "evidence_slices.bounded_current_capabilities.exact_nominal_prone_to_standing.force_aware_continuous_recovery": False,
            "evidence_slices.bounded_current_capabilities.exact_nominal_prone_to_standing.general_self_righting": False,
            "evidence_slices.bounded_current_capabilities.native_external_push_interaction_and_recovery.supported": False,
            "evidence_composition_rule.evidence_slice_count": 4,
            "evidence_composition_rule.method": "union_of_independently_proven_exact_finite_slices",
            "evidence_composition_rule.all_slice_identities_and_used_semantics_verified": True,
            "evidence_composition_rule.no_new_threshold_or_outcome_derived_correction": True,
            "evidence_composition_rule.no_cross_campaign_world_total_is_used_as_a_scientific_population": True,
            "evidence_composition_rule.no_cross_campaign_deduplication_or_exchangeability_assumed": True,
            "evidence_composition_rule.morphology_by_material_cartesian_product_proven": False,
            "evidence_composition_rule.morphology_material_independence_proven": False,
            "evidence_composition_rule.unsupported_combinations_default_to_explicit_refusal": True,
            "evidence_composition_rule.decision": "positive",
            "advertised_sdk1_godot_jolt_envelope.engine_id": "godot_jolt",
            "advertised_sdk1_godot_jolt_envelope.physics_hz": 120,
            "advertised_sdk1_godot_jolt_envelope.solver_velocity_steps": 20,
            "advertised_sdk1_godot_jolt_envelope.solver_position_steps": 7,
            "advertised_sdk1_godot_jolt_envelope.walking_policy_id": POLICY_ID,
            "advertised_sdk1_godot_jolt_envelope.walking_policy_digest": POLICY_DIGEST,
            "historical_negative_preservation.historical_results_reclassified": False,
            "historical_negative_preservation.historical_thresholds_changed": False,
            "historical_negative_preservation.historical_evaluators_changed": False,
            "historical_negative_preservation.same_identity_reruns_permitted": False,
            "finite_decision_rule.required_named_evidence_slice_count": 4,
            "finite_decision_rule.all_required_slices_identity_valid": True,
            "finite_decision_rule.all_required_used_semantics_positive": True,
            "finite_decision_rule.unsupported_surface_explicit": True,
            "finite_decision_rule.historical_negative_records_preserved": True,
            "finite_decision_rule.result": "positive",
            "finite_decision_rule.q_sdk_r13_satisfied": True,
            "finite_decision_rule.sdk1_m08_satisfied": True,
            "finite_decision_rule.full_program_score_before": "13/25",
            "finite_decision_rule.full_program_score_after": "14/25",
            "finite_decision_rule.sdk1_score_before": "13/20",
            "finite_decision_rule.sdk1_score_after": "14/20",
            "adequacy_and_limits.outcome_derived_threshold_change_count": 0,
            "adequacy_and_limits.policy_reselection_count": 0,
            "adequacy_and_limits.historical_result_rewrite_count": 0,
            "adequacy_and_limits.physical_world_count_added": 0,
            "claim_boundary.q_sdk_r13_satisfied": True,
            "claim_boundary.sdk1_m08_satisfied": True,
            "claim_boundary.godot_jolt_exact_finite_sdk1_envelope_advertised": True,
            "claim_boundary.selected_policy_straight_walking_in_declared_finite_slices": True,
            "claim_boundary.bounded_basic_turning": True,
            "claim_boundary.exact_nominal_prone_to_standing": True,
            "claim_boundary.morphology_material_cartesian_product": False,
            "claim_boundary.arbitrary_or_continuous_morphology": False,
            "claim_boundary.arbitrary_or_continuous_material": False,
            "claim_boundary.external_push_or_kick_recovery": False,
            "claim_boundary.force_aware_continuous_recovery": False,
            "claim_boundary.general_self_righting": False,
            "claim_boundary.formal_cross_engine_equivalence": False,
            "claim_boundary.population_inference": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "claim_boundary.publication_authority": False,
            "audit_execution.historical_physical_audit_reexecution_count": 0,
            "audit_execution.physics_engine_process_count": 0,
            "audit_execution.model_construction_count": 0,
            "audit_execution.world_attempt_count": 0,
            "audit_execution.world_build_count": 0,
            "audit_execution.native_physics_read_count": 0,
            "audit_execution.solver_step_count": 0,
            "audit_execution.physics_state_modified": False,
            "next_boundary.m07_requires_distinct_prospectively_frozen_physical_successor": True,
            "next_boundary.m14_requires_cole_license_and_copyright_holder_decision": True,
            "next_boundary.m20_requires_m07_before_explorer_interaction_closure": True,
            "next_boundary.physical_execution_authorized_by_this_decision": False,
            "next_boundary.release_remains_blocked": True,
        },
        "DECISION_FIELD",
    )
    morphology = decision["evidence_slices"]["exact_finite_morphology_and_walking"]
    require(
        morphology["one_axis_at_a_time_endpoints"] == EXPECTED_ENDPOINTS,
        "DECISION_ENDPOINTS",
    )
    require(morphology["campaign_seeds"] == [40101, 40102, 40103], "R05E_SEEDS")
    require(
        morphology["reference_descriptor"]
        == {
            "torso_length_scale": 1.0,
            "torso_width_scale": 1.0,
            "upper_length_fraction": 0.5142857142857142,
            "hip_span_scale": 1.0,
            "foot_radius_scale": 1.0,
            "front_limb_mass_scale": 1.0,
        },
        "REFERENCE_DESCRIPTOR",
    )
    material = decision["evidence_slices"]["bounded_discrete_material_walking"]
    require(
        material["advertised_material_profiles"] == EXPECTED_MATERIAL_PROFILES,
        "DECISION_MATERIAL_PROFILES",
    )
    require(material["campaign_seeds"] == [20001, 20002, 20003], "BW5C_SEEDS")
    require(
        decision["advertised_sdk1_godot_jolt_envelope"][
            "explicitly_unsupported_or_unproved"
        ]
        == EXPECTED_UNSUPPORTED,
        "UNSUPPORTED_SURFACE",
    )
    require(
        decision["next_boundary"]["current_sdk1_blocking_milestone_ids_after_adoption"]
        == ["SDK1-M07", "SDK1-M14", "SDK1-M20"],
        "NEXT_BLOCKERS",
    )
    require(
        list(decision["evidence_slices"].keys())
        == [
            "interface_passive_and_actuator_foundation",
            "exact_finite_morphology_and_walking",
            "bounded_discrete_material_walking",
            "bounded_current_capabilities",
        ],
        "EVIDENCE_SLICE_SET",
    )
    require(len(decision["pre_adoption_authorities"]) == 3, "PRE_AUTHORITY_COUNT")
    records = decision["historical_negative_preservation"]["records"]
    require(
        [(record["role"], record["preserved_disposition"]) for record in records]
        == [
            ("legacy_c6_selection_negative", "negative"),
            ("legacy_c6r_heldout_r1_negative", "negative"),
        ],
        "HISTORICAL_NEGATIVE_ROLES",
    )


def validate_pre_adoption_authorities(decision: dict[str, Any]) -> None:
    expected_paths = [CONTRACT_PATH, SUPPORT_MATRIX_PATH, MAPPING_PATH]
    authorities = decision["pre_adoption_authorities"]
    require([item["path"] for item in authorities] == expected_paths, "PRE_PATH_ORDER")
    parsed: dict[str, dict[str, Any]] = {}
    for authority in authorities:
        require(authority["commit"] == DECISION_PARENT, "PRE_COMMIT")
        payload = git_bytes(DECISION_PARENT, authority["path"])
        require(len(payload) == authority["byte_length"], f"PRE_BYTES:{authority['path']}")
        require(sha256(payload) == authority["raw_sha256"], f"PRE_SHA:{authority['path']}")
        require(
            git("rev-parse", f"{DECISION_PARENT}:{authority['path']}")
            == authority["git_blob_oid"],
            f"PRE_BLOB:{authority['path']}",
        )
        parsed[authority["path"]] = json.loads(payload.decode("utf-8"))

    old_r13 = find_gate(parsed[CONTRACT_PATH], "QSDK-R13")
    require(old_r13["proof"]["kind"] == "missing", "PRE_R13_NOT_MISSING")
    require(
        parsed[SUPPORT_MATRIX_PATH]["engines"]["godot_jolt"][
            "selected_policy_physical_c6"
        ]
        is False,
        "PRE_GODOT_C6_NOT_FALSE",
    )
    old_m08 = find_milestone(parsed[MAPPING_PATH], "SDK1-M08")
    require(old_m08["source"]["gate_id"] == "QSDK-R13", "PRE_M08_SOURCE")
    require(
        authorities[0]["pre_adoption_r13_disposition"] == "missing"
        and authorities[1][
            "pre_adoption_godot_jolt_selected_policy_physical_c6"
        ]
        is False
        and authorities[2]["pre_adoption_m08_disposition"] == "missing",
        "PRE_RECORDED_DISPOSITIONS",
    )


def validate_selected_policy(decision: dict[str, Any]) -> None:
    binding = decision["selected_walking_policy"]["identity_source"]
    verify_repo_binding(binding)
    selected = read_repo_json(binding["path"])
    require_exact(
        selected,
        {
            "schema_version": "sporespore_balanced_wave_selected_policy_v1",
            "selected_candidate_id": "BW5R-B",
            "selected_policy_id": POLICY_ID,
            "selected_candidate_policy_digest": POLICY_DIGEST,
        },
        "SELECTED_POLICY",
    )
    require(selected["selected_profile"]["branch_surfaces"] == [], "POLICY_BRANCHES")


def validate_c2_c5(decision: dict[str, Any]) -> None:
    slice_ = decision["evidence_slices"]["interface_passive_and_actuator_foundation"]
    path = verify_external_binding(slice_["evidence"])
    transcript = path.read_text(encoding="utf-8")
    prefix = slice_["evidence"]["receipt_prefix"]
    lines = [line for line in transcript.splitlines() if line.startswith(prefix)]
    require(len(lines) == 1, f"C2_C5_RECEIPT_COUNT:{len(lines)}")
    receipt = json.loads(lines[0][len(prefix) :])
    require_exact(
        receipt,
        {
            "schema_version": "sporespore_godot_jolt_c2_c5_receipt_v1",
            "ok": True,
            "physics_engine": "Jolt Physics",
            "physics_hz": 120,
            "solver_velocity_steps": 20,
            "solver_position_steps": 7,
            "c2_c5_adapter.ok": True,
            "c2_c5_adapter.c2_topology_complete": True,
            "c2_c5_adapter.c2_frames_and_limits_bounded": True,
            "c2_c5_adapter.c2_coordinate_conversion_bounded": True,
            "c2_c5_adapter.c4_declared_capabilities_exact": True,
            "c2_c5_adapter.c5_declared_capabilities_exact": True,
            "c2_c5_adapter.c5_live_contact_complete": True,
            "c2_c5_adapter.c5_contact_ids_persistent": True,
            "c2_c5_adapter.c5_unavailable_load_preserved": True,
            "c3_passive.ok": True,
            "c3_passive.mass_inertia_round_trip": True,
            "c3_passive.free_fall_bounded": True,
            "c3_passive.unconstrained_integration_bounded": True,
            "c3_passive.damping_response_bounded": True,
            "c3_passive.pendulum_response_bounded": True,
            "c4_actuator.ok": True,
            "c4_actuator.parameters_round_trip": True,
            "c4_actuator.pd_conversion_bounded": True,
            "c4_actuator.impulse_response_ordered": True,
            "c4_actuator.physical_response_bounded": True,
            "formal_milestone_acceptance_authorized": False,
            "encyclopedia_admission_authorized": False,
        },
        "C2_C5",
    )
    world_count = sum(
        receipt[name]["world_build_count"]
        for name in ("c2_c5_adapter", "c3_passive", "c4_actuator")
    )
    require(world_count == 3, "C2_C5_WORLD_COUNT")
    require(
        "SDK Godot/Jolt C2-C5 summary: 20 passed, 0 failed" in transcript,
        "C2_C5_SUMMARY",
    )


def validate_r05e(decision: dict[str, Any]) -> None:
    slice_ = decision["evidence_slices"]["exact_finite_morphology_and_walking"]
    for name in (
        "physical_closure",
        "zero_world_qualification_closure",
        "preregistration",
        "literal_descriptor_source",
    ):
        verify_repo_binding(slice_[name])

    closure = read_repo_json(slice_["physical_closure"]["path"])
    require_exact(
        closure,
        {
            "schema_version": "sporespore_qsdk_r05e_exact_finite_morphology_physical_closure_v1",
            "status": "closed_consumed_complete_held_out_finite_positive_eligible_for_separate_qsdk_r05_adoption",
            "ledger_scope.question_class": "finite decision",
            "source_and_authority.source_freeze_commit": "54d23a7afcca6e98f35eebf5479b1fd145b11c23",
            "source_and_authority.qualification_commit": "3228ad65f3afafe0d53572a0bc375e89ff0ea85c",
            "source_and_authority.authorization_commit": "2c47d8b05e3f46f1c752bc544937c0b69826069e",
            "selected_policy.candidate_id": "BW5R-B",
            "selected_policy.controller_policy_id": POLICY_ID,
            "selected_policy.candidate_policy_digest": POLICY_DIGEST,
            "selected_policy.policy_branch_surface_count": 0,
            "engine_and_material.adapter_id": "godot_jolt_gdextension_v1",
            "engine_and_material.physics_engine": "Jolt Physics",
            "engine_and_material.physics_hz": 120,
            "engine_and_material.solver_velocity_steps": 20,
            "engine_and_material.solver_position_steps": 7,
            "engine_and_material.material_profile_id": "godot_jolt_bw5c_mu095_v1",
            "engine_and_material.authored_friction": 0.95,
            "engine_and_material.characterized_friction_coefficient": 0.94,
            "physical_attempt.physical_identity_consumed": True,
            "physical_attempt.same_identity_rerun_permitted": False,
            "physical_attempt.observed_world_count": 36,
            "population.morphology_count": 12,
            "population.cartesian_world_count": 36,
            "outcome.walking_pass_count": 36,
            "outcome.integrity_pass_count": 36,
            "outcome.mechanism_pass_count": 36,
            "outcome.combined_application_pass_count": 36,
            "outcome.walking_gate_receipt_count": 972,
            "outcome.false_walking_gate_receipt_count": 0,
            "outcome.r05e_passed": True,
            "authority_and_integrity.sdk_step_count": 97862,
            "authority_and_integrity.validated_balanced_wave_command_count": 782896,
            "authority_and_integrity.native_motor_write_count": 782896,
            "authority_and_integrity.native_motor_write_count_per_sdk_step": 8,
            "authority_and_integrity.direct_body_write_count": 0,
            "authority_and_integrity.legacy_post_settle_motor_write_count": 0,
            "authority_and_integrity.legacy_evidence_motor_write_count": 0,
            "authority_and_integrity.sdk_mismatch_count": 0,
            "decision.accepted": True,
            "decision.qsdk_r05e_finite_decision_passed": True,
            "claim_boundary.exact_twelve_descriptor_identities_under_exact_three_seeds_only": True,
            "claim_boundary.finite_population_only": True,
            "claim_boundary.multi_axis_combinations_supported": False,
            "claim_boundary.interpolation_supported": False,
            "claim_boundary.extrapolation_supported": False,
            "claim_boundary.arbitrary_quadruped_coverage": False,
            "claim_boundary.material_or_friction_robustness": False,
            "claim_boundary.physical_acceptance_authority": False,
            "audit_execution.world_build_count": 0,
            "audit_execution.solver_step_count": 0,
        },
        "R05E_CLOSURE",
    )
    require(
        closure["population"]["morphology_ids"] == EXPECTED_MORPHOLOGY_IDS,
        "R05E_CLOSURE_IDS",
    )
    require(
        closure["population"]["generator_indices"] == EXPECTED_GENERATOR_INDICES,
        "R05E_CLOSURE_INDICES",
    )
    require(
        closure["population"]["campaign_seeds"] == [40101, 40102, 40103],
        "R05E_CLOSURE_SEEDS",
    )

    qualification = read_repo_json(slice_["zero_world_qualification_closure"]["path"])
    require_exact(
        qualification,
        {
            "status": "closed_complete_zero_world_qualification_physics_still_sealed",
            "source.source_freeze_commit": "54d23a7afcca6e98f35eebf5479b1fd145b11c23",
            "qualification.official_zero_world_qualification_passed": True,
            "qualification.qualified_source_path_count": 80,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.native_readback_count": 0,
            "qualification.solver_step_count": 0,
            "qualification.physics_state_modified": False,
            "decision.qualification_complete": True,
            "decision.physical_execution_authorized": False,
            "claim_boundary.physical_attempted": False,
            "claim_boundary.physical_acceptance_authority": False,
        },
        "R05E_QUALIFICATION",
    )

    preregistration = read_repo_json(slice_["preregistration"]["path"])
    require(
        preregistration["morphology_generator"]["generator_indices"]
        == EXPECTED_GENERATOR_INDICES,
        "R05E_PREREG_INDICES",
    )
    require(
        [
            cell["morphology_id"]
            for cell in preregistration["morphology_generator"]["cells"]
        ]
        == EXPECTED_MORPHOLOGY_IDS,
        "R05E_PREREG_IDS",
    )
    require_exact(
        preregistration,
        {
            "selected_candidate_id": "BW5R-B",
            "selected_policy_id": POLICY_ID,
            "selected_policy_digest": POLICY_DIGEST,
            "repetitions.expected_world_count": 36,
            "walking_gate.all_36_cells_must_walk": True,
            "acceptance.all_cells_walk": True,
            "claim_boundary.multi_axis_combinations_supported": False,
            "claim_boundary.interpolation_supported": False,
            "claim_boundary.extrapolation_supported": False,
        },
        "R05E_PREREG",
    )

    report_path = verify_external_binding(slice_["physical_report"])
    report = read_json_path(report_path)
    require_exact(
        report,
        {
            "schema_version": "sporespore_qsdk_r05e_exact_finite_morphology_report_v1",
            "gate_id": "QSDK-R05E",
            "selected_candidate_id": "BW5R-B",
            "selected_policy_id": POLICY_ID,
            "selected_policy_digest": POLICY_DIGEST,
            "expected_world_count": 36,
            "observed_world_count": 36,
            "complete_receipt_count": 36,
            "harness_pass_count": 36,
            "walking_pass_count": 36,
            "integrity_pass_count": 36,
            "failure_count": 0,
            "material_profile_id": "godot_jolt_bw5c_mu095_v1",
            "authored_friction": 0.95,
            "same_selected_policy_independent_morphology_evidence": True,
            "finite_population_only": True,
            "arbitrary_quadruped_coverage": False,
            "continuous_full_volume_coverage": False,
            "material_robustness": False,
            "external_push_recovery": False,
            "sensor_noise_or_latency_robustness": False,
            "r05e_passed": True,
            "physical_acceptance_authority": False,
        },
        "R05E_REPORT",
    )
    require(report["morphology_ids"] == EXPECTED_MORPHOLOGY_IDS, "R05E_REPORT_IDS")
    require(
        report["generator_indices"] == EXPECTED_GENERATOR_INDICES,
        "R05E_REPORT_INDICES",
    )
    require(report["campaign_seeds"] == [40101, 40102, 40103], "R05E_REPORT_SEEDS")
    results = report["results"]
    require(len(results) == 36, "R05E_RESULT_COUNT")
    expected_pairs = set(itertools.product(EXPECTED_MORPHOLOGY_IDS, [40101, 40102, 40103]))
    observed_pairs = {(row["morphology_id"], row["campaign_seed"]) for row in results}
    require(observed_pairs == expected_pairs, "R05E_EXACT_CARTESIAN_WITHIN_SLICE")
    require(all(row["harness_passed"] is True for row in results), "R05E_HARNESS")
    require(all(row["walking_observed"] is True for row in results), "R05E_WALKING")
    require(
        all(row["common_execution_integrity"] is True for row in results),
        "R05E_INTEGRITY",
    )
    require(
        all(row["mechanism_gate_passed"] is True for row in results),
        "R05E_MECHANISM",
    )
    require(
        all(row["combined_application_gate_passed"] is True for row in results),
        "R05E_COMBINED_APPLICATION",
    )
    receipts = [row["receipt"] for row in results]
    walking_boolean_count = sum(
        len(receipt["walking_gate_receipts"]) for receipt in receipts
    )
    require(walking_boolean_count == 972, "R05E_WALKING_BOOLEAN_COUNT")
    require(
        all(
            all(value is True for value in receipt["walking_gate_receipts"].values())
            for receipt in receipts
        ),
        "R05E_WALKING_BOOLEAN_FALSE",
    )
    require(sum(r["sdk_step_count"] for r in receipts) == 97862, "R05E_STEP_SUM")
    require(
        sum(r["validated_balanced_wave_command_count"] for r in receipts) == 782896,
        "R05E_COMMAND_SUM",
    )
    require(
        sum(r["native_motor_write_count"] for r in receipts) == 782896,
        "R05E_WRITE_SUM",
    )
    require(sum(r["direct_body_write_count"] for r in receipts) == 0, "R05E_BODY_WRITE")
    require(
        sum(r["legacy_post_settle_motor_write_count"] for r in receipts) == 0,
        "R05E_LEGACY_POST_SETTLE",
    )
    require(
        sum(r["legacy_evidence_motor_write_count"] for r in receipts) == 0,
        "R05E_LEGACY_EVIDENCE",
    )
    require(sum(r["sdk_mismatch_count"] for r in receipts) == 0, "R05E_MISMATCH")


def validate_bw5c(decision: dict[str, Any]) -> None:
    slice_ = decision["evidence_slices"]["bounded_discrete_material_walking"]
    report_path = verify_external_binding(slice_["physical_report"])
    report = read_json_path(report_path)
    require_exact(
        report,
        {
            "schema_version": "sporespore_balanced_wave_bw5c_validation_report_v1",
            "accepted": True,
            "result_status": "cold_acceptance_passed",
            "campaign_partition": "cold_acceptance",
            "candidate_id": "BW5R-B",
            "policy_id": POLICY_ID,
            "candidate_policy_digest": POLICY_DIGEST,
            "cold_acceptance": True,
            "walking_acceptance": True,
            "bounded_discrete_material_robustness": True,
            "material_robustness": True,
            "arbitrary_material_robustness": False,
            "continuous_friction_coverage": False,
            "arbitrary_quadruped_coverage": False,
            "continuous_full_volume_coverage": False,
            "rough_terrain_robustness": False,
            "external_push_recovery": False,
            "sensor_fault_robustness": False,
            "cross_engine_c6": False,
            "completed_engine_neutral_sdk": False,
            "physical_acceptance_authority": False,
            "receipt.expected_world_count": 17,
            "receipt.observed_world_count": 17,
            "receipt.expected_treatment_count": 12,
            "receipt.observed_treatment_count": 12,
            "receipt.observed_treatment_pass_count": 12,
            "receipt.expected_control_count": 4,
            "receipt.observed_control_pass_count": 4,
            "receipt.expected_pair_count": 4,
            "receipt.observed_pair_pass_count": 4,
            "receipt.expected_zero_friction_safety_count": 1,
            "receipt.observed_zero_friction_safety_pass_count": 1,
            "receipt.expected_gate_count": 28,
            "receipt.passed_gate_count": 28,
            "receipt.failed_gate_count": 0,
            "receipt.integrity_failure_count": 0,
        },
        "BW5C",
    )
    scope = report["material_robustness_scope"]
    require(
        scope
        == {
            "adapter_id": "godot_jolt_gdextension_v1",
            "authored_friction_values": [0.12, 0.48, 0.95, 1.5],
            "controller_policy_id": POLICY_ID,
            "external_pushes": False,
            "fixture": "physical_quadruped_fixture_spec.reference_spec",
            "physics_engine": "Jolt Physics",
            "physics_hz": 120.0,
            "seeds": [20001.0, 20002.0, 20003.0],
            "sensor_faults": False,
            "solver_position_steps": 7.0,
            "solver_velocity_steps": 20.0,
            "terrain": "flat",
        },
        "BW5C_SCOPE",
    )
    profile_rows = [
        {
            "profile_id": row["profile_id"],
            "authored_friction": row["authored_friction"],
            "characterized_friction_coefficient": row[
                "characterized_friction_coefficient"
            ],
        }
        for row in report["receipt"]["profile_receipts"]
        if row["authored_friction"] != 0.0
    ]
    require(profile_rows == EXPECTED_MATERIAL_PROFILES, "BW5C_PROFILES")
    cells = report["receipt"]["cells"]
    treatments = [
        row
        for row in cells
        if row["cohort"] == "validation" and row["mode"] == "treatment"
    ]
    require(len(treatments) == 12, "BW5C_TREATMENT_COUNT")
    require(
        {(row["profile_id"], row["campaign_seed"]) for row in treatments}
        == set(
            itertools.product(
                [profile["profile_id"] for profile in EXPECTED_MATERIAL_PROFILES],
                [20001, 20002, 20003],
            )
        ),
        "BW5C_TREATMENT_GRID",
    )
    require(all(row["treatment_gate_passed"] is True for row in treatments), "BW5C_GATES")
    require(all(row["walking_observed"] is True for row in treatments), "BW5C_WALKING")
    require(
        all(row["common_execution_integrity"] is True for row in treatments),
        "BW5C_INTEGRITY",
    )
    require(sum(row["step_count"] for row in treatments) == 18168, "BW5C_STEPS")
    require(
        sum(row["validated_balanced_wave_command_count"] for row in treatments)
        == 145344,
        "BW5C_COMMANDS",
    )
    require(
        sum(row["native_actuation_application_count"] for row in treatments)
        == 145344,
        "BW5C_NATIVE_APPLICATIONS",
    )
    require(
        sum(row["portable_controller_base_application_count"] for row in treatments)
        == 145344,
        "BW5C_PORTABLE_APPLICATIONS",
    )
    require(
        sum(row["direct_body_write_count"] for row in treatments) == 0,
        "BW5C_BODY_WRITES",
    )


def validate_capabilities(decision: dict[str, Any]) -> None:
    capabilities = decision["evidence_slices"]["bounded_current_capabilities"]
    turning_binding = capabilities["basic_turning"]["closure"]
    verify_repo_binding(turning_binding)
    turning = read_repo_json(turning_binding["path"])
    require_exact(
        turning,
        {
            "status": "closed_consumed_valid_complete_positive_exact_seed_23199_three_engine_portable_turning",
            "retained_physical_attempt.campaign_seed": 23199,
            "retained_physical_attempt.engine_results.godot_jolt.passed": True,
            "retained_physical_attempt.engine_results.godot_jolt.all_common_physical_gates_passed": True,
            "retained_physical_attempt.engine_results.godot_jolt.all_three_cells_execution_valid": True,
            "retained_physical_attempt.engine_results.godot_jolt.positive_reference_conditioned_cycle_shift_rad": 0.21771034587650862,
            "retained_physical_attempt.engine_results.godot_jolt.negative_reference_conditioned_cycle_shift_rad": 0.15143261911316452,
            "official_result.finite_three_engine_turning_positive": True,
            "official_result.cross_engine_equivalence_test_invoked": False,
            "official_result.population_inference_attempted": False,
            "adequacy_and_claim_boundary.formal_cross_engine_equivalence_established": False,
            "adequacy_and_claim_boundary.repeatability_established": False,
            "claims.godot_jolt_frozen_turning_gates_passed": True,
            "claims.cross_engine_equivalence": False,
            "claims.population_robustness": False,
            "claims.physical_acceptance_authority": False,
            "claims.release_authority": False,
        },
        "TURNING",
    )
    godot_cells = [
        row
        for row in turning["retained_physical_attempt"]["retained_cells"]
        if row["engine_id"] == "godot_jolt"
    ]
    require(len(godot_cells) == 3, "TURNING_GODOT_CELL_COUNT")
    require(
        all(row["controller_semantic_step_count"] == 2992 for row in godot_cells),
        "TURNING_STEP_COUNT",
    )
    require(
        all(row["official_execution_valid"] is True for row in godot_cells),
        "TURNING_EXECUTION",
    )

    recovery_binding = capabilities["exact_nominal_prone_to_standing"]["decision"]
    verify_repo_binding(recovery_binding)
    recovery = read_repo_json(recovery_binding["path"])
    require_exact(
        recovery,
        {
            "schema_version": "sporespore_qsdk_r24d173_three_engine_canonical_prone_to_standing_decision_v1",
            "status": "closed_zero_world_finite_conjunction_positive_qsdk_r24_satisfied_sdk1_m19_passed",
            "finite_decision_rule.q_sdk_r24_satisfied": True,
            "finite_decision_rule.sdk1_m19_satisfied": True,
            "claim_boundary.prone_to_standing": True,
            "claim_boundary.cross_engine_equivalence_claimed": False,
            "claim_boundary.repeatability_claimed": False,
            "claim_boundary.population_claimed": False,
            "claim_boundary.general_self_righting_claimed": False,
            "claim_boundary.physical_balance_recovery_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
        },
        "RECOVERY",
    )
    godot = [
        row
        for row in recovery["immutable_engine_results"]
        if row["engine_id"] == "godot_jolt"
    ]
    require(len(godot) == 1, "RECOVERY_GODOT_RESULT_COUNT")
    require_exact(
        godot[0],
        {
            "gate_id": "QSDK-R24D172",
            "question_class": "development",
            "physical_attempt_consumed": True,
            "candidate_terminal_phase": "complete",
            "candidate_terminal_step": 240,
            "matched_zero_terminal_phase": "failed",
            "portable_evaluation_verdict": "physical_development_passed",
            "exact_nominal_prone_to_standing_observed": True,
            "recovery_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v6",
        },
        "RECOVERY_GODOT",
    )


def validate_historical_negatives(decision: dict[str, Any]) -> None:
    records = decision["historical_negative_preservation"]["records"]
    expected = [
        ("G4-GQ15-SELECTION", "selection", 12, 10, 382, 14),
        ("G4-GQ15-HELDOUT-R1", "heldout", 8, 6, 254, 10),
    ]
    legacy_digest = "sha256:db8810a6a52c93348598e5a29a9d54bfef2b38121c13032b4e8fd421c9a16b04"
    for record, expected_row in zip(records, expected, strict=True):
        path = verify_external_binding(record)
        report = read_json_path(path)
        campaign, role, count, walked, assertions_passed, assertions_failed = expected_row
        require(report["campaign_id"] == campaign, f"LEGACY_CAMPAIGN:{campaign}")
        require(report["campaign_role"] == role, f"LEGACY_ROLE:{campaign}")
        require(len(report["results"]) == count, f"LEGACY_RESULT_COUNT:{campaign}")
        require(
            sum(row["walking_observed"] is True for row in report["results"]) == walked,
            f"LEGACY_WALKED:{campaign}",
        )
        require(
            int(report["total_assertions_passed"]) == assertions_passed,
            f"LEGACY_ASSERTIONS_PASS:{campaign}",
        )
        require(
            int(report["total_assertions_failed"]) == assertions_failed,
            f"LEGACY_ASSERTIONS_FAIL:{campaign}",
        )
        require(report["formula_policy_sha256"] == legacy_digest, "LEGACY_POLICY")
        require(
            all(row["policy_sha256"] == legacy_digest for row in report["results"]),
            "LEGACY_POLICY_ROWS",
        )
        for field in (
            "all_harnesses_passed",
            "all_cells_walked",
            "selection_eligible",
            "held_out_repetition_passed",
            "sdk_c6_selection_eligible",
            "sdk_c6_held_out_repetition_passed",
            "finite_gq15_godot_jolt_sdk_c6_confirmed",
            "morphology_generalization_established",
            "formal_milestone_acceptance_authorized",
        ):
            require(report[field] is False, f"LEGACY_NEGATIVE:{campaign}:{field}")
        require(record["campaign_id"] == campaign, "LEGACY_RECORD_CAMPAIGN")
        require(record["morphology_count"] == count, "LEGACY_RECORD_COUNT")
        require(record["walking_pass_count"] == walked, "LEGACY_RECORD_WALKED")
        require(record["assertion_pass_count"] == assertions_passed, "LEGACY_RECORD_PASS")
        require(record["assertion_fail_count"] == assertions_failed, "LEGACY_RECORD_FAIL")
        require(record["finite_godot_jolt_c6_confirmed"] is False, "LEGACY_RECORD_C6")
        require(record["preserved_disposition"] == "negative", "LEGACY_RECORD_DISPOSITION")


def expected_r13_predicates() -> list[dict[str, Any]]:
    return [
        {
            "path": "status",
            "equals": (
                "closed_zero_world_exact_finite_godot_jolt_sdk1_envelope_"
                "positive_qsdk_r13_satisfied_sdk1_m08_passed"
            ),
        },
        {"path": "ledger_scope.question_class", "equals": "finite decision"},
        {"path": "selected_walking_policy.policy_id", "equals": POLICY_ID},
        {"path": "evidence_composition_rule.decision", "equals": "positive"},
        {
            "path": "evidence_composition_rule.morphology_by_material_cartesian_product_proven",
            "equals": False,
        },
        {"path": "finite_decision_rule.q_sdk_r13_satisfied", "equals": True},
        {"path": "finite_decision_rule.sdk1_m08_satisfied", "equals": True},
        {
            "path": "claim_boundary.godot_jolt_exact_finite_sdk1_envelope_advertised",
            "equals": True,
        },
        {"path": "claim_boundary.external_push_or_kick_recovery", "equals": False},
        {"path": "claim_boundary.force_aware_continuous_recovery", "equals": False},
        {"path": "claim_boundary.formal_cross_engine_equivalence", "equals": False},
        {
            "path": "historical_negative_preservation.historical_results_reclassified",
            "equals": False,
        },
        {"path": "claim_boundary.physical_acceptance_authority", "equals": False},
        {"path": "claim_boundary.release_authority", "equals": False},
    ]


def run_json_powershell(relative_path: str) -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(REPO_ROOT / relative_path)],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    require(
        completed.returncode == 0,
        f"POWERSHELL_COMPILER_FAILED:{relative_path}:{completed.stderr[-2000:]}",
    )
    marker = (
        "QUADRUPED_SDK1_MILESTONE_READINESS "
        if relative_path == SDK1_COMPILER_PATH
        else "QUADRUPED_SDK_RELEASE_READINESS "
    )
    json_lines = [
        line[len(marker) :]
        for line in completed.stdout.splitlines()
        if line.startswith(marker)
    ]
    require(len(json_lines) == 1, f"POWERSHELL_COMPILER_JSON_COUNT:{relative_path}")
    try:
        result = json.loads(json_lines[0])
    except json.JSONDecodeError as exc:
        raise DecisionAuditError(
            f"POWERSHELL_COMPILER_JSON:{relative_path}:{completed.stdout[-2000:]}"
        ) from exc
    require(isinstance(result, dict), f"POWERSHELL_COMPILER_OBJECT:{relative_path}")
    return result


def validate_current_adoption() -> tuple[dict[str, Any], dict[str, Any]]:
    contract = read_repo_json(CONTRACT_PATH)
    support = read_repo_json(SUPPORT_MATRIX_PATH)
    mapping = read_repo_json(MAPPING_PATH)
    r13 = find_gate(contract, "QSDK-R13")
    require(
        r13["requirement"]
        == (
            "Godot/Jolt passes the complete exact-finite morphology, material, "
            "actuator, walking, and capability envelope the bounded SDK1 release "
            "advertises."
        ),
        "CURRENT_R13_REQUIREMENT",
    )
    require(
        r13["proof"]
        == {
            "kind": "repo_json",
            "path": DECISION_PATH,
            "sha256": DECISION_SHA256,
            "predicates": expected_r13_predicates(),
        },
        "CURRENT_R13_PROOF",
    )
    godot = support["engines"]["godot_jolt"]
    expected_support = {
        "selected_policy_physical_c6": True,
        "quadruped_submission_advertised": True,
        "sdk1_exact_finite_envelope_decision_path": DECISION_PATH,
        "sdk1_exact_finite_envelope_decision_raw_sha256": DECISION_SHA256,
        "sdk1_exact_finite_envelope_status": (
            "closed_zero_world_exact_finite_godot_jolt_sdk1_envelope_"
            "positive_qsdk_r13_satisfied_sdk1_m08_passed"
        ),
        "sdk1_exact_finite_envelope_zero_world_adoption": True,
        "sdk1_exact_finite_envelope_policy_id": POLICY_ID,
        "sdk1_exact_finite_envelope_policy_digest": POLICY_DIGEST,
        "sdk1_exact_finite_morphology_point_count": 12,
        "sdk1_exact_finite_morphology_world_count": 36,
        "sdk1_exact_finite_morphology_walking_pass_count": 36,
        "sdk1_exact_finite_material_profile_count": 4,
        "sdk1_exact_finite_material_treatment_world_count": 12,
        "sdk1_exact_finite_material_treatment_pass_count": 12,
        "sdk1_interface_passive_actuator_foundation_passed": True,
        "sdk1_basic_turning_exact_seed_passed": True,
        "sdk1_exact_nominal_prone_to_standing_passed": True,
        "sdk1_morphology_material_cartesian_product_claimed": False,
        "sdk1_external_push_or_kick_recovery": False,
        "sdk1_force_aware_continuous_recovery": False,
        "sdk1_formal_cross_engine_equivalence": False,
        "sdk1_physical_acceptance_authority": False,
        "sdk1_release_or_publication_authorized": False,
    }
    for key, expected_value in expected_support.items():
        require(
            godot.get(key) == expected_value
            and type(godot.get(key)) is type(expected_value),
            f"CURRENT_SUPPORT:{key}",
        )
    require(
        godot.get("sdk1_exact_finite_material_authored_friction_values")
        == [0.12, 0.48, 0.95, 1.5],
        "CURRENT_SUPPORT_MATERIAL_VALUES",
    )
    require(
        godot.get("sdk1_selected_policy_physical_c6_scope")
        == "bounded_sdk1_exact_finite_union_not_legacy_c6_population",
        "CURRENT_SUPPORT_SCOPE",
    )
    require(
        support["claim_boundary"].get("cross_engine_c6") is True,
        "CURRENT_SUPPORT_THREE_ENGINE_FINITE_ENVELOPES",
    )
    require(
        support["claim_boundary"].get(
            "formal_cross_engine_comparative_inference"
        )
        is False,
        "CURRENT_SUPPORT_NO_FORMAL_COMPARATIVE_INFERENCE",
    )
    require(
        support["comparative_inference"].get("formal_equivalence_study_accepted")
        is False
        and support["comparative_inference"].get(
            "formal_non_inferiority_study_accepted"
        )
        is False
        and support["comparative_inference"].get("release_comparative_gate_passed")
        is False,
        "CURRENT_SUPPORT_NO_FORMAL_EQUIVALENCE_OR_NON_INFERIORITY",
    )

    contract_length, contract_sha = raw_identity(REPO_ROOT / CONTRACT_PATH)
    support_length, support_sha = raw_identity(REPO_ROOT / SUPPORT_MATRIX_PATH)
    require(contract_length > 0 and support_length > 0, "CURRENT_AUTHORITY_BYTES")
    require(
        mapping["full_program_authority"]["release_contract_raw_sha256"]
        == contract_sha,
        "CURRENT_MAPPING_CONTRACT_SHA",
    )
    require(
        mapping["full_program_authority"]["support_matrix_raw_sha256"]
        == support_sha,
        "CURRENT_MAPPING_SUPPORT_SHA",
    )
    m08 = find_milestone(mapping, "SDK1-M08")
    require(m08["source"] == {"kind": "full_program_gate", "gate_id": "QSDK-R13"}, "M08_SOURCE")

    full = run_json_powershell(FULL_COMPILER_PATH)
    require_exact(
        full,
        {
            "status": "blocked",
            "release_ready": False,
            "package_authorized": False,
            "publication_authorized": False,
            "gate_counts.required_for_release": 25,
            "gate_counts.required_passed": 14,
            "gate_counts.required_missing": 8,
            "gate_counts.required_contradicted": 3,
            "gate_counts.required_invalid_proof": 0,
            "support_matrix.consistent_with_gate_dispositions": True,
        },
        "FULL_COMPILER",
    )
    require(
        full["blocking_gate_ids"]
        == [
            "QSDK-R01",
            "QSDK-R06",
            "QSDK-R07",
            "QSDK-R09",
            "QSDK-R10",
            "QSDK-R11",
            "QSDK-R12",
            "QSDK-R16",
            "QSDK-R19",
            "QSDK-R20",
            "QSDK-R25",
        ],
        "FULL_BLOCKERS",
    )
    require(
        full["clean_room_candidate_blocking_gate_ids"]
        == [
            "QSDK-R06",
            "QSDK-R07",
            "QSDK-R09",
            "QSDK-R10",
            "QSDK-R11",
            "QSDK-R12",
            "QSDK-R19",
            "QSDK-R25",
        ],
        "FULL_CANDIDATE_BLOCKERS",
    )

    sdk1 = run_json_powershell(SDK1_COMPILER_PATH)
    require_exact(
        sdk1,
        {
            "status": "blocked",
            "sdk1_milestones_complete": False,
            "mapping_completion_authorizes_release": False,
            "sdk1_counts.total": 20,
            "sdk1_counts.passed": 14,
            "sdk1_counts.missing": 5,
            "sdk1_counts.contradicted": 1,
            "sdk1_counts.invalid_proof": 0,
            "full_program.required_passed": 14,
            "full_program.required_total": 25,
            "full_program.denominator_changed": False,
        },
        "SDK1_COMPILER",
    )
    require(
        sdk1["clean_room_candidate_blocking_milestone_ids"]
        == ["SDK1-M07", "SDK1-M14", "SDK1-M20"],
        "SDK1_CANDIDATE_BLOCKERS",
    )
    m08_results = [
        row for row in sdk1["milestones"] if row["milestone_id"] == "SDK1-M08"
    ]
    require(
        len(m08_results) == 1 and m08_results[0]["disposition"] == "passed",
        "SDK1_M08_NOT_PASSED",
    )
    return full, sdk1


def validate_mutation_refusals(decision: dict[str, Any]) -> int:
    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("gate", lambda value: set_path(value, "gate_id", "QSDK-R12")),
        (
            "ledger_question",
            lambda value: set_path(value, "ledger_scope.question_class", "development"),
        ),
        (
            "physical",
            lambda value: set_path(value, "new_physical_evidence_collected", True),
        ),
        (
            "world",
            lambda value: set_path(value, "source_boundary.world_build_count", 1),
        ),
        (
            "policy",
            lambda value: set_path(
                value, "selected_walking_policy.policy_id", "forged_policy"
            ),
        ),
        (
            "endpoint",
            lambda value: value["evidence_slices"][
                "exact_finite_morphology_and_walking"
            ]["one_axis_at_a_time_endpoints"][0]["low"].__setitem__("value", 0.97),
        ),
        (
            "material",
            lambda value: value["evidence_slices"][
                "bounded_discrete_material_walking"
            ]["advertised_material_profiles"][0].__setitem__("authored_friction", 0.13),
        ),
        (
            "morphology_count",
            lambda value: set_path(
                value,
                "evidence_slices.exact_finite_morphology_and_walking.observed.morphology_count",
                13,
            ),
        ),
        (
            "walking",
            lambda value: set_path(
                value,
                "evidence_slices.exact_finite_morphology_and_walking.observed.walking_pass_count",
                35,
            ),
        ),
        (
            "body_write",
            lambda value: set_path(
                value,
                "evidence_slices.exact_finite_morphology_and_walking.observed.direct_body_write_count",
                1,
            ),
        ),
        (
            "material_fail",
            lambda value: set_path(
                value,
                "evidence_slices.bounded_discrete_material_walking.observed.failed_gate_count",
                1,
            ),
        ),
        (
            "turning",
            lambda value: set_path(
                value,
                "evidence_slices.bounded_current_capabilities.basic_turning.godot_jolt_gate_passed",
                False,
            ),
        ),
        (
            "push",
            lambda value: set_path(
                value,
                "evidence_slices.bounded_current_capabilities.native_external_push_interaction_and_recovery.supported",
                True,
            ),
        ),
        (
            "force_aware",
            lambda value: set_path(
                value,
                "claim_boundary.force_aware_continuous_recovery",
                True,
            ),
        ),
        (
            "cartesian",
            lambda value: set_path(
                value,
                "evidence_composition_rule.morphology_by_material_cartesian_product_proven",
                True,
            ),
        ),
        (
            "population",
            lambda value: set_path(
                value,
                "evidence_composition_rule.no_cross_campaign_world_total_is_used_as_a_scientific_population",
                False,
            ),
        ),
        (
            "reinterpret",
            lambda value: set_path(
                value,
                "historical_negative_preservation.historical_results_reclassified",
                True,
            ),
        ),
        (
            "decision",
            lambda value: set_path(value, "evidence_composition_rule.decision", "negative"),
        ),
        (
            "score",
            lambda value: set_path(
                value, "finite_decision_rule.sdk1_score_after", "15/20"
            ),
        ),
        (
            "r13",
            lambda value: set_path(
                value, "finite_decision_rule.q_sdk_r13_satisfied", False
            ),
        ),
        (
            "unsupported",
            lambda value: value["advertised_sdk1_godot_jolt_envelope"][
                "explicitly_unsupported_or_unproved"
            ].pop(),
        ),
        (
            "equivalence",
            lambda value: set_path(
                value, "claim_boundary.formal_cross_engine_equivalence", True
            ),
        ),
        (
            "physical_authority",
            lambda value: set_path(
                value, "claim_boundary.physical_acceptance_authority", True
            ),
        ),
        (
            "release",
            lambda value: set_path(value, "claim_boundary.release_authority", True),
        ),
        (
            "next_physical",
            lambda value: set_path(
                value,
                "next_boundary.physical_execution_authorized_by_this_decision",
                True,
            ),
        ),
    ]
    rejected = 0
    for label, mutate in mutations:
        candidate = copy.deepcopy(decision)
        mutate(candidate)
        try:
            validate_decision_shape(candidate)
        except DecisionAuditError:
            rejected += 1
        else:
            raise DecisionAuditError(f"MUTATION_ACCEPTED:{label}")
    require(rejected == len(mutations), "MUTATION_COUNT")
    return rejected


def validate_live_equal() -> dict[str, Any]:
    status = git("status", "--porcelain=v1")
    require(status == "", "LIVE_WORKTREE_NOT_CLEAN")
    head = git("rev-parse", "HEAD")
    tracking = git("rev-parse", "refs/remotes/origin/main")
    live_line = git("ls-remote", "origin", "refs/heads/main")
    fields = live_line.split()
    require(len(fields) == 2 and fields[1] == "refs/heads/main", "LIVE_REMOTE_SHAPE")
    live = fields[0]
    require(head == tracking == live, "LIVE_REMOTE_NOT_EQUAL")
    return {"head": head, "origin_main": tracking, "live_origin_main": live}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-live-equal", action="store_true")
    arguments = parser.parse_args()

    root = REPO_ROOT.resolve().as_posix()
    require(root.casefold() == EXPECTED_ROOT.casefold(), f"REPOSITORY_ROOT:{root}")
    require(git("remote", "get-url", "origin") == EXPECTED_REMOTE, "REMOTE")
    require(git("rev-parse", f"{DECISION_PARENT}^{{commit}}") == DECISION_PARENT, "PARENT")
    require(git("show", "-s", "--format=%T", DECISION_PARENT) == DECISION_PARENT_TREE, "TREE")
    require(
        git("merge-base", "--is-ancestor", DECISION_PARENT, "HEAD") == "",
        "PARENT_NOT_ANCESTOR",
    )

    decision_length, decision_sha = raw_identity(REPO_ROOT / DECISION_PATH)
    require(decision_length == DECISION_BYTES, "DECISION_BYTES")
    require(decision_sha == DECISION_SHA256, "DECISION_SHA")
    decision = read_repo_json(DECISION_PATH)
    validate_decision_shape(decision)
    validate_pre_adoption_authorities(decision)
    validate_selected_policy(decision)
    validate_c2_c5(decision)
    validate_r05e(decision)
    validate_bw5c(decision)
    validate_capabilities(decision)
    validate_historical_negatives(decision)
    mutation_count = validate_mutation_refusals(decision)
    full, sdk1 = validate_current_adoption()
    live = validate_live_equal() if arguments.require_live_equal else None

    receipt = {
        "schema_version": "sporespore_qsdk_r13_godot_jolt_sdk1_envelope_decision_audit_receipt_v1",
        "gate_id": "QSDK-R13",
        "sdk1_milestone_id": "SDK1-M08",
        "decision_raw_sha256": DECISION_SHA256,
        "decision_byte_length": DECISION_BYTES,
        "evidence_slice_count": 4,
        "mutation_refusal_count": mutation_count,
        "full_program_required_passed": full["gate_counts"]["required_passed"],
        "sdk1_milestones_passed": sdk1["sdk1_counts"]["passed"],
        "sdk1_candidate_blocking_milestone_ids": sdk1[
            "clean_room_candidate_blocking_milestone_ids"
        ],
        "historical_negative_count": 2,
        "historical_result_reclassification_count": 0,
        "model_construction_count": 0,
        "physics_engine_process_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_physics_read_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "live_equal_verified": live is not None,
        "live": live,
    }
    print(PASS_MARKER + json.dumps(receipt, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (DecisionAuditError, OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(FAIL_MARKER + str(exc), file=sys.stderr)
        raise SystemExit(1)
