extends SceneTree

## Zero-world authority contract for the prospective BW15F sign/gain family.
##
## This test creates no PhysicsServer body or simulation world. It proves all
## treatments inherit BW5R-B except for one explicit, branch-free velocity-error
## orientation and one global bounded gain.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const PREREGISTRATION_PATH := (
	"res://sdk/balanced_wave_bw15f_morphology_development_preregistration.json"
)
const CLASS_NAME := "SporeLocomotionSdk"
const CANDIDATE_IDS := ["BW15F-A", "BW15F-B", "BW15F-C", "BW15F-D"]
const POLICY_IDS := [
	"sporespore_balanced_wave_bw5r_b_v1",
	"sporespore_balanced_wave_bw15f_b_v1",
	"sporespore_balanced_wave_bw15f_c_v1",
	"sporespore_balanced_wave_bw15f_d_v1",
]
const PROFILE_SHA256 := [
	"sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e",
	"sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413",
	"sha256:c18b5ff2202060a4f6e8e0a93c57eb9137e5394c99170e4b8edb9a569340f796",
	"sha256:7355df08b7650412326535fdc51fba0e805dc20b1b8fe7d3d018537eeb503466",
]
const ORIENTATION_IDS := [
	"",
	"desired_minus_measured_forward_velocity_error_v1",
	"measured_minus_desired_forward_velocity_error_v1",
	"measured_minus_desired_forward_velocity_error_v1",
]
const MAXIMUM_CORRECTIONS := [0.0, 0.03, 0.03, 0.06]
const EXPECTED_SLOW_ERRORS := [0.0, 1.0, -1.0, -1.0]
const MODE_ID := "forward_velocity_foot_placement_v1"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK balanced-wave BW15F zero-world authority contract ===")
	var preregistration := _read_json(PREREGISTRATION_PATH)
	_check(
		String(preregistration.get("schema_version", ""))
		== "sporespore_balanced_wave_bw15f_morphology_development_preregistration_v1"
		and (preregistration.get("candidate_order", []) as Array) == CANDIDATE_IDS,
		"the four-arm preregistration loads in frozen candidate order",
	)
	var extension_resource := load(EXTENSION_PATH)
	_check(
		extension_resource != null and ClassDB.class_exists(CLASS_NAME),
		"the checked-in GDExtension and native SDK class load",
	)
	if not ClassDB.class_exists(CLASS_NAME):
		_finish()
		return
	var api: Object = ClassDB.instantiate(CLASS_NAME)
	if api == null:
		_check(false, "the native SDK class instantiates")
		_finish()
		return

	var descriptor := _reference_descriptor()
	var compile_envelope := _call_input(api, "compile_bounded_quadruped_json", descriptor)
	var morphology: Dictionary = (
		(compile_envelope.get("value", {}) as Dictionary).get("morphology", {})
	)
	_check(
		bool(compile_envelope.get("ok", false)) and not morphology.is_empty(),
		"the reference descriptor compiles without a world",
	)
	if morphology.is_empty():
		_finish()
		return

	var candidates: Array = preregistration.get("candidates", [])
	var candidate_digests: Dictionary = preregistration.get("candidate_policy_digests", {})
	var profiles: Array[Dictionary] = []
	var profile_contract_exact := candidates.size() == 4
	for index in range(4):
		var profile_envelope := _profile(api, descriptor, String(POLICY_IDS[index]))
		var profile: Dictionary = profile_envelope.get("value", {})
		profiles.append(profile)
		var candidate: Dictionary = candidates[index]
		var expected_profile_schema := (
			"sporespore_balanced_wave_filtered_profile_v1"
			if index == 0
			else "sporespore_balanced_wave_signed_forward_velocity_foot_placement_profile_v1"
		)
		profile_contract_exact = (
			profile_contract_exact
			and bool(profile_envelope.get("ok", false))
			and String(profile.get("schema_version", "")) == expected_profile_schema
			and String(profile.get("policy_id", "")) == String(POLICY_IDS[index])
			and CanonicalJsonScript.sha256(profile) == String(PROFILE_SHA256[index])
			and String(candidate.get("candidate_id", "")) == String(CANDIDATE_IDS[index])
			and String(candidate.get("controller_policy_id", "")) == String(POLICY_IDS[index])
			and String(candidate.get("runtime_profile_sha256", ""))
			== String(PROFILE_SHA256[index])
			and CanonicalJsonScript.sha256(candidate)
			== String(candidate_digests.get(CANDIDATE_IDS[index], ""))
			and (profile.get("branch_surfaces", []) as Array).is_empty()
			and bool(profile.get("controller_authority", false))
			and not bool(profile.get("physical_acceptance_authority", true))
		)
		if index == 0:
			profile_contract_exact = (
				profile_contract_exact
				and not profile.has("forward_velocity_foot_placement_mode_id")
				and not profile.has("forward_velocity_error_orientation_id")
				and not profile.has("maximum_forward_velocity_hip_target_correction_rad")
			)
		else:
			profile_contract_exact = (
				profile_contract_exact
				and String(profile.get("forward_velocity_foot_placement_mode_id", ""))
				== MODE_ID
				and String(profile.get("forward_velocity_error_orientation_id", ""))
				== String(ORIENTATION_IDS[index])
				and is_equal_approx(
					float(profile.get(
						"maximum_forward_velocity_hip_target_correction_rad",
						NAN,
					)),
					float(MAXIMUM_CORRECTIONS[index]),
				)
			)
	_check(
		profile_contract_exact,
		"all runtime profiles and candidate declarations are hash-bound and branch-free",
	)

	var inheritance_exact := true
	var comparable_control := profiles[0].duplicate(true)
	for field in ["schema_version", "policy_id"]:
		comparable_control.erase(field)
	for index in range(1, 4):
		var comparable_treatment := profiles[index].duplicate(true)
		for field in [
			"schema_version",
			"policy_id",
			"forward_velocity_foot_placement_mode_id",
			"forward_velocity_error_orientation_id",
			"maximum_forward_velocity_hip_target_correction_rad",
		]:
			comparable_treatment.erase(field)
		inheritance_exact = inheritance_exact and comparable_control == comparable_treatment
	_check(
		inheritance_exact,
		"every non-mechanism profile field is inherited exactly from BW5R-B",
	)

	var memory_envelope := _call_no_input(api, "balanced_wave_initial_memory_json")
	var initial_memory: Dictionary = memory_envelope.get("value", {})
	var slow_receipts: Array[Dictionary] = []
	var step_contract_exact := bool(memory_envelope.get("ok", false))
	for index in range(1, 4):
		var slow := _step(
			api,
			String(POLICY_IDS[index]),
			descriptor,
			initial_memory,
			_state_frame(morphology, 0.0),
			_motion_command(0.2),
		)
		var on_target := _step(
			api,
			String(POLICY_IDS[index]),
			descriptor,
			initial_memory,
			_state_frame(morphology, 0.2),
			_motion_command(0.2),
		)
		var zero_desired := _step(
			api,
			String(POLICY_IDS[index]),
			descriptor,
			initial_memory,
			_state_frame(morphology, 0.4),
			_motion_command(0.0),
		)
		var slow_receipt := _mechanism_receipt(slow)
		var target_receipt := _mechanism_receipt(on_target)
		var zero_receipt := _mechanism_receipt(zero_desired)
		slow_receipts.append(slow_receipt)
		step_contract_exact = (
			step_contract_exact
			and _step_receipt_exact(
				slow,
				String(POLICY_IDS[index]),
				String(ORIENTATION_IDS[index]),
				float(MAXIMUM_CORRECTIONS[index]),
				float(EXPECTED_SLOW_ERRORS[index]),
			)
			and _all_corrections_zero(target_receipt)
			and _all_corrections_zero(zero_receipt)
		)
	_check(
		step_contract_exact,
		"every treatment emits an exact typed v5 receipt and exact zero at target or zero command",
	)

	var factorial_exact := true
	var b_corrections: Array = slow_receipts[0].get("ordered_limb_corrections", [])
	var c_corrections: Array = slow_receipts[1].get("ordered_limb_corrections", [])
	var d_corrections: Array = slow_receipts[2].get("ordered_limb_corrections", [])
	for index in range(4):
		var b_value := float(
			(b_corrections[index] as Dictionary).get(
				"applied_hip_target_correction_rad",
				NAN,
			)
		)
		var c_value := float(
			(c_corrections[index] as Dictionary).get(
				"applied_hip_target_correction_rad",
				NAN,
			)
		)
		var d_value := float(
			(d_corrections[index] as Dictionary).get(
				"applied_hip_target_correction_rad",
				NAN,
			)
		)
		factorial_exact = (
			factorial_exact
			and absf(b_value + c_value) <= 1.0e-12
			and absf(d_value - 2.0 * c_value) <= 1.0e-12
		)
	_check(
		factorial_exact,
		"B/C isolate orientation at fixed gain and C/D isolate gain at fixed orientation",
	)

	var material_result := MaterialProfilesScript.resolve("godot_jolt_bw5c_mu095_v1")
	var routing_exact := bool(material_result.get("ok", false))
	for policy_id_value in POLICY_IDS:
		var policy_id := String(policy_id_value)
		var normalized := WaveGaitScript._normalize_sdk_authority_options(
			{
				"enabled": true,
				"descriptor": descriptor,
				"comparison_tolerance": 2.5e-7,
				"authority_scope": "post_settle_full",
				"stability_policy_id": "p5i3b_weight_support_shadow_v1",
				"material_profile_id": "godot_jolt_bw5c_mu095_v1",
				"controller_policy_id": policy_id,
			}
		)
		var adapter := AdapterScript.new()
		var started := adapter.start(
			descriptor,
			{
				"front_left": 0,
				"front_right": 0,
				"rear_left": 0,
				"rear_right": 0,
			},
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			0.0,
			120,
			{
				"solver_policy_id": "jolt_120hz_20v_7p_v1",
				"physics_engine": "Jolt Physics",
				"physics_hz": 120,
				"solver_velocity_steps": 20,
				"solver_position_steps": 7,
			},
			2.5e-7,
			"clocked",
			true,
			0,
			360,
			"post_settle_full",
			"p5i3b_weight_support_shadow_v1",
			material_result.get("profile", {}),
			policy_id,
		)
		var boundary: Dictionary = {}
		if bool(started.get("ok", false)):
			boundary = adapter.preflight_perfect_declared_policy_runtime_boundary()
		routing_exact = (
			routing_exact
			and bool(normalized.get("ok", false))
			and bool(started.get("ok", false))
			and String(started.get("controller_policy_id", "")) == policy_id
			and bool(started.get("actuation_authority", false))
			and int(started.get("world_build_count", -1)) == 0
			and bool(boundary.get("ok", false))
			and String(boundary.get("controller_policy_id", "")) == policy_id
			and int(boundary.get("actual_world_build_count", -1)) == 0
			and not bool(boundary.get("locomotion_outcome_exposed", true))
		)
	_check(
		routing_exact and root.get_child_count() == 0,
		"all four candidates route through native full authority with zero worlds",
	)
	_finish()


func _profile(api: Object, descriptor: Dictionary, policy_id: String) -> Dictionary:
	return _call_input(
		api,
		"balanced_wave_policy_profile_json",
		{
			"schema_version": "sporespore_balanced_wave_policy_profile_request_v1",
			"policy_id": policy_id,
			"descriptor": descriptor,
		},
	)


func _step(
	api: Object,
	policy_id: String,
	descriptor: Dictionary,
	memory: Dictionary,
	state: Dictionary,
	command: Dictionary,
) -> Dictionary:
	return _call_input(
		api,
		"balanced_wave_policy_step_json",
		{
			"schema_version": "sporespore_balanced_wave_policy_step_request_v1",
			"policy_id": policy_id,
			"descriptor": descriptor,
			"memory": memory,
			"state": state,
			"command": command,
		},
	)


func _mechanism_receipt(step_envelope: Dictionary) -> Dictionary:
	var output: Dictionary = step_envelope.get("value", {})
	var actuation: Dictionary = output.get("actuation", {})
	var receipt: Dictionary = actuation.get("receipt", {})
	return receipt.get("forward_velocity_foot_placement", {})


func _step_receipt_exact(
	step_envelope: Dictionary,
	policy_id: String,
	orientation_id: String,
	maximum_correction: float,
	expected_error: float,
) -> bool:
	var output: Dictionary = step_envelope.get("value", {})
	var actuation: Dictionary = output.get("actuation", {})
	var receipt: Dictionary = actuation.get("receipt", {})
	var mechanism := _mechanism_receipt(step_envelope)
	var corrections: Array = mechanism.get("ordered_limb_corrections", [])
	var expected_order := ["front_left", "front_right", "rear_left", "rear_right"]
	var corrections_exact := corrections.size() == 4
	for index in range(mini(corrections.size(), expected_order.size())):
		var correction: Dictionary = corrections[index]
		var envelope := float(correction.get("cycle_envelope", NAN))
		var applied := float(correction.get("applied_hip_target_correction_rad", NAN))
		corrections_exact = (
			corrections_exact
			and String(correction.get("limb_id", "")) == String(expected_order[index])
			and int(correction.get("local_phase_step", -1)) in range(360)
			and is_finite(envelope)
			and envelope >= 0.0
			and envelope <= 1.0
			and is_finite(applied)
			and absf(applied) <= maximum_correction + 1.0e-12
		)
	return (
		bool(step_envelope.get("ok", false))
		and not bool(actuation.get("safe_no_actuation", true))
		and String(receipt.get("schema_version", ""))
		== "sporespore_controller_step_receipt_v5"
		and String(receipt.get("policy_id", "")) == policy_id
		and String(mechanism.get("schema_version", ""))
		== "sporespore_forward_velocity_foot_placement_receipt_v2"
		and String(mechanism.get("mode_id", "")) == MODE_ID
		and String(mechanism.get("velocity_error_orientation_id", "")) == orientation_id
		and is_equal_approx(
			float(mechanism.get("normalized_forward_velocity_error", NAN)),
			expected_error,
		)
		and is_equal_approx(
			float(mechanism.get("maximum_hip_target_correction_rad", NAN)),
			maximum_correction,
		)
		and corrections_exact
		and int(mechanism.get("morphology_branch_surface_count", -1)) == 0
		and bool(mechanism.get("controller_parameter", false))
		and not bool(mechanism.get("walking_claim_authorized", true))
		and not bool(mechanism.get("physical_acceptance_authority", true))
	)


func _all_corrections_zero(mechanism: Dictionary) -> bool:
	var corrections: Array = mechanism.get("ordered_limb_corrections", [])
	if corrections.size() != 4:
		return false
	for correction_value in corrections:
		var correction: Dictionary = correction_value
		if not is_zero_approx(
			float(correction.get("applied_hip_target_correction_rad", NAN))
		):
			return false
	return true


func _reference_descriptor() -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": "bw15f_zero_world_reference",
		"torso_length_scale": 1.0,
		"torso_width_scale": 1.0,
		"upper_length_fraction": 18.0 / 35.0,
		"hip_span_scale": 1.0,
		"foot_radius_scale": 1.0,
		"front_limb_mass_scale": 1.0,
	}


func _state_frame(morphology: Dictionary, forward_velocity_m_s: float) -> Dictionary:
	var joints: Array = []
	for joint_id_value in morphology.get("ordered_joint_ids", []):
		joints.append({
			"joint_id": String(joint_id_value),
			"position_rad": 0.0,
			"velocity_rad_s": 0.0,
			"anchor_error_m": 0.0,
			"validity": {
				"position": true,
				"velocity": true,
				"anchor_error": true,
			},
		})
	var contacts: Array = []
	for contact_id_value in morphology.get("ordered_contact_site_ids", []):
		var contact_id := String(contact_id_value)
		contacts.append({
			"contact_site_id": contact_id,
			"presence": true,
			"bears_support": true,
			"normal_load_n": null,
			"provenance": {
				"adapter_id": "bw15f_zero_world_contract",
				"engine_contact_ids": ["%s_zero_world" % contact_id],
				"aggregation_rule_id": "qualified_bearing_only",
				"quality": "qualified_bearing",
			},
		})
	return {
		"schema_version": "sporespore_state_frame_v1",
		"semantic_step": 0,
		"sample_time_s": 0.0,
		"base_pose_world": {
			"position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
			"orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		},
		"base_twist_world": {
			"linear_velocity_m_s": {
				"x": forward_velocity_m_s,
				"y": 0.0,
				"z": 0.0,
			},
			"angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
		},
		"ordered_joint_observations": joints,
		"ordered_contact_observations": contacts,
		"previous_applied_actuation": null,
		"gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
		"task_frame": {
			"origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
			"forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
			"lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
			"up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
			"reference_yaw_rad": 0.0,
		},
		"adapter_capability_sha256":
		"sha256:1515151515151515151515151515151515151515151515151515151515151515",
	}


func _motion_command(desired_forward_velocity_m_s: float) -> Dictionary:
	return {
		"schema_version": "sporespore_motion_command_v2",
		"command_id": "bw15f_zero_world_forward_velocity",
		"desired_planar_velocity_task_m_s": {
			"x": desired_forward_velocity_m_s,
			"y": 0.0,
			"z": 0.0,
		},
		"desired_heading_rad": 0.0,
		"desired_yaw_rate_rad_s": null,
		"gait_family_id": "lateral_wave",
		"speed_class": "walk",
		"gait_amplitude": 1.0,
		"phase_progression_mode": "contact_gated",
		"valid_from_step": 0,
		"valid_through_step": 0,
		"authority": "test_fixture",
	}


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _call_input(api: Object, method: StringName, value: Dictionary) -> Dictionary:
	var response := String(api.call(method, JSON.stringify(value, "", true, true)))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _call_no_input(api: Object, method: StringName) -> Dictionary:
	var response := String(api.call(method))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print("SDK BW15F authority summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
