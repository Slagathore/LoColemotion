extends SceneTree

## Zero-world authority contract for the prospective BW25Y paired yaw-gain
## development screen. It binds the exact candidate compositions, native policy
## profiles, live one-variable response, all published BW24M material records,
## and both policy routes without constructing or inserting a physics world.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CANDIDATES_PATH := "res://sdk/balanced_wave_bw25y_yaw_development_candidates.json"
const CLASS_NAME := "SporeLocomotionSdk"
const CANDIDATE_IDS := ["BW25Y-A", "BW25Y-B"]
const POLICY_IDS := [
	"sporespore_balanced_wave_bw15f_b_v1",
	"sporespore_balanced_wave_bw23y_b_v1",
]
const PROFILE_SHA256 := [
	"sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413",
	"sha256:d345d9607bed545ee6c58a20055cd6258f38ed581dd3d9f6490a9ae7f1a57570",
]
const CANDIDATE_DIGESTS := [
	"sha256:3a2e04cfa76c63f829d9828b125a8de2e0c0fe35e75b29d8caf87866ce1ea913",
	"sha256:cba24c1ac86b4cc629723d86609af58a17e88b23c041c4e8bca5deb766704a57",
]
const CONTROL_DIGEST := "sha256:06383da3e7d5701b1547f32193f4989cc38cabbbd49e5eef5a56c33120a62f12"
const EXPECTED_YAW_GAINS := [1.3, 1.0]
const EXPECTED_REQUESTED_STEERING := [0.17875, 0.1375]
const MATERIAL_IDS := [
	"godot_jolt_bw24m_mu059_v1",
	"godot_jolt_bw24m_mu071_v1",
	"godot_jolt_bw24m_mu083_v1",
]
const MATERIAL_DIGESTS := [
	"sha256:2d8a2571c129dbe7b2b894bae1aa28f5650fdbea27fcb65a149566c54a536173",
	"sha256:a8efdd111b740391931219d720079beffeea8181e5c46fd00ea7acb6108ab8ee",
	"sha256:e5916d9e17f87120e5cc04ff03e8688c4dea3919715a68854a8dce29e4d9c2a0",
]
const MATERIAL_COEFFICIENTS := [0.58, 0.68, 0.81]
const PROFILE_SCHEMA := "sporespore_balanced_wave_signed_forward_velocity_foot_placement_profile_v1"
const RECEIPT_SCHEMA := "sporespore_controller_step_receipt_v5"
const FOOT_PLACEMENT_SCHEMA := "sporespore_forward_velocity_foot_placement_receipt_v2"
const FOOT_PLACEMENT_MODE_ID := "forward_velocity_foot_placement_v1"
const VELOCITY_ERROR_ORIENTATION_ID := "desired_minus_measured_forward_velocity_error_v1"
const LATERAL_POSITION_M := 0.12
const LATERAL_VELOCITY_M_S := 0.05

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK balanced-wave BW25Y zero-world authority contract ===")
	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var declaration := _read_json(CANDIDATES_PATH)
	var declared_candidates: Array = declaration.get("candidates", [])
	var declared_digests: Dictionary = declaration.get("candidate_composition_digests", {})
	var control: Dictionary = declaration.get("policy_relative_control", {})
	var declaration_exact := declared_candidates.size() == 2
	for index in range(declared_candidates.size()):
		var candidate: Dictionary = declared_candidates[index]
		declaration_exact = (
			declaration_exact
			and String(candidate.get("candidate_id", "")) == String(CANDIDATE_IDS[index])
			and String(candidate.get("controller_policy_id", "")) == String(POLICY_IDS[index])
			and String(candidate.get("runtime_profile_sha256", "")) == String(PROFILE_SHA256[index])
			and CanonicalJsonScript.sha256(candidate) == String(CANDIDATE_DIGESTS[index])
			and String(declared_digests.get(CANDIDATE_IDS[index], "")) == String(CANDIDATE_DIGESTS[index])
			and is_equal_approx(float(candidate.get("cross_track_proportional_factor", NAN)), 1.0)
			and is_equal_approx(float(candidate.get("cross_track_velocity_factor", NAN)), 1.0)
			and is_equal_approx(
				float(candidate.get("yaw_error_stride_gain_per_rad", NAN)),
				float(EXPECTED_YAW_GAINS[index]),
			)
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
			and not bool(candidate.get("physical_acceptance_authority", true))
		)
	_check(
		(
			String(declaration.get("schema_version", ""))
			== "sporespore_balanced_wave_bw25y_yaw_development_candidates_v1"
			and String(declaration.get("campaign_id", ""))
			== "BW25Y-FRESH-MATERIAL-YAW-DEVELOPMENT"
			and (declaration.get("candidate_order", []) as Array) == CANDIDATE_IDS
			and String(control.get("candidate_id", "")) == "BW25Y-CONTROL"
			and String(control.get("controller_policy_id", "")) == String(POLICY_IDS[0])
			and is_zero_approx(float(control.get("global_requested_correction_scale", NAN)))
			and not bool(control.get("residual_application_expected", true))
			and bool(control.get("base_controller_motor_writes_expected", false))
			and bool(control.get("broad_base_controller_physical_influence_expected", false))
			and not bool(control.get("combined_application_gate_expected", true))
			and CanonicalJsonScript.sha256(control) == CONTROL_DIGEST
			and String(declaration.get("policy_relative_control_composition_digest", ""))
			== CONTROL_DIGEST
			and declaration_exact
		),
		"the candidates and zero-residual control have exact canonical identities",
	)

	var provenance: Dictionary = declaration.get("provenance_boundary", {})
	_check(
		(
			not bool(provenance.get("bw22l_was_infrastructure_valid", true))
			and not bool(provenance.get("bw22l_was_a_controller_comparison_result", true))
			and String(provenance.get("bw22l_selected_candidate_id", "")) == "NONE"
			and String(provenance.get("bw22l_posthoc_selector_output", "")) == "NONE"
			and bool(provenance.get("bw22l_descriptive_observations_used_for_hypothesis_narrowing_only", false))
			and bool(provenance.get("bw22l_b_may_not_be_promoted_or_retested", false))
			and bool(provenance.get("bw23y_development_worlds_were_nonretained_and_outcome_exposed", false))
			and not bool(provenance.get("bw23y_selected", true))
			and not bool(provenance.get("bw23y_promoted", true))
			and bool(provenance.get("bw25y_uses_fresh_outcome_unexposed_material_values", false))
			and bool(provenance.get("bw25y_uses_fresh_unopened_seeds", false))
		),
		"invalid and exposed predecessors remain hypothesis sources without authority",
	)

	var extension_resource := load(EXTENSION_PATH)
	_check(
		extension_resource != null and ClassDB.class_exists(CLASS_NAME),
		"the checked-in GDExtension and native SDK class load",
	)
	if not ClassDB.class_exists(CLASS_NAME):
		_finish(root_children_before, physics_hz_before)
		return
	var api: Object = ClassDB.instantiate(CLASS_NAME)
	if api == null:
		_check(false, "the native SDK class instantiates")
		_finish(root_children_before, physics_hz_before)
		return

	var descriptor := _reference_descriptor()
	var compile_envelope := _call_input(api, "compile_bounded_quadruped_json", descriptor)
	var morphology: Dictionary = (compile_envelope.get("value", {}) as Dictionary).get("morphology", {})
	_check(
		bool(compile_envelope.get("ok", false)) and not morphology.is_empty(),
		"the reference descriptor compiles without a world",
	)
	if morphology.is_empty():
		_finish(root_children_before, physics_hz_before)
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
			and is_equal_approx(float(profile.get("cross_track_heading_gain_rad_per_m", NAN)), 1.0)
			and is_equal_approx(float(profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN)), 0.35)
			and is_equal_approx(
				float(profile.get("yaw_error_stride_gain_per_rad", NAN)),
				float(EXPECTED_YAW_GAINS[index]),
			)
			and String(profile.get("forward_velocity_foot_placement_mode_id", ""))
			== FOOT_PLACEMENT_MODE_ID
			and String(profile.get("forward_velocity_error_orientation_id", ""))
			== VELOCITY_ERROR_ORIENTATION_ID
			and (profile.get("branch_surfaces", []) as Array).is_empty()
			and bool(profile.get("controller_authority", false))
			and not bool(profile.get("physical_acceptance_authority", true))
		)
	_check(profiles_exact, "both native profiles expose the declared branch-free yaw contrast")

	var inheritance_exact := profiles.size() == 2
	if inheritance_exact:
		var baseline := profiles[0].duplicate(true)
		var candidate := profiles[1].duplicate(true)
		for field in ["policy_id", "yaw_error_stride_gain_per_rad"]:
			baseline.erase(field)
			candidate.erase(field)
		inheritance_exact = candidate == baseline
	_check(
		inheritance_exact,
		"every non-yaw-gain profile field is inherited exactly from BW15F-B",
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
			_state_frame(morphology, LATERAL_POSITION_M, LATERAL_VELOCITY_M_S),
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
			and absf(requested - float(EXPECTED_REQUESTED_STEERING[index])) <= 1.0e-12
			and not bool(receipt.get("steering_saturated", true))
			and bool(receipt.get("steering_feedback_updated", false))
			and String(foot_placement.get("schema_version", "")) == FOOT_PLACEMENT_SCHEMA
			and String(foot_placement.get("mode_id", "")) == FOOT_PLACEMENT_MODE_ID
			and int(foot_placement.get("morphology_branch_surface_count", -1)) == 0
			and int(receipt.get("world_build_count", -1)) == 0
			and not bool(receipt.get("physical_acceptance_authority", true))
		)
	_check(live_step_exact, "the native live step emits the exact two-arm yaw response")
	_check(
		requested_values.size() == 2 and requested_values[1] < requested_values[0],
		"the BW23Y hypothesis reduces the declared pre-filter steering response",
	)

	var materials_exact := true
	var material_profiles: Array[Dictionary] = []
	for index in range(MATERIAL_IDS.size()):
		var result := MaterialProfilesScript.resolve(String(MATERIAL_IDS[index]))
		var material_profile: Dictionary = result.get("profile", {})
		material_profiles.append(material_profile)
		materials_exact = (
			materials_exact
			and bool(result.get("ok", false))
			and String(result.get("profile_sha256", "")) == String(MATERIAL_DIGESTS[index])
			and is_equal_approx(
				float(material_profile.get("characterized_friction_coefficient", NAN)),
				float(MATERIAL_COEFFICIENTS[index]),
			)
		)
	_check(materials_exact, "all three closed BW24M material records resolve exactly")

	var routing_exact := materials_exact and material_profiles.size() == 3
	for policy_id_value in POLICY_IDS:
		var policy_id := String(policy_id_value)
		for material_profile in material_profiles:
			var adapter := AdapterScript.new()
			var started := adapter.start(
				descriptor,
				{"front_left": 0, "front_right": 0, "rear_left": 0, "rear_right": 0},
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
				material_profile,
				policy_id,
			)
			var boundary: Dictionary = {}
			if bool(started.get("ok", false)):
				boundary = adapter.preflight_perfect_declared_policy_runtime_boundary()
			routing_exact = (
				routing_exact
				and bool(started.get("ok", false))
				and String(started.get("controller_policy_id", "")) == policy_id
				and int(started.get("world_build_count", -1)) == 0
				and bool(boundary.get("ok", false))
				and String(boundary.get("controller_policy_id", "")) == policy_id
				and int(boundary.get("actual_world_build_count", -1)) == 0
				and not bool(boundary.get("locomotion_outcome_exposed", true))
			)
	_check(routing_exact, "both policies compose with every material through native authority")

	var unknown := _profile(api, descriptor, "sporespore_balanced_wave_bw25y_unknown")
	_check(not bool(unknown.get("ok", true)), "an undeclared BW25Y policy fails closed")
	_finish(root_children_before, physics_hz_before)


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
		"morphology_id": "bw25y_zero_world_reference",
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
		joints.append(
			{
				"joint_id": String(joint_id_value),
				"position_rad": 0.0,
				"velocity_rad_s": 0.0,
				"anchor_error_m": 0.0,
				"validity": {"position": true, "velocity": true, "anchor_error": true},
			}
		)
	var contacts: Array = []
	for contact_id_value in morphology.get("ordered_contact_site_ids", []):
		var contact_id := String(contact_id_value)
		contacts.append(
			{
				"contact_site_id": contact_id,
				"presence": true,
				"bears_support": true,
				"normal_load_n": null,
				"provenance":
				{
					"adapter_id": "bw25y_zero_world_contract",
					"engine_contact_ids": ["%s_zero_world" % contact_id],
					"aggregation_rule_id": "qualified_bearing_only",
					"quality": "qualified_bearing",
				},
			}
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
			"linear_velocity_m_s": {"x": 0.2, "y": 0.0, "z": lateral_velocity_m_s},
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
		"sha256:2222222222222222222222222222222222222222222222222222222222222222",
	}


func _motion_command() -> Dictionary:
	return {
		"schema_version": "sporespore_motion_command_v2",
		"command_id": "bw25y_zero_world_yaw_response",
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
	return parsed if parsed is Dictionary else {}


func _call_input(api: Object, method: StringName, value: Dictionary) -> Dictionary:
	var response := String(api.call(method, JSON.stringify(value, "", true, true)))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if parsed is Dictionary else {}


func _call_no_input(api: Object, method: StringName) -> Dictionary:
	var response := String(api.call(method))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if parsed is Dictionary else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish(root_children_before: int, physics_hz_before: int) -> void:
	_check(root.get_child_count() == root_children_before, "no scene-tree node was inserted")
	_check(Engine.physics_ticks_per_second == physics_hz_before, "physics state was not mutated")
	print("SDK BW25Y authority summary: %d passed, %d failed" % [_passed, _failed])
	if _failed == 0:
		print(
			"BW25Y_AUTHORITY_PASS candidates=2 materials=3 routes=6 worlds=0 branch_surfaces=0 physical_authority=False"
		)
	quit(0 if _failed == 0 else 1)
