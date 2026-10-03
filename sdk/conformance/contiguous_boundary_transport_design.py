#!/usr/bin/env python3
"""Pure zero-world reference design for contiguous Godot body boundaries.

This module is an executable design oracle, not the live Godot transport.  It
models the smallest state transition required to pair an inactive sequence-zero
initializer boundary with completed-step direct-state callbacks.  No engine,
model, native read, world, or solver step is available from this module.
"""

from __future__ import annotations

from copy import deepcopy
import hashlib
import math
from typing import Any, Callable, Mapping

from sdk.conformance.content_addressed_zero_world_closure import canonical_bytes


TRANSPORT_DESIGN_ID = (
    "godot_jolt_r24d167_contiguous_completed_step_boundary_transport_v1"
)
BOUNDARY_SCHEMA = "sporespore_qsdk_r24d167_completed_body_boundary_set_v1"
STATE_SCHEMA = "sporespore_qsdk_r24d167_boundary_transport_state_v1"
PAIR_SCHEMA = "sporespore_qsdk_r24d167_contiguous_body_boundary_pair_v1"
INITIALIZER_SOURCE_KIND = "inactive_physics_initializer_readback_v1"
COMPLETED_STEP_SOURCE_KIND = "completed_step_direct_state_callback_v1"
ORDERED_BODY_IDS = (
    "torso",
    "front_left_upper",
    "front_left_distal",
    "front_right_upper",
    "front_right_distal",
    "rear_left_upper",
    "rear_left_distal",
    "rear_right_upper",
    "rear_right_distal",
)

_BOUNDARY_KEYS = {
    "schema_version",
    "transport_design_id",
    "attempt_id",
    "arm_id",
    "model_instance_id",
    "boundary_sequence",
    "source_event_id",
    "source_kind",
    "physics_active",
    "source_measurement",
    "ordered_body_ids",
    "ordered_bodies",
    "mechanical_energy_change_used_as_input",
    "energy_balance_residual_used_as_input",
    "acceptance_threshold_used_as_input",
    "controller_or_behavior_result_used_as_input",
    "payload_sha256",
}
_COMMON_BODY_KEYS = {
    "body_id",
    "body_index",
    "boundary_sequence",
    "position_world_m",
    "linear_velocity_world_m_s",
    "mass_kg",
}
_COMPLETED_BODY_KEYS = _COMMON_BODY_KEYS | {
    "callback_sequence",
    "total_gravity_world_m_s2",
    "solver_step_s",
}
_STATE_KEYS = {
    "schema_version",
    "transport_design_id",
    "attempt_id",
    "arm_id",
    "model_instance_id",
    "ordered_body_ids",
    "cached_completed_boundary",
    "cached_boundary_sequence",
    "accepted_pair_count",
    "state_revision",
}
_OUTCOME_DERIVED_KEYS = {
    "acceptance_threshold",
    "behavior_result",
    "energy_balance_residual_j",
    "physical_result",
    "recovery_success",
    "stable_stance_gate",
}


class BoundaryTransportDesignError(ValueError):
    """Raised when the reference transport refuses an invalid transition."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise BoundaryTransportDesignError(code)


def _payload_sha256(boundary: Mapping[str, Any]) -> str:
    payload = {key: value for key, value in boundary.items() if key != "payload_sha256"}
    return "sha256:" + hashlib.sha256(canonical_bytes(payload)).hexdigest()


def _finite_number(value: Any, code: str) -> float:
    _require(isinstance(value, (int, float)) and not isinstance(value, bool), code)
    projected = float(value)
    _require(math.isfinite(projected), code)
    return projected


def _finite_vector3(value: Any, code: str) -> tuple[float, float, float]:
    _require(isinstance(value, list) and len(value) == 3, code)
    return tuple(_finite_number(component, code) for component in value)


def _validate_boundary(
    boundary: Mapping[str, Any],
    *,
    expected_source_kind: str,
) -> None:
    _require(isinstance(boundary, Mapping), "BOUNDARY_SHAPE")
    _require(
        not any(key in boundary for key in _OUTCOME_DERIVED_KEYS),
        "OUTCOME_DERIVED_INPUT",
    )
    _require(set(boundary) == _BOUNDARY_KEYS, "BOUNDARY_KEYS")
    _require(boundary["schema_version"] == BOUNDARY_SCHEMA, "BOUNDARY_SCHEMA")
    _require(
        boundary["transport_design_id"] == TRANSPORT_DESIGN_ID,
        "TRANSPORT_DESIGN_ID",
    )
    for key in ("attempt_id", "arm_id", "model_instance_id", "source_event_id"):
        _require(isinstance(boundary[key], str) and bool(boundary[key]), f"IDENTITY:{key}")
    sequence = boundary["boundary_sequence"]
    _require(
        isinstance(sequence, int) and not isinstance(sequence, bool) and sequence >= 0,
        "BOUNDARY_SEQUENCE_TYPE",
    )
    _require(boundary["source_kind"] == expected_source_kind, "BOUNDARY_SOURCE_KIND")
    _require(boundary["source_measurement"] is True, "SOURCE_MEASUREMENT")
    expected_physics_active = expected_source_kind == COMPLETED_STEP_SOURCE_KIND
    _require(
        boundary["physics_active"] is expected_physics_active,
        "BOUNDARY_PHYSICS_ACTIVE",
    )
    for key in (
        "mechanical_energy_change_used_as_input",
        "energy_balance_residual_used_as_input",
        "acceptance_threshold_used_as_input",
        "controller_or_behavior_result_used_as_input",
    ):
        _require(boundary[key] is False, f"OUTCOME_INDEPENDENCE:{key}")

    ordered_ids = boundary["ordered_body_ids"]
    bodies = boundary["ordered_bodies"]
    _require(isinstance(ordered_ids, list), "ORDERED_BODY_IDS_SHAPE")
    _require(tuple(ordered_ids) == ORDERED_BODY_IDS, "ORDERED_BODY_IDS")
    _require(isinstance(bodies, list) and len(bodies) == len(ORDERED_BODY_IDS), "BODY_COUNT")
    expected_body_keys = (
        _COMMON_BODY_KEYS
        if expected_source_kind == INITIALIZER_SOURCE_KIND
        else _COMPLETED_BODY_KEYS
    )
    for index, (expected_body_id, body) in enumerate(zip(ORDERED_BODY_IDS, bodies, strict=True)):
        _require(isinstance(body, Mapping), f"BODY_SHAPE:{index}")
        _require(
            not any(key in body for key in _OUTCOME_DERIVED_KEYS),
            f"OUTCOME_DERIVED_BODY_INPUT:{index}",
        )
        _require(set(body) == expected_body_keys, f"BODY_KEYS:{index}")
        _require(body["body_id"] == expected_body_id, f"BODY_ID:{index}")
        _require(body["body_index"] == index, f"BODY_INDEX:{index}")
        _require(body["boundary_sequence"] == sequence, f"BODY_SEQUENCE:{index}")
        _finite_vector3(body["position_world_m"], f"BODY_POSITION:{index}")
        _finite_vector3(body["linear_velocity_world_m_s"], f"BODY_VELOCITY:{index}")
        mass = _finite_number(body["mass_kg"], f"BODY_MASS:{index}")
        _require(mass > 0.0, f"BODY_MASS:{index}")
        if expected_source_kind == COMPLETED_STEP_SOURCE_KIND:
            _require(body["callback_sequence"] == sequence, f"CALLBACK_SEQUENCE:{index}")
            _finite_vector3(
                body["total_gravity_world_m_s2"],
                f"BODY_GRAVITY:{index}",
            )
            step = _finite_number(body["solver_step_s"], f"SOLVER_STEP:{index}")
            _require(step > 0.0, f"SOLVER_STEP:{index}")
    _require(boundary["payload_sha256"] == _payload_sha256(boundary), "PAYLOAD_SHA256")


def _validate_state(state: Mapping[str, Any]) -> None:
    _require(isinstance(state, Mapping) and set(state) == _STATE_KEYS, "STATE_KEYS")
    _require(state["schema_version"] == STATE_SCHEMA, "STATE_SCHEMA")
    _require(state["transport_design_id"] == TRANSPORT_DESIGN_ID, "STATE_DESIGN_ID")
    _require(tuple(state["ordered_body_ids"]) == ORDERED_BODY_IDS, "STATE_BODY_IDS")
    sequence = state["cached_boundary_sequence"]
    _require(isinstance(sequence, int) and sequence >= 0, "STATE_SEQUENCE")
    _require(state["accepted_pair_count"] == sequence, "STATE_PAIR_COUNT")
    _require(state["state_revision"] == sequence, "STATE_REVISION")
    cached = state["cached_completed_boundary"]
    expected_kind = INITIALIZER_SOURCE_KIND if sequence == 0 else COMPLETED_STEP_SOURCE_KIND
    _validate_boundary(cached, expected_source_kind=expected_kind)
    _require(cached["boundary_sequence"] == sequence, "STATE_CACHED_SEQUENCE")
    for key in ("attempt_id", "arm_id", "model_instance_id"):
        _require(state[key] == cached[key], f"STATE_CACHED_IDENTITY:{key}")


def initialize_boundary_transport_state_v1(
    initializer_boundary: Mapping[str, Any],
) -> dict[str, Any]:
    """Accept exactly one inactive, source-measured sequence-zero boundary."""

    _validate_boundary(
        initializer_boundary,
        expected_source_kind=INITIALIZER_SOURCE_KIND,
    )
    _require(initializer_boundary["boundary_sequence"] == 0, "INITIALIZER_SEQUENCE")
    return {
        "schema_version": STATE_SCHEMA,
        "transport_design_id": TRANSPORT_DESIGN_ID,
        "attempt_id": initializer_boundary["attempt_id"],
        "arm_id": initializer_boundary["arm_id"],
        "model_instance_id": initializer_boundary["model_instance_id"],
        "ordered_body_ids": list(ORDERED_BODY_IDS),
        "cached_completed_boundary": deepcopy(initializer_boundary),
        "cached_boundary_sequence": 0,
        "accepted_pair_count": 0,
        "state_revision": 0,
    }


def advance_boundary_transport_state_v1(
    state: Mapping[str, Any],
    completed_step_boundary: Mapping[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Map one contiguous pair, then return exactly one advanced cache state.

    Inputs are never mutated.  Every validation completes before the successor
    state is constructed, giving the live implementation a transactional rule:
    replace its owned state only when this transition succeeds.
    """

    _validate_state(state)
    _validate_boundary(
        completed_step_boundary,
        expected_source_kind=COMPLETED_STEP_SOURCE_KIND,
    )
    for key in ("attempt_id", "arm_id", "model_instance_id"):
        _require(state[key] == completed_step_boundary[key], f"CROSSED_IDENTITY:{key}")

    cached = state["cached_completed_boundary"]
    _require(
        completed_step_boundary["source_event_id"] != cached["source_event_id"],
        "SAME_SOURCE_EVENT",
    )
    cached_sequence = int(state["cached_boundary_sequence"])
    current_sequence = int(completed_step_boundary["boundary_sequence"])
    if current_sequence == cached_sequence:
        raise BoundaryTransportDesignError("DUPLICATE_BOUNDARY")
    if current_sequence < cached_sequence:
        raise BoundaryTransportDesignError("STALE_BOUNDARY")
    if current_sequence > cached_sequence + 1:
        raise BoundaryTransportDesignError("SKIPPED_BOUNDARY")
    _require(current_sequence == cached_sequence + 1, "NONCONTIGUOUS_BOUNDARY")

    paired_bodies: list[dict[str, Any]] = []
    for index, (before, after) in enumerate(
        zip(cached["ordered_bodies"], completed_step_boundary["ordered_bodies"], strict=True)
    ):
        _require(before["body_id"] == after["body_id"], f"CROSSED_BODY:{index}")
        _require(before["mass_kg"] == after["mass_kg"], f"MASS_CONTINUITY:{index}")
        paired_bodies.append(
            {
                "body_id": before["body_id"],
                "body_index": index,
                "pre_boundary_sequence": cached_sequence,
                "post_boundary_sequence": current_sequence,
                "pre_source_event_id": cached["source_event_id"],
                "post_source_event_id": completed_step_boundary["source_event_id"],
                "mass_kg": before["mass_kg"],
                "pre_position_world_m": deepcopy(before["position_world_m"]),
                "post_position_world_m": deepcopy(after["position_world_m"]),
                "pre_linear_velocity_world_m_s": deepcopy(
                    before["linear_velocity_world_m_s"]
                ),
                "post_linear_velocity_world_m_s": deepcopy(
                    after["linear_velocity_world_m_s"]
                ),
                "total_gravity_world_m_s2": deepcopy(
                    after["total_gravity_world_m_s2"]
                ),
                "solver_step_s": after["solver_step_s"],
            }
        )

    pair = {
        "schema_version": PAIR_SCHEMA,
        "transport_design_id": TRANSPORT_DESIGN_ID,
        "attempt_id": state["attempt_id"],
        "arm_id": state["arm_id"],
        "model_instance_id": state["model_instance_id"],
        "semantic_step": current_sequence,
        "previous_sequence": cached_sequence,
        "pre_source_kind": cached["source_kind"],
        "post_source_kind": completed_step_boundary["source_kind"],
        "pre_source_event_id": cached["source_event_id"],
        "post_source_event_id": completed_step_boundary["source_event_id"],
        "ordered_body_ids": list(ORDERED_BODY_IDS),
        "ordered_body_boundaries": paired_bodies,
        "cache_advance_count": 1,
        "source_measurement": True,
        "mechanical_energy_change_used_as_input": False,
        "energy_balance_residual_used_as_input": False,
        "acceptance_threshold_used_as_input": False,
        "controller_or_behavior_result_used_as_input": False,
    }
    successor_state = {
        "schema_version": STATE_SCHEMA,
        "transport_design_id": TRANSPORT_DESIGN_ID,
        "attempt_id": state["attempt_id"],
        "arm_id": state["arm_id"],
        "model_instance_id": state["model_instance_id"],
        "ordered_body_ids": list(ORDERED_BODY_IDS),
        "cached_completed_boundary": deepcopy(completed_step_boundary),
        "cached_boundary_sequence": current_sequence,
        "accepted_pair_count": int(state["accepted_pair_count"]) + 1,
        "state_revision": int(state["state_revision"]) + 1,
    }
    _validate_state(successor_state)
    return pair, successor_state


def _fixture_boundary(sequence: int, source_kind: str) -> dict[str, Any]:
    bodies: list[dict[str, Any]] = []
    for index, body_id in enumerate(ORDERED_BODY_IDS):
        body: dict[str, Any] = {
            "body_id": body_id,
            "body_index": index,
            "boundary_sequence": sequence,
            "position_world_m": [
                index * 0.1 + sequence * 0.001,
                0.4 + index * 0.01 + sequence * 0.002,
                -index * 0.05 + sequence * 0.003,
            ],
            "linear_velocity_world_m_s": [
                sequence * 0.01,
                -sequence * 0.02,
                index * 0.001,
            ],
            "mass_kg": 1.2 if body_id == "torso" else 0.44,
        }
        if source_kind == COMPLETED_STEP_SOURCE_KIND:
            body.update(
                {
                    "callback_sequence": sequence,
                    "total_gravity_world_m_s2": [0.0, -9.8, 0.0],
                    "solver_step_s": 1.0 / 120.0,
                }
            )
        bodies.append(body)
    boundary = {
        "schema_version": BOUNDARY_SCHEMA,
        "transport_design_id": TRANSPORT_DESIGN_ID,
        "attempt_id": "r24d167-zero-world-attempt",
        "arm_id": "candidate_arm",
        "model_instance_id": "synthetic-reference-model",
        "boundary_sequence": sequence,
        "source_event_id": f"reference-event-{sequence}",
        "source_kind": source_kind,
        "physics_active": source_kind == COMPLETED_STEP_SOURCE_KIND,
        "source_measurement": True,
        "ordered_body_ids": list(ORDERED_BODY_IDS),
        "ordered_bodies": bodies,
        "mechanical_energy_change_used_as_input": False,
        "energy_balance_residual_used_as_input": False,
        "acceptance_threshold_used_as_input": False,
        "controller_or_behavior_result_used_as_input": False,
        "payload_sha256": "",
    }
    boundary["payload_sha256"] = _payload_sha256(boundary)
    return boundary


def _rehash(boundary: dict[str, Any]) -> dict[str, Any]:
    boundary["payload_sha256"] = _payload_sha256(boundary)
    return boundary


def _expect_refusal(
    expected: str,
    state: Mapping[str, Any],
    call: Callable[[], object],
) -> None:
    before = canonical_bytes(state)
    caught: BoundaryTransportDesignError | None = None
    try:
        call()
    except BoundaryTransportDesignError as error:
        caught = error
    _require(str(caught) == expected, f"MUTATION_EXPECTATION:{expected}:{caught}")
    _require(canonical_bytes(state) == before, f"MUTATION_CHANGED_STATE:{expected}")


def qualify_contiguous_boundary_transport_design_v1() -> dict[str, Any]:
    """Execute the R167 synthetic transition and refusal matrix."""

    initializer = _fixture_boundary(0, INITIALIZER_SOURCE_KIND)
    post_one = _fixture_boundary(1, COMPLETED_STEP_SOURCE_KIND)
    post_two = _fixture_boundary(2, COMPLETED_STEP_SOURCE_KIND)
    state_zero = initialize_boundary_transport_state_v1(initializer)
    pair_one, state_one = advance_boundary_transport_state_v1(state_zero, post_one)
    pair_two, state_two = advance_boundary_transport_state_v1(state_one, post_two)
    stationary_post_one = deepcopy(post_one)
    stationary_post_one["source_event_id"] = "reference-stationary-event-1"
    for index, body in enumerate(stationary_post_one["ordered_bodies"]):
        body["position_world_m"] = deepcopy(
            initializer["ordered_bodies"][index]["position_world_m"]
        )
        body["linear_velocity_world_m_s"] = deepcopy(
            initializer["ordered_bodies"][index]["linear_velocity_world_m_s"]
        )
    _rehash(stationary_post_one)
    stationary_pair, _ = advance_boundary_transport_state_v1(
        state_zero,
        stationary_post_one,
    )

    _require(state_zero["cached_boundary_sequence"] == 0, "POSITIVE_INITIALIZER")
    _require(
        (pair_one["previous_sequence"], pair_one["semantic_step"]) == (0, 1)
        and (pair_two["previous_sequence"], pair_two["semantic_step"]) == (1, 2),
        "POSITIVE_CONTIGUITY",
    )
    _require(
        all(
            row["pre_position_world_m"]
            == post_one["ordered_bodies"][index]["position_world_m"]
            for index, row in enumerate(pair_two["ordered_body_boundaries"])
        ),
        "POSITIVE_CACHE_PROVENANCE",
    )
    _require(
        pair_one["cache_advance_count"] == pair_two["cache_advance_count"] == 1
        and state_two["accepted_pair_count"] == 2
        and state_two["state_revision"] == 2,
        "POSITIVE_EXACT_ONCE_ADVANCE",
    )
    _require(
        canonical_bytes(state_zero["cached_completed_boundary"])
        == canonical_bytes(initializer),
        "POSITIVE_INPUT_IMMUTABILITY",
    )
    _require(
        all(
            row["pre_position_world_m"] == row["post_position_world_m"]
            and row["pre_linear_velocity_world_m_s"]
            == row["post_linear_velocity_world_m_s"]
            for row in stationary_pair["ordered_body_boundaries"]
        ),
        "POSITIVE_STATIONARY_DISTINCT_EVENT",
    )

    mutation_ids: list[str] = []

    def control(
        control_id: str,
        expected: str,
        state: Mapping[str, Any],
        call: Callable[[], object],
    ) -> None:
        _expect_refusal(expected, state, call)
        mutation_ids.append(control_id)

    wrong_initializer = _fixture_boundary(1, INITIALIZER_SOURCE_KIND)
    control(
        "initializer_nonzero_sequence",
        "INITIALIZER_SEQUENCE",
        {},
        lambda: initialize_boundary_transport_state_v1(wrong_initializer),
    )
    wrong_initializer = _fixture_boundary(0, COMPLETED_STEP_SOURCE_KIND)
    control(
        "initializer_wrong_source_kind",
        "BOUNDARY_SOURCE_KIND",
        {},
        lambda: initialize_boundary_transport_state_v1(wrong_initializer),
    )

    missing_body = deepcopy(post_one)
    missing_body["ordered_bodies"].pop()
    _rehash(missing_body)
    control(
        "missing_body",
        "BODY_COUNT",
        state_zero,
        lambda: advance_boundary_transport_state_v1(state_zero, missing_body),
    )
    nonfinite = deepcopy(post_one)
    nonfinite["ordered_bodies"][0]["position_world_m"][0] = float("nan")
    control(
        "nonfinite_body_value",
        "BODY_POSITION:0",
        state_zero,
        lambda: advance_boundary_transport_state_v1(state_zero, nonfinite),
    )
    control(
        "same_source_event",
        "SAME_SOURCE_EVENT",
        state_one,
        lambda: advance_boundary_transport_state_v1(state_one, post_one),
    )
    duplicate = deepcopy(post_one)
    duplicate["source_event_id"] = "reference-event-1-replay"
    _rehash(duplicate)
    control(
        "duplicate_sequence",
        "DUPLICATE_BOUNDARY",
        state_one,
        lambda: advance_boundary_transport_state_v1(state_one, duplicate),
    )
    stale = deepcopy(post_one)
    stale["source_event_id"] = "reference-event-1-stale"
    _rehash(stale)
    control(
        "stale_sequence",
        "STALE_BOUNDARY",
        state_two,
        lambda: advance_boundary_transport_state_v1(state_two, stale),
    )
    control(
        "skipped_sequence",
        "SKIPPED_BOUNDARY",
        state_zero,
        lambda: advance_boundary_transport_state_v1(state_zero, post_two),
    )
    reordered = deepcopy(post_one)
    reordered["ordered_body_ids"][0], reordered["ordered_body_ids"][1] = (
        reordered["ordered_body_ids"][1],
        reordered["ordered_body_ids"][0],
    )
    reordered["ordered_bodies"][0], reordered["ordered_bodies"][1] = (
        reordered["ordered_bodies"][1],
        reordered["ordered_bodies"][0],
    )
    _rehash(reordered)
    control(
        "reordered_bodies",
        "ORDERED_BODY_IDS",
        state_zero,
        lambda: advance_boundary_transport_state_v1(state_zero, reordered),
    )
    for identity_key, control_id in (
        ("arm_id", "crossed_arm"),
        ("attempt_id", "crossed_attempt"),
        ("model_instance_id", "crossed_model"),
    ):
        crossed = deepcopy(post_one)
        crossed[identity_key] = f"other-{identity_key}"
        _rehash(crossed)
        control(
            control_id,
            f"CROSSED_IDENTITY:{identity_key}",
            state_zero,
            lambda value=crossed: advance_boundary_transport_state_v1(state_zero, value),
        )
    wrong_callback = deepcopy(post_one)
    wrong_callback["ordered_bodies"][3]["callback_sequence"] = 2
    _rehash(wrong_callback)
    control(
        "callback_sequence_mismatch",
        "CALLBACK_SEQUENCE:3",
        state_zero,
        lambda: advance_boundary_transport_state_v1(state_zero, wrong_callback),
    )
    outcome_derived = deepcopy(post_one)
    outcome_derived["recovery_success"] = True
    _rehash(outcome_derived)
    control(
        "outcome_derived_input",
        "OUTCOME_DERIVED_INPUT",
        state_zero,
        lambda: advance_boundary_transport_state_v1(state_zero, outcome_derived),
    )
    mass_drift = deepcopy(post_one)
    mass_drift["ordered_bodies"][4]["mass_kg"] += 0.01
    _rehash(mass_drift)
    control(
        "mass_drift",
        "MASS_CONTINUITY:4",
        state_zero,
        lambda: advance_boundary_transport_state_v1(state_zero, mass_drift),
    )
    corrupt_payload = deepcopy(post_one)
    corrupt_payload["payload_sha256"] = "sha256:" + "0" * 64
    control(
        "payload_digest_mismatch",
        "PAYLOAD_SHA256",
        state_zero,
        lambda: advance_boundary_transport_state_v1(state_zero, corrupt_payload),
    )
    wrong_source = deepcopy(post_one)
    wrong_source["source_kind"] = INITIALIZER_SOURCE_KIND
    _rehash(wrong_source)
    control(
        "completed_boundary_wrong_source_kind",
        "BOUNDARY_SOURCE_KIND",
        state_zero,
        lambda: advance_boundary_transport_state_v1(state_zero, wrong_source),
    )

    return {
        "schema_version": (
            "sporespore_qsdk_r24d167_contiguous_boundary_transport_design_"
            "qualification_receipt_v1"
        ),
        "gate_id": "QSDK-R24D167",
        "ok": True,
        "transport_design_id": TRANSPORT_DESIGN_ID,
        "ordered_body_count": len(ORDERED_BODY_IDS),
        "ordered_body_ids": list(ORDERED_BODY_IDS),
        "initializer_boundary_sequence": 0,
        "accepted_sequence_pairs": [[0, 1], [1, 2]],
        "terminal_cached_boundary_sequence": 2,
        "terminal_accepted_pair_count": 2,
        "terminal_state_revision": 2,
        "successful_mapping_cache_advance_count_each": 1,
        "initializer_source_kind": INITIALIZER_SOURCE_KIND,
        "completed_step_source_kind": COMPLETED_STEP_SOURCE_KIND,
        "sequence_zero_initializer_consumed": True,
        "pre_values_from_cached_completed_boundary": True,
        "post_values_from_callback_coherent_completed_boundary": True,
        "successful_mapping_advances_cache_exactly_once": True,
        "cache_advance_occurs_only_after_complete_mapping": True,
        "rejected_transition_preserves_state": True,
        "source_event_payloads_content_addressed": True,
        "outcome_derived_input_permitted": False,
        "mutation_control_ids": mutation_ids,
        "positive_case_count": 6,
        "mutation_control_count": len(mutation_ids),
        "rejection_state_unchanged_count": len(mutation_ids),
        "model_construction_count": 0,
        "native_readback_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
