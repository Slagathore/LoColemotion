extends SceneTree

## Independent no-world GDScript oracle for the branch-free balanced-wave
## profile. The oracle reconstructs the preregistered formulas directly and
## compares them to the real Rust GDExtension across the complete length axis.

const EXTENSION_PATH := (
	"res://sdk/adapters/godot/sporespore_locomotion.gdextension"
)
const CLASS_NAME := "SporeLocomotionSdk"
const SAMPLE_COUNT := 10_001
const ABSOLUTE_TOLERANCE := 1.0e-12
const POLICY_ID := "sporespore_balanced_wave_v1"
const PROFILE_VERSION := "sporespore_balanced_wave_profile_v1"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK balanced-wave independent profile oracle ===")
	var extension_resource := load(EXTENSION_PATH)
	_check(extension_resource != null, "the checked-in GDExtension resource loads")
	_check(ClassDB.class_exists(CLASS_NAME), "the native SDK class is registered")
	if not ClassDB.class_exists(CLASS_NAME):
		_finish(0, SAMPLE_COUNT)
		return
	var api: Object = ClassDB.instantiate(CLASS_NAME)
	_check(api != null, "the native SDK class instantiates")
	if api == null:
		_finish(0, SAMPLE_COUNT)
		return
	_check(
		api.has_method("balanced_wave_profile_json"),
		"the balanced-wave profile method is registered",
	)
	if not api.has_method("balanced_wave_profile_json"):
		_finish(0, SAMPLE_COUNT)
		return

	var matched_samples := 0
	var first_failure: Dictionary = {}
	var step := (1.10 - 0.90) / float(SAMPLE_COUNT - 1)
	for index in range(SAMPLE_COUNT):
		var length := 0.90 + float(index) * step
		var descriptor := _descriptor("balanced_wave_oracle_%05d" % index)
		descriptor["torso_length_scale"] = length
		var envelope := _call_input(api, "balanced_wave_profile_json", descriptor)
		var profile: Dictionary = envelope.get("value", {})
		var expected_heading_gain := 1.0 / length
		var expected_velocity_gain := 0.30 * sqrt(length)
		var matches := (
			bool(envelope.get("ok", false))
			and String(profile.get("schema_version", "")) == PROFILE_VERSION
			and String(profile.get("policy_id", "")) == POLICY_ID
			and absf(float(profile.get("torso_length_scale", NAN)) - length)
			<= ABSOLUTE_TOLERANCE
			and absf(
				float(profile.get("cross_track_heading_gain_rad_per_m", NAN))
				- expected_heading_gain
			)
			<= ABSOLUTE_TOLERANCE
			and float(profile.get("yaw_error_stride_gain_per_rad", NAN)) == 1.0
			and absf(
				float(
					profile.get(
						"cross_track_velocity_heading_gain_rad_per_m_s",
						NAN,
					)
				)
				- expected_velocity_gain
			)
			<= ABSOLUTE_TOLERANCE
			and int(
				profile.get(
					"contact_loaded_swing_knee_activation_start_phase_step",
					-1,
				)
			)
			== 0
			and float(
				profile.get(
					"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
					NAN,
				)
			)
			== 3.25
			and float(
				profile.get("anchor_error_guard_activation_fraction", NAN)
			)
			== 0.85
			and float(
				profile.get(
					"anchor_error_guard_maximum_motor_target_speed_rad_s",
					NAN,
				)
			)
			== 2.25
			and (profile.get("branch_surfaces", []) as Array).is_empty()
			and bool(profile.get("controller_authority", false))
			and not bool(profile.get("physical_acceptance_authority", true))
		)
		if matches:
			matched_samples += 1
		elif first_failure.is_empty():
			first_failure = {
				"index": index,
				"length": length,
				"expected_heading_gain": expected_heading_gain,
				"expected_velocity_gain": expected_velocity_gain,
				"envelope": envelope,
			}
	_check(
		matched_samples == SAMPLE_COUNT,
		"all 10,001 profile samples match the independent formulas within 1e-12",
	)
	if not first_failure.is_empty():
		print("  first sample failure: ", JSON.stringify(first_failure))

	var lower := _profile(api, _descriptor_with_length("balanced_lower", 0.90))
	var reference := _profile(api, _descriptor_with_length("balanced_reference", 1.0))
	var upper := _profile(api, _descriptor_with_length("balanced_upper", 1.10))
	_check(
		absf(float(lower.get("cross_track_heading_gain_rad_per_m", NAN)) - 1.0 / 0.90)
		<= ABSOLUTE_TOLERANCE
		and float(reference.get("cross_track_heading_gain_rad_per_m", NAN)) == 1.0
		and absf(float(upper.get("cross_track_heading_gain_rad_per_m", NAN)) - 1.0 / 1.10)
		<= ABSOLUTE_TOLERANCE,
		"lower, reference, and upper heading-gain boundaries are exact",
	)
	_check(
		absf(
			float(
				lower.get(
					"cross_track_velocity_heading_gain_rad_per_m_s",
					NAN,
				)
			)
			- 0.30 * sqrt(0.90)
		)
		<= ABSOLUTE_TOLERANCE
		and float(
			reference.get(
				"cross_track_velocity_heading_gain_rad_per_m_s",
				NAN,
			)
		)
		== 0.30
		and absf(
			float(
				upper.get(
					"cross_track_velocity_heading_gain_rad_per_m_s",
					NAN,
				)
			)
			- 0.30 * sqrt(1.10)
		)
		<= ABSOLUTE_TOLERANCE,
		"lower, reference, and upper velocity-gain boundaries are exact",
	)

	var other_axes_low := _descriptor_with_length("balanced_other_low", 1.0)
	other_axes_low["torso_width_scale"] = 0.90
	other_axes_low["upper_length_fraction"] = 0.48
	other_axes_low["hip_span_scale"] = 0.90
	other_axes_low["foot_radius_scale"] = 0.90
	other_axes_low["front_limb_mass_scale"] = 0.90
	var other_axes_high := _descriptor_with_length("balanced_other_high", 1.0)
	other_axes_high["torso_width_scale"] = 1.10
	other_axes_high["upper_length_fraction"] = 0.55
	other_axes_high["hip_span_scale"] = 1.10
	other_axes_high["foot_radius_scale"] = 1.10
	other_axes_high["front_limb_mass_scale"] = 1.10
	var low_profile := _profile(api, other_axes_low)
	var high_profile := _profile(api, other_axes_high)
	low_profile.erase("torso_length_scale")
	high_profile.erase("torso_length_scale")
	_check(
		low_profile == high_profile,
		"width, limb proportion, hip span, foot radius, and mass do not select branches",
	)

	var below_domain := _descriptor_with_length("balanced_below_domain", 0.899)
	var below_envelope := _call_input(api, "balanced_wave_profile_json", below_domain)
	_check(
		not bool(below_envelope.get("ok", true)),
		"out-of-domain length fails closed",
	)
	var unknown_field := _descriptor("balanced_unknown_field")
	unknown_field["cohort_selector"] = "forbidden"
	var unknown_envelope := _call_input(api, "balanced_wave_profile_json", unknown_field)
	_check(
		not bool(unknown_envelope.get("ok", true)),
		"unknown cohort selector fails closed",
	)
	_finish(matched_samples, SAMPLE_COUNT - matched_samples)


func _descriptor(morphology_id: String) -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": morphology_id,
		"torso_length_scale": 1.0,
		"torso_width_scale": 1.0,
		"upper_length_fraction": 18.0 / 35.0,
		"hip_span_scale": 1.0,
		"foot_radius_scale": 1.0,
		"front_limb_mass_scale": 1.0,
	}


func _descriptor_with_length(morphology_id: String, length: float) -> Dictionary:
	var descriptor := _descriptor(morphology_id)
	descriptor["torso_length_scale"] = length
	return descriptor


func _profile(api: Object, descriptor: Dictionary) -> Dictionary:
	var envelope := _call_input(api, "balanced_wave_profile_json", descriptor)
	return envelope.get("value", {}) if bool(envelope.get("ok", false)) else {}


func _call_input(api: Object, method: StringName, value: Dictionary) -> Dictionary:
	var response := String(
		api.call(method, JSON.stringify(value, "", true, true))
	)
	var parsed: Variant = JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish(matched_samples: int, failed_samples: int) -> void:
	print(
		"BALANCED_WAVE_PROFILE_SAMPLES passed=%d failed=%d"
		% [matched_samples, failed_samples]
	)
	print(
		"SDK balanced-wave profile summary: %d passed, %d failed"
		% [_passed, _failed]
	)
	quit(0 if _failed == 0 else 1)
