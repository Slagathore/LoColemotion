class_name SdkSupportLossConditionedStartup
extends RefCounted

## Portable startup transform selected by R23D45 and prospectively validated
## by R23D48.  It consumes only semantic time and the ordered four-foot
## contact observation; engine and command-arm identities are not inputs.

const POLICY_ID := "support_loss_latched_smoothstep_one_cycle_v1"
const RAMP_STEPS := 360
const RAMP_LAST_LOCAL_STEP := RAMP_STEPS - 1
const PROBE_LAST_SEMANTIC_STEP := 3
const LIMB_ORDER := ["rear_left", "front_left", "rear_right", "front_right"]


static func new_state() -> Dictionary:
	return {
		"next_semantic_step": 0,
		"trigger_step": -1,
		"decision_locked": false,
		"minimum_probe_support_count": LIMB_ORDER.size(),
	}


static func scale_for_local_step(local_step: int) -> float:
	if local_step < 0:
		return NAN
	if local_step >= RAMP_LAST_LOCAL_STEP:
		return 1.0
	var progress := float(local_step) / float(RAMP_LAST_LOCAL_STEP)
	return progress * progress * (3.0 - 2.0 * progress)


static func _support_count(contacts: Dictionary) -> int:
	if contacts.keys().size() != LIMB_ORDER.size():
		return -1
	var count := 0
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		if not contacts.has(limb_id) or typeof(contacts[limb_id]) != TYPE_BOOL:
			return -1
		count += int(bool(contacts[limb_id]))
	return count


static func transform_step_result(
	step_result: Dictionary,
	ordered_foot_contacts_before: Dictionary,
	state: Dictionary,
) -> Dictionary:
	var transformed := step_result.duplicate(true)
	var semantic_step := int(transformed.get("semantic_step", -1))
	var support_count := _support_count(ordered_foot_contacts_before)
	if (
		not bool(transformed.get("ok", false))
		or semantic_step != int(state.get("next_semantic_step", -1))
		or semantic_step < 0
		or support_count < 0
	):
		return {
			"ok": false,
			"failure_code": "SDK_SUPPORT_LOSS_STARTUP_INPUT_INVALID",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}

	var in_probe := semantic_step <= PROBE_LAST_SEMANTIC_STEP
	state["minimum_probe_support_count"] = mini(
		int(state["minimum_probe_support_count"]),
		support_count,
	)
	if (
		in_probe
		and not bool(state["decision_locked"])
		and int(state["trigger_step"]) < 0
		and support_count == 0
	):
		state["trigger_step"] = semantic_step
	if semantic_step >= PROBE_LAST_SEMANTIC_STEP:
		state["decision_locked"] = true

	var trigger_step := int(state["trigger_step"])
	var local_step := semantic_step - trigger_step if trigger_step >= 0 else -1
	var scale := scale_for_local_step(local_step) if trigger_step >= 0 else 1.0
	var output: Dictionary = transformed.get("native_output", {})
	var actuation: Dictionary = output.get("actuation", {})
	var commands: Array = actuation.get("ordered_commands", [])
	if not is_finite(scale) or commands.size() != 8:
		return {
			"ok": false,
			"failure_code": "SDK_SUPPORT_LOSS_STARTUP_COMMAND_SET_INVALID",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}

	var maximum_residual := 0.0
	for command_index in range(commands.size()):
		var command: Dictionary = commands[command_index]
		var source_velocity := float(command.get("target_velocity_rad_s", NAN))
		var maximum_speed := float(command.get("maximum_target_speed_rad_s", NAN))
		if not is_finite(source_velocity) or not is_finite(maximum_speed) or maximum_speed <= 0.0:
			return {
				"ok": false,
				"failure_code": "SDK_SUPPORT_LOSS_STARTUP_COMMAND_INVALID",
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		var transformed_velocity := source_velocity * scale
		maximum_residual = maxf(maximum_residual, absf(transformed_velocity - source_velocity))
		command["target_velocity_rad_s"] = transformed_velocity
		commands[command_index] = command
	actuation["ordered_commands"] = commands
	output["actuation"] = actuation
	transformed["native_output"] = output
	state["next_semantic_step"] = semantic_step + 1
	return {
		"ok": true,
		"failure_code": "",
		"step_result": transformed,
		"startup_transform_id": POLICY_ID,
		"startup_probe_active": in_probe,
		"startup_probe_support_count": support_count,
		"startup_probe_complete_support_loss": support_count == 0,
		"startup_transform_decision_locked": bool(state["decision_locked"]),
		"startup_ramp_triggered": trigger_step >= 0,
		"startup_ramp_trigger_step": trigger_step if trigger_step >= 0 else null,
		"startup_ramp_local_step": local_step if trigger_step >= 0 else null,
		"startup_ramp_id": POLICY_ID,
		"startup_velocity_scale": scale,
		"startup_ramp_active": trigger_step >= 0 and scale < 1.0,
		"startup_ramp_residual_count": commands.size(),
		"startup_transform_residual_count": commands.size(),
		"startup_ramp_maximum_absolute_residual_rad_s": maximum_residual,
		"startup_transform_maximum_absolute_residual_rad_s": maximum_residual,
		"controller_state_or_phase_modified": false,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _canary_step_result(semantic_step: int) -> Dictionary:
	var commands: Array[Dictionary] = []
	for actuator_index in range(8):
		commands.append(
			{
				"actuator_id": "actuator_%d" % actuator_index,
				"target_velocity_rad_s": float(actuator_index + 1),
				"maximum_target_speed_rad_s": 20.0,
			}
		)
	return {
		"ok": true,
		"semantic_step": semantic_step,
		"native_output": {"actuation": {"ordered_commands": commands}},
	}


static func preflight() -> Dictionary:
	var triggered := new_state()
	var identity := new_state()
	var selected_steps := [0, 1, 2, 3, 4, 182, 361, 362]
	var selected_scales: Array[float] = []
	for semantic_step in range(363):
		var support_count: int = (
			int([4, 4, 2, 0][semantic_step]) if semantic_step < 4 else 4
		)
		var trigger_contacts := {}
		var identity_contacts := {}
		for limb_index in range(LIMB_ORDER.size()):
			trigger_contacts[String(LIMB_ORDER[limb_index])] = limb_index < support_count
			identity_contacts[String(LIMB_ORDER[limb_index])] = true
		var trigger_receipt := transform_step_result(
			_canary_step_result(semantic_step), trigger_contacts, triggered
		)
		var identity_receipt := transform_step_result(
			_canary_step_result(semantic_step), identity_contacts, identity
		)
		if not bool(trigger_receipt.get("ok", false)) or not bool(identity_receipt.get("ok", false)):
			return {
				"ok": false,
				"failure_code": "SDK_SUPPORT_LOSS_STARTUP_PREFLIGHT_EXECUTION_INVALID",
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		if semantic_step in selected_steps:
			selected_scales.append(float(trigger_receipt["startup_velocity_scale"]))
		if float(identity_receipt["startup_velocity_scale"]) != 1.0:
			identity["identity_canary_failed"] = true
	var expected := [
		1.0,
		1.0,
		1.0,
		0.0,
		scale_for_local_step(1),
		scale_for_local_step(179),
		scale_for_local_step(358),
		1.0,
	]
	var exact := (
		selected_scales == expected
		and int(triggered["trigger_step"]) == 3
		and bool(triggered["decision_locked"])
		and int(identity["trigger_step"]) == -1
		and bool(identity["decision_locked"])
		and not identity.has("identity_canary_failed")
	)
	return {
		"schema_version": "sporespore_sdk_support_loss_conditioned_startup_preflight_v1",
		"ok": exact,
		"failure_code": "" if exact else "SDK_SUPPORT_LOSS_STARTUP_PREFLIGHT_INVALID",
		"policy_id": POLICY_ID,
		"probe_last_semantic_step": PROBE_LAST_SEMANTIC_STEP,
		"ramp_step_count_if_triggered": RAMP_STEPS,
		"trigger_branch_selected_scales": selected_scales,
		"identity_branch_all_unity": not identity.has("identity_canary_failed"),
		"engine_identity_input_count": 0,
		"arm_identity_input_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
