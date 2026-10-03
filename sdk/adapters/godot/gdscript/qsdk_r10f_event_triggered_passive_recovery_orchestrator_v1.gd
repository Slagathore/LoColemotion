class_name SporeQsdkR10fEventTriggeredPassiveRecoveryOrchestratorV1
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-file-lines

## Pure phase authority for one continuous R10F body population.
##
## The state machine owns ordering and claim boundaries only. It never creates
## a Node, reads native state, writes a motor/body, or advances a solver. Live
## workers must first obtain source receipts, then submit one content-addressed
## event per completed global solver step.

const LocomotionFacade := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
)
const EnergyInitializer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")

const GATE_ID := "QSDK-R10F"
const ORCHESTRATOR_ID := "sporespore_qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1"
const STATE_SCHEMA := "sporespore_qsdk_r10f_event_triggered_passive_recovery_state_v1"
const EVENT_SCHEMA := "sporespore_qsdk_r10f_event_triggered_passive_recovery_event_v1"
const INITIALIZATION_SCHEMA := "sporespore_qsdk_r10f_event_triggered_passive_recovery_initialization_v1"
const ADVANCE_SCHEMA := "sporespore_qsdk_r10f_event_triggered_passive_recovery_advance_v1"
const LOCKSTEP_PAIR_PLAN_SCHEMA := "sporespore_qsdk_r10f_isolated_own_world_3d_lockstep_pair_plan_v1"
const FAILURE_SCHEMA := "sporespore_qsdk_r10f_event_triggered_passive_recovery_failure_v1"

const PHASE_PRECONDITION_RECOVERY := "canonical_prone_precondition_recovery"
const PHASE_WALKING_PREFIX := "fresh_selected_policy_walking_prefix"
const PHASE_INTERACTION := "native_kick_or_matched_no_kick_step"
const PHASE_CONFIRM_PRONE := "kick_triggered_zero_actuation_passive_fall"
const PHASE_POST_KICK_RECOVERY := "offset_bound_recovery_epoch"
const PHASE_WALKING_RESUME := "fresh_selected_policy_walking_resume"
const PHASE_MATCHED_CONTINUATION := "matched_no_kick_continuation"
const PHASE_COMPLETE := "complete"
const PHASE_FAILED := "failed"

const MAXIMUM_PRECONDITION_RECOVERY_STEPS := 1200
const WALKING_PREFIX_STEPS := 720
const MAXIMUM_CONFIRM_PRONE_STEPS := 60
const REQUIRED_CONSECUTIVE_PRONE_SAMPLES := 12
const MAXIMUM_POST_KICK_RECOVERY_EPOCH_STEPS := 1200
const WALKING_RESUME_STEPS := 720
const MAXIMUM_PRECONDITION_PAIR_WAIT_STEPS := 1199
const PRECONDITION_PAIR_RELEASE_STEPS := 1
const MAXIMUM_ACTIVE_ARM_SOLVER_STEPS := 3842

const STATE_KEYS := [
	"schema_version",
	"orchestrator_id",
	"attempt_id",
	"arm_id",
	"model_instance_id",
	"frozen_configuration_sha256",
	"body_population_instance_sha256",
	"ordered_same_body_node_ids",
	"phase",
	"previous_global_semantic_step",
	"total_completed_solver_step_count",
	"precondition_recovery_step_count",
	"precondition_pair_ready",
	"precondition_pair_wait_step_count",
	"precondition_pair_release_step_count",
	"walking_prefix_step_count",
	"interaction_effect_step_count",
	"confirm_prone_step_count",
	"consecutive_prone_sample_count",
	"post_kick_recovery_step_count",
	"recovery_epoch_step_count",
	"walking_resume_step_count",
	"matched_continuation_step_count",
	"epoch_start_global_step",
	"prefix_walking_session_id",
	"resume_or_continuation_session_id",
	"interaction_receipt_sha256",
	"energy_initializer_sha256",
	"state_revision",
	"terminal_outcome",
	"terminal_reason",
	"event_triggered_passive_recovery",
	"force_aware_recovery",
	"body_population_rebuild_count",
	"body_transform_write_count",
	"body_velocity_write_count",
	"solver_reset_count",
	"payload_sha256",
]
const EVENT_KEYS := [
	"schema_version",
	"orchestrator_id",
	"attempt_id",
	"arm_id",
	"model_instance_id",
	"frozen_configuration_sha256",
	"body_population_instance_sha256",
	"ordered_same_body_node_ids",
	"source_phase",
	"event_kind",
	"global_semantic_step",
	"recovery_epoch_local_step",
	"control_owner",
	"actuation_owner",
	"no_actuation_requested",
	"application_intent_sha256",
	"walking_session_id",
	"walking_session_local_step",
	"walking_actuation_applied",
	"recovery_actuation_applied",
	"stable_four_foot_stance",
	"prone_sample",
	"recovery_controller_terminal_phase",
	"recovery_controller_terminal_reason",
	"interaction_receipt_sha256",
	"energy_initializer_sha256",
	"kick_application_count",
	"walking_motors_disabled_in_same_pre_solver_event",
	"walking_motors_enabled_during_interaction_solve",
	"body_population_rebuild_count",
	"body_transform_write_count",
	"body_velocity_write_count",
	"solver_reset_count",
	"source_measurement",
	"event_triggered_passive_recovery",
	"force_aware_recovery",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]


static func initialize_v1(
	sdk: Object,
	attempt_id: String,
	arm_id: String,
	model_instance_id: String,
	frozen_configuration_sha256: String,
	body_population_instance_sha256: String,
	starting_global_semantic_step: int = 0,
) -> Dictionary:
	if (
		sdk == null
		or attempt_id.is_empty()
		or not [EnergyInitializer.ACTIVE_ARM_ID, EnergyInitializer.BASELINE_ARM_ID].has(arm_id)
		or model_instance_id.is_empty()
		or not _digest_valid_v1(frozen_configuration_sha256)
		or not _digest_valid_v1(body_population_instance_sha256)
		or starting_global_semantic_step < 0
	):
		return _failure("QSDK_R10F_ORCHESTRATOR_INITIALIZATION_INPUT_INVALID")
	var state := {
		"schema_version": STATE_SCHEMA,
		"orchestrator_id": ORCHESTRATOR_ID,
		"attempt_id": attempt_id,
		"arm_id": arm_id,
		"model_instance_id": model_instance_id,
		"frozen_configuration_sha256": frozen_configuration_sha256,
		"body_population_instance_sha256": body_population_instance_sha256,
		"ordered_same_body_node_ids": LocomotionFacade.SAME_BODY_NODE_IDENTITY.duplicate(),
		"phase": PHASE_PRECONDITION_RECOVERY,
		"previous_global_semantic_step": starting_global_semantic_step,
		"total_completed_solver_step_count": 0,
		"precondition_recovery_step_count": 0,
		"precondition_pair_ready": false,
		"precondition_pair_wait_step_count": 0,
		"precondition_pair_release_step_count": 0,
		"walking_prefix_step_count": 0,
		"interaction_effect_step_count": 0,
		"confirm_prone_step_count": 0,
		"consecutive_prone_sample_count": 0,
		"post_kick_recovery_step_count": 0,
		"recovery_epoch_step_count": 0,
		"walking_resume_step_count": 0,
		"matched_continuation_step_count": 0,
		"epoch_start_global_step": null,
		"prefix_walking_session_id": "",
		"resume_or_continuation_session_id": "",
		"interaction_receipt_sha256": "",
		"energy_initializer_sha256": "",
		"state_revision": 0,
		"terminal_outcome": "",
		"terminal_reason": "",
		"event_triggered_passive_recovery": true,
		"force_aware_recovery": false,
		"body_population_rebuild_count": 0,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
		"payload_sha256": "",
	}
	state["payload_sha256"] = _payload_sha256_v1(sdk, state)
	if not state_valid_v1(sdk, state):
		return _failure("QSDK_R10F_ORCHESTRATOR_INITIAL_STATE_INVALID")
	return {
		"schema_version": INITIALIZATION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"state": state,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Normalize a caller-supplied event payload under the exact immutable state
## identity. This helper is usable by zero-world tests and by the live worker
## after it has collected the underlying source receipts.
static func build_event_v1(
	sdk: Object,
	state: Dictionary,
	fields: Dictionary,
) -> Dictionary:
	if not state_valid_v1(sdk, state):
		return _failure("QSDK_R10F_ORCHESTRATOR_EVENT_STATE_INVALID")
	return _build_event_for_shape_v1(sdk, state, fields, EVENT_SCHEMA, ORCHESTRATOR_ID, EVENT_KEYS)


## Shared field construction only. The caller validates its own state schema;
## historical build_event_v1 above remains closed to successor states.
static func _build_event_for_shape_v1(
	sdk: Object, state: Dictionary, fields: Dictionary, event_schema: String,
	orchestrator_id: String, event_keys: Array, extra_fields: Dictionary = {},
	expected_recovery_owner: String = "recovery_v6",
	expected_walking_owner: String = "walking_bw5r_b",
) -> Dictionary:
	var event := {
		"schema_version": event_schema,
		"orchestrator_id": orchestrator_id,
		"attempt_id": String(state["attempt_id"]),
		"arm_id": String(state["arm_id"]),
		"model_instance_id": String(state["model_instance_id"]),
		"frozen_configuration_sha256": String(state["frozen_configuration_sha256"]),
		"body_population_instance_sha256": String(state["body_population_instance_sha256"]),
		"ordered_same_body_node_ids": LocomotionFacade.SAME_BODY_NODE_IDENTITY.duplicate(),
		"source_phase": String(state["phase"]),
		"event_kind": String(fields.get("event_kind", "")),
		"global_semantic_step": int(fields.get("global_semantic_step", -1)),
		"recovery_epoch_local_step": int(fields.get("recovery_epoch_local_step", 0)),
		"control_owner": String(fields.get("control_owner", "none")),
		"actuation_owner": String(fields.get("actuation_owner", "none")),
		"no_actuation_requested": bool(fields.get("no_actuation_requested", false)),
		"application_intent_sha256": String(fields.get("application_intent_sha256", "")),
		"walking_session_id": String(fields.get("walking_session_id", "")),
		"walking_session_local_step": int(fields.get("walking_session_local_step", 0)),
		"walking_actuation_applied": bool(fields.get("walking_actuation_applied", false)),
		"recovery_actuation_applied": bool(fields.get("recovery_actuation_applied", false)),
		"stable_four_foot_stance": bool(fields.get("stable_four_foot_stance", false)),
		"prone_sample": bool(fields.get("prone_sample", false)),
		"recovery_controller_terminal_phase":
		String(fields.get("recovery_controller_terminal_phase", "")),
		"recovery_controller_terminal_reason":
		String(fields.get("recovery_controller_terminal_reason", "")),
		"interaction_receipt_sha256": String(fields.get("interaction_receipt_sha256", "")),
		"energy_initializer_sha256": String(fields.get("energy_initializer_sha256", "")),
		"kick_application_count": int(fields.get("kick_application_count", 0)),
		"walking_motors_disabled_in_same_pre_solver_event":
		bool(fields.get("walking_motors_disabled_in_same_pre_solver_event", false)),
		"walking_motors_enabled_during_interaction_solve":
		bool(fields.get("walking_motors_enabled_during_interaction_solve", false)),
		"body_population_rebuild_count": int(fields.get("body_population_rebuild_count", 0)),
		"body_transform_write_count": int(fields.get("body_transform_write_count", 0)),
		"body_velocity_write_count": int(fields.get("body_velocity_write_count", 0)),
		"solver_reset_count": int(fields.get("solver_reset_count", 0)),
		"source_measurement": bool(fields.get("source_measurement", true)),
		"event_triggered_passive_recovery":
		bool(fields.get("event_triggered_passive_recovery", true)),
		"force_aware_recovery": bool(fields.get("force_aware_recovery", false)),
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	for key in extra_fields:
		if event.has(key):
			return _failure("QSDK_R10F_ORCHESTRATOR_EXTRA_FIELD_COLLISION")
		event[key] = extra_fields[key]
	event["payload_sha256"] = _payload_sha256_v1(sdk, event)
	if not _event_valid_shape_v1(sdk, event, event_keys, event_schema, orchestrator_id, expected_recovery_owner, expected_walking_owner):
		return _failure("QSDK_R10F_ORCHESTRATOR_EVENT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r10f_event_triggered_passive_recovery_event_build_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"event": event,
		"event_sha256": String(event["payload_sha256"]),
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func advance_v1(
	sdk: Object,
	state: Dictionary,
	event: Dictionary,
) -> Dictionary:
	return _advance_with_prefix_v1(sdk, state, event, WALKING_PREFIX_STEPS)


## Diagnostic entrypoint only. Canonical advance_v1 always keeps 720 steps.
## The enclosing smoke report has a distinct schema and never claims a route.
static func advance_development_smoke_v1(
	sdk: Object, state: Dictionary, event: Dictionary
) -> Dictionary:
	var result := _advance_with_prefix_v1(sdk, state, event, 30)
	result["schema_version"] = "sporespore_development_smoke_orchestrator_advance_v1"
	result["development_smoke_only"] = true
	result["complete_route_proven"] = false
	return result


static func _advance_with_prefix_v1(
	sdk: Object, state: Dictionary, event: Dictionary, prefix_steps: int
) -> Dictionary:
	if not state_valid_v1(sdk, state):
		return _failure("QSDK_R10F_ORCHESTRATOR_STATE_INVALID")
	if not event_valid_v1(sdk, event):
		return _failure("QSDK_R10F_ORCHESTRATOR_EVENT_INVALID")
	if String(state["phase"]) in [PHASE_COMPLETE, PHASE_FAILED]:
		return _failure("QSDK_R10F_ORCHESTRATOR_ALREADY_TERMINAL")
	for identity_key in [
		"orchestrator_id",
		"attempt_id",
		"arm_id",
		"model_instance_id",
		"frozen_configuration_sha256",
		"body_population_instance_sha256",
	]:
		if state.get(identity_key) != event.get(identity_key):
			return _failure("QSDK_R10F_ORCHESTRATOR_CROSSED_IDENTITY:%s" % identity_key)
	if (
		String(event["source_phase"]) != String(state["phase"])
		or event["ordered_same_body_node_ids"] != state["ordered_same_body_node_ids"]
		or int(event["global_semantic_step"]) != int(state["previous_global_semantic_step"]) + 1
		or int(event["body_population_rebuild_count"]) != 0
		or int(event["body_transform_write_count"]) != 0
		or int(event["body_velocity_write_count"]) != 0
		or int(event["solver_reset_count"]) != 0
		or not bool(event["source_measurement"])
		or not bool(event["event_triggered_passive_recovery"])
		or bool(event["force_aware_recovery"])
	):
		return _failure("QSDK_R10F_ORCHESTRATOR_COMMON_EVENT_INVARIANT")

	var successor := state.duplicate(true)
	successor["previous_global_semantic_step"] = int(event["global_semantic_step"])
	successor["total_completed_solver_step_count"] = (
		int(state["total_completed_solver_step_count"]) + 1
	)
	successor["state_revision"] = int(state["state_revision"]) + 1
	var phase := String(state["phase"])
	var phase_failure := ""
	if phase == PHASE_PRECONDITION_RECOVERY:
		phase_failure = _advance_precondition_v1(successor, event)
	elif phase == PHASE_WALKING_PREFIX:
		phase_failure = _advance_walking_prefix_v1(successor, event, prefix_steps)
	elif phase == PHASE_INTERACTION:
		phase_failure = _advance_interaction_v1(successor, event)
	elif phase == PHASE_CONFIRM_PRONE:
		phase_failure = _advance_confirm_prone_v1(successor, event)
	elif phase == PHASE_POST_KICK_RECOVERY:
		phase_failure = _advance_post_kick_recovery_v1(successor, event)
	elif phase == PHASE_WALKING_RESUME:
		phase_failure = _advance_walking_resume_v1(successor, event)
	elif phase == PHASE_MATCHED_CONTINUATION:
		phase_failure = _advance_matched_continuation_v1(successor, event)
	else:
		phase_failure = "QSDK_R10F_ORCHESTRATOR_UNKNOWN_PHASE"
	if not phase_failure.is_empty():
		return _failure(phase_failure)
	if (
		String(state["arm_id"]) == EnergyInitializer.ACTIVE_ARM_ID
		and int(successor["total_completed_solver_step_count"]) > MAXIMUM_ACTIVE_ARM_SOLVER_STEPS
	):
		return _failure("QSDK_R10F_ORCHESTRATOR_ACTIVE_HORIZON_EXCEEDED")
	successor["payload_sha256"] = ""
	successor["payload_sha256"] = _payload_sha256_v1(sdk, successor)
	if not state_valid_v1(sdk, successor):
		return _failure("QSDK_R10F_ORCHESTRATOR_SUCCESSOR_STATE_INVALID")
	return {
		"schema_version": ADVANCE_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"event_sha256": String(event["payload_sha256"]),
		"state_before_sha256": String(state["payload_sha256"]),
		"state_after": successor,
		"state_after_sha256": String(successor["payload_sha256"]),
		"source_phase": phase,
		"next_phase": String(successor["phase"]),
		"global_semantic_step": int(event["global_semantic_step"]),
		"input_state_mutated": false,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Pure execution topology selected before either physical world is built.
## Each arm owns a distinct SubViewport/World3D physics space, while the host
## advances both spaces on the same global physics frames. Independently
## measured V6 precondition terminals may occur on different frames; a separate
## source-bound pair barrier keeps the early arm stepping with motors disabled
## and gives both arms one common no-actuation release frame. The eventual
## active terminal frame still closes both arms, so the final horizon is equal
## without a snapshot, replay, third world, or hindsight-selected rerun.
static func isolated_lockstep_pair_plan_v1(
	sdk: Object,
	active_initial_state: Dictionary,
	baseline_initial_state: Dictionary,
) -> Dictionary:
	if (
		sdk == null
		or not state_valid_v1(sdk, active_initial_state)
		or not state_valid_v1(sdk, baseline_initial_state)
		or String(active_initial_state.get("arm_id", "")) != EnergyInitializer.ACTIVE_ARM_ID
		or String(baseline_initial_state.get("arm_id", "")) != EnergyInitializer.BASELINE_ARM_ID
		or (
			String(active_initial_state.get("attempt_id", ""))
			!= String(baseline_initial_state.get("attempt_id", ""))
		)
		or (
			String(active_initial_state.get("frozen_configuration_sha256", ""))
			!= String(baseline_initial_state.get("frozen_configuration_sha256", ""))
		)
		or (
			String(active_initial_state.get("model_instance_id", ""))
			== String(baseline_initial_state.get("model_instance_id", ""))
		)
		or (
			String(active_initial_state.get("body_population_instance_sha256", ""))
			== String(baseline_initial_state.get("body_population_instance_sha256", ""))
		)
		or int(active_initial_state.get("previous_global_semantic_step", -1)) != 0
		or int(baseline_initial_state.get("previous_global_semantic_step", -1)) != 0
		or String(active_initial_state.get("phase", "")) != PHASE_PRECONDITION_RECOVERY
		or String(baseline_initial_state.get("phase", "")) != PHASE_PRECONDITION_RECOVERY
	):
		return _failure("QSDK_R10F_LOCKSTEP_PAIR_PLAN_INPUT_INVALID")
	var plan := {
		"schema_version": LOCKSTEP_PAIR_PLAN_SCHEMA,
		"gate_id": GATE_ID,
		"orchestrator_id": ORCHESTRATOR_ID,
		"attempt_id": String(active_initial_state["attempt_id"]),
		"frozen_configuration_sha256": String(active_initial_state["frozen_configuration_sha256"]),
		"ordered_arm_ids":
		[
			EnergyInitializer.BASELINE_ARM_ID,
			EnergyInitializer.ACTIVE_ARM_ID,
		],
		"world_count": 2,
		"subviewport_count": 2,
		"distinct_world_3d_count": 2,
		"own_world_3d_required": true,
		"worlds_built_while_physics_server_inactive": true,
		"world_spaces_advance_on_same_global_physics_frames": true,
		"cross_arm_collision_possible": false,
		"cross_arm_contact_possible": false,
		"active_and_baseline_receive_candidate_v6_precondition": true,
		"precondition_terminal_threshold_crossing_frame_lockstep_required": false,
		"precondition_pair_barrier_required": true,
		"precondition_ready_arm_world_step_skip_permitted": false,
		"precondition_ready_arm_motor_actuation_permitted": false,
		"precondition_common_no_actuation_release_frame_count": 1,
		"active_and_baseline_receive_equal_walking_prefix_steps": true,
		"only_active_receives_frozen_kick": true,
		"baseline_receives_matched_no_kick_event": true,
		"active_terminal_frame_closes_both_arms": true,
		"baseline_extra_solver_step_permitted": false,
		"hindsight_horizon_selection_permitted": false,
		"snapshot_restore_permitted": false,
		"third_world_permitted": false,
		"solver_reset_permitted": false,
		"global_sequence_rewrite_permitted": false,
		"canonical_output_order_independent_of_step_order": true,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	plan["payload_sha256"] = _payload_sha256_v1(sdk, plan)
	if not _digest_valid_v1(String(plan["payload_sha256"])):
		return _failure("QSDK_R10F_LOCKSTEP_PAIR_PLAN_DIGEST_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r10f_isolated_lockstep_pair_plan_build_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"plan": plan,
		"plan_sha256": String(plan["payload_sha256"]),
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _advance_precondition_v1(state: Dictionary, event: Dictionary) -> String:
	var event_kind := String(event["event_kind"])
	if event_kind in ["recovery_controller_step", "precondition_pair_ready"]:
		if (
			bool(state["precondition_pair_ready"])
			or String(event["control_owner"]) != "recovery_v6"
			or not _recovery_control_actuation_exact_v1(event)
			or bool(event["walking_actuation_applied"])
			or int(event["recovery_epoch_local_step"]) != 0
			or not String(event["walking_session_id"]).is_empty()
			or int(event["walking_session_local_step"]) != 0
		):
			return "QSDK_R10F_ORCHESTRATOR_PRECONDITION_RECOVERY_EVENT_INVALID"
		state["precondition_recovery_step_count"] = (
			int(state["precondition_recovery_step_count"]) + 1
		)
		if int(state["precondition_recovery_step_count"]) > MAXIMUM_PRECONDITION_RECOVERY_STEPS:
			return "QSDK_R10F_ORCHESTRATOR_PRECONDITION_HORIZON_EXCEEDED"
		var terminal_phase := String(event["recovery_controller_terminal_phase"])
		if event_kind == "precondition_pair_ready":
			if terminal_phase != "complete" or not bool(event["stable_four_foot_stance"]):
				return "QSDK_R10F_ORCHESTRATOR_PRECONDITION_READY_SOURCE_INVALID"
			state["precondition_pair_ready"] = true
		elif terminal_phase == "complete":
			return "QSDK_R10F_ORCHESTRATOR_PRECONDITION_READY_EVENT_REQUIRED"
		elif terminal_phase in ["failed", "refused"]:
			state["phase"] = PHASE_FAILED
			state["terminal_outcome"] = "failed"
			state["terminal_reason"] = String(event["recovery_controller_terminal_reason"])
		elif int(state["precondition_recovery_step_count"]) == MAXIMUM_PRECONDITION_RECOVERY_STEPS:
			state["phase"] = PHASE_FAILED
			state["terminal_outcome"] = "failed"
			state["terminal_reason"] = "canonical_precondition_recovery_timeout"
		return ""
	if event_kind == "precondition_pair_wait_step":
		if (
			not bool(state["precondition_pair_ready"])
			or not _precondition_pair_no_actuation_event_valid_v1(event)
			or int(state["precondition_pair_release_step_count"]) != 0
		):
			return "QSDK_R10F_ORCHESTRATOR_PRECONDITION_WAIT_EVENT_INVALID"
		state["precondition_pair_wait_step_count"] = (
			int(state["precondition_pair_wait_step_count"]) + 1
		)
		if int(state["precondition_pair_wait_step_count"]) > MAXIMUM_PRECONDITION_PAIR_WAIT_STEPS:
			return "QSDK_R10F_ORCHESTRATOR_PRECONDITION_WAIT_HORIZON_EXCEEDED"
		return ""
	if event_kind == "precondition_pair_release_step":
		if (
			not bool(state["precondition_pair_ready"])
			or not _precondition_pair_no_actuation_event_valid_v1(event)
			or int(state["precondition_pair_release_step_count"]) != 0
		):
			return "QSDK_R10F_ORCHESTRATOR_PRECONDITION_RELEASE_EVENT_INVALID"
		state["precondition_pair_release_step_count"] = PRECONDITION_PAIR_RELEASE_STEPS
		state["phase"] = PHASE_WALKING_PREFIX
		return ""
	return "QSDK_R10F_ORCHESTRATOR_PRECONDITION_EVENT_INVALID"


static func _advance_walking_prefix_v1(
	state: Dictionary, event: Dictionary, prefix_steps: int = WALKING_PREFIX_STEPS
) -> String:
	var expected_local_step := int(state["walking_prefix_step_count"]) + 1
	var session_id := String(event["walking_session_id"])
	if (
		String(event["event_kind"]) != "walking_policy_step"
		or String(event["control_owner"]) != "walking_bw5r_b"
		or String(event["actuation_owner"]) != "walking_bw5r_b"
		or bool(event["no_actuation_requested"])
		or not bool(event["walking_actuation_applied"])
		or bool(event["recovery_actuation_applied"])
		or session_id.is_empty()
		or int(event["walking_session_local_step"]) != expected_local_step
		or int(event["recovery_epoch_local_step"]) != 0
	):
		return "QSDK_R10F_ORCHESTRATOR_WALKING_PREFIX_EVENT_INVALID"
	if String(state["prefix_walking_session_id"]).is_empty():
		state["prefix_walking_session_id"] = session_id
	elif String(state["prefix_walking_session_id"]) != session_id:
		return "QSDK_R10F_ORCHESTRATOR_WALKING_PREFIX_SESSION_CROSSED"
	state["walking_prefix_step_count"] = expected_local_step
	if expected_local_step > prefix_steps:
		return "QSDK_R10F_ORCHESTRATOR_WALKING_PREFIX_HORIZON_EXCEEDED"
	if expected_local_step == prefix_steps:
		state["phase"] = PHASE_INTERACTION
	return ""


static func _advance_interaction_v1(state: Dictionary, event: Dictionary) -> String:
	var active := String(state["arm_id"]) == EnergyInitializer.ACTIVE_ARM_ID
	var expected_kind := "kick_effect_step" if active else "matched_no_kick_effect_step"
	var expected_kick_count := 1 if active else 0
	if (
		String(event["event_kind"]) != expected_kind
		or String(event["control_owner"]) != "none"
		or String(event["actuation_owner"]) != "none"
		or not bool(event["no_actuation_requested"])
		or bool(event["walking_actuation_applied"])
		or bool(event["recovery_actuation_applied"])
		or not String(event["walking_session_id"]).is_empty()
		or int(event["walking_session_local_step"]) != 0
		or int(event["recovery_epoch_local_step"]) != 0
		or int(event["kick_application_count"]) != expected_kick_count
		or not bool(event["walking_motors_disabled_in_same_pre_solver_event"])
		or bool(event["walking_motors_enabled_during_interaction_solve"])
		or not _digest_valid_v1(String(event["interaction_receipt_sha256"]))
		or not _digest_valid_v1(String(event["energy_initializer_sha256"]))
	):
		return "QSDK_R10F_ORCHESTRATOR_INTERACTION_EVENT_INVALID"
	state["interaction_effect_step_count"] = 1
	state["epoch_start_global_step"] = int(event["global_semantic_step"])
	state["interaction_receipt_sha256"] = String(event["interaction_receipt_sha256"])
	state["energy_initializer_sha256"] = String(event["energy_initializer_sha256"])
	state["phase"] = PHASE_CONFIRM_PRONE if active else PHASE_MATCHED_CONTINUATION
	return ""


static func _advance_confirm_prone_v1(state: Dictionary, event: Dictionary,
	expected_recovery_owner: String = "recovery_v6") -> String:
	var epoch_start := int(state["epoch_start_global_step"])
	var local_step := int(event["global_semantic_step"]) - epoch_start
	if (
		String(event["event_kind"]) != "passive_prone_observation"
		or String(event["control_owner"]) != expected_recovery_owner
		or String(event["actuation_owner"]) != "none"
		or not bool(event["no_actuation_requested"])
		or bool(event["walking_actuation_applied"])
		or bool(event["recovery_actuation_applied"])
		or not String(event["walking_session_id"]).is_empty()
		or int(event["walking_session_local_step"]) != 0
		or int(event["recovery_epoch_local_step"]) != local_step
		or String(event["energy_initializer_sha256"]) != String(state["energy_initializer_sha256"])
		or not String(event["interaction_receipt_sha256"]).is_empty()
		or int(event["kick_application_count"]) != 0
	):
		return "QSDK_R10F_ORCHESTRATOR_CONFIRM_PRONE_EVENT_INVALID"
	state["confirm_prone_step_count"] = int(state["confirm_prone_step_count"]) + 1
	state["recovery_epoch_step_count"] = local_step
	var terminal_phase := String(event["recovery_controller_terminal_phase"])
	if terminal_phase in ["failed", "refused"]:
		state["phase"] = PHASE_FAILED
		state["terminal_outcome"] = "failed"
		state["terminal_reason"] = String(event["recovery_controller_terminal_reason"])
		return ""
	if terminal_phase == "complete":
		state["phase"] = PHASE_FAILED
		state["terminal_outcome"] = "failed"
		state["terminal_reason"] = "recovery_completed_before_required_passive_prone_confirmation"
		return ""
	if bool(event["prone_sample"]):
		state["consecutive_prone_sample_count"] = int(state["consecutive_prone_sample_count"]) + 1
	else:
		state["consecutive_prone_sample_count"] = 0
	if int(state["confirm_prone_step_count"]) > MAXIMUM_CONFIRM_PRONE_STEPS:
		return "QSDK_R10F_ORCHESTRATOR_CONFIRM_PRONE_HORIZON_EXCEEDED"
	if int(state["consecutive_prone_sample_count"]) >= REQUIRED_CONSECUTIVE_PRONE_SAMPLES:
		state["phase"] = PHASE_POST_KICK_RECOVERY
	elif int(state["confirm_prone_step_count"]) == MAXIMUM_CONFIRM_PRONE_STEPS:
		state["phase"] = PHASE_FAILED
		state["terminal_outcome"] = "failed"
		state["terminal_reason"] = "ventral_prone_confirmation_not_observed"
	return ""


static func _advance_post_kick_recovery_v1(
	state: Dictionary, event: Dictionary,
	maximum_epoch_steps: int = MAXIMUM_POST_KICK_RECOVERY_EPOCH_STEPS,
	expected_recovery_owner: String = "recovery_v6",
) -> String:
	var epoch_start := int(state["epoch_start_global_step"])
	var local_step := int(event["global_semantic_step"]) - epoch_start
	if (
		String(event["event_kind"]) != "recovery_controller_step"
		or String(event["control_owner"]) != expected_recovery_owner
		or not _recovery_control_actuation_exact_v1(event, expected_recovery_owner)
		or bool(event["walking_actuation_applied"])
		or not String(event["walking_session_id"]).is_empty()
		or int(event["walking_session_local_step"]) != 0
		or int(event["recovery_epoch_local_step"]) != local_step
		or String(event["energy_initializer_sha256"]) != String(state["energy_initializer_sha256"])
		or not String(event["interaction_receipt_sha256"]).is_empty()
	):
		return "QSDK_R10F_ORCHESTRATOR_POST_KICK_RECOVERY_EVENT_INVALID"
	state["post_kick_recovery_step_count"] = int(state["post_kick_recovery_step_count"]) + 1
	state["recovery_epoch_step_count"] = local_step
	if local_step > maximum_epoch_steps:
		return "QSDK_R10F_ORCHESTRATOR_RECOVERY_EPOCH_HORIZON_EXCEEDED"
	var terminal_phase := String(event["recovery_controller_terminal_phase"])
	if terminal_phase == "complete":
		if not bool(event["stable_four_foot_stance"]):
			return "QSDK_R10F_ORCHESTRATOR_POST_RECOVERY_STANCE_MISSING"
		state["phase"] = PHASE_WALKING_RESUME
	elif terminal_phase in ["failed", "refused"]:
		state["phase"] = PHASE_FAILED
		state["terminal_outcome"] = "failed"
		state["terminal_reason"] = String(event["recovery_controller_terminal_reason"])
	elif local_step == maximum_epoch_steps:
		state["phase"] = PHASE_FAILED
		state["terminal_outcome"] = "failed"
		state["terminal_reason"] = "post_kick_recovery_epoch_timeout"
	return ""


static func _advance_walking_resume_v1(state: Dictionary, event: Dictionary, expected_walking_owner: String = "walking_bw5r_b", maximum_walking_steps: int = WALKING_RESUME_STEPS) -> String:
	var expected_local_step := int(state["walking_resume_step_count"]) + 1
	var session_id := String(event["walking_session_id"])
	if (
		String(event["event_kind"]) != "walking_policy_step"
		or String(event["control_owner"]) != expected_walking_owner
		or String(event["actuation_owner"]) != expected_walking_owner
		or bool(event["no_actuation_requested"])
		or not bool(event["walking_actuation_applied"])
		or bool(event["recovery_actuation_applied"])
		or session_id.is_empty()
		or session_id == String(state["prefix_walking_session_id"])
		or int(event["walking_session_local_step"]) != expected_local_step
		or (
			int(event["recovery_epoch_local_step"])
			!= int(event["global_semantic_step"]) - int(state["epoch_start_global_step"])
		)
		or not String(event["energy_initializer_sha256"]).is_empty()
	):
		return "QSDK_R10F_ORCHESTRATOR_WALKING_RESUME_EVENT_INVALID"
	if String(state["resume_or_continuation_session_id"]).is_empty():
		state["resume_or_continuation_session_id"] = session_id
	elif String(state["resume_or_continuation_session_id"]) != session_id:
		return "QSDK_R10F_ORCHESTRATOR_WALKING_RESUME_SESSION_CROSSED"
	state["walking_resume_step_count"] = expected_local_step
	state["recovery_epoch_step_count"] = (
		int(event["global_semantic_step"]) - int(state["epoch_start_global_step"])
	)
	if expected_local_step > maximum_walking_steps:
		return "QSDK_R10F_ORCHESTRATOR_WALKING_RESUME_HORIZON_EXCEEDED"
	if expected_local_step == maximum_walking_steps:
		state["phase"] = PHASE_COMPLETE
		state["terminal_outcome"] = "complete"
		state["terminal_reason"] = "kick_passive_recovery_and_walk_resume_complete"
	return ""


static func _advance_matched_continuation_v1(state: Dictionary, event: Dictionary, expected_walking_owner: String = "walking_bw5r_b") -> String:
	var expected_local_step := int(state["matched_continuation_step_count"]) + 1
	var session_id := String(event["walking_session_id"])
	if (
		String(event["event_kind"]) != "matched_continuation_step"
		or String(event["control_owner"]) != expected_walking_owner
		or String(event["actuation_owner"]) != expected_walking_owner
		or bool(event["no_actuation_requested"])
		or not bool(event["walking_actuation_applied"])
		or bool(event["recovery_actuation_applied"])
		or session_id.is_empty()
		or session_id == String(state["prefix_walking_session_id"])
		or int(event["walking_session_local_step"]) != expected_local_step
		or (
			int(event["recovery_epoch_local_step"])
			!= int(event["global_semantic_step"]) - int(state["epoch_start_global_step"])
		)
	):
		return "QSDK_R10F_ORCHESTRATOR_MATCHED_CONTINUATION_EVENT_INVALID"
	if String(state["resume_or_continuation_session_id"]).is_empty():
		state["resume_or_continuation_session_id"] = session_id
	elif String(state["resume_or_continuation_session_id"]) != session_id:
		return "QSDK_R10F_ORCHESTRATOR_MATCHED_CONTINUATION_SESSION_CROSSED"
	state["matched_continuation_step_count"] = expected_local_step
	state["recovery_epoch_step_count"] = (
		int(event["global_semantic_step"]) - int(state["epoch_start_global_step"])
	)
	if String(event["recovery_controller_terminal_phase"]) == "complete":
		state["phase"] = PHASE_COMPLETE
		state["terminal_outcome"] = "complete"
		state["terminal_reason"] = "matched_no_kick_equal_horizon_continuation_complete"
	elif not String(event["recovery_controller_terminal_phase"]).is_empty():
		return "QSDK_R10F_ORCHESTRATOR_MATCHED_CONTINUATION_TERMINAL_INVALID"
	return ""


static func state_valid_v1(sdk: Object, state: Dictionary) -> bool:
	return _state_valid_shape_v1(sdk, state, STATE_KEYS, STATE_SCHEMA, ORCHESTRATOR_ID)


static func _state_valid_shape_v1(
	sdk: Object, state: Dictionary, state_keys: Array, state_schema: String,
	orchestrator_id: String, extra_phases: Array = [], extra_epoch_phases: Array = [],
) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(state, state_keys)
		or String(state.get("schema_version", "")) != state_schema
		or String(state.get("orchestrator_id", "")) != orchestrator_id
		or not [EnergyInitializer.ACTIVE_ARM_ID, EnergyInitializer.BASELINE_ARM_ID].has(
			String(state.get("arm_id", ""))
		)
		or String(state.get("attempt_id", "")).is_empty()
		or String(state.get("model_instance_id", "")).is_empty()
		or not _digest_valid_v1(String(state.get("frozen_configuration_sha256", "")))
		or not _digest_valid_v1(String(state.get("body_population_instance_sha256", "")))
		or state.get("ordered_same_body_node_ids") != LocomotionFacade.SAME_BODY_NODE_IDENTITY
		or int(state.get("previous_global_semantic_step", -1)) < 0
		or int(state.get("total_completed_solver_step_count", -1)) < 0
		or (
			int(state.get("state_revision", -1))
			!= int(state.get("total_completed_solver_step_count", -2))
		)
		or not bool(state.get("event_triggered_passive_recovery", false))
		or bool(state.get("force_aware_recovery", true))
		or int(state.get("body_population_rebuild_count", -1)) != 0
		or int(state.get("body_transform_write_count", -1)) != 0
		or int(state.get("body_velocity_write_count", -1)) != 0
		or int(state.get("solver_reset_count", -1)) != 0
	):
		return false
	for count_key in [
		"precondition_recovery_step_count",
		"precondition_pair_wait_step_count",
		"precondition_pair_release_step_count",
		"walking_prefix_step_count",
		"interaction_effect_step_count",
		"confirm_prone_step_count",
		"consecutive_prone_sample_count",
		"post_kick_recovery_step_count",
		"recovery_epoch_step_count",
		"walking_resume_step_count",
		"matched_continuation_step_count",
	]:
		if int(state.get(count_key, -1)) < 0:
			return false
	if (
		typeof(state.get("precondition_pair_ready")) != TYPE_BOOL
		or (
			int(state.get("precondition_recovery_step_count", -1))
			> MAXIMUM_PRECONDITION_RECOVERY_STEPS
		)
		or (
			int(state.get("precondition_pair_wait_step_count", -1))
			> MAXIMUM_PRECONDITION_PAIR_WAIT_STEPS
		)
		or (
			int(state.get("precondition_pair_release_step_count", -1))
			not in [0, PRECONDITION_PAIR_RELEASE_STEPS]
		)
		or (
			not bool(state.get("precondition_pair_ready", false))
			and (
				int(state.get("precondition_pair_wait_step_count", -1)) != 0
				or int(state.get("precondition_pair_release_step_count", -1)) != 0
			)
		)
	):
		return false
	var phase := String(state.get("phase", ""))
	if not (
		[
			PHASE_PRECONDITION_RECOVERY,
			PHASE_WALKING_PREFIX,
			PHASE_INTERACTION,
			PHASE_CONFIRM_PRONE,
			PHASE_POST_KICK_RECOVERY,
			PHASE_WALKING_RESUME,
			PHASE_MATCHED_CONTINUATION,
			PHASE_COMPLETE,
			PHASE_FAILED,
		]
		. has(phase) or extra_phases.has(phase)
	):
		return false
	var epoch_value: Variant = state.get("epoch_start_global_step")
	if (
		phase
		in [
			PHASE_CONFIRM_PRONE,
			PHASE_POST_KICK_RECOVERY,
			PHASE_WALKING_RESUME,
			PHASE_MATCHED_CONTINUATION,
			PHASE_COMPLETE,
		]
		or extra_epoch_phases.has(phase)
	):
		if (
			typeof(epoch_value) != TYPE_INT
			or int(epoch_value) <= 0
			or not _digest_valid_v1(String(state.get("interaction_receipt_sha256", "")))
			or not _digest_valid_v1(String(state.get("energy_initializer_sha256", "")))
		):
			return false
	elif phase == PHASE_FAILED:
		var preinteraction_failure := (
			epoch_value == null
			and int(state.get("interaction_effect_step_count", -1)) == 0
			and String(state.get("interaction_receipt_sha256", "")).is_empty()
			and String(state.get("energy_initializer_sha256", "")).is_empty()
		)
		var postinteraction_failure := (
			typeof(epoch_value) == TYPE_INT
			and int(epoch_value) > 0
			and _digest_valid_v1(String(state.get("interaction_receipt_sha256", "")))
			and _digest_valid_v1(String(state.get("energy_initializer_sha256", "")))
		)
		if not preinteraction_failure and not postinteraction_failure:
			return false
	else:
		if epoch_value != null:
			return false
	if phase in [PHASE_COMPLETE, PHASE_FAILED]:
		if (
			String(state.get("terminal_outcome", "")) != phase
			or String(state.get("terminal_reason", "")).is_empty()
		):
			return false
	else:
		if (
			not String(state.get("terminal_outcome", "")).is_empty()
			or not String(state.get("terminal_reason", "")).is_empty()
		):
			return false
	if (
		phase not in [PHASE_PRECONDITION_RECOVERY, PHASE_FAILED]
		and (
			not bool(state.get("precondition_pair_ready", false))
			or (
				int(state.get("precondition_pair_release_step_count", -1))
				!= PRECONDITION_PAIR_RELEASE_STEPS
			)
		)
	):
		return false
	return String(state.get("payload_sha256", "")) == _payload_sha256_v1(sdk, state)


static func event_valid_v1(sdk: Object, event: Dictionary) -> bool:
	return _event_valid_shape_v1(sdk, event, EVENT_KEYS, EVENT_SCHEMA, ORCHESTRATOR_ID)


static func _event_valid_shape_v1(
	sdk: Object, event: Dictionary, event_keys: Array, event_schema: String,
	orchestrator_id: String,
	expected_recovery_owner: String = "recovery_v6",
	expected_walking_owner: String = "walking_bw5r_b",
) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(event, event_keys)
		or String(event.get("schema_version", "")) != event_schema
		or String(event.get("orchestrator_id", "")) != orchestrator_id
		or String(event.get("attempt_id", "")).is_empty()
		or String(event.get("model_instance_id", "")).is_empty()
		or not [EnergyInitializer.ACTIVE_ARM_ID, EnergyInitializer.BASELINE_ARM_ID].has(
			String(event.get("arm_id", ""))
		)
		or not _digest_valid_v1(String(event.get("frozen_configuration_sha256", "")))
		or not _digest_valid_v1(String(event.get("body_population_instance_sha256", "")))
		or event.get("ordered_same_body_node_ids") != LocomotionFacade.SAME_BODY_NODE_IDENTITY
		or String(event.get("source_phase", "")).is_empty()
		or String(event.get("event_kind", "")).is_empty()
		or int(event.get("global_semantic_step", -1)) <= 0
		or int(event.get("recovery_epoch_local_step", -1)) < 0
		or expected_recovery_owner not in ["recovery_v6", "recovery_v7", "recovery_v8", "recovery_candidate"]
		or expected_walking_owner not in ["walking_bw5r_b", "stance"]
		or String(event.get("control_owner", "")) not in ["none", expected_recovery_owner, expected_walking_owner]
		or String(event.get("actuation_owner", "")) not in ["none", expected_recovery_owner, expected_walking_owner]
		or not _digest_valid_v1(String(event.get("application_intent_sha256", "")))
		or int(event.get("walking_session_local_step", -1)) < 0
		or int(event.get("kick_application_count", -1)) not in [0, 1]
		or int(event.get("body_population_rebuild_count", -1)) < 0
		or int(event.get("body_transform_write_count", -1)) < 0
		or int(event.get("body_velocity_write_count", -1)) < 0
		or int(event.get("solver_reset_count", -1)) < 0
		or not bool(event.get("source_measurement", false))
		or not bool(event.get("event_triggered_passive_recovery", false))
		or bool(event.get("force_aware_recovery", true))
		or bool(event.get("physical_acceptance_authority", true))
		or bool(event.get("release_authority", true))
	):
		return false
	var actuation_owner := String(event["actuation_owner"])
	var no_actuation_requested := bool(event["no_actuation_requested"])
	var terminal_phase := String(event["recovery_controller_terminal_phase"])
	var terminal_reason := String(event["recovery_controller_terminal_reason"])
	if (
		(no_actuation_requested and actuation_owner != "none")
		or (not no_actuation_requested and actuation_owner == "none")
		or (bool(event["walking_actuation_applied"]) != (actuation_owner == expected_walking_owner))
		or (bool(event["recovery_actuation_applied"]) != (actuation_owner == expected_recovery_owner))
		or terminal_phase not in ["", "complete", "failed", "refused"]
		or (terminal_phase in ["failed", "refused"] and terminal_reason.is_empty())
		or (terminal_phase not in ["failed", "refused"] and not terminal_reason.is_empty())
	):
		return false
	return String(event.get("payload_sha256", "")) == _payload_sha256_v1(sdk, event)


static func _recovery_control_actuation_exact_v1(event: Dictionary,
	expected_recovery_owner: String = "recovery_v6") -> bool:
	if String(event.get("control_owner", "")) != expected_recovery_owner:
		return false
	if bool(event.get("recovery_actuation_applied", false)):
		return (
			String(event.get("actuation_owner", "")) == expected_recovery_owner
			and not bool(event.get("no_actuation_requested", true))
		)
	return (
		String(event.get("actuation_owner", "")) == "none"
		and bool(event.get("no_actuation_requested", false))
	)


static func _precondition_pair_no_actuation_event_valid_v1(event: Dictionary) -> bool:
	return (
		String(event.get("control_owner", "")) == "none"
		and String(event.get("actuation_owner", "")) == "none"
		and bool(event.get("no_actuation_requested", false))
		and not bool(event.get("walking_actuation_applied", true))
		and not bool(event.get("recovery_actuation_applied", true))
		and int(event.get("recovery_epoch_local_step", -1)) == 0
		and String(event.get("walking_session_id", "")).is_empty()
		and int(event.get("walking_session_local_step", -1)) == 0
		and String(event.get("recovery_controller_terminal_phase", "")).is_empty()
		and String(event.get("recovery_controller_terminal_reason", "")).is_empty()
		and String(event.get("interaction_receipt_sha256", "")).is_empty()
		and String(event.get("energy_initializer_sha256", "")).is_empty()
		and int(event.get("kick_application_count", -1)) == 0
		and not bool(event.get("walking_motors_disabled_in_same_pre_solver_event", true))
		and not bool(event.get("walking_motors_enabled_during_interaction_solve", true))
	)


static func _payload_sha256_v1(sdk: Object, value: Dictionary) -> String:
	if sdk == null:
		return ""
	var payload := value.duplicate(true)
	payload.erase("payload_sha256")
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, payload)
	var digest := String(receipt.get("sha256", ""))
	return digest if _digest_valid_v1(digest) else ""


static func _keys_exact_v1(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _digest_valid_v1(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": FAILURE_SCHEMA,
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
