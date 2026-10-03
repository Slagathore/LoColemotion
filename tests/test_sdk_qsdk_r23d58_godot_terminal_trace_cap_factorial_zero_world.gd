extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## R23D58 zero-world runtime gate.
##
## Four fresh, unparented copies of the exact physical fixture surface exercise
## the complete hip-source x knee-source cap factorial. The same explicit
## full-precision serializer then carries production-shaped terminal receipts
## and first trace-row applications through the Python evaluator. No node is
## inserted into a SceneTree and no physics model or world is constructed.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const FactorialBindingScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_factorial_binding.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
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
const PYTHON_VALIDATOR_PATH := (
	"res://sdk/turning/r23d58_terminal_trace_cap_factorial_zero_world.py"
)
const EXPECTED_BINDER_MUTATION_REJECTION_COUNT := 12
const EXPECTED_TRANSPORT_MUTATION_REJECTION_COUNT := 32


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(
		"QSDK_R23D58_GODOT_TERMINAL_TRACE_CAP_FACTORIAL_ZERO_WORLD ",
		JsonTransportScript.stringify(result),
	)
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var prepared := _prepared_boundary()
	if not bool(prepared.get("ok", false)):
		return _failure("R23D58_PREPARATION_INVALID", prepared)
	var started := _started_adapter(prepared)
	if not bool(started.get("ok", false)):
		return _failure("R23D58_ADAPTER_START_INVALID", started)
	var morphology: Dictionary = started["morphology"]
	var terminal_cells: Array = []
	var trace_rows: Array = []
	var profile_summaries: Array = []
	var first_profile_bindings: Array = []
	var total_writes := 0
	var total_readbacks := 0
	var maximum_readback_error := 0.0
	var maximum_source_delta := 0.0
	for profile_id_value in FactorialBindingScript.ORDERED_PROFILE_IDS:
		var profile_id := String(profile_id_value)
		var surface := _fixture_surface(prepared)
		if not bool(surface.get("ok", false)):
			return _failure("R23D58_FIXTURE_SURFACE_INVALID", surface)
		var states: Dictionary = surface["joint_state_by_joint_id"]
		var binder: RefCounted = FactorialBindingScript.new()
		var preflight: Dictionary = binder.preflight_profile(
			morphology,
			states,
			READBACK_TOLERANCE_NMS,
			profile_id,
			FactorialBindingScript.POLICY_ID,
		)
		if not _preflight_exact(preflight, profile_id):
			_free_surface(surface)
			return _failure("R23D58_PROFILE_PREFLIGHT_INVALID", preflight)
		var binding: Dictionary = binder.bind_profile(
			morphology,
			states,
			READBACK_TOLERANCE_NMS,
			profile_id,
			FactorialBindingScript.POLICY_ID,
		)
		if not _binding_exact(binding, profile_id):
			_free_surface(surface)
			return _failure("R23D58_PROFILE_BINDING_INVALID", binding)
		var validation: Dictionary = binder.validate_bound_profile(
			states,
			READBACK_TOLERANCE_NMS,
			profile_id,
			FactorialBindingScript.POLICY_ID,
		)
		if not bool(validation.get("ok", false)):
			_free_surface(surface)
			return _failure("R23D58_PROFILE_VALIDATION_INVALID", validation)
		var cell_id := "zero_world__%s" % profile_id
		terminal_cells.append(
			{
				"schema_version": "sporespore_qsdk_r23d58_terminal_cap_identity_cell_v1",
				"cell_id": cell_id,
				"profile_id": profile_id,
				"sdk_authority_summary": {
					"r23d58_live_fixture_cap_source_factorial_binding_receipt": (
						binding.duplicate(true)
					),
				},
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		)
		var applications: Array = []
		for binding_value in binding.get("ordered_bindings", []):
			var item: Dictionary = binding_value
			applications.append(
				{
					"actuator_id": String(item["actuator_id"]),
					"joint_id": String(item["joint_id"]),
					"host_joint_id": String(item["host_joint_id"]),
					"limb_id": String(item["limb_id"]),
					"joint_role": String(item["joint_role"]),
					"selected_cap_source": String(item["selected_cap_source"]),
					"declared_maximum_impulse_nms": float(
						item["selected_maximum_impulse_nms"]
					),
					"motor_maximum_impulse_readback_nms": float(
						item["motor_maximum_impulse_readback_nms"]
					),
					"readback_error_nms": float(item["readback_error_nms"]),
				}
			)
		trace_rows.append(
			{
				"schema_version": "sporespore_qsdk_r23d58_trace_cap_identity_row_v1",
				"cell_id": cell_id,
				"profile_id": profile_id,
				"semantic_step": 0,
				"actuator_phase_observation": {
					"schema_version": "sporespore_godot_jolt_actuator_phase_observation_v1",
					"ordered_applications": applications,
					"configured_motor_parameters_only": true,
					"measured_motor_torque_available": false,
					"measured_motor_impulse_available": false,
				},
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		)
		profile_summaries.append(
			{
				"profile_id": profile_id,
				"hip_cap_source": String(binding["hip_cap_source"]),
				"knee_cap_source": String(binding["knee_cap_source"]),
				"portable_fixture_distinct_actuator_count": int(
					binding["portable_fixture_distinct_actuator_count"]
				),
				"maximum_portable_fixture_absolute_delta_nms": float(
					binding["maximum_portable_fixture_absolute_delta_nms"]
				),
				"write_count": int(binding["write_count"]),
				"readback_count": int(binding["readback_count"]),
				"maximum_postbinding_readback_error_nms": float(
					binding["maximum_postbinding_readback_error_nms"]
				),
			}
		)
		if first_profile_bindings.is_empty():
			first_profile_bindings = (binding["ordered_bindings"] as Array).duplicate(true)
		total_writes += int(binding["write_count"])
		total_readbacks += int(binding["readback_count"])
		maximum_readback_error = maxf(
			maximum_readback_error,
			float(binding["maximum_postbinding_readback_error_nms"]),
		)
		maximum_source_delta = maxf(
			maximum_source_delta,
			float(binding["maximum_portable_fixture_absolute_delta_nms"]),
		)
		_free_surface(surface)

	var transport_receipt := JsonTransportScript.receipt()
	var terminal_document := {
		"schema_version": "sporespore_qsdk_r23d58_terminal_cap_identity_canary_v1",
		"transport": transport_receipt.duplicate(true),
		"ordered_profile_ids": FactorialBindingScript.ORDERED_PROFILE_IDS.duplicate(),
		"cells": terminal_cells,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
	}
	var trace_document := {
		"schema_version": "sporespore_qsdk_r23d58_trace_cap_identity_canary_v1",
		"transport": transport_receipt.duplicate(true),
		"ordered_profile_ids": FactorialBindingScript.ORDERED_PROFILE_IDS.duplicate(),
		"rows": trace_rows,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
	}
	var validator := _run_python_validator(terminal_document, trace_document)
	if not bool(validator.get("ok", false)):
		return _failure("R23D58_TERMINAL_TRACE_VALIDATOR_INVALID", validator)
	var binder_mutations := _binder_mutation_controls(prepared, morphology)
	var binder_mutation_rejection_count := 0
	for rejected in binder_mutations.values():
		binder_mutation_rejection_count += int(bool(rejected))
	var exact := (
		String(Engine.get_version_info().get("string", "")) == "4.7-stable (official)"
		and terminal_cells.size() == 4
		and trace_rows.size() == 4
		and total_writes == 32
		and total_readbacks == 32
		and maximum_readback_error <= READBACK_TOLERANCE_NMS
		and maximum_source_delta > READBACK_TOLERANCE_NMS
		and binder_mutation_rejection_count == EXPECTED_BINDER_MUTATION_REJECTION_COUNT
		and int(validator.get("profile_count", -1)) == 4
		and int(validator.get("actuator_count_per_profile", -1)) == 8
		and int(validator.get("binary64_comparison_count", -1)) == 96
		and int(validator.get("binary64_mismatch_count", -1)) == 0
		and int(validator.get("default_precision_binary64_mismatch_count", 0)) > 0
		and int(validator.get("mutation_rejection_count", -1))
		== EXPECTED_TRANSPORT_MUTATION_REJECTION_COUNT
		and bool(validator.get("nextafter_up_rejected", false))
		and bool(validator.get("nextafter_down_rejected", false))
		and int(validator.get("world_build_count", -1)) == 0
	)
	return {
		"schema_version": "sporespore_qsdk_r23d58_godot_terminal_trace_cap_factorial_zero_world_v1",
		"ok": exact,
		"failure_code": "" if exact else "R23D58_ZERO_WORLD_GATE_INVALID",
		"question_class": "development",
		"runtime_api_version": String(Engine.get_version_info().get("string", "")),
		"transport_id": JsonTransportScript.TRANSPORT_ID,
		"selected_godot_invocation": JsonTransportScript.GODOT_INVOCATION,
		"factorial_policy_id": FactorialBindingScript.POLICY_ID,
		"ordered_profile_ids": FactorialBindingScript.ORDERED_PROFILE_IDS.duplicate(),
		"profile_count": terminal_cells.size(),
		"profile_summaries": profile_summaries,
		"portable_portable_ordered_bindings": first_profile_bindings,
		"validated_actuator_count_per_profile": 8,
		"host_object_creation_count": 32,
		"write_count": total_writes,
		"readback_count": total_readbacks,
		"readback_tolerance_nms": READBACK_TOLERANCE_NMS,
		"maximum_postbinding_readback_error_nms": maximum_readback_error,
		"maximum_portable_fixture_absolute_delta_nms": maximum_source_delta,
		"binder_mutation_rejection_count": binder_mutation_rejection_count,
		"binder_mutation_results": binder_mutations,
		"terminal_trace_binary64_comparison_count": int(
			validator.get("binary64_comparison_count", -1)
		),
		"terminal_trace_binary64_mismatch_count": int(
			validator.get("binary64_mismatch_count", -1)
		),
		"default_precision_binary64_mismatch_count": int(
			validator.get("default_precision_binary64_mismatch_count", -1)
		),
		"transport_mutation_rejection_count": int(
			validator.get("mutation_rejection_count", -1)
		),
		"transport_nextafter_up_rejected": bool(
			validator.get("nextafter_up_rejected", false)
		),
		"transport_nextafter_down_rejected": bool(
			validator.get("nextafter_down_rejected", false)
		),
		"configured_motor_parameters_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
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


static func _preflight_exact(preflight: Dictionary, profile_id: String) -> bool:
	return (
		bool(preflight.get("ok", false))
		and String(preflight.get("policy_id", "")) == FactorialBindingScript.POLICY_ID
		and String(preflight.get("profile_id", "")) == profile_id
		and int(preflight.get("validated_actuator_count", -1)) == 8
		and int(preflight.get("validated_limb_count", -1)) == 4
		and int(preflight.get("unique_host_joint_object_count", -1)) == 8
		and int(preflight.get("portable_fixture_distinct_actuator_count", -1)) == 8
		and int(preflight.get("scene_tree_insertion_count", -1)) == 0
		and int(preflight.get("world_build_count", -1)) == 0
	)


static func _binding_exact(binding: Dictionary, profile_id: String) -> bool:
	var definition: Dictionary = FactorialBindingScript.profile_definition(profile_id)
	return (
		bool(binding.get("ok", false))
		and String(binding.get("schema_version", ""))
		== FactorialBindingScript.RECEIPT_SCHEMA_VERSION
		and String(binding.get("policy_id", "")) == FactorialBindingScript.POLICY_ID
		and String(binding.get("profile_id", "")) == profile_id
		and String(binding.get("hip_cap_source", "")) == String(definition["hip_cap_source"])
		and String(binding.get("knee_cap_source", ""))
		== String(definition["knee_cap_source"])
		and int(binding.get("validated_actuator_count", -1)) == 8
		and int(binding.get("validated_limb_count", -1)) == 4
		and int(binding.get("unique_host_joint_object_count", -1)) == 8
		and int(binding.get("portable_fixture_distinct_actuator_count", -1)) == 8
		and int(binding.get("write_count", -1)) == 8
		and int(binding.get("readback_count", -1)) == 8
		and float(binding.get("maximum_postbinding_readback_error_nms", INF))
		<= READBACK_TOLERANCE_NMS
		and int(binding.get("scene_tree_insertion_count", -1)) == 0
		and int(binding.get("world_build_count", -1)) == 0
	)


static func _run_python_validator(terminal: Dictionary, trace: Dictionary) -> Dictionary:
	var root := OS.get_user_data_dir().path_join(
		"r23d58-zero-world-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	if DirAccess.dir_exists_absolute(root):
		return _failure("R23D58_TEMP_ROOT_ALREADY_EXISTS")
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		return _failure("R23D58_TEMP_ROOT_CREATE_FAILED")
	var terminal_path := root.path_join("terminal.full.json")
	var trace_path := root.path_join("trace.full.json")
	var default_terminal_path := root.path_join("terminal.default.json")
	var wrote := (
		_write_text(terminal_path, JsonTransportScript.line(terminal))
		and _write_text(trace_path, JsonTransportScript.line(trace))
		and _write_text(default_terminal_path, JSON.stringify(terminal, "", true, false) + "\n")
	)
	if not wrote:
		_cleanup_temp_root(root, [terminal_path, trace_path, default_terminal_path])
		return _failure("R23D58_TEMP_PAYLOAD_WRITE_FAILED")
	var python := OS.get_environment("SPORESPORE_QSDK_R23D58_PYTHON_PATH")
	if python.is_empty():
		python = "python"
	var output: Array = []
	var exit_code := OS.execute(
		python,
		PackedStringArray(
			[
				ProjectSettings.globalize_path(PYTHON_VALIDATOR_PATH),
				"--terminal-json",
				terminal_path,
				"--trace-json",
				trace_path,
				"--default-terminal-json",
				default_terminal_path,
			]
		),
		output,
		true,
	)
	_cleanup_temp_root(root, [terminal_path, trace_path, default_terminal_path])
	var marker := "QSDK_R23D58_TERMINAL_TRACE_CANARY "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _failure(
			"R23D58_PYTHON_VALIDATOR_FAILED:%d" % exit_code,
			{"output": output},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _failure("R23D58_PYTHON_VALIDATOR_RECEIPT_INVALID")
	return parsed


static func _write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	file = null
	return true


static func _cleanup_temp_root(root: String, paths: Array) -> void:
	var normalized_root := root.simplify_path()
	var expected_parent := OS.get_user_data_dir().simplify_path().trim_suffix("/") + "/"
	if not normalized_root.begins_with(expected_parent) or not normalized_root.get_file().begins_with(
		"r23d58-zero-world-"
	):
		return
	for path_value in paths:
		var path := String(path_value).simplify_path()
		if path.begins_with(normalized_root.trim_suffix("/") + "/"):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(normalized_root)


static func _binder_mutation_controls(
	prepared: Dictionary,
	morphology: Dictionary,
) -> Dictionary:
	return {
		"unknown_profile_rejected_without_write": _binder_mutation_rejected(
			prepared, morphology, "unknown_profile"
		),
		"wrong_policy_rejected_without_write": _binder_mutation_rejected(
			prepared, morphology, "wrong_policy"
		),
		"missing_joint_rejected_without_write": _binder_mutation_rejected(
			prepared, morphology, "missing_joint"
		),
		"extra_joint_rejected_without_write": _binder_mutation_rejected(
			prepared, morphology, "extra_joint"
		),
		"duplicate_host_object_rejected_without_write": _binder_mutation_rejected(
			prepared, morphology, "duplicate_object"
		),
		"wrong_fixture_marker_rejected_without_write": _binder_mutation_rejected(
			prepared, morphology, "wrong_marker"
		),
		"wrong_host_name_rejected_without_write": _binder_mutation_rejected(
			prepared, morphology, "wrong_name"
		),
		"zero_portable_cap_rejected_without_write": _binder_mutation_rejected(
			prepared, morphology, "zero_cap"
		),
		"nonfinite_portable_cap_rejected_without_write": _binder_mutation_rejected(
			prepared, morphology, "nonfinite_cap"
		),
		"excessive_tolerance_rejected_without_write": _binder_mutation_rejected(
			prepared, morphology, "excessive_tolerance"
		),
		"validation_before_binding_rejected": _binder_mutation_rejected(
			prepared, morphology, "validation_before_binding"
		),
		"duplicate_binding_rejected": _binder_mutation_rejected(
			prepared, morphology, "duplicate_binding"
		),
	}


static func _binder_mutation_rejected(
	prepared: Dictionary,
	morphology: Dictionary,
	mutation_id: String,
) -> bool:
	var surface := _fixture_surface(prepared)
	if not bool(surface.get("ok", false)):
		return false
	var before := _surface_caps(surface)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	var candidate_morphology := morphology.duplicate(true)
	var profile_id := FactorialBindingScript.PROFILE_PORTABLE_HIP_PORTABLE_KNEE
	var policy_id := FactorialBindingScript.POLICY_ID
	var tolerance := READBACK_TOLERANCE_NMS
	var extra_joint: HingeJoint3D
	match mutation_id:
		"unknown_profile":
			profile_id = "mutated"
		"wrong_policy":
			policy_id = "mutated"
		"missing_joint":
			states.erase(states.keys()[0])
		"extra_joint":
			extra_joint = HingeJoint3D.new()
			states["unexpected.hip_pitch"] = {"joint": extra_joint}
		"duplicate_object":
			var ids: Array = states.keys()
			(states[ids[1]] as Dictionary)["joint"] = (states[ids[0]] as Dictionary)["joint"]
		"wrong_marker":
			var marker_joint: HingeJoint3D = (states[states.keys()[0]] as Dictionary)["joint"]
			marker_joint.set_meta("sporespore_fixture_joint_composition_schema_version", "mutated")
		"wrong_name":
			var named_joint: HingeJoint3D = (states[states.keys()[0]] as Dictionary)["joint"]
			named_joint.name = "mutated"
		"zero_cap", "nonfinite_cap":
			var spec: Dictionary = candidate_morphology["morphology_spec"]
			var actuators: Array = spec["actuators"]
			(actuators[0] as Dictionary)["maximum_impulse_nms"] = (
				0.0 if mutation_id == "zero_cap" else NAN
			)
		"excessive_tolerance":
			tolerance = FactorialBindingScript.MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS * 2.0
		"validation_before_binding":
			var early: Dictionary = FactorialBindingScript.new().validate_bound_profile(
				states, tolerance, profile_id, policy_id
			)
			var early_rejected := not bool(early.get("ok", true)) and _caps_unchanged(surface, before)
			_free_surface(surface)
			return early_rejected
		"duplicate_binding":
			var duplicate_binder: RefCounted = FactorialBindingScript.new()
			var first: Dictionary = duplicate_binder.bind_profile(
				candidate_morphology, states, tolerance, profile_id, policy_id
			)
			var after_first := _surface_caps(surface)
			var second: Dictionary = duplicate_binder.bind_profile(
				candidate_morphology, states, tolerance, profile_id, policy_id
			)
			var duplicate_rejected := (
				bool(first.get("ok", false))
				and not bool(second.get("ok", true))
				and _caps_unchanged(surface, after_first)
			)
			_free_surface(surface)
			return duplicate_rejected
	var result: Dictionary = FactorialBindingScript.new().bind_profile(
		candidate_morphology,
		states,
		tolerance,
		profile_id,
		policy_id,
	)
	var rejected := not bool(result.get("ok", true)) and _caps_unchanged(surface, before)
	if is_instance_valid(extra_joint):
		extra_joint.free()
	_free_surface(surface)
	return rejected


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


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r23d58_godot_terminal_trace_cap_factorial_zero_world_v1",
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
