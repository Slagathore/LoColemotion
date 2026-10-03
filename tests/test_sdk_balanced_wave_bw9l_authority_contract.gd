extends SceneTree

## BW9L no-world authority contract. This freezes the scheduler-aware
## load-transfer family and proves the portable core/adapter routing before any
## BW9L physics world is constructed.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw9l_preregistration.json"
const PREREGISTRATION_SHA256 := (
	"sha256:b0b708bc6bcfd5475606b4014295f204a9b9d64846eb60d362b355184a5e2767"
)
const BASE_CONTROLLER_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const AUTHORITY_SCOPE := "stability_contribution_overlay"
const PHYSICS_HZ := 120
const POLICY_IDS := [
	"sporespore_scheduled_load_transfer_bw9l_a_v1",
	"sporespore_scheduled_load_transfer_bw9l_b_v1",
	"sporespore_scheduled_load_transfer_bw9l_c_v1",
	"sporespore_scheduled_load_transfer_bw9l_d_v1",
]
const MODES := [
	"control",
	"preferred_normal_force",
	"remaining_support_centroid",
	"combined",
]
const EXPECTED_POLICY_DIGESTS := {
	"BW9L-A": "sha256:36fff9ffbf953e121e3ea1e3f25ad66d6358be4c9e4bcba383231b9977d98320",
	"BW9L-B": "sha256:ee964cfc22b19ce2aa5fb198c0d646a3bbaa562cd1916e7edd704033998210ff",
	"BW9L-C": "sha256:efb7d388369692731a20c8b0670ad08e7f5fe1a3363ca2e0659969e40cdbe7dd",
	"BW9L-D": "sha256:e3f3074fc39d4aee5f58a8c10cb8e680c802524df21f36ea0a1e5389b227067f",
}
const SOLVER_POLICY := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": PHYSICS_HZ,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "balanced_wave_bw9l_authority_contract",
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}
const GAIT_STEPS := {
	"front_left": 54,
	"front_right": 54,
	"rear_left": 54,
	"rear_right": 54,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK balanced-wave BW9L no-world authority contract ===")
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)

	var preregistration_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PREREGISTRATION_PATH)
	)
	var preregistration: Dictionary = (
		preregistration_value
		if typeof(preregistration_value) == TYPE_DICTIONARY
		else {}
	)
	_check(
		(
			String(preregistration.get("schema_version", ""))
			== "sporespore_balanced_wave_bw9l_preregistration_v1"
			and String(preregistration.get("status", ""))
			== "frozen_before_first_bw9l_physics_world"
			and CanonicalJsonScript.sha256(preregistration)
			== PREREGISTRATION_SHA256
			and (
				(
					preregistration.get("development_matrix", {}) as Dictionary
				).get("expected_complete_world_count", -1)
				== 48
			)
		),
		"1 BW9L preregistration identity, digest, and 48-world family are exact",
	)

	var candidate_contract_ok := true
	var observed_digests: Dictionary = {}
	var candidates: Array = preregistration.get("candidates", [])
	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			candidate_contract_ok = false
			continue
		var candidate: Dictionary = candidate_value
		var candidate_id := String(candidate.get("candidate_id", ""))
		var digest := CanonicalJsonScript.sha256(candidate)
		observed_digests[candidate_id] = digest
		candidate_contract_ok = (
			candidate_contract_ok
			and EXPECTED_POLICY_DIGESTS.has(candidate_id)
			and digest == String(EXPECTED_POLICY_DIGESTS[candidate_id])
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
			and (
				String(candidate.get("base_controller_policy_id", ""))
				== BASE_CONTROLLER_POLICY_ID
			)
		)
	_check(
		candidate_contract_ok and observed_digests == EXPECTED_POLICY_DIGESTS,
		"2 all four factorial candidates are exact and morphology-branch-free",
	)

	var material_result: Dictionary = MaterialProfilesScript.resolve(
		"godot_jolt_bw5c_mu095_v1"
	)
	var material_profile: Dictionary = material_result.get("profile", {})
	var starts_ok := bool(material_result.get("ok", false))
	for policy_id in POLICY_IDS:
		var options := _authority_options(policy_id)
		var normalized: Dictionary = WaveGaitScript._normalize_sdk_authority_options(
			options
		)
		var normalized_options: Dictionary = normalized.get(
			"sdk_authority_options",
			{},
		)
		starts_ok = (
			starts_ok
			and bool(normalized.get("ok", false))
			and String(normalized_options.get("stability_policy_id", ""))
			== policy_id
			and String(normalized_options.get("controller_policy_id", ""))
			== BASE_CONTROLLER_POLICY_ID
		)
		var adapter := AdapterScript.new()
		var start := _start_adapter(adapter, policy_id, material_profile)
		var manifest: Dictionary = start.get("adapter_manifest", {})
		var stability_v3: Dictionary = manifest.get("stability_v3", {})
		var feedback_policy: Dictionary = stability_v3.get("feedback_policy", {})
		var controller_profile: Dictionary = manifest.get("controller_profile", {})
		starts_ok = (
			starts_ok
			and bool(start.get("ok", false))
			and int(start.get("world_build_count", -1)) == 0
			and String(manifest.get("schema_version", ""))
			== "sporespore_godot_jolt_adapter_manifest_v14"
			and String(manifest.get("stability_policy_id", "")) == policy_id
			and String(controller_profile.get("policy_id", ""))
			== BASE_CONTROLLER_POLICY_ID
			and (controller_profile.get("branch_surfaces", []) as Array).is_empty()
			and bool(feedback_policy.get("enabled", false))
			and String(feedback_policy.get("portable_plan_operation", ""))
			== "plan_scheduled_load_transfer_v1_json"
			and not bool(start.get("physical_acceptance_authority", true))
		)
	_check(
		starts_ok,
		"3 every candidate normalizes and starts the same portable base without a world",
	)

	var api: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var compile_envelope := _call_input(
		api,
		"compile_bounded_quadruped_json",
		DESCRIPTOR,
	)
	var compiled: Dictionary = compile_envelope.get("value", {})
	var morphology: Dictionary = compiled.get("morphology", {})
	var stability_state := _stability_state(morphology)
	var factor_contract_ok := bool(compile_envelope.get("ok", false))
	var baseline_target: Dictionary = {}
	var preferred_vector: Array = []
	var remaining_target: Dictionary = {}
	for index in range(POLICY_IDS.size()):
		var plan_envelope := _call_input(
			api,
			"plan_scheduled_load_transfer_v1_json",
			_plan_request(
				POLICY_IDS[index],
				morphology,
				stability_state,
			),
		)
		var receipt: Dictionary = plan_envelope.get("value", {})
		factor_contract_ok = (
			factor_contract_ok
			and bool(plan_envelope.get("ok", false))
			and String(receipt.get("mode", "")) == MODES[index]
			and int(receipt.get("morphology_branch_surface_count", -1)) == 0
			and not bool(receipt.get("physics_state_modified", true))
			and not bool(receipt.get("physical_acceptance_authority", true))
		)
		var preferences: Array = receipt.get("ordered_contact_preferences", [])
		var force_vector: Array = []
		for preference_value in preferences:
			var preference: Dictionary = preference_value
			force_vector.append(float(preference.get("preferred_normal_force_n", NAN)))
		if index == 0:
			baseline_target = receipt.get(
				"target_center_of_mass_world_m",
				{},
			)
			factor_contract_ok = (
				factor_contract_ok
				and not bool(receipt.get("active", true))
				and _all_zero(force_vector)
			)
		elif index == 1:
			preferred_vector = force_vector.duplicate()
			factor_contract_ok = (
				factor_contract_ok
				and bool(receipt.get("active", false))
				and not _all_zero(force_vector)
				and (
					receipt.get("target_center_of_mass_world_m", {})
					== baseline_target
				)
			)
		elif index == 2:
			remaining_target = receipt.get(
				"target_center_of_mass_world_m",
				{},
			)
			factor_contract_ok = (
				factor_contract_ok
				and bool(receipt.get("active", false))
				and _all_zero(force_vector)
				and remaining_target != baseline_target
			)
		else:
			factor_contract_ok = (
				factor_contract_ok
				and bool(receipt.get("active", false))
				and force_vector == preferred_vector
				and (
					receipt.get("target_center_of_mass_world_m", {})
					== remaining_target
				)
			)
	_check(
		factor_contract_ok,
		"4 the portable endpoint realizes the exact control, force, centroid, and combined factors",
	)

	var malformed_options := _authority_options("invented_load_transfer_policy")
	var malformed := WaveGaitScript._normalize_sdk_authority_options(
		malformed_options
	)
	_check(
		not bool(malformed.get("ok", false))
		and String(malformed.get("failure_code", ""))
		== "INVALID_SDK_AUTHORITY_OPTION_VALUE",
		"5 unknown stability policy identities fail closed before a world",
	)

	var receipt := {
		"schema_version": "sporespore_balanced_wave_bw9l_preflight_receipt_v1",
		"preregistration_sha256": PREREGISTRATION_SHA256,
		"candidate_policy_digests": EXPECTED_POLICY_DIGESTS,
		"base_controller_policy_id": BASE_CONTROLLER_POLICY_ID,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"passed": _failed == 0,
	}
	print("BALANCED_WAVE_BW9L_PREFLIGHT ", JSON.stringify(receipt, "", true, true))
	_finish()


static func _authority_options(stability_policy_id: String) -> Dictionary:
	return {
		"enabled": true,
		"descriptor": DESCRIPTOR,
		"comparison_tolerance": 2.0e-8,
		"authority_scope": AUTHORITY_SCOPE,
		"stability_policy_id": stability_policy_id,
		"material_profile_id": "godot_jolt_bw5c_mu095_v1",
		"controller_policy_id": BASE_CONTROLLER_POLICY_ID,
	}


static func _start_adapter(
	adapter: Variant,
	stability_policy_id: String,
	material_profile: Dictionary,
) -> Dictionary:
	return (
		adapter
		. start(
			DESCRIPTOR,
			GAIT_STEPS,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			0.0,
			PHYSICS_HZ,
			SOLVER_POLICY,
			2.0e-8,
			"contact_gated",
			true,
			0,
			-1,
			AUTHORITY_SCOPE,
			stability_policy_id,
			material_profile,
			BASE_CONTROLLER_POLICY_ID,
		)
	)


static func _stability_state(morphology: Dictionary) -> Dictionary:
	var bodies: Array = []
	for body_id_value in morphology.get("ordered_body_ids", []):
		bodies.append(
			{
				"body_id": String(body_id_value),
				"pose_world":
				{
					"position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
					"orientation_xyzw":
					{"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
				},
				"twist_world":
				{
					"linear_velocity_m_s":
					{"x": 0.0, "y": 0.0, "z": 0.0},
					"angular_velocity_rad_s":
					{"x": 0.0, "y": 0.0, "z": 0.0},
				},
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
				"point_world_m":
				{
					"x": 0.30 if contact_id.begins_with("front") else -0.30,
					"y": 0.0,
					"z": -0.20 if contact_id.contains("left") else 0.20,
				},
				"normal_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
				"surface_relative_velocity_world_m_s":
				{"x": 0.0, "y": 0.0, "z": 0.0},
				"material_id": "bw9l_contract_material",
				"adapter_id": "bw9l_contract",
				"engine_contact_ids": ["%s_engine" % contact_id],
			}
		)
	return {
		"schema_version": "sporespore_stability_state_v2",
		"semantic_step": 54,
		"ordered_body_states": bodies,
		"ordered_support_contacts": contacts,
		"gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
		"support_plane_forward_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
		"adapter_capability_sha256": "sha256:%s" % "5".repeat(64),
	}


static func _plan_request(
	policy_id: String,
	morphology: Dictionary,
	stability_state: Dictionary,
) -> Dictionary:
	var ordered_limb_gait_steps: Array = []
	for limb_id_value in morphology.get("ordered_limb_ids", []):
		ordered_limb_gait_steps.append(
			{
				"limb_id": String(limb_id_value),
				"gait_step": 54,
			}
		)
	return {
		"schema_version":
		"sporespore_plan_scheduled_load_transfer_request_v1",
		"descriptor": DESCRIPTOR,
		"request":
		{
			"schema_version":
			"sporespore_scheduled_load_transfer_request_v1",
			"policy_id": policy_id,
			"gait_amplitude": 1.0,
			"cycle_steps": 360,
			"swing_steps": 72,
			"characterized_friction_coefficient": 0.95,
			"maximum_normal_force_n":
			float(morphology.get("total_mass_kg", 0.0)) * 9.8,
			"feasibility_tolerance": 1.0e-5,
			"ordered_limb_gait_steps": ordered_limb_gait_steps,
			"stability_state": stability_state,
		},
	}


static func _all_zero(values: Array) -> bool:
	for value in values:
		if float(value) != 0.0:
			return false
	return true


static func _call_input(
	api: Object,
	method: StringName,
	value: Dictionary,
) -> Dictionary:
	var response := String(api.call(method, JSON.stringify(value, "", true, true)))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: ", label)
	else:
		_failed += 1
		push_error("  FAIL: %s" % label)


func _finish() -> void:
	print(
		"\nSDK balanced-wave BW9L authority-contract summary: ",
		_passed,
		" passed, ",
		_failed,
		" failed",
	)
	quit(0 if _failed == 0 else 1)
