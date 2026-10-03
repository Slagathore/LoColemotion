#!/usr/bin/env python3
"""Fail-closed zero-world audit for the QSDK-R10A successor design."""

from __future__ import annotations

import copy
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DESIGN_PATH = (
    REPO_ROOT / "sdk/qsdk_r10a_bounded_upright_push_recovery_successor_design_v1.json"
)
EXPECTED_DESIGN_BYTES = 25836
EXPECTED_DESIGN_SHA256 = (
    "f5738803e65d25b3225c0b054ced5f21613650f2a5aa1d79e76b700ad7d36f66"
)
PARENT_COMMIT = "392712f9747a539d6f37a8000d056451cb68cb9b"

EXPECTED_ROLES = {
    "live_release_contract",
    "sdk1_milestone_mapping",
    "selected_portable_policy",
    "bw6n_frozen_challenge_manifest",
    "bw6n_immutable_negative_report",
    "bw6n_opened_diagnostic_report",
    "bw32n_immutable_development_closure",
    "r05e_selected_policy_production_route_physical_closure",
    "r05e_selected_policy_production_route",
    "godot_jolt_physical_walker_and_native_push_source",
    "reference_fixture_source",
    "gq15_clock_source",
    "godot_jolt_material_profile_source",
    "godot_jolt_adapter_source",
    "research_evidence_contract",
    "r10a_design_freshness_receipt",
}


class AuditFailure(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditFailure(message)


def sha256_hex(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def git_blob_oid(raw: bytes) -> str:
    header = f"blob {len(raw)}\0".encode("ascii")
    return hashlib.sha1(header + raw).hexdigest()


def read_json(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"{label} is not strict UTF-8 JSON: {exc}") from exc
    require(isinstance(value, dict), f"{label} must be a JSON object")
    return value


def exact_equal(actual: Any, expected: Any) -> bool:
    if isinstance(expected, bool):
        return isinstance(actual, bool) and actual is expected
    if isinstance(expected, int):
        return (
            isinstance(actual, int)
            and not isinstance(actual, bool)
            and actual == expected
        )
    if isinstance(expected, float):
        return (
            isinstance(actual, (int, float))
            and not isinstance(actual, bool)
            and math.isfinite(float(actual))
            and float(actual) == expected
        )
    return type(actual) is type(expected) and actual == expected


def dotted(value: Any, path: str) -> Any:
    current = value
    for part in path.split("."):
        require(isinstance(current, dict), f"{path}: {part} parent is not an object")
        require(part in current, f"{path}: missing {part}")
        current = current[part]
    return current


def parent_blob_oid(commit: str, repo_path: str) -> str:
    completed = subprocess.run(
        ["git", "rev-parse", f"{commit}:{repo_path}"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    require(completed.returncode == 0, f"cannot resolve parent blob for {repo_path}")
    return completed.stdout.strip().lower()


def selected_authority_object(role: str, loaded: dict[str, Any]) -> dict[str, Any]:
    if role == "live_release_contract":
        gates = loaded.get("gates")
        require(isinstance(gates, list), "release contract gates missing")
        matches = [
            gate
            for gate in gates
            if isinstance(gate, dict) and gate.get("gate_id") == "QSDK-R10"
        ]
        require(
            len(matches) == 1, "release contract must contain exactly one QSDK-R10 gate"
        )
        return matches[0]
    if role == "sdk1_milestone_mapping":
        contract = loaded.get("sdk1_contract")
        require(isinstance(contract, dict), "SDK1 contract missing")
        milestones = contract.get("milestones")
        require(isinstance(milestones, list), "SDK1 milestone list missing")
        matches = [
            item
            for item in milestones
            if isinstance(item, dict) and item.get("milestone_id") == "SDK1-M07"
        ]
        require(
            len(matches) == 1, "mapping must contain exactly one SDK1-M07 milestone"
        )
        return matches[0]
    return loaded


def validate_bindings(design: dict[str, Any]) -> dict[str, dict[str, Any]]:
    authorities = design.get("bound_authorities")
    require(isinstance(authorities, list), "bound_authorities must be an array")
    require(len(authorities) == len(EXPECTED_ROLES), "bound authority count mismatch")
    roles = [entry.get("role") for entry in authorities if isinstance(entry, dict)]
    require(
        len(roles) == len(authorities),
        "every bound authority must be an object with a role",
    )
    require(
        set(roles) == EXPECTED_ROLES and len(set(roles)) == len(roles),
        "bound authority role set mismatch",
    )

    loaded_by_role: dict[str, dict[str, Any]] = {}
    for entry in authorities:
        role = entry["role"]
        raw_path = entry.get("path")
        require(isinstance(raw_path, str) and raw_path, f"{role}: invalid path")
        absolute = entry.get("path_kind") == "absolute_durable_evidence"
        path = Path(raw_path) if absolute else REPO_ROOT / raw_path
        require(path.is_file(), f"{role}: missing bound file {path}")
        raw = path.read_bytes()
        require(len(raw) == entry.get("byte_length"), f"{role}: byte length mismatch")
        require(
            "sha256:" + sha256_hex(raw) == entry.get("raw_sha256"),
            f"{role}: SHA-256 mismatch",
        )
        if not absolute:
            require(
                entry.get("source_commit") == PARENT_COMMIT,
                f"{role}: source commit mismatch",
            )
            observed_blob = git_blob_oid(raw)
            require(
                observed_blob == entry.get("git_blob_oid"),
                f"{role}: current Git blob mismatch",
            )
            require(
                parent_blob_oid(PARENT_COMMIT, raw_path) == observed_blob,
                f"{role}: file differs from authored parent",
            )
        loaded = read_json(raw, role) if path.suffix.lower() == ".json" else {}
        loaded_by_role[role] = loaded
        expected_paths = entry.get("expected_paths", {})
        require(
            isinstance(expected_paths, dict),
            f"{role}: expected_paths must be an object",
        )
        if expected_paths:
            selected = selected_authority_object(role, loaded)
            for dotted_path, expected in expected_paths.items():
                actual = dotted(selected, dotted_path)
                require(
                    exact_equal(actual, expected),
                    f"{role}: expected path mismatch at {dotted_path}",
                )
    return loaded_by_role


def validate_historical_diagnosis(
    design: dict[str, Any], loaded: dict[str, dict[str, Any]]
) -> None:
    diagnosis = design["retained_evidence_diagnosis"]
    bw6n = loaded["bw6n_immutable_negative_report"]
    receipt = bw6n.get("receipt")
    require(isinstance(receipt, dict), "BW6N receipt missing")
    require(receipt.get("observed_world_count") == 12, "BW6N world count changed")
    require(receipt.get("passed_gate_count") == 16, "BW6N gate count changed")
    require(
        receipt.get("expected_gate_count") == 24, "BW6N expected gate count changed"
    )
    require(
        receipt.get("pass_by_cohort")
        == {"baseline": 2, "push": 2, "rough": 1, "sensor_noise": 2},
        "BW6N cohort pass counts changed",
    )
    cells = receipt.get("cells")
    require(
        isinstance(cells, list) and len(cells) == 12, "BW6N cell population changed"
    )
    by_identity = {
        (cell.get("cohort"), cell.get("campaign_seed")): cell
        for cell in cells
        if isinstance(cell, dict)
    }
    require(len(by_identity) == 12, "BW6N cell identities are not unique")
    for cohort in ("baseline", "push"):
        cell = by_identity[(cohort, 21003)]
        gates = cell.get("walking_gate_receipts")
        require(isinstance(gates, dict), f"BW6N {cohort} seed 21003 gates missing")
        failed = sorted(key for key, value in gates.items() if value is not True)
        require(
            failed == ["evidence_four_contact_stance"], f"BW6N {cohort} failure changed"
        )
    push_cells = [cell for cell in cells if cell.get("cohort") == "push"]
    require(len(push_cells) == 3, "BW6N push cell count changed")
    for cell in push_cells:
        push = cell.get("external_push_receipt")
        require(isinstance(push, dict), "BW6N push receipt missing")
        require(
            cell.get("external_push_application_count") == 1, "BW6N push count changed"
        )
        require(push.get("effect_sampled") is True, "BW6N push effect was not sampled")
        require(
            float(push.get("observed_next_tick_velocity_delta_magnitude_m_s", 0.0))
            > 1.0e-4,
            "BW6N native push effect no longer clears its floor",
        )

    declared_bw6n = diagnosis["bw6n"]
    require(
        declared_bw6n["baseline_walking_pass_count"] == 2,
        "declared BW6N baseline count mismatch",
    )
    require(
        declared_bw6n["push_walking_pass_count"] == 2,
        "declared BW6N push count mismatch",
    )
    require(
        declared_bw6n["same_identity_rerun_or_repair_permitted"] is False,
        "BW6N rerun opened",
    )

    bw32n = loaded["bw32n_immutable_development_closure"]
    candidate_b = dotted(bw32n, "candidate_comparison.candidate_b")
    require(candidate_b["walking_pass_count"] == 10, "BW32N-B walking count changed")
    require(
        candidate_b["failures_by_axis"]["bw6n_push_v1"] == 0,
        "BW32N-B push count changed",
    )
    require(
        dotted(bw32n, "claim_boundary.external_push_recovery") is False,
        "BW32N claim inflated",
    )
    require(
        diagnosis["bw32n"]["external_push_recovery_authority"] is False,
        "BW32N authority inflated",
    )

    r05e = loaded["r05e_selected_policy_production_route_physical_closure"]
    require(
        dotted(r05e, "outcome.walking_pass_count") == 36, "R05E walking count changed"
    )
    require(
        dotted(r05e, "outcome.false_walking_gate_receipt_count") == 0,
        "R05E gate count changed",
    )
    require(
        dotted(r05e, "claim_boundary.external_push_recovery") is False,
        "R05E claim inflated",
    )
    require(
        diagnosis["historical_results_used_to_choose_held_out_seed"] is False,
        "outcome-based seed selection",
    )
    require(
        diagnosis["historical_threshold_or_result_changed"] is False,
        "historical result changed",
    )


def validate_scope_and_profile(design: dict[str, Any]) -> None:
    context = design["release_milestone_context"]
    require(context["sdk1_milestone_id"] == "SDK1-M07", "wrong SDK1 milestone")
    require(context["full_program_gate_id"] == "QSDK-R10", "wrong release gate")
    require(context["current_sdk1_completed_steps"] == 13, "SDK1 score changed")
    require(context["current_full_program_completed_steps"] == 13, "full score changed")
    require(
        context["milestone_advanced_by_this_design"] is False, "design advanced M07"
    )
    require(
        context["native_kick_deferred_to_sdk1_m20_explorer"] is True,
        "native kick was pulled into the R10A physical question",
    )
    scope = design["selected_successor_scope"]
    expected_scope = {
        "successor_gate_id": "QSDK-R10B",
        "official_campaign_id": "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-VALIDATION",
        "development_route_ghost_campaign_id": "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST",
        "engine_adapter_id": "godot_jolt_gdextension_v1",
        "physics_engine": "Jolt Physics",
        "engine_count": 1,
        "physics_hz": 120,
        "solver_velocity_steps": 20,
        "solver_position_steps": 7,
        "selected_candidate_id": "BW5R-B",
        "selected_policy_id": "sporespore_balanced_wave_bw5r_b_v1",
        "selected_policy_digest": "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f",
        "material_profile_id": "godot_jolt_bw5c_mu095_v1",
        "gait_clock_policy_id": "g4_gq15_four_cycle_contact_clock_v1",
        "fixture_scope": "exact_reference_quadruped_geometry_only",
    }
    for key, expected in expected_scope.items():
        require(exact_equal(scope.get(key), expected), f"scope mismatch at {key}")
    for key in (
        "controller_change_selected",
        "recovery_controller_added",
        "force_estimator_added",
        "force_aware_recovery_added",
        "active_mode_switch_added",
        "walking_threshold_change_selected",
        "material_change_selected",
        "solver_change_selected",
        "host_mapping_change_selected",
        "behavior_change_selected",
    ):
        require(scope.get(key) is False, f"forbidden scope change: {key}")
    require(
        scope["measurement_only_trace_extension_required"] is True,
        "measurement trace not selected",
    )

    descriptor = design["exact_reference_descriptor"]
    require(
        descriptor["schema_version"] == "sporespore_bounded_quadruped_descriptor_v1",
        "descriptor schema",
    )
    require(
        [
            descriptor[key]
            for key in (
                "torso_length_scale",
                "torso_width_scale",
                "hip_span_scale",
                "foot_radius_scale",
                "front_limb_mass_scale",
            )
        ]
        == [1.0] * 5,
        "reference descriptor scale changed",
    )
    require(
        descriptor["upper_length_fraction"] == 0.5142857142857142,
        "reference upper fraction changed",
    )
    require(
        descriptor["interpolation_or_arbitrary_morphology_claim"] is False,
        "morphology scope inflated",
    )

    profile = design["prospective_challenge_profile"]
    require(
        profile["challenge_profile_id"] == "qsdk_r10a_lateral_upright_impulse_v1",
        "profile identity",
    )
    require(profile["terrain_profile_id"] == "flat_v1", "terrain changed")
    require(profile["target_body"] == "torso", "push target changed")
    require(
        profile["application_point"]
        == "native_center_of_mass_via_apply_central_impulse",
        "application point changed",
    )
    require(
        profile["coordinate_frame"] == "initial_task_frame_x_forward_y_up_z_right",
        "frame changed",
    )
    require(profile["impulse_task_n_s"] == [0.0, 0.0, 0.25], "push vector changed")
    require(profile["impulse_magnitude_n_s"] == 0.25, "push magnitude changed")
    require(
        profile["application_semantic_step_from_sdk_start"] == 540, "push time changed"
    )
    require(
        profile["application_simulation_time_s_from_sdk_start"] == 4.5,
        "push seconds changed",
    )
    require(
        profile["operator_disturbance_not_controller_command"] is True,
        "push became controller authority",
    )
    require(
        profile["profile_inherited_exactly_from_bw6n"] is True,
        "BW6N profile inheritance removed",
    )
    for key in (
        "magnitude_selected_from_new_outcome",
        "direction_selected_from_new_outcome",
        "timing_selected_from_new_outcome",
    ):
        require(profile[key] is False, f"outcome-derived challenge field: {key}")
    baseline = profile["baseline_arm"]
    require(baseline["matched_semantic_marker_step"] == 540, "baseline marker changed")
    require(
        baseline["native_impulse_application_count"] == 0, "baseline applies impulse"
    )
    require(
        baseline["physics_state_mutation_at_marker"] is False,
        "baseline marker mutates physics",
    )


def validate_population(
    design: dict[str, Any], loaded: dict[str, dict[str, Any]]
) -> None:
    population = design["prospective_population"]
    ghost = population["development_route_ghost"]
    held = population["held_out_finite_decision"]
    require(ghost["campaign_seed"] == 50300, "ghost seed changed")
    require(
        ghost["arms"] == ["matched_no_impulse_control", "lateral_upright_impulse"],
        "ghost arms changed",
    )
    require(ghost["world_count"] == 2, "ghost world count changed")
    require(
        ghost["world_order"] == ["baseline_s50300", "push_s50300"],
        "ghost order changed",
    )
    require(ghost["behavioral_success_required"] is False, "ghost became behavior gate")
    require(ghost["route_validity_required"] is True, "ghost route validity removed")
    require(ghost["claim_authority"] is False, "ghost claim authority inflated")
    require(held["campaign_seeds"] == [50301, 50302, 50303], "held-out seeds changed")
    require(held["arm_count_per_seed"] == 2, "held-out arm count changed")
    require(held["world_count"] == 6, "held-out world count changed")
    require(
        held["world_order"]
        == [
            "baseline_s50301",
            "push_s50301",
            "baseline_s50302",
            "push_s50302",
            "baseline_s50303",
            "push_s50303",
        ],
        "held-out world order changed",
    )
    for key in (
        "same_seeded_initial_perturbation_within_each_pair",
        "all_worlds_run_regardless_of_intermediate_behavior",
        "failed_cell_deletion_replacement_averaging_or_threshold_change_forbidden",
        "exact_enumeration_adequacy_not_population_sampling",
    ):
        require(held[key] is True, f"held-out population safeguard removed: {key}")
    require(
        population["maximum_total_future_physical_world_count"] == 8,
        "future world budget changed",
    )
    require(
        population["reserved_before_implementation"] is True, "population not reserved"
    )
    require(
        population["outcomes_currently_unobserved"] is True, "outcome exposed in design"
    )
    receipt = loaded["r10a_design_freshness_receipt"]
    require(
        dotted(receipt, "reserved_identity_search.official_campaign_id")
        == "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-VALIDATION",
        "receipt official campaign mismatch",
    )
    require(
        dotted(receipt, "reserved_identity_search.development_campaign_id")
        == "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST",
        "receipt ghost campaign mismatch",
    )
    require(
        dotted(receipt, "reserved_identity_search.development_campaign_seed") == 50300,
        "receipt ghost seed mismatch",
    )
    require(
        dotted(receipt, "reserved_identity_search.official_campaign_seeds")
        == [50301, 50302, 50303],
        "receipt held-out seeds mismatch",
    )
    require(
        dotted(receipt, "selection_rule.outcome_based_selection") is False,
        "freshness receipt outcome selection",
    )


def validate_measurement(design: dict[str, Any]) -> None:
    measurement = design["trace_and_recovery_measurement_contract"]
    require(
        measurement["trace_role"] == "measurement_only_behavior_neutral_observer",
        "trace role changed",
    )
    required_fields = measurement["trace_row_required_fields"]
    require(
        isinstance(required_fields, list) and len(required_fields) == 10,
        "trace field population changed",
    )
    require(len(set(required_fields)) == len(required_fields), "trace fields duplicate")
    for required in (
        "semantic_step",
        "torso_position_world_m",
        "torso_orientation_xyzw",
        "torso_linear_velocity_world_m_s",
        "torso_angular_velocity_world_rad_s",
        "torso_tilt_rad",
        "torso_ground_contact",
        "ordered_foot_contacts_after",
        "validated_portable_command_count",
        "native_actuation_application_count",
    ):
        require(required in required_fields, f"missing trace field {required}")
    require(
        measurement["trace_required_for_every_sdk_step"] is True,
        "trace completeness relaxed",
    )
    for key in (
        "trace_may_change_controller_input",
        "trace_may_change_controller_output",
        "trace_may_change_physics_state",
        "trace_may_change_existing_walking_evaluator",
    ):
        require(measurement[key] is False, f"measurement observer became active: {key}")

    horizon = measurement["runtime_horizon"]
    require(
        horizon["source"] == "unchanged_r05e_contact_gated_full_world_horizon",
        "runtime horizon source changed",
    )
    require(
        horizon["minimum_sdk_semantic_step_count"] == 2152,
        "minimum runtime horizon changed",
    )
    require(
        horizon["maximum_sdk_semantic_step_count"] == 2872,
        "maximum runtime horizon changed",
    )
    require(
        horizon["maximum_sdk_semantic_step_count"]
        - horizon["minimum_sdk_semantic_step_count"]
        == horizon["maximum_additional_contact_gated_extension_steps"]
        == 720,
        "contact-gated extension changed",
    )
    require(
        horizon["trace_row_count_must_equal_executed_sdk_step_count"] is True,
        "trace-to-execution cardinality relaxed",
    )
    require(
        horizon["acceptance_outcome_based_early_termination_permitted"] is False,
        "outcome-based early termination introduced",
    )
    require(
        horizon["latest_recovery_window_half_open_semantic_step_interval"]
        == [900, 1260],
        "latest recovery interval changed",
    )
    require(
        horizon["minimum_sdk_semantic_step_count"] - 1260
        == horizon["minimum_remaining_steps_after_latest_recovery_window"]
        == 892,
        "latest recovery window no longer fits the full run",
    )

    ordinary = measurement["ordinary_walking_gate"]
    require(
        ordinary["source"] == "unchanged_r05e_production_walking_conjunction",
        "walking gate source changed",
    )
    require(
        all(
            ordinary[key] is True
            for key in (
                "required_for_every_baseline_world",
                "required_for_every_push_world",
                "all_raw_walking_receipts_must_be_true",
            )
        ),
        "ordinary walking conjunction relaxed",
    )

    pre = measurement["pre_push_upright_walking_eligibility"]
    require(
        pre["half_open_semantic_step_interval"] == [180, 540],
        "pre-push interval changed",
    )
    require(
        pre["duration_steps"] == 360 and pre["duration_s"] == 3.0,
        "pre-push duration changed",
    )
    require(pre["maximum_torso_tilt_rad"] == 0.6, "tilt bound changed")
    require(
        pre["maximum_torso_ground_contact_steps"] == 0, "torso-contact bound changed"
    )
    require(pre["minimum_airborne_dwell_steps"] == 3, "airborne dwell changed")
    expected_advance = (0.080 * 0.50) / 4.0
    require(
        abs(pre["minimum_task_frame_forward_advance_m"] - expected_advance) < 1.0e-15,
        "per-cycle advance derivation changed",
    )
    for key in (
        "each_limb_requires_airborne_then_recontact",
        "all_steps_require_eight_validated_portable_commands",
        "all_steps_require_eight_native_motor_applications",
    ):
        require(pre[key] is True, f"pre-push gate relaxed: {key}")

    effect = measurement["native_disturbance_effect"]
    require(
        effect["active_native_impulse_application_count"] == 1,
        "active impulse count changed",
    )
    require(
        effect["baseline_native_impulse_application_count"] == 0,
        "baseline impulse count changed",
    )
    require(effect["active_receipt_effect_sampled"] is True, "effect sampling removed")
    require(
        effect["minimum_next_step_velocity_delta_magnitude_m_s"] == 0.0001,
        "effect floor changed",
    )
    require(
        effect["paired_lateral_velocity_jump_difference_must_be_positive"] is True,
        "causal sign check removed",
    )
    require(
        effect["paired_comparison_uses_same_seed_and_semantic_step"] is True,
        "pair identity relaxed",
    )
    require(
        effect["paired_difference_is_causal_path_confirmation_not_effect_equivalence"]
        is True,
        "effect claim inflated",
    )

    recovery = measurement["bounded_reentry_search"]
    require(
        recovery["first_candidate_reentry_semantic_step"] == 541,
        "reentry start changed",
    )
    require(
        recovery["last_candidate_reentry_semantic_step"] == 900,
        "reentry deadline changed",
    )
    require(
        recovery["last_candidate_reentry_semantic_step"] - 540 == 360,
        "reentry latency derivation changed",
    )
    require(recovery["maximum_reentry_latency_steps"] == 360, "reentry latency changed")
    require(recovery["maximum_reentry_latency_s"] == 3.0, "reentry seconds changed")
    require(
        recovery["candidate_recovery_window_duration_steps"] == 360,
        "recovery window changed",
    )
    require(
        recovery["candidate_recovery_window_duration_s"] == 3.0,
        "recovery duration changed",
    )
    require(
        recovery["first_valid_window_selected"] is True, "first-valid selection removed"
    )
    require(
        recovery[
            "window_requirements_identical_to_pre_push_upright_walking_eligibility"
        ]
        is True,
        "recovery requirements changed",
    )
    require(
        recovery["push_may_remain_inside_the_safe_envelope"] is True,
        "forced departure introduced",
    )
    require(
        recovery["forced_fall_or_forced_threshold_departure_required"] is False,
        "forced fall introduced",
    )

    baseline = measurement["matched_baseline_control"]
    require(
        baseline["post_marker_half_open_semantic_step_interval"] == [541, 901],
        "baseline post-marker interval changed",
    )
    require(baseline["duration_steps"] == 360, "baseline control duration changed")
    require(
        baseline["requirements_identical_to_pre_push_upright_walking_eligibility"]
        is True,
        "baseline control relaxed",
    )
    meanings = measurement["recovery_does_not_mean"]
    for excluded in (
        "fall_recovery",
        "prone_to_standing",
        "self_righting",
        "active_force_estimation",
        "force_conditioned_control",
        "a_recovery_mode_switch",
        "terminal_four_contact_coincidence_only",
    ):
        require(excluded in meanings, f"missing recovery exclusion: {excluded}")


def validate_decision_and_limits(design: dict[str, Any]) -> None:
    decision = design["decision_contract"]
    conditions = decision["held_out_result_valid_only_if"]
    require(
        isinstance(conditions, list) and len(conditions) == 11,
        "held-out conjunction changed",
    )
    require(
        decision["acceptance_rule"]
        == "valid complete positive only if every conjunction is true for every declared world and pair",
        "acceptance rule changed",
    )
    for key in (
        "pooling_across_seeds_permitted",
        "pooling_across_hosts_permitted",
        "mean_success_rate_permitted",
        "same_identity_rerun_permitted",
        "post_result_threshold_or_interpretation_change_permitted",
    ):
        require(decision[key] is False, f"decision safeguard relaxed: {key}")

    sequence = design["prospective_sequence"]
    require(
        isinstance(sequence["ordered_steps"], list)
        and len(sequence["ordered_steps"]) == 10,
        "prospective sequence changed",
    )
    require(
        sequence["production_route_ghost_required_before_heldout_authorization"]
        is True,
        "ghost prerequisite removed",
    )
    require(
        sequence["ghost_success_means_route_execution_valid_not_behavior_positive"]
        is True,
        "ghost meaning inflated",
    )
    require(
        sequence["physical_execution_authorized_by_this_design"] is False,
        "design authorized physics",
    )
    require(
        sequence["next_legal_work"]
        == "zero_world_r10b_implementation_and_qualification",
        "next work changed",
    )

    limits = design["immutability_and_limits"]
    for key in (
        "bw6n_rerun_count",
        "bw32n_rerun_count",
        "r05e_rerun_count",
        "new_physical_process_launch_count",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(
            limits[key] == 0 and not isinstance(limits[key], bool),
            f"nonzero execution count: {key}",
        )
    for key in (
        "physical_outcome_exposed",
        "controller_or_threshold_mutation",
        "historical_result_reinterpretation",
    ):
        require(limits[key] is False, f"immutability boundary changed: {key}")

    claims = design["claim_boundary"]
    require(claims["design_complete"] is True, "design not closed")
    for key, value in claims.items():
        if key != "design_complete":
            require(value is False, f"premature claim or completion: {key}")
    selected = design["decision"]
    require(
        selected["selected"]
        == "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-IMPLEMENTATION",
        "wrong successor selected",
    )
    require(selected["q_sdk_r10a_closed"] is True, "R10A not closed")
    require(
        selected["q_sdk_r10b_zero_world_implementation_authorized"] is True,
        "zero-world successor not authorized",
    )
    require(
        selected["q_sdk_r10b_physical_execution_authorized"] is False,
        "successor physics authorized early",
    )
    require(selected["scores_unchanged"] is True, "design changed score")


def validate_design(
    design: dict[str, Any],
    *,
    verify_bindings: bool,
    preloaded: dict[str, dict[str, Any]] | None = None,
) -> dict[str, dict[str, Any]]:
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10a_bounded_upright_push_recovery_successor_design_v1",
        "schema version mismatch",
    )
    require(design.get("gate_id") == "QSDK-R10A", "gate mismatch")
    require(
        design.get("status")
        == "closed_zero_world_bounded_upright_push_recovery_successor_selected_implementation_required_physics_blocked",
        "status mismatch",
    )
    require(
        design.get("authored_parent_commit") == PARENT_COMMIT,
        "authored parent mismatch",
    )
    ledger = design.get("ledger_scope")
    require(
        ledger
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "closed_zero_world_retained_evidence_diagnosis_and_successor_design",
            "question_class": "development",
        },
        "ledger scope mismatch",
    )
    require(design.get("question_class") == "development", "question class mismatch")
    for key in (
        "physical_question_declared",
        "finite_decision_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        require(design.get(key) is False, f"design declared forbidden question: {key}")

    authority_declarations = design.get("bound_authorities")
    require(
        isinstance(authority_declarations, list), "bound authority declarations missing"
    )
    require(
        len(authority_declarations) == len(EXPECTED_ROLES),
        "bound authority declaration count mismatch",
    )
    declared_roles = [
        entry.get("role") for entry in authority_declarations if isinstance(entry, dict)
    ]
    require(
        len(declared_roles) == len(authority_declarations)
        and set(declared_roles) == EXPECTED_ROLES
        and len(set(declared_roles)) == len(declared_roles),
        "bound authority declaration role set mismatch",
    )

    loaded = validate_bindings(design) if verify_bindings else preloaded
    require(isinstance(loaded, dict), "preloaded authorities missing")
    validate_historical_diagnosis(design, loaded)
    validate_scope_and_profile(design)
    validate_population(design, loaded)
    validate_measurement(design)
    validate_decision_and_limits(design)
    return loaded


def mutation_controls(design: dict[str, Any], loaded: dict[str, dict[str, Any]]) -> int:
    mutations = [
        ("schema", lambda d: d.__setitem__("schema_version", "mutated")),
        (
            "engine scope",
            lambda d: d["ledger_scope"].__setitem__("engine_scope", "three_engine"),
        ),
        (
            "force aware",
            lambda d: d["selected_successor_scope"].__setitem__(
                "force_aware_recovery_added", True
            ),
        ),
        (
            "behavior change",
            lambda d: d["selected_successor_scope"].__setitem__(
                "behavior_change_selected", True
            ),
        ),
        (
            "push magnitude",
            lambda d: d["prospective_challenge_profile"].__setitem__(
                "impulse_magnitude_n_s", 0.30
            ),
        ),
        (
            "push step",
            lambda d: d["prospective_challenge_profile"].__setitem__(
                "application_semantic_step_from_sdk_start", 600
            ),
        ),
        (
            "held-out seed",
            lambda d: d["prospective_population"][
                "held_out_finite_decision"
            ].__setitem__("campaign_seeds", [50301, 50302, 50304]),
        ),
        (
            "world removal",
            lambda d: d["prospective_population"]["held_out_finite_decision"][
                "world_order"
            ].pop(),
        ),
        (
            "pre-push duration",
            lambda d: d["trace_and_recovery_measurement_contract"][
                "pre_push_upright_walking_eligibility"
            ].__setitem__("duration_steps", 120),
        ),
        (
            "runtime horizon",
            lambda d: d["trace_and_recovery_measurement_contract"][
                "runtime_horizon"
            ].__setitem__("minimum_sdk_semantic_step_count", 1259),
        ),
        (
            "tilt relaxation",
            lambda d: d["trace_and_recovery_measurement_contract"][
                "pre_push_upright_walking_eligibility"
            ].__setitem__("maximum_torso_tilt_rad", 0.8),
        ),
        (
            "reentry extension",
            lambda d: d["trace_and_recovery_measurement_contract"][
                "bounded_reentry_search"
            ].__setitem__("maximum_reentry_latency_steps", 720),
        ),
        (
            "effect floor deletion",
            lambda d: d["trace_and_recovery_measurement_contract"][
                "native_disturbance_effect"
            ].__setitem__("minimum_next_step_velocity_delta_magnitude_m_s", 0.0),
        ),
        (
            "walking evaluator",
            lambda d: d["trace_and_recovery_measurement_contract"][
                "ordinary_walking_gate"
            ].__setitem__("source", "new_gate"),
        ),
        (
            "ghost behavior",
            lambda d: d["prospective_population"][
                "development_route_ghost"
            ].__setitem__("behavioral_success_required", True),
        ),
        (
            "physical authorization",
            lambda d: d["prospective_sequence"].__setitem__(
                "physical_execution_authorized_by_this_design", True
            ),
        ),
        (
            "claim promotion",
            lambda d: d["claim_boundary"].__setitem__("external_push_recovery", True),
        ),
        (
            "solver count",
            lambda d: d["immutability_and_limits"].__setitem__("solver_step_count", 1),
        ),
        ("authority removal", lambda d: d["bound_authorities"].pop()),
    ]
    passed = 0
    for label, mutate in mutations:
        candidate = copy.deepcopy(design)
        mutate(candidate)
        try:
            validate_design(candidate, verify_bindings=False, preloaded=loaded)
        except AuditFailure:
            passed += 1
        else:
            raise AuditFailure(f"mutation control was accepted: {label}")
    return passed


def main() -> int:
    try:
        raw = DESIGN_PATH.read_bytes()
        require(len(raw) == EXPECTED_DESIGN_BYTES, "design byte length mismatch")
        require(sha256_hex(raw) == EXPECTED_DESIGN_SHA256, "design SHA-256 mismatch")
        design = read_json(raw, "R10A design")
        loaded = validate_design(design, verify_bindings=True)
        controls = mutation_controls(design, loaded)
        print(
            "QSDK_R10A_BOUNDED_UPRIGHT_PUSH_RECOVERY_SUCCESSOR_DESIGN_PASS "
            f"bound_authorities={len(loaded)} historical_campaign_reruns=0 "
            "ghost_world_budget=2 heldout_world_budget=6 total_future_world_budget=8 "
            f"mutation_controls={controls} model_construction_count=0 "
            "world_attempt_count=0 world_build_count=0 native_readback_count=0 "
            "solver_step_count=0 physical_execution_authorized=False"
        )
        return 0
    except (AuditFailure, KeyError, IndexError, TypeError, OSError, ValueError) as exc:
        print(
            f"QSDK_R10A_BOUNDED_UPRIGHT_PUSH_RECOVERY_SUCCESSOR_DESIGN_FAIL {exc}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
