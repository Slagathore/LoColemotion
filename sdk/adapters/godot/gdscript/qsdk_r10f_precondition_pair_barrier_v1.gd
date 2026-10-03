class_name SporeQsdkR10fPreconditionPairBarrierV1
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-file-lines

## Pure authority for synchronizing two independently measured V6 standing
## terminals without pausing either physics world or requiring same-frame
## threshold crossing. The live worker remains responsible for native motor
## writes/readbacks and passes only already-validated application digests here.

const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const EnergyInitializer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd"
)

const GATE_ID := "QSDK-R10F"
const REPAIR_ID := "QSDK-R10F-L6"
const BARRIER_ID := "sporespore_qsdk_r10f_precondition_pair_barrier_v1"
const STATE_SCHEMA := "sporespore_qsdk_r10f_precondition_pair_barrier_state_v1"
const TERMINAL_SOURCE_SCHEMA := "sporespore_qsdk_r10f_precondition_terminal_source_v1"
const PLAN_SCHEMA := "sporespore_qsdk_r10f_precondition_pair_barrier_plan_v1"
const COMPLETION_SCHEMA := "sporespore_qsdk_r10f_precondition_pair_barrier_completion_v1"
const FAILURE_SCHEMA := "sporespore_qsdk_r10f_precondition_pair_barrier_failure_v1"
const ZERO_WORLD_SCHEMA := "sporespore_qsdk_r10f_precondition_pair_barrier_zero_world_v1"

const ACTION_RECOVERY := "continue_recovery"
const ACTION_WAIT := "no_actuation_wait"
const ACTION_RELEASE := "no_actuation_release"
const ACTIONS := [ACTION_RECOVERY, ACTION_WAIT, ACTION_RELEASE]
const ARM_ORDER := [
	EnergyInitializer.BASELINE_ARM_ID,
	EnergyInitializer.ACTIVE_ARM_ID,
]
const MAXIMUM_PRECONDITION_GLOBAL_FRAMES_BEFORE_RELEASE := 1200
const MAXIMUM_RELEASE_GLOBAL_STEP := 1201

const TERMINAL_SOURCE_KEYS := [
	"schema_version",
	"gate_id",
	"repair_id",
	"barrier_id",
	"attempt_id",
	"arm_id",
	"model_instance_id",
	"global_semantic_step",
	"recovery_controller_id",
	"terminal_phase",
	"stable_four_foot_stance",
	"terminal_step_receipt",
	"terminal_step_receipt_sha256",
	"terminal_classification",
	"terminal_classification_sha256",
	"source_measurement",
	"outcome_derived_readiness",
	"model_construction_count",
	"world_attempt_count",
	"world_build_count",
	"scene_tree_insertion_count",
	"native_readback_count",
	"solver_step_count",
	"physics_state_modified",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]
const PLAN_KEYS := [
	"schema_version",
	"gate_id",
	"repair_id",
	"barrier_id",
	"attempt_id",
	"completed_global_semantic_step",
	"planned_global_semantic_step",
	"ordered_arm_ids",
	"action_by_arm",
	"ready_by_arm",
	"terminal_source_sha256_by_arm",
	"state_before_sha256",
	"common_solver_frame_required",
	"world_pause_or_step_skip_permitted",
	"motors_enabled_for_wait_or_release_permitted",
	"outcome_derived_readiness",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]
const STATE_KEYS := [
	"schema_version",
	"gate_id",
	"repair_id",
	"barrier_id",
	"attempt_id",
	"model_instance_id_by_arm",
	"ready_by_arm",
	"terminal_source_by_arm",
	"terminal_source_sha256_by_arm",
	"terminal_global_step_by_arm",
	"planned_global_semantic_step",
	"planned_action_by_arm",
	"planned_action_completed_by_arm",
	"planned_application_sha256_by_arm",
	"current_plan",
	"current_plan_sha256",
	"last_completed_global_semantic_step",
	"completed_wait_step_count_by_arm",
	"release_planned_global_step",
	"release_completed_global_step",
	"released",
	"state_revision",
	"source_measurement",
	"outcome_derived_readiness",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]


static func initialize_v1(
	sdk: Object,
	attempt_id: String,
	model_instance_id_by_arm: Dictionary,
) -> Dictionary:
	if (
		sdk == null
		or attempt_id.is_empty()
		or not _model_identity_map_valid_v1(model_instance_id_by_arm)
	):
		return _failure("QSDK_R10F_L6_BARRIER_INITIALIZATION_INPUT_INVALID")
	var state := {
		"schema_version": STATE_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"barrier_id": BARRIER_ID,
		"attempt_id": attempt_id,
		"model_instance_id_by_arm": model_instance_id_by_arm.duplicate(true),
		"ready_by_arm": _arm_boolean_map_v1(false),
		"terminal_source_by_arm": _arm_null_map_v1(),
		"terminal_source_sha256_by_arm": _arm_string_map_v1(""),
		"terminal_global_step_by_arm": _arm_null_map_v1(),
		"planned_global_semantic_step": 1,
		"planned_action_by_arm": _arm_string_map_v1(ACTION_RECOVERY),
		"planned_action_completed_by_arm": _arm_boolean_map_v1(false),
		"planned_application_sha256_by_arm": _arm_string_map_v1(""),
		"current_plan": null,
		"current_plan_sha256": "",
		"last_completed_global_semantic_step": 0,
		"completed_wait_step_count_by_arm": _arm_integer_map_v1(0),
		"release_planned_global_step": null,
		"release_completed_global_step": null,
		"released": false,
		"state_revision": 0,
		"source_measurement": true,
		"outcome_derived_readiness": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	state["payload_sha256"] = _payload_sha256_v1(sdk, state)
	if not state_valid_v1(sdk, state):
		return _failure("QSDK_R10F_L6_BARRIER_INITIAL_STATE_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r10f_precondition_pair_barrier_initialization_v1",
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": true,
		"state": state,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func build_terminal_source_v1(
	sdk: Object,
	state: Dictionary,
	arm_id: String,
	global_semantic_step: int,
	recovery_controller_id: String,
	recovery_advance: Dictionary,
	classification: Dictionary,
) -> Dictionary:
	var step_value: Variant = recovery_advance.get("step_receipt")
	var memory_value: Variant = recovery_advance.get("next_memory")
	var control_value: Variant = recovery_advance.get("control_receipt")
	if (
		not state_valid_v1(sdk, state)
		or arm_id not in ARM_ORDER
		or global_semantic_step != int(state["planned_global_semantic_step"])
		or String((state["planned_action_by_arm"] as Dictionary).get(arm_id, "")) != ACTION_RECOVERY
		or recovery_controller_id.is_empty()
		or typeof(recovery_advance.get("ok")) != TYPE_BOOL
		or not bool(recovery_advance.get("ok"))
		or typeof(recovery_advance.get("terminal")) != TYPE_BOOL
		or not bool(recovery_advance.get("terminal"))
		or not (step_value is Dictionary)
		or not (memory_value is Dictionary)
		or control_value != null
		or String((memory_value as Dictionary).get("phase", "")) != "complete"
		or typeof(classification.get("stable_stance_gate")) != TYPE_BOOL
		or not bool(classification.get("stable_stance_gate"))
		or bool((state["ready_by_arm"] as Dictionary).get(arm_id, true))
		or not _zero_world_authority_fields_v1(recovery_advance)
	):
		return _failure("QSDK_R10F_L6_TERMINAL_SOURCE_INPUT_INVALID")
	var step: Dictionary = step_value
	var source := {
		"schema_version": TERMINAL_SOURCE_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"barrier_id": BARRIER_ID,
		"attempt_id": String(state["attempt_id"]),
		"arm_id": arm_id,
		"model_instance_id": String((state["model_instance_id_by_arm"] as Dictionary)[arm_id]),
		"global_semantic_step": global_semantic_step,
		"recovery_controller_id": recovery_controller_id,
		"terminal_phase": "complete",
		"stable_four_foot_stance": true,
		"terminal_step_receipt": step.duplicate(true),
		"terminal_step_receipt_sha256": _payload_sha256_v1(sdk, step),
		"terminal_classification": classification.duplicate(true),
		"terminal_classification_sha256": _payload_sha256_v1(sdk, classification),
		"source_measurement": true,
		"outcome_derived_readiness": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	source["payload_sha256"] = _payload_sha256_v1(sdk, source)
	if not terminal_source_valid_v1(sdk, source, state, arm_id, global_semantic_step):
		return _failure("QSDK_R10F_L6_TERMINAL_SOURCE_BUILD_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r10f_precondition_terminal_source_build_v1",
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": true,
		"source": source,
		"source_sha256": String(source["payload_sha256"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func observe_terminal_v1(
	sdk: Object,
	state: Dictionary,
	source: Dictionary,
) -> Dictionary:
	if not state_valid_v1(sdk, state):
		return _failure("QSDK_R10F_L6_TERMINAL_OBSERVATION_STATE_INVALID")
	var arm_id := String(source.get("arm_id", ""))
	var global_step := int(source.get("global_semantic_step", -1))
	if (
		arm_id not in ARM_ORDER
		or not terminal_source_valid_v1(sdk, source, state, arm_id, global_step)
		or global_step != int(state["planned_global_semantic_step"])
		or bool((state["ready_by_arm"] as Dictionary).get(arm_id, true))
		or state.get("release_planned_global_step") != null
	):
		return _failure("QSDK_R10F_L6_TERMINAL_OBSERVATION_INVALID")
	var successor := state.duplicate(true)
	(successor["ready_by_arm"] as Dictionary)[arm_id] = true
	(successor["terminal_source_by_arm"] as Dictionary)[arm_id] = source.duplicate(true)
	(successor["terminal_source_sha256_by_arm"] as Dictionary)[arm_id] = String(
		source["payload_sha256"]
	)
	(successor["terminal_global_step_by_arm"] as Dictionary)[arm_id] = global_step
	successor["state_revision"] = int(successor["state_revision"]) + 1
	successor["payload_sha256"] = ""
	successor["payload_sha256"] = _payload_sha256_v1(sdk, successor)
	if not state_valid_v1(sdk, successor):
		return _failure("QSDK_R10F_L6_TERMINAL_OBSERVATION_SUCCESSOR_INVALID")
	return _transition_receipt_v1("terminal_observed", state, successor)


static func complete_planned_action_v1(
	sdk: Object,
	state: Dictionary,
	arm_id: String,
	global_semantic_step: int,
	action: String,
	application_sha256: String,
) -> Dictionary:
	if (
		not state_valid_v1(sdk, state)
		or arm_id not in ARM_ORDER
		or action not in ACTIONS
		or not _digest_valid_v1(application_sha256)
		or global_semantic_step != int(state["planned_global_semantic_step"])
		or action != String((state["planned_action_by_arm"] as Dictionary).get(arm_id, ""))
		or bool((state["planned_action_completed_by_arm"] as Dictionary).get(arm_id, true))
	):
		return _failure("QSDK_R10F_L6_ACTION_COMPLETION_INVALID")
	if (
		action in [ACTION_WAIT, ACTION_RELEASE]
		and not bool((state["ready_by_arm"] as Dictionary).get(arm_id, false))
	):
		return _failure("QSDK_R10F_L6_ACTION_COMPLETION_WITHOUT_READY_SOURCE")
	if action == ACTION_RELEASE:
		if (
			state.get("release_planned_global_step") != global_semantic_step
			or not _both_arms_true_v1(state["ready_by_arm"] as Dictionary)
		):
			return _failure("QSDK_R10F_L6_RELEASE_COMPLETION_NOT_AUTHORIZED")
	var successor := state.duplicate(true)
	(successor["planned_action_completed_by_arm"] as Dictionary)[arm_id] = true
	(successor["planned_application_sha256_by_arm"] as Dictionary)[arm_id] = application_sha256
	if action == ACTION_WAIT:
		(successor["completed_wait_step_count_by_arm"] as Dictionary)[arm_id] = (
			int((successor["completed_wait_step_count_by_arm"] as Dictionary)[arm_id]) + 1
		)
	if _both_arms_true_v1(successor["planned_action_completed_by_arm"] as Dictionary):
		successor["last_completed_global_semantic_step"] = global_semantic_step
		if action == ACTION_RELEASE:
			if not _both_arms_equal_v1(
				successor["planned_action_by_arm"] as Dictionary, ACTION_RELEASE
			):
				return _failure("QSDK_R10F_L6_ASYMMETRIC_RELEASE_COMPLETION")
			successor["release_completed_global_step"] = global_semantic_step
			successor["released"] = true
	successor["state_revision"] = int(successor["state_revision"]) + 1
	successor["payload_sha256"] = ""
	successor["payload_sha256"] = _payload_sha256_v1(sdk, successor)
	if not state_valid_v1(sdk, successor):
		return _failure(
			"QSDK_R10F_L6_ACTION_COMPLETION_SUCCESSOR_INVALID",
			{"successor": successor},
		)
	return _transition_receipt_v1("action_completed", state, successor)


static func plan_next_frame_v1(
	sdk: Object,
	state: Dictionary,
	completed_global_semantic_step: int,
) -> Dictionary:
	if (
		not state_valid_v1(sdk, state)
		or bool(state.get("released", false))
		or completed_global_semantic_step != int(state["last_completed_global_semantic_step"])
		or completed_global_semantic_step != int(state["planned_global_semantic_step"])
		or not _both_arms_true_v1(state["planned_action_completed_by_arm"] as Dictionary)
		or completed_global_semantic_step < 1
		or completed_global_semantic_step > MAXIMUM_PRECONDITION_GLOBAL_FRAMES_BEFORE_RELEASE
	):
		return _failure("QSDK_R10F_L6_NEXT_PLAN_INPUT_INVALID")
	var ready: Dictionary = state["ready_by_arm"]
	var ready_count := int(bool(ready[ARM_ORDER[0]])) + int(bool(ready[ARM_ORDER[1]]))
	var action_by_arm := {}
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		action_by_arm[arm_id] = (
			ACTION_RELEASE
			if ready_count == ARM_ORDER.size()
			else (ACTION_WAIT if bool(ready[arm_id]) else ACTION_RECOVERY)
		)
	var next_global_step := completed_global_semantic_step + 1
	if next_global_step > MAXIMUM_RELEASE_GLOBAL_STEP:
		return _failure("QSDK_R10F_L6_NEXT_PLAN_HORIZON_EXCEEDED")
	var plan := {
		"schema_version": PLAN_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"barrier_id": BARRIER_ID,
		"attempt_id": String(state["attempt_id"]),
		"completed_global_semantic_step": completed_global_semantic_step,
		"planned_global_semantic_step": next_global_step,
		"ordered_arm_ids": ARM_ORDER.duplicate(),
		"action_by_arm": action_by_arm.duplicate(true),
		"ready_by_arm": ready.duplicate(true),
		"terminal_source_sha256_by_arm":
		(state["terminal_source_sha256_by_arm"] as Dictionary).duplicate(true),
		"state_before_sha256": String(state["payload_sha256"]),
		"common_solver_frame_required": true,
		"world_pause_or_step_skip_permitted": false,
		"motors_enabled_for_wait_or_release_permitted": false,
		"outcome_derived_readiness": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	plan["payload_sha256"] = _payload_sha256_v1(sdk, plan)
	if not plan_valid_v1(sdk, plan, state):
		return _failure("QSDK_R10F_L6_NEXT_PLAN_BUILD_INVALID")
	var successor := state.duplicate(true)
	successor["planned_global_semantic_step"] = next_global_step
	successor["planned_action_by_arm"] = action_by_arm.duplicate(true)
	successor["planned_action_completed_by_arm"] = _arm_boolean_map_v1(false)
	successor["planned_application_sha256_by_arm"] = _arm_string_map_v1("")
	successor["current_plan"] = plan.duplicate(true)
	successor["current_plan_sha256"] = String(plan["payload_sha256"])
	if ready_count == ARM_ORDER.size():
		successor["release_planned_global_step"] = next_global_step
	successor["state_revision"] = int(successor["state_revision"]) + 1
	successor["payload_sha256"] = ""
	successor["payload_sha256"] = _payload_sha256_v1(sdk, successor)
	if not state_valid_v1(sdk, successor):
		return _failure("QSDK_R10F_L6_NEXT_PLAN_SUCCESSOR_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r10f_precondition_pair_barrier_plan_build_v1",
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": true,
		"plan": plan,
		"plan_sha256": String(plan["payload_sha256"]),
		"state_before_sha256": String(state["payload_sha256"]),
		"state_after": successor,
		"state_after_sha256": String(successor["payload_sha256"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func terminal_source_valid_v1(
	sdk: Object,
	source: Dictionary,
	state: Dictionary,
	expected_arm_id: String,
	expected_global_step: int,
) -> bool:
	return (
		state_valid_v1(sdk, state)
		and _terminal_source_valid_for_state_identity_v1(
			sdk,
			source,
			state,
			expected_arm_id,
			expected_global_step,
		)
	)


## Validate a retained terminal source against only the immutable state identity.
## state_valid_v1 calls this helper for sources stored inside that same state;
## keeping the helper separate avoids recursive state -> source -> state validation.
static func _terminal_source_valid_for_state_identity_v1(
	sdk: Object,
	source: Dictionary,
	state: Dictionary,
	expected_arm_id: String,
	expected_global_step: int,
) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(source, TERMINAL_SOURCE_KEYS)
		or not _state_identity_valid_v1(state)
		or expected_arm_id not in ARM_ORDER
		or String(source.get("schema_version", "")) != TERMINAL_SOURCE_SCHEMA
		or String(source.get("gate_id", "")) != GATE_ID
		or String(source.get("repair_id", "")) != REPAIR_ID
		or String(source.get("barrier_id", "")) != BARRIER_ID
		or String(source.get("attempt_id", "")) != String(state["attempt_id"])
		or String(source.get("arm_id", "")) != expected_arm_id
		or (
			String(source.get("model_instance_id", ""))
			!= String((state["model_instance_id_by_arm"] as Dictionary)[expected_arm_id])
		)
		or typeof(source.get("global_semantic_step")) != TYPE_INT
		or int(source.get("global_semantic_step")) != expected_global_step
		or expected_global_step < 1
		or expected_global_step > MAXIMUM_PRECONDITION_GLOBAL_FRAMES_BEFORE_RELEASE
		or String(source.get("recovery_controller_id", "")).is_empty()
		or String(source.get("terminal_phase", "")) != "complete"
		or typeof(source.get("stable_four_foot_stance")) != TYPE_BOOL
		or not bool(source.get("stable_four_foot_stance"))
		or not (source.get("terminal_step_receipt") is Dictionary)
		or not (source.get("terminal_classification") is Dictionary)
		or typeof(source.get("source_measurement")) != TYPE_BOOL
		or not bool(source.get("source_measurement"))
		or typeof(source.get("outcome_derived_readiness")) != TYPE_BOOL
		or bool(source.get("outcome_derived_readiness"))
		or not _zero_world_authority_fields_v1(source)
	):
		return false
	var step: Dictionary = source["terminal_step_receipt"]
	var classification: Dictionary = source["terminal_classification"]
	var memory_value: Variant = step.get("memory")
	return (
		memory_value is Dictionary
		and String((memory_value as Dictionary).get("phase", "")) == "complete"
		and typeof(classification.get("stable_stance_gate")) == TYPE_BOOL
		and bool(classification.get("stable_stance_gate"))
		and _digest_valid_v1(String(source.get("terminal_step_receipt_sha256", "")))
		and (
			String(source.get("terminal_step_receipt_sha256", "")) == _payload_sha256_v1(sdk, step)
		)
		and _digest_valid_v1(String(source.get("terminal_classification_sha256", "")))
		and (
			String(source.get("terminal_classification_sha256", ""))
			== _payload_sha256_v1(sdk, classification)
		)
		and String(source.get("payload_sha256", "")) == _payload_sha256_v1(sdk, source)
	)


static func plan_valid_v1(sdk: Object, plan: Dictionary, state: Dictionary) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(plan, PLAN_KEYS)
		or not state_valid_v1(sdk, state)
		or String(plan.get("schema_version", "")) != PLAN_SCHEMA
		or String(plan.get("gate_id", "")) != GATE_ID
		or String(plan.get("repair_id", "")) != REPAIR_ID
		or String(plan.get("barrier_id", "")) != BARRIER_ID
		or String(plan.get("attempt_id", "")) != String(state["attempt_id"])
		or typeof(plan.get("completed_global_semantic_step")) != TYPE_INT
		or typeof(plan.get("planned_global_semantic_step")) != TYPE_INT
		or (
			int(plan.get("planned_global_semantic_step"))
			!= int(plan.get("completed_global_semantic_step")) + 1
		)
		or plan.get("ordered_arm_ids") != ARM_ORDER
		or not _action_map_valid_v1(plan.get("action_by_arm"))
		or not _arm_boolean_map_valid_v1(plan.get("ready_by_arm"))
		or not _arm_digest_map_valid_v1(
			plan.get("terminal_source_sha256_by_arm"), plan.get("ready_by_arm")
		)
		or String(plan.get("state_before_sha256", "")) != String(state["payload_sha256"])
		or typeof(plan.get("common_solver_frame_required")) != TYPE_BOOL
		or not bool(plan.get("common_solver_frame_required"))
		or typeof(plan.get("world_pause_or_step_skip_permitted")) != TYPE_BOOL
		or bool(plan.get("world_pause_or_step_skip_permitted"))
		or typeof(plan.get("motors_enabled_for_wait_or_release_permitted")) != TYPE_BOOL
		or bool(plan.get("motors_enabled_for_wait_or_release_permitted"))
		or typeof(plan.get("outcome_derived_readiness")) != TYPE_BOOL
		or bool(plan.get("outcome_derived_readiness"))
		or typeof(plan.get("physical_acceptance_authority")) != TYPE_BOOL
		or bool(plan.get("physical_acceptance_authority"))
		or typeof(plan.get("release_authority")) != TYPE_BOOL
		or bool(plan.get("release_authority"))
	):
		return false
	var ready: Dictionary = plan["ready_by_arm"]
	var actions: Dictionary = plan["action_by_arm"]
	var ready_count := int(bool(ready[ARM_ORDER[0]])) + int(bool(ready[ARM_ORDER[1]]))
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var expected_action := (
			ACTION_RELEASE
			if ready_count == ARM_ORDER.size()
			else (ACTION_WAIT if bool(ready[arm_id]) else ACTION_RECOVERY)
		)
		if String(actions[arm_id]) != expected_action:
			return false
	return String(plan.get("payload_sha256", "")) == _payload_sha256_v1(sdk, plan)


static func current_plan_valid_v1(sdk: Object, state: Dictionary) -> bool:
	return state_valid_v1(sdk, state) and _current_plan_matches_state_v1(sdk, state)


static func state_valid_v1(sdk: Object, state: Dictionary) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(state, STATE_KEYS)
		or String(state.get("schema_version", "")) != STATE_SCHEMA
		or String(state.get("gate_id", "")) != GATE_ID
		or String(state.get("repair_id", "")) != REPAIR_ID
		or String(state.get("barrier_id", "")) != BARRIER_ID
		or String(state.get("attempt_id", "")).is_empty()
		or not _model_identity_map_valid_v1(state.get("model_instance_id_by_arm"))
		or not _arm_boolean_map_valid_v1(state.get("ready_by_arm"))
		or not _arm_optional_dictionary_map_valid_v1(state.get("terminal_source_by_arm"))
		or not _arm_digest_map_valid_v1(
			state.get("terminal_source_sha256_by_arm"), state.get("ready_by_arm")
		)
		or not _arm_optional_integer_map_valid_v1(
			state.get("terminal_global_step_by_arm"), state.get("ready_by_arm")
		)
		or typeof(state.get("planned_global_semantic_step")) != TYPE_INT
		or int(state.get("planned_global_semantic_step")) < 1
		or int(state.get("planned_global_semantic_step")) > MAXIMUM_RELEASE_GLOBAL_STEP
		or not _action_map_valid_v1(state.get("planned_action_by_arm"))
		or not _arm_boolean_map_valid_v1(state.get("planned_action_completed_by_arm"))
		or not _arm_string_map_valid_v1(state.get("planned_application_sha256_by_arm"))
		or typeof(state.get("last_completed_global_semantic_step")) != TYPE_INT
		or int(state.get("last_completed_global_semantic_step")) < 0
		or not _arm_nonnegative_integer_map_valid_v1(state.get("completed_wait_step_count_by_arm"))
		or typeof(state.get("released")) != TYPE_BOOL
		or typeof(state.get("state_revision")) != TYPE_INT
		or int(state.get("state_revision")) < 0
		or typeof(state.get("source_measurement")) != TYPE_BOOL
		or not bool(state.get("source_measurement"))
		or typeof(state.get("outcome_derived_readiness")) != TYPE_BOOL
		or bool(state.get("outcome_derived_readiness"))
		or typeof(state.get("physical_acceptance_authority")) != TYPE_BOOL
		or bool(state.get("physical_acceptance_authority"))
		or typeof(state.get("release_authority")) != TYPE_BOOL
		or bool(state.get("release_authority"))
	):
		return false
	var ready: Dictionary = state["ready_by_arm"]
	var sources: Dictionary = state["terminal_source_by_arm"]
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		if bool(ready[arm_id]):
			if not (sources[arm_id] is Dictionary):
				return false
			if not _terminal_source_valid_for_state_identity_v1(
				sdk,
				sources[arm_id],
				state,
				arm_id,
				int((state["terminal_global_step_by_arm"] as Dictionary)[arm_id]),
			):
				return false
			if (
				String((state["terminal_source_sha256_by_arm"] as Dictionary)[arm_id])
				!= String((sources[arm_id] as Dictionary)["payload_sha256"])
			):
				return false
		elif sources[arm_id] != null:
			return false
	if not _current_plan_matches_state_v1(sdk, state):
		return false
	var release_planned: Variant = state.get("release_planned_global_step")
	var release_completed: Variant = state.get("release_completed_global_step")
	if (
		release_planned != null
		and (
			typeof(release_planned) != TYPE_INT
			or int(release_planned) < 2
			or int(release_planned) > MAXIMUM_RELEASE_GLOBAL_STEP
			or not _both_arms_true_v1(ready)
		)
	):
		return false
	if bool(state["released"]):
		if (
			typeof(release_completed) != TYPE_INT
			or release_planned != release_completed
			or int(state["last_completed_global_semantic_step"]) != int(release_completed)
			or not _both_arms_equal_v1(state["planned_action_by_arm"] as Dictionary, ACTION_RELEASE)
			or not _both_arms_true_v1(state["planned_action_completed_by_arm"] as Dictionary)
		):
			return false
	elif release_completed != null:
		return false
	return String(state.get("payload_sha256", "")) == _payload_sha256_v1(sdk, state)


static func _state_identity_valid_v1(state: Dictionary) -> bool:
	return (
		_keys_exact_v1(state, STATE_KEYS)
		and String(state.get("schema_version", "")) == STATE_SCHEMA
		and String(state.get("gate_id", "")) == GATE_ID
		and String(state.get("repair_id", "")) == REPAIR_ID
		and String(state.get("barrier_id", "")) == BARRIER_ID
		and not String(state.get("attempt_id", "")).is_empty()
		and _model_identity_map_valid_v1(state.get("model_instance_id_by_arm"))
	)


static func _current_plan_matches_state_v1(sdk: Object, state: Dictionary) -> bool:
	var current_plan_value: Variant = state.get("current_plan")
	if current_plan_value == null:
		return (
			String(state.get("current_plan_sha256", "")).is_empty()
			and int(state.get("planned_global_semantic_step", -1)) == 1
			and int(state.get("last_completed_global_semantic_step", -1)) in [0, 1]
			and _both_arms_equal_v1(
				state.get("planned_action_by_arm", {}) as Dictionary,
				ACTION_RECOVERY,
			)
		)
	if not (current_plan_value is Dictionary):
		return false
	var plan: Dictionary = current_plan_value
	return (
		_keys_exact_v1(plan, PLAN_KEYS)
		and String(plan.get("schema_version", "")) == PLAN_SCHEMA
		and String(plan.get("gate_id", "")) == GATE_ID
		and String(plan.get("repair_id", "")) == REPAIR_ID
		and String(plan.get("barrier_id", "")) == BARRIER_ID
		and String(plan.get("attempt_id", "")) == String(state.get("attempt_id", ""))
		and (
			int(plan.get("completed_global_semantic_step", -1))
			== int(state.get("planned_global_semantic_step", -2)) - 1
		)
		and (
			int(plan.get("planned_global_semantic_step", -1))
			== int(state.get("planned_global_semantic_step", -2))
		)
		and (
			int(state.get("last_completed_global_semantic_step", -1))
			in [
				int(plan.get("completed_global_semantic_step", -2)),
				int(plan.get("planned_global_semantic_step", -2)),
			]
		)
		and plan.get("ordered_arm_ids") == ARM_ORDER
		and plan.get("action_by_arm") == state.get("planned_action_by_arm")
		and _plan_readiness_snapshot_valid_v1(plan, state)
		and typeof(plan.get("common_solver_frame_required")) == TYPE_BOOL
		and bool(plan.get("common_solver_frame_required"))
		and typeof(plan.get("world_pause_or_step_skip_permitted")) == TYPE_BOOL
		and not bool(plan.get("world_pause_or_step_skip_permitted"))
		and typeof(plan.get("motors_enabled_for_wait_or_release_permitted")) == TYPE_BOOL
		and not bool(plan.get("motors_enabled_for_wait_or_release_permitted"))
		and typeof(plan.get("outcome_derived_readiness")) == TYPE_BOOL
		and not bool(plan.get("outcome_derived_readiness"))
		and typeof(plan.get("physical_acceptance_authority")) == TYPE_BOOL
		and not bool(plan.get("physical_acceptance_authority"))
		and typeof(plan.get("release_authority")) == TYPE_BOOL
		and not bool(plan.get("release_authority"))
		and _digest_valid_v1(String(state.get("current_plan_sha256", "")))
		and String(state.get("current_plan_sha256", "")) == String(plan.get("payload_sha256", ""))
		and String(plan.get("payload_sha256", "")) == _payload_sha256_v1(sdk, plan)
	)


static func _plan_readiness_snapshot_valid_v1(plan: Dictionary, state: Dictionary) -> bool:
	var plan_ready_value: Variant = plan.get("ready_by_arm")
	var plan_sources_value: Variant = plan.get("terminal_source_sha256_by_arm")
	if (
		not _arm_boolean_map_valid_v1(plan_ready_value)
		or not _arm_digest_map_valid_v1(plan_sources_value, plan_ready_value)
	):
		return false
	var plan_ready: Dictionary = plan_ready_value
	var plan_sources: Dictionary = plan_sources_value
	var state_ready: Dictionary = state["ready_by_arm"]
	var state_sources: Dictionary = state["terminal_source_sha256_by_arm"]
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		if (
			bool(plan_ready[arm_id])
			and (
				not bool(state_ready[arm_id])
				or String(plan_sources[arm_id]) != String(state_sources[arm_id])
			)
		):
			return false
	return true


static func zero_world_contract_v1(sdk: Object) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L6_ZERO_WORLD_SDK_MISSING")
	var scenarios := [
		_run_zero_world_scenario_v1(sdk, 240, 240),
		_run_zero_world_scenario_v1(sdk, 241, 240),
		_run_zero_world_scenario_v1(sdk, 240, 241),
		_run_zero_world_scenario_v1(sdk, 244, 240),
	]
	var positive_count := 0
	for scenario_value in scenarios:
		var scenario: Dictionary = scenario_value
		if bool(scenario.get("ok", false)):
			positive_count += 1
	var controls := _zero_world_negative_controls_v1(sdk)
	return {
		"schema_version": ZERO_WORLD_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": positive_count == scenarios.size() and bool(controls.get("ok", false)),
		"positive_sequence_control_count": positive_count,
		"positive_sequence_controls": scenarios,
		"mutation_rejection_count": int(controls.get("rejection_count", -1)),
		"mutation_controls": controls,
		"maximum_precondition_global_frames_before_release":
		MAXIMUM_PRECONDITION_GLOBAL_FRAMES_BEFORE_RELEASE,
		"maximum_release_global_step": MAXIMUM_RELEASE_GLOBAL_STEP,
		"maximum_solver_steps_per_arm": 3842,
		"maximum_total_solver_steps": 7684,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _run_zero_world_scenario_v1(
	sdk: Object,
	active_terminal_step: int,
	baseline_terminal_step: int,
) -> Dictionary:
	var terminal_by_arm := {
		EnergyInitializer.ACTIVE_ARM_ID: active_terminal_step,
		EnergyInitializer.BASELINE_ARM_ID: baseline_terminal_step,
	}
	var initialized := initialize_v1(
		sdk,
		"r10f-l6-zero-world-%d-%d" % [active_terminal_step, baseline_terminal_step],
		{
			EnergyInitializer.ACTIVE_ARM_ID: "zero-world-active-model",
			EnergyInitializer.BASELINE_ARM_ID: "zero-world-baseline-model",
		},
	)
	if not bool(initialized.get("ok", false)):
		return initialized
	var state: Dictionary = initialized["state"]
	var final_terminal_step := maxi(active_terminal_step, baseline_terminal_step)
	for global_step in range(1, final_terminal_step + 1):
		for arm_id_value in ARM_ORDER:
			var arm_id := String(arm_id_value)
			var action := String((state["planned_action_by_arm"] as Dictionary)[arm_id])
			if global_step == int(terminal_by_arm[arm_id]):
				var terminal_build := build_terminal_source_v1(
					sdk,
					state,
					arm_id,
					global_step,
					"sporespore_exact_s169_prone_to_standing_controller_v6",
					_zero_world_terminal_advance_v1(arm_id, global_step),
					_zero_world_terminal_classification_v1(arm_id),
				)
				if not bool(terminal_build.get("ok", false)):
					return terminal_build
				var observed := observe_terminal_v1(sdk, state, terminal_build["source"])
				if not bool(observed.get("ok", false)):
					return observed
				state = observed["state_after"]
			var completed := complete_planned_action_v1(
				sdk,
				state,
				arm_id,
				global_step,
				action,
				_filled_sha256_v1("e" if arm_id == EnergyInitializer.ACTIVE_ARM_ID else "f"),
			)
			if not bool(completed.get("ok", false)):
				return completed
			state = completed["state_after"]
		if global_step < final_terminal_step:
			var planned := plan_next_frame_v1(sdk, state, global_step)
			if not bool(planned.get("ok", false)):
				return planned
			state = planned["state_after"]
	var release_plan := plan_next_frame_v1(sdk, state, final_terminal_step)
	if not bool(release_plan.get("ok", false)):
		return release_plan
	state = release_plan["state_after"]
	var release_step := final_terminal_step + 1
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var completed := complete_planned_action_v1(
			sdk,
			state,
			arm_id,
			release_step,
			ACTION_RELEASE,
			_filled_sha256_v1("1" if arm_id == EnergyInitializer.ACTIVE_ARM_ID else "2"),
		)
		if not bool(completed.get("ok", false)):
			return completed
		state = completed["state_after"]
	var wait_counts: Dictionary = state["completed_wait_step_count_by_arm"]
	return {
		"ok":
		(
			state_valid_v1(sdk, state)
			and bool(state["released"])
			and int(state["release_completed_global_step"]) == release_step
			and int(state["last_completed_global_semantic_step"]) == release_step
		),
		"active_terminal_step": active_terminal_step,
		"baseline_terminal_step": baseline_terminal_step,
		"release_global_step": release_step,
		"walking_prefix_first_global_step": release_step + 1,
		"active_wait_step_count": int(wait_counts[EnergyInitializer.ACTIVE_ARM_ID]),
		"baseline_wait_step_count": int(wait_counts[EnergyInitializer.BASELINE_ARM_ID]),
	}


static func _zero_world_negative_controls_v1(sdk: Object) -> Dictionary:
	var initialized := initialize_v1(
		sdk,
		"r10f-l6-zero-world-mutations",
		{
			EnergyInitializer.ACTIVE_ARM_ID: "zero-world-active-model",
			EnergyInitializer.BASELINE_ARM_ID: "zero-world-baseline-model",
		},
	)
	if not bool(initialized.get("ok", false)):
		return initialized
	var state: Dictionary = initialized["state"]
	var terminal_build := build_terminal_source_v1(
		sdk,
		state,
		EnergyInitializer.ACTIVE_ARM_ID,
		1,
		"sporespore_exact_s169_prone_to_standing_controller_v6",
		_zero_world_terminal_advance_v1(EnergyInitializer.ACTIVE_ARM_ID, 1),
		_zero_world_terminal_classification_v1(EnergyInitializer.ACTIVE_ARM_ID),
	)
	if not bool(terminal_build.get("ok", false)):
		return terminal_build
	var source: Dictionary = terminal_build["source"]
	var controls := {}
	var wrong_arm := source.duplicate(true)
	wrong_arm["arm_id"] = EnergyInitializer.BASELINE_ARM_ID
	wrong_arm["payload_sha256"] = _payload_sha256_v1(sdk, wrong_arm)
	controls["wrong_arm_terminal_source"] = not terminal_source_valid_v1(
		sdk, wrong_arm, state, EnergyInitializer.ACTIVE_ARM_ID, 1
	)
	controls["copied_terminal_source"] = not terminal_source_valid_v1(
		sdk, source, state, EnergyInitializer.BASELINE_ARM_ID, 1
	)
	var stale_step := source.duplicate(true)
	stale_step["global_semantic_step"] = 2
	stale_step["payload_sha256"] = _payload_sha256_v1(sdk, stale_step)
	controls["stale_or_future_terminal_step"] = not terminal_source_valid_v1(
		sdk, stale_step, state, EnergyInitializer.ACTIVE_ARM_ID, 1
	)
	var noncomplete := source.duplicate(true)
	noncomplete["terminal_phase"] = "establish_distal_support"
	noncomplete["payload_sha256"] = _payload_sha256_v1(sdk, noncomplete)
	controls["noncomplete_terminal_source"] = not terminal_source_valid_v1(
		sdk, noncomplete, state, EnergyInitializer.ACTIVE_ARM_ID, 1
	)
	var unstable := source.duplicate(true)
	unstable["stable_four_foot_stance"] = false
	unstable["payload_sha256"] = _payload_sha256_v1(sdk, unstable)
	controls["unstable_terminal_source"] = not terminal_source_valid_v1(
		sdk, unstable, state, EnergyInitializer.ACTIVE_ARM_ID, 1
	)
	var outcome_derived := source.duplicate(true)
	outcome_derived["outcome_derived_readiness"] = true
	outcome_derived["payload_sha256"] = _payload_sha256_v1(sdk, outcome_derived)
	controls["outcome_derived_readiness"] = not terminal_source_valid_v1(
		sdk, outcome_derived, state, EnergyInitializer.ACTIVE_ARM_ID, 1
	)
	var observed := observe_terminal_v1(sdk, state, source)
	if not bool(observed.get("ok", false)):
		return observed
	var observed_state: Dictionary = observed.get("state_after", {})
	controls["duplicate_terminal_observation"] = not bool(
		observe_terminal_v1(sdk, observed_state, source).get("ok", true)
	)
	controls["release_before_both_ready"] = not bool(
		(
			complete_planned_action_v1(
				sdk,
				observed_state,
				EnergyInitializer.ACTIVE_ARM_ID,
				1,
				ACTION_RELEASE,
				_filled_sha256_v1("1"),
			)
			. get("ok", true)
		)
	)
	var asymmetric := observed_state.duplicate(true)
	(asymmetric["planned_action_by_arm"] as Dictionary)[EnergyInitializer.ACTIVE_ARM_ID] = (ACTION_RELEASE)
	asymmetric["release_planned_global_step"] = 1
	asymmetric["payload_sha256"] = _payload_sha256_v1(sdk, asymmetric)
	controls["asymmetric_release_state"] = not state_valid_v1(sdk, asymmetric)
	var rejection_count := 0
	for control_value in controls.values():
		if bool(control_value):
			rejection_count += 1
	return {
		"ok": rejection_count == controls.size(),
		"rejection_count": rejection_count,
		"controls": controls,
	}


static func _zero_world_terminal_advance_v1(arm_id: String, global_step: int) -> Dictionary:
	return {
		"schema_version": "sporespore_zero_world_recovery_advance_v1",
		"ok": true,
		"terminal": true,
		"step_receipt":
		{
			"schema_version": "sporespore_zero_world_recovery_step_v1",
			"arm_id": arm_id,
			"global_semantic_step": global_step,
			"memory": {"phase": "complete"},
		},
		"next_memory": {"phase": "complete"},
		"control_receipt": null,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _zero_world_terminal_classification_v1(arm_id: String) -> Dictionary:
	return {
		"schema_version": "sporespore_zero_world_stable_stance_classification_v1",
		"arm_id": arm_id,
		"stable_stance_gate": true,
		"source_measurement": true,
	}


static func _transition_receipt_v1(
	transition_kind: String,
	state_before: Dictionary,
	state_after: Dictionary,
) -> Dictionary:
	return {
		"schema_version": COMPLETION_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": true,
		"transition_kind": transition_kind,
		"state_before_sha256": String(state_before["payload_sha256"]),
		"state_after": state_after,
		"state_after_sha256": String(state_after["payload_sha256"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _zero_world_authority_fields_v1(value: Dictionary) -> bool:
	for field in [
		"model_construction_count",
		"world_attempt_count",
		"world_build_count",
		"solver_step_count",
	]:
		if typeof(value.get(field)) != TYPE_INT or int(value.get(field)) != 0:
			return false
	return (
		typeof(value.get("physics_state_modified")) == TYPE_BOOL
		and not bool(value.get("physics_state_modified"))
		and typeof(value.get("physical_acceptance_authority")) == TYPE_BOOL
		and not bool(value.get("physical_acceptance_authority"))
		and typeof(value.get("release_authority")) == TYPE_BOOL
		and not bool(value.get("release_authority"))
	)


static func _model_identity_map_valid_v1(value: Variant) -> bool:
	if not (value is Dictionary) or not _arm_map_exact_v1(value as Dictionary):
		return false
	var identities: Array = []
	for arm_id_value in ARM_ORDER:
		var model_id_value: Variant = (value as Dictionary).get(String(arm_id_value))
		if typeof(model_id_value) != TYPE_STRING or String(model_id_value).is_empty():
			return false
		identities.append(String(model_id_value))
	return identities[0] != identities[1]


static func _action_map_valid_v1(value: Variant) -> bool:
	if not (value is Dictionary) or not _arm_map_exact_v1(value as Dictionary):
		return false
	for action_value in (value as Dictionary).values():
		if typeof(action_value) != TYPE_STRING or String(action_value) not in ACTIONS:
			return false
	return true


static func _arm_boolean_map_valid_v1(value: Variant) -> bool:
	if not (value is Dictionary) or not _arm_map_exact_v1(value as Dictionary):
		return false
	for item in (value as Dictionary).values():
		if typeof(item) != TYPE_BOOL:
			return false
	return true


static func _arm_string_map_valid_v1(value: Variant) -> bool:
	if not (value is Dictionary) or not _arm_map_exact_v1(value as Dictionary):
		return false
	for item in (value as Dictionary).values():
		if typeof(item) != TYPE_STRING:
			return false
	return true


static func _arm_digest_map_valid_v1(value: Variant, ready_value: Variant) -> bool:
	if (
		not (value is Dictionary)
		or not (ready_value is Dictionary)
		or not _arm_map_exact_v1(value as Dictionary)
		or not _arm_map_exact_v1(ready_value as Dictionary)
	):
		return false
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var digest := String((value as Dictionary).get(arm_id, ""))
		if bool((ready_value as Dictionary).get(arm_id, false)) != _digest_valid_v1(digest):
			return false
	return true


static func _arm_optional_dictionary_map_valid_v1(value: Variant) -> bool:
	if not (value is Dictionary) or not _arm_map_exact_v1(value as Dictionary):
		return false
	for item in (value as Dictionary).values():
		if item != null and not (item is Dictionary):
			return false
	return true


static func _arm_optional_integer_map_valid_v1(value: Variant, ready_value: Variant) -> bool:
	if (
		not (value is Dictionary)
		or not (ready_value is Dictionary)
		or not _arm_map_exact_v1(value as Dictionary)
		or not _arm_map_exact_v1(ready_value as Dictionary)
	):
		return false
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var item: Variant = (value as Dictionary)[arm_id]
		if bool((ready_value as Dictionary)[arm_id]):
			if typeof(item) != TYPE_INT or int(item) < 1:
				return false
		elif item != null:
			return false
	return true


static func _arm_nonnegative_integer_map_valid_v1(value: Variant) -> bool:
	if not (value is Dictionary) or not _arm_map_exact_v1(value as Dictionary):
		return false
	for item in (value as Dictionary).values():
		if typeof(item) != TYPE_INT or int(item) < 0:
			return false
	return true


static func _arm_map_exact_v1(value: Dictionary) -> bool:
	return value.size() == ARM_ORDER.size() and value.has(ARM_ORDER[0]) and value.has(ARM_ORDER[1])


static func _arm_boolean_map_v1(value: bool) -> Dictionary:
	return {ARM_ORDER[0]: value, ARM_ORDER[1]: value}


static func _arm_string_map_v1(value: String) -> Dictionary:
	return {ARM_ORDER[0]: value, ARM_ORDER[1]: value}


static func _arm_integer_map_v1(value: int) -> Dictionary:
	return {ARM_ORDER[0]: value, ARM_ORDER[1]: value}


static func _arm_null_map_v1() -> Dictionary:
	return {ARM_ORDER[0]: null, ARM_ORDER[1]: null}


static func _both_arms_true_v1(value: Dictionary) -> bool:
	return bool(value.get(ARM_ORDER[0], false)) and bool(value.get(ARM_ORDER[1], false))


static func _both_arms_equal_v1(value: Dictionary, expected: String) -> bool:
	return (
		String(value.get(ARM_ORDER[0], "")) == expected
		and String(value.get(ARM_ORDER[1], "")) == expected
	)


static func _keys_exact_v1(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _payload_sha256_v1(sdk: Object, value: Dictionary) -> String:
	if sdk == null:
		return ""
	var payload := value.duplicate(true)
	payload.erase("payload_sha256")
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, payload)
	var digest := String(receipt.get("sha256", ""))
	return digest if _digest_valid_v1(digest) else ""


static func _filled_sha256_v1(fill: String) -> String:
	return "sha256:" + fill.repeat(64)


static func _digest_valid_v1(value: String) -> bool:
	if not value.begins_with("sha256:") or value.length() != 71:
		return false
	for byte in value.substr(7).to_ascii_buffer():
		if not (byte >= 48 and byte <= 57) and not (byte >= 97 and byte <= 102):
			return false
	return true


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": FAILURE_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
