extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## R23D58 production-route zero-world integration gate.
##
## This gate crosses all four declared hip-source x knee-source profiles through
## the real physical runner's option normalization and cap-binding dispatcher,
## then through the real adapter cap resolver and apply_authority() readback
## path. Every HingeJoint3D remains unparented; no body, model, SceneTree node,
## or physics world is constructed.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const FactorialBindingScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_factorial_binding.gd"
)
const LegacyBindingScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_binding.gd"
)
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const R23D48WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d48_godot_jolt_physical_worker.gd"
)

const STAGE_ID := "three_engine_support_loss_conditioned_turning_validation"
const ONSET_ID := "onset_600"
const ARM_ID := "reference_zero"
const READBACK_TOLERANCE_NMS := 2.5e-7
const KNEE_MOTOR_IMPULSE_SCALE := 10.0
const FIXTURE_ACTUATOR_IMPULSE_SCALE := 1.015
const CONTROLLER_POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
	+ "stability_guarded_steering_v1"
)
const ORIGIN_POLICY_ID := "warmup_preserving_command_onset_origin_reanchor_v1"
const EXPECTED_NORMALIZATION_MUTATION_REJECTION_COUNT := 7
const EXPECTED_ROUTE_MUTATION_REJECTION_COUNT := 7
const EXPECTED_RESOLUTION_MUTATION_REJECTION_COUNT := 6
const POSITIVE_PROFILE_HOST_OBJECT_CREATION_COUNT := 32
const NEGATIVE_CONTROL_HOST_OBJECT_CREATION_COUNT := 57


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(
		"QSDK_R23D58_GODOT_PHYSICAL_ROUTE_CAP_FACTORIAL_ZERO_WORLD ",
		JSON.stringify(result, "", false, true),
	)
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var prepared := _prepared_boundary()
	if not bool(prepared.get("ok", false)):
		return _failure("R23D58_ROUTE_PREPARATION_INVALID", prepared)
	var started := _started_adapter(prepared)
	if not bool(started.get("ok", false)):
		return _failure("R23D58_ROUTE_ADAPTER_START_INVALID", started)
	var adapter: RefCounted = started["adapter"]
	var morphology: Dictionary = started["morphology"]
	var compiled_boundary := {
		"ok": true,
		"failure_code": "",
		"morphology": morphology.duplicate(true),
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	var profile_summaries: Array = []
	var total_writes := 0
	var total_readbacks := 0
	var total_authority_applications := 0
	var maximum_cap_readback_error_nms := 0.0
	var reference_override: Dictionary = {}
	for profile_index in range(FactorialBindingScript.ORDERED_PROFILE_IDS.size()):
		var profile_id := String(FactorialBindingScript.ORDERED_PROFILE_IDS[profile_index])
		var authority_request := _authority_request(prepared, profile_id)
		var normalization: Dictionary = WaveGaitScript._normalize_sdk_authority_options(
			authority_request
		)
		if not _normalization_exact(normalization, profile_id):
			return _fail_after_start(
				adapter,
				{},
				"R23D58_ROUTE_AUTHORITY_NORMALIZATION_INVALID",
				normalization,
			)
		var surface := _fixture_surface(prepared)
		if not bool(surface.get("ok", false)):
			return _fail_after_start(
				adapter,
				surface,
				"R23D58_ROUTE_FIXTURE_SURFACE_INVALID",
				surface,
			)
		var states: Dictionary = surface["joint_state_by_joint_id"]
		var route: Dictionary = WaveGaitScript.bind_sdk_live_fixture_actuator_cap_route(
			compiled_boundary,
			states,
			READBACK_TOLERANCE_NMS,
			FactorialBindingScript.POLICY_ID,
			profile_id,
		)
		if not _route_exact(route, profile_id):
			return _fail_after_start(
				adapter,
				surface,
				"R23D58_ROUTE_BINDING_INVALID",
				route,
			)
		var override_by_actuator_id: Dictionary = (
			route["maximum_impulse_override_by_actuator_id"]
		)
		var resolution: Dictionary = (
			AdapterScript.resolve_authorized_maximum_impulse_by_actuator_id(
				morphology,
				override_by_actuator_id,
			)
		)
		if not _resolution_exact(resolution, override_by_actuator_id):
			return _fail_after_start(
				adapter,
				surface,
				"R23D58_ROUTE_CAP_RESOLUTION_INVALID",
				resolution,
			)
		var step_result := _authority_step_result(morphology, profile_index)
		var authority_receipt: Dictionary = adapter.apply_authority(
			step_result,
			states,
			true,
			override_by_actuator_id,
		)
		if not _authority_receipt_exact(
			authority_receipt,
			override_by_actuator_id,
			profile_index,
		):
			return _fail_after_start(
				adapter,
				surface,
				"R23D58_ROUTE_AUTHORITY_READBACK_INVALID",
				authority_receipt,
			)
		var binding_receipt: Dictionary = route["binding_receipt"]
		profile_summaries.append(
			{
				"profile_id": profile_id,
				"hip_cap_source": String(binding_receipt["hip_cap_source"]),
				"knee_cap_source": String(binding_receipt["knee_cap_source"]),
				"write_count": int(route["write_count"]),
				"readback_count": int(route["readback_count"]),
				"resolved_actuator_count": int(resolution["validated_actuator_count"]),
				"authority_application_count": int(
					authority_receipt["applied_command_count"]
				),
				"maximum_cap_readback_error_nms": float(
					authority_receipt["maximum_impulse_readback_error_nms"]
				),
			}
		)
		total_writes += int(route["write_count"])
		total_readbacks += int(route["readback_count"])
		total_authority_applications += int(authority_receipt["applied_command_count"])
		maximum_cap_readback_error_nms = maxf(
			maximum_cap_readback_error_nms,
			float(authority_receipt["maximum_impulse_readback_error_nms"]),
		)
		if reference_override.is_empty():
			reference_override = override_by_actuator_id.duplicate(true)
		_free_surface(surface)

	var normalization_mutations := _normalization_mutation_controls(prepared)
	var route_mutations := _route_mutation_controls(prepared, compiled_boundary)
	var resolution_mutations := _resolution_mutation_controls(
		morphology,
		reference_override,
	)
	var normalization_mutation_rejection_count := _true_count(normalization_mutations)
	var route_mutation_rejection_count := _true_count(route_mutations)
	var resolution_mutation_rejection_count := _true_count(resolution_mutations)
	var default_resolution := AdapterScript.resolve_authorized_maximum_impulse_by_actuator_id(
		morphology
	)
	var default_resolution_exact := (
		bool(default_resolution.get("ok", false))
		and not bool(default_resolution.get("override_applied", true))
		and int(default_resolution.get("validated_actuator_count", -1)) == 8
		and int(default_resolution.get("world_build_count", -1)) == 0
	)
	var shutdown: Dictionary = adapter.shutdown()
	var exact := (
		profile_summaries.size() == 4
		and total_writes == 32
		and total_readbacks == 32
		and total_authority_applications == 32
		and maximum_cap_readback_error_nms <= READBACK_TOLERANCE_NMS
		and normalization_mutation_rejection_count
		== EXPECTED_NORMALIZATION_MUTATION_REJECTION_COUNT
		and route_mutation_rejection_count == EXPECTED_ROUTE_MUTATION_REJECTION_COUNT
		and resolution_mutation_rejection_count
		== EXPECTED_RESOLUTION_MUTATION_REJECTION_COUNT
		and default_resolution_exact
		and bool(shutdown.get("ok", false))
		and int(shutdown.get("world_build_count", -1)) == 0
	)
	return {
		"schema_version": "sporespore_qsdk_r23d58_godot_physical_route_cap_factorial_zero_world_v1",
		"ok": exact,
		"failure_code": "" if exact else "R23D58_PHYSICAL_ROUTE_ZERO_WORLD_INVALID",
		"question_class": "development",
		"runtime_api_version": String(Engine.get_version_info().get("string", "")),
		"factorial_policy_id": FactorialBindingScript.POLICY_ID,
		"ordered_profile_ids": FactorialBindingScript.ORDERED_PROFILE_IDS.duplicate(),
		"profile_count": profile_summaries.size(),
		"profile_summaries": profile_summaries,
		"physical_runner_option_normalization_exercised": true,
		"physical_runner_binding_dispatch_exercised": true,
		"adapter_cap_resolution_exercised": true,
		"adapter_apply_authority_exercised": true,
		"write_count": total_writes,
		"binding_readback_count": total_readbacks,
		"authority_application_count": total_authority_applications,
		"maximum_cap_readback_error_nms": maximum_cap_readback_error_nms,
		"readback_tolerance_nms": READBACK_TOLERANCE_NMS,
		"normalization_mutation_rejection_count": (
			normalization_mutation_rejection_count
		),
		"normalization_mutation_results": normalization_mutations,
		"route_mutation_rejection_count": route_mutation_rejection_count,
		"route_mutation_results": route_mutations,
		"resolution_mutation_rejection_count": resolution_mutation_rejection_count,
		"resolution_mutation_results": resolution_mutations,
		"empty_override_preserves_compiled_caps": default_resolution_exact,
		"configured_motor_parameters_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
		"positive_profile_host_object_creation_count": (
			POSITIVE_PROFILE_HOST_OBJECT_CREATION_COUNT
		),
		"negative_control_host_object_creation_count": (
			NEGATIVE_CONTROL_HOST_OBJECT_CREATION_COUNT
		),
		"total_host_object_creation_count": (
			POSITIVE_PROFILE_HOST_OBJECT_CREATION_COUNT
			+ NEGATIVE_CONTROL_HOST_OBJECT_CREATION_COUNT
		),
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_campaign_opened": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"shutdown_receipt": shutdown,
	}


static func _authority_request(prepared: Dictionary, profile_id: String) -> Dictionary:
	var request: Dictionary = (prepared["authority_options"] as Dictionary).duplicate(true)
	request["task_frame_origin_policy_id"] = ORIGIN_POLICY_ID
	request["live_fixture_actuator_cap_binding_policy_id"] = FactorialBindingScript.POLICY_ID
	request["live_fixture_actuator_cap_binding_profile_id"] = profile_id
	return request


static func _normalization_exact(normalization: Dictionary, profile_id: String) -> bool:
	var options: Dictionary = normalization.get("sdk_authority_options", {})
	return (
		bool(normalization.get("ok", false))
		and String(options.get("live_fixture_actuator_cap_binding_policy_id", ""))
		== FactorialBindingScript.POLICY_ID
		and String(options.get("live_fixture_actuator_cap_binding_profile_id", ""))
		== profile_id
		and String(options.get("task_frame_origin_policy_id", "")) == ORIGIN_POLICY_ID
		and String(options.get("authority_scope", "")) == "post_settle_full"
		and int(normalization.get("world_build_count", -1)) == 0
	)


static func _route_exact(route: Dictionary, profile_id: String) -> bool:
	var receipt: Dictionary = route.get("binding_receipt", {})
	var override_by_actuator_id: Dictionary = route.get(
		"maximum_impulse_override_by_actuator_id",
		{},
	)
	return (
		bool(route.get("ok", false))
		and String(route.get("policy_id", "")) == FactorialBindingScript.POLICY_ID
		and String(route.get("profile_id", "")) == profile_id
		and String(receipt.get("schema_version", ""))
		== FactorialBindingScript.RECEIPT_SCHEMA_VERSION
		and String(receipt.get("profile_id", "")) == profile_id
		and override_by_actuator_id.size() == 8
		and int(route.get("write_count", -1)) == 8
		and int(route.get("readback_count", -1)) == 8
		and int(route.get("world_build_count", -1)) == 0
		and not bool(route.get("physics_state_modified", true))
	)


static func _resolution_exact(resolution: Dictionary, expected: Dictionary) -> bool:
	return (
		bool(resolution.get("ok", false))
		and bool(resolution.get("override_applied", false))
		and int(resolution.get("validated_actuator_count", -1)) == 8
		and (resolution.get("maximum_impulse_by_actuator_id", {}) as Dictionary) == expected
		and int(resolution.get("world_build_count", -1)) == 0
		and not bool(resolution.get("physics_state_modified", true))
	)


static func _authority_step_result(morphology: Dictionary, semantic_step: int) -> Dictionary:
	var commands: Array = []
	var ordered_actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	for actuator_index in range(ordered_actuator_ids.size()):
		commands.append(
			{
				"actuator_id": String(ordered_actuator_ids[actuator_index]),
				"mode": "position_velocity",
				"requested_target_position_rad": 0.0,
				"clamped_target_position_rad": 0.0,
				"target_velocity_rad_s": 0.125 if actuator_index % 2 == 0 else -0.125,
				"maximum_target_speed_rad_s": 1.0,
				"position_saturated": false,
				"velocity_saturated": false,
				"slew_limited": false,
			}
		)
	return {
		"ok": true,
		"failure_code": "",
		"semantic_step": semantic_step,
		"native_output": {
			"actuation": {
				"safe_no_actuation": false,
				"ordered_commands": commands,
			},
		},
	}


static func _authority_receipt_exact(
	receipt: Dictionary,
	expected_caps: Dictionary,
	semantic_step: int,
) -> bool:
	var applications: Array = receipt.get("ordered_applications", [])
	if (
		not bool(receipt.get("ok", false))
		or int(receipt.get("semantic_step", -1)) != semantic_step
		or int(receipt.get("applied_command_count", -1)) != 8
		or applications.size() != 8
		or float(receipt.get("maximum_impulse_readback_error_nms", INF))
		> READBACK_TOLERANCE_NMS
		or not bool(receipt.get("maximum_impulse_override_applied", false))
		or (
			(receipt.get("authorized_maximum_impulse_by_actuator_id", {}) as Dictionary)
			!= expected_caps
		)
		or not bool(receipt.get("configured_motor_parameters_only", false))
		or bool(receipt.get("measured_motor_torque_available", true))
		or bool(receipt.get("measured_motor_impulse_available", true))
	):
		return false
	for application_value in applications:
		if typeof(application_value) != TYPE_DICTIONARY:
			return false
		var application: Dictionary = application_value
		var actuator_id := String(application.get("actuator_id", ""))
		if (
			actuator_id.is_empty()
			or not expected_caps.has(actuator_id)
			or float(application.get("declared_maximum_impulse_nms", NAN))
			!= float(expected_caps[actuator_id])
			or not bool(application.get("maximum_impulse_readback_matches", false))
			or bool(application.get("host_additional_clamp_applied", true))
		):
			return false
	return true


static func _normalization_mutation_controls(prepared: Dictionary) -> Dictionary:
	var base := _authority_request(
		prepared,
		FactorialBindingScript.PROFILE_PORTABLE_HIP_PORTABLE_KNEE,
	)
	var missing_profile := base.duplicate(true)
	missing_profile.erase("live_fixture_actuator_cap_binding_profile_id")
	var empty_profile := base.duplicate(true)
	empty_profile["live_fixture_actuator_cap_binding_profile_id"] = ""
	var unknown_profile := base.duplicate(true)
	unknown_profile["live_fixture_actuator_cap_binding_profile_id"] = "unknown_profile"
	var legacy_with_profile := base.duplicate(true)
	legacy_with_profile["live_fixture_actuator_cap_binding_policy_id"] = LegacyBindingScript.POLICY_ID
	var extra_key := base.duplicate(true)
	extra_key["undeclared_factorial_selector"] = true
	var wrong_profile_type := base.duplicate(true)
	wrong_profile_type["live_fixture_actuator_cap_binding_profile_id"] = 7
	var wrong_scope := base.duplicate(true)
	wrong_scope["authority_scope"] = "shadow"
	return {
		"missing_profile_rejected": _normalization_rejected(missing_profile),
		"empty_profile_rejected": _normalization_rejected(empty_profile),
		"unknown_profile_rejected": _normalization_rejected(unknown_profile),
		"legacy_policy_with_profile_rejected": _normalization_rejected(
			legacy_with_profile
		),
		"extra_selector_key_rejected": _normalization_rejected(extra_key),
		"wrong_profile_type_rejected": _normalization_rejected(wrong_profile_type),
		"wrong_authority_scope_rejected": _normalization_rejected(wrong_scope),
	}


static func _normalization_rejected(request: Dictionary) -> bool:
	return not bool(
		WaveGaitScript._normalize_sdk_authority_options(request).get("ok", true)
	)


static func _route_mutation_controls(
	prepared: Dictionary,
	compiled_boundary: Dictionary,
) -> Dictionary:
	return {
		"invalid_compiled_boundary_rejected_without_write": _route_mutation_rejected(
			prepared,
			compiled_boundary,
			"invalid_boundary",
		),
		"missing_joint_rejected_without_write": _route_mutation_rejected(
			prepared,
			compiled_boundary,
			"missing_joint",
		),
		"extra_joint_rejected_without_write": _route_mutation_rejected(
			prepared,
			compiled_boundary,
			"extra_joint",
		),
		"excessive_tolerance_rejected_without_write": _route_mutation_rejected(
			prepared,
			compiled_boundary,
			"excessive_tolerance",
		),
		"unknown_profile_rejected_without_write": _route_mutation_rejected(
			prepared,
			compiled_boundary,
			"unknown_profile",
		),
		"unknown_policy_rejected_without_write": _route_mutation_rejected(
			prepared,
			compiled_boundary,
			"unknown_policy",
		),
		"legacy_policy_profile_rejected_without_write": _route_mutation_rejected(
			prepared,
			compiled_boundary,
			"legacy_profile",
		),
	}


static func _route_mutation_rejected(
	prepared: Dictionary,
	compiled_boundary: Dictionary,
	mutation_id: String,
) -> bool:
	var surface := _fixture_surface(prepared)
	if not bool(surface.get("ok", false)):
		_free_surface(surface)
		return false
	var before := _surface_caps(surface)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	var boundary := compiled_boundary.duplicate(true)
	var tolerance := READBACK_TOLERANCE_NMS
	var policy_id := FactorialBindingScript.POLICY_ID
	var profile_id := FactorialBindingScript.PROFILE_PORTABLE_HIP_PORTABLE_KNEE
	var extra_joint: HingeJoint3D
	match mutation_id:
		"invalid_boundary":
			boundary["ok"] = false
		"missing_joint":
			states.erase(String(states.keys()[0]))
		"extra_joint":
			extra_joint = HingeJoint3D.new()
			states["intruder.joint"] = {"joint": extra_joint}
		"excessive_tolerance":
			tolerance = 2.0e-6
		"unknown_profile":
			profile_id = "unknown_profile"
		"unknown_policy":
			policy_id = "unknown_policy"
		"legacy_profile":
			policy_id = LegacyBindingScript.POLICY_ID
		_:
			_free_surface(surface)
			return false
	var result := WaveGaitScript.bind_sdk_live_fixture_actuator_cap_route(
		boundary,
		states,
		tolerance,
		policy_id,
		profile_id,
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	if extra_joint != null and is_instance_valid(extra_joint):
		extra_joint.free()
	_free_surface(surface)
	return rejected


static func _resolution_mutation_controls(
	morphology: Dictionary,
	reference_override: Dictionary,
) -> Dictionary:
	var ordered_ids: Array = morphology.get("ordered_actuator_ids", [])
	if ordered_ids.size() != 8 or reference_override.size() != 8:
		return {}
	var first_id := String(ordered_ids[0])
	var missing := reference_override.duplicate(true)
	missing.erase(first_id)
	var extra := reference_override.duplicate(true)
	extra["intruder_motor"] = 0.1
	var same_size_wrong_key := reference_override.duplicate(true)
	same_size_wrong_key.erase(first_id)
	same_size_wrong_key["intruder_motor"] = 0.1
	var zero := reference_override.duplicate(true)
	zero[first_id] = 0.0
	var nonfinite := reference_override.duplicate(true)
	nonfinite[first_id] = NAN
	var wrong_type := reference_override.duplicate(true)
	wrong_type[first_id] = "0.1"
	return {
		"missing_override_rejected": _resolution_rejected(morphology, missing),
		"extra_override_rejected": _resolution_rejected(morphology, extra),
		"same_cardinality_wrong_key_rejected": _resolution_rejected(
			morphology,
			same_size_wrong_key,
		),
		"zero_override_rejected": _resolution_rejected(morphology, zero),
		"nonfinite_override_rejected": _resolution_rejected(morphology, nonfinite),
		"wrong_type_override_rejected": _resolution_rejected(morphology, wrong_type),
	}


static func _resolution_rejected(morphology: Dictionary, override: Dictionary) -> bool:
	var result := AdapterScript.resolve_authorized_maximum_impulse_by_actuator_id(
		morphology,
		override,
	)
	return (
		not bool(result.get("ok", true))
		and int(result.get("world_build_count", -1)) == 0
		and not bool(result.get("physics_state_modified", true))
	)


static func _true_count(values: Dictionary) -> int:
	var count := 0
	for value in values.values():
		count += int(bool(value))
	return count


static func _prepared_boundary() -> Dictionary:
	var cell: Dictionary = R23D48WorkerScript._r23d48_cell(STAGE_ID, ONSET_ID, ARM_ID)
	if not bool(cell.get("ok", false)):
		return cell
	return R23D48WorkerScript._r23d48_prepare(cell)


static func _started_adapter(prepared: Dictionary) -> Dictionary:
	var adapter: RefCounted = AdapterScript.new()
	var phase_offset := int(
		(prepared["initial_perturbation"] as Dictionary)["gait_phase_offset_ticks"]
	)
	var start: Dictionary = adapter.start(
		prepared["descriptor"],
		{"rear_left": 0, "front_left": 0, "rear_right": 0, "front_right": 0},
		0.0,
		Vector3.ZERO,
		Vector3.BACK,
		PI * 0.5,
		120,
		{
			"solver_policy_id": "jolt_120hz_20v_7p_v1",
			"physics_engine": "Jolt Physics",
			"physics_hz": 120,
			"solver_velocity_steps": 20,
			"solver_position_steps": 7,
		},
		READBACK_TOLERANCE_NMS,
		"clocked",
		true,
		phase_offset,
		360,
		"post_settle_full",
		"p5i3b_weight_support_shadow_v1",
		prepared["material_profile"],
		CONTROLLER_POLICY_ID,
	)
	if not bool(start.get("ok", false)):
		return start
	var boundary: Dictionary = adapter.preflight_compiled_morphology_boundary()
	if not bool(boundary.get("ok", false)):
		var shutdown: Dictionary = adapter.shutdown()
		boundary["shutdown_receipt"] = shutdown
		return boundary
	return {
		"ok": true,
		"failure_code": "",
		"adapter": adapter,
		"morphology": (boundary["morphology"] as Dictionary).duplicate(true),
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _fixture_surface(prepared: Dictionary) -> Dictionary:
	return WaveGaitScript.compose_sdk_live_fixture_actuator_cap_binding_surface(
		prepared["fixture_spec"],
		KNEE_MOTOR_IMPULSE_SCALE,
		FIXTURE_ACTUATOR_IMPULSE_SCALE,
		FIXTURE_ACTUATOR_IMPULSE_SCALE,
		prepared["initial_perturbation"],
	)


static func _surface_caps(surface: Dictionary) -> Dictionary:
	var caps: Dictionary = {}
	for joint_value in surface.get("ordered_joint_nodes", []):
		if joint_value is HingeJoint3D:
			var joint: HingeJoint3D = joint_value
			caps[joint.get_instance_id()] = float(
				joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)
			)
	return caps


static func _caps_unchanged(surface: Dictionary, before: Dictionary) -> bool:
	return _surface_caps(surface) == before


static func _free_surface(surface: Dictionary) -> void:
	for joint_value in surface.get("ordered_joint_nodes", []):
		if joint_value is HingeJoint3D:
			var joint: HingeJoint3D = joint_value
			if is_instance_valid(joint):
				joint.free()


static func _fail_after_start(
	adapter: RefCounted,
	surface: Dictionary,
	code: String,
	detail: Dictionary,
) -> Dictionary:
	_free_surface(surface)
	var failure_detail := detail.duplicate(true)
	failure_detail["shutdown_receipt"] = adapter.shutdown()
	return _failure(code, failure_detail)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r23d58_godot_physical_route_cap_factorial_zero_world_v1",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"question_class": "development",
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_campaign_opened": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
