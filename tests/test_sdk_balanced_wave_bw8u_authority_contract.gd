extends SceneTree

## Zero-world authority contract for the prospective BW8U mechanism family.
##
## This test creates no PhysicsServer body or simulation world. It binds the
## public native profile and step ABIs, the branch-free 2x2 candidate records,
## and the exact loaded-release-gate receipt and command behavior.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw8u_preregistration.json"
const PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw8u_preregistration_v1"
const EXPECTED_PREREGISTRATION_SHA256 := (
	"sha256:51b3af71af5ad933eaaee9767383f38d8b1cdfe00a9845754b7e36370fbc3793"
)
const CLASS_NAME := "SporeLocomotionSdk"
const PROFILE_SCHEMA := "sporespore_balanced_wave_release_gate_unweighting_profile_v1"
const STEP_RECEIPT_SCHEMA := "sporespore_controller_step_receipt_v3"
const UNWEIGHTING_RECEIPT_SCHEMA := "sporespore_release_gate_unweighting_receipt_v1"
const KNEE_TARGET_MODE_ID := "release_gate_knee_swing_apex_target_v1"
const HIP_TARGET_MODE_ID := "release_gate_hip_swing_apex_target_v1"
const ANALYTIC_TARGET_BASIS := "existing_lateral_wave_swing_apex_at_half_swing_v1"
const POLICY_IDS := [
	"sporespore_balanced_wave_bw8u_a_v1",
	"sporespore_balanced_wave_bw8u_b_v1",
	"sporespore_balanced_wave_bw8u_c_v1",
	"sporespore_balanced_wave_bw8u_d_v1",
]
const CANDIDATE_IDS := ["BW8U-A", "BW8U-B", "BW8U-C", "BW8U-D"]
const EXPECTED_KNEE_MODES := [null, KNEE_TARGET_MODE_ID, null, KNEE_TARGET_MODE_ID]
const EXPECTED_HIP_MODES := [null, null, HIP_TARGET_MODE_ID, HIP_TARGET_MODE_ID]
const EXPECTED_RUNTIME_PROFILE_SHA256 := [
	"sha256:7cf179accc9858dd2e0683a531c5e947721602ce2a99d87ed35e2f9fb5498069",
	"sha256:00fc8348405648bcaa4ea27a506b4e0e505432bb4eae80399bc9b64a016adb07",
	"sha256:c49dd5f9a0462c6c50176ed896f04ce662ac1e6849233f48a6540460a96aee2a",
	"sha256:02b85937c806842ee075d0aea980e4256126ade9937ebb144c424957bb51fa44",
]
const EXPECTED_CANDIDATE_POLICY_SHA256 := [
	"sha256:d0a66d7350404b2acb0d7723fee0c34ae44cb7fd48e0cc1c2c03a407d34c9383",
	"sha256:b687a6c6d5afe358ceed3239adff8234ff154f4483c6dcef8259e1c9113bdefa",
	"sha256:cf6bc226d56fbde5a9f54ab56fcccbd844493e128b92bc387fa3d35795ca1dc3",
	"sha256:cdb61f9a3bdd6760dc76c70a673dd77db159794f4d13eab2ced502a4e4c2e156",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK balanced-wave BW8U zero-world authority contract ===")
	var extension_resource := load(EXTENSION_PATH)
	_check(extension_resource != null, "the checked-in GDExtension resource loads")
	_check(ClassDB.class_exists(CLASS_NAME), "the native SDK class is registered")
	if not ClassDB.class_exists(CLASS_NAME):
		_finish()
		return
	var api: Object = ClassDB.instantiate(CLASS_NAME)
	_check(api != null, "the native SDK class instantiates")
	_check(
		api != null
		and api.has_method("balanced_wave_policy_profile_json")
		and api.has_method("balanced_wave_initial_memory_json")
		and api.has_method("balanced_wave_policy_step_json"),
		"the named profile, memory, and pure-step ABIs are registered",
	)
	if api == null or not api.has_method("balanced_wave_policy_step_json"):
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
	_check(
		(morphology.get("ordered_actuator_ids", []) as Array).size() == 8
		and (morphology.get("ordered_contact_site_ids", []) as Array).size() == 4,
		"the zero-world morphology has exact quadruped semantic order",
	)

	var preregistration := _load_json_dictionary(PREREGISTRATION_PATH)
	var preregistration_sha := CanonicalJsonScript.sha256(preregistration)
	print("BW8U_PREREGISTRATION_SHA256=", preregistration_sha)
	_check(
		String(preregistration.get("schema_version", "")) == PREREGISTRATION_SCHEMA
		and String(preregistration.get("status", ""))
		== "frozen_before_first_bw8u_physics_world"
		and preregistration_sha == EXPECTED_PREREGISTRATION_SHA256,
		"the prospective preregistration is readable, frozen, and hash-bound",
	)
	var registered_candidates: Array = preregistration.get("candidates", [])
	var registered_digests: Dictionary = preregistration.get(
		"candidate_policy_digests",
		{},
	)
	var profiles: Array[Dictionary] = []
	var candidate_digests_match := true
	var runtime_digests_match := true
	var profiles_exact := true
	var manifest_candidates_exact := registered_candidates.size() == POLICY_IDS.size()
	for index in range(POLICY_IDS.size()):
		var envelope := _call_input(
			api,
			"balanced_wave_policy_profile_json",
			{
				"schema_version":
				"sporespore_balanced_wave_policy_profile_request_v1",
				"policy_id": POLICY_IDS[index],
				"descriptor": descriptor,
			},
		)
		var profile: Dictionary = envelope.get("value", {})
		profiles.append(profile)
		var runtime_sha := CanonicalJsonScript.sha256(profile)
		var candidate := _candidate(index, runtime_sha)
		var candidate_sha := CanonicalJsonScript.sha256(candidate)
		print(
			"BW8U_DIGEST candidate=%s runtime=%s policy=%s"
			% [CANDIDATE_IDS[index], runtime_sha, candidate_sha]
		)
		runtime_digests_match = (
			runtime_digests_match
			and runtime_sha == EXPECTED_RUNTIME_PROFILE_SHA256[index]
		)
		candidate_digests_match = (
			candidate_digests_match
			and candidate_sha == EXPECTED_CANDIDATE_POLICY_SHA256[index]
			and String(registered_digests.get(String(CANDIDATE_IDS[index]), ""))
			== candidate_sha
		)
		manifest_candidates_exact = (
			manifest_candidates_exact
			and index < registered_candidates.size()
			and CanonicalJsonScript.sha256(registered_candidates[index])
			== candidate_sha
		)
		profiles_exact = (
			profiles_exact
			and bool(envelope.get("ok", false))
			and String(profile.get("schema_version", "")) == PROFILE_SCHEMA
			and String(profile.get("policy_id", "")) == String(POLICY_IDS[index])
			and float(profile.get("cross_track_heading_gain_rad_per_m", NAN)) == 1.0
			and float(
				profile.get(
					"cross_track_velocity_heading_gain_rad_per_m_s",
					NAN,
				)
			)
			== 0.35
			and float(profile.get("yaw_error_stride_gain_per_rad", NAN)) == 1.3
			and float(
				profile.get(
					"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
					NAN,
				)
			)
			== 3.5
			and float(profile.get("anchor_error_guard_activation_fraction", NAN)) == 0.9
			and float(
				profile.get(
					"anchor_error_guard_maximum_motor_target_speed_rad_s",
					NAN,
				)
			)
			== 2.5
			and int(profile.get("steering_feedback_update_interval_steps", -1)) == 1
			and float(
				profile.get(
					"steering_low_pass_time_constant_cycle_fraction",
					NAN,
				)
			)
			== 0.0625
			and String(profile.get("steering_stride_transform_id", ""))
			== "reciprocal_steering_stride_transform_v1"
			and profile.get("release_gate_knee_target_mode_id", null)
			== EXPECTED_KNEE_MODES[index]
			and profile.get("release_gate_hip_target_mode_id", null)
			== EXPECTED_HIP_MODES[index]
			and (profile.get("branch_surfaces", []) as Array).is_empty()
			and bool(profile.get("controller_authority", false))
			and not bool(profile.get("physical_acceptance_authority", true))
		)
	_check(profiles_exact, "all four native profiles implement the frozen branch-free 2x2")
	_check(runtime_digests_match, "all four native runtime profiles are hash-bound")
	_check(candidate_digests_match, "all four candidate records are hash-bound")
	_check(
		manifest_candidates_exact,
		"the preregistered candidate records exactly match the native identities",
	)

	var parent_envelope := _call_input(
		api,
		"balanced_wave_policy_profile_json",
		{
			"schema_version": "sporespore_balanced_wave_policy_profile_request_v1",
			"policy_id": "sporespore_balanced_wave_bw7d_d_v1",
			"descriptor": descriptor,
		},
	)
	var parent_profile: Dictionary = parent_envelope.get("value", {})
	_check(
		bool(parent_envelope.get("ok", false))
		and CanonicalJsonScript.sha256(parent_profile)
		== "sha256:5708156714cdb9dc5c3f956b452c60d09acaa998e39970b556e3c2010a12878f",
		"the rejected-family BW7D-D parent remains byte-identical",
	)
	var parent_fields_inherited := profiles.size() == 4
	for profile_value in profiles:
		var profile: Dictionary = profile_value.duplicate(true)
		profile.erase("schema_version")
		profile.erase("policy_id")
		profile.erase("release_gate_knee_target_mode_id")
		profile.erase("release_gate_hip_target_mode_id")
		var comparable_parent := parent_profile.duplicate(true)
		comparable_parent.erase("schema_version")
		comparable_parent.erase("policy_id")
		comparable_parent.erase("release_gate_knee_target_mode_id")
		comparable_parent.erase("release_gate_hip_target_mode_id")
		parent_fields_inherited = parent_fields_inherited and profile == comparable_parent
	_check(
		parent_fields_inherited,
		"every non-factor profile field is inherited exactly from BW7D-D",
	)

	var material_result: Dictionary = MaterialProfilesScript.resolve(
		"godot_jolt_bw5c_mu095_v1"
	)
	var material_profile: Dictionary = material_result.get("profile", {})
	var adapter_routing_exact := bool(material_result.get("ok", false))
	for index in range(POLICY_IDS.size()):
		var policy_id := String(POLICY_IDS[index])
		var normalized := WaveGaitScript._normalize_sdk_authority_options(
			{
				"enabled": true,
				"descriptor": descriptor,
				"comparison_tolerance": 2.0e-8,
				"authority_scope": "stability_contribution_overlay",
				"stability_policy_id": "p5i3c_support_centroid_tilt_feedback_v1",
				"material_profile_id": "godot_jolt_bw5c_mu095_v1",
				"controller_policy_id": policy_id,
			}
		)
		var adapter := AdapterScript.new()
		var started: Dictionary = adapter.start(
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
			2.0e-8,
			"clocked",
			true,
			0,
			-1,
			"stability_contribution_overlay",
			"p5i3c_support_centroid_tilt_feedback_v1",
			material_profile,
			policy_id,
		)
		var manifest: Dictionary = started.get("adapter_manifest", {})
		var adapter_profile: Dictionary = manifest.get("controller_profile", {})
		adapter_routing_exact = (
			adapter_routing_exact
			and bool(normalized.get("ok", false))
			and String(
				(normalized.get("sdk_authority_options", {}) as Dictionary).get(
					"controller_policy_id",
					"",
				)
			)
			== policy_id
			and bool(started.get("ok", false))
			and int(started.get("world_build_count", -1)) == 0
			and String(manifest.get("controller_profile_sha256", ""))
			== String(EXPECTED_RUNTIME_PROFILE_SHA256[index])
			and adapter_profile.get("release_gate_knee_target_mode_id", null)
			== EXPECTED_KNEE_MODES[index]
			and adapter_profile.get("release_gate_hip_target_mode_id", null)
			== EXPECTED_HIP_MODES[index]
		)
	_check(
		adapter_routing_exact,
		"the physical runner and Godot/Jolt adapter route all four exact identities without a world",
	)

	var memory_envelope := _call_no_input(api, "balanced_wave_initial_memory_json")
	var loaded_memory: Dictionary = (
		memory_envelope.get("value", {}) as Dictionary
	).duplicate(true)
	loaded_memory["last_semantic_step"] = 0
	loaded_memory["phase_progression_mode"] = "contact_gated"
	var limb_memory: Array = loaded_memory.get("ordered_limb_memory", [])
	(limb_memory[0] as Dictionary)["gait_step"] = 54
	var loaded_state := _state_frame(morphology, true)
	var command := _motion_command()
	var loaded_targets: Array[Dictionary] = []
	var step_contract_exact := bool(memory_envelope.get("ok", false))
	for index in range(POLICY_IDS.size()):
		var step_envelope := _call_input(
			api,
			"balanced_wave_policy_step_json",
			{
				"schema_version":
				"sporespore_balanced_wave_policy_step_request_v1",
				"policy_id": POLICY_IDS[index],
				"descriptor": descriptor,
				"memory": loaded_memory,
				"state": loaded_state,
				"command": command,
			},
		)
		var output: Dictionary = step_envelope.get("value", {})
		var actuation: Dictionary = output.get("actuation", {})
		var receipt: Dictionary = actuation.get("receipt", {})
		var unweighting: Dictionary = receipt.get("release_gate_unweighting", {})
		var knee_ids: Array = unweighting.get("ordered_knee_override_limb_ids", [])
		var hip_ids: Array = unweighting.get("ordered_hip_override_limb_ids", [])
		var expected_knee_ids: Array = ["rear_left"] if index in [1, 3] else []
		var expected_hip_ids: Array = ["rear_left"] if index in [2, 3] else []
		var targets := _rear_left_targets(actuation)
		loaded_targets.append(targets)
		step_contract_exact = (
			step_contract_exact
			and bool(step_envelope.get("ok", false))
			and not bool(actuation.get("safe_no_actuation", true))
			and String(receipt.get("schema_version", "")) == STEP_RECEIPT_SCHEMA
			and String(receipt.get("policy_id", "")) == String(POLICY_IDS[index])
			and String(unweighting.get("schema_version", ""))
			== UNWEIGHTING_RECEIPT_SCHEMA
			and unweighting.get("knee_target_mode_id", null)
			== EXPECTED_KNEE_MODES[index]
			and unweighting.get("hip_target_mode_id", null)
			== EXPECTED_HIP_MODES[index]
			and knee_ids == expected_knee_ids
			and hip_ids == expected_hip_ids
			and String(unweighting.get("analytic_target_basis", ""))
			== ANALYTIC_TARGET_BASIS
			and int(unweighting.get("morphology_branch_surface_count", -1)) == 0
			and bool(unweighting.get("controller_parameter", false))
			and not bool(unweighting.get("walking_claim_authorized", true))
			and not bool(unweighting.get("physical_acceptance_authority", true))
		)
	_check(
		step_contract_exact,
		"all four pure steps emit exact loaded-release-gate receipts",
	)
	var target_factorial_exact := (
		loaded_targets.size() == 4
		and is_equal_approx(
			float(loaded_targets[0]["hip"]),
			float(loaded_targets[1]["hip"]),
		)
		and is_equal_approx(
			float(loaded_targets[0]["knee"]),
			float(loaded_targets[2]["knee"]),
		)
		and not is_equal_approx(
			float(loaded_targets[0]["knee"]),
			float(loaded_targets[1]["knee"]),
		)
		and not is_equal_approx(
			float(loaded_targets[0]["hip"]),
			float(loaded_targets[2]["hip"]),
		)
		and is_equal_approx(float(loaded_targets[1]["knee"]), 1.835)
		and is_equal_approx(float(loaded_targets[3]["knee"]), 1.835)
		and is_zero_approx(float(loaded_targets[2]["hip"]))
		and is_zero_approx(float(loaded_targets[3]["hip"]))
	)
	_check(
		target_factorial_exact,
		"the two factors change only their own exact analytic target",
	)

	var unloaded_state := _state_frame(morphology, false)
	var unloaded_envelope := _call_input(
		api,
		"balanced_wave_policy_step_json",
		{
			"schema_version": "sporespore_balanced_wave_policy_step_request_v1",
			"policy_id": POLICY_IDS[3],
			"descriptor": descriptor,
			"memory": loaded_memory,
			"state": unloaded_state,
			"command": command,
		},
	)
	var unloaded_actuation: Dictionary = (
		unloaded_envelope.get("value", {}) as Dictionary
	).get("actuation", {})
	var unloaded_receipt: Dictionary = unloaded_actuation.get("receipt", {})
	var unloaded_unweighting: Dictionary = unloaded_receipt.get(
		"release_gate_unweighting",
		{},
	)
	_check(
		bool(unloaded_envelope.get("ok", false))
		and (
			unloaded_unweighting.get("ordered_knee_override_limb_ids", []) as Array
		).is_empty()
		and (
			unloaded_unweighting.get("ordered_hip_override_limb_ids", []) as Array
		).is_empty(),
		"the override predicate is false when the release-gate foot is not bearing",
	)
	_finish()


func _candidate(index: int, runtime_sha: String) -> Dictionary:
	var knee_enabled := index in [1, 3]
	var hip_enabled := index in [2, 3]
	return {
		"candidate_id": CANDIDATE_IDS[index],
		"policy_id": POLICY_IDS[index],
		"parent_policy_id": "sporespore_balanced_wave_bw7d_d_v1",
		"profile_schema_version": PROFILE_SCHEMA,
		"runtime_profile_sha256": runtime_sha,
		"knee_release_target_factor":
		"existing_swing_apex_target" if knee_enabled else "inherited_phase54_target",
		"hip_release_target_factor":
		"existing_swing_apex_target" if hip_enabled else "inherited_phase54_target",
		"release_gate_knee_target_mode_id":
		KNEE_TARGET_MODE_ID if knee_enabled else null,
		"release_gate_hip_target_mode_id":
		HIP_TARGET_MODE_ID if hip_enabled else null,
		"analytic_target_basis": ANALYTIC_TARGET_BASIS,
		"evidence_acquisition_policy_id": "bounded_all_support_acquisition_v1",
		"evidence_acquisition_maximum_ticks": 15,
		"evidence_acquisition_minimum_all_support_dwell_ticks": 3,
		"branch_surfaces": [],
	}


func _reference_descriptor() -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": "bw8u_zero_world_reference",
		"torso_length_scale": 1.0,
		"torso_width_scale": 1.0,
		"upper_length_fraction": 18.0 / 35.0,
		"hip_span_scale": 1.0,
		"foot_radius_scale": 1.0,
		"front_limb_mass_scale": 1.0,
	}


func _state_frame(morphology: Dictionary, rear_left_bearing: bool) -> Dictionary:
	var joints: Array = []
	for joint_id_value in morphology.get("ordered_joint_ids", []):
		joints.append(
			{
				"joint_id": String(joint_id_value),
				"position_rad": 0.0,
				"velocity_rad_s": 0.0,
				"anchor_error_m": 0.0,
				"validity":
				{
					"position": true,
					"velocity": true,
					"anchor_error": true,
				},
			}
		)
	var contacts: Array = []
	for contact_id_value in morphology.get("ordered_contact_site_ids", []):
		var contact_id := String(contact_id_value)
		var bearing := rear_left_bearing if contact_id == "rear_left_foot" else true
		contacts.append(
			{
				"contact_site_id": contact_id,
				"presence": bearing,
				"bears_support": bearing,
				"normal_load_n": null,
				"provenance":
				{
					"adapter_id": "bw8u_zero_world_contract",
					"engine_contact_ids": ["%s_zero_world" % contact_id],
					"aggregation_rule_id": "qualified_bearing_only",
					"quality": "qualified_bearing",
				},
			}
		)
	return {
		"schema_version": "sporespore_state_frame_v1",
		"semantic_step": 1,
		"sample_time_s": 1.0 / 120.0,
		"base_pose_world":
		{
			"position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
			"orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		},
		"base_twist_world":
		{
			"linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
			"angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
		},
		"ordered_joint_observations": joints,
		"ordered_contact_observations": contacts,
		"previous_applied_actuation": null,
		"gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
		"task_frame":
		{
			"origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
			"forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
			"lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
			"up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
			"reference_yaw_rad": 0.0,
		},
		"adapter_capability_sha256":
		"sha256:8888888888888888888888888888888888888888888888888888888888888888",
	}


func _motion_command() -> Dictionary:
	return {
		"schema_version": "sporespore_motion_command_v2",
		"command_id": "bw8u_zero_world_loaded_release_gate",
		"desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
		"desired_heading_rad": 0.0,
		"desired_yaw_rate_rad_s": null,
		"gait_family_id": "lateral_wave",
		"speed_class": "walk",
		"gait_amplitude": 1.0,
		"phase_progression_mode": "contact_gated",
		"valid_from_step": 1,
		"valid_through_step": 1,
		"authority": "test_fixture",
	}


func _rear_left_targets(actuation: Dictionary) -> Dictionary:
	var result := {"hip": NAN, "knee": NAN}
	for command_value in actuation.get("ordered_commands", []):
		var command: Dictionary = command_value
		match String(command.get("actuator_id", "")):
			"rear_left_hip_motor":
				result["hip"] = float(command.get("requested_target_position_rad", NAN))
			"rear_left_knee_motor":
				result["knee"] = float(command.get("requested_target_position_rad", NAN))
	return result


func _call_input(api: Object, method: StringName, value: Dictionary) -> Dictionary:
	var response := String(api.call(method, JSON.stringify(value, "", true, true)))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _call_no_input(api: Object, method: StringName) -> Dictionary:
	var response := String(api.call(method))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print("SDK BW8U authority summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
