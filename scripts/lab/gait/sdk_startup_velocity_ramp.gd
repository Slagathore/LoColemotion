class_name SdkStartupVelocityRamp
extends RefCounted

## Engine-neutral one-cycle canonical velocity startup transform.
##
## The transform changes only the velocity component presented for native
## application. Controller state and gait phase advance on their original
## schedule, so the ramp cannot silently become engine-specific gait logic.

const POLICY_ID := "canonical_velocity_smoothstep_one_gait_cycle_v1"
const RAMP_STEPS := 360


static func scale_for_step(semantic_step: int) -> float:
	if semantic_step < 0:
		return NAN
	if semantic_step >= RAMP_STEPS - 1:
		return 1.0
	var progress := float(semantic_step) / float(RAMP_STEPS - 1)
	return progress * progress * (3.0 - 2.0 * progress)


static func transform_step_result(step_result: Dictionary) -> Dictionary:
	var transformed := step_result.duplicate(true)
	var semantic_step := int(transformed.get("semantic_step", -1))
	var scale := scale_for_step(semantic_step)
	var output: Dictionary = transformed.get("native_output", {})
	var actuation: Dictionary = output.get("actuation", {})
	var commands: Array = actuation.get("ordered_commands", [])
	if (
		not bool(transformed.get("ok", false))
		or not is_finite(scale)
		or commands.size() != 8
	):
		return {
			"ok": false,
			"failure_code": "SDK_STARTUP_RAMP_INPUT_INVALID",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var maximum_residual := 0.0
	for command_index in range(commands.size()):
		var command: Dictionary = commands[command_index]
		var source_velocity := float(command.get("target_velocity_rad_s", NAN))
		var maximum_speed := float(command.get("maximum_target_speed_rad_s", NAN))
		if (
			not is_finite(source_velocity)
			or not is_finite(maximum_speed)
			or maximum_speed <= 0.0
		):
			return {
				"ok": false,
				"failure_code": "SDK_STARTUP_RAMP_COMMAND_INVALID",
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
	return {
		"ok": true,
		"failure_code": "",
		"step_result": transformed,
		"startup_ramp_id": POLICY_ID,
		"startup_velocity_scale": scale,
		"startup_ramp_active": scale < 1.0,
		"startup_ramp_residual_count": commands.size(),
		"startup_ramp_maximum_absolute_residual_rad_s": maximum_residual,
		"controller_state_or_phase_modified": false,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func preflight() -> Dictionary:
	var samples := {}
	for step in [0, 1, 179, 358, 359, 360, 2991]:
		samples[str(step)] = scale_for_step(step)
	var exact := (
		float(samples["0"]) == 0.0
		and float(samples["359"]) == 1.0
		and float(samples["360"]) == 1.0
		and float(samples["2991"]) == 1.0
		and float(samples["1"]) > 0.0
		and float(samples["179"]) > float(samples["1"])
		and float(samples["358"]) > float(samples["179"])
		and float(samples["358"]) < 1.0
	)
	return {
		"schema_version": "sporespore_sdk_startup_velocity_ramp_preflight_v1",
		"ok": exact,
		"failure_code": "" if exact else "SDK_STARTUP_RAMP_PREFLIGHT_INVALID",
		"policy_id": POLICY_ID,
		"ramp_step_count": RAMP_STEPS,
		"samples": samples,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
