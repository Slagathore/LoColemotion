extends SceneTree
# gdlint: disable=max-line-length

## Zero-world executable contract for the BW19V global residual-scale family.
##
## Every arm uses the same BW15F-B native controller and frozen BW13P-A
## scheduler-aware portable plan. The only varying field is one core-owned
## global scale applied before the existing contribution magnitude and slew
## limits. This test creates no Node3D, physics body, or locomotion outcome.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const WaveGaitScript := preload(
	"res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
)

const CONTROLLER_POLICY_ID := "sporespore_balanced_wave_bw15f_b_v1"
const STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_a_v3"
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const CANDIDATE_IDS := ["BW19V-A", "BW19V-B"]
const GLOBAL_SCALES := [0.0, 0.5]
const SOLVER_POLICY_OPTIONS := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": 120,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "bw19v_zero_world_reference",
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}
const TOLERANCE := 1.0e-12

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK BW19V zero-world global-scale contract ===")
	var material_result := MaterialProfilesScript.resolve(MATERIAL_PROFILE_ID)
	_check(
		(
			bool(material_result.get("ok", false))
			and (
				String(
					(
						(material_result.get("profile", {}) as Dictionary)
						. get(
							"profile_id",
							"",
						)
					)
				)
				== MATERIAL_PROFILE_ID
			)
		),
		"1 the held Godot Jolt material profile resolves without a world",
	)
	if not bool(material_result.get("ok", false)):
		_finish()
		return
	var plan := (
		WaveGaitScript
		. compile_sdk_execution_mode_plan(
			true,
			true,
			"post_settle_full",
			STABILITY_POLICY_ID,
			-3,
		)
	)
	_check(
		(
			bool(plan.get("ok", false))
			and bool(plan.get("full_post_settle_authority_enabled", false))
			and bool(
				plan.get(
					"full_authority_stability_contribution_enabled",
					false,
				)
			)
			and bool(
				plan.get(
					"exclusive_native_post_settle_motor_writes_required",
					false,
				)
			)
			and not bool(plan.get("legacy_base_motor_writes_allowed", true))
		),
		"2 the unchanged BW13P-A composition resolves to exclusive native authority",
	)
	if not bool(plan.get("ok", false)):
		_finish()
		return

	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var starts: Array[Dictionary] = []
	var boundaries: Array[Dictionary] = []
	var adapters: Array[RefCounted] = []
	for scale_value in GLOBAL_SCALES:
		var adapter: RefCounted = AdapterScript.new()
		var start := _start_adapter(
			adapter,
			plan,
			material_result["profile"],
			float(scale_value),
		)
		adapters.append(adapter)
		starts.append(start)
		boundaries.append(
			(
				adapter.preflight_perfect_declared_policy_runtime_boundary()
				if bool(start.get("ok", false))
				else {}
			)
		)

	var starts_exact := starts.size() == GLOBAL_SCALES.size()
	for index in range(starts.size()):
		var start: Dictionary = starts[index]
		var manifest: Dictionary = start.get("adapter_manifest", {})
		var stability: Dictionary = manifest.get("stability_v3", {})
		var contribution: Dictionary = stability.get("contribution_shadow", {})
		starts_exact = (
			starts_exact
			and bool(start.get("ok", false))
			and String(start.get("controller_policy_id", "")) == CONTROLLER_POLICY_ID
			and String(start.get("stability_policy_id", "")) == STABILITY_POLICY_ID
			and String(start.get("authority_scope", "")) == "post_settle_full"
			and String(manifest.get("execution_mode", ""))
			== "native_balanced_wave_base_with_stability_contribution"
			and String(manifest.get("stability_influence_scale_authority", ""))
			== "portable_core_v3"
			and _near(
				float(manifest.get("stability_influence_global_scale", NAN)),
				float(GLOBAL_SCALES[index]),
			)
			and String(contribution.get("influence_operation", ""))
			== "bound_stability_influence_v3_json"
			and _near(
				float(
					contribution.get(
						"global_requested_correction_scale",
						NAN,
					)
				),
				float(GLOBAL_SCALES[index]),
			)
			and not bool(contribution.get("adapter_actuation_applied", true))
			and not bool(contribution.get("physics_state_modified", true))
			and not bool(contribution.get("physical_acceptance_authority", true))
		)
	_check(
		starts_exact,
		"3 both arms differ only through the portable-core v3 global scale",
	)

	var boundaries_exact := boundaries.size() == GLOBAL_SCALES.size()
	var reference_raw_by_actuator: Dictionary = {}
	for index in range(boundaries.size()):
		var boundary: Dictionary = boundaries[index]
		var influence: Dictionary = boundary.get(
			"portable_stability_influence_receipt",
			{},
		)
		var receipt: Dictionary = influence.get("influence_receipt", {})
		var ordered: Array = influence.get("ordered_contributions", [])
		boundaries_exact = (
			boundaries_exact
			and bool(boundary.get("ok", false))
			and bool(boundary.get("portable_stability_influence_required", false))
			and bool(boundary.get("portable_stability_influence_passed", false))
			and String(
				influence.get(
					"stability_influence_operation",
					"",
				)
			)
			== "bound_stability_influence_v3_json"
			and String(receipt.get("schema_version", ""))
			== "sporespore_stability_influence_receipt_v3"
			and bool(
				receipt.get(
					"global_scale_applied_before_magnitude_and_slew",
					false,
				)
			)
			and _near(
				float(receipt.get("global_requested_correction_scale", NAN)),
				float(GLOBAL_SCALES[index]),
			)
			and ordered.size() == 8
			and int(boundary.get("actual_world_build_count", -1)) == 0
			and int(boundary.get("scene_tree_insertion_count", -1)) == 0
			and not bool(boundary.get("physics_state_modified", true))
			and not bool(boundary.get("locomotion_outcome_exposed", true))
			and not bool(boundary.get("physical_acceptance_authority", true))
		)
		for contribution_value in ordered:
			var contribution: Dictionary = contribution_value
			var actuator_id := String(contribution.get("actuator_id", ""))
			var raw := float(
				contribution.get(
					"proposed_canonical_velocity_delta_rad_s",
					NAN,
				)
			)
			var scaled := float(
				contribution.get(
					"scaled_proposed_canonical_velocity_delta_rad_s",
					NAN,
				)
			)
			var applied := float(
				contribution.get(
					"applied_canonical_velocity_delta_rad_s",
					NAN,
				)
			)
			if index == 0:
				reference_raw_by_actuator[actuator_id] = raw
			boundaries_exact = (
				boundaries_exact
				and not actuator_id.is_empty()
				and reference_raw_by_actuator.has(actuator_id)
				and _near(raw, float(reference_raw_by_actuator[actuator_id]))
				and _near(scaled, raw * float(GLOBAL_SCALES[index]))
				and _near(applied, scaled)
			)
	_check(
		boundaries_exact,
		"4 every real runtime boundary applies the exact scale before unchanged limits",
	)

	var zero_influence: Dictionary = boundaries[0].get(
		"portable_stability_influence_receipt",
		{},
	)
	var zero_exact := (
		float(
			zero_influence.get(
				"maximum_absolute_proposed_velocity_rad_s",
				0.0,
			)
		)
		> 0.0
		and _near(
			float(
				zero_influence.get(
					"maximum_absolute_applied_velocity_rad_s",
					NAN,
				)
			),
			0.0,
		)
	)
	for contribution_value in zero_influence.get("ordered_contributions", []):
		var contribution: Dictionary = contribution_value
		zero_exact = (
			zero_exact
			and _near(
				float(
					contribution.get(
						"scaled_proposed_canonical_velocity_delta_rad_s",
						NAN,
					)
				),
				0.0,
			)
			and _near(
				float(
					contribution.get(
						"applied_canonical_velocity_delta_rad_s",
						NAN,
					)
				),
				0.0,
			)
		)
	_check(
		zero_exact,
		"5 scale zero preserves a nonzero raw witness while enforcing exact-zero influence",
	)

	var invalid_scales := [-0.01, 1.01, NAN]
	var invalid_fail_closed := true
	for scale_value in invalid_scales:
		var invalid_adapter: RefCounted = AdapterScript.new()
		var invalid_start := _start_adapter(
			invalid_adapter,
			plan,
			material_result["profile"],
			float(scale_value),
		)
		invalid_fail_closed = (
			invalid_fail_closed
			and not bool(invalid_start.get("ok", true))
			and String(invalid_start.get("failure_code", ""))
			== "ADAPTER_START_INPUT_INVALID"
		)
	_check(
		invalid_fail_closed,
		"6 nonfinite and out-of-range scales fail closed before extension startup",
	)
	_check(
		(
			root.get_child_count() == root_children_before
			and Engine.physics_ticks_per_second == physics_hz_before
		),
		"7 the complete two-arm contract creates no world and mutates no physics clock",
	)
	_check(
		(
			CANDIDATE_IDS.size() == GLOBAL_SCALES.size()
			and GLOBAL_SCALES == [0.0, 0.5]
		),
		"8 the prospective family is the exact preregistered control and hypothesis pair",
	)
	_finish()


func _start_adapter(
	adapter: RefCounted,
	plan: Dictionary,
	material_profile: Dictionary,
	scale: float,
) -> Dictionary:
	return adapter.start(
		DESCRIPTOR,
		plan.get("zero_base_initial_gait_steps", {}) as Dictionary,
		0.0,
		Vector3.ZERO,
		Vector3.BACK,
		0.0,
		120,
		SOLVER_POLICY_OPTIONS,
		2.5e-7,
		"clocked",
		true,
		-3,
		360,
		"post_settle_full",
		STABILITY_POLICY_ID,
		material_profile,
		CONTROLLER_POLICY_ID,
		scale,
	)


func _near(actual: float, expected: float) -> bool:
	return (
		is_finite(actual)
		and is_finite(expected)
		and absf(actual - expected) <= TOLERANCE
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print(
		"\nSDK BW19V global-scale summary: %d passed, %d failed"
		% [_passed, _failed]
	)
	quit(0 if _failed == 0 else 1)
