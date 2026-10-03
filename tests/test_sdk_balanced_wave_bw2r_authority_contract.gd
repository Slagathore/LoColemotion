extends SceneTree

## BW2R no-world authority contract.
##
## This verifies the one-factor recovery-family freeze, opened-evidence
## bindings, branch-free policy identities, and Godot/Jolt routing before any
## BW2R physics world may be constructed.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const EXPECTED_GATE_COUNT := 9
const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw2r_preregistration.json"
const PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw2r_preregistration_v1"
const STABILITY_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const AUTHORITY_SCOPE := "stability_contribution_overlay"
const PHYSICS_HZ := 120
const EXPECTED_CANDIDATES := {
	"BW2R-A":
	{
		"policy_id": "sporespore_balanced_wave_bw2r_a_v1",
		"policy_digest": "sha256:4ffb7abd947f60287b81c9105fb99b2964355d0e16e13b64bc8b18d9fcec6343",
		"yaw_gain": 1.1,
	},
	"BW2R-B":
	{
		"policy_id": "sporespore_balanced_wave_bw2r_b_v1",
		"policy_digest": "sha256:44e8bfd0e4e1227db56ace8c58fc62fa6dd6bfc0d1cb993367510214272da144",
		"yaw_gain": 1.2,
	},
	"BW2R-C":
	{
		"policy_id": "sporespore_balanced_wave_bw2r_c_v1",
		"policy_digest": "sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0",
		"yaw_gain": 1.3,
	},
}
const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "balanced_wave_bw2r_authority_contract",
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
const SOLVER_POLICY := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": PHYSICS_HZ,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK balanced-wave BW2R no-world authority contract ===")
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)

	var parsed_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PREREGISTRATION_PATH)
	)
	var preregistration: Dictionary = (
		parsed_value if typeof(parsed_value) == TYPE_DICTIONARY else {}
	)
	var matrix: Dictionary = preregistration.get("physics_matrix", {})
	_check(
		(
			String(preregistration.get("schema_version", "")) == PREREGISTRATION_SCHEMA
			and (
				String(preregistration.get("status", ""))
				== "frozen_before_first_bw2r_physics_world"
			)
			and String(preregistration.get("freeze_parent_commit", "")).length() == 40
			and int(matrix.get("reference_pair_world_count", -1)) == 2
			and int(matrix.get("material_world_count", -1)) == 23
			and int(matrix.get("counterexample_world_count", -1)) == 4
			and int(matrix.get("opened_bw3_replay_world_count", -1)) == 12
			and int(matrix.get("total_world_count_per_opened_candidate", -1)) == 41
		),
		"1 BW2R preregistration identity and complete 41-world candidate matrix are exact",
	)

	var opened_evidence_exact := true
	for input_value in preregistration.get("opened_evidence_inputs", []):
		if typeof(input_value) != TYPE_DICTIONARY:
			opened_evidence_exact = false
			continue
		var input: Dictionary = input_value
		var path := String(input.get("path", ""))
		opened_evidence_exact = (
			opened_evidence_exact
			and not path.is_empty()
			and FileAccess.file_exists(path)
			and FileAccess.get_sha256(path) == String(input.get("sha256", ""))
		)
	_check(
		opened_evidence_exact and (preregistration.get("opened_evidence_inputs", []) as Array).size() == 2,
		"2 original BW2 and rejected first-result BW3 evidence remain present and hash exact",
	)

	var observed_digests: Dictionary = {}
	var candidate_contract_exact := true
	var candidate_order: Array = preregistration.get("candidate_order", [])
	for candidate_value in preregistration.get("candidates", []):
		if typeof(candidate_value) != TYPE_DICTIONARY:
			candidate_contract_exact = false
			continue
		var candidate: Dictionary = candidate_value
		var candidate_id := String(candidate.get("candidate_id", ""))
		var expected: Dictionary = EXPECTED_CANDIDATES.get(candidate_id, {})
		var digest := CanonicalJsonScript.sha256(candidate)
		observed_digests[candidate_id] = digest
		candidate_contract_exact = (
			candidate_contract_exact
			and not expected.is_empty()
			and String(candidate.get("policy_id", "")) == String(expected.get("policy_id", ""))
			and digest == String(expected.get("policy_digest", ""))
			and (
				digest
				== String(
					(preregistration.get("candidate_policy_digests", {}) as Dictionary).get(
						candidate_id,
						"",
					)
				)
			)
			and is_equal_approx(
				float(candidate.get("yaw_error_stride_gain_per_rad", NAN)),
				float(expected.get("yaw_gain", NAN)),
			)
			and String(candidate.get("heading_gain_formula", "")) == "1.0 / torso_length_scale"
			and (
				String(candidate.get("velocity_heading_gain_formula", ""))
				== "0.35 * sqrt(torso_length_scale)"
			)
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
		)
	_check(
		(
			candidate_contract_exact
			and candidate_order == ["BW2R-A", "BW2R-B", "BW2R-C"]
			and observed_digests.size() == EXPECTED_CANDIDATES.size()
			and bool(
				(preregistration.get("one_factor_design", {}) as Dictionary).get(
					"branch_topology_frozen_empty",
					false,
				)
			)
		),
		"3 all three one-factor branch-free candidate digests recompute exactly",
	)

	var material_result: Dictionary = MaterialProfilesScript.resolve(
		"godot_jolt_legacy_mu180_d3d5cd1_v1"
	)
	var material_profile: Dictionary = material_result.get("profile", {})
	var starts: Dictionary = {}
	for candidate_id_value in candidate_order:
		var candidate_id := String(candidate_id_value)
		var expected: Dictionary = EXPECTED_CANDIDATES[candidate_id]
		var policy_id := String(expected["policy_id"])
		var normalized := WaveGaitScript._normalize_sdk_authority_options(
			_authority_options(policy_id)
		)
		var normalized_options: Dictionary = normalized.get("sdk_authority_options", {})
		candidate_contract_exact = (
			candidate_contract_exact
			and bool(normalized.get("ok", false))
			and String(normalized_options.get("controller_policy_id", "")) == policy_id
			and String(normalized_options.get("authority_scope", "")) == AUTHORITY_SCOPE
		)
		var adapter := AdapterScript.new()
		starts[candidate_id] = _start_adapter(adapter, policy_id, AUTHORITY_SCOPE, material_profile)
	_check(
		candidate_contract_exact,
		"4 the physical runner preserves every explicit BW2R controller identity",
	)

	_check(
		_profile_matches(starts.get("BW2R-A", {}), EXPECTED_CANDIDATES["BW2R-A"]),
		"5 runtime manifest exposes exact branch-free BW2R-A",
	)
	_check(
		_profile_matches(starts.get("BW2R-B", {}), EXPECTED_CANDIDATES["BW2R-B"]),
		"6 runtime manifest exposes exact branch-free BW2R-B",
	)
	_check(
		_profile_matches(starts.get("BW2R-C", {}), EXPECTED_CANDIDATES["BW2R-C"]),
		"7 runtime manifest exposes exact branch-free BW2R-C",
	)

	var forbidden := AdapterScript.new()
	var forbidden_start := _start_adapter(
		forbidden,
		String(EXPECTED_CANDIDATES["BW2R-A"]["policy_id"]),
		"post_settle_full",
		material_profile,
	)
	_check(
		(
			not bool(forbidden_start.get("ok", false))
			and String(forbidden_start.get("failure_code", "")) == "ADAPTER_START_INPUT_INVALID"
		),
		"8 BW2R authority fails closed outside the bounded stability-overlay scope",
	)

	var claims: Dictionary = preregistration.get("claims", {})
	var post_selection: Dictionary = preregistration.get("post_selection_validation", {})
	var broader_claims_false := true
	for key in [
		"walking_acceptance",
		"material_robustness",
		"arbitrary_material_robustness",
		"continuous_friction_coverage",
		"balance_improvement",
		"physical_balance_recovery",
		"rough_terrain_robustness",
		"external_push_recovery",
		"sensor_fault_robustness",
		"arbitrary_quadruped_coverage",
		"continuous_full_volume_coverage",
		"cross_engine_c6",
		"completed_engine_neutral_sdk",
		"physical_acceptance_authority",
	]:
		broader_claims_false = broader_claims_false and not bool(claims.get(key, true))
	_check(
		(
			broader_claims_false
			and bool(post_selection.get("old_bw3_is_development_data_after_first_result", false))
			and bool(post_selection.get("old_bw3_may_not_be_relabelled_cold_or_independent", false))
			and bool(post_selection.get("new_material_values_required", false))
			and bool(post_selection.get("new_campaign_seeds_required", false))
			and bool(post_selection.get("new_material_characterization_and_profile_publication_required", false))
		),
		"9 replay grants only development selection authority and requires genuinely new validation",
	)
	_finish()


static func _authority_options(policy_id: String) -> Dictionary:
	return {
		"enabled": true,
		"descriptor": DESCRIPTOR,
		"comparison_tolerance": 2.0e-8,
		"authority_scope": AUTHORITY_SCOPE,
		"stability_policy_id": STABILITY_POLICY_ID,
		"controller_policy_id": policy_id,
	}


static func _start_adapter(
	adapter: Variant,
	policy_id: String,
	authority_scope: String,
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
			true,
			0,
			-1,
			authority_scope,
			STABILITY_POLICY_ID,
			material_profile,
			policy_id,
		)
	)


static func _profile_matches(start_result: Dictionary, expected: Dictionary) -> bool:
	var manifest: Dictionary = start_result.get("adapter_manifest", {})
	var profile: Dictionary = manifest.get("controller_profile", {})
	return (
		bool(start_result.get("ok", false))
		and int(start_result.get("world_build_count", -1)) == 0
		and String(profile.get("policy_id", "")) == String(expected.get("policy_id", ""))
		and is_equal_approx(float(profile.get("cross_track_heading_gain_rad_per_m", NAN)), 1.0)
		and is_equal_approx(
			float(profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN)),
			0.35,
		)
		and is_equal_approx(
			float(profile.get("yaw_error_stride_gain_per_rad", NAN)),
			float(expected.get("yaw_gain", NAN)),
		)
		and is_equal_approx(
			float(profile.get("contact_loaded_swing_knee_maximum_motor_target_speed_rad_s", NAN)),
			3.0,
		)
		and is_equal_approx(
			float(profile.get("anchor_error_guard_activation_fraction", NAN)),
			0.8,
		)
		and is_equal_approx(
			float(profile.get("anchor_error_guard_maximum_motor_target_speed_rad_s", NAN)),
			2.0,
		)
		and (profile.get("branch_surfaces", []) as Array).is_empty()
		and bool(profile.get("controller_authority", false))
		and not bool(profile.get("physical_acceptance_authority", true))
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
		"\nBW2R authority contract: %d passed, %d failed (expected %d)"
		% [_passed, _failed, EXPECTED_GATE_COUNT]
	)
	quit(0 if _failed == 0 and _passed == EXPECTED_GATE_COUNT else 1)
