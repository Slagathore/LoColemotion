extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## R23D55 zero-world conformance gate for the exact fixture-created hinge path.
##
## The same composition helper used by the physical fixture creates eight
## unparented joints. The production cap binder validates their identities,
## replaces the legacy fixture caps with the SDK-compiled per-actuator caps,
## and reads every value back. No node enters a SceneTree and physics never
## advances.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const BindingScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_binding.gd"
)
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const R23D48WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d48_godot_jolt_physical_worker.gd"
)

const STAGE_ID := "three_engine_support_loss_conditioned_turning_validation"
const ONSET_ID := "onset_600"
const ARM_ID := "positive_heading"
const READBACK_TOLERANCE_NMS := 2.5e-7
const KNEE_MOTOR_IMPULSE_SCALE := 10.0
const FIXTURE_ACTUATOR_IMPULSE_SCALE := 1.015
const POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
	+ "stability_guarded_steering_v1"
)
const EXPECTED_MUTATION_REJECTION_COUNT := 14


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(
		"QSDK_R23D55_GODOT_LIVE_FIXTURE_ACTUATOR_CAP_CONFORMANCE ",
		JSON.stringify(result),
	)
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var prepared := _prepared_boundary()
	if not bool(prepared.get("ok", false)):
		return _failure("R23D55_PREPARATION_INVALID", prepared)
	var started := _started_adapter(prepared)
	if not bool(started.get("ok", false)):
		return _failure("R23D55_ADAPTER_START_INVALID", started)
	var morphology: Dictionary = started["morphology"]
	var authority_request: Dictionary = (prepared["authority_options"] as Dictionary).duplicate(
		true
	)
	authority_request["task_frame_origin_policy_id"] = ("warmup_preserving_command_onset_origin_reanchor_v1")
	authority_request["live_fixture_actuator_cap_binding_policy_id"] = (BindingScript.POLICY_ID)
	var authority_options: Dictionary = WaveGaitScript._normalize_sdk_authority_options(
		authority_request
	)
	var wrong_authority_request := authority_request.duplicate(true)
	wrong_authority_request["live_fixture_actuator_cap_binding_policy_id"] = ("sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v0")
	var wrong_authority_options: Dictionary = WaveGaitScript._normalize_sdk_authority_options(
		wrong_authority_request
	)
	var surface := _fixture_surface(prepared)
	if not bool(surface.get("ok", false)):
		return _failure("R23D55_FIXTURE_SURFACE_INVALID", surface)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	var binder: RefCounted = BindingScript.new()
	var binding: Dictionary = (
		binder
		. bind_compiled_actuator_caps(
			morphology,
			states,
			READBACK_TOLERANCE_NMS,
			BindingScript.POLICY_ID,
		)
	)
	if not bool(binding.get("ok", false)):
		var binding_failure := _failure("R23D55_BINDING_INVALID", binding)
		_free_surface(surface)
		return binding_failure
	var validation: Dictionary = (
		binder
		. validate_bound_actuator_caps(
			morphology,
			states,
			READBACK_TOLERANCE_NMS,
			BindingScript.POLICY_ID,
		)
	)
	if not bool(validation.get("ok", false)):
		var validation_failure := _failure(
			"R23D55_POSTBIND_VALIDATION_INVALID",
			validation,
		)
		_free_surface(surface)
		return validation_failure
	var mutation_results := {
		"missing_joint_rejected_without_write": _missing_joint_rejected(prepared, morphology),
		"extra_joint_rejected_without_write": _extra_joint_rejected(prepared, morphology),
		"swapped_joint_rejected_without_write": _swapped_joint_rejected(prepared, morphology),
		"duplicate_host_object_rejected_without_write":
		_duplicate_object_rejected(
			prepared,
			morphology,
		),
		"detached_preconfigured_only_rejected": _detached_only_rejected(morphology),
		"nonfinite_compiled_cap_rejected_without_write":
		_compiled_cap_rejected(
			prepared,
			morphology,
			NAN,
		),
		"zero_compiled_cap_rejected_without_write":
		_compiled_cap_rejected(
			prepared,
			morphology,
			0.0,
		),
		"wrong_policy_rejected_without_write": _wrong_policy_rejected(prepared, morphology),
		"excessive_tolerance_rejected_without_write":
		_tolerance_rejected(
			prepared,
			morphology,
		),
		"wrong_fixture_marker_rejected_without_write":
		_wrong_marker_rejected(
			prepared,
			morphology,
		),
		"wrong_host_name_rejected_without_write":
		_wrong_name_rejected(
			prepared,
			morphology,
		),
		"omitted_write_readback_rejected":
		_postbind_mutation_rejected(
			prepared,
			morphology,
			"omitted_write",
		),
		"wrong_scale_readback_rejected":
		_postbind_mutation_rejected(
			prepared,
			morphology,
			"wrong_scale",
		),
		"duplicate_binding_rejected":
		not bool(
			(
				binder
				. bind_compiled_actuator_caps(
					morphology,
					states,
					READBACK_TOLERANCE_NMS,
					BindingScript.POLICY_ID,
				)
				. get("ok", true)
			)
		),
	}
	var mutation_rejection_count := 0
	for rejected in mutation_results.values():
		mutation_rejection_count += int(bool(rejected))
	var exact := (
		(
			String(surface.get("schema_version", ""))
			== BindingScript.FIXTURE_COMPOSITION_SCHEMA_VERSION
		)
		and int(surface.get("host_object_creation_count", -1)) == 8
		and int(surface.get("scene_tree_insertion_count", -1)) == 0
		and int(surface.get("model_construction_count", -1)) == 0
		and int(surface.get("world_attempt_count", -1)) == 0
		and int(surface.get("world_build_count", -1)) == 0
		and not bool(surface.get("physics_state_modified", true))
		and bool(authority_options.get("ok", false))
		and (
			String(
				(
					(authority_options["sdk_authority_options"] as Dictionary)
					. get(
						"live_fixture_actuator_cap_binding_policy_id",
						"",
					)
				)
			)
			== BindingScript.POLICY_ID
		)
		and not bool(wrong_authority_options.get("ok", true))
		and String(binding.get("schema_version", "")) == BindingScript.RECEIPT_SCHEMA_VERSION
		and int(binding.get("validated_actuator_count", -1)) == 8
		and int(binding.get("validated_limb_count", -1)) == 4
		and int(binding.get("unique_host_joint_object_count", -1)) == 8
		and int(binding.get("prebinding_mismatch_count", -1)) == 8
		and int(binding.get("write_count", -1)) == 8
		and int(binding.get("readback_count", -1)) == 8
		and (
			float(binding.get("maximum_postbinding_readback_error_nms", INF))
			<= READBACK_TOLERANCE_NMS
		)
		and bool(binding.get("all_fixture_composition_markers_valid", false))
		and bool(binding.get("all_host_joint_names_valid", false))
		and bool(binding.get("all_postbinding_readbacks_match", false))
		and int(binding.get("scene_tree_insertion_count", -1)) == 0
		and bool(binding.get("configured_parameter_readback_only", false))
		and not bool(binding.get("measured_motor_torque_available", true))
		and not bool(binding.get("measured_motor_impulse_available", true))
		and int(validation.get("validated_actuator_count", -1)) == 8
		and float(validation.get("maximum_readback_error_nms", INF)) <= READBACK_TOLERANCE_NMS
		and mutation_rejection_count == EXPECTED_MUTATION_REJECTION_COUNT
	)
	var result := {
		"schema_version":
		"sporespore_qsdk_r23d55_godot_live_fixture_actuator_cap_" + "conformance_v1",
		"ok": exact,
		"failure_code": "" if exact else "R23D55_ZERO_WORLD_CONFORMANCE_INVALID",
		"question_class": "development",
		"policy_id": BindingScript.POLICY_ID,
		"fixture_composition_schema_version": BindingScript.FIXTURE_COMPOSITION_SCHEMA_VERSION,
		"binding_receipt_schema_version": BindingScript.RECEIPT_SCHEMA_VERSION,
		"physical_entrypoint_option_normalized": bool(authority_options.get("ok", false)),
		"wrong_physical_entrypoint_policy_rejected":
		not bool(wrong_authority_options.get("ok", true)),
		"runtime_api_version": Engine.get_version_info().get("string", ""),
		"validated_actuator_count": int(binding.get("validated_actuator_count", -1)),
		"validated_limb_count": int(binding.get("validated_limb_count", -1)),
		"unique_host_joint_object_count": int(binding.get("unique_host_joint_object_count", -1)),
		"prebinding_mismatch_count": int(binding.get("prebinding_mismatch_count", -1)),
		"maximum_prebinding_readback_error_nms":
		float(binding.get("maximum_prebinding_readback_error_nms", INF)),
		"write_count": int(binding.get("write_count", -1)),
		"readback_count": int(binding.get("readback_count", -1)),
		"readback_tolerance_nms": READBACK_TOLERANCE_NMS,
		"maximum_postbinding_readback_error_nms":
		float(binding.get("maximum_postbinding_readback_error_nms", INF)),
		"mutation_rejection_count": mutation_rejection_count,
		"mutation_results": mutation_results,
		"configured_parameter_readback_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
		"host_object_creation_count": int(surface.get("host_object_creation_count", -1)),
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_successor_opened": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	_free_surface(surface)
	return result


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
	var start: Dictionary = (
		adapter
		. start(
			prepared["descriptor"],
			{
				"rear_left": 0,
				"front_left": 0,
				"rear_right": 0,
				"front_right": 0,
			},
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
			POLICY_ID,
		)
	)
	if not bool(start.get("ok", false)):
		return start
	var boundary: Dictionary = adapter.preflight_compiled_morphology_boundary()
	if not bool(boundary.get("ok", false)):
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
	return (
		WaveGaitScript
		. compose_sdk_live_fixture_actuator_cap_binding_surface(
			prepared["fixture_spec"],
			KNEE_MOTOR_IMPULSE_SCALE,
			FIXTURE_ACTUATOR_IMPULSE_SCALE,
			FIXTURE_ACTUATOR_IMPULSE_SCALE,
			prepared["initial_perturbation"],
		)
	)


static func _surface_caps(surface: Dictionary) -> Dictionary:
	var caps: Dictionary = {}
	for joint_value in surface.get("ordered_joint_nodes", []):
		if not (joint_value is HingeJoint3D):
			continue
		var joint: HingeJoint3D = joint_value
		caps[joint.get_instance_id()] = float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE))
	return caps


static func _caps_unchanged(surface: Dictionary, before: Dictionary) -> bool:
	var after := _surface_caps(surface)
	return before == after


static func _missing_joint_rejected(prepared: Dictionary, morphology: Dictionary) -> bool:
	var surface := _fixture_surface(prepared)
	var before := _surface_caps(surface)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	states.erase(
		(
			String((morphology["ordered_actuator_ids"] as Array)[0])
			. trim_suffix("_motor")
			. replace("_hip", ".hip_pitch")
			. replace("_knee", ".knee_pitch")
		)
	)
	var result: Dictionary = BindingScript.new().bind_compiled_actuator_caps(
		morphology, states, READBACK_TOLERANCE_NMS, BindingScript.POLICY_ID
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	_free_surface(surface)
	return rejected


static func _extra_joint_rejected(prepared: Dictionary, morphology: Dictionary) -> bool:
	var surface := _fixture_surface(prepared)
	var before := _surface_caps(surface)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	var extra_joint := HingeJoint3D.new()
	states["unexpected.hip_pitch"] = {"joint": extra_joint}
	var result: Dictionary = BindingScript.new().bind_compiled_actuator_caps(
		morphology, states, READBACK_TOLERANCE_NMS, BindingScript.POLICY_ID
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	extra_joint.free()
	_free_surface(surface)
	return rejected


static func _swapped_joint_rejected(prepared: Dictionary, morphology: Dictionary) -> bool:
	var surface := _fixture_surface(prepared)
	var before := _surface_caps(surface)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	var ids: Array = states.keys()
	var first_joint: Variant = (states[ids[0]] as Dictionary)["joint"]
	(states[ids[0]] as Dictionary)["joint"] = (states[ids[1]] as Dictionary)["joint"]
	(states[ids[1]] as Dictionary)["joint"] = first_joint
	var result: Dictionary = BindingScript.new().bind_compiled_actuator_caps(
		morphology, states, READBACK_TOLERANCE_NMS, BindingScript.POLICY_ID
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	_free_surface(surface)
	return rejected


static func _duplicate_object_rejected(prepared: Dictionary, morphology: Dictionary) -> bool:
	var surface := _fixture_surface(prepared)
	var before := _surface_caps(surface)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	var ids: Array = states.keys()
	(states[ids[1]] as Dictionary)["joint"] = (states[ids[0]] as Dictionary)["joint"]
	var result: Dictionary = BindingScript.new().bind_compiled_actuator_caps(
		morphology, states, READBACK_TOLERANCE_NMS, BindingScript.POLICY_ID
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	_free_surface(surface)
	return rejected


static func _detached_only_rejected(morphology: Dictionary) -> bool:
	var states: Dictionary = {}
	var created_joints: Array[HingeJoint3D] = []
	var morphology_spec: Dictionary = morphology["morphology_spec"]
	for actuator_value in morphology_spec["actuators"]:
		var actuator: Dictionary = actuator_value
		var portable_joint_id := String(actuator["joint_id"])
		var host_role := "hip" if portable_joint_id.ends_with("_hip") else "knee"
		var limb_id := portable_joint_id.trim_suffix("_%s" % host_role)
		var joint_id := "%s.%s_pitch" % [limb_id, host_role]
		var joint := HingeJoint3D.new()
		joint.name = "wave_gait_%s_%s" % [limb_id, host_role]
		(
			joint
			. set_param(
				HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
				float(actuator["maximum_impulse_nms"]),
			)
		)
		states[joint_id] = {"joint": joint}
		created_joints.append(joint)
	var result: Dictionary = BindingScript.new().bind_compiled_actuator_caps(
		morphology, states, READBACK_TOLERANCE_NMS, BindingScript.POLICY_ID
	)
	var rejected := not bool(result.get("ok", true))
	for joint in created_joints:
		joint.free()
	return rejected


static func _compiled_cap_rejected(
	prepared: Dictionary,
	morphology: Dictionary,
	mutated_cap: float,
) -> bool:
	var surface := _fixture_surface(prepared)
	var before := _surface_caps(surface)
	var mutated := morphology.duplicate(true)
	var morphology_spec: Dictionary = mutated["morphology_spec"]
	var actuators: Array = morphology_spec["actuators"]
	(actuators[0] as Dictionary)["maximum_impulse_nms"] = mutated_cap
	var result: Dictionary = (
		BindingScript
		. new()
		. bind_compiled_actuator_caps(
			mutated,
			surface["joint_state_by_joint_id"],
			READBACK_TOLERANCE_NMS,
			BindingScript.POLICY_ID,
		)
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	_free_surface(surface)
	return rejected


static func _wrong_policy_rejected(prepared: Dictionary, morphology: Dictionary) -> bool:
	var surface := _fixture_surface(prepared)
	var before := _surface_caps(surface)
	var result: Dictionary = (
		BindingScript
		. new()
		. bind_compiled_actuator_caps(
			morphology,
			surface["joint_state_by_joint_id"],
			READBACK_TOLERANCE_NMS,
			"sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v0",
		)
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	_free_surface(surface)
	return rejected


static func _tolerance_rejected(prepared: Dictionary, morphology: Dictionary) -> bool:
	var surface := _fixture_surface(prepared)
	var before := _surface_caps(surface)
	var result: Dictionary = (
		BindingScript
		. new()
		. bind_compiled_actuator_caps(
			morphology,
			surface["joint_state_by_joint_id"],
			1.1e-6,
			BindingScript.POLICY_ID,
		)
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	_free_surface(surface)
	return rejected


static func _wrong_marker_rejected(prepared: Dictionary, morphology: Dictionary) -> bool:
	var surface := _fixture_surface(prepared)
	var before := _surface_caps(surface)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	var state: Dictionary = states[states.keys()[0]]
	var joint: HingeJoint3D = state["joint"]
	(
		joint
		. set_meta(
			"sporespore_fixture_joint_composition_schema_version",
			"sporespore_godot_jolt_fixture_joint_composition_v0",
		)
	)
	var result: Dictionary = BindingScript.new().bind_compiled_actuator_caps(
		morphology, states, READBACK_TOLERANCE_NMS, BindingScript.POLICY_ID
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	_free_surface(surface)
	return rejected


static func _wrong_name_rejected(prepared: Dictionary, morphology: Dictionary) -> bool:
	var surface := _fixture_surface(prepared)
	var before := _surface_caps(surface)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	var state: Dictionary = states[states.keys()[0]]
	var joint: HingeJoint3D = state["joint"]
	joint.name = "wrong_fixture_joint"
	var result: Dictionary = BindingScript.new().bind_compiled_actuator_caps(
		morphology, states, READBACK_TOLERANCE_NMS, BindingScript.POLICY_ID
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	_free_surface(surface)
	return rejected


static func _postbind_mutation_rejected(
	prepared: Dictionary,
	morphology: Dictionary,
	mutation_id: String,
) -> bool:
	var surface := _fixture_surface(prepared)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	var binder: RefCounted = BindingScript.new()
	var binding: Dictionary = binder.bind_compiled_actuator_caps(
		morphology, states, READBACK_TOLERANCE_NMS, BindingScript.POLICY_ID
	)
	if not bool(binding.get("ok", false)):
		_free_surface(surface)
		return false
	var ordered: Array = binding["ordered_bindings"]
	var target: Dictionary = ordered[0] if mutation_id == "omitted_write" else ordered[1]
	var state: Dictionary = states[String(target["host_joint_id"])]
	var joint: HingeJoint3D = state["joint"]
	var mutated_cap := (
		float(target["prebinding_maximum_impulse_readback_nms"])
		if mutation_id == "omitted_write"
		else float(target["declared_maximum_impulse_nms"]) * 10.0
	)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, mutated_cap)
	var validation: Dictionary = binder.validate_bound_actuator_caps(
		morphology, states, READBACK_TOLERANCE_NMS, BindingScript.POLICY_ID
	)
	var rejected := not bool(validation.get("ok", true))
	_free_surface(surface)
	return rejected


static func _free_surface(surface: Dictionary) -> void:
	for joint_value in surface.get("ordered_joint_nodes", []):
		if joint_value is HingeJoint3D:
			var joint: HingeJoint3D = joint_value
			if is_instance_valid(joint):
				joint.free()


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version":
		"sporespore_qsdk_r23d55_godot_live_fixture_actuator_cap_" + "conformance_v1",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"question_class": "development",
		"configured_parameter_readback_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_successor_opened": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
