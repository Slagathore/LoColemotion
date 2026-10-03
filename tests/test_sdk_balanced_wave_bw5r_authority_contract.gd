extends SceneTree
# gdlint: disable=max-line-length

## BW5R no-world authority and preregistration contract.
##
## This test must pass before any BW5R physics world is created. It verifies
## the rejected-result binding, the complete prospective candidate identities,
## branch-free cycle-normalized filtered-feedback profiles, future partitions,
## and Godot/Jolt routing without constructing a physics world.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const EXPECTED_GATE_COUNT := 12
const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw5r_preregistration.json"
const PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw5r_preregistration_v1"
const FILTERED_PROFILE_SCHEMA := "sporespore_balanced_wave_filtered_profile_v1"
const PARENT_POLICY_ID := "sporespore_balanced_wave_bw2r_c_v1"
const PARENT_PROFILE_SHA256 := "sha256:a626c6478b4ac3fa1fb214c3cd09e68b5033f939c276dfb2bae679faa3085f2a"
const STABILITY_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const AUTHORITY_SCOPE := "stability_contribution_overlay"
const PHYSICS_HZ := 120
const EXPECTED_CANDIDATES := {
	"BW5R-A":
	{
		"policy_id": "sporespore_balanced_wave_bw5r_a_v1",
		"policy_digest": "sha256:6001dd2b5926908a1bad16d17e49e233cbfb1dfa7eb360bdfe8e4df147b245ac",
		"profile_sha256": "sha256:593ce25ddae1a7eec6e2a5aff5aa666ada42a332a40423d21ed85a51973ce27a",
		"time_constant_cycle_fraction": 1.0 / 32.0,
	},
	"BW5R-B":
	{
		"policy_id": "sporespore_balanced_wave_bw5r_b_v1",
		"policy_digest": "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f",
		"profile_sha256": "sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e",
		"time_constant_cycle_fraction": 1.0 / 16.0,
	},
	"BW5R-C":
	{
		"policy_id": "sporespore_balanced_wave_bw5r_c_v1",
		"policy_digest": "sha256:c067ece936a53edb9cc9d667a68274451e4db67b762ab262bf42e8efe88d742d",
		"profile_sha256": "sha256:b3969632c8fa45c60b7017d710a0f9171fb1cfc7faa99dfe3e2572b1ecf1bbe0",
		"time_constant_cycle_fraction": 1.0 / 8.0,
	},
}
const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "balanced_wave_bw5r_authority_contract",
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
	print("\n=== SDK balanced-wave BW5R no-world authority contract ===")
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)

	var parsed_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PREREGISTRATION_PATH)
	)
	var preregistration: Dictionary = (
		parsed_value if typeof(parsed_value) == TYPE_DICTIONARY else {}
	)
	var reason: Dictionary = preregistration.get("reason_for_successor", {})
	var rejected_path := String(reason.get("rejected_selection_report_path", ""))
	_check(
		(
			String(preregistration.get("schema_version", "")) == PREREGISTRATION_SCHEMA
			and (
				String(preregistration.get("status", ""))
				== "frozen_before_first_bw5r_physics_world"
			)
			and String(preregistration.get("freeze_parent_commit", "")).length() == 40
			and String(reason.get("rejected_family_id", "")) == "BW4R"
			and String(reason.get("rejected_result_status", "")) == "candidate_family_rejected"
			and int(reason.get("bw4r_a_opened_bw4_treatment_nonwalk_count", -1)) == 3
			and int(reason.get("bw4r_b_opened_bw4_treatment_nonwalk_count", -1)) == 1
			and is_equal_approx(
				float(reason.get("frozen_maximum_absolute_lateral_drift_m", NAN)),
				0.10,
			)
			and bool(reason.get("threshold_relaxation_or_gate_deletion_forbidden", false))
			and bool(reason.get("candidate35_repair_or_branch_reuse_forbidden", false))
			and FileAccess.file_exists(rejected_path)
			and (
				FileAccess.get_sha256(rejected_path)
				== String(reason.get("rejected_selection_report_sha256", ""))
			)
		),
		(
			"1 rejected BW4R family, unchanged threshold, branch prohibition, "
			+ "and evidence hash are exact"
		),
	)

	var opened_evidence_exact := true
	var opened_inputs: Array = preregistration.get("opened_evidence_inputs", [])
	for input_value in opened_inputs:
		if typeof(input_value) != TYPE_DICTIONARY:
			opened_evidence_exact = false
			continue
		var input: Dictionary = input_value
		var path := String(input.get("path", ""))
		opened_evidence_exact = (
			opened_evidence_exact
			and FileAccess.file_exists(path)
			and FileAccess.get_sha256(path) == String(input.get("sha256", ""))
		)
	_check(
		opened_evidence_exact and opened_inputs.size() == 4,
		"2 all four opened development evidence inputs remain present and hash exact",
	)

	var candidate_order: Array = preregistration.get("candidate_order", [])
	var observed_policy_digests: Dictionary = {}
	var candidate_contract_exact := candidate_order == ["BW5R-A", "BW5R-B", "BW5R-C"]
	for candidate_value in preregistration.get("candidates", []):
		if typeof(candidate_value) != TYPE_DICTIONARY:
			candidate_contract_exact = false
			continue
		var candidate: Dictionary = candidate_value
		var candidate_id := String(candidate.get("candidate_id", ""))
		var expected: Dictionary = EXPECTED_CANDIDATES.get(candidate_id, {})
		var digest := CanonicalJsonScript.sha256(candidate)
		observed_policy_digests[candidate_id] = digest
		candidate_contract_exact = (
			candidate_contract_exact
			and not expected.is_empty()
			and String(candidate.get("policy_id", "")) == String(expected.get("policy_id", ""))
			and String(candidate.get("parent_policy_id", "")) == PARENT_POLICY_ID
			and String(candidate.get("profile_schema_version", "")) == FILTERED_PROFILE_SCHEMA
			and digest == String(expected.get("policy_digest", ""))
			and (
				digest
				== String(
					(
						(preregistration.get("candidate_policy_digests", {}) as Dictionary)
						. get(
							candidate_id,
							"",
						)
					)
				)
			)
			and int(candidate.get("steering_feedback_update_interval_steps", -1)) == 1
			and candidate.get("maximum_steering_fraction_delta_per_step") == null
			and is_equal_approx(
				float(candidate.get("yaw_error_stride_gain_per_rad", NAN)),
				1.3,
			)
			and is_equal_approx(
				float(candidate.get("steering_low_pass_time_constant_cycle_fraction", NAN)),
				float(expected.get("time_constant_cycle_fraction", NAN)),
			)
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
		)
	print("BW5R_CANDIDATE_DIGESTS ", JSON.stringify(observed_policy_digests))
	_check(
		(
			candidate_contract_exact
			and observed_policy_digests.size() == EXPECTED_CANDIDATES.size()
			and bool(
				(
					(preregistration.get("mechanism_hypothesis", {}) as Dictionary)
					. get(
						"branch_topology_frozen_empty",
						false,
					)
				)
			)
		),
		"3 all three prospective branch-free candidate digests recompute exactly",
	)

	var development: Dictionary = preregistration.get("development_matrix", {})
	var validation: Dictionary = preregistration.get("independent_validation_reservation", {})
	var cold: Dictionary = preregistration.get("cold_acceptance_reservation", {})
	var development_values: Array = development.get("opened_bw4_authored_friction_values", [])
	var development_seeds: Array = development.get("opened_bw4_seeds", [])
	var validation_values: Array = validation.get("authored_friction_values", [])
	var validation_seeds: Array = validation.get("campaign_seeds", [])
	var cold_values: Array = cold.get("authored_friction_values", [])
	var cold_seeds: Array = cold.get("campaign_seeds", [])
	_check(
		(
			int(development.get("expected_world_count_per_candidate", -1)) == 58
			and int(development.get("expected_complete_world_count", -1)) == 174
			and _disjoint(development_values, validation_values)
			and _disjoint(development_values, cold_values)
			and _disjoint(validation_values, cold_values)
			and _disjoint(development_seeds, validation_seeds)
			and _disjoint(development_seeds, cold_seeds)
			and _disjoint(validation_seeds, cold_seeds)
			and bool(validation.get("selection_may_not_observe_reserved_values_or_seeds", false))
			and bool(
				(
					cold
					. get(
						"development_and_validation_may_not_observe_reserved_values_or_seeds",
						false,
					)
				)
			)
		),
		"4 complete development matrix and disjoint validation/cold reservations are frozen",
	)

	var material_result: Dictionary = MaterialProfilesScript.resolve(
		"godot_jolt_legacy_mu180_d3d5cd1_v1"
	)
	var material_profile: Dictionary = material_result.get("profile", {})
	var starts: Dictionary = {}
	for candidate_id_value in candidate_order:
		var candidate_id := String(candidate_id_value)
		var policy_id := String((EXPECTED_CANDIDATES[candidate_id] as Dictionary)["policy_id"])
		var normalized := WaveGaitScript._normalize_sdk_authority_options(
			_authority_options(policy_id)
		)
		candidate_contract_exact = (
			candidate_contract_exact
			and bool(normalized.get("ok", false))
			and (
				String(
					(
						(normalized.get("sdk_authority_options", {}) as Dictionary)
						. get(
							"controller_policy_id",
							"",
						)
					)
				)
				== policy_id
			)
		)
		var adapter := AdapterScript.new()
		starts[candidate_id] = _start_adapter(
			adapter,
			policy_id,
			AUTHORITY_SCOPE,
			material_profile,
		)
	_check(
		candidate_contract_exact,
		"5 the physical runner preserves all three explicit BW5R controller identities",
	)

	var observed_profile_digests: Dictionary = {}
	for candidate_id_value in candidate_order:
		var candidate_id := String(candidate_id_value)
		var start: Dictionary = starts.get(candidate_id, {})
		var manifest: Dictionary = start.get("adapter_manifest", {})
		observed_profile_digests[candidate_id] = String(
			manifest.get("controller_profile_sha256", "")
		)
	print("BW5R_PROFILE_DIGESTS ", JSON.stringify(observed_profile_digests))
	_check(
		_profile_matches(starts.get("BW5R-A", {}), EXPECTED_CANDIDATES["BW5R-A"]),
		"6 runtime manifest exposes exact 1/32-cycle BW5R-A filter",
	)
	_check(
		_profile_matches(starts.get("BW5R-B", {}), EXPECTED_CANDIDATES["BW5R-B"]),
		"7 runtime manifest exposes exact 1/16-cycle BW5R-B filter",
	)
	_check(
		_profile_matches(starts.get("BW5R-C", {}), EXPECTED_CANDIDATES["BW5R-C"]),
		"8 runtime manifest exposes exact 1/8-cycle BW5R-C filter",
	)

	var parent := AdapterScript.new()
	var parent_start := _start_adapter(
		parent,
		PARENT_POLICY_ID,
		AUTHORITY_SCOPE,
		material_profile,
	)
	var parent_manifest: Dictionary = parent_start.get("adapter_manifest", {})
	var parent_profile: Dictionary = parent_manifest.get("controller_profile", {})
	_check(
		(
			bool(parent_start.get("ok", false))
			and int(parent_start.get("world_build_count", -1)) == 0
			and (
				String(parent_manifest.get("controller_profile_sha256", ""))
				== PARENT_PROFILE_SHA256
			)
			and not parent_profile.has("steering_feedback_update_interval_steps")
			and not parent_profile.has("maximum_steering_fraction_delta_per_step")
			and not parent_profile.has("steering_low_pass_time_constant_cycle_fraction")
		),
		"9 immutable BW2R-C parent profile remains byte-stable and legacy-timed",
	)

	var forbidden := AdapterScript.new()
	var forbidden_start := _start_adapter(
		forbidden,
		String(EXPECTED_CANDIDATES["BW5R-A"]["policy_id"]),
		"post_settle_full",
		material_profile,
	)
	_check(
		(
			not bool(forbidden_start.get("ok", false))
			and String(forbidden_start.get("failure_code", "")) == "ADAPTER_START_INPUT_INVALID"
		),
		"10 non-selected BW5R candidates remain forbidden outside stability-overlay authority",
	)
	var selected_full_authority := AdapterScript.new()
	var selected_full_authority_start := _start_adapter(
		selected_full_authority,
		String(EXPECTED_CANDIDATES["BW5R-B"]["policy_id"]),
		"post_settle_full",
		material_profile,
	)
	var selected_full_authority_manifest: Dictionary = (
		selected_full_authority_start
		. get(
			"adapter_manifest",
			{},
		)
	)
	_check(
		(
			bool(selected_full_authority_start.get("ok", false))
			and int(selected_full_authority_start.get("world_build_count", -1)) == 0
			and (
				String(selected_full_authority_start.get("controller_policy_id", ""))
				== String(EXPECTED_CANDIDATES["BW5R-B"]["policy_id"])
			)
			and (
				String(selected_full_authority_start.get("authority_scope", ""))
				== "post_settle_full"
			)
			and bool(selected_full_authority_start.get("actuation_authority", false))
			and (
				String(selected_full_authority_manifest.get("controller_policy_id", ""))
				== String(EXPECTED_CANDIDATES["BW5R-B"]["policy_id"])
			)
			and (
				String(selected_full_authority_manifest.get("authority_scope", ""))
				== "post_settle_full"
			)
			and bool(selected_full_authority_manifest.get("actuation_authority", false))
			and not bool(
				(
					selected_full_authority_start
					. get(
						"physical_acceptance_authority",
						true,
					)
				)
			)
		),
		"11 selected BW5R-B alone supports zero-world full-authority start",
	)

	var claims: Dictionary = preregistration.get("claims", {})
	var interlock: Dictionary = preregistration.get("cross_engine_c6_interlock", {})
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
			and bool(interlock.get("bw5r_development_selection_required", false))
			and bool(interlock.get("new_independent_validation_required", false))
			and bool(interlock.get("new_cold_material_acceptance_required", false))
			and bool(interlock.get("same_selected_portable_policy_authority_required", false))
		),
		"12 preregistration grants development authority only and keeps C6 interlocked",
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
		and String(profile.get("schema_version", "")) == FILTERED_PROFILE_SCHEMA
		and String(profile.get("policy_id", "")) == String(expected.get("policy_id", ""))
		and (
			String(manifest.get("controller_profile_sha256", ""))
			== String(expected.get("profile_sha256", ""))
		)
		and is_equal_approx(float(profile.get("cross_track_heading_gain_rad_per_m", NAN)), 1.0)
		and is_equal_approx(
			float(profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN)),
			0.35,
		)
		and is_equal_approx(float(profile.get("yaw_error_stride_gain_per_rad", NAN)), 1.3)
		and int(profile.get("steering_feedback_update_interval_steps", -1)) == 1
		and not profile.has("maximum_steering_fraction_delta_per_step")
		and is_equal_approx(
			float(profile.get("steering_low_pass_time_constant_cycle_fraction", NAN)),
			float(expected.get("time_constant_cycle_fraction", NAN)),
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


static func _disjoint(first: Array, second: Array) -> bool:
	for value in first:
		if second.has(value):
			return false
	return true


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
			"\nBW5R authority contract: %d passed, %d failed (expected %d)"
			% [_passed, _failed, EXPECTED_GATE_COUNT]
		)
	)
	quit(0 if _failed == 0 and _passed == EXPECTED_GATE_COUNT else 1)
