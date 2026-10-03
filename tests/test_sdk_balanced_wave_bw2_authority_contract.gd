extends SceneTree

## BW2 no-world authority contract. This verifies the prospective candidate
## freeze and adapter routing before any BW2 physics world is constructed.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const EXPECTED_GATE_COUNT := 11
const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw2_preregistration.json"
const BALANCED_POLICY_ID := "sporespore_balanced_wave_v1"
const BALANCED_B_POLICY_ID := "sporespore_balanced_wave_bw2_b_v1"
const BALANCED_C_POLICY_ID := "sporespore_balanced_wave_bw2_c_v1"
const CANDIDATE35_POLICY_ID := "g4_gq15_candidate35_v5"
const STABILITY_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const AUTHORITY_SCOPE := "stability_contribution_overlay"
const PHYSICS_HZ := 120
const SOLVER_POLICY := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": PHYSICS_HZ,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "balanced_wave_bw2_authority_contract",
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}
const GAIT_STEPS := {
	"front_left": 0,
	"front_right": 0,
	"rear_left": 0,
	"rear_right": 0,
}
const EXPECTED_POLICY_DIGESTS := {
	"BW2-A": "sha256:d1ce56ba1a74f843700559e1b240c3a5a4ea33c31d7a14d874fdd2c6ebfb2fd9",
	"BW2-B": "sha256:0ab4fa4c4e37441b26bdd00d23926e4511892201150bf61554c5b1362edf7913",
	"BW2-C": "sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3",
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK balanced-wave BW2 no-world authority contract ===")
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)

	var preregistration_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PREREGISTRATION_PATH)
	)
	var preregistration: Dictionary = (
		preregistration_value if typeof(preregistration_value) == TYPE_DICTIONARY else {}
	)
	_check(
		(
			(
				String(preregistration.get("schema_version", ""))
				== "sporespore_balanced_wave_bw2_preregistration_v1"
			)
			and String(preregistration.get("status", "")) == "frozen_before_first_bw2_physics_world"
			and (
				int(
					(
						(preregistration.get("physics_matrix", {}) as Dictionary)
						. get(
							"total_world_count_per_opened_candidate",
							-1,
						)
					)
				)
				== 29
			)
		),
		"1 BW2 preregistration identity and 29-world matrix are exact",
	)

	var observed_digests: Dictionary = {}
	var candidate_contract_ok := true
	for candidate_value in preregistration.get("candidates", []):
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
		)
	_check(
		candidate_contract_ok and observed_digests == EXPECTED_POLICY_DIGESTS,
		"2 all three branch-free candidate policy digests recompute exactly",
	)

	var authority_options := _authority_options(BALANCED_POLICY_ID)
	var normalized: Dictionary = WaveGaitScript._normalize_sdk_authority_options(authority_options)
	var normalized_options: Dictionary = normalized.get("sdk_authority_options", {})
	_check(
		(
			bool(normalized.get("ok", false))
			and String(normalized_options.get("controller_policy_id", "")) == BALANCED_POLICY_ID
			and String(normalized_options.get("authority_scope", "")) == AUTHORITY_SCOPE
		),
		"3 physical runner preserves explicit balanced controller authority",
	)

	var material_options := authority_options.duplicate(true)
	material_options["material_profile_id"] = "godot_jolt_legacy_mu180_d3d5cd1_v1"
	var normalized_material: Dictionary = WaveGaitScript._normalize_sdk_authority_options(
		material_options
	)
	_check(
		(
			bool(normalized_material.get("ok", false))
			and (
				String(
					(normalized_material.get("sdk_authority_options", {}) as Dictionary).get(
						"material_profile_id", ""
					)
				)
				== "godot_jolt_legacy_mu180_d3d5cd1_v1"
			)
		),
		"4 balanced authority and explicit material identity normalize together",
	)

	var material_result: Dictionary = MaterialProfilesScript.resolve(
		"godot_jolt_legacy_mu180_d3d5cd1_v1"
	)
	var material_profile: Dictionary = material_result.get("profile", {})
	var balanced_adapter := AdapterScript.new()
	var balanced_start := _start_adapter(
		balanced_adapter,
		BALANCED_POLICY_ID,
		AUTHORITY_SCOPE,
		true,
		material_profile,
	)
	_check(
		(
			bool(material_result.get("ok", false))
			and bool(balanced_start.get("ok", false))
			and int(balanced_start.get("world_build_count", -1)) == 0
		),
		"5 balanced plus stability authority starts without constructing a world",
	)
	var balanced_manifest: Dictionary = balanced_start.get("adapter_manifest", {})
	var balanced_profile: Dictionary = balanced_manifest.get("controller_profile", {})
	var physical_overlay: Dictionary = (
		(balanced_manifest.get("stability_v3", {}) as Dictionary).get("physical_overlay", {})
	)
	_check(
		(
			String(balanced_profile.get("policy_id", "")) == BALANCED_POLICY_ID
			and is_equal_approx(
				float(balanced_profile.get("cross_track_heading_gain_rad_per_m", NAN)),
				1.0,
			)
			and is_equal_approx(
				float(
					(
						balanced_profile
						. get(
							"cross_track_velocity_heading_gain_rad_per_m_s",
							NAN,
						)
					)
				),
				0.30,
			)
			and is_equal_approx(
				float(balanced_profile.get("yaw_error_stride_gain_per_rad", NAN)),
				1.0,
			)
			and is_equal_approx(
				float(
					(
						balanced_profile
						. get(
							"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
							NAN,
						)
					)
				),
				3.25,
			)
			and is_equal_approx(
				float(
					(
						balanced_profile
						. get(
							"anchor_error_guard_activation_fraction",
							NAN,
						)
					)
				),
				0.85,
			)
			and is_equal_approx(
				float(
					(
						balanced_profile
						. get(
							"anchor_error_guard_maximum_motor_target_speed_rad_s",
							NAN,
						)
					)
				),
				2.25,
			)
			and (balanced_profile.get("branch_surfaces", []) as Array).is_empty()
		),
		"6 runtime manifest exposes the exact frozen branch-free BW2-A profile",
	)

	var balanced_b_adapter := AdapterScript.new()
	var balanced_b_start := _start_adapter(
		balanced_b_adapter,
		BALANCED_B_POLICY_ID,
		AUTHORITY_SCOPE,
		true,
		material_profile,
	)
	_check(
		_profile_matches(
			balanced_b_start,
			BALANCED_B_POLICY_ID,
			0.275,
			3.50,
			0.90,
			2.50,
		),
		"7 runtime manifest exposes the exact frozen branch-free BW2-B profile",
	)

	var balanced_c_adapter := AdapterScript.new()
	var balanced_c_start := _start_adapter(
		balanced_c_adapter,
		BALANCED_C_POLICY_ID,
		AUTHORITY_SCOPE,
		true,
		material_profile,
	)
	_check(
		_profile_matches(
			balanced_c_start,
			BALANCED_C_POLICY_ID,
			0.35,
			3.00,
			0.80,
			2.00,
		),
		"8 runtime manifest exposes the exact frozen branch-free BW2-C profile",
	)
	_check(
		(
			(
				String(balanced_manifest.get("schema_version", ""))
				== "sporespore_godot_jolt_adapter_manifest_v14"
			)
			and (
				String(balanced_manifest.get("execution_mode", ""))
				== "portable_balanced_wave_base_with_stability_overlay"
			)
			and (
				String(physical_overlay.get("base_command", ""))
				== "portable_balanced_wave_ordered_command"
			)
			and not bool(balanced_start.get("physical_acceptance_authority", true))
		),
		"9 manifest binds portable base commands to the bounded stability overlay",
	)

	var forbidden_adapter := AdapterScript.new()
	var forbidden_start := _start_adapter(
		forbidden_adapter,
		BALANCED_POLICY_ID,
		"post_settle_full",
		true,
		material_profile,
	)
	_check(
		(
			not bool(forbidden_start.get("ok", false))
			and String(forbidden_start.get("failure_code", "")) == "ADAPTER_START_INPUT_INVALID"
		),
		"10 balanced authority remains forbidden outside the preregistered scope",
	)

	var legacy_adapter := AdapterScript.new()
	var legacy_start := _start_adapter(
		legacy_adapter,
		CANDIDATE35_POLICY_ID,
		AUTHORITY_SCOPE,
		true,
		material_profile,
	)
	var legacy_overlay: Dictionary = (
		(
			(legacy_start.get("adapter_manifest", {}) as Dictionary).get("stability_v3", {})
			as Dictionary
		)
		. get("physical_overlay", {})
	)
	_check(
		(
			bool(legacy_start.get("ok", false))
			and (
				String(legacy_overlay.get("base_command", ""))
				== "unchanged_legacy_candidate35_motor_target_velocity"
			)
		),
		"11 Candidate 35 legacy-overlay behavior remains explicitly unchanged",
	)
	_finish()


static func _authority_options(controller_policy_id: String) -> Dictionary:
	return {
		"enabled": true,
		"descriptor": DESCRIPTOR,
		"comparison_tolerance": 2.0e-8,
		"authority_scope": AUTHORITY_SCOPE,
		"stability_policy_id": STABILITY_POLICY_ID,
		"controller_policy_id": controller_policy_id,
	}


static func _start_adapter(
	adapter: Variant,
	controller_policy_id: String,
	authority_scope: String,
	actuation_authority: bool,
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
			"clocked",
			actuation_authority,
			0,
			-1,
			authority_scope,
			STABILITY_POLICY_ID,
			material_profile,
			controller_policy_id,
		)
	)


static func _profile_matches(
	start_result: Dictionary,
	policy_id: String,
	velocity_gain: float,
	knee_cap: float,
	anchor_fraction: float,
	anchor_cap: float,
) -> bool:
	var manifest: Dictionary = start_result.get("adapter_manifest", {})
	var profile: Dictionary = manifest.get("controller_profile", {})
	return (
		bool(start_result.get("ok", false))
		and int(start_result.get("world_build_count", -1)) == 0
		and String(profile.get("policy_id", "")) == policy_id
		and is_equal_approx(
			float(profile.get("cross_track_heading_gain_rad_per_m", NAN)),
			1.0,
		)
		and is_equal_approx(
			float(profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN)),
			velocity_gain,
		)
		and is_equal_approx(
			float(profile.get("yaw_error_stride_gain_per_rad", NAN)),
			1.0,
		)
		and is_equal_approx(
			float(
				profile.get(
					"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
					NAN,
				)
			),
			knee_cap,
		)
		and is_equal_approx(
			float(profile.get("anchor_error_guard_activation_fraction", NAN)),
			anchor_fraction,
		)
		and is_equal_approx(
			float(
				profile.get(
					"anchor_error_guard_maximum_motor_target_speed_rad_s",
					NAN,
				)
			),
			anchor_cap,
		)
		and (profile.get("branch_surfaces", []) as Array).is_empty()
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: ", label)
	else:
		_failed += 1
		push_error("  FAIL: %s" % label)


func _finish() -> void:
	print(
		(
			"\nSDK balanced-wave BW2 authority-contract summary: %d passed, %d failed"
			% [_passed, _failed]
		)
	)
	if _passed != EXPECTED_GATE_COUNT:
		_failed += 1
		push_error("Expected %d gates, observed %d" % [EXPECTED_GATE_COUNT, _passed])
	quit(0 if _failed == 0 else 1)
