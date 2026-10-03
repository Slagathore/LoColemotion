"""Independent source proof for an active negative that ends before resume.

This is a completeness consumer, not a recovery policy or physics evaluator.
Only the two unchanged pre-resume terminal transitions are projected here.
All other state fields must survive byte-equivalent canonical source copies,
including JSON number kinds. No missing session is itself proof of failure.
"""

from __future__ import annotations

import copy
import re
from typing import Any, Callable

from qsdk_r10f_l14_terminal_consumers import SESSION_KEYS, same_source_value

ACTIVE = "kick_passive_recovery_resume"
PRECONDITION = "canonical_prone_precondition_recovery"
PREFIX = "fresh_selected_policy_walking_prefix"
INTERACTION = "native_kick_or_matched_no_kick_step"
CONFIRM = "kick_triggered_zero_actuation_passive_fall"
RECOVERY = "offset_bound_recovery_epoch"
O_ID = "sporespore_qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1"
O_SCHEMA_PREFIX = "sporespore_qsdk_r10f_event_triggered_passive_recovery_"
IDENTITY_KEYS = set(
    "orchestrator_id attempt_id arm_id model_instance_id frozen_configuration_sha256 "
    "body_population_instance_sha256 ordered_same_body_node_ids".split()
)
COUNTER_KEYS = set(
    "previous_global_semantic_step total_completed_solver_step_count "
    "precondition_recovery_step_count precondition_pair_wait_step_count "
    "precondition_pair_release_step_count walking_prefix_step_count "
    "interaction_effect_step_count confirm_prone_step_count consecutive_prone_sample_count "
    "post_kick_recovery_step_count recovery_epoch_step_count walking_resume_step_count "
    "matched_continuation_step_count state_revision".split()
)
ZERO_STATE_KEYS = set(
    "body_population_rebuild_count body_transform_write_count "
    "body_velocity_write_count solver_reset_count".split()
)
STATE_KEYS = (
    IDENTITY_KEYS
    | COUNTER_KEYS
    | ZERO_STATE_KEYS
    | set(
        "schema_version phase precondition_pair_ready epoch_start_global_step "
        "prefix_walking_session_id resume_or_continuation_session_id "
        "interaction_receipt_sha256 energy_initializer_sha256 terminal_outcome "
        "terminal_reason event_triggered_passive_recovery force_aware_recovery payload_sha256".split()
    )
)
EVENT_COUNTER_KEYS = set(
    "global_semantic_step recovery_epoch_local_step walking_session_local_step "
    "kick_application_count".split()
)
EVENT_BOOL_KEYS = set(
    "no_actuation_requested walking_actuation_applied recovery_actuation_applied "
    "stable_four_foot_stance prone_sample walking_motors_disabled_in_same_pre_solver_event "
    "walking_motors_enabled_during_interaction_solve source_measurement "
    "event_triggered_passive_recovery force_aware_recovery "
    "physical_acceptance_authority release_authority".split()
)
EVENT_KEYS = (
    IDENTITY_KEYS
    | EVENT_COUNTER_KEYS
    | EVENT_BOOL_KEYS
    | ZERO_STATE_KEYS
    | set(
        "schema_version source_phase event_kind control_owner actuation_owner "
        "application_intent_sha256 walking_session_id recovery_controller_terminal_phase "
        "recovery_controller_terminal_reason interaction_receipt_sha256 "
        "energy_initializer_sha256 payload_sha256".split()
    )
)
PURE_ZERO_KEYS = set(
    "model_construction_count native_readback_count world_attempt_count "
    "world_build_count solver_step_count".split()
)
ADVANCE_KEYS = PURE_ZERO_KEYS | set(
    "schema_version gate_id ok event_sha256 state_before_sha256 state_after "
    "state_after_sha256 source_phase next_phase global_semantic_step "
    "input_state_mutated physics_state_modified physical_acceptance_authority release_authority".split()
)
BODY_NODES = (
    ["body:torso"]
    + [
        "body:" + limb + part
        for limb in ("front_left", "front_right", "rear_left", "rear_right")
        for part in ("_upper", "_distal")
    ]
    + [
        "joint:" + limb + part
        for limb in ("front_left", "front_right", "rear_left", "rear_right")
        for part in ("_hip", "_knee")
    ]
)
WALKING_GATES = set(
    "bounded_anchor_error bounded_hinge_axis_error bounded_joint_only_lateral_stride_steering "
    "bounded_lateral_drift bounded_tilt bounded_torso_height bounded_yaw_drift "
    "contact_gated_evidence_horizon_completed contact_gating_completed_without_timeout "
    "every_contact_observer_executed every_limb_completed_evidence_gait_horizon "
    "every_limb_forward_relocation every_limb_two_contact_cycles evidence_four_contact_stance "
    "explicit_sdk_controller_session_shutdown fixture_spec_compiled_before_world_creation "
    "initial_four_contact_stance initial_perturbation_within_declared_envelope "
    "minimum_evidence_forward_translation minimum_final_forward_translation "
    "native_sdk_exclusive_post_settle_actuation "
    "no_torso_force_or_impulse_or_velocity_or_transform_command no_world_reset "
    "one_continuous_world pinned_jolt_solver_settings terminal_four_contact_recovery "
    "zero_torso_contact".split()
)
FIXED_THRESHOLDS = {
    "minimum_airborne_dwell_steps": 3,
    "minimum_foot_relocation_m": 0.012,
    "minimum_forward_advance_m": 0.02,
    "maximum_absolute_lateral_drift_m": 0.25,
    "maximum_yaw_drift_rad": 0.45,
    "maximum_tilt_rad": 0.60,
    "minimum_torso_height_m": 0.25,
    "maximum_anchor_error_m": 0.025,
    "maximum_hinge_axis_error_rad": 0.20,
}


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError("L14_NO_RESUME_" + code)


def integer(value: Any, low: int, high: int) -> bool:
    return type(value) is int and low <= value <= high


def digest(value: Any) -> bool:
    return (
        type(value) is str and re.fullmatch(r"sha256:[0-9a-f]{64}", value) is not None
    )


def _v2_native_count_matches(value: Any, expected: int) -> bool:
    # Exact counterpart of the already-qualified evaluator v2 native-summary
    # rule. This is not used for any host-owned state/event/trace counter and
    # introduces no tolerance or source-number rewriting.
    return type(value) in (int, float) and value == expected


def _object(value: Any, code: str, keys: set | None = None) -> dict:
    require(type(value) is dict, code + "_OBJECT")
    if keys is not None:
        require(set(value) == keys, code + "_KEYS")
    return value


def _available_payloads(value: Any, payload_sha256: Callable) -> None:
    """Recompute embedded payload digests without rewriting any source value."""
    if type(value) is dict:
        if "payload_sha256" in value:
            require(
                value["payload_sha256"] == payload_sha256(value),
                "EMBEDDED_PAYLOAD_DIGEST",
            )
        for child in value.values():
            _available_payloads(child, payload_sha256)
    elif type(value) is list:
        for child in value:
            _available_payloads(child, payload_sha256)


def _state(value: Any, identity: dict, payload_sha256: Callable) -> dict:
    value = _object(value, "STATE", STATE_KEYS)
    require(
        value["schema_version"] == O_SCHEMA_PREFIX + "state_v1"
        and all(same_source_value(value[k], v) for k, v in identity.items())
        and all(integer(value[k], 0, 3842) for k in COUNTER_KEYS)
        and all(type(value[k]) is int and value[k] == 0 for k in ZERO_STATE_KEYS)
        and value["precondition_pair_ready"] is True
        and value["event_triggered_passive_recovery"] is True
        and value["force_aware_recovery"] is False
        and integer(value["epoch_start_global_step"], 1, 3842)
        and digest(value["interaction_receipt_sha256"])
        and digest(value["energy_initializer_sha256"])
        and value["payload_sha256"] == payload_sha256(value),
        "STATE_SOURCE",
    )
    require(
        1 <= value["precondition_recovery_step_count"] <= 1200
        and value["precondition_pair_wait_step_count"] == 0
        and value["precondition_pair_release_step_count"] == 1
        and value["walking_prefix_step_count"] == 720
        and value["interaction_effect_step_count"] == 1
        and value["walking_resume_step_count"] == 0
        and value["matched_continuation_step_count"] == 0
        and value["resume_or_continuation_session_id"] == ""
        and type(value["prefix_walking_session_id"]) is str
        and bool(value["prefix_walking_session_id"])
        and value["epoch_start_global_step"]
        == value["precondition_recovery_step_count"] + 722
        and 0 <= value["confirm_prone_step_count"] <= 60
        and 0 <= value["consecutive_prone_sample_count"] <= 12
        and value["recovery_epoch_step_count"]
        == value["confirm_prone_step_count"] + value["post_kick_recovery_step_count"]
        and value["previous_global_semantic_step"]
        == value["epoch_start_global_step"] + value["recovery_epoch_step_count"]
        == value["total_completed_solver_step_count"]
        == value["state_revision"],
        "STATE_COUNTER_ACCOUNTING",
    )
    return value


def _terminal_successor(before: dict, event: dict, payload_sha256: Callable) -> dict:
    """Project only the unchanged terminal branches, preserving every other field."""
    expected = copy.deepcopy(before)
    expected["previous_global_semantic_step"] += 1
    expected["total_completed_solver_step_count"] += 1
    expected["state_revision"] += 1
    expected["recovery_epoch_step_count"] = event["recovery_epoch_local_step"]
    terminal_phase = event["recovery_controller_terminal_phase"]
    reason = event["recovery_controller_terminal_reason"]
    if before["phase"] == CONFIRM:
        require(before["post_kick_recovery_step_count"] == 0, "CONFIRM_POST_STEPS")
        require(before["consecutive_prone_sample_count"] < 12, "ALREADY_CONFIRMED")
        expected["confirm_prone_step_count"] += 1
        if terminal_phase in {"failed", "refused"}:
            pass  # The producer returns before updating consecutive prone samples.
        elif terminal_phase == "complete":
            reason = "recovery_completed_before_required_passive_prone_confirmation"
        else:
            expected["consecutive_prone_sample_count"] = (
                before["consecutive_prone_sample_count"] + 1
                if event["prone_sample"]
                else 0
            )
            require(
                expected["confirm_prone_step_count"] == 60
                and expected["consecutive_prone_sample_count"] < 12,
                "CONFIRM_NOT_FAILED_TERMINAL",
            )
            reason = "ventral_prone_confirmation_not_observed"
    else:
        require(
            12 <= before["confirm_prone_step_count"] <= 60
            and before["consecutive_prone_sample_count"] == 12
            and event["recovery_epoch_local_step"] <= 1200,
            "RECOVERY_ENTRY_OR_HORIZON",
        )
        expected["post_kick_recovery_step_count"] += 1
        if terminal_phase not in {"failed", "refused"}:
            require(
                terminal_phase == "" and event["recovery_epoch_local_step"] == 1200,
                "RECOVERY_NOT_FAILED_TERMINAL",
            )
            reason = "post_kick_recovery_epoch_timeout"
    expected.update(phase="failed", terminal_outcome="failed", terminal_reason=reason)
    expected["payload_sha256"] = payload_sha256(expected)
    return expected


def _observation_links(
    arm: dict,
    event: dict,
    after: dict,
    last_row: dict,
    step: dict,
    canonical_sha256: Callable,
    payload_sha256: Callable,
) -> None:
    sources = _object(
        arm.get("terminal_recovery_observation_sources"),
        "OBSERVATION_SOURCES",
        {"application_intent", "global_observation", "bound_recovery_observations"},
    )
    _available_payloads(sources, payload_sha256)
    application = _object(sources["application_intent"], "APPLICATION")
    global_observation = _object(sources["global_observation"], "GLOBAL_OBSERVATION")
    bound = _object(sources["bound_recovery_observations"], "RECOVERY_BOUND")
    require(
        bound.get("schema_version")
        == "sporespore_qsdk_r10f_recovery_epoch_bound_observations_v1"
        and bound.get("ok") is True
        and application.get("phase") == last_row.get("application_phase")
        and application.get("controller_owner") == last_row.get("control_owner")
        and same_source_value(
            application.get("semantic_step"), event["global_semantic_step"]
        )
        and application.get("no_actuation_requested") is event["no_actuation_requested"]
        and canonical_sha256(application)
        == event["application_intent_sha256"]
        == last_row.get("application_intent_sha256")
        and canonical_sha256(global_observation) == last_row.get("observation_sha256"),
        "APPLICATION_OR_GLOBAL_OBSERVATION_LINK",
    )
    for key in ("owner_source_receipt", "motor_population_readback"):
        if key in application:
            source = _object(application[key], "APPLICATION_" + key.upper())
            require(
                application.get(key + "_sha256") == canonical_sha256(source),
                "APPLICATION_SOURCE_DIGEST:" + key,
            )
    observations = [
        _object(bound.get("observation_v" + str(v)), "OBSERVATION_V" + str(v))
        for v in (2, 3)
    ]
    epoch = _object(bound.get("epoch_source_binding"), "EPOCH_BINDING")
    source_binding = _object(bound.get("source_binding"), "PORTABLE_BINDING")
    require(
        epoch.get("schema_version")
        == "sporespore_qsdk_r10f_recovery_epoch_observation_source_binding_v1"
        and epoch.get("source_measurement") is True
        and epoch.get("global_sequence_rewrite_permitted") is False
        and same_source_value(
            epoch.get("global_semantic_step"), event["global_semantic_step"]
        )
        and same_source_value(
            epoch.get("epoch_local_step"), event["recovery_epoch_local_step"]
        )
        and same_source_value(
            epoch.get("epoch_start_global_step"), after["epoch_start_global_step"]
        ),
        "EPOCH_SOURCE_CLOCKS",
    )
    global_base = {
        k: v
        for k, v in global_observation.items()
        if k not in {"schema_version", "energy_balance"}
    }
    require(
        global_observation.get("schema_version") == "sporespore_recovery_observation_v3"
        and same_source_value(
            global_observation.get("semantic_step"), event["global_semantic_step"]
        )
        and same_source_value(
            global_observation.get("engine_step_identity", {}).get("semantic_step"),
            event["global_semantic_step"],
        )
        and epoch.get("observation_base_sha256") == canonical_sha256(global_base),
        "GLOBAL_SOURCE_CLOCK_AND_BASE",
    )
    for version, observation in zip((2, 3), observations):
        base = {
            k: v
            for k, v in observation.items()
            if k not in {"schema_version", "energy_balance"}
        }
        require(
            observation.get("schema_version")
            == "sporespore_recovery_observation_v" + str(version)
            and same_source_value(base, global_base)
            and epoch.get("portable_observation_v" + str(version) + "_sha256")
            == canonical_sha256(observation)
            and epoch.get("ledger_v" + str(version) + "_sha256")
            == canonical_sha256(observation.get("energy_balance")),
            "REBASED_OBSERVATION_SOURCE_V" + str(version),
        )
    require(
        step.get("observation_sha256") == canonical_sha256(observations[1]),
        "RECOVERY_STEP_OBSERVATION",
    )
    binding_body = dict(source_binding)
    chain_sha = binding_body.pop("source_chain_sha256", None)
    require(
        source_binding.get("schema_version")
        == "sporespore_recovery_observation_v2_source_binding_v1"
        and chain_sha == canonical_sha256(binding_body)
        and source_binding.get("observation_base_sha256")
        == epoch["observation_base_sha256"]
        and source_binding.get("portable_observation_sha256")
        == epoch["portable_observation_v2_sha256"]
        and source_binding.get("ledger_sha256") == epoch["ledger_v2_sha256"],
        "PORTABLE_SOURCE_BINDING",
    )
    for key, binding_key in (
        ("energy_source_receipt", "source_values_sha256"),
        ("source_component_receipts", "source_component_receipts_sha256"),
        ("mapping_receipt", "mapping_receipt_sha256"),
    ):
        source = _object(bound.get(key), key.upper())
        require(
            epoch.get(binding_key) == canonical_sha256(source),
            "EPOCH_" + binding_key.upper(),
        )
        if binding_key != "source_values_sha256":
            require(
                source_binding.get(binding_key) == epoch[binding_key],
                "PORTABLE_" + binding_key.upper(),
            )
    components = bound["source_component_receipts"]
    initializer = _object(components.get("epoch_initializer"), "ENERGY_INITIALIZER")
    require(
        initializer.get("payload_sha256")
        == payload_sha256(initializer)
        == after["energy_initializer_sha256"]
        and same_source_value(
            initializer.get("epoch_start_global_step"), after["epoch_start_global_step"]
        )
        and initializer.get("schema_version")
        == "sporespore_qsdk_r10f_recovery_epoch_energy_initializer_v1"
        and initializer.get("attempt_id") == arm["child_attempt_id"]
        and initializer.get("arm_id") == ACTIVE
        and initializer.get("model_instance_id") == arm["model_instance_id"]
        and initializer.get("kick_interaction_receipt_sha256")
        == after["interaction_receipt_sha256"]
        and initializer.get("source_measurement") is True
        and initializer.get("global_counters_mutated") is False
        and initializer.get("force_aware_recovery_used") is False
        and initializer.get("physical_acceptance_authority") is False
        and initializer.get("release_authority") is False,
        "ENERGY_INITIALIZER_LINK",
    )
    # Reopen component payloads that are actually retained, never accept a
    # claimed digest in place of its available source object.
    for key, source in components.items():
        hash_key = key + "_sha256"
        if type(source) is dict and hash_key in components:
            expected_hash = (
                payload_sha256(source)
                if key == "epoch_initializer"
                else canonical_sha256(source)
            )
            require(components[hash_key] == expected_hash, "COMPONENT_SOURCE:" + key)
    source = bound["energy_source_receipt"]
    require(
        source.get("epoch_initializer_sha256") == after["energy_initializer_sha256"]
        and source.get("kick_interaction_receipt_sha256")
        == after["interaction_receipt_sha256"]
        and same_source_value(
            source.get("global_semantic_step"), event["global_semantic_step"]
        )
        and same_source_value(
            source.get("epoch_local_step"), event["recovery_epoch_local_step"]
        ),
        "ENERGY_SOURCE_IDENTITY_AND_CLOCKS",
    )


def validate_no_resume_terminal(
    report: dict,
    *,
    canonical_sha256: Callable,
    payload_sha256: Callable,
    native_step_matches: Callable,
) -> dict:
    arm = _object(report.get("arm_result"), "ARM")
    require(
        report.get("arm_id") == ACTIVE
        and arm.get("arm_id") == ACTIVE
        and report.get("role_outcome") == "behavior_negative"
        and report.get("reached_walking_prefix") is True
        and report.get("reached_interaction") is True
        and report.get("reached_walking_resume") is False,
        "ROLE_OUTCOME",
    )
    identity = {
        "orchestrator_id": O_ID,
        "attempt_id": report["child_attempt_id"],
        "arm_id": ACTIVE,
        "model_instance_id": arm["model_instance_id"],
        "frozen_configuration_sha256": report["configuration_sha256"],
        "body_population_instance_sha256": arm["body_population_instance_sha256"],
        "ordered_same_body_node_ids": BODY_NODES,
    }
    transition = _object(
        arm.get("terminal_orchestrator_transition"),
        "TRANSITION",
        {"state_before", "event", "advance_receipt"},
    )
    before = _state(transition["state_before"], identity, payload_sha256)
    advance = _object(transition["advance_receipt"], "ADVANCE", ADVANCE_KEYS)
    after = _state(advance["state_after"], identity, payload_sha256)
    event = _object(transition["event"], "EVENT", EVENT_KEYS)
    require(
        before["phase"] in {CONFIRM, RECOVERY}
        and before["terminal_outcome"] == before["terminal_reason"] == ""
        and all(same_source_value(event[k], v) for k, v in identity.items())
        and event["schema_version"] == O_SCHEMA_PREFIX + "event_v1"
        and all(integer(event[k], 0, 3842) for k in EVENT_COUNTER_KEYS)
        and all(type(event[k]) is bool for k in EVENT_BOOL_KEYS)
        and all(type(event[k]) is int and event[k] == 0 for k in ZERO_STATE_KEYS)
        and event["source_phase"] == before["phase"]
        and event["global_semantic_step"] == before["previous_global_semantic_step"] + 1
        and event["recovery_epoch_local_step"]
        == before["recovery_epoch_step_count"] + 1
        and event["event_kind"]
        == (
            "passive_prone_observation"
            if before["phase"] == CONFIRM
            else "recovery_controller_step"
        )
        and event["control_owner"] == "recovery_v6"
        and event["actuation_owner"]
        == ("none" if event["no_actuation_requested"] else "recovery_v6")
        and event["walking_actuation_applied"] is False
        and event["recovery_actuation_applied"] is (not event["no_actuation_requested"])
        and (before["phase"] != CONFIRM or event["no_actuation_requested"] is True)
        and event["walking_session_id"] == ""
        and event["walking_session_local_step"] == 0
        and event["kick_application_count"] == 0
        and event["interaction_receipt_sha256"] == ""
        and event["energy_initializer_sha256"] == before["energy_initializer_sha256"]
        and event["walking_motors_disabled_in_same_pre_solver_event"] is False
        and event["walking_motors_enabled_during_interaction_solve"] is False
        and event["source_measurement"] is True
        and event["event_triggered_passive_recovery"] is True
        and event["force_aware_recovery"] is False
        and event["physical_acceptance_authority"] is False
        and event["release_authority"] is False
        and digest(event["application_intent_sha256"])
        and event["payload_sha256"] == payload_sha256(event),
        "EVENT_SOURCE",
    )
    terminal_kind = event["recovery_controller_terminal_phase"]
    reason = event["recovery_controller_terminal_reason"]
    require(
        terminal_kind in {"", "failed", "refused", "complete"}
        and type(reason) is str
        and (bool(reason) if terminal_kind in {"failed", "refused"} else reason == ""),
        "EVENT_TERMINAL_KIND",
    )
    require(
        same_source_value(after, _terminal_successor(before, event, payload_sha256)),
        "TERMINAL_TRANSITION",
    )
    expected_advance = {
        "schema_version": O_SCHEMA_PREFIX + "advance_v1",
        "gate_id": "QSDK-R10F",
        "ok": True,
        "event_sha256": event["payload_sha256"],
        "state_before_sha256": before["payload_sha256"],
        "state_after": after,
        "state_after_sha256": after["payload_sha256"],
        "source_phase": before["phase"],
        "next_phase": "failed",
        "global_semantic_step": event["global_semantic_step"],
        "input_state_mutated": False,
        **{k: 0 for k in PURE_ZERO_KEYS},
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    require(same_source_value(advance, expected_advance), "ADVANCE_SOURCE")
    require(
        same_source_value(arm.get("final_orchestrator_state"), after)
        and arm.get("final_phase") == "failed"
        and arm.get("terminal_reason") == after["terminal_reason"]
        and same_source_value(
            report.get("solver_step_count"), after["total_completed_solver_step_count"]
        )
        and report.get("reached_post_kick_recovery")
        is (after["post_kick_recovery_step_count"] > 0),
        "FINAL_SOURCE_LINKS",
    )
    sessions = arm.get("walking_sessions")
    handoffs = arm.get("walking_actuation_handoff_receipts")
    require(
        type(sessions) is list
        and len(sessions) == 1
        and type(handoffs) is list
        and len(handoffs) == 1,
        "PREFIX_POPULATION",
    )
    prefix = _object(sessions[0], "PREFIX", SESSION_KEYS)
    require(
        prefix.get("evaluation_segment_id") == "walking_prefix"
        and prefix.get("session_id") == after["prefix_walking_session_id"],
        "PREFIX_IDENTITY",
    )
    evaluation = _object(prefix.get("evaluation"), "PREFIX_EVALUATION")
    completion = _object(prefix.get("completion_receipt"), "PREFIX_COMPLETION")
    summary = _object(completion.get("adapter_summary"), "PREFIX_SUMMARY")
    shutdown = _object(completion.get("adapter_shutdown_receipt"), "PREFIX_SHUTDOWN")
    require(
        summary.get("ok") is True
        and _v2_native_count_matches(summary.get("step_count"), 720)
        and summary.get("controller_policy_id") == "sporespore_balanced_wave_bw5r_b_v1"
        and shutdown.get("ok") is True
        and shutdown.get("explicit_shutdown_completed") is True
        and _v2_native_count_matches(
            shutdown.get("native_controller_session_destroy_count"), 1
        ),
        "PREFIX_COMPLETED_SESSION_SOURCE",
    )
    gates = _object(
        evaluation.get("walking_gate_receipts"), "PREFIX_GATES", WALKING_GATES
    )
    evaluation_body = dict(evaluation, payload_sha256="")
    require(
        evaluation.get("schema_version")
        == "sporespore_qsdk_r10f_walking_segment_evaluation_v2"
        and evaluation.get("evaluator_id")
        == "sporespore_qsdk_r10f_fixed_walking_segment_evaluator_v2"
        and evaluation.get("session_id") == prefix["session_id"]
        and evaluation.get("ok") is True
        and evaluation.get("evidence_valid") is True
        and evaluation.get("outcome_complete") is True
        and evaluation.get("behavior_passed") is all(gates.values())
        and all(type(v) is bool for v in gates.values())
        and evaluation.get("false_walking_receipts")
        == sorted(k for k, v in gates.items() if not v)
        and same_source_value(evaluation.get("trace_row_count"), 720)
        and same_source_value(evaluation.get("walking_receipt_count"), 27)
        and same_source_value(evaluation.get("fixed_thresholds"), FIXED_THRESHOLDS)
        and evaluation.get("payload_sha256") == canonical_sha256(evaluation_body)
        and type(prefix.get("step_receipt_sha256s")) is list
        and len(prefix["step_receipt_sha256s"]) == 720
        and all(digest(v) for v in prefix["step_receipt_sha256s"]),
        "PREFIX_COMPLETE_FIXED_EVALUATION",
    )
    epoch_start = after["epoch_start_global_step"]
    interaction = _object(arm.get("interaction_receipt"), "INTERACTION_RECEIPT")
    require(
        interaction.get("payload_sha256")
        == payload_sha256(interaction)
        == after["interaction_receipt_sha256"]
        and interaction.get("schema_version")
        == "sporespore_qsdk_r10f_kick_or_matched_no_kick_interaction_receipt_v1"
        and interaction.get("attempt_id") == report["child_attempt_id"]
        and interaction.get("arm_id") == ACTIVE
        and interaction.get("model_instance_id") == arm["model_instance_id"]
        and interaction.get("interaction_kind") == "kick_impulse"
        and same_source_value(interaction.get("application_global_step"), epoch_start)
        and same_source_value(
            interaction.get("completed_effect_global_step"), epoch_start
        )
        and same_source_value(interaction.get("application_count"), 1)
        and interaction.get("source_measurement") is True
        and interaction.get("force_aware_recovery_used") is False
        and interaction.get("physical_acceptance_authority") is False
        and interaction.get("release_authority") is False
        and same_source_value(
            report.get("interaction_source", {}).get("completed_effect_global_step"),
            epoch_start,
        )
        and same_source_value(
            prefix.get("start_receipt", {}).get("global_start_step"), epoch_start - 721
        )
        and same_source_value(
            handoffs[0].get("global_semantic_step"), epoch_start - 720
        ),
        "PREFIX_INTERACTION_ORDER",
    )
    rows = arm.get("trace", {}).get("rows")
    require(
        type(rows) is list and len(rows) == event["global_semantic_step"],
        "TRACE_POPULATION",
    )
    precondition_steps = after["precondition_recovery_step_count"]
    confirm_end = epoch_start + after["confirm_prone_step_count"]
    for global_step, row in enumerate(rows, 1):
        row = _object(row, "ROW")
        phase = (
            PRECONDITION
            if global_step <= precondition_steps + 1
            else (
                PREFIX
                if global_step < epoch_start
                else (
                    INTERACTION
                    if global_step == epoch_start
                    else (CONFIRM if global_step <= confirm_end else RECOVERY)
                )
            )
        )
        require(
            row.get("schema_version")
            == "sporespore_qsdk_r10f_compact_native_trace_row_v1"
            and row.get("source_measurement") is True
            and row.get("arm_id") == ACTIVE
            and row.get("body_population_instance_sha256")
            == identity["body_population_instance_sha256"]
            and same_source_value(row.get("global_semantic_step"), global_step)
            and row.get("orchestrator_phase") == phase
            and same_source_value(
                row.get("recovery_epoch_local_step"),
                None if global_step < epoch_start else global_step - epoch_start,
            )
            and row.get("walking_segment_id")
            == ("walking_prefix" if phase == PREFIX else "")
            and row.get("walking_session_id")
            == (prefix["session_id"] if phase == PREFIX else "")
            and same_source_value(
                row.get("walking_session_local_step"),
                global_step - precondition_steps - 1 if phase == PREFIX else 0,
            ),
            "TRACE_PHASE_OR_SESSION:" + str(global_step),
        )
    steps = arm.get("recovery_step_receipts")
    require(
        type(steps) is list
        and len(steps) == precondition_steps + after["recovery_epoch_step_count"],
        "RECOVERY_STEP_POPULATION",
    )
    step = _object(steps[-1], "FINAL_RECOVERY_STEP")
    memory = _object(arm.get("final_recovery_memory"), "FINAL_MEMORY")
    native_memory = _object(step.get("memory"), "STEP_MEMORY")
    classification = _object(step.get("classification"), "CLASSIFICATION")
    require(
        step.get("schema_version") == "sporespore_recovery_step_receipt_v1"
        and step.get("support_status") == "supported_exact"
        and step.get("refusal_reason") is None
        and step.get("post_step_observation_only") is True
        and step.get("phase_skip_permitted") is False
        and step.get("controller_implemented") is True
        and step.get("synthetic_canary_semantics_executed") is False
        and memory.get("schema_version") == "sporespore_recovery_supervisor_memory_v1"
        and same_source_value(memory, native_memory)
        # The core receives the unchanged GLOBAL observation semantic_step.
        # total_steps_observed is epoch-local; last_semantic_step is not.
        and native_step_matches(
            memory.get("last_semantic_step"),
            native_memory.get("last_semantic_step"),
            event["global_semantic_step"],
        )
        and native_step_matches(
            memory.get("start_semantic_step"),
            native_memory.get("start_semantic_step"),
            after["epoch_start_global_step"] + 1,
        )
        and native_step_matches(
            memory.get("total_steps_observed"),
            native_memory.get("total_steps_observed"),
            after["recovery_epoch_step_count"],
        )
        and step.get("next_phase") == memory.get("phase")
        and same_source_value(classification, rows[-1].get("recovery_classification"))
        and classification.get("stable_stance_gate") is event["stable_four_foot_stance"]
        and classification.get("entry_prone_gate") is event["prone_sample"]
        and rows[-1].get("no_actuation_requested") is event["no_actuation_requested"]
        and rows[-1].get("application_phase") == step.get("prior_phase"),
        "FINAL_MEMORY_AND_CLASSIFICATION",
    )
    memory_phase = memory.get("phase")
    require(
        (
            memory_phase == terminal_kind
            if terminal_kind
            else memory_phase
            in {
                "confirm_prone",
                "establish_distal_support",
                "raise_body",
                "stance_handoff",
                "stance_dwell",
            }
        )
        and (
            memory.get("terminal_failure_code") == reason
            if terminal_kind in {"failed", "refused"}
            else memory.get("terminal_failure_code") in (None, "")
        )
        and memory.get("physical_acceptance_authority") is False
        and memory.get("release_authority") is False
        and step.get("physical_acceptance_authority") is False
        and step.get("release_authority") is False
        and step.get("physics_state_modified") is False
        and memory.get("physics_state_modified") is False,
        "MEMORY_TERMINAL_KIND_OR_AUTHORITY",
    )
    _observation_links(
        arm, event, after, rows[-1], step, canonical_sha256, payload_sha256
    )
    return {
        "schema_version": "sporespore_qsdk_r10f_l14_source_proven_no_resume_negative_v1",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "independently_validated_terminal_source_completeness",
            "question_class": "development",
        },
        "source_proven_no_resume_negative": True,
        "terminal_source_phase": before["phase"],
        "terminal_reason": after["terminal_reason"],
        "terminal_transition_sha256": canonical_sha256(transition),
        "terminal_recovery_observation_sources_sha256": canonical_sha256(
            arm["terminal_recovery_observation_sources"]
        ),
        "terminal_global_semantic_step": event["global_semantic_step"],
        "terminal_recovery_epoch_local_step": event["recovery_epoch_local_step"],
        "completed_prefix_step_count": 720,
        "walking_resume_step_count": 0,
        "expected_walking_segments": ["walking_prefix"],
        "recovery_success_observed": False,
        "source_values_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
