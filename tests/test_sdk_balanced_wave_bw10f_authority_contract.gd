extends SceneTree

## BW10F no-world authority contract. This proves that the additive portable
## planner always emits a typed receipt, including support-unavailable steps,
## before any successor physics campaign is frozen or constructed.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw10f_preregistration.json"
const PREREGISTRATION_SHA256 := (
	"sha256:eb460a1b373a5aef4a9f07724d5e08e573fc18f3898cd94401c80047ebfa5148"
)
const BASE_CONTROLLER_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const AUTHORITY_SCOPE := "stability_contribution_overlay"
const PHYSICS_HZ := 120
const POLICY_IDS := [
	"sporespore_scheduled_load_transfer_bw10f_a_v2",
	"sporespore_scheduled_load_transfer_bw10f_b_v2",
	"sporespore_scheduled_load_transfer_bw10f_c_v2",
	"sporespore_scheduled_load_transfer_bw10f_d_v2",
]
const MODES := [
	"control",
	"preferred_normal_force",
	"remaining_support_centroid",
	"combined",
]
const POLICY_DIGESTS := {
	"BW10F-A": "sha256:d7f3dd32eaea8d6bac411bb541216eb70f9b291ee88276f46209a15ee0360bce",
	"BW10F-B": "sha256:c3c9239e7c044b893cb362e4bec33ccca75eec358b956406739ebf38d3bb9751",
	"BW10F-C": "sha256:43bbf227b85acb15749a3e54cdb9e00e098a1d843e9ad516a4cfdd4f68ba1c03",
	"BW10F-D": "sha256:1395551e5f7f4feafe78f3bdcb0be21c57c925a381735812156b0181dc5224a8",
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
	"morphology_id": "balanced_wave_bw10f_authority_contract",
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
	print("\n=== SDK balanced-wave BW10F no-world authority contract ===")
	var preregistration_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PREREGISTRATION_PATH)
	)
	var preregistration: Dictionary = (
		preregistration_value
		if typeof(preregistration_value) == TYPE_DICTIONARY
		else {}
	)
	var observed_digests: Dictionary = {}
	for candidate_value in preregistration.get("candidates", []):
		var candidate: Dictionary = candidate_value
		observed_digests[String(candidate.get("candidate_id", ""))] = (
			CanonicalJsonScript.sha256(candidate)
		)
	_check(
		String(preregistration.get("schema_version", ""))
		== "sporespore_balanced_wave_bw10f_preregistration_v1"
		and String(preregistration.get("status", ""))
		== "frozen_before_first_bw10f_physics_world"
		and CanonicalJsonScript.sha256(preregistration)
		== PREREGISTRATION_SHA256
		and observed_digests == POLICY_DIGESTS
		and int(
			(preregistration.get("development_matrix", {}) as Dictionary).get(
				"expected_complete_world_count",
				-1,
			)
		)
		== 48,
		"0 preregistration, policy digests, and fresh 48-world family are exact",
	)
	var extension_resource := load(EXTENSION_PATH)
	var api: Object = ClassDB.instantiate("SporeLocomotionSdk")
	_check(
		extension_resource != null and api != null,
		"1 native SDK endpoint is available",
	)
	if api == null:
		_finish()
		return
	var compile := _call_input(api, "compile_bounded_quadruped_json", DESCRIPTOR)
	var morphology: Dictionary = compile.get("value", {}).get("morphology", {})
	_check(
		bool(compile.get("ok", false))
		and int(compile.get("value", {}).get("world_build_count", -1)) == 0,
		"2 reference morphology compiles without constructing a world",
	)
	if morphology.is_empty():
		_finish()
		return
	var material_result: Dictionary = MaterialProfilesScript.resolve(
		"godot_jolt_bw5c_mu095_v1"
	)
	var material_profile: Dictionary = material_result.get("profile", {})
	var starts_exact := bool(material_result.get("ok", false))
	for policy_id_value in POLICY_IDS:
		var policy_id := String(policy_id_value)
		var normalized := WaveGaitScript._normalize_sdk_authority_options(
			_authority_options(policy_id)
		)
		var adapter := AdapterScript.new()
		var start := _start_adapter(adapter, policy_id, material_profile)
		var manifest: Dictionary = start.get("adapter_manifest", {})
		var feedback_policy: Dictionary = (
			manifest
			. get("stability_v3", {})
			. get("feedback_policy", {})
		)
		starts_exact = (
			starts_exact
			and bool(normalized.get("ok", false))
			and bool(start.get("ok", false))
			and int(start.get("world_build_count", -1)) == 0
			and String(manifest.get("schema_version", ""))
			== "sporespore_godot_jolt_adapter_manifest_v14"
			and String(feedback_policy.get("portable_plan_operation", ""))
			== "plan_scheduled_load_transfer_v2_json"
			and String(feedback_policy.get("portable_plan_schema_version", ""))
			== "sporespore_scheduled_load_transfer_receipt_v2"
			and String(feedback_policy.get("target_mode", ""))
			== "portable_scheduler_aware_load_transfer_v2_fail_zero"
			and not bool(start.get("physical_acceptance_authority", true))
		)
	_check(
		starts_exact,
		"3 all four v2 policies normalize and route through manifest v14 without a world",
	)

	var full_state := _stability_state(morphology)
	var routed_state: Dictionary = full_state.duplicate(true)
	var routed_contacts: Array = routed_state["ordered_support_contacts"]
	(routed_contacts[0] as Dictionary)["bears_support"] = false
	(routed_contacts[1] as Dictionary)["bears_support"] = false
	var routed_adapter := AdapterScript.new()
	var routed_start := _start_adapter(
		routed_adapter,
		POLICY_IDS[3],
		material_profile,
	)
	var routed_plan: Dictionary = routed_adapter.call(
		"_scheduled_load_transfer_plan",
		54,
		morphology,
		routed_state,
		1.0,
	)
	var routed_receipt: Dictionary = routed_plan.get("receipt", {})
	_check(
		bool(routed_start.get("ok", false))
		and bool(routed_plan.get("ok", false))
		and bool(routed_plan.get("fail_zero_required", false))
		and String(routed_plan.get("planning_availability", ""))
		== "observation_unavailable"
		and String(routed_receipt.get("schema_version", ""))
		== "sporespore_scheduled_load_transfer_receipt_v2"
		and (
			routed_receipt.get("ordered_safe_zero_actuator_ids", []) as Array
		)
		== (morphology.get("ordered_actuator_ids", []) as Array),
		"3b the no-world Godot runtime route preserves typed fail-zero semantics",
	)
	var available_exact := true
	var unavailable_exact := true
	for index in range(POLICY_IDS.size()):
		var full_plan := _call_input(
			api,
			"plan_scheduled_load_transfer_v2_json",
			_plan_request(POLICY_IDS[index], morphology, full_state),
		)
		var full_receipt: Dictionary = full_plan.get("value", {})
		available_exact = (
			available_exact
			and bool(full_plan.get("ok", false))
			and String(full_receipt.get("schema_version", ""))
			== "sporespore_scheduled_load_transfer_receipt_v2"
			and String(full_receipt.get("mode", "")) == MODES[index]
			and String(full_receipt.get("planning_availability", ""))
			== "available"
			and String(full_receipt.get("planning_outcome_code", ""))
			== "AVAILABLE"
			and not bool(full_receipt.get("fail_zero_required", true))
			and (
				full_receipt.get("ordered_safe_zero_actuator_ids", []) as Array
			).is_empty()
			and int(full_receipt.get("morphology_branch_surface_count", -1)) == 0
			and not bool(full_receipt.get("walking_claim_authorized", true))
			and not bool(full_receipt.get("physical_acceptance_authority", true))
		)
		var unavailable_state: Dictionary = full_state.duplicate(true)
		var contacts: Array = unavailable_state["ordered_support_contacts"]
		(contacts[0] as Dictionary)["bears_support"] = false
		(contacts[1] as Dictionary)["bears_support"] = false
		var unavailable_plan := _call_input(
			api,
			"plan_scheduled_load_transfer_v2_json",
			_plan_request(POLICY_IDS[index], morphology, unavailable_state),
		)
		var unavailable_receipt: Dictionary = unavailable_plan.get("value", {})
		unavailable_exact = (
			unavailable_exact
			and bool(unavailable_plan.get("ok", false))
			and String(unavailable_receipt.get("mode", "")) == MODES[index]
			and String(
				unavailable_receipt.get("planning_availability", "")
			)
			== "observation_unavailable"
			and String(
				unavailable_receipt.get("planning_outcome_code", "")
			)
			== (
				"PLANNING_UNAVAILABLE:CONTACT_INVALID:"
				+ "centroidal_support_contact_set_too_small"
			)
			and bool(unavailable_receipt.get("fail_zero_required", false))
			and unavailable_receipt.get("centroidal_request") == null
			and unavailable_receipt.get("centroidal_command") == null
			and (
				unavailable_receipt.get(
					"ordered_safe_zero_actuator_ids",
					[],
				) as Array
			)
			== (morphology.get("ordered_actuator_ids", []) as Array)
			and int(
				unavailable_receipt.get(
					"morphology_branch_surface_count",
					-1,
				)
			)
			== 0
			and not bool(
				unavailable_receipt.get("physical_acceptance_authority", true)
			)
		)
	_check(
		available_exact,
		"4 full support preserves the exact branch-free factorial semantics",
	)
	_check(
		unavailable_exact,
		"5 two-contact support always returns a typed ordered fail-zero receipt",
	)
	var receipt := {
		"schema_version": "sporespore_balanced_wave_bw10f_preflight_receipt_v1",
		"passed": _failed == 0,
		"preregistration_sha256": PREREGISTRATION_SHA256,
		"policy_ids": POLICY_IDS,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	print("BALANCED_WAVE_BW10F_PREFLIGHT ", JSON.stringify(receipt, "", true, true))
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
	return adapter.start(
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
				"material_id": "bw10f_contract_material",
				"adapter_id": "bw10f_contract",
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
		"adapter_capability_sha256": "sha256:%s" % "6".repeat(64),
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
		"sporespore_plan_scheduled_load_transfer_request_v2",
		"descriptor": DESCRIPTOR,
		"request":
		{
			"schema_version":
			"sporespore_scheduled_load_transfer_request_v2",
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
		"\nSDK balanced-wave BW10F authority-contract summary: ",
		_passed,
		" passed, ",
		_failed,
		" failed",
	)
	quit(0 if _failed == 0 else 1)
