## Reusable zero-world evaluator for a versioned raise-body speed-only change.
## Callers supply controller-version wrappers and exact content identities;
## this helper owns the repeated route, refusal, mutation, and application
## mechanics. It creates only uninserted hinges: no model, world, or solver step.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const SUPPORT_TARGETS := [0.60, -1.05, 0.60, -1.05, -0.60, 1.05, -0.60, 1.05]
const HALF_RAMP_TARGETS := [0.30, -0.525, 0.30, -0.525, -0.30, 0.525, -0.30, 0.525]
const STANCE_TARGETS := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


static func evaluate(config: Dictionary) -> Dictionary:
	for key in [
		"schema_version",
		"gate_id",
		"failure_prefix",
		"historical_regression",
		"historical_regression_key",
		"historical_controller_id",
		"successor_controller_id",
		"historical_profile_sha256",
		"successor_profile_sha256",
		"support_command_sha256",
		"historical_raise_command_sha256",
		"successor_raise_command_sha256",
		"historical_speed_rad_s",
		"successor_speed_rad_s",
		"prepare_historical",
		"prepare_successor",
		"fixture_historical",
		"fixture_successor",
		"bootstrap_successor",
		"invalid_context_failure_code",
		"invalid_bootstrap_failure_code",
	]:
		if not config.has(key):
			return _failure(config, "CONFIG_MISSING:%s" % key)
	var historical_regression: Dictionary = config["historical_regression"]
	if not bool(historical_regression.get("ok", false)):
		return _failure(config, "HISTORICAL_REGRESSION_FAILED", historical_regression)
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure(config, "EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure(config, "EXTENSION_INSTANTIATION_FAILED")

	var prepare_historical: Callable = config["prepare_historical"]
	var prepare_successor: Callable = config["prepare_successor"]
	var historical_context: Dictionary = prepare_historical.call(
		sdk, String(config["historical_controller_id"])
	)
	var successor_context: Dictionary = prepare_successor.call(
		sdk, String(config["successor_controller_id"])
	)
	if (
		not bool(historical_context.get("ok", false))
		or not bool(successor_context.get("ok", false))
	):
		return _failure(
			config,
			"CONTEXT_FAILED",
			{"historical": historical_context, "successor": successor_context},
		)

	var fixture_historical: Callable = config["fixture_historical"]
	var fixture_successor: Callable = config["fixture_successor"]
	var historical_bound: Dictionary = fixture_historical.call(sdk, historical_context)
	var successor_bound: Dictionary = fixture_successor.call(sdk, successor_context)
	if not bool(historical_bound.get("ok", false)) or not bool(successor_bound.get("ok", false)):
		return _failure(
			config,
			"FIXTURE_FAILED",
			{"historical": historical_bound, "successor": successor_bound},
		)

	var historical_support_route := RouteScript.collect_and_plan_v1(
		sdk, historical_context, historical_bound, "establish_distal_support", 0
	)
	var successor_support_route := RouteScript.collect_and_plan_v1(
		sdk, successor_context, successor_bound, "establish_distal_support", 0
	)
	if (
		not bool(historical_support_route.get("ok", false))
		or not bool(successor_support_route.get("ok", false))
	):
		return _failure(
			config,
			"SUPPORT_ROUTE_FAILED",
			{"historical": historical_support_route, "successor": successor_support_route},
		)
	var historical_support: Dictionary = historical_support_route["control_receipt"]
	var successor_support: Dictionary = successor_support_route["control_receipt"]

	var phase_steps := [0, 180, 360]
	var expected_targets := [SUPPORT_TARGETS, HALF_RAMP_TARGETS, STANCE_TARGETS]
	var historical_raise_controls: Array = []
	var successor_raise_controls: Array = []
	var historical_raise_hashes: Array = []
	var successor_raise_hashes: Array = []
	var observed_raise_targets: Array = []
	var changed_speed_count := 0
	var non_speed_command_fields_identical := true
	for phase_index in range(phase_steps.size()):
		var phase_step: int = phase_steps[phase_index]
		var historical_route := RouteScript.collect_and_plan_v1(
			sdk, historical_context, historical_bound, "raise_body", phase_step
		)
		var successor_route := RouteScript.collect_and_plan_v1(
			sdk, successor_context, successor_bound, "raise_body", phase_step
		)
		if (
			not bool(historical_route.get("ok", false))
			or not bool(successor_route.get("ok", false))
		):
			return _failure(
				config,
				"RAISE_ROUTE_FAILED",
				{
					"phase_step": phase_step,
					"historical": historical_route,
					"successor": successor_route,
				},
			)
		var historical_control: Dictionary = historical_route["control_receipt"]
		var successor_control: Dictionary = successor_route["control_receipt"]
		var historical_commands: Array = historical_control["ordered_commands"]
		var successor_commands: Array = successor_control["ordered_commands"]
		historical_raise_controls.append(historical_control)
		successor_raise_controls.append(successor_control)
		historical_raise_hashes.append(String(historical_control.get("command_sha256", "")))
		successor_raise_hashes.append(String(successor_control.get("command_sha256", "")))
		var targets := _command_values(successor_commands, "target_position_rad")
		observed_raise_targets.append(targets)
		non_speed_command_fields_identical = (
			non_speed_command_fields_identical
			and historical_commands.size() == 8
			and successor_commands.size() == 8
			and targets == expected_targets[phase_index]
		)
		for command_index in range(mini(historical_commands.size(), successor_commands.size())):
			var historical_command: Dictionary = historical_commands[command_index]
			var successor_command: Dictionary = successor_commands[command_index]
			if (
				float(historical_command.get("maximum_target_speed_rad_s", NAN))
				!= float(successor_command.get("maximum_target_speed_rad_s", NAN))
			):
				changed_speed_count += 1
			var historical_non_speed := historical_command.duplicate(true)
			var successor_non_speed := successor_command.duplicate(true)
			historical_non_speed.erase("maximum_target_speed_rad_s")
			successor_non_speed.erase("maximum_target_speed_rad_s")
			non_speed_command_fields_identical = (
				non_speed_command_fields_identical
				and (
					JsonTransportScript.stringify(historical_non_speed)
					== JsonTransportScript.stringify(successor_non_speed)
				)
			)

	var successor_with_historical_observation := RouteScript.collect_and_plan_v1(
		sdk, successor_context, historical_bound, "raise_body", 0
	)
	var historical_with_successor_observation := RouteScript.collect_and_plan_v1(
		sdk, historical_context, successor_bound, "raise_body", 0
	)
	var cross_version_observation_refusal_count := (
		int(_is_ownership_mismatch_refusal(successor_with_historical_observation))
		+ int(_is_ownership_mismatch_refusal(historical_with_successor_observation))
	)
	var invalid_context: Dictionary = prepare_successor.call(sdk, "unregistered_controller")
	var bootstrap_successor: Callable = config["bootstrap_successor"]
	var apply_successor: Callable = config.get(
		"apply_successor",
		Callable(RouteScript, "apply_behavior_control_v1"),
	)
	var realization_mismatch_refusal_count := 0
	if config.has("mutated_realization_failure_code"):
		var mutated_context := successor_context.duplicate(true)
		(mutated_context["actuation_realization"] as Dictionary)[
			"actuation_realization_id"
		] = "mutated_actuation_realization"
		var mutated_fixture: Dictionary = fixture_successor.call(sdk, mutated_context)
		realization_mismatch_refusal_count += int(
			String(mutated_fixture.get("failure_code", ""))
			== String(config["mutated_realization_failure_code"])
		)

	var surface := RouteScript.zero_world_command_surface_v1(successor_context)
	if not bool(surface.get("ok", false)):
		return _failure(config, "COMMAND_SURFACE_FAILED", surface)
	if config.has("historical_realization_failure_code"):
		var historical_realization_application: Dictionary = (
			apply_successor
			. call(
				sdk,
				historical_raise_controls[0],
				surface["joint_by_actuator_id"],
				surface["position_by_joint_id"],
				true,
			)
		)
		realization_mismatch_refusal_count += int(
			String(historical_realization_application.get("failure_code", ""))
			== String(config["historical_realization_failure_code"])
		)
	var successor_raise_zero: Dictionary = successor_raise_controls[0]
	var successor_commands: Array = successor_raise_zero["ordered_commands"]
	var zero_world_joint_nodes := {}
	for command_value in successor_commands:
		var command: Dictionary = command_value
		zero_world_joint_nodes[String(command["joint_id"])] = surface["joint_by_actuator_id"][String(
			command["actuator_id"]
		)]
	var bootstrap_model := {
		"ok": true,
		"host_step_count": 0,
		"joint_nodes": zero_world_joint_nodes,
	}
	var bootstrap_application: Dictionary = (
		bootstrap_successor
		. call(
			sdk,
			bootstrap_model,
			"candidate_command",
			"confirm_prone",
			String(config["successor_controller_id"]),
		)
	)
	var unknown_bootstrap_application: Dictionary = (
		bootstrap_successor
		. call(
			sdk,
			bootstrap_model,
			"candidate_command",
			"confirm_prone",
			"unregistered_controller",
		)
	)
	var application: Dictionary = (
		apply_successor
		. call(
			sdk,
			successor_raise_zero,
			surface["joint_by_actuator_id"],
			surface["position_by_joint_id"],
			true,
		)
	)
	var target_mutation := successor_raise_zero.duplicate(true)
	(target_mutation["ordered_commands"] as Array)[0]["target_position_rad"] = 0.59
	var target_mutation_application: Dictionary = (
		apply_successor
		. call(
			sdk,
			target_mutation,
			surface["joint_by_actuator_id"],
			surface["position_by_joint_id"],
			true,
		)
	)
	var speed_mutation := successor_raise_zero.duplicate(true)
	(speed_mutation["ordered_commands"] as Array)[0]["maximum_target_speed_rad_s"] = float(
		config.get("speed_mutation_value_rad_s", config["historical_speed_rad_s"])
	)
	var speed_mutation_application: Dictionary = (
		apply_successor
		. call(
			sdk,
			speed_mutation,
			surface["joint_by_actuator_id"],
			surface["position_by_joint_id"],
			true,
		)
	)
	var unknown_control := successor_raise_zero.duplicate(true)
	unknown_control["controller_id"] = "unregistered_controller"
	var unknown_application: Dictionary = (
		apply_successor
		. call(
			sdk,
			unknown_control,
			surface["joint_by_actuator_id"],
			surface["position_by_joint_id"],
			true,
		)
	)
	RouteScript.free_zero_world_command_surface_v1(surface)

	var command_mutation_refusal_count := (
		int(
			(
				String(target_mutation_application.get("failure_code", ""))
				== "QSDK_R24D57_COMMAND_DIGEST_INVALID"
			)
		)
		+ int(
			(
				String(speed_mutation_application.get("failure_code", ""))
				== "QSDK_R24D57_COMMAND_DIGEST_INVALID"
			)
		)
	)
	var unregistered_controller_refusal_count := (
		int(
			(
				String(invalid_context.get("failure_code", ""))
				== String(config["invalid_context_failure_code"])
			)
		)
		+ int(
			(
				String(unknown_bootstrap_application.get("failure_code", ""))
				== String(config["invalid_bootstrap_failure_code"])
			)
		)
		+ int(
			(
				String(unknown_application.get("failure_code", ""))
				== String(
					config.get(
						"unknown_application_failure_code",
						"QSDK_R24D65_ACTIVE_CONTROL_OWNER_INVALID",
					)
				)
			)
		)
	)
	var support_commands_preserved := (
		(
			String(historical_support.get("command_sha256", ""))
			== String(config["support_command_sha256"])
		)
		and (
			String(successor_support.get("command_sha256", ""))
			== String(config["support_command_sha256"])
		)
		and (
			JsonTransportScript.stringify(historical_support["ordered_commands"])
			== JsonTransportScript.stringify(successor_support["ordered_commands"])
		)
	)
	var expected_actuation_realization_id := String(
		config.get("expected_actuation_realization_id", "")
	)
	var realization_binding_valid := (
		expected_actuation_realization_id.is_empty()
		or (
			String(application.get("actuation_realization_id", ""))
			== expected_actuation_realization_id
			and String(application.get("portable_recovery_controller_id", ""))
			== String(config["successor_controller_id"])
			and bool(application.get("native_contact_solver_coupled", false))
			and int(application.get("solver_coupled_motor_target_write_count", -1)) == 8
			and int(application.get("pre_solver_direct_body_impulse_write_count", -1)) == 0
			and String(application.get("energy_source_profile_id", ""))
			== String(config.get("expected_energy_source_profile_id", ""))
			and bool(application.get("controller_realization_identity_checked", false))
		)
	)
	var exact: bool = (
		(
			String(historical_support.get("controller_id", ""))
			== String(config["historical_controller_id"])
		)
		and (
			String(successor_support.get("controller_id", ""))
			== String(config["successor_controller_id"])
		)
		and (
			String(historical_support.get("controller_profile_sha256", ""))
			== String(config["historical_profile_sha256"])
		)
		and (
			String(successor_support.get("controller_profile_sha256", ""))
			== String(config["successor_profile_sha256"])
		)
		and support_commands_preserved
		and historical_raise_hashes == config["historical_raise_command_sha256"]
		and successor_raise_hashes == config["successor_raise_command_sha256"]
		and observed_raise_targets == expected_targets
		and changed_speed_count == int(config.get("expected_changed_speed_count", 24))
		and non_speed_command_fields_identical
		and _all_speeds(historical_raise_controls, float(config["historical_speed_rad_s"]))
		and _all_speeds(successor_raise_controls, float(config["successor_speed_rad_s"]))
		and cross_version_observation_refusal_count == 2
		and command_mutation_refusal_count == 2
		and unregistered_controller_refusal_count == 3
		and realization_mismatch_refusal_count
		== int(config.get("expected_realization_mismatch_refusal_count", 0))
		and bool(bootstrap_application.get("ok", false))
		and (
			String(bootstrap_application.get("recovery_controller_id", ""))
			== String(config["successor_controller_id"])
		)
		and int(bootstrap_application.get("motor_enabled_count", -1)) == 0
		and bool(application.get("ok", false))
		and (
			String(application.get("recovery_controller_id", ""))
			== String(config["successor_controller_id"])
		)
		and int(application.get("validated_command_count", -1)) == 8
		and int(application.get("host_write_count", -1)) == 8
		and realization_binding_valid
	)
	var result := {
		"schema_version": String(config["schema_version"]),
		"gate_id": String(config["gate_id"]),
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode":
			String(
				config.get(
					"authority_mode",
					"zero_world_versioned_raise_body_speed_implementation",
				)
			),
			"question_class": "development",
		},
		"ok": exact,
		"failure_code":
		"" if exact else "%s_ZERO_WORLD_CONJUNCTION_INVALID" % config["failure_prefix"],
		"historical_controller_id": String(historical_support.get("controller_id", "")),
		"successor_controller_id": String(successor_support.get("controller_id", "")),
		"historical_controller_profile_sha256":
		String(historical_support.get("controller_profile_sha256", "")),
		"successor_controller_profile_sha256":
		String(successor_support.get("controller_profile_sha256", "")),
		"support_command_sha256": String(successor_support.get("command_sha256", "")),
		"support_commands_preserved": support_commands_preserved,
		"raise_body_phase_steps": phase_steps,
		"historical_raise_body_command_sha256": historical_raise_hashes,
		"successor_raise_body_command_sha256": successor_raise_hashes,
		"observed_raise_body_targets_rad": observed_raise_targets,
		"changed_speed_count": changed_speed_count,
		"portable_commands_preserved": changed_speed_count == 0,
		"non_speed_command_fields_identical": non_speed_command_fields_identical,
		"cross_version_observation_refusal_count": cross_version_observation_refusal_count,
		"command_mutation_refusal_count": command_mutation_refusal_count,
		"unregistered_controller_refusal_count": unregistered_controller_refusal_count,
		"realization_mismatch_refusal_count": realization_mismatch_refusal_count,
		"zero_world_bootstrap_application_passed": bool(bootstrap_application.get("ok", false)),
		"zero_world_application_passed": bool(application.get("ok", false)),
		"actuation_realization_id": String(
			application.get("actuation_realization_id", "")
		),
		"solver_coupled_realization_binding_passed": realization_binding_valid,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	result[String(config["historical_regression_key"])] = true
	return result


static func _all_speeds(controls: Array, expected_speed: float) -> bool:
	for control_value in controls:
		var control: Dictionary = control_value
		if (
			_command_values(control["ordered_commands"], "maximum_target_speed_rad_s")
			!= [
				expected_speed,
				expected_speed,
				expected_speed,
				expected_speed,
				expected_speed,
				expected_speed,
				expected_speed,
				expected_speed,
			]
		):
			return false
	return true


static func _is_ownership_mismatch_refusal(value: Dictionary) -> bool:
	var detail_value: Variant = value.get("detail")
	if not (detail_value is Dictionary):
		return false
	var detail: Dictionary = detail_value
	return (
		String(value.get("failure_code", "")) == "QSDK_R24D57_CONTROL_REFUSED"
		and String(detail.get("support_status", "")) == "invalid_observation"
		and String(detail.get("refusal_reason", "")) == "recovery_controller_ownership_mismatch"
		and (detail.get("ordered_commands") is Array)
		and (detail["ordered_commands"] as Array).is_empty()
	)


static func _command_values(commands: Array, field: String) -> Array:
	var values: Array = []
	for command_value in commands:
		var command: Dictionary = command_value
		values.append(float(command.get(field, NAN)))
	return values


static func _failure(config: Dictionary, suffix: String, detail: Dictionary = {}) -> Dictionary:
	var prefix := String(config.get("failure_prefix", "QSDK_VERSIONED_RECOVERY"))
	return {
		"schema_version":
		String(
			(
				config
				. get(
					"schema_version",
					"sporespore_versioned_recovery_raise_body_speed_zero_world_failure_v1",
				)
			)
		),
		"gate_id": String(config.get("gate_id", "QSDK-VERSIONED-RECOVERY")),
		"ok": false,
		"failure_code": "%s_%s" % [prefix, suffix],
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
