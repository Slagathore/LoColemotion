class_name LabMorphologyFeatureReceipt
extends RefCounted

## Pure, fail-closed morphology feature compiler.
##
## This module is intentionally descriptive. It reconstructs physical and
## dimensionless features from sealed generator/fixture/controller inputs
## without building a physics world, and it grants no controller or acceptance
## authority.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FiniteSanitizerScript := preload("res://scripts/lab/finite_sanitizer.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const ProportionSpecScript := preload(
	"res://scripts/lab/gait/physical_quadruped_proportion_spec.gd"
)

const SCHEMA_VERSION := "sporespore_morphology_feature_receipt_v1"
const POLICY_ID := "g4_gq13_compiled_physical_features_v1"
const GQ14_POLICY_ID := "g4_gq14_compiled_physical_features_v1"
const GQ15_POLICY_ID := "g4_gq15_compiled_physical_features_v1"
const TOPOLOGY_FAMILY_ID := "rigid_articulated_quadruped_v1"
const GRAVITY_M_S2 := 9.8
const AXIS_ORDER := [
	"torso_length_scale",
	"torso_width_scale",
	"upper_length_fraction",
	"hip_span_scale",
	"foot_radius_scale",
	"front_limb_mass_scale",
]


static func compile(
	generation_result: Dictionary,
	proportion_compile_result: Dictionary,
	controller_configuration_sha256: String,
	clock_options: Dictionary,
	solver_options: Dictionary,
) -> Dictionary:
	if (
		not bool(generation_result.get("ok", false))
		or int(generation_result.get("world_build_count", -1)) != 0
	):
		return _failure("MORPHOLOGY_FEATURE_GENERATION_INVALID")
	if (
		not bool(proportion_compile_result.get("ok", false))
		or int(proportion_compile_result.get("world_build_count", -1)) != 0
	):
		return _failure("MORPHOLOGY_FEATURE_PROPORTION_COMPILE_INVALID")
	if not _digest_valid(controller_configuration_sha256):
		return _failure("MORPHOLOGY_FEATURE_CONTROLLER_DIGEST_INVALID")
	if clock_options.is_empty():
		return _failure("MORPHOLOGY_FEATURE_CLOCK_EMPTY")
	if solver_options.is_empty():
		return _failure("MORPHOLOGY_FEATURE_SOLVER_EMPTY")

	var generator_receipt: Dictionary = generation_result.get("generator_receipt", {})
	var proportion_spec: Dictionary = generation_result.get("proportion_spec", {})
	var compiled_proportion: Dictionary = proportion_compile_result.get("proportion_spec", {})
	if (
		generator_receipt.is_empty()
		or proportion_spec.is_empty()
		or proportion_spec != compiled_proportion
		or generator_receipt.get("proportion_spec", {}) != proportion_spec
	):
		return _failure("MORPHOLOGY_FEATURE_SOURCE_IDENTITY_MISMATCH")
	var campaign_id := String(generator_receipt.get("campaign_id", ""))
	if (
		campaign_id
		not in [
			ProportionSpecScript.CAMPAIGN_GQ11,
			ProportionSpecScript.CAMPAIGN_GQ12,
			ProportionSpecScript.CAMPAIGN_GQ13,
			ProportionSpecScript.CAMPAIGN_GQ14,
			ProportionSpecScript.CAMPAIGN_GQ15,
		]
	):
		return _failure("MORPHOLOGY_FEATURE_CAMPAIGN_INVALID")
	var generator_digest := String(generation_result.get("generator_receipt_sha256", ""))
	if (
		not _digest_valid(generator_digest)
		or generator_digest != CanonicalJsonScript.sha256(generator_receipt)
	):
		return _failure("MORPHOLOGY_FEATURE_GENERATOR_DIGEST_MISMATCH")

	var fixture: Dictionary = proportion_compile_result.get("fixture_spec", {})
	var fixture_compile := FixtureSpecScript.compile(fixture)
	if not bool(fixture_compile.get("ok", false)):
		return _failure("MORPHOLOGY_FEATURE_FIXTURE_INVALID")
	var fixture_digest := String(proportion_compile_result.get("fixture_spec_sha256", ""))
	if (
		not _digest_valid(fixture_digest)
		or fixture_digest != String(fixture_compile.get("fixture_spec_sha256", ""))
	):
		return _failure("MORPHOLOGY_FEATURE_FIXTURE_DIGEST_MISMATCH")

	var axis_coordinates: Dictionary = generator_receipt.get("axis_coordinates", {})
	if axis_coordinates.size() != AXIS_ORDER.size():
		return _failure("MORPHOLOGY_FEATURE_AXIS_SET_INVALID")
	var ordered_axis_samples: Array = []
	var ordered_signed_coordinates: Array = []
	var ordered_realized_scales: Array = []
	for axis_key_value in AXIS_ORDER:
		var axis_key := String(axis_key_value)
		if not axis_coordinates.has(axis_key) or not proportion_spec.has(axis_key):
			return _failure("MORPHOLOGY_FEATURE_AXIS_MISSING")
		var axis: Dictionary = axis_coordinates[axis_key]
		var signed_coordinate := float(axis.get("centered_coordinate", NAN))
		var radical_inverse := float(axis.get("radical_inverse", NAN))
		var realized_scale := float(proportion_spec[axis_key])
		if (
			not is_finite(signed_coordinate)
			or not is_finite(radical_inverse)
			or not is_finite(realized_scale)
			or radical_inverse < 0.0
			or radical_inverse >= 1.0
		):
			return _failure("MORPHOLOGY_FEATURE_AXIS_NONFINITE")
		ordered_signed_coordinates.append(signed_coordinate)
		ordered_realized_scales.append(realized_scale)
		ordered_axis_samples.append(
			{
				"axis_id": axis_key,
				"base_dimensionless": int(axis.get("base", 0)),
				"radical_inverse_dimensionless": radical_inverse,
				"signed_centered_coordinate_dimensionless": signed_coordinate,
				"realized_scale_dimensionless": realized_scale,
			}
		)

	var torso: Dictionary = fixture["torso"]
	var torso_size: Array = torso["size_m"]
	var torso_length_m := float(torso_size[0])
	var torso_height_m := float(torso_size[1])
	var torso_width_m := float(torso_size[2])
	if torso_length_m <= 0.0 or torso_height_m <= 0.0 or torso_width_m <= 0.0:
		return _failure("MORPHOLOGY_FEATURE_TORSO_DIMENSION_INVALID")
	var torso_mass_kg := float(torso["mass_kg"])
	var limbs: Array = fixture["limbs"]
	if limbs.size() != FixtureSpecScript.REFERENCE_LIMB_IDS.size():
		return _failure("MORPHOLOGY_FEATURE_TOPOLOGY_INVALID")

	var ordered_limb_ids: Array = []
	var longitudinal_hip_half_extent_m := 0.0
	var lateral_hip_half_extent_m := 0.0
	var total_mass_kg := torso_mass_kg
	var front_limb_mass_kg := 0.0
	var rear_limb_mass_kg := 0.0
	var weighted_projected_com_xz_kg_m := Vector2.ZERO
	var upper_length_m := NAN
	var lower_length_m := NAN
	var foot_radius_m := NAN
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var limb_id := String(limb["limb_id"])
		ordered_limb_ids.append(limb_id)
		var offset: Array = limb["hip_offset_from_torso_center_m"]
		var hip_x_m := float(offset[0])
		var hip_z_m := float(offset[2])
		longitudinal_hip_half_extent_m = maxf(longitudinal_hip_half_extent_m, absf(hip_x_m))
		lateral_hip_half_extent_m = maxf(lateral_hip_half_extent_m, absf(hip_z_m))
		var limb_mass_kg := float(limb["upper_mass_kg"]) + float(limb["distal_mass_kg"])
		total_mass_kg += limb_mass_kg
		weighted_projected_com_xz_kg_m += limb_mass_kg * Vector2(hip_x_m, hip_z_m)
		if limb_id.begins_with("front_"):
			front_limb_mass_kg += limb_mass_kg
		else:
			rear_limb_mass_kg += limb_mass_kg
		if not is_finite(upper_length_m):
			upper_length_m = float(limb["upper_length_m"])
			lower_length_m = float(limb["lower_length_m"])
			foot_radius_m = float(limb["foot_radius_m"])
		elif (
			not is_equal_approx(upper_length_m, float(limb["upper_length_m"]))
			or not is_equal_approx(lower_length_m, float(limb["lower_length_m"]))
			or not is_equal_approx(foot_radius_m, float(limb["foot_radius_m"]))
		):
			return _failure("MORPHOLOGY_FEATURE_LIMB_GEOMETRY_ASYMMETRIC")
	if ordered_limb_ids != FixtureSpecScript.REFERENCE_LIMB_IDS:
		return _failure("MORPHOLOGY_FEATURE_LIMB_ORDER_INVALID")
	if total_mass_kg <= 0.0:
		return _failure("MORPHOLOGY_FEATURE_TOTAL_MASS_INVALID")
	var projected_com_xz_m := weighted_projected_com_xz_kg_m / total_mass_kg
	var static_screen: Dictionary = proportion_compile_result.get("static_screen", {})
	var support_extents: Array = static_screen.get("support_half_extents_xz_m", [])
	if support_extents.size() != 2:
		return _failure("MORPHOLOGY_FEATURE_SUPPORT_EXTENTS_INVALID")
	var longitudinal_support_half_extent_m := float(support_extents[0])
	var lateral_support_half_extent_m := float(support_extents[1])
	var nominal_support_margin_m := float(
		static_screen.get("minimum_support_polygon_margin_m", NAN)
	)

	var yaw_inertia_kg_m2 := (
		torso_mass_kg * (torso_length_m * torso_length_m + torso_width_m * torso_width_m)
		/ 12.0
	)
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var offset: Array = limb["hip_offset_from_torso_center_m"]
		var center_xz := Vector2(float(offset[0]), float(offset[2]))
		var upper_mass_kg := float(limb["upper_mass_kg"])
		var distal_mass_kg := float(limb["distal_mass_kg"])
		var cross_section: Array = limb["upper_cross_section_m"]
		var upper_intrinsic_yaw_inertia := (
			upper_mass_kg
			* (
				float(cross_section[0]) * float(cross_section[0])
				+ float(cross_section[1]) * float(cross_section[1])
			)
			/ 12.0
		)
		var foot_intrinsic_yaw_inertia := (
			0.4 * distal_mass_kg * float(limb["foot_radius_m"]) * float(limb["foot_radius_m"])
		)
		yaw_inertia_kg_m2 += (
			upper_intrinsic_yaw_inertia
			+ foot_intrinsic_yaw_inertia
			+ (upper_mass_kg + distal_mass_kg) * center_xz.distance_squared_to(projected_com_xz_m)
		)

	var motor_impulses: Dictionary = fixture["motor_impulses"]
	var body_weight_n := total_mass_kg * GRAVITY_M_S2
	var total_leg_reach_m := upper_length_m + lower_length_m
	var feature_policy_id := (
		GQ15_POLICY_ID
		if campaign_id == ProportionSpecScript.CAMPAIGN_GQ15
		else (
			GQ14_POLICY_ID
			if campaign_id == ProportionSpecScript.CAMPAIGN_GQ14
			else POLICY_ID
		)
	)
	var feature_policy_digest := CanonicalJsonScript.sha256({"policy_id": feature_policy_id})
	var feature_schema_digest := CanonicalJsonScript.sha256({"schema_version": SCHEMA_VERSION})
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"policy_id": feature_policy_id,
		"campaign_id": campaign_id,
		"morphology_id": String(proportion_spec["morphology_id"]),
		"generator_index_dimensionless": int(generator_receipt["generator_index"]),
		"campaign_role": String(generator_receipt["campaign_role"]),
		"shell_fraction_dimensionless": float(generator_receipt["shell_fraction"]),
		"axis_order": AXIS_ORDER.duplicate(),
		"ordered_axis_samples": ordered_axis_samples,
		"ordered_signed_centered_coordinates_dimensionless": ordered_signed_coordinates,
		"ordered_realized_scales_dimensionless": ordered_realized_scales,
		"topology":
		{
			"family_id": TOPOLOGY_FAMILY_ID,
			"ordered_limb_count_dimensionless": limbs.size(),
			"ordered_limb_ids": ordered_limb_ids,
		},
		"geometry":
		{
			"torso_dimensions_m": [torso_length_m, torso_height_m, torso_width_m],
			"torso_length_to_width_aspect_ratio_dimensionless":
			torso_length_m / torso_width_m,
			"longitudinal_hip_half_extent_m": longitudinal_hip_half_extent_m,
			"lateral_hip_half_extent_m": lateral_hip_half_extent_m,
			"longitudinal_nominal_support_half_extent_m":
			longitudinal_support_half_extent_m,
			"lateral_nominal_support_half_extent_m": lateral_support_half_extent_m,
			"nominal_support_length_to_width_aspect_ratio_dimensionless":
			longitudinal_support_half_extent_m / lateral_support_half_extent_m,
			"upper_leg_length_m": upper_length_m,
			"lower_leg_length_m": lower_length_m,
			"total_leg_reach_m": total_leg_reach_m,
			"foot_radius_m": foot_radius_m,
			"foot_radius_to_leg_reach_ratio_dimensionless":
			foot_radius_m / total_leg_reach_m,
		},
		"mass_properties":
		{
			"total_mass_kg": total_mass_kg,
			"torso_mass_kg": torso_mass_kg,
			"torso_mass_ratio_dimensionless": torso_mass_kg / total_mass_kg,
			"front_limb_mass_total_kg": front_limb_mass_kg,
			"rear_limb_mass_total_kg": rear_limb_mass_kg,
			"signed_front_minus_rear_mass_imbalance_kg":
			front_limb_mass_kg - rear_limb_mass_kg,
			"signed_front_minus_rear_mass_imbalance_ratio_dimensionless":
			(front_limb_mass_kg - rear_limb_mass_kg) / total_mass_kg,
			"projected_nominal_center_of_mass_xz_m":
			[projected_com_xz_m.x, projected_com_xz_m.y],
			"nominal_support_margin_m": nominal_support_margin_m,
			"approximate_nominal_yaw_inertia_kg_m2": yaw_inertia_kg_m2,
			"yaw_inertia_over_mass_torso_length_squared_dimensionless":
			yaw_inertia_kg_m2 / (total_mass_kg * torso_length_m * torso_length_m),
		},
		"actuator_authority":
		{
			"body_weight_n": body_weight_n,
			"hip_declared_lever_arm_m": total_leg_reach_m,
			"knee_declared_lever_arm_m": lower_length_m,
			"hip_max_angular_impulse_n_m_s":
			float(motor_impulses["hip_max_impulse_nms"]),
			"knee_base_max_angular_impulse_n_m_s":
			float(motor_impulses["knee_base_max_impulse_nms"]),
			"hip_impulse_over_body_weight_lever_arm_s":
			float(motor_impulses["hip_max_impulse_nms"])
			/ (body_weight_n * total_leg_reach_m),
			"knee_impulse_over_body_weight_lever_arm_s":
			float(motor_impulses["knee_base_max_impulse_nms"])
			/ (body_weight_n * lower_length_m),
		},
		"source_digests":
		{
			"fixture_spec_sha256": fixture_digest,
			"controller_configuration_sha256": controller_configuration_sha256,
			"clock_configuration_sha256": CanonicalJsonScript.sha256(clock_options),
			"solver_configuration_sha256": CanonicalJsonScript.sha256(solver_options),
			"generator_receipt_sha256": generator_digest,
			"feature_policy_sha256": feature_policy_digest,
			"feature_schema_sha256": feature_schema_digest,
		},
		"policy_response": "REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY",
		"world_build_count": 0,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"automatic_creature_guidance_allowed": false,
	}
	var finite_report := FiniteSanitizerScript.inspect(receipt)
	if not bool(finite_report.get("ok", false)):
		return _failure("MORPHOLOGY_FEATURE_RECEIPT_NONFINITE")
	return {
		"ok": true,
		"failure_code": "",
		"feature_receipt": receipt,
		"feature_receipt_sha256": CanonicalJsonScript.sha256(receipt),
		"world_build_count": 0,
	}


static func verify(
	generation_result: Dictionary,
	proportion_compile_result: Dictionary,
	controller_configuration_sha256: String,
	clock_options: Dictionary,
	solver_options: Dictionary,
	expected_feature_receipt_sha256: String,
) -> Dictionary:
	var result := compile(
		generation_result,
		proportion_compile_result,
		controller_configuration_sha256,
		clock_options,
		solver_options,
	)
	if not bool(result.get("ok", false)):
		return result
	if (
		not _digest_valid(expected_feature_receipt_sha256)
		or String(result["feature_receipt_sha256"]) != expected_feature_receipt_sha256
	):
		return _failure("MORPHOLOGY_FEATURE_RECEIPT_DIGEST_MISMATCH")
	return result


static func _digest_valid(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"world_build_count": 0,
	}
