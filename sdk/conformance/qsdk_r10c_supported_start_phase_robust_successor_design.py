#!/usr/bin/env python3
"""Audit the QSDK-R10C retained-evidence diagnosis without opening a world."""

from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
import subprocess
from typing import Any

import qsdk_r10b_held_out_finite_decision_physical_closure as r10b


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
SOURCE_COMMIT = "279f201e21b84356c32c281baad947dea0f8a1f2"
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10c_supported_start_phase_robust_successor_design_v1.json"
)
EXPECTED_DESIGN_BYTES = 40599
EXPECTED_DESIGN_SHA256 = (
    "sha256:2f2a4f86562e3398d69fc08510c347ed1634a2331f45ce58651db7bbb8aae4a8"
)
R05E_REPORT_PATH = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r05e-exact-finite-morphology-physical-20260903T200811432Z-3228ad65"
    r"\report.json"
)
R05E_REPORT_BYTES = 890_301
R05E_REPORT_SHA256 = (
    "sha256:0fb1d495d079beeda1412c8f3c0af5127dc0646429debf80cf0d20e0d3cd1ab6"
)
PASS_MARKER = "QSDK_R10C_SUPPORTED_START_PHASE_ROBUST_SUCCESSOR_DESIGN_PASS "
EXPECTED_LIMBS = ("front_left", "front_right", "rear_left", "rear_right")
EXPECTED_ROLES = {
    "consumed_r10b_held_out_finite_negative_closure",
    "consumed_r10b_held_out_finite_negative_closure_audit",
    "prior_r05e_exact_finite_supported_morphology_closure",
    "r05e_exact_finite_descriptor_source",
    "r10a_original_successor_design",
    "r10b_consumed_trace_and_evaluator_source",
    "r05e_development_seed_classification",
    "selected_portable_policy",
    "live_release_contract",
    "sdk1_milestone_mapping",
    "r05e_prior_supported_population_report",
}
EXPECTED_TOP_LEVEL = {
    "schema_version",
    "gate_id",
    "design_id",
    "closed_local_date",
    "status",
    "ledger_scope",
    "question_declaration",
    "authored_parent_commit",
    "diagnostic_question",
    "release_milestone_context",
    "bound_authorities",
    "consumed_predecessor_result",
    "causal_diagnosis",
    "supported_start_selection",
    "retained_r10b_trace_diagnosis",
    "selected_successor_scope",
    "prospective_population",
    "prospective_challenge_profile",
    "prospective_trace_and_recovery_measurement_contract",
    "decision_contract",
    "required_zero_world_implementation_controls",
    "forward_authority_sequence",
    "immutability_and_limits",
    "claim_boundary",
    "decision",
}
EXPECTED_DESCRIPTOR = {
    "schema_version": "sporespore_physical_quadruped_proportion_spec_v1",
    "morphology_id": "qsdk_r05e_axis_star_torso_length_low_s217",
    "torso_length_scale": 0.975,
    "torso_width_scale": 1.0,
    "upper_length_fraction": 0.5142857142857142,
    "hip_span_scale": 1.0,
    "foot_radius_scale": 1.0,
    "front_limb_mass_scale": 1.0,
}
R05E_RESULT_SPECS = {
    40101: {
        "sdk_step_count": 2655,
        "maximum_anchor_error_m": 0.017417307943105698,
        "maximum_tilt_rad": 0.10733848004530039,
        "minimum_torso_height_m": 0.42786696553230286,
        "evidence_task_frame_forward_displacement_m": 0.9566579461097717,
        "final_task_frame_forward_displacement_m": 1.1054338216781616,
    },
    40102: {
        "sdk_step_count": 2826,
        "maximum_anchor_error_m": 0.018217405304312706,
        "maximum_tilt_rad": 0.12718664063875323,
        "minimum_torso_height_m": 0.429505318403244,
        "evidence_task_frame_forward_displacement_m": 0.8869139552116394,
        "final_task_frame_forward_displacement_m": 1.0098134279251099,
    },
    40103: {
        "sdk_step_count": 2703,
        "maximum_anchor_error_m": 0.018256276845932007,
        "maximum_tilt_rad": 0.09253041115573826,
        "minimum_torso_height_m": 0.42880770564079285,
        "evidence_task_frame_forward_displacement_m": 0.9272481203079224,
        "final_task_frame_forward_displacement_m": 1.0449362993240356,
    },
}
PREFIX_SHA256 = {
    50301: "sha256:00263f6fe1e9ac259cfd0aaddc992042e41db263c03847470bd8fbbd6887ac30",
    50302: "sha256:cb05c66ba7344a55960880e13ee5eeca6c39b27e8a2eb4d6a38f97f02363524e",
    50303: "sha256:d73bbeabfe981aefa89914552c440ff4c020cab875013c9deae124d01ac52c4c",
}
ONE_CYCLE_FIRST_VALID = {
    50301: (195, 555, 0.17516215723302117),
    50302: (364, 724, 0.20473522687423087),
    50303: (200, 560, 0.14047835615694956),
}
TWO_CYCLE_SPECS = {
    50301: {
        "pre_advance": 0.3172908443008378,
        "pre_recontacts": {
            "front_left": 554,
            "front_right": 455,
            "rear_left": 376,
            "rear_right": 256,
        },
        "post_advance": 0.4206261006473522,
        "post_recontacts": {
            "front_left": 997,
            "front_right": 1275,
            "rear_left": 1219,
            "rear_right": 1072,
        },
    },
    50302: {
        "pre_advance": 0.39591369394043563,
        "pre_recontacts": {
            "front_left": 561,
            "front_right": 723,
            "rear_left": 373,
            "rear_right": 255,
        },
        "post_advance": 0.3953313519069778,
        "post_recontacts": {
            "front_left": 1009,
            "front_right": 1195,
            "rear_left": 1253,
            "rear_right": 956,
        },
    },
    50303: {
        "pre_advance": 0.2866612539260309,
        "pre_recontacts": {
            "front_left": 559,
            "front_right": 352,
            "rear_left": 435,
            "rear_right": 251,
        },
        "post_advance": 0.510337226133057,
        "post_recontacts": {
            "front_left": 993,
            "front_right": 1201,
            "rear_left": 1251,
            "rear_right": 1060,
        },
    },
}


class AuditFailure(RuntimeError):
    """Raised when the design or one of its immutable inputs drifts."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def git_blob_oid(raw: bytes) -> str:
    header = f"blob {len(raw)}\0".encode("ascii")
    return hashlib.sha1(header + raw).hexdigest()  # noqa: S324 - Git object identity


def git(args: tuple[str, ...], *, binary: bool = False) -> bytes | str:
    completed = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=not binary,
    )
    require(completed.returncode == 0, f"GIT_FAILED:{' '.join(args)}")
    if binary:
        require(isinstance(completed.stdout, bytes), "GIT_BINARY_TYPE")
        return completed.stdout
    require(isinstance(completed.stdout, str), "GIT_TEXT_TYPE")
    return completed.stdout.strip()


def read_json(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"{label}_JSON_INVALID:{exc}") from exc
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    return value


def exact_equal(actual: Any, expected: Any) -> bool:
    if type(actual) is not type(expected):
        return False
    if isinstance(actual, dict):
        return set(actual) == set(expected) and all(
            exact_equal(actual[key], expected[key]) for key in actual
        )
    if isinstance(actual, list):
        return len(actual) == len(expected) and all(
            exact_equal(left, right) for left, right in zip(actual, expected)
        )
    return bool(actual == expected)


def dotted(value: Any, path: str) -> Any:
    current = value
    for part in path.split("."):
        require(isinstance(current, dict) and part in current, f"DOTTED_MISSING:{path}")
        current = current[part]
    return current


def authority_projection(role: str, loaded: dict[str, Any]) -> dict[str, Any]:
    if role == "live_release_contract":
        gates = loaded.get("gates")
        require(isinstance(gates, list), "RELEASE_GATES_MISSING")
        matches = [
            gate
            for gate in gates
            if isinstance(gate, dict) and gate.get("gate_id") == "QSDK-R10"
        ]
        require(len(matches) == 1, "RELEASE_QSDK_R10_COUNT")
        return matches[0]
    if role == "sdk1_milestone_mapping":
        contract = loaded.get("sdk1_contract")
        require(isinstance(contract, dict), "SDK1_CONTRACT_MISSING")
        milestones = contract.get("milestones")
        require(isinstance(milestones, list), "SDK1_MILESTONES_MISSING")
        matches = [
            item
            for item in milestones
            if isinstance(item, dict) and item.get("milestone_id") == "SDK1-M07"
        ]
        require(len(matches) == 1, "SDK1_M07_COUNT")
        return matches[0]
    return loaded


def validate_repository() -> None:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "WRONG_SCRIPT_ROOT")
    require(
        Path(str(git(("rev-parse", "--show-toplevel")))).resolve()
        == EXPECTED_ROOT.resolve(),
        "WRONG_GIT_ROOT",
    )
    require(git(("remote", "get-url", "origin")) == EXPECTED_REMOTE, "WRONG_REMOTE")
    require(
        git(("rev-parse", SOURCE_COMMIT)) == SOURCE_COMMIT,
        "SOURCE_COMMIT_UNRESOLVED",
    )


def validate_design_identity() -> dict[str, Any]:
    raw = DESIGN_PATH.read_bytes()
    require(len(raw) == EXPECTED_DESIGN_BYTES, "DESIGN_BYTE_LENGTH")
    require(sha256_bytes(raw) == EXPECTED_DESIGN_SHA256, "DESIGN_RAW_SHA256")
    return read_json(raw, "DESIGN")


def validate_bindings(design: dict[str, Any]) -> dict[str, dict[str, Any]]:
    entries = design.get("bound_authorities")
    require(isinstance(entries, list), "BOUND_AUTHORITIES_NOT_ARRAY")
    roles = [entry.get("role") for entry in entries if isinstance(entry, dict)]
    require(len(roles) == len(entries), "BOUND_AUTHORITY_ENTRY_INVALID")
    require(set(roles) == EXPECTED_ROLES, "BOUND_AUTHORITY_ROLE_SET")
    require(len(roles) == len(set(roles)), "BOUND_AUTHORITY_ROLE_DUPLICATE")
    loaded: dict[str, dict[str, Any]] = {}
    for entry in entries:
        role = str(entry["role"])
        path_text = entry.get("path")
        require(isinstance(path_text, str) and path_text, f"{role}:PATH")
        if entry.get("path_kind") == "absolute_durable_evidence":
            path = Path(path_text)
            require(
                path.resolve() == R05E_REPORT_PATH.resolve(), f"{role}:ABSOLUTE_PATH"
            )
            raw = path.read_bytes()
            require("source_commit" not in entry, f"{role}:EXTERNAL_SOURCE_COMMIT")
            require("git_blob_oid" not in entry, f"{role}:EXTERNAL_BLOB")
        else:
            require(
                entry.get("source_commit") == SOURCE_COMMIT, f"{role}:SOURCE_COMMIT"
            )
            path = ROOT / path_text
            raw = path.read_bytes()
            committed_raw = git(("show", f"{SOURCE_COMMIT}:{path_text}"), binary=True)
            require(raw == committed_raw, f"{role}:WORKTREE_DRIFT")
            require(
                entry.get("git_blob_oid") == git_blob_oid(raw),
                f"{role}:GIT_BLOB_OID",
            )
        require(entry.get("byte_length") == len(raw), f"{role}:BYTE_LENGTH")
        require(entry.get("raw_sha256") == sha256_bytes(raw), f"{role}:RAW_SHA256")
        if path.suffix.lower() == ".json":
            value = read_json(raw, role)
            loaded[role] = value
            selected = authority_projection(role, value)
            expected_paths = entry.get("expected_paths", {})
            require(isinstance(expected_paths, dict), f"{role}:EXPECTED_PATHS")
            for expected_path, expected_value in expected_paths.items():
                require(
                    exact_equal(dotted(selected, expected_path), expected_value),
                    f"{role}:EXPECTED:{expected_path}",
                )
    return loaded


def validate_static_contract(design: dict[str, Any]) -> None:
    require(set(design) == EXPECTED_TOP_LEVEL, "TOP_LEVEL_KEY_SET")
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10c_supported_start_phase_robust_successor_design_v1"
        and design.get("gate_id") == "QSDK-R10C"
        and design.get("design_id") == "QSDK-R10C-D1"
        and design.get("closed_local_date") == "2026-09-04"
        and design.get("status")
        == "closed_zero_world_retained_evidence_diagnosis_supported_start_phase_robust_successor_selected_implementation_required_physics_blocked"
        and design.get("authored_parent_commit") == SOURCE_COMMIT,
        "DESIGN_IDENTITY",
    )
    ledger = design["ledger_scope"]
    require(
        ledger
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "closed_zero_world_retained_evidence_diagnosis_and_prospective_successor_design",
            "question_class": "development",
        },
        "LEDGER_SCOPE",
    )
    question = design["question_declaration"]
    for key in (
        "physical_question_declared",
        "finite_decision_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
        "physical_work_authorized",
    ):
        require(question.get(key) is False, f"QUESTION_FALSE:{key}")
    require(
        question.get("maximum_world_attempt_count_before_complete_new_authority_graph")
        == 0
        and question.get(
            "maximum_world_build_count_before_complete_new_authority_graph"
        )
        == 0,
        "QUESTION_ZERO_WORLD_LIMIT",
    )
    release = design["release_milestone_context"]
    require(
        release.get("sdk1_milestone_id") == "SDK1-M07"
        and release.get("full_program_gate_id") == "QSDK-R10"
        and release.get("current_sdk1_completed_steps") == 13
        and release.get("current_sdk1_total_steps") == 20
        and release.get("current_full_program_completed_steps") == 13
        and release.get("current_full_program_total_steps") == 25
        and release.get("milestone_advanced_by_this_design") is False,
        "RELEASE_CONTEXT",
    )
    predecessor = design["consumed_predecessor_result"]
    require(
        predecessor.get("gate_id") == "QSDK-R10B"
        and predecessor.get("closure_id") == "QSDK-R10B-H1"
        and predecessor.get("classification") == "valid_complete_exact_finite_negative"
        and predecessor.get("world_count") == 6
        and predecessor.get("pair_count") == 3
        and predecessor.get("ordinary_walking_pass_count") == 0
        and predecessor.get("pre_push_window_pass_count") == 0
        and predecessor.get("native_push_application_count") == 3
        and predecessor.get("native_effect_confirmed_pair_count") == 3
        and predecessor.get("post_push_recovery_window_found_count") == 3
        and predecessor.get("baseline_post_marker_window_pass_count") == 3
        and predecessor.get("same_identity_rerun_permitted") is False
        and predecessor.get("historical_threshold_change_permitted") is False
        and predecessor.get("historical_result_reclassification_permitted") is False
        and predecessor.get("bounded_upright_push_recovery_established") is False,
        "CONSUMED_PREDECESSOR",
    )
    diagnosis = design["causal_diagnosis"]
    defects = diagnosis.get("defects")
    require(
        diagnosis.get("classification")
        == "two_independent_precondition_design_defects_before_the_native_push_measurement"
        and isinstance(defects, list)
        and [item.get("defect_id") for item in defects]
        == [
            "unsupported_start_selection",
            "phase_sensitive_single_cycle_eligibility_window",
        ]
        and all(item.get("native_push_caused_this_defect") is False for item in defects)
        and all(
            item.get("post_push_recovery_measurement_failed") is False
            for item in defects
        )
        and diagnosis.get("single_cause_claimed") is False
        and diagnosis.get("r10b_native_push_or_recovery_failure_claimed") is False
        and diagnosis.get("r10b_result_remains_negative") is True
        and diagnosis.get("successor_can_reclassify_r10b") is False,
        "CAUSAL_DIAGNOSIS",
    )
    selection = design["supported_start_selection"]
    eligible = selection.get("eligible_generator_indices_in_frozen_order")
    require(
        eligible == list(range(217, 229))
        and selection.get("selection_rule")
        == "choose_the_lowest_generator_index_in_the_frozen_r05e_official_order"
        and selection.get("selected_generator_index") == min(eligible)
        and selection.get("selected_morphology_id")
        == "qsdk_r05e_axis_star_torso_length_low_s217"
        and exact_equal(selection.get("exact_proportion_spec"), EXPECTED_DESCRIPTOR),
        "SUPPORTED_START_SELECTION",
    )
    for key in (
        "selection_uses_walking_margin_ranking",
        "selection_uses_push_or_recovery_outcome",
        "selection_uses_post_hoc_best_seed",
        "selection_is_claimed_optimal",
        "r05e_physical_identity_rerun_selected",
        "r05e_result_changed_or_reinterpreted",
    ):
        require(selection.get(key) is False, f"SELECTION_FALSE:{key}")
    require(
        selection.get("generator_receipt_sha256")
        == "sha256:776dc3efb497917a79391de6d895e4984d8c35fe9ae29b3470552e2ee3a087d9"
        and selection.get("proportion_spec_sha256")
        == "sha256:2ad58378a1e3c6e8e9b16a9862141c4f390f2947f01b1108cd66a594a0f75d0c"
        and selection.get("fixture_spec_sha256")
        == "sha256:9b54fda516c11d451f319fb9ea116896de049aa53b43676de8745ca5f29d670a"
        and selection.get("controller_profile_sha256")
        == "sha256:e4fb8bc38d6892ec5d7a4b5eb01007ab7bdb405c69ddfccac1684889dadfba2b",
        "SUPPORTED_START_HASHES",
    )
    trace = design["retained_r10b_trace_diagnosis"]
    require(
        trace.get("retained_file_count") == 37
        and trace.get("retained_total_byte_length") == 121_645_064
        and trace.get("retained_tree_manifest_sha256")
        == "sha256:5fb5b1f1ab1b68baea8a9c4f25dd8a95cdbf8e8bde11ce2892e0de605a5ec850"
        and trace.get("retained_trace_row_count") == 16_315
        and trace.get("analysis_role") == "outcome_exposed_development_diagnostic_only",
        "TRACE_DIAGNOSIS_IDENTITY",
    )
    prefix = trace["pre_marker_pair_identity"]
    require(
        prefix.get("half_open_semantic_step_interval") == [0, 540]
        and prefix.get("excluded_field") == "cell_id"
        and prefix.get("all_other_trace_fields_exactly_equal_within_each_seed_pair")
        is True
        and prefix.get("first_expected_difference_semantic_step") == 540,
        "PREFIX_CONTRACT",
    )
    frozen = trace["frozen_one_cycle_pre_window"]
    require(
        frozen.get("half_open_semantic_step_interval") == [180, 540]
        and frozen.get("duration_steps") == 360
        and frozen.get("minimum_forward_advance_m") == 0.01
        and frozen.get("safe_envelope_pass_count") == 3
        and frozen.get("forward_advance_pass_count") == 3
        and frozen.get("command_application_pass_count") == 3
        and frozen.get("complete_contact_cycle_pass_count") == 0,
        "FROZEN_ONE_CYCLE",
    )
    sliding = trace["one_cycle_sliding_window_diagnostic"]
    require(
        sliding.get("candidate_start_range_inclusive") == [180, 540]
        and sliding.get("duration_steps") == 360
        and sliding.get("minimum_forward_advance_m") == 0.01
        and sliding.get("valid_window_ending_at_or_before_frozen_marker_count") == 0,
        "SLIDING_WINDOW_CONTRACT",
    )
    two = trace["two_cycle_prospective_structure_diagnostic"]
    require(
        two.get("prospective_marker_step") == 900
        and two.get("marker_shift_steps") == 360
        and two.get("marker_shift_nominal_gq15_cycles") == 1
        and two.get("pre_window_half_open_semantic_step_interval") == [180, 900]
        and two.get("baseline_post_marker_half_open_semantic_step_interval")
        == [901, 1621]
        and two.get("duration_steps") == 720
        and two.get("minimum_forward_advance_m") == 0.02
        and two.get("forward_floor_doubled_with_duration") is True
        and two.get("safe_envelope_or_command_requirement_relaxed") is False
        and two.get("contact_requirement_relaxed") is False
        and two.get("retained_pre_window_pass_count") == 3
        and two.get("retained_baseline_post_window_pass_count") == 3
        and two.get("behavioral_acceptance_authority") is False
        and two.get("r10b_reclassification_authority") is False
        and two.get("r10d_result_prediction_claimed") is False,
        "TWO_CYCLE_CONTRACT",
    )
    require(
        trace.get("retained_outcome_used_to_select_successor_window_structure") is True
        and trace.get("retained_outcome_used_to_change_push_magnitude_or_direction")
        is False
        and trace.get("retained_outcome_used_to_relax_a_safety_threshold") is False
        and trace.get("retained_outcome_used_as_new_acceptance_evidence") is False,
        "OUTCOME_EXPOSURE_DISCLOSURE",
    )
    successor = design["selected_successor_scope"]
    require(
        successor.get("successor_gate_id") == "QSDK-R10D"
        and successor.get("question_class_after_freeze") == "finite decision"
        and successor.get("engine_adapter_id") == "godot_jolt_gdextension_v1"
        and successor.get("physics_engine") == "Jolt Physics"
        and successor.get("engine_count") == 1
        and successor.get("physics_hz") == 120
        and successor.get("solver_velocity_steps") == 20
        and successor.get("solver_position_steps") == 7
        and successor.get("generator_index") == 217
        and successor.get("morphology_id")
        == "qsdk_r05e_axis_star_torso_length_low_s217",
        "SUCCESSOR_SCOPE_IDENTITY",
    )
    for key in (
        "controller_change_selected",
        "recovery_controller_added",
        "force_estimator_added",
        "force_aware_recovery_added",
        "active_mode_switch_added",
        "ordinary_walking_gate_change_selected",
        "material_change_selected",
        "solver_change_selected",
        "host_mapping_change_selected",
        "push_magnitude_or_direction_change_selected",
    ):
        require(successor.get(key) is False, f"SUCCESSOR_FALSE:{key}")
    for key in (
        "supported_start_descriptor_change_selected",
        "marker_shift_by_one_nominal_cycle_selected",
        "eligibility_and_recovery_observation_duration_change_selected",
        "forward_floor_scaled_exactly_with_duration",
        "measurement_only_trace_forward_version_required",
    ):
        require(successor.get(key) is True, f"SUCCESSOR_TRUE:{key}")
    population = design["prospective_population"]
    ghost = population["development_route_ghost"]
    heldout = population["held_out_finite_decision"]
    require(
        ghost.get("campaign_seed") == 40001
        and ghost.get("generator_index") == 217
        and ghost.get("world_count") == 2
        and ghost.get("world_order") == ["baseline_s40001", "push_s40001"]
        and ghost.get("behavioral_success_required") is False
        and ghost.get("route_validity_required") is True
        and ghost.get("claim_authority") is False,
        "GHOST_POPULATION",
    )
    require(
        heldout.get("campaign_seeds") == [40101, 40102, 40103]
        and heldout.get("generator_index") == 217
        and heldout.get("world_count") == 6
        and heldout.get("world_order")
        == [
            "baseline_s40101",
            "push_s40101",
            "baseline_s40102",
            "push_s40102",
            "baseline_s40103",
            "push_s40103",
        ]
        and heldout.get(
            "failed_cell_deletion_replacement_averaging_or_threshold_change_forbidden"
        )
        is True
        and heldout.get(
            "prior_r05e_walking_outcome_for_each_descriptor_seed_pair_known"
        )
        is True
        and heldout.get(
            "external_push_or_recovery_outcome_for_each_descriptor_seed_pair_known"
        )
        is False,
        "HELDOUT_POPULATION",
    )
    require(
        population.get("maximum_total_future_physical_world_count") == 8
        and population.get("population_reserved_by_this_design") is True
        and population.get("r10d_physical_identity_distinct_from_r05e_and_r10b") is True
        and population.get("r10d_outcomes_currently_unobserved") is True,
        "POPULATION_BOUNDARY",
    )
    challenge = design["prospective_challenge_profile"]
    require(
        challenge.get("impulse_task_n_s") == [0.0, 0.0, 0.25]
        and challenge.get("impulse_magnitude_n_s") == 0.25
        and challenge.get("application_semantic_step_from_sdk_start") == 900
        and challenge.get("application_simulation_time_s_from_sdk_start") == 7.5
        and challenge.get("r10b_marker_step") == 540
        and challenge.get("marker_shift_steps") == 360
        and challenge.get("marker_shift_nominal_gq15_cycles") == 1
        and challenge.get("same_nominal_clock_phase_modulo_360_as_r10b") is True
        and challenge.get("magnitude_inherited_exactly_from_r10b_and_bw6n") is True
        and challenge.get("direction_inherited_exactly_from_r10b_and_bw6n") is True
        and challenge.get("magnitude_selected_from_new_outcome") is False
        and challenge.get("direction_selected_from_new_outcome") is False,
        "CHALLENGE_PROFILE",
    )
    baseline = challenge["baseline_arm"]
    require(
        baseline.get("matched_semantic_marker_step") == 900
        and baseline.get("native_impulse_application_count") == 0
        and baseline.get("physics_state_mutation_at_marker") is False,
        "BASELINE_CHALLENGE",
    )
    measurement = design["prospective_trace_and_recovery_measurement_contract"]
    for key in (
        "trace_required_for_every_sdk_step",
        "trace_may_change_controller_input",
        "trace_may_change_controller_output",
        "trace_may_change_physics_state",
        "trace_may_change_existing_walking_evaluator",
    ):
        expected = key == "trace_required_for_every_sdk_step"
        require(measurement.get(key) is expected, f"TRACE_BEHAVIOR:{key}")
    horizon = measurement["runtime_horizon"]
    require(
        horizon.get("minimum_sdk_semantic_step_count") == 2152
        and horizon.get("maximum_sdk_semantic_step_count") == 2872
        and horizon.get("maximum_additional_contact_gated_extension_steps") == 720
        and horizon.get("acceptance_outcome_based_early_termination_permitted") is False
        and horizon.get("latest_recovery_window_half_open_semantic_step_interval")
        == [1260, 1980]
        and horizon.get("minimum_remaining_steps_after_latest_recovery_window") == 172,
        "RUNTIME_HORIZON",
    )
    walking = measurement["ordinary_walking_gate"]
    require(
        walking.get("required_receipt_count") == 27
        and walking.get("required_for_every_baseline_world") is True
        and walking.get("required_for_every_push_world") is True
        and walking.get("all_raw_walking_receipts_must_be_true") is True
        and walking.get("bounded_anchor_error_receipt_removed_or_relaxed") is False,
        "ORDINARY_WALKING_GATE",
    )
    pre = measurement["pre_push_upright_walking_eligibility"]
    require(
        pre.get("half_open_semantic_step_interval") == [180, 900]
        and pre.get("duration_steps") == 720
        and pre.get("duration_s") == 6.0
        and pre.get("maximum_torso_tilt_rad") == 0.6
        and pre.get("minimum_torso_height_m") == 0.25
        and pre.get("maximum_torso_ground_contact_steps") == 0
        and pre.get("each_limb_requires_airborne_then_recontact") is True
        and pre.get("minimum_airborne_dwell_steps") == 3
        and pre.get("minimum_task_frame_forward_advance_m") == 0.02
        and pre.get("all_steps_require_eight_validated_portable_commands") is True
        and pre.get("all_steps_require_eight_native_motor_applications") is True,
        "PRE_WINDOW",
    )
    effect = measurement["native_disturbance_effect"]
    require(
        effect.get("active_native_impulse_application_count") == 1
        and effect.get("baseline_native_impulse_application_count") == 0
        and effect.get("minimum_next_step_velocity_delta_magnitude_m_s") == 0.0001
        and effect.get("paired_lateral_velocity_jump_difference_must_be_positive")
        is True
        and effect.get(
            "paired_difference_is_causal_path_confirmation_not_effect_equivalence"
        )
        is True,
        "NATIVE_EFFECT",
    )
    recovery = measurement["bounded_reentry_search"]
    require(
        recovery.get("first_candidate_reentry_semantic_step") == 901
        and recovery.get("last_candidate_reentry_semantic_step") == 1260
        and recovery.get("candidate_start_count") == 360
        and recovery.get("maximum_reentry_latency_steps") == 360
        and recovery.get("maximum_reentry_latency_s") == 3.0
        and recovery.get("candidate_recovery_window_duration_steps") == 720
        and recovery.get("candidate_recovery_window_duration_s") == 6.0
        and recovery.get("first_valid_window_selected") is True
        and recovery.get(
            "window_requirements_identical_to_pre_push_upright_walking_eligibility"
        )
        is True
        and recovery.get("forced_fall_or_forced_threshold_departure_required") is False,
        "RECOVERY_SEARCH",
    )
    matched = measurement["matched_baseline_control"]
    require(
        matched.get("post_marker_half_open_semantic_step_interval") == [901, 1621]
        and matched.get("duration_steps") == 720
        and matched.get(
            "requirements_identical_to_pre_push_upright_walking_eligibility"
        )
        is True,
        "MATCHED_BASELINE",
    )
    decision_contract = design["decision_contract"]
    require(
        len(decision_contract.get("held_out_result_valid_only_if", [])) == 11
        and decision_contract.get("pooling_across_seeds_permitted") is False
        and decision_contract.get("pooling_across_hosts_permitted") is False
        and decision_contract.get("mean_success_rate_permitted") is False
        and decision_contract.get("same_identity_rerun_permitted") is False
        and decision_contract.get(
            "post_result_threshold_or_interpretation_change_permitted"
        )
        is False,
        "DECISION_CONTRACT",
    )
    controls = design["required_zero_world_implementation_controls"]
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(controls.get(key) == 0, f"CONTROLS_NONZERO:{key}")
    require(
        controls.get("ordinary_walking_gate_change_selected", False) is False
        and controls.get("physical_acceptance_authority") is False
        and controls.get("release_authority") is False,
        "CONTROLS_AUTHORITY",
    )
    sequence = design["forward_authority_sequence"]
    require(len(sequence.get("ordered_steps", [])) == 16, "SEQUENCE_STEP_COUNT")
    for key in (
        "new_clean_pushed_source_required",
        "new_official_zero_world_qualification_required",
        "stage_freeze_only_commit_required",
        "execution_authority_only_child_commit_required",
        "committed_graph_authority_check_required",
        "distinct_physical_output_identity_required",
        "held_out_cells_remain_sealed",
        "physical_execution_blocked_until_sequence_complete",
    ):
        require(sequence.get(key) is True, f"SEQUENCE_TRUE:{key}")
    require(
        sequence.get("old_r10b_or_r05e_physical_identity_may_be_reused") is False
        and sequence.get("maximum_development_route_ghost_campaign_attempt_count") == 1
        and sequence.get("maximum_development_route_ghost_world_count") == 2,
        "SEQUENCE_LIMITS",
    )
    limits = design["immutability_and_limits"]
    for key in (
        "r05e_rerun_count",
        "r10b_rerun_count",
        "new_physical_process_launch_count",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(limits.get(key) == 0, f"LIMIT_NONZERO:{key}")
    require(
        limits.get("physical_outcome_exposed") is False
        and limits.get("r10b_retained_outcome_exposed_to_design") is True
        and limits.get("r05e_prior_walking_outcome_exposed_to_design") is True
        and limits.get("r10d_push_or_recovery_outcome_exposed") is False
        and limits.get("controller_or_ordinary_walking_threshold_mutation") is False
        and limits.get("historical_result_reinterpretation") is False
        and limits.get("outcome_derived_acceptance_correction") is False,
        "IMMUTABILITY_DISCLOSURE",
    )
    claims = design["claim_boundary"]
    require(
        claims.get("design_complete") is True
        and claims.get("retained_diagnosis_complete") is True
        and claims.get("r05e_exact_descriptor_prior_walking_support_claimed") is True
        and claims.get("r10b_valid_complete_finite_negative_preserved") is True
        and claims.get("r10b_native_push_path_observed_claimed") is True
        and claims.get("r10b_post_push_recovery_windows_observed_claimed") is True,
        "CLAIM_TRUE_SET",
    )
    for key in (
        "implementation_complete",
        "development_route_ghost_complete",
        "held_out_finite_decision_complete",
        "r10d_bounded_upright_push_recovery",
        "external_push_recovery",
        "physical_balance_recovery",
        "fall_recovery",
        "prone_to_standing",
        "self_righting",
        "force_aware_recovery",
        "arbitrary_push_direction_or_magnitude",
        "push_recovery_across_r05e_axis_star_morphologies",
        "push_recovery_in_rapier_or_mujoco",
        "cross_engine_effect_equivalence",
        "population_success_rate",
        "sdk1_m07_advanced",
        "q_sdk_r10_advanced",
        "release_authorized",
        "physical_acceptance_authority",
    ):
        require(claims.get(key) is False, f"FORBIDDEN_CLAIM:{key}")
    decision = design["decision"]
    require(
        decision.get("selected")
        == "QSDK-R10D-SUPPORTED-START-PHASE-ROBUST-UPRIGHT-PUSH-RECOVERY-IMPLEMENTATION"
        and decision.get("q_sdk_r10c_closed") is True
        and decision.get("q_sdk_r10d_zero_world_implementation_authorized") is True
        and decision.get("q_sdk_r10d_physical_execution_authorized") is False
        and decision.get("scores_unchanged") is True,
        "DECISION",
    )


def validate_r05e_support(
    design: dict[str, Any], loaded: dict[str, dict[str, Any]]
) -> int:
    report_raw = R05E_REPORT_PATH.read_bytes()
    require(len(report_raw) == R05E_REPORT_BYTES, "R05E_REPORT_BYTES")
    require(sha256_bytes(report_raw) == R05E_REPORT_SHA256, "R05E_REPORT_SHA256")
    report = read_json(report_raw, "R05E_REPORT")
    require(
        report.get("campaign_id") == "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION"
        and report.get("campaign_role") == "held_out_finite_decision"
        and report.get("observed_world_count") == 36
        and report.get("complete_receipt_count") == 36
        and report.get("walking_pass_count") == 36
        and report.get("integrity_pass_count") == 36
        and report.get("failure_count") == 0
        and report.get("external_push_recovery") is False
        and report.get("r05e_passed") is True,
        "R05E_REPORT_RESULT",
    )
    results = report.get("results")
    require(isinstance(results, list), "R05E_RESULTS_ARRAY")
    selected = [item for item in results if item.get("generator_index") == 217]
    require(len(selected) == 3, "R05E_SELECTED_CELL_COUNT")
    design_receipts = design["supported_start_selection"]["prior_exact_walking_support"]
    require(
        [item.get("campaign_seed") for item in design_receipts]
        == list(R05E_RESULT_SPECS),
        "R05E_DESIGN_SEED_ORDER",
    )
    for result, summary in zip(selected, design_receipts):
        seed = int(result.get("campaign_seed", -1))
        spec = R05E_RESULT_SPECS.get(seed)
        require(spec is not None, f"R05E_SEED:{seed}")
        receipt = result.get("receipt")
        require(isinstance(receipt, dict), f"R05E_RECEIPT:{seed}")
        walking_receipts = receipt.get("walking_gate_receipts")
        require(
            isinstance(walking_receipts, dict)
            and len(walking_receipts) == 27
            and all(value is True for value in walking_receipts.values()),
            f"R05E_WALKING_RECEIPTS:{seed}",
        )
        require(
            result.get("morphology_id") == "qsdk_r05e_axis_star_torso_length_low_s217"
            and result.get("harness_passed") is True
            and result.get("walking_observed") is True
            and result.get("common_execution_integrity") is True
            and result.get("failed_production_walking_gate_count") == 0
            and receipt.get("walking_observed") is True
            and receipt.get("world_build_count") == 1
            and receipt.get("generator_receipt_sha256")
            == "sha256:776dc3efb497917a79391de6d895e4984d8c35fe9ae29b3470552e2ee3a087d9"
            and receipt.get("proportion_spec_sha256")
            == "sha256:2ad58378a1e3c6e8e9b16a9862141c4f390f2947f01b1108cd66a594a0f75d0c"
            and receipt.get("fixture_spec_sha256")
            == "sha256:9b54fda516c11d451f319fb9ea116896de049aa53b43676de8745ca5f29d670a"
            and receipt.get("controller_profile_sha256")
            == "sha256:e4fb8bc38d6892ec5d7a4b5eb01007ab7bdb405c69ddfccac1684889dadfba2b",
            f"R05E_CELL_IDENTITY:{seed}",
        )
        for field, expected in spec.items():
            require(receipt.get(field) == expected, f"R05E_METRIC:{seed}:{field}")
            require(
                summary.get(field) == expected, f"R05E_DESIGN_METRIC:{seed}:{field}"
            )
        require(
            summary.get("walking_receipt_count") == 27
            and summary.get("false_walking_receipt_count") == 0
            and summary.get("walking_passed") is True,
            f"R05E_DESIGN_SUMMARY:{seed}",
        )
    closure = loaded["prior_r05e_exact_finite_supported_morphology_closure"]
    frozen = closure["population"]["frozen_cells"]
    require(
        frozen[0]
        == {
            "generator_index": 217,
            "morphology_id": "qsdk_r05e_axis_star_torso_length_low_s217",
            "generator_receipt_sha256": "sha256:776dc3efb497917a79391de6d895e4984d8c35fe9ae29b3470552e2ee3a087d9",
            "proportion_spec_sha256": "sha256:2ad58378a1e3c6e8e9b16a9862141c4f390f2947f01b1108cd66a594a0f75d0c",
        }
        and closure["population"]["generator_indices"] == list(range(217, 229))
        and closure["population"]["campaign_seeds"] == [40101, 40102, 40103]
        and closure["outcome"]["walking_pass_count"] == 36
        and closure["outcome"]["false_walking_gate_receipt_count"] == 0,
        "R05E_CLOSURE_SUPPORT",
    )
    seed_authority = loaded["r05e_development_seed_classification"]
    require(
        seed_authority["repetitions"]["campaign_seeds"] == [40001]
        and seed_authority["predecessor_interlock"]["heldout_seed_values"]
        == [40101, 40102, 40103],
        "R05E_SEED_CLASSIFICATION",
    )
    return len(selected)


def vector_sub(left: list[Any], right: list[Any]) -> list[float]:
    require(len(left) == 3 and len(right) == 3, "VECTOR_LENGTH")
    return [float(a) - float(b) for a, b in zip(left, right)]


def vector_dot(left: list[Any], right: list[Any]) -> float:
    require(len(left) == 3 and len(right) == 3, "VECTOR_LENGTH")
    return sum(float(a) * float(b) for a, b in zip(left, right))


def evaluate_window(
    rows: list[dict[str, Any]], start: int, end: int, minimum_advance: float
) -> dict[str, Any]:
    require(start >= 1 and end > start and end <= len(rows), "WINDOW_BOUNDS")
    safe = True
    commands = True
    for step in range(start, end):
        row = rows[step]
        require(row.get("semantic_step") == step, f"TRACE_STEP:{step}")
        position = row["torso_position_world_m"]
        safe = (
            safe
            and float(position[1]) >= 0.25
            and float(row["torso_tilt_rad"]) <= 0.6
            and row["torso_ground_contact"] is False
        )
        commands = (
            commands
            and row["validated_portable_command_count"] == 8
            and row["native_actuation_application_count"] == 8
        )
    cycles: dict[str, dict[str, Any]] = {}
    for limb in EXPECTED_LIMBS:
        airborne_dwell = 0
        longest_airborne_dwell = 0
        qualifying_recontact = -1
        for step in range(start, end):
            contact = rows[step]["ordered_foot_contacts_after"][limb]
            require(type(contact) is bool, f"CONTACT_TYPE:{step}:{limb}")
            if not contact:
                airborne_dwell += 1
                longest_airborne_dwell = max(longest_airborne_dwell, airborne_dwell)
            elif airborne_dwell >= 3:
                qualifying_recontact = step
                break
            else:
                airborne_dwell = 0
        cycles[limb] = {
            "passed": qualifying_recontact >= 0,
            "longest_airborne_dwell_steps": longest_airborne_dwell,
            "qualifying_recontact_semantic_step": qualifying_recontact,
        }
    advance = vector_dot(
        vector_sub(
            rows[end - 1]["torso_position_world_m"],
            rows[start - 1]["torso_position_world_m"],
        ),
        rows[start - 1]["task_frame_forward_axis_world_unit"],
    )
    forward = advance >= minimum_advance
    passed = (
        safe
        and commands
        and all(item["passed"] for item in cycles.values())
        and forward
    )
    return {
        "start": start,
        "end": end,
        "duration": end - start,
        "safe": safe,
        "commands": commands,
        "cycles": cycles,
        "advance": advance,
        "forward": forward,
        "passed": passed,
    }


def normalized_prefix(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {key: value for key, value in row.items() if key != "cell_id"}
        for row in rows[:540]
    ]


def validate_r10b_retained_diagnosis(design: dict[str, Any]) -> tuple[int, int]:
    closure = r10b.common.read_json(r10b.CLOSURE_PATH, "R10B_CLOSURE")
    r10b.validate_closure_contract(closure)
    r10b.validate_source_graph(closure)
    r10b.validate_qualification(closure)
    marker_count, trace_row_count = r10b.validate_retained_evidence(closure)
    require(marker_count == 12, "R10B_MARKER_COUNT")
    require(trace_row_count == 16_315, "R10B_TRACE_ROW_COUNT")
    trace_design = design["retained_r10b_trace_diagnosis"]
    prefix_design = trace_design["pre_marker_pair_identity"]
    frozen_design = trace_design["frozen_one_cycle_pre_window"]
    sliding_design = trace_design["one_cycle_sliding_window_diagnostic"]
    two_design = trace_design["two_cycle_prospective_structure_diagnostic"]
    frozen_by_seed = {
        int(item["campaign_seed"]): item
        for item in frozen_design["baseline_receipts_by_seed"]
    }
    sliding_by_seed = {
        int(item["campaign_seed"]): item
        for item in sliding_design["first_valid_window_by_seed"]
    }
    two_by_seed = {
        int(item["campaign_seed"]): item
        for item in two_design["retained_baseline_receipts_by_seed"]
    }
    valid_by_old_marker = 0
    for seed in (50301, 50302, 50303):
        baseline_cell = r10b.common.read_json(
            r10b.EVIDENCE_ROOT / f"baseline_s{seed}" / "cell.json",
            f"R10B_BASELINE_{seed}",
        )
        push_cell = r10b.common.read_json(
            r10b.EVIDENCE_ROOT / f"push_s{seed}" / "cell.json",
            f"R10B_PUSH_{seed}",
        )
        baseline_rows = baseline_cell["sdk_physical_trace"]["rows"]
        push_rows = push_cell["sdk_physical_trace"]["rows"]
        baseline_prefix = normalized_prefix(baseline_rows)
        push_prefix = normalized_prefix(push_rows)
        require(baseline_prefix == push_prefix, f"PREFIX_PAIR_MISMATCH:{seed}")
        require(
            r10b.hash_object(baseline_prefix) == PREFIX_SHA256[seed],
            f"PREFIX_SHA:{seed}",
        )
        require(
            prefix_design["prefix_sha256_by_seed"][str(seed)] == PREFIX_SHA256[seed],
            f"PREFIX_DESIGN_SHA:{seed}",
        )
        require(
            normalized_prefix(baseline_rows[540:541])
            != normalized_prefix(push_rows[540:541]),
            f"MARKER_DIFFERENCE_MISSING:{seed}",
        )
        frozen = evaluate_window(baseline_rows, 180, 540, 0.01)
        stored = baseline_cell["evaluation"]["pre_push_window"]
        require(
            frozen["safe"] is True
            and frozen["commands"] is True
            and frozen["forward"] is True
            and frozen["passed"] is False
            and math.isclose(
                frozen["advance"],
                stored["task_frame_forward_advance_m"],
                rel_tol=0.0,
                abs_tol=2.0e-8,
            ),
            f"FROZEN_REPLAY:{seed}",
        )
        failed_limbs = sorted(
            limb for limb, receipt in frozen["cycles"].items() if not receipt["passed"]
        )
        frozen_summary = frozen_by_seed[seed]
        require(
            frozen_summary["task_frame_forward_advance_m"]
            == stored["task_frame_forward_advance_m"]
            and frozen_summary["failed_limbs"] == failed_limbs,
            f"FROZEN_DESIGN_SUMMARY:{seed}",
        )
        first_valid: dict[str, Any] | None = None
        for start in range(180, 541):
            candidate = evaluate_window(baseline_rows, start, start + 360, 0.01)
            if candidate["passed"]:
                first_valid = candidate
                break
        require(first_valid is not None, f"NO_ONE_CYCLE_WINDOW:{seed}")
        start, end, advance = ONE_CYCLE_FIRST_VALID[seed]
        require(
            first_valid["start"] == start
            and first_valid["end"] == end
            and first_valid["advance"] == advance,
            f"FIRST_ONE_CYCLE:{seed}",
        )
        if first_valid["end"] <= 540:
            valid_by_old_marker += 1
        sliding_summary = sliding_by_seed[seed]
        require(
            sliding_summary["start_semantic_step"] == start
            and sliding_summary["end_semantic_step_exclusive"] == end
            and sliding_summary["shift_after_frozen_end_steps"] == end - 540
            and sliding_summary["task_frame_forward_advance_m"] == advance,
            f"SLIDING_DESIGN_SUMMARY:{seed}",
        )
        two_pre = evaluate_window(baseline_rows, 180, 900, 0.02)
        two_post = evaluate_window(baseline_rows, 901, 1621, 0.02)
        spec = TWO_CYCLE_SPECS[seed]
        require(
            two_pre["passed"] is True
            and two_post["passed"] is True
            and two_pre["advance"] == spec["pre_advance"]
            and two_post["advance"] == spec["post_advance"],
            f"TWO_CYCLE_REPLAY:{seed}",
        )
        pre_recontacts = {
            limb: receipt["qualifying_recontact_semantic_step"]
            for limb, receipt in two_pre["cycles"].items()
        }
        post_recontacts = {
            limb: receipt["qualifying_recontact_semantic_step"]
            for limb, receipt in two_post["cycles"].items()
        }
        require(
            pre_recontacts == spec["pre_recontacts"]
            and post_recontacts == spec["post_recontacts"],
            f"TWO_CYCLE_RECONTACTS:{seed}",
        )
        two_summary = two_by_seed[seed]
        require(
            two_summary["pre_window_passed"] is True
            and two_summary["pre_task_frame_forward_advance_m"] == two_pre["advance"]
            and two_summary["pre_recontact_steps"] == pre_recontacts
            and two_summary["baseline_post_window_passed"] is True
            and two_summary["baseline_post_task_frame_forward_advance_m"]
            == two_post["advance"]
            and two_summary["baseline_post_recontact_steps"] == post_recontacts,
            f"TWO_CYCLE_DESIGN_SUMMARY:{seed}",
        )
    require(valid_by_old_marker == 0, "OLD_MARKER_VALID_WINDOW_COUNT")
    require(
        sliding_design["valid_window_ending_at_or_before_frozen_marker_count"]
        == valid_by_old_marker,
        "OLD_MARKER_DESIGN_COUNT",
    )
    return marker_count, trace_row_count


def set_path(value: dict[str, Any], path: str, replacement: Any) -> None:
    parts = path.split(".")
    target: Any = value
    for part in parts[:-1]:
        target = target[part]
    target[parts[-1]] = replacement


def mutation_refusal_count(design: dict[str, Any]) -> int:
    mutations = (
        ("authored_parent_commit", "0" * 40),
        ("question_declaration.physical_work_authorized", True),
        ("release_milestone_context.current_sdk1_completed_steps", 14),
        ("consumed_predecessor_result.same_identity_rerun_permitted", True),
        ("causal_diagnosis.r10b_result_remains_negative", False),
        ("supported_start_selection.selected_generator_index", 218),
        ("supported_start_selection.selection_uses_walking_margin_ranking", True),
        ("supported_start_selection.exact_proportion_spec.torso_length_scale", 1.0),
        ("retained_r10b_trace_diagnosis.retained_trace_row_count", 16_314),
        (
            "retained_r10b_trace_diagnosis.pre_marker_pair_identity.first_expected_difference_semantic_step",
            541,
        ),
        (
            "retained_r10b_trace_diagnosis.one_cycle_sliding_window_diagnostic.valid_window_ending_at_or_before_frozen_marker_count",
            1,
        ),
        (
            "retained_r10b_trace_diagnosis.two_cycle_prospective_structure_diagnostic.duration_steps",
            719,
        ),
        ("selected_successor_scope.ordinary_walking_gate_change_selected", True),
        (
            "prospective_population.held_out_finite_decision.campaign_seeds",
            [40101, 40102],
        ),
        ("prospective_challenge_profile.impulse_magnitude_n_s", 0.24),
        ("prospective_challenge_profile.application_semantic_step_from_sdk_start", 899),
        (
            "prospective_trace_and_recovery_measurement_contract.pre_push_upright_walking_eligibility.minimum_task_frame_forward_advance_m",
            0.019,
        ),
        (
            "prospective_trace_and_recovery_measurement_contract.bounded_reentry_search.last_candidate_reentry_semantic_step",
            1261,
        ),
        (
            "forward_authority_sequence.old_r10b_or_r05e_physical_identity_may_be_reused",
            True,
        ),
        ("immutability_and_limits.outcome_derived_acceptance_correction", True),
        ("claim_boundary.external_push_recovery", True),
        ("decision.q_sdk_r10d_physical_execution_authorized", True),
    )
    refused = 0
    for path, replacement in mutations:
        candidate = copy.deepcopy(design)
        set_path(candidate, path, replacement)
        try:
            validate_static_contract(candidate)
        except AuditFailure:
            refused += 1
    require(refused == len(mutations), "MUTATION_CONTROL_FAILED")
    return refused


def main() -> int:
    validate_repository()
    design = validate_design_identity()
    validate_static_contract(design)
    loaded = validate_bindings(design)
    r05e_cell_count = validate_r05e_support(design, loaded)
    marker_count, trace_row_count = validate_r10b_retained_diagnosis(design)
    mutation_count = mutation_refusal_count(design)
    receipt = {
        "schema_version": "sporespore_qsdk_r10c_supported_start_phase_robust_successor_design_audit_v1",
        "gate_id": "QSDK-R10C",
        "design_id": "QSDK-R10C-D1",
        "ok": True,
        "bound_authority_count": len(EXPECTED_ROLES),
        "r05e_prior_supported_cell_count": r05e_cell_count,
        "r05e_prior_walking_receipt_count": r05e_cell_count * 27,
        "r10b_retained_file_count": 37,
        "r10b_retained_total_byte_length": 121_645_064,
        "r10b_retained_trace_row_count": trace_row_count,
        "r10b_cell_marker_count": marker_count,
        "matched_pre_marker_prefix_count": 3,
        "first_valid_one_cycle_window_count": 3,
        "one_cycle_window_ending_by_old_marker_count": 0,
        "two_cycle_pre_window_pass_count": 3,
        "two_cycle_baseline_post_window_pass_count": 3,
        "design_mutation_rejection_count": mutation_count,
        "r10b_result_reclassified": False,
        "r05e_result_reclassified": False,
        "r10d_physical_outcome_exposed": False,
        "sdk1_m07_satisfied": False,
        "q_sdk_r10_satisfied": False,
        "sdk1_completed_steps": 13,
        "sdk1_total_steps": 20,
        "full_program_completed_steps": 13,
        "full_program_total_steps": 25,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    print(PASS_MARKER + json.dumps(receipt, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditFailure, r10b.common.ClosureFailure) as exc:
        print(f"QSDK_R10C_SUPPORTED_START_PHASE_ROBUST_SUCCESSOR_DESIGN_FAIL {exc}")
        raise SystemExit(1) from exc
