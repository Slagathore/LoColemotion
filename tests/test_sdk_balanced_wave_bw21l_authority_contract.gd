extends SceneTree

## Zero-world authority contract for the prospective BW21L lateral-gain study.
##
## The exposed BW20F observations motivate this development-only 2x2 screen,
## but do not authorize validation or material-robustness claims. This test
## constructs no physics world. It proves that the four controller arms differ
## only in the declared cross-track proportional and velocity gains, retain the
## frozen BW15F-B mechanism, and route through the real Godot adapter.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CANDIDATES_PATH := "res://sdk/balanced_wave_bw21l_lateral_development_candidates.json"
const CLASS_NAME := "SporeLocomotionSdk"
const CANDIDATE_IDS := ["BW21L-A", "BW21L-B", "BW21L-C", "BW21L-D"]
const POLICY_IDS := [
	"sporespore_balanced_wave_bw15f_b_v1",
	"sporespore_balanced_wave_bw21l_b_v1",
	"sporespore_balanced_wave_bw21l_c_v1",
	"sporespore_balanced_wave_bw21l_d_v1",
]
const EXPECTED_HEADING_GAINS := [1.0, 1.5, 1.0, 1.5]
const EXPECTED_VELOCITY_GAINS := [0.35, 0.35, 0.70, 0.70]
const EXPECTED_REQUESTED_STEERING := [0.17875, 0.25675, 0.2015, 0.2795]
const PROFILE_SHA256 := [
	"sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413",
	"sha256:70b1b0c445bc8b53d94a09f70e18271b9727d9f41b772fa843ae9e59174af6f5",
	"sha256:53c443565996a1a7e7c749ca37c7530a99847d7c3a267a9dea83ee1c17926ff3",
	"sha256:9b558419c3b74218b26fa306407b6efb20a680c80059365a405c6fdb06642a59",
]
const PROFILE_SCHEMA := "sporespore_balanced_wave_signed_forward_velocity_foot_placement_profile_v1"
const RECEIPT_SCHEMA := "sporespore_controller_step_receipt_v5"
const FOOT_PLACEMENT_SCHEMA := "sporespore_forward_velocity_foot_placement_receipt_v2"
const FOOT_PLACEMENT_MODE_ID := "forward_velocity_foot_placement_v1"
const VELOCITY_ERROR_ORIENTATION_ID := "desired_minus_measured_forward_velocity_error_v1"
const MAXIMUM_FORWARD_CORRECTION_RAD := 0.03
const LATERAL_POSITION_M := 0.12
const LATERAL_VELOCITY_M_S := 0.05

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK balanced-wave BW21L zero-world authority contract ===")
	var declaration := _read_json(CANDIDATES_PATH)
	var declared_candidates: Array = declaration.get("candidates", [])
	var candidate_digests: Dictionary = declaration.get("candidate_composition_digests", {})
	var control: Dictionary = declaration.get("policy_relative_control", {})
	var declaration_exact := declared_candidates.size() == 4
	for index in range(declared_candidates.size()):
		var candidate: Dictionary = declared_candidates[index]
		declaration_exact = (
			declaration_exact
			and String(candidate.get("candidate_id", "")) == String(CANDIDATE_IDS[index])
			and String(candidate.get("controller_policy_id", "")) == String(POLICY_IDS[index])
			and String(candidate.get("runtime_profile_sha256", "")) == String(PROFILE_SHA256[index])
			and (
				CanonicalJsonScript.sha256(candidate)
				== String(candidate_digests.get(CANDIDATE_IDS[index], ""))
			)
			and is_equal_approx(
				float(candidate.get("cross_track_proportional_factor", NAN)),
				float(EXPECTED_HEADING_GAINS[index]),
			)
			and is_equal_approx(
				float(candidate.get("reference_cross_track_heading_gain_rad_per_m", NAN)),
				float(EXPECTED_HEADING_GAINS[index]),
			)
			and is_equal_approx(
				float(
					candidate.get("reference_cross_track_velocity_heading_gain_rad_per_m_s", NAN)
				),
				float(EXPECTED_VELOCITY_GAINS[index]),
			)
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
			and not bool(candidate.get("physical_acceptance_authority", true))
		)
	_check(
		(
			(
				String(declaration.get("schema_version", ""))
				== "sporespore_balanced_wave_bw21l_lateral_development_candidates_v1"
			)
			and (declaration.get("candidate_order", []) as Array) == CANDIDATE_IDS
			and String(control.get("candidate_id", "")) == "BW21L-CONTROL"
			and String(control.get("controller_policy_id", "")) == String(POLICY_IDS[0])
			and is_zero_approx(float(control.get("global_requested_correction_scale", NAN)))
			and not bool(control.get("residual_application_expected", true))
			and bool(control.get("base_controller_motor_writes_expected", false))
			and bool(control.get("broad_base_controller_physical_influence_expected", false))
			and not bool(control.get("combined_application_gate_expected", true))
			and (
				CanonicalJsonScript.sha256(control)
				== String(declaration.get("policy_relative_control_composition_digest", ""))
			)
			and declaration_exact
		),
		"the four-arm candidate declaration loads in frozen factorial order",
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
	var morphology: Dictionary = (compile_envelope.get("value", {}) as Dictionary).get(
		"morphology", {}
	)
	_check(
		bool(compile_envelope.get("ok", false)) and not morphology.is_empty(),
		"the reference descriptor compiles without a world",
	)
	if morphology.is_empty():
		_finish()
		return

	var profiles: Array[Dictionary] = []
	var profiles_exact := true
	for index in range(POLICY_IDS.size()):
		var envelope := _profile(api, descriptor, String(POLICY_IDS[index]))
		var profile: Dictionary = envelope.get("value", {})
		profiles.append(profile)
		profiles_exact = (
			profiles_exact
			and bool(envelope.get("ok", false))
			and String(profile.get("schema_version", "")) == PROFILE_SCHEMA
			and String(profile.get("policy_id", "")) == String(POLICY_IDS[index])
			and CanonicalJsonScript.sha256(profile) == String(PROFILE_SHA256[index])
			and is_equal_approx(
				float(profile.get("cross_track_heading_gain_rad_per_m", NAN)),
				float(EXPECTED_HEADING_GAINS[index]),
			)
			and is_equal_approx(
				float(profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN)),
				float(EXPECTED_VELOCITY_GAINS[index]),
			)
			and (
				String(profile.get("forward_velocity_foot_placement_mode_id", ""))
				== FOOT_PLACEMENT_MODE_ID
			)
			and (
				String(profile.get("forward_velocity_error_orientation_id", ""))
				== VELOCITY_ERROR_ORIENTATION_ID
			)
			and is_equal_approx(
				float(
					(
						profile
						. get(
							"maximum_forward_velocity_hip_target_correction_rad",
							NAN,
						)
					)
				),
				MAXIMUM_FORWARD_CORRECTION_RAD,
			)
			and (profile.get("branch_surfaces", []) as Array).is_empty()
			and bool(profile.get("controller_authority", false))
			and not bool(profile.get("physical_acceptance_authority", true))
		)
	_check(
		profiles_exact,
		"all four profiles expose the declared branch-free gain factorial",
	)

	var inheritance_exact := profiles.size() == POLICY_IDS.size()
	if inheritance_exact:
		var baseline := profiles[0].duplicate(true)
		for field in [
			"policy_id",
			"cross_track_heading_gain_rad_per_m",
			"cross_track_velocity_heading_gain_rad_per_m_s",
		]:
			baseline.erase(field)
		for index in range(1, profiles.size()):
			var candidate := profiles[index].duplicate(true)
			for field in [
				"policy_id",
				"cross_track_heading_gain_rad_per_m",
				"cross_track_velocity_heading_gain_rad_per_m_s",
			]:
				candidate.erase(field)
			inheritance_exact = inheritance_exact and candidate == baseline
	_check(
		inheritance_exact,
		"every non-factor profile field is inherited exactly from BW15F-B",
	)

	var memory_envelope := _call_no_input(api, "balanced_wave_initial_memory_json")
	var initial_memory: Dictionary = memory_envelope.get("value", {})
	var requested_values: Array[float] = []
	var live_step_exact := bool(memory_envelope.get("ok", false))
	for index in range(POLICY_IDS.size()):
		var step := _step(
			api,
			String(POLICY_IDS[index]),
			descriptor,
			initial_memory,
			_state_frame(
				morphology,
				LATERAL_POSITION_M,
				LATERAL_VELOCITY_M_S,
			),
			_motion_command(),
		)
		var output: Dictionary = step.get("value", {})
		var actuation: Dictionary = output.get("actuation", {})
		var receipt: Dictionary = actuation.get("receipt", {})
		var foot_placement: Dictionary = receipt.get("forward_velocity_foot_placement", {})
		var requested := float(receipt.get("requested_steering_fraction", NAN))
		requested_values.append(requested)
		live_step_exact = (
			live_step_exact
			and bool(step.get("ok", false))
			and not bool(actuation.get("safe_no_actuation", true))
			and String(receipt.get("schema_version", "")) == RECEIPT_SCHEMA
			and String(receipt.get("policy_id", "")) == String(POLICY_IDS[index])
			and is_equal_approx(
				float(receipt.get("cross_track_error_m", NAN)),
				LATERAL_POSITION_M,
			)
			and is_equal_approx(
				float(receipt.get("cross_track_velocity_m_s", NAN)),
				LATERAL_VELOCITY_M_S,
			)
			and absf(requested - float(EXPECTED_REQUESTED_STEERING[index])) <= 1.0e-12
			and not bool(receipt.get("steering_saturated", true))
			and bool(receipt.get("steering_feedback_updated", false))
			and is_finite(float(receipt.get("held_steering_fraction", NAN)))
			and String(foot_placement.get("schema_version", "")) == FOOT_PLACEMENT_SCHEMA
			and String(foot_placement.get("mode_id", "")) == FOOT_PLACEMENT_MODE_ID
			and (
				String(foot_placement.get("velocity_error_orientation_id", ""))
				== VELOCITY_ERROR_ORIENTATION_ID
			)
			and int(foot_placement.get("morphology_branch_surface_count", -1)) == 0
			and int(receipt.get("world_build_count", -1)) == 0
			and not bool(receipt.get("physical_acceptance_authority", true))
		)
	_check(
		live_step_exact,
		"the native live step emits the exact declared gain response with no world",
	)

	var factorial_exact := requested_values.size() == 4
	if factorial_exact:
		factorial_exact = (
			(
				absf(
					(
						(requested_values[1] - requested_values[0])
						- (requested_values[3] - requested_values[2])
					)
				)
				<= 1.0e-12
			)
			and (
				absf(
					(
						(requested_values[2] - requested_values[0])
						- (requested_values[3] - requested_values[1])
					)
				)
				<= 1.0e-12
			)
			and requested_values[1] > requested_values[0]
			and requested_values[2] > requested_values[0]
			and requested_values[3] > requested_values[1]
			and requested_values[3] > requested_values[2]
		)
	_check(
		factorial_exact,
		"the proportional and velocity factors are independently additive before filtering",
	)

	var material_result := MaterialProfilesScript.resolve("godot_jolt_bw5c_mu095_v1")
	var routing_exact := bool(material_result.get("ok", false))
	for policy_id_value in POLICY_IDS:
		var policy_id := String(policy_id_value)
		var adapter := AdapterScript.new()
		var started := (
			adapter
			. start(
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
				"sporespore_scheduled_load_transfer_bw13p_a_v3",
				material_result.get("profile", {}),
				policy_id,
			)
		)
		var boundary: Dictionary = {}
		if bool(started.get("ok", false)):
			boundary = adapter.preflight_perfect_declared_policy_runtime_boundary()
		routing_exact = (
			routing_exact
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
		"all four arms route through native full authority with zero worlds",
	)

	var unknown := _profile(api, descriptor, "sporespore_balanced_wave_bw21l_unknown")
	_check(
		not bool(unknown.get("ok", true)),
		"an undeclared BW21L policy fails closed",
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


func _reference_descriptor() -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": "bw21l_zero_world_reference",
		"torso_length_scale": 1.0,
		"torso_width_scale": 1.0,
		"upper_length_fraction": 18.0 / 35.0,
		"hip_span_scale": 1.0,
		"foot_radius_scale": 1.0,
		"front_limb_mass_scale": 1.0,
	}


func _state_frame(
	morphology: Dictionary,
	lateral_position_m: float,
	lateral_velocity_m_s: float,
) -> Dictionary:
	var joints: Array = []
	for joint_id_value in morphology.get("ordered_joint_ids", []):
		(
			joints
			. append(
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
		)
	var contacts: Array = []
	for contact_id_value in morphology.get("ordered_contact_site_ids", []):
		var contact_id := String(contact_id_value)
		(
			contacts
			. append(
				{
					"contact_site_id": contact_id,
					"presence": true,
					"bears_support": true,
					"normal_load_n": null,
					"provenance":
					{
						"adapter_id": "bw21l_zero_world_contract",
						"engine_contact_ids": ["%s_zero_world" % contact_id],
						"aggregation_rule_id": "qualified_bearing_only",
						"quality": "qualified_bearing",
					},
				}
			)
		)
	return {
		"schema_version": "sporespore_state_frame_v1",
		"semantic_step": 0,
		"sample_time_s": 0.0,
		"base_pose_world":
		{
			"position_m": {"x": 0.0, "y": 0.44, "z": lateral_position_m},
			"orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		},
		"base_twist_world":
		{
			"linear_velocity_m_s":
			{
				"x": 0.2,
				"y": 0.0,
				"z": lateral_velocity_m_s,
			},
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
		"sha256:2121212121212121212121212121212121212121212121212121212121212121",
	}


func _motion_command() -> Dictionary:
	return {
		"schema_version": "sporespore_motion_command_v2",
		"command_id": "bw21l_zero_world_lateral_response",
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
	print("SDK BW21L authority summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
