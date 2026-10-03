"""Pure independent checks of the L14 worker's invalid terminal source receipt.

Passing these checks only proves retention of a named failure. It cannot turn
that failure into a valid child, route ghost, behavioral result or release.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from qsdk_r10f_l14_terminal_consumers import same_source_value

SCHEMA = "sporespore_qsdk_r10f_l14_walking_terminal_failure_retention_v1"
EVALUATOR_FAILURE_SCHEMA = "sporespore_qsdk_r10f_walking_segment_evaluation_failure_v2"
COMPLETION_FAILURE = "QSDK_R10F_WALKING_COMPLETION_RECEIPT_INVALID"
SLICE_FAILURE = "QSDK_R10F_WALKING_TRACE_SLICE_INVALID"
EVALUATION_FAILURE = "QSDK_R10F_WALKING_EVALUATION_INVALID"
COUNTERS = (
    "body_population_rebuild_count",
    "direct_torso_force_command_count",
    "direct_torso_impulse_command_count",
    "direct_torso_velocity_command_count",
    "direct_torso_transform_command_count",
)
KEYS = {
    "schema_version",
    "gate_id",
    "repair_id",
    "ledger_scope",
    "ok",
    "measurement_complete",
    "failure_code",
    "evaluator_failure_code",
    "arm_id",
    "active_walking_session",
    "all_observed_trace_rows",
    "completion_receipt",
    "walking_evaluation_input",
    "evaluation",
    "trace_slice_valid",
    "walking_session_completion_attempted",
    "physical_acceptance_authority",
    "release_authority",
    "payload_sha256",
}


def validate_failure_retention(
    partial: Any,
    *,
    role: str,
    canonical_sha256: Callable[[Any], str],
    payload_sha256: Callable[[Any], str],
) -> dict[str, Any]:
    predicates: dict[str, bool] = {}

    def finish() -> dict[str, Any]:
        failed = [key for key, value in predicates.items() if not value]
        return {
            "walking_evaluation_failure_retention_valid": not failed,
            "predicates": predicates,
            "failed_predicate_ids": failed,
            "route_execution_valid": False,
            "behavior_passed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }

    predicates["partial_arm_object"] = type(partial) is dict
    if not predicates["partial_arm_object"]:
        return finish()
    failure = partial.get("last_walking_evaluation_failure")
    predicates["failure_exact_key_set"] = type(failure) is dict and set(failure) == KEYS
    if not predicates["failure_exact_key_set"]:
        return finish()
    predicates["failure_identity_and_denied_claims"] = (
        failure.get("schema_version") == SCHEMA
        and failure.get("gate_id") == "QSDK-R10F"
        and failure.get("repair_id") == "QSDK-R10F-L14"
        and failure.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "invalid_walking_terminal_source_retention",
            "question_class": "development",
        }
        and partial.get("arm_id") == failure.get("arm_id") == role
        and failure.get("ok") is False
        and failure.get("measurement_complete") is False
        and failure.get("physical_acceptance_authority") is False
        and failure.get("release_authority") is False
        and failure.get("walking_session_completion_attempted") is True
        and partial.get("walking_session_completion_attempted") is True
    )
    session = failure.get("active_walking_session")
    rows = failure.get("all_observed_trace_rows")
    completion = failure.get("completion_receipt")
    evidence = failure.get("walking_evaluation_input")
    evaluation = failure.get("evaluation")
    predicates["source_container_types"] = (
        type(session) is dict
        and type(rows) is list
        and type(completion) is dict
        and type(evidence) is dict
        and type(evaluation) is dict
    )
    if not predicates["source_container_types"]:
        return finish()
    predicates["original_partial_sources_equal_including_number_kinds"] = (
        same_source_value(session, partial.get("active_walking_session"))
        and same_source_value(rows, partial.get("trace_rows"))
    )
    start = session.get("trace_start_index")
    count = session.get("scheduled_step_count")
    valid_slice = (
        type(start) is int
        and type(count) is int
        and start >= 0
        and count >= 1
        and start + count == len(rows)
    )
    predicates["trace_slice_status_recomputed"] = (
        failure.get("trace_slice_valid") is valid_slice
    )
    projected = {
        "arm_id": role,
        "segment_id": session.get("evaluation_segment_id"),
        "session_id": session.get("session_id"),
        "expected_step_count": count,
        "start_receipt": session.get("start_receipt"),
        "completion_receipt": completion,
        "initial_contact_by_limb": session.get("initial_contact_by_limb"),
        "rows": rows[start:] if valid_slice else [],
        "world_build_count": 1,
        "world_reset_count": partial.get("solver_reset_count"),
        **{key: partial.get(key) for key in COUNTERS},
        "fixture_spec_compiled_before_world_creation": True,
        "initial_perturbation_application_count": 0,
        "physics_engine": "Jolt Physics",
        "physics_hz": 120,
        "solver_velocity_steps": 20,
        "solver_position_steps": 7,
        "source_measurement": True,
    }
    predicates["complete_production_input_recomputed_without_coercion"] = (
        same_source_value(evidence, projected)
    )
    completion_shape = (
        type(completion.get("adapter_summary")) is dict
        and type(completion.get("adapter_shutdown_receipt")) is dict
    )
    expected_code = (
        COMPLETION_FAILURE
        if not completion_shape
        else SLICE_FAILURE if not valid_slice else EVALUATION_FAILURE
    )
    predicates["named_failure_boundary_matches_sources"] = (
        failure.get("failure_code") == expected_code
    )
    if expected_code == EVALUATION_FAILURE:
        predicates["invalid_evaluator_receipt_not_behavioral_negative"] = (
            evaluation.get("schema_version") == EVALUATOR_FAILURE_SCHEMA
            and evaluation.get("gate_id") == "QSDK-R10F"
            and evaluation.get("ok") is False
            and type(evaluation.get("failure_code")) is str
            and bool(evaluation["failure_code"])
            and failure.get("evaluator_failure_code") == evaluation["failure_code"]
            and all(
                type(evaluation.get(key)) is int and evaluation[key] == 0
                for key in (
                    "model_construction_count",
                    "native_readback_count",
                    "world_attempt_count",
                    "world_build_count",
                    "solver_step_count",
                )
            )
            and all(
                evaluation.get(key) is False
                for key in (
                    "physics_state_modified",
                    "physical_acceptance_authority",
                    "release_authority",
                )
            )
        )
    else:
        predicates["evaluation_not_invented_before_input_preparation"] = (
            evaluation == {} and failure.get("evaluator_failure_code") == ""
        )
    try:
        digest = failure.get("payload_sha256")
        predicates["failure_payload_digest"] = (
            type(digest) is str
            and len(digest) == 71
            and digest.startswith("sha256:")
            and digest == payload_sha256(failure)
        )
        # The complete all-row source is separately compared to the enclosing
        # partial report above; hashing only an internally consistent fragment
        # cannot qualify retention of the whole observed population.
        predicates["complete_source_digest_available"] = canonical_sha256(
            evidence
        ).startswith("sha256:")
    except (ValueError, TypeError, OverflowError):
        predicates["failure_payload_digest"] = False
        predicates["complete_source_digest_available"] = False
    return finish()
