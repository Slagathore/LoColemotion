extends SceneTree

## BW4R no-world authority and preregistration contract.
##
## This test must pass before any BW4R physics world is created. It verifies
## the rejected-result binding, the complete prospective candidate identities,
## branch-free continuous-feedback profiles, future partition reservations,
## and Godot/Jolt routing without constructing a physics world.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const EXPECTED_GATE_COUNT := 10
const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw4r_preregistration.json"
const PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw4r_preregistration_v1"
const CONTINUOUS_PROFILE_SCHEMA := "sporespore_balanced_wave_continuous_profile_v1"
const PARENT_POLICY_ID := "sporespore_balanced_wave_bw2r_c_v1"
const PARENT_PROFILE_SHA256 := (
	"sha256:a626c6478b4ac3fa1fb214c3cd09e68b5033f939c276dfb2bae679faa3085f2a"
)
const STABILITY_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const AUTHORITY_SCOPE := "stability_contribution_overlay"
const PHYSICS_HZ := 120
const EXPECTED_CANDIDATES := {
	"BW4R-A":
	{
		"policy_id": "sporespore_balanced_wave_bw4r_a_v1",
		"policy_digest":
		"sha256:40dc551e99fea518df68c35d49e3d7d9605484e25cb385f938b3568ddcab2cf4",
		"profile_sha256":
		"sha256:1688531a7ffa0d5b596ff6b22667f353bd4efd2fd5383806409652d640f6bb6e",
		"maximum_delta": null,
	},
	"BW4R-B":
	{
		"policy_id": "sporespore_balanced_wave_bw4r_b_v1",
		"policy_digest":
		"sha256:2496dc6da6dea17cfc7ffee0027234fa7a2a0f4eea8bc463a68db9a9d105bae7",
		"profile_sha256":
		"sha256:8e756112ddf1b649b259bbe768fc52efac53bd5e55c9ec7eed2e0d7ec4cfa48c",
		"maximum_delta": 0.80 / 90.0,
	},
}
const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "balanced_wave_bw4r_authority_contract",
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
	print("\n=== SDK balanced-wave BW4R no-world authority contract ===")
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
	var rejected_path := String(reason.get("rejected_report_path", ""))
	_check(
		(
			String(preregistration.get("schema_version", "")) == PREREGISTRATION_SCHEMA
			and (
				String(preregistration.get("status", ""))
				== "frozen_before_first_bw4r_physics_world"
			)
			and String(preregistration.get("freeze_parent_commit", "")).length() == 40
			and String(reason.get("rejected_policy_id", "")) == PARENT_POLICY_ID
			and String(reason.get("failed_cell_id", ""))
			== "validation_mu140_s18001_treatment"
			and String(reason.get("failed_gate", "")) == "bounded_lateral_drift"
			and is_equal_approx(
				float(reason.get("frozen_maximum_absolute_lateral_drift_m", NAN)),
				0.10,
			)
			and bool(reason.get("legacy_gate_used_world_axis_proxy_not_task_frame", false))
			and bool(
				reason.get("threshold_relaxation_or_gate_deletion_forbidden", false)
			)
			and is_equal_approx(
				float(
					(
						reason.get("successor_gate_semantics", {}) as Dictionary
					).get("maximum_absolute_lateral_drift_m", NAN)
				),
				0.10,
			)
			and FileAccess.file_exists(rejected_path)
			and FileAccess.get_sha256(rejected_path)
			== String(reason.get("rejected_report_sha256", ""))
		),
		(
			"1 rejected BW4 identity, failed cell, unchanged threshold, "
			+ "corrected task-frame semantics, and evidence hash are exact"
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
		opened_evidence_exact and opened_inputs.size() == 3,
		"2 all three opened development evidence inputs remain present and hash exact",
	)

	var candidate_order: Array = preregistration.get("candidate_order", [])
	var observed_policy_digests: Dictionary = {}
	var candidate_contract_exact := candidate_order == ["BW4R-A", "BW4R-B"]
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
			and String(candidate.get("profile_schema_version", "")) == CONTINUOUS_PROFILE_SCHEMA
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
			and int(candidate.get("steering_feedback_update_interval_steps", -1)) == 1
			and is_equal_approx(
				float(candidate.get("yaw_error_stride_gain_per_rad", NAN)),
				1.3,
			)
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
		)
	print("BW4R_CANDIDATE_DIGESTS ", JSON.stringify(observed_policy_digests))
	_check(
		(
			candidate_contract_exact
			and observed_policy_digests.size() == EXPECTED_CANDIDATES.size()
			and bool(
				(preregistration.get("mechanism_hypothesis", {}) as Dictionary).get(
					"branch_topology_frozen_empty",
					false,
				)
			)
		),
		"3 both prospective branch-free candidate digests recompute exactly",
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
			and int(development.get("expected_complete_world_count", -1)) == 116
			and _disjoint(development_values, validation_values)
			and _disjoint(development_values, cold_values)
			and _disjoint(validation_values, cold_values)
			and _disjoint(development_seeds, validation_seeds)
			and _disjoint(development_seeds, cold_seeds)
			and _disjoint(validation_seeds, cold_seeds)
			and bool(validation.get("selection_may_not_observe_reserved_values_or_seeds", false))
			and bool(
				cold.get(
					"development_and_validation_may_not_observe_reserved_values_or_seeds",
					false,
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
					(normalized.get("sdk_authority_options", {}) as Dictionary).get(
						"controller_policy_id",
						"",
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
		"5 the physical runner preserves both explicit BW4R controller identities",
	)

	var observed_profile_digests: Dictionary = {}
	for candidate_id_value in candidate_order:
		var candidate_id := String(candidate_id_value)
		var start: Dictionary = starts.get(candidate_id, {})
		var manifest: Dictionary = start.get("adapter_manifest", {})
		observed_profile_digests[candidate_id] = String(
			manifest.get("controller_profile_sha256", "")
		)
	print("BW4R_PROFILE_DIGESTS ", JSON.stringify(observed_profile_digests))
	_check(
		_profile_matches(starts.get("BW4R-A", {}), EXPECTED_CANDIDATES["BW4R-A"]),
		"6 runtime manifest exposes exact direct per-step BW4R-A",
	)
	_check(
		_profile_matches(starts.get("BW4R-B", {}), EXPECTED_CANDIDATES["BW4R-B"]),
		"7 runtime manifest exposes exact slew-limited per-step BW4R-B",
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
			and String(parent_manifest.get("controller_profile_sha256", ""))
			== PARENT_PROFILE_SHA256
			and not parent_profile.has("steering_feedback_update_interval_steps")
			and not parent_profile.has("maximum_steering_fraction_delta_per_step")
		),
		"8 immutable BW2R-C parent profile remains byte-stable and legacy-timed",
	)

	var forbidden := AdapterScript.new()
	var forbidden_start := _start_adapter(
		forbidden,
		String(EXPECTED_CANDIDATES["BW4R-A"]["policy_id"]),
		"post_settle_full",
		material_profile,
	)
	_check(
		(
			not bool(forbidden_start.get("ok", false))
			and String(forbidden_start.get("failure_code", "")) == "ADAPTER_START_INPUT_INVALID"
		),
		"9 BW4R fails closed outside bounded stability-overlay authority",
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
			and bool(interlock.get("bw4r_development_selection_required", false))
			and bool(interlock.get("new_independent_validation_required", false))
			and bool(interlock.get("new_cold_material_acceptance_required", false))
			and bool(interlock.get("same_selected_portable_policy_authority_required", false))
		),
		"10 preregistration grants development authority only and keeps C6 interlocked",
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
	var expected_delta: Variant = expected.get("maximum_delta")
	var delta_exact := (
		not profile.has("maximum_steering_fraction_delta_per_step")
		if expected_delta == null
		else (
			is_equal_approx(
				float(profile.get("maximum_steering_fraction_delta_per_step", NAN)),
				float(expected_delta),
			)
		)
	)
	return (
		bool(start_result.get("ok", false))
		and int(start_result.get("world_build_count", -1)) == 0
		and String(profile.get("schema_version", "")) == CONTINUOUS_PROFILE_SCHEMA
		and String(profile.get("policy_id", "")) == String(expected.get("policy_id", ""))
		and String(manifest.get("controller_profile_sha256", ""))
		== String(expected.get("profile_sha256", ""))
		and is_equal_approx(float(profile.get("cross_track_heading_gain_rad_per_m", NAN)), 1.0)
		and is_equal_approx(
			float(profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN)),
			0.35,
		)
		and is_equal_approx(float(profile.get("yaw_error_stride_gain_per_rad", NAN)), 1.3)
		and int(profile.get("steering_feedback_update_interval_steps", -1)) == 1
		and delta_exact
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
		"\nBW4R authority contract: %d passed, %d failed (expected %d)"
		% [_passed, _failed, EXPECTED_GATE_COUNT]
	)
	quit(0 if _failed == 0 and _passed == EXPECTED_GATE_COUNT else 1)
