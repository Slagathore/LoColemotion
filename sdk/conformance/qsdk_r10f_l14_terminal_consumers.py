"""Pure L14 terminal/source projections; no I/O, physics, or source rewriting."""

from __future__ import annotations

from typing import Any, Callable, Mapping


SESSION_KEYS = {
    "completion_receipt",
    "evaluation",
    "evaluation_segment_id",
    "session_id",
    "start_receipt",
    "step_receipt_sha256s",
}
START_SCHEMA = "sporespore_qsdk_r10f_recovery_native_locomotion_session_v1"
FACADE_ID = "sporespore_qsdk_r10f_recovery_native_s169_locomotion_facade_v1"
POLICY_ID = "sporespore_balanced_wave_bw5r_b_v1"


def same_source_value(left: Any, right: Any) -> bool:
    """Equality for duplicated sources includes every retained JSON number kind."""
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(
            same_source_value(left[k], right[k]) for k in left
        )
    if isinstance(left, list):
        return len(left) == len(right) and all(
            same_source_value(a, b) for a, b in zip(left, right)
        )
    return left == right


def _digest_matches(value: Any, stored: Any, compute: Callable[[Any], str]) -> bool:
    if type(stored) is not str:
        return False
    try:
        return stored == compute(value)
    except (ValueError, TypeError, OverflowError, RuntimeError):
        return False


def terminal_content_predicates(
    terminal: Mapping[str, Any],
    *,
    native_step_matches: Callable[[Any, Any, Any], bool],
    canonical_sha256: Callable[[Any], str],
    payload_sha256: Callable[[Any], str],
) -> dict[str, bool]:
    """Use the established exact native-step rule only at its source boundary.

    Host integer counters remain the caller's strict integer contract. Both
    retained memory copies and every digest are checked without normalizing a
    value, changing a type, or using an empirical floating-point allowance.
    """
    memory = terminal.get("recovery_memory")
    step = terminal.get("recovery_step_receipt")
    classification = terminal.get("recovery_classification")
    memory_object = type(memory) is dict
    step_object = type(step) is dict
    classification_object = type(classification) is dict
    source_memory = step.get("memory") if step_object else None
    source_object = type(source_memory) is dict
    return {
        "memory_step_exact_native_source": memory_object
        and source_object
        and native_step_matches(
            memory.get("last_semantic_step"),
            source_memory.get("last_semantic_step"),
            terminal.get("completed_global_semantic_step"),
        ),
        "step_memory_equal": memory_object
        and source_object
        and same_source_value(source_memory, memory),
        "step_classification_equal": step_object
        and classification_object
        and same_source_value(step.get("classification"), classification),
        "memory_step_number_kind_equal": memory_object
        and source_object
        and type(source_memory.get("last_semantic_step"))
        is type(memory.get("last_semantic_step")),
        "step_next_phase_equal": step_object
        and memory_object
        and step.get("next_phase") == memory.get("phase"),
        "terminal_phase_equal": memory_object
        and terminal.get("recovery_terminal_phase") == memory.get("phase"),
        "recovery_memory_sha256": memory_object
        and _digest_matches(
            memory, terminal.get("recovery_memory_sha256"), canonical_sha256
        ),
        "recovery_step_receipt_sha256": step_object
        and _digest_matches(
            step, terminal.get("recovery_step_receipt_sha256"), canonical_sha256
        ),
        "recovery_classification_sha256": classification_object
        and _digest_matches(
            classification,
            terminal.get("recovery_classification_sha256"),
            canonical_sha256,
        ),
        "terminal_payload_sha256": _digest_matches(
            terminal, terminal.get("payload_sha256"), payload_sha256
        ),
    }


def interaction_start_projection(
    session: Any,
    interaction: Mapping[str, Any],
    *,
    model_instance_id: str,
    canonical_sha256: Callable[[Any], str],
) -> dict[str, Any]:
    """Select exactly the producer's start receipt, never its later wrapper."""
    wrapper_valid = type(session) is dict and set(session) == SESSION_KEYS
    start = session.get("start_receipt") if type(session) is dict else None
    start_valid = type(start) is dict
    predicates = {
        "completed_session_producer_shape": wrapper_valid,
        "walking_prefix_session": wrapper_valid
        and session.get("evaluation_segment_id") == "walking_prefix",
        "start_source_object": start_valid,
        "start_source_identity": start_valid
        and start.get("schema_version") == START_SCHEMA
        and start.get("gate_id") == "QSDK-R10F"
        and start.get("facade_id") == FACADE_ID
        and start.get("selected_policy_id") == POLICY_ID
        and start.get("segment_id") == "walking_prefix"
        and start.get("model_instance_id") == model_instance_id
        and start.get("ok") is True,
        "start_session_links": start_valid
        and wrapper_valid
        and type(start.get("session_id")) is str
        and bool(start["session_id"])
        and session.get("session_id")
        == start["session_id"]
        == interaction.get("prefix_session_id"),
        "start_source_digest": start_valid
        and _digest_matches(
            start, interaction.get("prefix_session_receipt_sha256"), canonical_sha256
        ),
        "forward_axis_source_equal": start_valid
        and type(start.get("task_frame_forward_axis_world_host_real")) is list
        and same_source_value(
            start.get("task_frame_forward_axis_world_host_real"),
            interaction.get("task_frame_forward_axis_world_host_real"),
        ),
        "lateral_axis_source_equal": start_valid
        and type(start.get("task_frame_lateral_axis_world_host_real")) is list
        and same_source_value(
            start.get("task_frame_lateral_axis_world_host_real"),
            interaction.get("task_frame_lateral_axis_world_host_real"),
        ),
        "task_frame_frozen_reanchored": start_valid
        and start.get("task_frame_frozen_for_walking_segment") is True
        and start.get("task_frame_reanchored_in_controller_memory") is True,
        "start_zero_world_and_no_state_write": start_valid
        and all(
            type(start.get(key)) is int and start[key] == 0
            for key in (
                "body_transform_write_count",
                "body_velocity_write_count",
                "solver_reset_count",
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
                "solver_step_count",
            )
        )
        and start.get("physics_state_modified") is False,
        "start_no_acceptance_authority": start_valid
        and start.get("physical_acceptance_authority") is False
        and start.get("release_authority") is False,
    }
    failed = [name for name, passed in predicates.items() if not passed]
    return {
        "ok": not failed,
        "predicates": predicates,
        "failed_predicates": failed,
        "start_receipt": start if not failed else {},
        "source_modified": False,
    }
