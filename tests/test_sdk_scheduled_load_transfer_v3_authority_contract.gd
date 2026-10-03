extends SceneTree

## Additive scheduled-load-transfer v3 no-world authority contract.
##
## This test opens no physics world. It proves that the portable core owns
## both the usable-observation and host-observation-unavailable decisions, that
## Godot routes the new identity through manifest v15, and that the adapter can
## inject exactly one typed safe-zero contribution before overlay validation.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const SHARED_HARNESS_PATH := "res://tests/test_sdk_godot_jolt_material_robustness.gd"
const BASE_CONTROLLER_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const AUTHORITY_SCOPE := "stability_contribution_overlay"
const PHYSICS_HZ := 120
const POLICY_IDS := [
	"sporespore_scheduled_load_transfer_bw11r_a_v3",
	"sporespore_scheduled_load_transfer_bw11r_b_v3",
	"sporespore_scheduled_load_transfer_bw11r_c_v3",
	"sporespore_scheduled_load_transfer_bw11r_d_v3",
	"sporespore_scheduled_load_transfer_bw13p_a_v3",
	"sporespore_scheduled_load_transfer_bw13p_b_v3",
	"sporespore_scheduled_load_transfer_bw13p_c_v3",
	"sporespore_scheduled_load_transfer_bw13p_d_v3",
]
const MODES := [
	"control",
	"preferred_normal_force",
	"remaining_support_centroid",
	"combined",
	"control",
	"preferred_normal_force",
	"remaining_support_centroid",
	"combined",
]
const SOLVER_POLICY := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": PHYSICS_HZ,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "scheduled_load_transfer_v3_authority_contract",
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
	print("\n=== SDK scheduled-load-transfer v3 no-world authority contract ===")
	var extension_resource := load(EXTENSION_PATH)
	var api: Object = ClassDB.instantiate("SporeLocomotionSdk")
	_check(
		(
			extension_resource != null
			and api != null
			and api.has_method("plan_scheduled_load_transfer_v3_json")
		),
		"0 native v3 endpoint is available",
	)
	if api == null:
		_finish()
		return

	var compile := _call_input(api, "compile_bounded_quadruped_json", DESCRIPTOR)
	var morphology: Dictionary = compile.get("value", {}).get("morphology", {})
	_check(
		(
			bool(compile.get("ok", false))
			and int(compile.get("value", {}).get("world_build_count", -1)) == 0
			and not morphology.is_empty()
		),
		"1 reference morphology compiles without constructing a world",
	)
	if morphology.is_empty():
		_finish()
		return

	var full_state := _stability_state(morphology)
	var full_exact := true
	var unavailable_exact := true
	for index in range(POLICY_IDS.size()):
		var full_plan := _call_input(
			api,
			"plan_scheduled_load_transfer_v3_json",
			_plan_request(
				POLICY_IDS[index],
				morphology,
				true,
				"",
				full_state,
			),
		)
		var full_receipt: Dictionary = full_plan.get("value", {})
		full_exact = (
			full_exact
			and bool(full_plan.get("ok", false))
			and (
				String(full_receipt.get("schema_version", ""))
				== "sporespore_scheduled_load_transfer_receipt_v3"
			)
			and String(full_receipt.get("mode", "")) == MODES[index]
			and bool(full_receipt.get("observation_input_available", false))
			and full_receipt.get("observation_unavailable_reason", null) == null
			and String(full_receipt.get("planning_availability", "")) == "available"
			and not bool(full_receipt.get("fail_zero_required", true))
			and (full_receipt.get("ordered_safe_zero_actuator_ids", []) as Array).is_empty()
			and int(full_receipt.get("morphology_branch_surface_count", -1)) == 0
			and not bool(full_receipt.get("physical_acceptance_authority", true))
		)
		var unavailable_plan := _call_input(
			api,
			"plan_scheduled_load_transfer_v3_json",
			_plan_request(
				POLICY_IDS[index],
				morphology,
				false,
				"NO_QUALIFIED_SUPPORT_CONTACT",
				{},
			),
		)
		var unavailable_receipt: Dictionary = unavailable_plan.get("value", {})
		unavailable_exact = (
			unavailable_exact
			and bool(unavailable_plan.get("ok", false))
			and not bool(unavailable_receipt.get("observation_input_available", true))
			and (
				String(
					(
						unavailable_receipt
						. get(
							"observation_unavailable_reason",
							"",
						)
					)
				)
				== "NO_QUALIFIED_SUPPORT_CONTACT"
			)
			and (
				String(unavailable_receipt.get("planning_availability", ""))
				== "observation_unavailable"
			)
			and (
				String(unavailable_receipt.get("planning_outcome_code", ""))
				== "OBSERVATION_UNAVAILABLE:NO_QUALIFIED_SUPPORT_CONTACT"
			)
			and bool(unavailable_receipt.get("fail_zero_required", false))
			and unavailable_receipt.get("centroidal_request", {}) == null
			and unavailable_receipt.get("centroidal_command", {}) == null
			and (
				(
					(
						unavailable_receipt
						. get(
							"ordered_safe_zero_actuator_ids",
							[],
						)
					)
					as Array
				)
				== (morphology.get("ordered_actuator_ids", []) as Array)
			)
			and (
				int(
					(
						unavailable_receipt
						. get(
							"morphology_branch_surface_count",
							-1,
						)
					)
				)
				== 0
			)
			and not bool(unavailable_receipt.get("physical_acceptance_authority", true))
		)
	_check(
		full_exact,
		"2 all declared available v3 policies preserve branch-free factorial semantics",
	)
	_check(
		unavailable_exact,
		"3 all declared unavailable v3 policies return ordered typed safe zero",
	)

	var contradiction := _plan_request(
		POLICY_IDS[3],
		morphology,
		true,
		"",
		{},
	)
	var contradiction_result := _call_input(
		api,
		"plan_scheduled_load_transfer_v3_json",
		contradiction,
	)
	var missing_reason := _plan_request(
		POLICY_IDS[3],
		morphology,
		false,
		"",
		{},
	)
	var missing_reason_result := _call_input(
		api,
		"plan_scheduled_load_transfer_v3_json",
		missing_reason,
	)
	_check(
		(
			not bool(contradiction_result.get("ok", true))
			and String(contradiction_result.get("failure_code", "")) == "SCHEMA_INVALID"
			and not bool(missing_reason_result.get("ok", true))
			and String(missing_reason_result.get("failure_code", "")) == "SCHEMA_INVALID"
		),
		"4 contradictory availability inputs fail closed at the native boundary",
	)

	var material_result: Dictionary = MaterialProfilesScript.resolve("godot_jolt_bw5c_mu095_v1")
	var material_profile: Dictionary = material_result.get("profile", {})
	var manifests_exact := bool(material_result.get("ok", false))
	for policy_id_value in POLICY_IDS:
		var policy_id := String(policy_id_value)
		var adapter := AdapterScript.new()
		var start := _start_adapter(adapter, policy_id, material_profile)
		var manifest: Dictionary = start.get("adapter_manifest", {})
		var feedback_policy: Dictionary = manifest.get("stability_v3", {}).get(
			"feedback_policy", {}
		)
		manifests_exact = (
			manifests_exact
			and bool(start.get("ok", false))
			and int(start.get("world_build_count", -1)) == 0
			and (
				String(manifest.get("schema_version", ""))
				== "sporespore_godot_jolt_adapter_manifest_v15"
			)
			and (
				String(feedback_policy.get("portable_plan_operation", ""))
				== "plan_scheduled_load_transfer_v3_json"
			)
			and (
				String(feedback_policy.get("portable_plan_schema_version", ""))
				== "sporespore_scheduled_load_transfer_receipt_v3"
			)
			and (
				String(feedback_policy.get("target_mode", ""))
				== "portable_scheduler_aware_load_transfer_v3_observation_fail_zero"
			)
			and not bool(start.get("physical_acceptance_authority", true))
		)
	_check(
		manifests_exact,
		"5 all declared v3 policies route through additive manifest v15 without a world",
	)

	var routed_adapter := AdapterScript.new()
	var routed_start := _start_adapter(
		routed_adapter,
		POLICY_IDS[3],
		material_profile,
	)
	var routed_shadow: Dictionary = {
		"ok": true,
		"failure_code": "",
		"observation_available": false,
		"unavailable_reason": "NO_QUALIFIED_SUPPORT_CONTACT",
		"state_emitted": true,
		"stability_state": _unavailable_stability_state(full_state),
		"comparison_performed": false,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"physical_balance_recovery": false,
		"physical_acceptance_authority": false,
	}
	var completed_shadow: Dictionary = (
		routed_adapter
		. call(
			"_ensure_v3_unavailable_stability_receipt",
			54,
			morphology,
			routed_shadow,
			1.0,
		)
	)
	var contribution: Dictionary = (
		completed_shadow
		. get(
			"stability_contribution_shadow",
			{},
		)
	)
	var receipt: Dictionary = (
		contribution
		. get(
			"scheduled_load_transfer_receipt",
			{},
		)
	)
	var ordered_contributions: Array = (
		contribution
		. get(
			"ordered_contributions",
			[],
		)
	)
	var zeros_exact := (
		ordered_contributions.size() == (morphology.get("ordered_actuator_ids", []) as Array).size()
	)
	for correction_value in ordered_contributions:
		var correction: Dictionary = correction_value
		zeros_exact = (
			zeros_exact
			and (
				float(
					(
						correction
						. get(
							"applied_canonical_velocity_delta_rad_s",
							NAN,
						)
					)
				)
				== 0.0
			)
			and (
				float(
					(
						correction
						. get(
							"host_target_velocity_delta_rad_s",
							NAN,
						)
					)
				)
				== 0.0
			)
			and bool(correction.get("fallback_zeroed", false))
		)
	var routed_summary: Dictionary = routed_adapter.summary()
	var transfer_summary: Dictionary = (
		routed_summary
		. get(
			"scheduled_load_transfer_summary",
			{},
		)
	)
	var route_checks := {
		"start_ok": bool(routed_start.get("ok", false)),
		"contribution_ok": bool(contribution.get("ok", false)),
		"support_mode": String(contribution.get("support_mode", "")) == "unavailable",
		"receipt_schema":
		(
			String(receipt.get("schema_version", ""))
			== "sporespore_scheduled_load_transfer_receipt_v3"
		),
		"planning_availability":
		String(receipt.get("planning_availability", "")) == "observation_unavailable",
		"zeros_exact": zeros_exact,
		"receipt_count": int(transfer_summary.get("receipt_count", -1)) == 1,
		"unavailable_count":
		(
			int(
				(
					transfer_summary
					. get(
						"observation_unavailable_receipt_count",
						-1,
					)
				)
			)
			== 1
		),
		"fail_zero_count": int(transfer_summary.get("fail_zero_receipt_count", -1)) == 1,
		"mapping_attempted":
		bool(
			(
				(completed_shadow.get("joint_mapping_shadow", {}) as Dictionary)
				. get(
					"attempted",
					false,
				)
			)
		),
	}
	var route_exact := true
	for route_check_value in route_checks.values():
		route_exact = route_exact and bool(route_check_value)
	if not route_exact:
		print(
			"V3_ROUTE_FAILURE ",
			(
				JSON
				. stringify(
					{
						"checks": route_checks,
						"contribution": contribution,
						"transfer_summary": transfer_summary,
					},
					"",
					true,
					true,
				)
			),
		)
	_check(
		route_exact,
		"6 adapter injects one portable receipt and eight safe zeros before overlay",
	)

	var harness_source := FileAccess.get_file_as_string(SHARED_HARNESS_PATH)
	_check(
		(
			harness_source.contains("== _expected_stability_policy_id()")
			and harness_source.contains("_stability_observation_partition_exact(stability_shadow)")
			and harness_source.contains("func _expected_stability_policy_id() -> String:")
			and harness_source.contains("func _stability_observation_partition_exact(")
		),
		"7 shared execution integrity is candidate-relative without rewriting legacy defaults",
	)

	var authority_receipt := {
		"schema_version": "sporespore_scheduled_load_transfer_v3_authority_contract_receipt_v1",
		"passed": _failed == 0,
		"policy_ids": POLICY_IDS,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	print(
		"SCHEDULED_LOAD_TRANSFER_V3_AUTHORITY_CONTRACT ",
		JSON.stringify(authority_receipt, "", true, true),
	)
	_finish()


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
		(
			bodies
			. append(
				{
					"body_id": String(body_id_value),
					"pose_world":
					{
						"position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
						"orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
					},
					"twist_world":
					{
						"linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
						"angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
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
					"point_world_m":
					{
						"x": 0.30 if contact_id.begins_with("front") else -0.30,
						"y": 0.0,
						"z": -0.20 if contact_id.contains("left") else 0.20,
					},
					"normal_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
					"surface_relative_velocity_world_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
					"material_id": "bw11r_contract_material",
					"adapter_id": "bw11r_contract",
					"engine_contact_ids": ["%s_engine" % contact_id],
				}
			)
		)
	return {
		"schema_version": "sporespore_stability_state_v2",
		"semantic_step": 54,
		"ordered_body_states": bodies,
		"ordered_support_contacts": contacts,
		"gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
		"support_plane_forward_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
		"adapter_capability_sha256": "sha256:%s" % "7".repeat(64),
	}


static func _unavailable_stability_state(full_state: Dictionary) -> Dictionary:
	var unavailable := full_state.duplicate(true)
	var contacts: Array = unavailable.get("ordered_support_contacts", [])
	for contact_value in contacts:
		var contact: Dictionary = contact_value
		contact["presence"] = false
		contact["bears_support"] = false
		contact["point_world_m"] = null
	return unavailable


static func _plan_request(
	policy_id: String,
	morphology: Dictionary,
	observation_available: bool,
	unavailable_reason: String,
	stability_state: Dictionary,
) -> Dictionary:
	var ordered_limb_gait_steps: Array = []
	for limb_id_value in morphology.get("ordered_limb_ids", []):
		(
			ordered_limb_gait_steps
			. append(
				{
					"limb_id": String(limb_id_value),
					"gait_step": 54,
				}
			)
		)
	return {
		"schema_version": "sporespore_plan_scheduled_load_transfer_request_v3",
		"descriptor": DESCRIPTOR,
		"request":
		{
			"schema_version": "sporespore_scheduled_load_transfer_request_v3",
			"policy_id": policy_id,
			"semantic_step": 54,
			"observation_available": observation_available,
			"observation_unavailable_reason": null if observation_available else unavailable_reason,
			"gait_amplitude": 1.0,
			"cycle_steps": 360,
			"swing_steps": 72,
			"characterized_friction_coefficient": 0.95,
			"maximum_normal_force_n": float(morphology.get("total_mass_kg", 0.0)) * 9.8,
			"feasibility_tolerance": 1.0e-5,
			"ordered_limb_gait_steps": ordered_limb_gait_steps,
			"stability_state": null if stability_state.is_empty() else stability_state,
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
	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
