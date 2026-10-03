extends SceneTree
# gdlint: disable=max-line-length

## G0 identity-preserving fixture-spec boundary. This test performs no physics.
## It proves that the extracted reference fixture is explicit, stable, and
## fail-closed before any generated morphology is allowed to build a world.

const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const EXPECTED_REFERENCE_DIGEST := "sha256:18361994a68e2a9a150aa539aff39679ba4b6e892092e26d218b08f6e12e9c3b"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Experimental BR14A.6 physical quadruped fixture spec G0 ===")
	var reference: Dictionary = FixtureSpecScript.reference_spec()
	var compiled: Dictionary = FixtureSpecScript.compile(reference)
	_check(bool(compiled.get("ok", false)), "reference fixture compiles")
	if not bool(compiled.get("ok", false)):
		printerr("  compile_failure=", compiled)
		_finish()
		return
	var fixture: Dictionary = compiled["fixture_spec"]
	var reference_digest := String(compiled["fixture_spec_sha256"])
	print("REFERENCE_FIXTURE_SPEC_SHA256=", reference_digest)
	_check(
		(
			String(fixture.get("schema_version", ""))
			== "sporespore_physical_quadruped_fixture_spec_v1"
		),
		"reference fixture schema is exact",
	)
	var torso: Dictionary = fixture["torso"]
	_check(
		(
			float(torso["mass_kg"]) == 3.0
			and torso["size_m"] == [0.50, 0.12, 0.32]
			and torso["initial_center_m"] == [0.0, 0.44, 0.0]
		),
		"reference torso values are identity-extracted",
	)
	var limbs: Array = fixture["limbs"]
	var limb_ids: Array = []
	for limb_value in limbs:
		limb_ids.append(String((limb_value as Dictionary)["limb_id"]))
	_check(
		limb_ids == ["front_left", "front_right", "rear_left", "rear_right"],
		"reference limb creation order is exact",
	)
	_check(
		(
			limbs.size() == 4
			and float((limbs[0] as Dictionary)["upper_mass_kg"]) == 0.25
			and float((limbs[0] as Dictionary)["distal_mass_kg"]) == 0.18
			and float((limbs[0] as Dictionary)["upper_length_m"]) == 0.18
			and float((limbs[0] as Dictionary)["lower_length_m"]) == 0.17
			and float((limbs[0] as Dictionary)["foot_radius_m"]) == 0.04
		),
		"reference limb mass and geometry are identity-extracted",
	)
	_check(
		(
			float(fixture["collision_margin_m"]) == 0.002
			and float((fixture["contact_material"] as Dictionary)["friction"]) == 1.8
			and bool((fixture["contact_material"] as Dictionary)["rough"])
			and bool((fixture["body_dynamics"] as Dictionary)["continuous_collision_detection"])
			and not bool((fixture["body_dynamics"] as Dictionary)["can_sleep"])
			and int((fixture["body_dynamics"] as Dictionary)["collision_layer"]) == 2
			and int((fixture["body_dynamics"] as Dictionary)["collision_mask"]) == 1
			and int((fixture["body_dynamics"] as Dictionary)["maximum_reported_contacts"]) == 16
		),
		"reference collision, material, and dynamics values are exact",
	)
	_check(
		(
			float((fixture["joint_limits"] as Dictionary)["hip_lower_rad"]) == -0.72
			and float((fixture["joint_limits"] as Dictionary)["hip_upper_rad"]) == 0.72
			and float((fixture["joint_limits"] as Dictionary)["knee_lower_rad"]) == -0.15
			and float((fixture["joint_limits"] as Dictionary)["knee_upper_rad"]) == 1.10
			and float((fixture["motor_impulses"] as Dictionary)["hip_max_impulse_nms"]) == 0.055
			and (
				float((fixture["motor_impulses"] as Dictionary)["knee_base_max_impulse_nms"])
				== 0.045
			)
			and float((fixture["joint_limits"] as Dictionary)["bias"]) == 0.30
			and float((fixture["joint_limits"] as Dictionary)["relaxation"]) == 1.0
		),
		"reference joint and actuator values are exact",
	)
	_check(
		(
			reference_digest == EXPECTED_REFERENCE_DIGEST
			and String(compiled.get("fixture_spec_sha256", "")) == EXPECTED_REFERENCE_DIGEST
		),
		"reference fixture digest is pinned",
	)
	var verified_reference: Dictionary = FixtureSpecScript.verify(
		reference.duplicate(true), EXPECTED_REFERENCE_DIGEST
	)
	_check(
		(
			bool(verified_reference.get("ok", false))
			and int(verified_reference.get("world_build_count", -1)) == 0
		),
		"pinned reference digest verifies before world construction",
	)
	var digest_mismatch: Dictionary = (
		FixtureSpecScript
		. verify(
			reference.duplicate(true),
			"sha256:0000000000000000000000000000000000000000000000000000000000000000",
		)
	)
	_check(
		(
			not bool(digest_mismatch.get("ok", true))
			and String(digest_mismatch.get("failure_code", "")) == "FIXTURE_SPEC_DIGEST_MISMATCH"
			and String(digest_mismatch.get("actual_sha256", "")) == EXPECTED_REFERENCE_DIGEST
			and int(digest_mismatch.get("world_build_count", -1)) == 0
		),
		"digest mismatch fails closed before world construction",
	)
	var repeated: Dictionary = FixtureSpecScript.compile(reference.duplicate(true))
	_check(
		(
			bool(repeated.get("ok", false))
			and String(repeated.get("fixture_spec_sha256", "")) == reference_digest
		),
		"reference fixture digest is deterministic",
	)
	var heavier: Dictionary = reference.duplicate(true)
	(heavier["torso"] as Dictionary)["mass_kg"] = 3.15
	var heavier_result: Dictionary = FixtureSpecScript.compile(heavier)
	_check(
		(
			bool(heavier_result.get("ok", false))
			and String(heavier_result.get("fixture_spec_sha256", "")) != reference_digest
		),
		"a valid mass-only fixture compiles under a distinct digest",
	)
	(heavier["torso"] as Dictionary)["mass_kg"] = 99.0
	_check(
		(
			float(
				((heavier_result["fixture_spec"] as Dictionary)["torso"] as Dictionary)["mass_kg"]
			)
			== 3.15
		),
		"compiled fixture is isolated from later candidate mutation",
	)
	var unit_scale: Dictionary = FixtureSpecScript.uniform_scaled_spec(1.0)
	_check(
		(
			bool(unit_scale.get("ok", false))
			and String(unit_scale.get("fixture_spec_sha256", "")) == EXPECTED_REFERENCE_DIGEST
			and float(unit_scale.get("uniform_scale", NAN)) == 1.0
			and float(unit_scale.get("density_mass_scale", NAN)) == 1.0
			and float(unit_scale.get("fixed_period_motor_impulse_scale", NAN)) == 1.0
			and int(unit_scale.get("world_build_count", -1)) == 0
		),
		"unit uniform scale preserves the exact reference fixture identity",
	)
	var small_scale_value := 0.90
	var small_scale: Dictionary = FixtureSpecScript.uniform_scaled_spec(small_scale_value)
	var small_fixture: Dictionary = small_scale.get("fixture_spec", {})
	var small_torso: Dictionary = small_fixture.get("torso", {})
	var small_limbs: Array = small_fixture.get("limbs", [])
	var small_motor: Dictionary = small_fixture.get("motor_impulses", {})
	var small_formula_complete := small_limbs.size() == 4
	for small_limb_value in small_limbs:
		var small_limb: Dictionary = small_limb_value
		small_formula_complete = (
			small_formula_complete
			and is_equal_approx(float(small_limb["upper_mass_kg"]), 0.25 * pow(0.90, 3.0))
			and is_equal_approx(float(small_limb["distal_mass_kg"]), 0.18 * pow(0.90, 3.0))
			and is_equal_approx(float(small_limb["upper_length_m"]), 0.18 * 0.90)
			and is_equal_approx(float(small_limb["lower_length_m"]), 0.17 * 0.90)
			and is_equal_approx(float(small_limb["foot_radius_m"]), 0.04 * 0.90)
		)
	_check(
		(
			bool(small_scale.get("ok", false))
			and is_equal_approx(float(small_scale["density_mass_scale"]), pow(0.90, 3.0))
			and is_equal_approx(
				float(small_scale["fixed_period_motor_impulse_scale"]), pow(0.90, 5.0)
			)
			and is_equal_approx(float(small_torso["mass_kg"]), 3.0 * pow(0.90, 3.0))
			and is_equal_approx(float((small_torso["size_m"] as Array)[0]), 0.50 * 0.90)
			and is_equal_approx(float(small_fixture["collision_margin_m"]), 0.002 * 0.90)
			and is_equal_approx(float(small_motor["hip_max_impulse_nms"]), 0.055 * pow(0.90, 5.0))
			and small_formula_complete
		),
		"smaller uniform fixture applies every preregistered s, s-cubed, and s-fifth law",
	)
	var large_scale_value := 1.10
	var large_scale: Dictionary = FixtureSpecScript.uniform_scaled_spec(large_scale_value)
	var large_fixture: Dictionary = large_scale.get("fixture_spec", {})
	var large_torso: Dictionary = large_fixture.get("torso", {})
	var large_limbs: Array = large_fixture.get("limbs", [])
	var large_motor: Dictionary = large_fixture.get("motor_impulses", {})
	var large_formula_complete := large_limbs.size() == 4
	for large_limb_value in large_limbs:
		var large_limb: Dictionary = large_limb_value
		large_formula_complete = (
			large_formula_complete
			and is_equal_approx(float(large_limb["upper_mass_kg"]), 0.25 * pow(1.10, 3.0))
			and is_equal_approx(float(large_limb["distal_mass_kg"]), 0.18 * pow(1.10, 3.0))
			and is_equal_approx(float(large_limb["upper_length_m"]), 0.18 * 1.10)
			and is_equal_approx(float(large_limb["lower_length_m"]), 0.17 * 1.10)
			and is_equal_approx(float(large_limb["foot_radius_m"]), 0.04 * 1.10)
		)
	_check(
		(
			bool(large_scale.get("ok", false))
			and is_equal_approx(float(large_scale["density_mass_scale"]), pow(1.10, 3.0))
			and is_equal_approx(
				float(large_scale["fixed_period_motor_impulse_scale"]), pow(1.10, 5.0)
			)
			and is_equal_approx(float(large_torso["mass_kg"]), 3.0 * pow(1.10, 3.0))
			and is_equal_approx(float((large_torso["size_m"] as Array)[0]), 0.50 * 1.10)
			and is_equal_approx(float(large_fixture["collision_margin_m"]), 0.002 * 1.10)
			and is_equal_approx(
				float(large_motor["knee_base_max_impulse_nms"]), 0.045 * pow(1.10, 5.0)
			)
			and large_formula_complete
		),
		"larger uniform fixture applies every preregistered s, s-cubed, and s-fifth law",
	)
	_check_failure(
		FixtureSpecScript.uniform_scaled_spec(0.0),
		"NONPOSITIVE_NUMERIC_FIELD",
		"zero uniform scale fails closed",
	)
	_check_failure(
		FixtureSpecScript.uniform_scaled_spec(NAN),
		"NONFINITE_NUMERIC_FIELD",
		"nonfinite uniform scale fails closed",
	)
	_check_failure(
		FixtureSpecScript.uniform_scaled_spec(0.20),
		"UNIFORM_SCALE_OUT_OF_RANGE",
		"out-of-range uniform scale fails closed",
	)
	var reference_thresholds: Dictionary = WaveGaitScript.compile_evidence_threshold_options()
	var normalized_reference_thresholds: Dictionary = reference_thresholds.get(
		"evidence_threshold_options", {}
	)
	_check(
		(
			bool(reference_thresholds.get("ok", false))
			and (
				String(normalized_reference_thresholds.get("evidence_threshold_policy_id", ""))
				== "reference_metric_thresholds_v1"
			)
			and (
				float(normalized_reference_thresholds.get("minimum_foot_relocation_m", NAN))
				== 0.012
			)
			and (
				float(normalized_reference_thresholds.get("minimum_evidence_torso_advance_m", NAN))
				== 0.040
			)
			and float(normalized_reference_thresholds.get("maximum_anchor_error_m", NAN)) == 0.025
			and (
				(
					String(reference_thresholds.get("evidence_threshold_configuration_sha256", ""))
					. length()
				)
				== 71
			)
			and int(reference_thresholds.get("world_build_count", -1)) == 0
		),
		"reference metric thresholds compile and digest before world construction",
	)
	var scale_threshold_value := 0.90
	var requested_scale_thresholds := {
		"evidence_threshold_policy_id": "uniform_scale_dimensionless_thresholds_v1",
		"minimum_foot_relocation_m": 0.012 * scale_threshold_value,
		"minimum_evidence_torso_advance_m": 0.040 * scale_threshold_value,
		"minimum_final_torso_advance_m": 0.030 * scale_threshold_value,
		"maximum_lateral_drift_m": 0.100 * scale_threshold_value,
		"maximum_yaw_drift_rad": 0.45,
		"maximum_tilt_rad": 0.60,
		"minimum_torso_height_m": 0.250 * scale_threshold_value,
		"maximum_anchor_error_m": 0.025 * scale_threshold_value,
		"maximum_hinge_axis_error_rad": 0.20,
	}
	var scale_thresholds: Dictionary = WaveGaitScript.compile_evidence_threshold_options(
		requested_scale_thresholds
	)
	_check(
		(
			bool(scale_thresholds.get("ok", false))
			and (
				(scale_thresholds["evidence_threshold_options"] as Dictionary)
				== requested_scale_thresholds
			)
			and (
				String(scale_thresholds.get("evidence_threshold_configuration_sha256", ""))
				!= String(reference_thresholds.get("evidence_threshold_configuration_sha256", ""))
			)
			and int(scale_thresholds.get("world_build_count", -1)) == 0
		),
		"uniform-scale dimensionless thresholds compile under a distinct digest",
	)
	var unknown_threshold: Dictionary = requested_scale_thresholds.duplicate(true)
	unknown_threshold["undeclared"] = true
	_check_failure(
		WaveGaitScript.compile_evidence_threshold_options(unknown_threshold),
		"UNKNOWN_EVIDENCE_THRESHOLD_OPTION",
		"unknown evidence-threshold field fails closed",
	)
	var missing_threshold: Dictionary = requested_scale_thresholds.duplicate(true)
	missing_threshold.erase("maximum_anchor_error_m")
	_check_failure(
		WaveGaitScript.compile_evidence_threshold_options(missing_threshold),
		"MISSING_EVIDENCE_THRESHOLD_OPTION",
		"missing evidence-threshold field fails closed",
	)
	var nonfinite_threshold: Dictionary = requested_scale_thresholds.duplicate(true)
	nonfinite_threshold["maximum_lateral_drift_m"] = NAN
	_check_failure(
		WaveGaitScript.compile_evidence_threshold_options(nonfinite_threshold),
		"EVIDENCE_THRESHOLD_OUT_OF_BOUNDS",
		"nonfinite evidence threshold fails closed",
	)
	var unknown_threshold_policy: Dictionary = requested_scale_thresholds.duplicate(true)
	unknown_threshold_policy["evidence_threshold_policy_id"] = "unregistered"
	_check_failure(
		WaveGaitScript.compile_evidence_threshold_options(unknown_threshold_policy),
		"UNKNOWN_EVIDENCE_THRESHOLD_POLICY_ID",
		"unknown evidence-threshold policy fails closed",
	)

	var unknown_root: Dictionary = reference.duplicate(true)
	unknown_root["undeclared"] = true
	_check_failure(
		FixtureSpecScript.compile(unknown_root),
		"UNKNOWN_FIXTURE_SPEC_FIELD",
		"unknown root field fails closed",
	)
	var missing_root: Dictionary = reference.duplicate(true)
	missing_root.erase("motor_impulses")
	_check_failure(
		FixtureSpecScript.compile(missing_root),
		"MISSING_FIXTURE_SPEC_FIELD",
		"missing root field fails closed",
	)
	var unknown_torso: Dictionary = reference.duplicate(true)
	(unknown_torso["torso"] as Dictionary)["undeclared"] = 1
	_check_failure(
		FixtureSpecScript.compile(unknown_torso),
		"UNKNOWN_FIXTURE_SPEC_FIELD",
		"unknown nested torso field fails closed",
	)
	var wrong_limb_count: Dictionary = reference.duplicate(true)
	(wrong_limb_count["limbs"] as Array).pop_back()
	_check_failure(
		FixtureSpecScript.compile(wrong_limb_count),
		"ASYMMETRIC_LIMB_OMISSION",
		"missing physical limb fails closed",
	)
	var wrong_limb_order: Dictionary = reference.duplicate(true)
	var wrong_order_limbs: Array = wrong_limb_order["limbs"]
	var swap_value: Variant = wrong_order_limbs[0]
	wrong_order_limbs[0] = wrong_order_limbs[1]
	wrong_order_limbs[1] = swap_value
	_check_failure(
		FixtureSpecScript.compile(wrong_limb_order),
		"NONREFERENCE_CONSTRUCTION_ORDER",
		"limb creation-order drift fails closed",
	)
	var zero_mass: Dictionary = reference.duplicate(true)
	(zero_mass["torso"] as Dictionary)["mass_kg"] = 0.0
	_check_failure(
		FixtureSpecScript.compile(zero_mass),
		"NONPOSITIVE_NUMERIC_FIELD",
		"nonpositive torso mass fails closed",
	)
	var nonfinite_geometry: Dictionary = reference.duplicate(true)
	(nonfinite_geometry["torso"] as Dictionary)["size_m"] = [0.50, NAN, 0.32]
	_check_failure(
		FixtureSpecScript.compile(nonfinite_geometry),
		"NONFINITE_NUMERIC_FIELD",
		"nonfinite geometry fails closed",
	)
	var intersecting_foot: Dictionary = reference.duplicate(true)
	((intersecting_foot["limbs"] as Array)[0] as Dictionary)["lower_length_m"] = 0.19
	_check_failure(
		FixtureSpecScript.compile(intersecting_foot),
		"INITIAL_FOOT_INTERPENETRATES_FLOOR",
		"initial foot-floor interpenetration fails closed",
	)
	var oversized_margin: Dictionary = reference.duplicate(true)
	oversized_margin["collision_margin_m"] = 0.04
	_check_failure(
		FixtureSpecScript.compile(oversized_margin),
		"EXCESSIVE_COLLISION_MARGIN",
		"collision margin cannot consume the foot radius",
	)
	var invalid_joint_range: Dictionary = reference.duplicate(true)
	(invalid_joint_range["joint_limits"] as Dictionary)["hip_lower_rad"] = 0.10
	_check_failure(
		FixtureSpecScript.compile(invalid_joint_range),
		"INVALID_HIP_LIMITS",
		"joint range excluding neutral stance fails closed",
	)
	var invalid_motor: Dictionary = reference.duplicate(true)
	(invalid_motor["motor_impulses"] as Dictionary)["hip_max_impulse_nms"] = 0.0
	_check_failure(
		FixtureSpecScript.compile(invalid_motor),
		"NONPOSITIVE_NUMERIC_FIELD",
		"nonpositive motor impulse fails closed",
	)
	var forged_claim: Dictionary = reference.duplicate(true)
	forged_claim["morphology_generalization_established"] = true
	_check_failure(
		FixtureSpecScript.compile(forged_claim),
		"UNKNOWN_FIXTURE_SPEC_FIELD",
		"fixture spec cannot self-authorize morphology generalization",
	)
	_check(
		(
			not fixture.has("morphology_generalization_established")
			and not fixture.has("automatic_creature_guidance_allowed")
			and int(compiled.get("world_build_count", -1)) == 0
		),
		"compiled fixture contains physical data, no claim authority, and builds no world",
	)
	_finish()


func _check_failure(result: Dictionary, expected_code: String, label: String) -> void:
	_check(
		(
			not bool(result.get("ok", true))
			and String(result.get("failure_code", "")) == expected_code
		),
		label,
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
