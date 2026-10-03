#!/usr/bin/env python3
"""Audit the prospective QSDK-R10B-L3 trace-validation repair design."""

from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any, Callable, Iterable


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10b_l3_serialization_stable_trace_validation_successor_design_v1.json"
)
L2_CLOSURE_AUDIT_PATH = (
    ROOT / "sdk/conformance/qsdk_r10b_l2_development_route_ghost_physical_invalid.py"
)
AUTHORED_PARENT_COMMIT = "4c9aec430173eb040df70b72bc241984584e911b"
PASS_MARKER = "QSDK_R10B_L3_SUCCESSOR_DESIGN_PASS "
L2_PASS_MARKER = "QSDK_R10B_L2_PHYSICAL_INVALID_CLOSURE_PASS "
FLOAT64_EPSILON = math.nextafter(1.0, math.inf) - 1.0
OPERATION_EVENT_BUDGET = 32

EXPECTED_BINDING_ROLES = [
    "consumed_l2_physical_invalid_closure",
    "consumed_l2_physical_invalid_closure_audit",
    "l2_retained_trace_zero_world_diagnosis",
    "l2_trace_evaluator_source",
    "l2_projection_helper_source",
]

DERIVED_NUMERIC_FIELDS = [
    "source_norm_squared",
    "source_norm",
    "source_norm_squared_delta",
    "source_norm_delta",
    "orientation_xyzw",
    "projected_norm_squared",
    "projected_norm",
    "projected_norm_squared_delta",
    "projected_norm_delta",
]


class DesignFailure(RuntimeError):
    """The prospective L3 design violated its zero-world contract."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise DesignFailure(code)


def sha256(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def read_json_bytes(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise DesignFailure(f"{label}_INVALID_JSON:{exc}") from exc
    require(isinstance(value, dict), f"{label}_ROOT_NOT_OBJECT")
    return value


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        return read_json_bytes(path.read_bytes(), label)
    except OSError as exc:
        raise DesignFailure(f"{label}_UNREADABLE:{exc}") from exc


def git(arguments: Iterable[str], *, binary: bool = False) -> bytes | str:
    completed = subprocess.run(
        ("git", "-C", ROOT, *arguments),
        check=False,
        capture_output=True,
        text=not binary,
        encoding=None if binary else "utf-8",
        errors=None if binary else "strict",
    )
    require(completed.returncode == 0, f"GIT_FAILED:{' '.join(arguments)}")
    return completed.stdout if binary else completed.stdout.strip()


def validate_repository_identity() -> None:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "WRONG_SCRIPT_ROOT")
    require(
        Path(str(git(("rev-parse", "--show-toplevel")))).resolve()
        == EXPECTED_ROOT.resolve(),
        "WRONG_GIT_ROOT",
    )
    require(
        str(git(("remote", "get-url", "origin"))) == EXPECTED_REMOTE,
        "WRONG_REMOTE",
    )


def validate_binding(binding: dict[str, Any]) -> dict[str, Any]:
    role = str(binding.get("role", ""))
    relative = str(binding.get("path", ""))
    source_commit = str(binding.get("source_commit", ""))
    require(role in EXPECTED_BINDING_ROLES, f"UNKNOWN_BINDING_ROLE:{role}")
    require(relative and source_commit, f"BINDING_IDENTITY_MISSING:{role}")
    raw = bytes(git(("show", f"{source_commit}:{relative}"), binary=True))
    require(
        binding.get("git_blob_oid")
        == str(git(("rev-parse", f"{source_commit}:{relative}")))
        and binding.get("byte_length") == len(raw)
        and binding.get("raw_sha256") == sha256(raw),
        f"BINDING_DRIFT:{role}",
    )
    return read_json_bytes(raw, role) if relative.endswith(".json") else {"raw": raw}


def validate_bindings(design: dict[str, Any]) -> dict[str, dict[str, Any]]:
    bindings = design.get("bound_authorities")
    require(isinstance(bindings, list), "BOUND_AUTHORITIES_NOT_ARRAY")
    require(
        [item.get("role") for item in bindings if isinstance(item, dict)]
        == EXPECTED_BINDING_ROLES,
        "BOUND_AUTHORITY_ROLE_ORDER_DRIFT",
    )
    loaded: dict[str, dict[str, Any]] = {}
    for binding_value in bindings:
        require(isinstance(binding_value, dict), "BINDING_NOT_OBJECT")
        role = str(binding_value.get("role", ""))
        loaded[role] = validate_binding(binding_value)
    closure = loaded["consumed_l2_physical_invalid_closure"]
    closure_binding = bindings[0]
    expected = closure_binding.get("expected")
    require(isinstance(expected, dict), "L2_EXPECTED_PROJECTION_MISSING")
    require(
        closure.get("status") == expected.get("status")
        and closure.get("physical_attempt", {}).get("physical_identity_consumed")
        == expected.get("physical_identity_consumed")
        and closure.get("physical_attempt", {}).get("same_identity_rerun_permitted")
        == expected.get("same_identity_rerun_permitted")
        and closure.get("physical_attempt", {})
        .get("execution_counts", {})
        .get("push_world_attempt_count")
        == expected.get("push_world_attempt_count")
        and closure.get("decision", {}).get(
            "valid_positive_or_negative_route_result_observed"
        )
        is False
        and int(
            not closure.get("decision", {}).get(
                "valid_positive_or_negative_route_result_observed"
            )
        )
        == 1
        and expected.get("valid_behavior_result_count") == 0
        and closure.get("decision", {}).get("selected_successor_id")
        == expected.get("selected_successor_id"),
        "L2_CLOSURE_SEMANTICS_DRIFT",
    )
    return loaded


def representation_allowance(actual: float, expected: float) -> float:
    return (
        OPERATION_EVENT_BUDGET * FLOAT64_EPSILON * max(1.0, abs(actual), abs(expected))
    )


def representation_equal(actual: Any, expected: Any) -> bool:
    if (
        not isinstance(actual, float)
        or not isinstance(expected, float)
        or not math.isfinite(actual)
        or not math.isfinite(expected)
    ):
        return False
    return abs(actual - expected) <= representation_allowance(actual, expected)


def validate_numeric_contract(design: dict[str, Any]) -> dict[str, int]:
    contract = design.get("selected_numeric_comparison_contract")
    require(isinstance(contract, dict), "NUMERIC_CONTRACT_MISSING")
    longest_path_events = 8 + 1 + 1 + 6 + 1 + 1 + 8 + 1
    transport_events = 2
    unrounded_events = longest_path_events + transport_events
    ceiling_events = 1 << (unrounded_events - 1).bit_length()
    unit_allowance = ceiling_events * FLOAT64_EPSILON
    observed_maximum = 4.440892098500626e-16
    material = 1.0e-12
    large_material = 0.001
    require(
        FLOAT64_EPSILON == 2.220446049250313e-16
        and longest_path_events == 27
        and unrounded_events == 29
        and ceiling_events == OPERATION_EVENT_BUDGET
        and unit_allowance == 7.105427357601002e-15,
        "OPERATION_BUDGET_DERIVATION_DRIFT",
    )
    require(
        contract
        == {
            "contract_id": "binary64_operation_budget_scaled_comparison_v1",
            "applies_only_to_recomputed_derived_floating_fields": True,
            "binary64_machine_epsilon": FLOAT64_EPSILON,
            "binary64_machine_epsilon_definition": (
                "2^-52_spacing_from_one_to_next_representable_value"
            ),
            "longest_projection_dependency_rounded_arithmetic_event_count": 27,
            "json_numeric_transport_rounding_event_allowance": 2,
            "unrounded_total_event_budget": 29,
            "power_of_two_ceiling_event_budget": 32,
            "comparison_allowance_formula": (
                "32 * 2^-52 * max(1.0, abs(actual), abs(recomputed_expected))"
            ),
            "unit_scale_absolute_allowance": unit_allowance,
            "observed_predecessor_maximum_absolute_delta": observed_maximum,
            "observed_predecessor_maximum_used_to_select_allowance": False,
            "unit_scale_allowance_to_observed_predecessor_maximum_ratio": (
                unit_allowance / observed_maximum
            ),
            "minimum_required_material_mutation": material,
            "unit_scale_material_mutation_to_allowance_ratio": material
            / unit_allowance,
            "representative_large_material_mutation": large_material,
            "unit_scale_large_material_mutation_to_allowance_ratio": (
                large_material / unit_allowance
            ),
            "nonfinite_actual_refused": True,
            "nonfinite_recomputed_expected_refused": True,
            "missing_numeric_field_refused": True,
            "integer_or_boolean_coercion_for_derived_float_fields_permitted": False,
            "comparison_is_behavior_threshold": False,
            "comparison_changes_quaternion_unit_tolerance": False,
            "comparison_changes_task_axis_unit_tolerance": False,
            "comparison_changes_locomotion_outcome": False,
        },
        "NUMERIC_CONTRACT_DRIFT",
    )

    positive_controls = [
        (1.0, 1.0),
        (math.nextafter(1.0, math.inf), 1.0),
        (0.00013243728491951, 0.00013243728491950626),
        (1.0000000511645777, 1.0000000511645772),
    ]
    outside_controls = [
        (1.0 + material, 1.0),
        (1.0 + large_material, 1.0),
        (0.0 + material, 0.0),
        (-1.0 - material, -1.0),
    ]
    nonfinite_controls = [
        (math.nan, 1.0),
        (1.0, math.nan),
        (math.inf, 1.0),
        (1.0, -math.inf),
    ]
    require(
        all(
            representation_equal(actual, expected)
            for actual, expected in positive_controls
        ),
        "WITHIN_ALLOWANCE_CONTROL_REFUSED",
    )
    require(
        all(
            not representation_equal(actual, expected)
            for actual, expected in outside_controls
        ),
        "OUTSIDE_ALLOWANCE_CONTROL_ACCEPTED",
    )
    require(
        all(
            not representation_equal(actual, expected)
            for actual, expected in nonfinite_controls
        )
        and not representation_equal(1, 1.0)
        and not representation_equal(True, 1.0),
        "NONFINITE_OR_TYPE_CONTROL_ACCEPTED",
    )
    return {
        "within_allowance_positive_control_count": len(positive_controls),
        "outside_allowance_refusal_control_count": len(outside_controls),
        "nonfinite_refusal_control_count": len(nonfinite_controls),
        "type_refusal_control_count": 2,
    }


def validate_design(design: dict[str, Any], *, verify_bindings: bool) -> None:
    require(
        list(design)
        == [
            "schema_version",
            "status",
            "gate_id",
            "repair_id",
            "authored_parent_commit",
            "authored_local_date",
            "ledger_scope",
            "question_declaration",
            "causal_basis",
            "bound_authorities",
            "selected_numeric_comparison_contract",
            "selected_projection_receipt_validation_contract",
            "selected_exported_axis_validation_contract",
            "controlled_change_boundary",
            "required_zero_world_controls",
            "forward_authority_sequence",
            "claim_boundary",
        ],
        "TOP_LEVEL_KEY_ORDER_DRIFT",
    )
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10b_l3_serialization_stable_trace_validation_successor_design_v1"
        and design.get("status")
        == "prospective_representation_validation_successor_design_complete_physics_blocked"
        and design.get("gate_id") == "QSDK-R10B"
        and design.get("repair_id") == "QSDK-R10B-L3"
        and design.get("authored_parent_commit") == AUTHORED_PARENT_COMMIT,
        "DESIGN_IDENTITY_DRIFT",
    )
    require(
        design.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "prospective_zero_world_representation_validation_repair_design",
            "question_class": "development",
        },
        "LEDGER_SCOPE_DRIFT",
    )
    question = design.get("question_declaration")
    require(
        isinstance(question, dict)
        and question.get("physical_question_declared") is False
        and question.get("physical_work_authorized") is False
        and question.get(
            "maximum_world_attempt_count_before_complete_new_authority_graph"
        )
        == 0
        and question.get(
            "maximum_world_build_count_before_complete_new_authority_graph"
        )
        == 0,
        "QUESTION_BOUNDARY_DRIFT",
    )
    causal = design.get("causal_basis")
    require(
        isinstance(causal, dict)
        and causal.get("consumed_predecessor_repair_id") == "QSDK-R10B-L2"
        and causal.get("single_original_failing_subpredicate_claimed") is False
        and causal.get(
            "retained_trace_replay_establishes_multiple_independent_refusal_paths"
        )
        is True
        and causal.get("l2_projected_orientation_length_contract_failure_count") == 0
        and causal.get("l2_projection_receipt_exact_failure_count") == 2640
        and causal.get("l2_task_axis_float32_vector3_unit_failure_count") == 2640
        and causal.get("l2_task_axis_exported_scalar_unit_failure_count") == 0
        and causal.get("physics_failure_established") is False
        and causal.get("behavior_result_established") is False
        and causal.get("outcome_derived_correction_selected") is False,
        "CAUSAL_BASIS_DRIFT",
    )
    projection = design.get("selected_projection_receipt_validation_contract")
    require(
        isinstance(projection, dict)
        and projection.get("contract_id")
        == "serialization_stable_projection_receipt_validation_v2"
        and projection.get("required_key_set_exact") is True
        and projection.get("row_orientation_to_receipt_orientation_link_exact") is True
        and projection.get(
            "derived_numeric_fields_compared_with_selected_numeric_contract"
        )
        == DERIVED_NUMERIC_FIELDS
        and projection.get("whole_dictionary_order_dependent_equality_removed") is True
        and projection.get("projection_algorithm_changed") is False
        and projection.get("projected_quaternion_length_tolerance") == 1.0e-9
        and projection.get("projected_quaternion_length_tolerance_changed") is False,
        "PROJECTION_VALIDATION_CONTRACT_DRIFT",
    )
    axes = design.get("selected_exported_axis_validation_contract")
    require(
        isinstance(axes, dict)
        and axes.get("contract_id") == "exported_binary64_task_axis_validation_v1"
        and axes.get("norm_and_dot_computed_from_exported_scalar_components") is True
        and axes.get("float32_vector3_rematerialization_before_validation") is False
        and axes.get("unit_norm_tolerance") == 1.0e-12
        and axes.get("orthogonality_tolerance") == 1.0e-12
        and axes.get("unit_norm_tolerance_changed") is False
        and axes.get("orthogonality_tolerance_changed") is False
        and axes.get("task_frame_constancy_comparison")
        == "exact_exported_scalar_array_equality",
        "AXIS_VALIDATION_CONTRACT_DRIFT",
    )
    changes = design.get("controlled_change_boundary")
    require(
        isinstance(changes, dict)
        and changes.get("historical_l1_or_l2_source_or_evidence_modified") is False
        and changes.get("controller_changed") is False
        and changes.get("fixture_changed") is False
        and changes.get("challenge_changed") is False
        and changes.get("impulse_changed") is False
        and changes.get("behavior_threshold_changed") is False
        and changes.get("quaternion_projection_algorithm_changed") is False
        and changes.get("quaternion_length_tolerance_changed") is False
        and changes.get("task_axis_unit_tolerance_changed") is False
        and changes.get("task_axis_orthogonality_tolerance_changed") is False
        and changes.get("outcome_derived_correction_added") is False,
        "CONTROLLED_CHANGE_BOUNDARY_DRIFT",
    )
    controls = design.get("required_zero_world_controls")
    require(
        isinstance(controls, dict)
        and controls.get("exact_consumed_l2_trace_row_count") == 2640
        and controls.get(
            "exact_consumed_l2_trace_repaired_projection_receipt_acceptance_count"
        )
        == 2640
        and controls.get("exact_consumed_l2_trace_repaired_axis_acceptance_count")
        == 2640
        and controls.get("consumed_l2_trace_behavior_reclassification_permitted")
        is False
        and controls.get(
            "projection_receipt_material_numeric_mutation_refusals_minimum"
        )
        == 9
        and controls.get("model_construction_count") == 0
        and controls.get("world_attempt_count") == 0
        and controls.get("world_build_count") == 0
        and controls.get("native_readback_count") == 0
        and controls.get("solver_step_count") == 0
        and controls.get("physical_acceptance_authority") is False
        and controls.get("release_authority") is False,
        "ZERO_WORLD_CONTROL_BOUNDARY_DRIFT",
    )
    sequence = design.get("forward_authority_sequence")
    require(
        isinstance(sequence, dict)
        and sequence.get("new_clean_pushed_source_required") is True
        and sequence.get("new_official_zero_world_qualification_required") is True
        and sequence.get("stage_freeze_only_commit_required") is True
        and sequence.get("execution_authority_only_child_commit_required") is True
        and sequence.get("committed_graph_authority_check_required") is True
        and sequence.get("old_physical_identity_may_be_reused") is False
        and sequence.get("physical_execution_blocked_until_sequence_complete") is True,
        "FORWARD_SEQUENCE_DRIFT",
    )
    claims = design.get("claim_boundary")
    require(
        isinstance(claims, dict)
        and claims.get("representation_validation_repair_design_claimed") is True
        and claims.get("numeric_allowance_is_operation_derived_claimed") is True
        and claims.get("numeric_allowance_is_outcome_derived_claimed") is False
        and claims.get("zero_world_control_result_claimed") is False
        and claims.get("new_physical_result_claimed") is False
        and claims.get("bounded_upright_push_recovery_claimed") is False
        and claims.get("physical_acceptance_authority") is False
        and claims.get("release_authority") is False,
        "CLAIM_BOUNDARY_DRIFT",
    )
    if verify_bindings:
        validate_bindings(design)


def mutation_controls(design: dict[str, Any]) -> int:
    mutations: list[Callable[[dict[str, Any]], None]] = [
        lambda value: value.__setitem__("status", "physical_execution_authorized"),
        lambda value: value["question_declaration"].__setitem__(
            "physical_work_authorized", True
        ),
        lambda value: value["causal_basis"].__setitem__(
            "single_original_failing_subpredicate_claimed", True
        ),
        lambda value: value["selected_numeric_comparison_contract"].__setitem__(
            "power_of_two_ceiling_event_budget", 64
        ),
        lambda value: value["selected_numeric_comparison_contract"].__setitem__(
            "observed_predecessor_maximum_used_to_select_allowance", True
        ),
        lambda value: value[
            "selected_projection_receipt_validation_contract"
        ].__setitem__("required_key_set_exact", False),
        lambda value: value[
            "selected_projection_receipt_validation_contract"
        ].__setitem__("projected_quaternion_length_tolerance", 1.0e-6),
        lambda value: value["selected_exported_axis_validation_contract"].__setitem__(
            "unit_norm_tolerance", 1.0e-6
        ),
        lambda value: value["controlled_change_boundary"].__setitem__(
            "behavior_threshold_changed", True
        ),
        lambda value: value["required_zero_world_controls"].__setitem__(
            "consumed_l2_trace_behavior_reclassification_permitted", True
        ),
        lambda value: value["forward_authority_sequence"].__setitem__(
            "physical_execution_blocked_until_sequence_complete", False
        ),
        lambda value: value["claim_boundary"].__setitem__(
            "bounded_upright_push_recovery_claimed", True
        ),
    ]
    rejected = 0
    for mutate in mutations:
        candidate = copy.deepcopy(design)
        mutate(candidate)
        try:
            validate_design(candidate, verify_bindings=False)
            validate_numeric_contract(candidate)
        except DesignFailure:
            rejected += 1
        else:
            raise DesignFailure("DESIGN_MUTATION_ACCEPTED")
    require(rejected == len(mutations), "DESIGN_MUTATION_REJECTION_COUNT_DRIFT")
    return rejected


def run_l2_closure_audit() -> dict[str, Any]:
    completed = subprocess.run(
        (sys.executable, L2_CLOSURE_AUDIT_PATH),
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
    )
    require(completed.returncode == 0, "L2_CLOSURE_AUDIT_FAILED")
    lines = [
        line
        for line in completed.stdout.splitlines()
        if line.startswith(L2_PASS_MARKER)
    ]
    require(len(lines) == 1, "L2_CLOSURE_AUDIT_MARKER_COUNT")
    receipt = json.loads(lines[0][len(L2_PASS_MARKER) :])
    require(
        isinstance(receipt, dict)
        and receipt.get("ok") is True
        and receipt.get("physical_identity_consumed") is True
        and receipt.get("same_identity_rerun_permitted") is False
        and receipt.get("valid_behavior_result_count") == 0
        and receipt.get("selected_successor_id") == "QSDK-R10B-L3"
        and receipt.get("audit_world_attempt_count") == 0
        and receipt.get("audit_world_build_count") == 0,
        "L2_CLOSURE_AUDIT_RECEIPT_DRIFT",
    )
    return receipt


def main() -> int:
    try:
        validate_repository_identity()
        design = read_json(DESIGN_PATH, "L3_DESIGN")
        validate_design(design, verify_bindings=True)
        numeric_counts = validate_numeric_contract(design)
        mutation_rejections = mutation_controls(design)
        predecessor = run_l2_closure_audit()
        receipt = {
            "schema_version": "sporespore_qsdk_r10b_l3_successor_design_audit_v1",
            "gate_id": "QSDK-R10B",
            "repair_id": "QSDK-R10B-L3",
            "ok": True,
            "failure_code": "",
            "bound_authority_count": len(EXPECTED_BINDING_ROLES),
            "operation_derived_event_budget": OPERATION_EVENT_BUDGET,
            "binary64_machine_epsilon": FLOAT64_EPSILON,
            "unit_scale_representation_allowance": (
                OPERATION_EVENT_BUDGET * FLOAT64_EPSILON
            ),
            **numeric_counts,
            "design_mutation_rejection_count": mutation_rejections,
            "predecessor_closure_audit_passed": predecessor.get("ok") is True,
            "predecessor_physical_identity_consumed": True,
            "predecessor_valid_behavior_result_count": 0,
            "behavior_threshold_changed": False,
            "quaternion_length_tolerance_changed": False,
            "task_axis_unit_tolerance_changed": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        print(PASS_MARKER + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
        return 0
    except (DesignFailure, OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"QSDK_R10B_L3_SUCCESSOR_DESIGN_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
