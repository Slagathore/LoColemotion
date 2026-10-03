extends RefCounted

## Independent Godot/Jolt GDScript zero-world mirror of the frozen R23D13 law.
## This source contains no world, controller, selector, heading command, or
## outcome input and does not preload the Python stage-zero reference oracle.

const GATE_ID := "QSDK-R23D13"
const CAMPAIGN_ID := (
	"QSDK-R23D13-RESIDUAL-POSE-AUTHORITY-QUIESCENT-TAPER-" +
	"BILATERAL-TURN-DEVELOPMENT"
)
const POLICY_ID := "sporespore_residual_pose_authority_quiescent_taper_v1"
const ENGINE_ID := "godot_jolt"

const ACTIVE_MODE := "active_neutral_acquisition"
const TAPER_MODE := "active_quiescent_taper"
const PASSIVE_MODE := "irreversible_zero_actuation_stability"
const ACTUATOR_COUNT := 8
const SCALE_DENOMINATOR := 120
const TIGHT_MAXIMUM_TILT_RAD := 0.01
const COARSE_MAXIMUM_TILT_RAD := 0.035
const TIGHT_MAXIMUM_JOINT_ERROR_RAD := 0.2
const COARSE_MAXIMUM_JOINT_ERROR_RAD := 0.32
const MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S := 0.425
const NUMERICAL_CEILING_TOLERANCE := 1.0e-12

const EXPECTED_MUTATION_CODES := [
	"R23D13_CONTACT_SHAPE_INVALID",
	"R23D13_CONTACT_TYPE_INVALID",
	"R23D13_POSE_MEASUREMENT_INVALID",
	"R23D13_POSE_MEASUREMENT_INVALID",
	"R23D13_POSE_MEASUREMENT_INVALID",
	"R23D13_POSE_MEASUREMENT_INVALID",
	"R23D13_MODE_INVALID",
	"R23D13_TEMPORAL_FRACTION_INVALID",
	"R23D13_TEMPORAL_FRACTION_INVALID",
	"R23D13_TEMPORAL_FRACTION_INVALID",
	"R23D13_TEMPORAL_FRACTION_INVALID",
	"R23D13_TEMPORAL_FRACTION_INVALID",
	"R23D13_TEMPORAL_FRACTION_INVALID",
	"R23D13_TEMPORAL_FRACTION_INVALID",
	"R23D13_ACTUATOR_ORDER_INVALID",
	"R23D13_ACTUATOR_ORDER_INVALID",
	"R23D13_PRE_TAPER_VELOCITY_COUNT_INVALID",
	"R23D13_ACTIVE_VELOCITY_INVALID",
	"R23D13_ACTIVE_VELOCITY_OUTSIDE_BOUND",
	"R23D13_PASSIVE_PRE_TAPER_VELOCITY_PRESENT",
]


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}


static func _finite_number(value: Variant) -> bool:
	var value_type := typeof(value)
	return (
		(value_type == TYPE_INT or value_type == TYPE_FLOAT) and
		is_finite(float(value))
	)


static func _channel_floor(value: float, tight: float, coarse: float) -> int:
	var normalized := clampf((value - tight) / (coarse - tight), 0.0, 1.0)
	return int(ceil(float(SCALE_DENOMINATOR) * normalized - NUMERICAL_CEILING_TOLERANCE))


static func pose_authority_floor(value: Dictionary) -> Dictionary:
	var contacts: Variant = value.get("contacts", null)
	if typeof(contacts) != TYPE_ARRAY or contacts.size() != 4:
		return _failure("R23D13_CONTACT_SHAPE_INVALID")
	var all_four := true
	for contact: Variant in contacts:
		if typeof(contact) != TYPE_BOOL:
			return _failure("R23D13_CONTACT_TYPE_INVALID")
		all_four = all_four and bool(contact)

	var torso_tilt: Variant = value.get("torso_tilt_rad", null)
	var joint_error: Variant = value.get(
		"maximum_absolute_joint_position_error_rad", null
	)
	if (
		not _finite_number(torso_tilt) or float(torso_tilt) < 0.0 or
		not _finite_number(joint_error) or float(joint_error) < 0.0
	):
		return _failure("R23D13_POSE_MEASUREMENT_INVALID")

	if not all_four:
		return {
			"ok": true,
			"tilt_floor_numerator": 0,
			"joint_error_floor_numerator": 0,
			"pose_authority_floor_numerator": SCALE_DENOMINATOR,
			"controlling_input": "incomplete_support_full_authority",
			"all_four_contacts": false,
		}
	var tilt := _channel_floor(
		float(torso_tilt), TIGHT_MAXIMUM_TILT_RAD, COARSE_MAXIMUM_TILT_RAD
	)
	var joint := _channel_floor(
		float(joint_error),
		TIGHT_MAXIMUM_JOINT_ERROR_RAD,
		COARSE_MAXIMUM_JOINT_ERROR_RAD
	)
	var floor_numerator: int = maxi(1, maxi(tilt, joint))
	var controlling := "equal_pose_channels"
	if tilt > joint:
		controlling = "torso_tilt"
	elif joint > tilt:
		controlling = "maximum_joint_position_error"
	elif floor_numerator == 1:
		controlling = "tight_pose_minimum"
	return {
		"ok": true,
		"tilt_floor_numerator": tilt,
		"joint_error_floor_numerator": joint,
		"pose_authority_floor_numerator": floor_numerator,
		"controlling_input": controlling,
		"all_four_contacts": true,
	}


static func apply_residual_pose_authority(value: Dictionary) -> Dictionary:
	var floor_receipt := pose_authority_floor(value)
	if not bool(floor_receipt.get("ok", false)):
		return floor_receipt
	var mode := String(value.get("mode", ""))
	if not [ACTIVE_MODE, TAPER_MODE, PASSIVE_MODE].has(mode):
		return _failure("R23D13_MODE_INVALID")
	var numerator: Variant = value.get("temporal_scale_numerator", null)
	var denominator: Variant = value.get("temporal_scale_denominator", null)
	if (
		typeof(numerator) != TYPE_INT or typeof(denominator) != TYPE_INT or
		int(denominator) != SCALE_DENOMINATOR
	):
		return _failure("R23D13_TEMPORAL_FRACTION_INVALID")
	var temporal_valid: bool = (
		(mode == ACTIVE_MODE and int(numerator) == SCALE_DENOMINATOR) or
		(mode == TAPER_MODE and int(numerator) >= 1 and int(numerator) <= SCALE_DENOMINATOR) or
		(mode == PASSIVE_MODE and int(numerator) == 0)
	)
	if not temporal_valid:
		return _failure("R23D13_TEMPORAL_FRACTION_INVALID")

	var actuator_ids: Variant = value.get("actuator_ids", null)
	if typeof(actuator_ids) != TYPE_ARRAY or actuator_ids.size() != ACTUATOR_COUNT:
		return _failure("R23D13_ACTUATOR_ORDER_INVALID")
	var unique := {}
	for actuator_id: Variant in actuator_ids:
		if typeof(actuator_id) != TYPE_STRING or String(actuator_id).is_empty():
			return _failure("R23D13_ACTUATOR_ORDER_INVALID")
		unique[String(actuator_id)] = true
	if unique.size() != ACTUATOR_COUNT:
		return _failure("R23D13_ACTUATOR_ORDER_INVALID")

	var velocities: Variant = value.get("combined_pre_taper_velocities_rad_s", null)
	if typeof(velocities) != TYPE_ARRAY or velocities.size() != ACTUATOR_COUNT:
		return _failure("R23D13_PRE_TAPER_VELOCITY_COUNT_INVALID")
	if mode == PASSIVE_MODE:
		for item: Variant in velocities:
			if item != null:
				return _failure("R23D13_PASSIVE_PRE_TAPER_VELOCITY_PRESENT")
		var zeros: Array[float] = []
		zeros.resize(ACTUATOR_COUNT)
		zeros.fill(0.0)
		return {
			"ok": true,
			"pose_authority_floor_numerator": 0,
			"temporal_scale_numerator": 0,
			"applied_scale_numerator": 0,
			"final_canonical_velocities_rad_s": zeros,
			"residual_pose_recovery_invoked": false,
		}

	var numeric: Array[float] = []
	for item: Variant in velocities:
		if not _finite_number(item):
			return _failure("R23D13_ACTIVE_VELOCITY_INVALID")
		var number := float(item)
		if absf(number) > MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S:
			return _failure("R23D13_ACTIVE_VELOCITY_OUTSIDE_BOUND")
		numeric.append(number)
	var floor_numerator := int(floor_receipt["pose_authority_floor_numerator"])
	var applied := maxi(int(numerator), floor_numerator)
	var scale := float(applied) / float(SCALE_DENOMINATOR)
	var output: Array[float] = []
	for item in numeric:
		output.append(item * scale)
	return {
		"ok": true,
		"pose_authority_floor_numerator": floor_numerator,
		"temporal_scale_numerator": int(numerator),
		"applied_scale_numerator": applied,
		"final_canonical_velocities_rad_s": output,
		"residual_pose_recovery_invoked": true,
	}


static func _baseline() -> Dictionary:
	var actuator_ids: Array = []
	for index in range(ACTUATOR_COUNT):
		actuator_ids.append("actuator_%d" % index)
	return {
		"mode": TAPER_MODE,
		"temporal_scale_numerator": 2,
		"temporal_scale_denominator": 120,
		"contacts": [true, true, true, true],
		"torso_tilt_rad": 0.005,
		"maximum_absolute_joint_position_error_rad": 0.1,
		"actuator_ids": actuator_ids,
		"combined_pre_taper_velocities_rad_s": [
			0.2, -0.1, 0.3, -0.2, 0.1, -0.3, 0.4, -0.4,
		],
	}


static func _floor_line(label: String, receipt: Dictionary) -> String:
	return "%s|%d|%d|%d|%s" % [
		label,
		int(receipt["tilt_floor_numerator"]),
		int(receipt["joint_error_floor_numerator"]),
		int(receipt["pose_authority_floor_numerator"]),
		String(receipt["controlling_input"]),
	]


static func _canary_context() -> Dictionary:
	var base := _baseline()
	var halfway_tilt := base.duplicate(true)
	halfway_tilt["torso_tilt_rad"] = 0.0225
	var halfway_joint := base.duplicate(true)
	halfway_joint["maximum_absolute_joint_position_error_rad"] = 0.26
	var joint_dominant := base.duplicate(true)
	joint_dominant["torso_tilt_rad"] = 0.015
	joint_dominant["maximum_absolute_joint_position_error_rad"] = 0.29
	var incomplete := base.duplicate(true)
	incomplete["contacts"] = [true, true, false, true]
	var tight_floor := pose_authority_floor(base)
	var halfway_tilt_floor := pose_authority_floor(halfway_tilt)
	var halfway_joint_floor := pose_authority_floor(halfway_joint)
	var joint_dominant_floor := pose_authority_floor(joint_dominant)
	var incomplete_floor := pose_authority_floor(incomplete)

	var active_input := base.duplicate(true)
	active_input["mode"] = ACTIVE_MODE
	active_input["temporal_scale_numerator"] = 120
	var active := apply_residual_pose_authority(active_input)
	var negative_best := base.duplicate(true)
	negative_best["torso_tilt_rad"] = 0.02039827933466296
	negative_best["maximum_absolute_joint_position_error_rad"] = 0.2375508558310486
	var raised := apply_residual_pose_authority(negative_best)
	var temporal_input := negative_best.duplicate(true)
	temporal_input["temporal_scale_numerator"] = 100
	var temporal := apply_residual_pose_authority(temporal_input)
	var negative_final := base.duplicate(true)
	negative_final["torso_tilt_rad"] = 0.027166660831829642
	negative_final["maximum_absolute_joint_position_error_rad"] = 0.2706423272295883
	var negative_final_floor := pose_authority_floor(negative_final)
	var passive_input := negative_final.duplicate(true)
	passive_input["mode"] = PASSIVE_MODE
	passive_input["temporal_scale_numerator"] = 0
	var nulls: Array = []
	nulls.resize(ACTUATOR_COUNT)
	nulls.fill(null)
	passive_input["combined_pre_taper_velocities_rad_s"] = nulls
	var passive := apply_residual_pose_authority(passive_input)

	var lines := PackedStringArray([
		_floor_line("tight", tight_floor),
		_floor_line("halfway_tilt", halfway_tilt_floor),
		_floor_line("halfway_joint", halfway_joint_floor),
		_floor_line("joint_dominant", joint_dominant_floor),
		_floor_line("incomplete", incomplete_floor),
		"active|%d|120|%d" % [
			int(active["pose_authority_floor_numerator"]),
			int(active["applied_scale_numerator"]),
		],
		"raised|%d|2|%d" % [
			int(raised["pose_authority_floor_numerator"]),
			int(raised["applied_scale_numerator"]),
		],
		"temporal_dominant|%d|100|%d" % [
			int(temporal["pose_authority_floor_numerator"]),
			int(temporal["applied_scale_numerator"]),
		],
		_floor_line("negative_final", negative_final_floor),
		"passive|%d|0|%d" % [
			int(passive["pose_authority_floor_numerator"]),
			int(passive["applied_scale_numerator"]),
		],
	])
	return {
		"vector": "\n".join(lines),
		"base": base,
		"tight_floor": tight_floor,
		"active": active,
		"raised": raised,
		"negative_final_floor": negative_final_floor,
		"passive": passive,
	}


static func _mutations() -> Array:
	var base := _baseline()
	var rows: Array = []
	var row := base.duplicate(true)
	row["contacts"] = [true, true, true]
	rows.append(row)
	row = base.duplicate(true)
	row["contacts"] = [true, true, true, 1]
	rows.append(row)
	row = base.duplicate(true)
	row["torso_tilt_rad"] = NAN
	rows.append(row)
	row = base.duplicate(true)
	row["torso_tilt_rad"] = -0.001
	rows.append(row)
	row = base.duplicate(true)
	row["maximum_absolute_joint_position_error_rad"] = INF
	rows.append(row)
	row = base.duplicate(true)
	row["maximum_absolute_joint_position_error_rad"] = -0.001
	rows.append(row)
	row = base.duplicate(true)
	row["mode"] = "negative_heading_recovery"
	rows.append(row)
	row = base.duplicate(true)
	row["mode"] = ACTIVE_MODE
	row["temporal_scale_numerator"] = 119
	rows.append(row)
	row = base.duplicate(true)
	row["temporal_scale_numerator"] = 0
	rows.append(row)
	row = base.duplicate(true)
	row["temporal_scale_numerator"] = 121
	rows.append(row)
	row = base.duplicate(true)
	row["temporal_scale_numerator"] = true
	rows.append(row)
	row = base.duplicate(true)
	row["temporal_scale_denominator"] = 119
	rows.append(row)
	row = base.duplicate(true)
	row["temporal_scale_denominator"] = true
	rows.append(row)
	row = base.duplicate(true)
	row["mode"] = PASSIVE_MODE
	row["temporal_scale_numerator"] = 1
	var nulls: Array = []
	nulls.resize(ACTUATOR_COUNT)
	nulls.fill(null)
	row["combined_pre_taper_velocities_rad_s"] = nulls
	rows.append(row)
	row = base.duplicate(true)
	row["actuator_ids"] = row["actuator_ids"].slice(0, 7)
	rows.append(row)
	row = base.duplicate(true)
	var duplicate_ids: Array = row["actuator_ids"].duplicate()
	duplicate_ids[7] = duplicate_ids[0]
	row["actuator_ids"] = duplicate_ids
	rows.append(row)
	row = base.duplicate(true)
	row["combined_pre_taper_velocities_rad_s"] = (
		row["combined_pre_taper_velocities_rad_s"].slice(0, 7)
	)
	rows.append(row)
	row = base.duplicate(true)
	var invalid_velocities: Array = row["combined_pre_taper_velocities_rad_s"].duplicate()
	invalid_velocities[0] = NAN
	row["combined_pre_taper_velocities_rad_s"] = invalid_velocities
	rows.append(row)
	row = base.duplicate(true)
	invalid_velocities = row["combined_pre_taper_velocities_rad_s"].duplicate()
	invalid_velocities[0] = 0.426
	row["combined_pre_taper_velocities_rad_s"] = invalid_velocities
	rows.append(row)
	row = base.duplicate(true)
	row["mode"] = PASSIVE_MODE
	row["temporal_scale_numerator"] = 0
	var zeros: Array = []
	zeros.resize(ACTUATOR_COUNT)
	zeros.fill(0.0)
	row["combined_pre_taper_velocities_rad_s"] = zeros
	rows.append(row)
	return rows


static func preflight() -> Dictionary:
	var context := _canary_context()
	var mutation_codes: Array[String] = []
	for mutation in _mutations():
		var result := apply_residual_pose_authority(mutation)
		if bool(result.get("ok", false)):
			return _failure("R23D13_MUTATION_UNEXPECTEDLY_ACCEPTED")
		mutation_codes.append(String(result.get("failure_code", "")))
	if mutation_codes != EXPECTED_MUTATION_CODES:
		return _failure("R23D13_MUTATION_FAILURE_CODES_CHANGED")

	var active: Dictionary = context["active"]
	var source: Array = context["base"]["combined_pre_taper_velocities_rad_s"]
	var output: Array = active["final_canonical_velocities_rad_s"]
	var positive_regression: bool = (
		int(context["tight_floor"]["pose_authority_floor_numerator"]) == 1
	)
	for index in range(ACTUATOR_COUNT):
		positive_regression = positive_regression and is_equal_approx(
			float(output[index]), float(source[index])
		)
	var raised: Dictionary = context["raised"]
	var critical: bool = (
		int(raised["pose_authority_floor_numerator"]) == 50 and
		int(raised["applied_scale_numerator"]) == 50 and
		int(context["negative_final_floor"]["pose_authority_floor_numerator"]) == 83
	)
	var passive: Dictionary = context["passive"]
	var passive_zero: bool = (
		int(passive["applied_scale_numerator"]) == 0 and
		not bool(passive["residual_pose_recovery_invoked"])
	)
	for item in passive["final_canonical_velocities_rad_s"]:
		passive_zero = passive_zero and float(item) == 0.0
	if not (positive_regression and critical and passive_zero):
		return _failure("R23D13_NATIVE_CANARY_FAILED")

	return {
		"ok": true,
		"schema_version": "sporespore_qsdk_r23d13_native_authority_preflight_v1",
		"gate_id": GATE_ID,
		"campaign_id": CAMPAIGN_ID,
		"policy_id": POLICY_ID,
		"engine_id": ENGINE_ID,
		"language": "gdscript",
		"valid_canary_count": 10,
		"mutation_control_count": mutation_codes.size(),
		"valid_canary_vector": String(context["vector"]),
		"mutation_failure_codes": mutation_codes,
		"critical_r23d12_negative_shape_passed": critical,
		"positive_tight_pose_no_regression_canary_passed": positive_regression,
		"passive_exact_zero_actuation_canary_passed": passive_zero,
		"reference_oracle_imported": false,
		"physical_worker_implemented": false,
		"physical_execution_authorized": false,
		"physical_process_launch_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
