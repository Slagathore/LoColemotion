"""Fail-closed zero-world audit for the QSDK-R24D1 recovery design.

This module validates declaration and dependency bytes only.  It must never
construct a physics model, step a solver, or imply that QSDK-R24 has passed.
"""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
from typing import Any, Callable


SCHEMA_VERSION = "sporespore_qsdk_r24d1_canonical_prone_to_standing_design_v1"
GATE_ID = "QSDK-R24D1"
WORK_ID = "QSDK-R24D1-CANONICAL-PRONE-TO-STANDING-DESIGN"
RELEASE_GATE_ID = "QSDK-R24"
EXPECTED_ENGINES = ["godot_jolt_4_7", "rapier_parry_native", "mujoco_native"]
EXPECTED_PHASES = [
    "confirm_prone",
    "establish_distal_support",
    "raise_body",
    "stance_handoff",
    "stance_dwell",
    "complete",
]
EXPECTED_GATE_FAMILIES = {
    "entry",
    "exit",
    "contact",
    "clearance",
    "safety",
    "timeout",
    "no_cheat",
}
EXPECTED_OBSERVATION_CHANNELS = [
    "canonical_body_pose_and_twist",
    "whole_system_center_of_mass_position_and_velocity",
    "ordered_joint_position_and_velocity",
    "ordered_foot_bearing_contact_observations",
    "classified_nonfoot_contact_observations",
    "applied_actuation_receipts",
    "external_intervention_ledger",
    "controller_ownership_receipt",
    "energy_balance_ledger",
    "engine_step_identity",
]
EXPECTED_ZERO_COUNTERS = [
    "root_force_application_count",
    "root_torque_application_count",
    "root_impulse_application_count",
    "root_pose_write_count",
    "root_velocity_write_count",
    "pin_or_guide_constraint_count",
    "hidden_body_actuation_count",
    "pose_teleport_count",
    "collision_disable_count",
    "contact_relabel_count",
    "gravity_mutation_count",
    "time_scale_mutation_count",
    "engine_specific_policy_branch_count",
]
EXPECTED_THRESHOLDS = [
    "entry_prone_height_ratio_max",
    "entry_torso_up_dot_max",
    "entry_prone_confirm_steps",
    "entry_initial_state_match_tolerance",
    "distal_bearing_minimum_impulse_ns",
    "minimum_com_height_gain_m",
    "stance_height_ratio_min",
    "stance_torso_up_dot_min",
    "minimum_nonfoot_clearance_m",
    "maximum_forbidden_contact_impulse_ns",
    "maximum_terminal_linear_speed_m_s",
    "maximum_terminal_angular_speed_rad_s",
    "stance_dwell_steps",
    "per_phase_timeout_steps",
    "total_timeout_steps",
    "maximum_energy_balance_residual_j",
]
EXPECTED_NEGATIVE_CONTROLS = [
    "matched_zero_command_same_state",
    "root_force_or_impulse_injection",
    "root_pose_or_velocity_write_injection",
    "pin_guide_or_scaffold_injection",
    "hidden_body_actuation_injection",
    "pose_teleport_injection",
    "contact_relabel_or_collision_disable_injection",
    "phase_skip_or_time_reset_injection",
    "engine_specific_policy_branch_injection",
    "missing_required_observation_capability",
    "valid_out_of_scope_descriptor",
    "mutated_actuator_profile_identity",
]
TOP_LEVEL_FIELDS = {
    "schema_version",
    "gate_id",
    "work_id",
    "release_gate_id",
    "status",
    "question_class",
    "question",
    "physical_question_declared",
    "physical_campaign_opened",
    "ordering_decision",
    "predecessor_qualification",
    "immutable_inputs",
    "initial_support_scope",
    "canonical_task",
    "required_observation_channels",
    "adapter_capability_contract",
    "phase_machine",
    "required_gate_families",
    "no_cheat_exact_zero_counters",
    "threshold_registry",
    "threshold_provenance_and_adequacy",
    "future_physical_questions",
    "cohort_and_population_adequacy",
    "required_negative_controls",
    "complete_zero_world_program",
    "claim_boundary",
    "release_boundary",
}


class AuditFailure(RuntimeError):
    """One exact declaration or dependency invariant failed."""


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise AuditFailure(f"duplicate_json_key:{key}")
        result[key] = value
    return result


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(
            path.read_text(encoding="utf-8"), object_pairs_hook=_reject_duplicate_keys
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"json_read_failed:{path}:{type(exc).__name__}") from exc
    if not isinstance(value, dict):
        raise AuditFailure(f"json_root_not_object:{path}")
    return value


def raw_sha256(path: Path) -> str:
    try:
        return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError as exc:
        raise AuditFailure(f"hash_read_failed:{path}:{type(exc).__name__}") from exc


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def _require_false_map(value: Any, code: str) -> None:
    _require(isinstance(value, dict) and value, f"{code}:not_nonempty_object")
    unexpected = [key for key, item in value.items() if item is not False]
    _require(not unexpected, f"{code}:true_or_nonboolean:{','.join(unexpected)}")


def _dependency_path(repo_root: Path, value: Any, field: str) -> Path:
    _require(isinstance(value, str) and value, f"{field}:invalid")
    candidate = (repo_root / value).resolve()
    try:
        candidate.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise AuditFailure(f"{field}:path_escape") from exc
    _require(candidate.is_file(), f"{field}:missing")
    return candidate


def _verify_bound_file(
    repo_root: Path, binding: dict[str, Any], path_field: str, sha_field: str
) -> Path:
    path = _dependency_path(repo_root, binding.get(path_field), path_field)
    expected = binding.get(sha_field)
    _require(
        isinstance(expected, str)
        and expected.startswith("sha256:")
        and len(expected) == 71,
        f"{sha_field}:invalid",
    )
    _require(raw_sha256(path) == expected, f"{sha_field}:mismatch")
    return path


def _find_release_gate(contract: dict[str, Any], gate_id: str) -> dict[str, Any]:
    gates = contract.get("gates")
    _require(isinstance(gates, list), "release_contract:gates_invalid")
    matches = [gate for gate in gates if isinstance(gate, dict) and gate.get("gate_id") == gate_id]
    _require(len(matches) == 1, "release_contract:q_sdk_r24_missing_or_duplicate")
    return matches[0]


def audit_document(document: dict[str, Any], repo_root: Path) -> dict[str, Any]:
    _require(set(document) == TOP_LEVEL_FIELDS, "top_level_fields_changed")
    _require(document.get("schema_version") == SCHEMA_VERSION, "schema_version_changed")
    _require(document.get("gate_id") == GATE_ID, "gate_id_changed")
    _require(document.get("work_id") == WORK_ID, "work_id_changed")
    _require(document.get("release_gate_id") == RELEASE_GATE_ID, "release_gate_id_changed")
    _require(
        document.get("status")
        == "implemented_zero_world_design_gate_passed_physical_execution_blocked",
        "status_changed",
    )
    _require(
        document.get("question_class") == "non_physical_source_conformance",
        "question_class_changed",
    )
    _require(document.get("physical_question_declared") is False, "physical_question_declared")
    _require(document.get("physical_campaign_opened") is False, "physical_campaign_opened")

    ordering = document.get("ordering_decision")
    _require(isinstance(ordering, dict), "ordering_decision_invalid")
    _require(
        ordering.get("canonical_prone_to_standing_is_current_movement_priority") is True,
        "movement_priority_changed",
    )
    _require(
        ordering.get("additional_turning_campaign_required_first") is False,
        "turning_precondition_reintroduced",
    )
    _require(
        ordering.get("next_permitted_work")
        == "Implement the engine-neutral observation, classifier, phase supervisor, result schemas, adapter capability receipts, and negative controls. No physical world is permitted by R24D1.",
        "next_permitted_work_changed",
    )

    predecessor = document.get("predecessor_qualification")
    _require(isinstance(predecessor, dict), "predecessor_qualification_invalid")
    _require(
        predecessor.get("source_commit") == "a56e4f4b966de733b16d418b814151e895844a8a",
        "predecessor_source_changed",
    )
    _require(predecessor.get("full_cold_stage_count") == 8, "predecessor_stage_count_changed")
    _require(predecessor.get("all_stages_passed") is True, "predecessor_not_passed")
    _require(predecessor.get("result_reused") is False, "predecessor_reused")
    _require(predecessor.get("true_claim_count") == 0, "predecessor_claim_count_changed")
    _require(predecessor.get("physical_world_count") == 0, "predecessor_world_count_changed")
    receipt_path = Path(str(predecessor.get("run_receipt_path", "")))
    _require(receipt_path.is_absolute() and receipt_path.is_file(), "predecessor_receipt_missing")
    _require(
        raw_sha256(receipt_path) == predecessor.get("run_receipt_raw_sha256"),
        "predecessor_receipt_hash_mismatch",
    )
    predecessor_receipt = load_json(receipt_path)
    _require(predecessor_receipt.get("status") == "passed", "predecessor_receipt_not_passed")
    _require(predecessor_receipt.get("tier") == "full_cold", "predecessor_receipt_not_full_cold")
    _require(
        predecessor_receipt.get("source", {}).get("head") == predecessor.get("source_commit"),
        "predecessor_receipt_source_mismatch",
    )
    _require(
        predecessor_receipt.get("source", {}).get("head_tree") == predecessor.get("source_tree"),
        "predecessor_receipt_tree_mismatch",
    )
    _require(
        predecessor_receipt.get("source", {}).get("worktree_clean") is True,
        "predecessor_receipt_dirty",
    )
    _require(
        predecessor_receipt.get("cache", {}).get("result_reused") is False,
        "predecessor_receipt_reused",
    )
    _require(
        len(predecessor_receipt.get("stage_receipts", [])) == 8
        and all(stage.get("status") == "passed" for stage in predecessor_receipt["stage_receipts"]),
        "predecessor_receipt_stage_failure",
    )
    _require_false_map(predecessor_receipt.get("claims"), "predecessor_receipt_claims")
    _require(
        predecessor_receipt.get("full_log", {}).get("raw_sha256")
        == predecessor.get("full_log_raw_sha256"),
        "predecessor_log_hash_mismatch",
    )

    immutable = document.get("immutable_inputs")
    _require(isinstance(immutable, dict) and set(immutable) == {"selected_actuator_profile", "br13_bounded_get_up"}, "immutable_inputs_changed")
    selected = immutable["selected_actuator_profile"]
    profile_path = _verify_bound_file(repo_root, selected, "path", "raw_sha256")
    profile = load_json(profile_path)
    for key in ("profile_id", "profile_sha256", "morphology_id", "descriptor_sha256", "morphology_spec_sha256"):
        _require(
            selected.get(key) == profile.get("publication", {}).get(key),
            f"selected_profile:{key}_mismatch",
        )
    _require(selected.get("physical_result_imported") is False, "selected_profile_physics_imported")

    br13 = immutable["br13_bounded_get_up"]
    _verify_bound_file(repo_root, br13, "decision_path", "decision_raw_sha256")
    _verify_bound_file(repo_root, br13, "decision_review_path", "decision_review_raw_sha256")
    _verify_bound_file(repo_root, br13, "adr_path", "adr_raw_sha256")
    _require(br13.get("accepted_claim") == "constrained_planar_get_up", "br13_claim_changed")
    _require(br13.get("engine") == "godot_jolt", "br13_engine_changed")
    _require(br13.get("fixture") == "symmetry_collapsed_sagittal_guide", "br13_fixture_changed")
    _require(br13.get("numeric_threshold_authority") is False, "br13_threshold_promoted")
    _require(br13.get("cohort_authority") is False, "br13_cohort_promoted")
    _require(br13.get("portable_physical_authority") is False, "br13_physics_promoted")
    _require("br13_numeric_thresholds" in br13.get("forbidden_promotions", []), "br13_threshold_prohibition_missing")
    _require("br13_godot_jolt_physical_result" in br13.get("forbidden_promotions", []), "br13_result_prohibition_missing")

    support = document.get("initial_support_scope")
    _require(isinstance(support, dict), "support_scope_invalid")
    _require(
        support.get("support_status") == "design_candidate_not_yet_implemented_or_physically_supported",
        "support_status_overclaimed",
    )
    _require(support.get("scope_kind") == "exact_morphology_only", "scope_kind_changed")
    _require(support.get("required_native_engines") == EXPECTED_ENGINES, "engine_set_changed")
    _require(support.get("mujoco_warp_is_native_validation_engine") is False, "warp_promoted_to_native")
    _require(support.get("arbitrary_valid_quadruped_support") is False, "arbitrary_support_claimed")
    _require(support.get("continuous_morphology_claim") is False, "continuous_morphology_claimed")

    task = document.get("canonical_task")
    _require(isinstance(task, dict), "canonical_task_invalid")
    _require(task.get("entry_pose_id") == "ventral_contact_prone_v1", "entry_pose_changed")
    _require(task.get("terminal_pose_id") == "stable_four_foot_stance_v1", "terminal_pose_changed")
    for key in (
        "ordinary_unilateral_ground_contacts_required",
        "intermediate_ventral_contact_permitted",
        "terminal_stance_controller_active",
    ):
        _require(task.get(key) is True, f"canonical_task:{key}_disabled")
    for key in (
        "terminal_nonfoot_contact_permitted",
        "terminal_recovery_controller_active",
        "root_or_world_assistance_permitted",
        "engine_specific_policy_branching_permitted",
        "implicit_fallback_permitted",
    ):
        _require(task.get(key) is False, f"canonical_task:{key}_enabled")

    _require(document.get("required_observation_channels") == EXPECTED_OBSERVATION_CHANNELS, "observation_channels_changed")
    capability = document.get("adapter_capability_contract")
    _require(isinstance(capability, dict), "adapter_capability_contract_invalid")
    _require(capability.get("all_required_channels_must_be_explicitly_supported") is True, "implicit_capability_allowed")
    for key in (
        "adapter_may_synthesize_missing_physical_observation",
        "adapter_may_infer_success_from_host_pose_label",
        "adapter_may_apply_fallback_control",
    ):
        _require(capability.get(key) is False, f"adapter_capability:{key}_enabled")

    phase = document.get("phase_machine")
    _require(isinstance(phase, dict), "phase_machine_invalid")
    _require(phase.get("ordered_success_path") == EXPECTED_PHASES, "phase_order_changed")
    _require(phase.get("terminal_failure_states") == ["failed", "refused"], "failure_states_changed")
    _require(phase.get("advancement_source") == "post_step_canonical_observation_only", "phase_observation_source_changed")
    for key in (
        "phase_skip_permitted",
        "phase_reorder_permitted",
        "controller_overlap_during_handoff_permitted",
        "success_latched_before_stance_dwell_permitted",
    ):
        _require(phase.get(key) is False, f"phase_machine:{key}_enabled")

    gates = document.get("required_gate_families")
    _require(isinstance(gates, dict) and set(gates) == EXPECTED_GATE_FAMILIES, "gate_families_changed")
    _require(all(isinstance(items, list) and items for items in gates.values()), "empty_gate_family")
    _require(document.get("no_cheat_exact_zero_counters") == EXPECTED_ZERO_COUNTERS, "zero_counter_set_changed")

    thresholds = document.get("threshold_registry")
    _require(isinstance(thresholds, list) and len(thresholds) == len(EXPECTED_THRESHOLDS), "threshold_registry_count_changed")
    _require([entry.get("threshold_id") for entry in thresholds if isinstance(entry, dict)] == EXPECTED_THRESHOLDS, "threshold_order_or_identity_changed")
    for entry in thresholds:
        _require(isinstance(entry, dict) and set(entry) == {"threshold_id", "unit", "value"}, "threshold_fields_changed")
        _require(isinstance(entry.get("unit"), str) and entry["unit"], "threshold_unit_missing")
        _require(entry.get("value") is None, f"threshold_value_set:{entry.get('threshold_id')}")
    threshold_boundary = document.get("threshold_provenance_and_adequacy")
    _require(isinstance(threshold_boundary, dict), "threshold_boundary_invalid")
    _require(threshold_boundary.get("status") == "unset_blocking_physical_execution", "threshold_status_changed")
    _require(threshold_boundary.get("registered_threshold_count") == 16, "threshold_count_changed")
    _require(threshold_boundary.get("set_threshold_count") == 0, "set_threshold_count_changed")
    for key in (
        "every_threshold_requires_explicit_provenance",
        "every_threshold_requires_adequacy_argument",
        "threshold_selection_must_precede_held_out_observation",
    ):
        _require(threshold_boundary.get(key) is True, f"threshold_boundary:{key}_disabled")
    for key in (
        "br13_numeric_values_are_authoritative",
        "historical_turning_values_are_authoritative",
        "post_outcome_rethresholding_permitted",
        "physical_execution_permitted_with_unset_threshold",
    ):
        _require(threshold_boundary.get(key) is False, f"threshold_boundary:{key}_enabled")

    questions = document.get("future_physical_questions")
    _require(isinstance(questions, dict) and set(questions) == {"initial_policy_development", "held_out_native_validation"}, "future_question_set_changed")
    development = questions["initial_policy_development"]
    validation = questions["held_out_native_validation"]
    _require(development.get("question_class") == "development", "development_question_class_changed")
    _require(development.get("status") == "not_opened", "development_question_opened")
    _require(development.get("engine_assignment") is None, "development_engine_selected")
    _require(development.get("seed_cohort") == [] and development.get("initial_state_cohort") == [], "development_cohort_selected")
    _require(development.get("physical_world_count") == 0, "development_world_opened")
    _require(validation.get("question_class") == "finite_decision", "validation_question_class_changed")
    _require(validation.get("status") == "not_opened", "validation_question_opened")
    _require(validation.get("required_engines") == EXPECTED_ENGINES, "validation_engine_set_changed")
    _require(validation.get("seed_cohort") == [] and validation.get("initial_state_cohort") == [], "validation_cohort_selected")
    _require(validation.get("development_seed_reuse_permitted") is False, "validation_seed_reuse_allowed")
    _require(validation.get("development_initial_state_reuse_permitted") is False, "validation_state_reuse_allowed")
    _require(validation.get("physical_world_count") == 0, "validation_world_opened")
    _require(validation.get("cross_engine_equivalence_claim") is False, "validation_equivalence_claimed")

    cohort = document.get("cohort_and_population_adequacy")
    _require(isinstance(cohort, dict), "cohort_boundary_invalid")
    _require(cohort.get("status") == "undeclared_blocking_physical_execution", "cohort_status_changed")
    _require(cohort.get("matched_zero_command_control_declared") is True, "matched_control_removed")
    for key in (
        "development_cohort_declared",
        "held_out_validation_cohort_declared",
        "population_claim",
        "repeatability_rate_claim",
        "cross_engine_equivalence_or_non_inferiority_claim",
    ):
        _require(cohort.get(key) is False, f"cohort_boundary:{key}_enabled")
    _require(cohort.get("cohort_provenance_required") is True, "cohort_provenance_not_required")
    _require(cohort.get("cohort_adequacy_argument_required") is True, "cohort_adequacy_not_required")

    _require(document.get("required_negative_controls") == EXPECTED_NEGATIVE_CONTROLS, "negative_controls_changed")

    zero_world = document.get("complete_zero_world_program")
    _require(isinstance(zero_world, dict), "zero_world_program_invalid")
    _require(
        zero_world.get("design_declaration_gate_passed") is True,
        "zero_world_program:design_declaration_gate_not_passed",
    )
    for key, value in zero_world.items():
        if key == "design_declaration_gate_passed":
            continue
        if key.endswith("_count"):
            _require(value == 0, f"zero_world_program:{key}_nonzero")
        else:
            _require(value is False, f"zero_world_program:{key}_prematurely_true")

    claims = document.get("claim_boundary")
    _require(isinstance(claims, dict), "claim_boundary_invalid")
    _require(claims.get("design_surface_declared") is True, "design_surface_not_declared")
    for key, value in claims.items():
        if key != "design_surface_declared":
            _require(value is False, f"claim_boundary:{key}_prematurely_true")

    release = document.get("release_boundary")
    _require(isinstance(release, dict), "release_boundary_invalid")
    _require(release.get("passed_gate_count") == 10, "release_passed_count_changed")
    _require(release.get("total_gate_count") == 25, "release_total_count_changed")
    _require(release.get("release_ready") is False, "release_ready_claimed")
    _require(release.get("q_sdk_r24_satisfied") is False, "q_sdk_r24_claimed")

    release_contract_path = repo_root / "sdk" / "release" / "quadruped_release_contract.json"
    release_contract = load_json(release_contract_path)
    r24_gate = _find_release_gate(release_contract, RELEASE_GATE_ID)
    _require(r24_gate.get("category") == "prone_to_standing", "release_contract:q_sdk_r24_category_changed")
    _require(r24_gate.get("required_for_release") is True, "release_contract:q_sdk_r24_not_required")
    _require(
        r24_gate.get("requirement")
        == "The portable SDK passes a canonical prone-to-standing contract with frozen entry, exit, contact, clearance, safety, timeout, and no-cheat gates on every advertised engine.",
        "release_contract:q_sdk_r24_requirement_changed",
    )
    _require(r24_gate.get("proof", {}).get("kind") == "missing", "release_contract:q_sdk_r24_prematurely_passed")

    return {
        "schema_version": "sporespore_qsdk_r24d1_design_audit_receipt_v1",
        "ok": True,
        "gate_id": GATE_ID,
        "question_class": "non_physical_source_conformance",
        "engine_count": len(EXPECTED_ENGINES),
        "gate_family_count": len(EXPECTED_GATE_FAMILIES),
        "observation_channel_count": len(EXPECTED_OBSERVATION_CHANNELS),
        "phase_count": len(EXPECTED_PHASES),
        "threshold_count": len(EXPECTED_THRESHOLDS),
        "set_threshold_count": 0,
        "negative_control_count": len(EXPECTED_NEGATIVE_CONTROLS),
        "future_physical_question_count": 2,
        "design_declaration_gate_passed": True,
        "complete_prephysical_gate_passed": False,
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


def _set(path: tuple[Any, ...], value: Any) -> Callable[[dict[str, Any]], None]:
    def mutate(document: dict[str, Any]) -> None:
        target: Any = document
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = value

    return mutate


def mutation_cases() -> list[tuple[str, Callable[[dict[str, Any]], None]]]:
    return [
        ("schema", _set(("schema_version",), "wrong")),
        ("gate", _set(("gate_id",), "QSDK-R24")),
        ("release_gate", _set(("release_gate_id",), "QSDK-R25")),
        ("status", _set(("status",), "passed")),
        ("question_class", _set(("question_class",), "finite_decision")),
        ("campaign_open", _set(("physical_campaign_opened",), True)),
        ("turning_precondition", _set(("ordering_decision", "additional_turning_campaign_required_first"), True)),
        ("predecessor_pass", _set(("predecessor_qualification", "all_stages_passed"), False)),
        ("predecessor_reuse", _set(("predecessor_qualification", "result_reused"), True)),
        ("predecessor_claim", _set(("predecessor_qualification", "true_claim_count"), 1)),
        ("profile_hash", _set(("immutable_inputs", "selected_actuator_profile", "profile_sha256"), "sha256:" + "0" * 64)),
        ("br13_claim", _set(("immutable_inputs", "br13_bounded_get_up", "accepted_claim"), "free_3d_recovery")),
        ("br13_threshold", _set(("immutable_inputs", "br13_bounded_get_up", "numeric_threshold_authority"), True)),
        ("arbitrary_support", _set(("initial_support_scope", "arbitrary_valid_quadruped_support"), True)),
        ("engine_removed", lambda value: value["initial_support_scope"]["required_native_engines"].pop()),
        ("warp_native", _set(("initial_support_scope", "mujoco_warp_is_native_validation_engine"), True)),
        ("root_assistance", _set(("canonical_task", "root_or_world_assistance_permitted"), True)),
        ("engine_branch", _set(("canonical_task", "engine_specific_policy_branching_permitted"), True)),
        ("observation_removed", lambda value: value["required_observation_channels"].pop()),
        ("adapter_synthesis", _set(("adapter_capability_contract", "adapter_may_synthesize_missing_physical_observation"), True)),
        ("phase_swap", lambda value: value["phase_machine"]["ordered_success_path"].reverse()),
        ("phase_source", _set(("phase_machine", "advancement_source"), "controller_prediction")),
        ("gate_missing", lambda value: value["required_gate_families"].pop("no_cheat")),
        ("counter_missing", lambda value: value["no_cheat_exact_zero_counters"].pop()),
        ("threshold_set", _set(("threshold_registry", 0, "value"), 0.35)),
        ("set_threshold_count", _set(("threshold_provenance_and_adequacy", "set_threshold_count"), 1)),
        ("unset_execution", _set(("threshold_provenance_and_adequacy", "physical_execution_permitted_with_unset_threshold"), True)),
        ("development_open", _set(("future_physical_questions", "initial_policy_development", "status"), "open")),
        ("development_seed", lambda value: value["future_physical_questions"]["initial_policy_development"]["seed_cohort"].append(1)),
        ("validation_seed", lambda value: value["future_physical_questions"]["held_out_native_validation"]["seed_cohort"].append(2)),
        ("validation_class", _set(("future_physical_questions", "held_out_native_validation", "question_class"), "equivalence_non_inferiority")),
        ("population_claim", _set(("cohort_and_population_adequacy", "population_claim"), True)),
        ("negative_removed", lambda value: value["required_negative_controls"].pop()),
        ("design_gate_false", _set(("complete_zero_world_program", "design_declaration_gate_passed"), False)),
        ("prephysical_pass", _set(("complete_zero_world_program", "complete_prephysical_gate_passed"), True)),
        ("world_open", _set(("complete_zero_world_program", "world_build_count"), 1)),
        ("prone_claim", _set(("claim_boundary", "canonical_prone_to_standing"), True)),
        ("release_ready", _set(("release_boundary", "release_ready"), True)),
    ]


def run_mutation_suite(document: dict[str, Any], repo_root: Path) -> int:
    rejected = 0
    for label, mutate in mutation_cases():
        candidate = copy.deepcopy(document)
        mutate(candidate)
        try:
            audit_document(candidate, repo_root)
        except AuditFailure:
            rejected += 1
        else:
            raise AuditFailure(f"mutation_accepted:{label}")
    return rejected


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    declaration_path = Path(__file__).with_name(
        "r24d1_canonical_prone_to_standing_design_v1.json"
    )
    try:
        document = load_json(declaration_path)
        report = audit_document(document, repo_root)
        report["declaration_path"] = declaration_path.relative_to(repo_root).as_posix()
        report["declaration_raw_sha256"] = raw_sha256(declaration_path)
        report["mutation_rejection_count"] = run_mutation_suite(document, repo_root)
        print("QSDK_R24D1_DESIGN_AUDIT " + json.dumps(report, sort_keys=True, separators=(",", ":")))
        return 0
    except AuditFailure as exc:
        print(f"QSDK_R24D1_DESIGN_AUDIT_FAIL {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
