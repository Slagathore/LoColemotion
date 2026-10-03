#!/usr/bin/env python3
"""Zero-world declaration and mutation audit for QSDK-R24D10."""

from __future__ import annotations

import copy
import hashlib
import json
import math
import pathlib
import subprocess
import sys
from typing import Any, Callable


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
CONTRACT_PATH = REPO_ROOT / (
    "sdk/recovery/"
    "r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "characterization_preregistration_v1.json"
)
SCHEMA = (
    "sporespore_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "characterization_preregistration_v1"
)
GATE_ID = "QSDK-R24D10"
EXPECTED_CELLS = [
    "drive_positive",
    "drive_negative",
    "brake_positive",
    "brake_negative",
    "disabled_positive",
    "disabled_negative",
    "limit_positive",
    "limit_negative",
    "sleep_stale",
]
EXPECTED_INITIAL_RATES = {
    "drive_positive": 0.0,
    "drive_negative": 0.0,
    "brake_positive": 0.4,
    "brake_negative": -0.4,
    "disabled_positive": 0.4,
    "disabled_negative": -0.4,
    "limit_positive": 0.0,
    "limit_negative": 0.0,
    "sleep_stale": 0.0,
}
EXPECTED_INITIAL_RATE_PROJECTIONS = {
    "drive_positive": 0.0,
    "drive_negative": 0.0,
    "brake_positive": 0.4000000059604645,
    "brake_negative": -0.4000000059604645,
    "disabled_positive": 0.4000000059604645,
    "disabled_negative": -0.4000000059604645,
    "limit_positive": 0.0,
    "limit_negative": 0.0,
    "sleep_stale": 0.0,
}
EXPECTED_RETAINED_STEPS = {
    "drive_positive": 4,
    "drive_negative": 4,
    "brake_positive": 4,
    "brake_negative": 4,
    "disabled_positive": 4,
    "disabled_negative": 4,
    "limit_positive": 20,
    "limit_negative": 20,
    "sleep_stale": 4,
}
EXPECTED_NEW_CONTROLS = [
    "pre_sample_frame_count_one_rejected",
    "first_retained_token_two_rejected",
    "last_retained_token_twenty_one_rejected",
    "retained_token_gap_rejected",
    "retained_token_duplicate_rejected",
    "worker_literal_step_count_disagreement_rejected",
    "observed_token_count_disagreement_rejected",
    "first_braking_pre_rate_consumed_to_zero_rejected",
    "first_disabled_pre_rate_sign_shift_rejected",
    "limit_cell_token_population_disagreement_rejected",
    "schedule_start_boundary_count_mutation_rejected",
    "extra_unretained_post_activation_step_claim_rejected",
]


class AuditError(ValueError):
    """Stable fail-closed declaration rejection."""


def fail(code: str) -> None:
    raise AuditError(code)


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"duplicate_json_key:{key}")
        result[key] = value
    return result


def reject_constant(value: str) -> Any:
    fail(f"non_finite_json_constant:{value}")


def strict_loads(text: str) -> dict[str, Any]:
    try:
        value = json.loads(
            text,
            object_pairs_hook=reject_duplicate_keys,
            parse_constant=reject_constant,
        )
    except AuditError:
        raise
    except (json.JSONDecodeError, TypeError, ValueError) as exc:
        raise AuditError(f"invalid_json:{exc}") from exc
    if not isinstance(value, dict):
        fail("contract_not_object")
    return value


def object_value(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(code)
    return value


def list_value(value: Any, code: str) -> list[Any]:
    if not isinstance(value, list):
        fail(code)
    return value


def exact_keys(value: dict[str, Any], expected: set[str], code: str) -> None:
    if set(value) != expected:
        fail(code)


def exact_bool(value: Any, expected: bool, code: str) -> None:
    if not isinstance(value, bool) or value is not expected:
        fail(code)


def exact_int(value: Any, expected: int, code: str) -> None:
    if isinstance(value, bool) or not isinstance(value, int) or value != expected:
        fail(code)


def exact_number(value: Any, expected: float, code: str) -> None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        fail(code)
    observed = float(value)
    if not math.isfinite(observed) or observed != expected:
        fail(code)


def raw_sha256(path: pathlib.Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def git(*arguments: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if completed.returncode != 0:
        fail(f"git_failed:{' '.join(arguments)}:{completed.stderr.strip()}")
    return completed.stdout.strip()


def validate_source_binding(
    declaration: dict[str, Any],
    path_key: str,
    hash_key: str,
    code: str,
) -> pathlib.Path:
    relative = declaration.get(path_key)
    expected_hash = declaration.get(hash_key)
    if not isinstance(relative, str) or not relative:
        fail(f"{code}_path")
    if not isinstance(expected_hash, str) or not expected_hash.startswith("sha256:"):
        fail(f"{code}_hash_format")
    path = REPO_ROOT / relative
    if not path.is_file() or raw_sha256(path) != expected_hash:
        fail(f"{code}_identity")
    return path


def validate(contract: dict[str, Any]) -> None:
    exact_keys(
        contract,
        {
            "schema_version",
            "gate_id",
            "work_id",
            "status",
            "question_class",
            "question",
            "purpose",
            "authorization_source",
            "non_reuse_and_non_reinterpretation",
            "engine_and_runtime_freeze",
            "prospective_source",
            "fixture_freeze",
            "exact_step_schedule",
            "token_derived_execution_validity",
            "evaluation_contract",
            "threshold_margin_cohort_and_population_adequacy",
            "negative_controls",
            "implementation_state_at_declaration",
            "physical_authorization",
            "claims",
        },
        "top_level_field_set",
    )
    if contract.get("schema_version") != SCHEMA:
        fail("schema_version")
    if contract.get("gate_id") != GATE_ID:
        fail("gate_id")
    if contract.get("question_class") != "development":
        fail("question_class")
    if contract.get("status") != (
        "prospectively_declared_exact_step_development_successor_"
        "implementation_and_complete_zero_world_gate_pending_"
        "physical_execution_forbidden"
    ):
        fail("status")

    authorization = object_value(contract.get("authorization_source"), "authorization")
    if authorization.get("gate_id") != "QSDK-R24D9":
        fail("authorization_gate")
    if authorization.get("closure_id") != "QSDK-R24D9-PH1-CLOSURE":
        fail("authorization_closure")
    exact_int(authorization.get("observed_exact_jolt_space_step_count"), 21, "observed_steps")
    exact_int(authorization.get("declared_maximum_space_step_count"), 20, "declared_steps")
    exact_int(
        authorization.get("unretained_post_activation_solver_step_count"),
        1,
        "unretained_steps",
    )
    exact_bool(
        authorization.get("declared_initial_rate_state_preserved_until_first_retained_pre_rate"),
        False,
        "r24d9_initial_state_result",
    )
    for key, expected in {
        "same_source_rerun_forbidden": True,
        "distinct_exact_step_development_successor_required": True,
        "r24d10_declaration_authorized": True,
        "r24d10_physical_execution_authorized": False,
    }.items():
        exact_bool(authorization.get(key), expected, f"authorization_{key}")
    closure_path = validate_source_binding(
        authorization,
        "closure_path",
        "closure_raw_sha256",
        "authorization_closure",
    )
    audit_path = validate_source_binding(
        authorization,
        "closure_audit_path",
        "closure_audit_raw_sha256",
        "authorization_audit",
    )
    publication_commit = authorization.get("closure_publication_commit")
    if not isinstance(publication_commit, str) or len(publication_commit) != 40:
        fail("authorization_publication_commit")
    for path in (closure_path, audit_path):
        relative = path.relative_to(REPO_ROOT).as_posix()
        current_blob = git("hash-object", relative)
        published_blob = git("rev-parse", f"{publication_commit}:{relative}")
        if current_blob != published_blob:
            fail(f"authorization_publication_blob:{relative}")
    closure = strict_loads(closure_path.read_text(encoding="utf-8"))
    next_boundary = object_value(closure.get("next_boundary"), "closure_next_boundary")
    if (
        next_boundary.get("gate_id") != GATE_ID
        or next_boundary.get("question_class") != "development"
        or next_boundary.get("physical_world_authorized_now") is not False
    ):
        fail("closure_does_not_authorize_declaration_only")

    non_reuse = object_value(
        contract.get("non_reuse_and_non_reinterpretation"),
        "non_reuse",
    )
    for path_key, hash_key, code in (
        ("r24d9_preregistration_path", "r24d9_preregistration_raw_sha256", "r24d9_prereg"),
        ("r24d9_evaluator_path", "r24d9_evaluator_raw_sha256", "r24d9_evaluator"),
        ("r24d9_worker_path", "r24d9_worker_raw_sha256", "r24d9_worker"),
    ):
        validate_source_binding(non_reuse, path_key, hash_key, code)
    for key, expected in {
        "r24d9_result_reinterpreted": False,
        "r24d9_reported_numerical_values_accepted": False,
        "r24d9_raw_numerical_values_used_to_select_thresholds": False,
        "r24d9_same_source_repair_or_rerun_claimed": False,
        "r24d9_numerical_kernel_may_be_imported_only_as_content_addressed_source_dependency": True,
        "scientifically_distinct_source_identity_required": True,
        "complete_new_zero_world_gate_required": True,
    }.items():
        exact_bool(non_reuse.get(key), expected, f"non_reuse_{key}")

    runtime = object_value(contract.get("engine_and_runtime_freeze"), "runtime")
    expected_runtime_values = {
        "runtime_profile_id": "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2",
        "physics_engine": "Jolt Physics",
        "godot_source_commit": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88",
        "combined_patch_raw_sha256": "sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c",
        "telemetry_schema": "sporespore.godot_jolt_hinge_motor_telemetry.v2",
    }
    for key, expected in expected_runtime_values.items():
        if runtime.get(key) != expected:
            fail(f"runtime_{key}")
    for key, expected in {
        "patched_file_count": 10,
        "physics_ticks_per_second": 120,
        "solver_velocity_steps": 20,
        "solver_position_steps": 7,
        "telemetry_field_count": 15,
        "space_step_sequence_initial_value": 0,
        "space_step_sequence_increment_per_jolt_space_step": 1,
    }.items():
        exact_int(runtime.get(key), expected, f"runtime_{key}")
    for key, expected in {
        "runtime_substitution_allowed": False,
        "solver_setting_substitution_allowed": False,
        "r24d10_independent_cold_build_required": True,
    }.items():
        exact_bool(runtime.get(key), expected, f"runtime_{key}")

    fixture = object_value(contract.get("fixture_freeze"), "fixture")
    if fixture.get("fixture_id") != "QSDK.R24D10.godot_jolt_exact_step_numerical_telemetry.v1":
        fail("fixture_id")
    exact_bool(
        fixture.get("r24d9_fixture_geometry_and_cell_parameters_changed"),
        False,
        "fixture_changed",
    )
    for key, expected in {
        "world_count": 1,
        "isolated_cell_count": 9,
        "maximum_physics_step_count": 20,
        "retained_sample_count": 68,
        "pre_activation_initial_angular_velocity_write_count": 4,
        "contact_count": 0,
        "direct_force_write_count": 0,
        "direct_torque_write_count": 0,
        "direct_impulse_write_count": 0,
        "post_activation_transform_write_count": 0,
    }.items():
        exact_int(fixture.get(key), expected, f"fixture_{key}")
    if fixture.get("cell_ids_in_order") != EXPECTED_CELLS:
        fail("fixture_cell_order")
    if fixture.get("declared_initial_canonical_rate_by_cell_rad_s") != EXPECTED_INITIAL_RATES:
        fail("fixture_initial_rates")
    if (
        fixture.get("declared_initial_canonical_rate_real_t_projection_by_cell_rad_s")
        != EXPECTED_INITIAL_RATE_PROJECTIONS
    ):
        fail("fixture_initial_rate_projections")
    if fixture.get("retained_step_count_by_cell") != EXPECTED_RETAINED_STEPS:
        fail("fixture_retained_steps")

    schedule = object_value(contract.get("exact_step_schedule"), "schedule")
    if schedule.get("schedule_id") != "r24d10_inactive_arm_then_token_bound_twenty_step_schedule_v1":
        fail("schedule_id")
    for key, expected in {
        "schedule_start_physics_frame_boundary_count": 1,
        "pre_sample_physics_frame_count": 0,
        "first_retained_space_step_sequence": 1,
        "last_retained_space_step_sequence": 20,
        "retained_awake_space_step_token_count": 20,
        "extra_unretained_post_activation_step_count": 0,
    }.items():
        exact_int(schedule.get(key), expected, f"schedule_{key}")
    for key, expected in {
        "physics_server_disabled_before_world_build": True,
        "physics_server_disabled_during_fixture_activation": True,
        "first_pre_rate_captured_before_physics_server_enable": True,
        "schedule_start_boundary_enables_server_for_same_boundary_step": True,
        "token_gaps_allowed": False,
        "token_duplicates_across_successive_awake_samples_allowed": False,
        "token_shift_allowed": False,
        "terminal_boundary_reads_step_twenty_before_step_twenty_one": True,
        "terminal_boundary_disables_physics_server_before_step_twenty_one": True,
        "worker_authored_literal_step_count_is_authoritative": False,
        "first_retained_pre_rate_must_equal_declared_initial_real_t_projection_for_every_cell": True,
        "outcome_dependent_early_stop_allowed": False,
    }.items():
        exact_bool(schedule.get(key), expected, f"schedule_{key}")
    if schedule.get("retained_awake_space_step_tokens_exactly") != "1..20":
        fail("schedule_token_population")
    if schedule.get("reported_physics_step_count_source") != (
        "max_retained_awake_read_space_step_sequence_minus_zero_initialized_space_step_sequence"
    ):
        fail("schedule_step_count_source")
    if schedule.get("nonzero_initial_rate_cell_ids") != EXPECTED_CELLS[2:6]:
        fail("schedule_nonzero_rate_cells")
    exact_number(
        schedule.get("nonzero_initial_rate_tolerance_rad_s"),
        0.0,
        "schedule_initial_rate_tolerance",
    )
    if schedule.get("sleep_stale_later_read_tokens") != [2, 3, 4]:
        fail("schedule_sleep_read_tokens")

    token_validity = object_value(
        contract.get("token_derived_execution_validity"),
        "token_validity",
    )
    if token_validity.get("global_retained_awake_read_token_population_required") != "1..20":
        fail("token_validity_population")
    exact_int(token_validity.get("derived_physics_step_count_required"), 20, "derived_steps")
    exact_int(
        token_validity.get("declared_maximum_physics_step_count_required"),
        20,
        "declared_maximum_steps",
    )
    for key in (
        "zero_initialized_space_step_sequence_required",
        "derived_and_declared_step_counts_must_match",
        "first_retained_token_must_equal_one",
        "last_retained_token_must_equal_twenty",
        "first_retained_pre_rates_must_match_declared_initial_real_t_projections",
        "extra_native_step_invalidates_execution",
        "shifted_initial_state_invalidates_execution",
        "validity_failure_is_not_a_numerical_telemetry_result",
    ):
        exact_bool(token_validity.get(key), True, f"token_validity_{key}")

    adequacy = object_value(
        contract.get("threshold_margin_cohort_and_population_adequacy"),
        "adequacy",
    )
    for key, expected in {
        "empirical_acceptance_threshold_count": 0,
        "initial_rate_match_tolerance_count": 0,
        "superiority_margin_count": 0,
        "equivalence_or_non_inferiority_margin_count": 0,
        "held_out_validation_cohort_count": 0,
        "development_runtime_pair_count": 1,
        "development_world_count": 1,
        "development_fixture_cell_count": 9,
        "population_claim_count": 0,
        "source_derived_exact_step_invariant_count": 7,
    }.items():
        exact_int(adequacy.get(key), expected, f"adequacy_{key}")
    if not isinstance(adequacy.get("adequacy_argument"), str) or len(adequacy["adequacy_argument"]) < 500:
        fail("adequacy_argument")

    controls = object_value(contract.get("negative_controls"), "negative_controls")
    exact_int(
        controls.get("inherited_r24d9_evaluator_negative_control_count"),
        46,
        "inherited_negative_count",
    )
    exact_int(
        controls.get("inherited_r24d9_accepted_adverse_finite_outcome_count"),
        3,
        "inherited_adverse_count",
    )
    exact_int(
        controls.get("new_exact_step_negative_control_count"),
        len(EXPECTED_NEW_CONTROLS),
        "new_negative_count",
    )
    if controls.get("new_required_rejections") != EXPECTED_NEW_CONTROLS:
        fail("new_negative_control_population")

    implementation = object_value(
        contract.get("implementation_state_at_declaration"),
        "implementation_state",
    )
    exact_bool(implementation.get("preregistration_written"), True, "prereg_written")
    exact_bool(implementation.get("declaration_audit_written"), True, "audit_written")
    for key in (
        "rig_implemented",
        "worker_implemented",
        "evaluator_implemented",
        "validation_manifest_written",
        "freeze_audit_written",
        "zero_world_supervisor_implemented",
        "physical_supervisor_implemented",
        "complete_zero_world_gate_implemented",
        "complete_zero_world_gate_passed",
        "physical_world_opened",
    ):
        exact_bool(implementation.get(key), False, f"implementation_{key}")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact_int(implementation.get(key), 0, f"implementation_{key}")

    physical = object_value(contract.get("physical_authorization"), "physical")
    exact_bool(physical.get("permitted_now"), False, "physical_permitted")
    exact_int(physical.get("same_source_physical_attempt_limit"), 1, "physical_attempt_limit")
    exact_bool(
        physical.get("same_source_physical_rerun_allowed"),
        False,
        "physical_rerun",
    )
    exact_bool(physical.get("physical_result_exists"), False, "physical_result")
    requirements = list_value(physical.get("required_before_permission"), "physical_requirements")
    if len(requirements) != 12 or len(set(requirements)) != 12:
        fail("physical_requirement_population")

    claims = object_value(contract.get("claims"), "claims")
    for key, value in claims.items():
        exact_bool(
            value,
            key == "prospective_development_question_declared",
            f"claim_{key}",
        )


def set_path(value: dict[str, Any], path: tuple[str, ...], replacement: Any) -> None:
    cursor: Any = value
    for key in path[:-1]:
        cursor = cursor[key]
    cursor[path[-1]] = replacement


def mutation(
    path: tuple[str, ...],
    replacement: Any,
) -> Callable[[dict[str, Any]], None]:
    return lambda value: set_path(value, path, replacement)


def run_mutation_controls(contract: dict[str, Any], raw_text: str) -> int:
    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("question_class", mutation(("question_class",), "finite_decision")),
        ("closure_hash", mutation(("authorization_source", "closure_raw_sha256"), "sha256:" + "0" * 64)),
        ("observed_r24d9_steps", mutation(("authorization_source", "observed_exact_jolt_space_step_count"), 20)),
        ("same_source_rerun", mutation(("authorization_source", "same_source_rerun_forbidden"), False)),
        ("fixture_changed", mutation(("fixture_freeze", "r24d9_fixture_geometry_and_cell_parameters_changed"), True)),
        ("maximum_steps", mutation(("fixture_freeze", "maximum_physics_step_count"), 21)),
        ("brake_initial_rate", mutation(("fixture_freeze", "declared_initial_canonical_rate_by_cell_rad_s", "brake_positive"), 0.0)),
        ("limit_retained_steps", mutation(("fixture_freeze", "retained_step_count_by_cell", "limit_positive"), 19)),
        ("server_disabled", mutation(("exact_step_schedule", "physics_server_disabled_before_world_build"), False)),
        ("pre_sample", mutation(("exact_step_schedule", "pre_sample_physics_frame_count"), 1)),
        ("first_token", mutation(("exact_step_schedule", "first_retained_space_step_sequence"), 2)),
        ("last_token", mutation(("exact_step_schedule", "last_retained_space_step_sequence"), 21)),
        ("token_population", mutation(("exact_step_schedule", "retained_awake_space_step_tokens_exactly"), "2..21")),
        ("token_count", mutation(("exact_step_schedule", "retained_awake_space_step_token_count"), 19)),
        ("literal_authority", mutation(("exact_step_schedule", "worker_authored_literal_step_count_is_authoritative"), True)),
        ("terminal_disable", mutation(("exact_step_schedule", "terminal_boundary_disables_physics_server_before_step_twenty_one"), False)),
        ("initial_rate_tolerance", mutation(("exact_step_schedule", "nonzero_initial_rate_tolerance_rad_s"), 1.0e-6)),
        ("derived_step_count", mutation(("token_derived_execution_validity", "derived_physics_step_count_required"), 21)),
        ("extra_step_validity", mutation(("token_derived_execution_validity", "extra_native_step_invalidates_execution"), False)),
        ("empirical_threshold", mutation(("threshold_margin_cohort_and_population_adequacy", "empirical_acceptance_threshold_count"), 1)),
        ("control_count", mutation(("negative_controls", "new_exact_step_negative_control_count"), 11)),
        ("world_count", mutation(("implementation_state_at_declaration", "world_attempt_count"), 1)),
        ("physical_permission", mutation(("physical_authorization", "permitted_now"), True)),
        ("schedule_claim", mutation(("claims", "exact_step_schedule_implemented"), True)),
        ("prone_claim", mutation(("claims", "prone_to_standing_world_opened"), True)),
    ]
    rejected = 0
    for name, apply in mutations:
        candidate = copy.deepcopy(contract)
        apply(candidate)
        try:
            validate(candidate)
        except AuditError:
            rejected += 1
            continue
        fail(f"mutation_accepted:{name}")

    duplicate_text = raw_text.replace(
        '"gate_id": "QSDK-R24D10",',
        '"gate_id": "QSDK-R24D10",\n  "gate_id": "QSDK-R24D10",',
        1,
    )
    try:
        strict_loads(duplicate_text)
    except AuditError as exc:
        if not str(exc).startswith("duplicate_json_key:"):
            raise
        rejected += 1
    else:
        fail("mutation_accepted:duplicate_json_key")
    return rejected


def main() -> int:
    try:
        raw_text = CONTRACT_PATH.read_text(encoding="utf-8")
        contract = strict_loads(raw_text)
        validate(contract)
        rejected = run_mutation_controls(contract, raw_text)
        print(
            "QSDK_R24D10_DECLARATION_AUDIT_PASS "
            f"mutations={rejected} inherited_evaluator_controls=46 "
            "new_exact_step_controls=12 worlds=0 builds=0 solver_steps=0 "
            "physical_authority=false"
        )
        return 0
    except (AuditError, OSError) as exc:
        print(f"QSDK_R24D10_DECLARATION_AUDIT_FAILURE {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
