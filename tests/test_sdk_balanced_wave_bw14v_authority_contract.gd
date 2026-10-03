extends SceneTree

## Zero-world authority contract for the prospective BW14V controller.
##
## This test creates no PhysicsServer body or simulation world. It proves the
## new policy inherits BW5R-B exactly except for one branch-free, bounded
## forward-velocity foot-placement term and emits a complete typed receipt.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const CONTROL_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const TREATMENT_POLICY_ID := "sporespore_balanced_wave_bw14v_b_v1"
const PROFILE_SCHEMA := (
	"sporespore_balanced_wave_forward_velocity_foot_placement_profile_v1"
)
const RECEIPT_SCHEMA := "sporespore_controller_step_receipt_v4"
const MECHANISM_RECEIPT_SCHEMA := (
	"sporespore_forward_velocity_foot_placement_receipt_v1"
)
const MODE_ID := "forward_velocity_foot_placement_v1"
const EXPECTED_CONTROL_PROFILE_SHA256 := (
	"sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e"
)
const EXPECTED_TREATMENT_PROFILE_SHA256 := (
	"sha256:7cecabe8ce4ec185713ff8e0b7d28a8f812575a36c67bbb26df50df74ea9fd5e"
)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK balanced-wave BW14V zero-world authority contract ===")
	var extension_resource := load(EXTENSION_PATH)
	_check(extension_resource != null, "the checked-in GDExtension resource loads")
	_check(ClassDB.class_exists(CLASS_NAME), "the native SDK class is registered")
	if not ClassDB.class_exists(CLASS_NAME):
		_finish()
		return
	var api: Object = ClassDB.instantiate(CLASS_NAME)
	_check(api != null, "the native SDK class instantiates")
	if api == null:
		_finish()
		return

	var descriptor := _reference_descriptor()
	var compile_envelope := _call_input(
		api,
		"compile_bounded_quadruped_json",
		descriptor,
	)
	_check(bool(compile_envelope.get("ok", false)), "the reference descriptor compiles")
	if not bool(compile_envelope.get("ok", false)):
		_finish()
		return
	var morphology: Dictionary = (
		(compile_envelope.get("value", {}) as Dictionary).get("morphology", {})
	)
	var control_envelope := _profile(api, descriptor, CONTROL_POLICY_ID)
	var treatment_envelope := _profile(api, descriptor, TREATMENT_POLICY_ID)
	var control: Dictionary = control_envelope.get("value", {})
	var treatment: Dictionary = treatment_envelope.get("value", {})
	var control_sha := CanonicalJsonScript.sha256(control)
	var treatment_sha := CanonicalJsonScript.sha256(treatment)
	print("BW14V_CONTROL_PROFILE_SHA256=", control_sha)
	print("BW14V_TREATMENT_PROFILE_SHA256=", treatment_sha)
	print(
		"BW14V_A_CANDIDATE_SHA256=",
		CanonicalJsonScript.sha256(_candidate(false, control_sha)),
	)
	print(
		"BW14V_B_CANDIDATE_SHA256=",
		CanonicalJsonScript.sha256(_candidate(true, treatment_sha)),
	)
	_check(
		bool(control_envelope.get("ok", false))
		and control_sha == EXPECTED_CONTROL_PROFILE_SHA256,
		"the BW5R-B control profile remains byte-identical",
	)
	_check(
		bool(treatment_envelope.get("ok", false))
		and String(treatment.get("schema_version", "")) == PROFILE_SCHEMA
		and String(treatment.get("policy_id", "")) == TREATMENT_POLICY_ID
		and String(treatment.get("forward_velocity_foot_placement_mode_id", ""))
		== MODE_ID
		and is_equal_approx(
			float(treatment.get(
				"maximum_forward_velocity_hip_target_correction_rad",
				NAN,
			)),
			0.30,
		)
		and (treatment.get("branch_surfaces", []) as Array).is_empty()
		and bool(treatment.get("controller_authority", false))
		and not bool(treatment.get("physical_acceptance_authority", true)),
		"the treatment profile declares exactly one bounded branch-free mechanism",
	)
	_check(
		not EXPECTED_TREATMENT_PROFILE_SHA256.is_empty()
		and treatment_sha == EXPECTED_TREATMENT_PROFILE_SHA256,
		"the treatment runtime profile is hash-bound",
	)
	var comparable_control := control.duplicate(true)
	var comparable_treatment := treatment.duplicate(true)
	for field in [
		"schema_version",
		"policy_id",
		"forward_velocity_foot_placement_mode_id",
		"maximum_forward_velocity_hip_target_correction_rad",
	]:
		comparable_control.erase(field)
		comparable_treatment.erase(field)
	_check(
		comparable_control == comparable_treatment,
		"every non-mechanism profile field is inherited exactly from BW5R-B",
	)

	var memory_envelope := _call_no_input(api, "balanced_wave_initial_memory_json")
	var initial_memory: Dictionary = memory_envelope.get("value", {})
	var command := _motion_command()
	var slow := _step(
		api,
		descriptor,
		initial_memory,
		_state_frame(morphology, 0.0),
		command,
	)
	var on_target := _step(
		api,
		descriptor,
		initial_memory,
		_state_frame(morphology, 0.2),
		command,
	)
	var fast := _step(
		api,
		descriptor,
		initial_memory,
		_state_frame(morphology, 0.4),
		command,
	)
	var slow_receipt := _mechanism_receipt(slow)
	var target_receipt := _mechanism_receipt(on_target)
	var fast_receipt := _mechanism_receipt(fast)
	var step_contract_exact := (
		bool(memory_envelope.get("ok", false))
		and _step_receipt_exact(slow, slow_receipt, 1.0)
		and _step_receipt_exact(on_target, target_receipt, 0.0)
		and _step_receipt_exact(fast, fast_receipt, -1.0)
	)
	_check(
		step_contract_exact,
		"slow, on-target, and fast steps emit exact signed typed receipts",
	)
	var sign_reversal_exact := true
	var slow_corrections: Array = slow_receipt.get("ordered_limb_corrections", [])
	var target_corrections: Array = target_receipt.get("ordered_limb_corrections", [])
	var fast_corrections: Array = fast_receipt.get("ordered_limb_corrections", [])
	for index in range(4):
		var slow_correction: Dictionary = slow_corrections[index]
		var target_correction: Dictionary = target_corrections[index]
		var fast_correction: Dictionary = fast_corrections[index]
		sign_reversal_exact = (
			sign_reversal_exact
			and String(slow_correction.get("limb_id", ""))
			== String(fast_correction.get("limb_id", ""))
			and int(slow_correction.get("local_phase_step", -1))
			== int(fast_correction.get("local_phase_step", -2))
			and is_equal_approx(
				float(slow_correction.get("cycle_envelope", NAN)),
				float(fast_correction.get("cycle_envelope", NAN)),
			)
			and absf(
				float(slow_correction.get("applied_hip_target_correction_rad", NAN))
				+ float(fast_correction.get(
					"applied_hip_target_correction_rad",
					NAN,
				))
			) <= 1.0e-12
			and is_zero_approx(float(target_correction.get(
				"applied_hip_target_correction_rad",
				NAN,
			)))
		)
	_check(
		sign_reversal_exact,
		"each limb correction reverses sign and is exactly zero at commanded speed",
	)

	var material_result := MaterialProfilesScript.resolve("godot_jolt_bw5c_mu095_v1")
	var normalized := WaveGaitScript._normalize_sdk_authority_options(
		{
			"enabled": true,
			"descriptor": descriptor,
			"comparison_tolerance": 2.5e-7,
			"authority_scope": "post_settle_full",
			"stability_policy_id": "p5i3b_weight_support_shadow_v1",
			"material_profile_id": "godot_jolt_bw5c_mu095_v1",
			"controller_policy_id": TREATMENT_POLICY_ID,
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
		TREATMENT_POLICY_ID,
	)
	var boundary: Dictionary = {}
	if bool(started.get("ok", false)):
		boundary = adapter.preflight_perfect_declared_policy_runtime_boundary()
	_check(
		bool(material_result.get("ok", false))
		and bool(normalized.get("ok", false))
		and bool(started.get("ok", false))
		and String(started.get("controller_policy_id", "")) == TREATMENT_POLICY_ID
		and String(started.get("authority_scope", "")) == "post_settle_full"
		and bool(started.get("actuation_authority", false))
		and int(started.get("world_build_count", -1)) == 0
		and bool(boundary.get("ok", false))
		and String(boundary.get("controller_policy_id", "")) == TREATMENT_POLICY_ID
		and int(boundary.get("actual_world_build_count", -1)) == 0
		and not bool(boundary.get("locomotion_outcome_exposed", true))
		and root.get_child_count() == 0,
		"the runner and adapter route BW14V-B through full authority with zero worlds",
	)
	_finish()


func _candidate(treatment: bool, runtime_profile_sha256: String) -> Dictionary:
	return {
		"candidate_id": "BW14V-B" if treatment else "BW14V-A",
		"controller_policy_id": TREATMENT_POLICY_ID if treatment else CONTROL_POLICY_ID,
		"mode": "forward_velocity_foot_placement" if treatment else "control",
		"parent_candidate_id": "BW5R-B",
		"parent_policy_id": CONTROL_POLICY_ID,
		"profile_schema_version":
		PROFILE_SCHEMA if treatment else "sporespore_balanced_wave_filtered_profile_v1",
		"runtime_profile_sha256": runtime_profile_sha256,
		"forward_velocity_foot_placement_mode_id": MODE_ID if treatment else null,
		"desired_velocity_source": "motion_command.desired_planar_velocity_task_m_s.x",
		"measured_velocity_source":
		"dot(state.base_twist_world.linear_velocity_m_s, task_frame.forward_axis_world_unit)",
		"normalized_error_formula":
		"clamp((desired-measured)/abs(desired),-1,1); exact_zero_when_abs(desired)<=1e-12",
		"maximum_hip_target_correction_rad": 0.30 if treatment else 0.0,
		"maximum_correction_source":
		"existing_lateral_wave_hip_forward_target_rad" if treatment else "none",
		"cycle_envelope":
		"smoothstep(swing_fraction); 1-smoothstep(stance_fraction)" if treatment else "none",
		"morphology_condition_count": 0,
		"material_condition_count": 0,
		"seed_condition_count": 0,
		"failure_identity_condition_count": 0,
		"outcome_condition_count": 0,
		"new_fitted_numeric_threshold_count": 0,
		"branch_surfaces": [],
	}


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
			"policy_id": TREATMENT_POLICY_ID,
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
	mechanism: Dictionary,
	expected_error: float,
) -> bool:
	var output: Dictionary = step_envelope.get("value", {})
	var actuation: Dictionary = output.get("actuation", {})
	var receipt: Dictionary = actuation.get("receipt", {})
	var corrections: Array = mechanism.get("ordered_limb_corrections", [])
	var corrections_exact := corrections.size() == 4
	var expected_order := ["front_left", "front_right", "rear_left", "rear_right"]
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
			and absf(applied) <= 0.30 + 1.0e-12
		)
	return (
		bool(step_envelope.get("ok", false))
		and not bool(actuation.get("safe_no_actuation", true))
		and String(receipt.get("schema_version", "")) == RECEIPT_SCHEMA
		and String(receipt.get("policy_id", "")) == TREATMENT_POLICY_ID
		and String(mechanism.get("schema_version", "")) == MECHANISM_RECEIPT_SCHEMA
		and String(mechanism.get("mode_id", "")) == MODE_ID
		and is_equal_approx(
			float(mechanism.get("normalized_forward_velocity_error", NAN)),
			expected_error,
		)
		and is_equal_approx(
			float(mechanism.get("maximum_hip_target_correction_rad", NAN)),
			0.30,
		)
		and corrections_exact
		and int(mechanism.get("morphology_branch_surface_count", -1)) == 0
		and bool(mechanism.get("controller_parameter", false))
		and not bool(mechanism.get("walking_claim_authorized", true))
		and not bool(mechanism.get("physical_acceptance_authority", true))
	)


func _reference_descriptor() -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": "bw14v_zero_world_reference",
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
				"adapter_id": "bw14v_zero_world_contract",
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
		"sha256:1414141414141414141414141414141414141414141414141414141414141414",
	}


func _motion_command() -> Dictionary:
	return {
		"schema_version": "sporespore_motion_command_v2",
		"command_id": "bw14v_zero_world_forward_velocity",
		"desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
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
	print("SDK BW14V authority summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
