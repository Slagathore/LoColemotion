extends RefCounted

## Fail-closed physical gait-clock compiler.
##
## The empty request preserves the established 120 Hz, 360-tick controller.
## Dynamic similarity is a separate policy and cannot mutate that default.

const REFERENCE_POLICY_ID := "reference_fixed_clock_v1"
const DYNAMIC_SIMILARITY_POLICY_ID := "uniform_scale_dynamic_similarity_clock_v1"
const GQ6_POLICY_ID := "g4_gq6_four_cycle_contact_clock_v1"
const GQ7_POLICY_ID := "g4_gq7_four_cycle_contact_clock_v1"
const GQ8_POLICY_ID := "g4_gq8_four_cycle_contact_clock_v1"
const GQ9_POLICY_ID := "g4_gq9_four_cycle_contact_clock_v1"
const GQ10_POLICY_ID := "g4_gq10_four_cycle_contact_clock_v1"
const GQ11_POLICY_ID := "g4_gq11_four_cycle_contact_clock_v1"
const GQ12_POLICY_ID := "g4_gq12_four_cycle_contact_clock_v1"
const GQ13_POLICY_ID := "g4_gq13_four_cycle_contact_clock_v1"
const GQ14_POLICY_ID := "g4_gq14_four_cycle_contact_clock_v1"
const GQ15_POLICY_ID := "g4_gq15_four_cycle_contact_clock_v1"
# GS3 is preregistered only as an upper extension through s = 1.150. A later
# campaign must deliberately widen this range instead of silently borrowing
# authority from the more general fixture compiler.
const MINIMUM_UNIFORM_SCALE := 1.0
const MAXIMUM_UNIFORM_SCALE := 1.15
const CLOCK_KEYS := [
	"policy_id",
	"uniform_scale",
	"time_scale",
	"physics_hz",
	"cycle_ticks",
	"swing_ticks",
	"settle_ticks",
	"terminal_settle_ticks",
	"warmup_cycles",
	"evidence_cycles",
	"cooldown_cycles",
	"evidence_boundary_alignment_ticks",
	"maximum_contact_gated_evidence_extension_ticks",
	"maximum_contact_gate_hold_ticks",
	"maximum_contact_gated_phase_skew_ticks",
	"steering_update_interval_ticks",
	"minimum_airborne_dwell_ticks",
	"motor_position_gain_per_s",
	"motor_rate_damping",
	"maximum_motor_target_speed_rad_s",
]


static func reference_clock() -> Dictionary:
	return {
		"policy_id": REFERENCE_POLICY_ID,
		"uniform_scale": 1.0,
		"time_scale": 1.0,
		"physics_hz": 120,
		"cycle_ticks": 360,
		"swing_ticks": 72,
		"settle_ticks": 240,
		"terminal_settle_ticks": 240,
		"warmup_cycles": 1,
		"evidence_cycles": 3,
		"cooldown_cycles": 1,
		"evidence_boundary_alignment_ticks": 112,
		"maximum_contact_gated_evidence_extension_ticks": 720,
		"maximum_contact_gate_hold_ticks": 96,
		"maximum_contact_gated_phase_skew_ticks": 12,
		"steering_update_interval_ticks": 90,
		"minimum_airborne_dwell_ticks": 3,
		"motor_position_gain_per_s": 8.0,
		"motor_rate_damping": 0.65,
		"maximum_motor_target_speed_rad_s": 3.5,
	}


static func dynamic_similarity_clock(scale_value: Variant) -> Dictionary:
	var scale_result := _positive_finite_number(scale_value, "uniform_scale")
	if not bool(scale_result.get("ok", false)):
		return scale_result
	var uniform_scale := float(scale_result["value"])
	if uniform_scale < MINIMUM_UNIFORM_SCALE or uniform_scale > MAXIMUM_UNIFORM_SCALE:
		return _failure("UNIFORM_SCALE_OUT_OF_RANGE", "uniform_scale")
	var time_scale := sqrt(uniform_scale)
	var requested := _dynamic_clock_values(uniform_scale)
	var compiled := compile(requested)
	if not bool(compiled.get("ok", false)):
		return compiled
	return {
		"ok": true,
		"uniform_scale": uniform_scale,
		"time_scale": time_scale,
		"gait_clock_options": (compiled["gait_clock_options"] as Dictionary).duplicate(true),
		"world_build_count": 0,
	}


static func gq6_clock() -> Dictionary:
	var clock := reference_clock()
	clock["policy_id"] = GQ6_POLICY_ID
	clock["evidence_cycles"] = 4
	clock["maximum_contact_gate_hold_ticks"] = 120
	return clock


static func gq7_clock() -> Dictionary:
	var clock := reference_clock()
	clock["policy_id"] = GQ7_POLICY_ID
	clock["evidence_cycles"] = 4
	clock["maximum_contact_gate_hold_ticks"] = 120
	return clock


static func gq8_clock() -> Dictionary:
	var clock := reference_clock()
	clock["policy_id"] = GQ8_POLICY_ID
	clock["evidence_cycles"] = 4
	clock["maximum_contact_gate_hold_ticks"] = 120
	return clock


static func gq9_clock() -> Dictionary:
	var clock := reference_clock()
	clock["policy_id"] = GQ9_POLICY_ID
	clock["evidence_cycles"] = 4
	clock["maximum_contact_gate_hold_ticks"] = 120
	return clock


static func gq10_clock() -> Dictionary:
	var clock := reference_clock()
	clock["policy_id"] = GQ10_POLICY_ID
	clock["evidence_cycles"] = 4
	clock["maximum_contact_gate_hold_ticks"] = 120
	return clock


static func gq11_clock() -> Dictionary:
	var clock := reference_clock()
	clock["policy_id"] = GQ11_POLICY_ID
	clock["evidence_cycles"] = 4
	clock["maximum_contact_gate_hold_ticks"] = 120
	return clock


static func gq12_clock() -> Dictionary:
	var clock := reference_clock()
	clock["policy_id"] = GQ12_POLICY_ID
	clock["evidence_cycles"] = 4
	clock["maximum_contact_gate_hold_ticks"] = 120
	return clock


static func gq13_clock() -> Dictionary:
	var clock := reference_clock()
	clock["policy_id"] = GQ13_POLICY_ID
	clock["evidence_cycles"] = 4
	clock["maximum_contact_gate_hold_ticks"] = 120
	return clock


static func gq14_clock() -> Dictionary:
	var clock := reference_clock()
	clock["policy_id"] = GQ14_POLICY_ID
	clock["evidence_cycles"] = 4
	clock["maximum_contact_gate_hold_ticks"] = 120
	return clock


static func gq15_clock() -> Dictionary:
	var clock := reference_clock()
	clock["policy_id"] = GQ15_POLICY_ID
	clock["evidence_cycles"] = 4
	clock["maximum_contact_gate_hold_ticks"] = 120
	return clock


static func compile(requested: Dictionary = {}) -> Dictionary:
	var source := reference_clock() if requested.is_empty() else requested.duplicate(true)
	if not _has_exact_keys(source, CLOCK_KEYS):
		return _failure("INVALID_GAIT_CLOCK_KEYS", "gait_clock_options")
	if typeof(source["policy_id"]) != TYPE_STRING:
		return _failure("INVALID_GAIT_CLOCK_POLICY_ID", "policy_id")
	var policy_id := String(source["policy_id"])
	if (
		policy_id
		not in [
			REFERENCE_POLICY_ID,
			DYNAMIC_SIMILARITY_POLICY_ID,
			GQ6_POLICY_ID,
			GQ7_POLICY_ID,
			GQ8_POLICY_ID,
			GQ9_POLICY_ID,
			GQ10_POLICY_ID,
			GQ11_POLICY_ID,
			GQ12_POLICY_ID,
			GQ13_POLICY_ID,
			GQ14_POLICY_ID,
			GQ15_POLICY_ID,
		]
	):
		return _failure("UNKNOWN_GAIT_CLOCK_POLICY_ID", "policy_id")
	for key in [
		"uniform_scale",
		"time_scale",
		"motor_position_gain_per_s",
		"motor_rate_damping",
		"maximum_motor_target_speed_rad_s",
	]:
		var result := _positive_finite_number(source[key], key)
		if not bool(result.get("ok", false)):
			return result
		source[key] = float(result["value"])
	for key in [
		"physics_hz",
		"cycle_ticks",
		"swing_ticks",
		"settle_ticks",
		"terminal_settle_ticks",
		"warmup_cycles",
		"evidence_cycles",
		"cooldown_cycles",
		"evidence_boundary_alignment_ticks",
		"maximum_contact_gated_evidence_extension_ticks",
		"maximum_contact_gate_hold_ticks",
		"maximum_contact_gated_phase_skew_ticks",
		"steering_update_interval_ticks",
		"minimum_airborne_dwell_ticks",
	]:
		if typeof(source[key]) != TYPE_INT:
			return _failure("INVALID_GAIT_CLOCK_INTEGER", key)
	var cycle_ticks := int(source["cycle_ticks"])
	var swing_ticks := int(source["swing_ticks"])
	var expected_evidence_cycles := (
		4
		if (
			policy_id == GQ6_POLICY_ID
			or policy_id == GQ7_POLICY_ID
			or policy_id == GQ8_POLICY_ID
			or policy_id == GQ9_POLICY_ID
			or policy_id == GQ10_POLICY_ID
			or policy_id == GQ11_POLICY_ID
			or policy_id == GQ12_POLICY_ID
			or policy_id == GQ13_POLICY_ID
			or policy_id == GQ14_POLICY_ID
			or policy_id == GQ15_POLICY_ID
		)
		else 3
	)
	if (
		int(source["physics_hz"]) != 120
		or cycle_ticks < 4
		or cycle_ticks % 4 != 0
		or swing_ticks < 1
		or swing_ticks > cycle_ticks / 4
		or int(source["settle_ticks"]) < 1
		or int(source["terminal_settle_ticks"]) < 1
		or int(source["warmup_cycles"]) != 1
		or int(source["evidence_cycles"]) != expected_evidence_cycles
		or int(source["cooldown_cycles"]) != 1
		or int(source["evidence_boundary_alignment_ticks"]) < 0
		or int(source["evidence_boundary_alignment_ticks"]) >= cycle_ticks
		or int(source["maximum_contact_gated_evidence_extension_ticks"]) < cycle_ticks
		or int(source["maximum_contact_gate_hold_ticks"]) < 1
		or int(source["maximum_contact_gate_hold_ticks"]) > 120
		or int(source["maximum_contact_gated_phase_skew_ticks"]) < 0
		or int(source["maximum_contact_gated_phase_skew_ticks"]) > 90
		or int(source["steering_update_interval_ticks"]) < 1
		or int(source["minimum_airborne_dwell_ticks"]) < 1
		or int(source["minimum_airborne_dwell_ticks"]) > swing_ticks
		or float(source["motor_position_gain_per_s"]) > 16.0
		or float(source["motor_rate_damping"]) > 1.0
		or float(source["maximum_motor_target_speed_rad_s"]) > 3.5
	):
		return _failure("INVALID_GAIT_CLOCK_RELATION", "gait_clock_options")
	if (
		policy_id == DYNAMIC_SIMILARITY_POLICY_ID
		and (
			float(source["uniform_scale"]) < MINIMUM_UNIFORM_SCALE
			or float(source["uniform_scale"]) > MAXIMUM_UNIFORM_SCALE
		)
	):
		return _failure("UNIFORM_SCALE_OUT_OF_RANGE", "uniform_scale")
	var expected: Dictionary
	if policy_id == REFERENCE_POLICY_ID:
		expected = reference_clock()
	elif policy_id == GQ6_POLICY_ID:
		expected = gq6_clock()
	elif policy_id == GQ7_POLICY_ID:
		expected = gq7_clock()
	elif policy_id == GQ8_POLICY_ID:
		expected = gq8_clock()
	elif policy_id == GQ9_POLICY_ID:
		expected = gq9_clock()
	elif policy_id == GQ10_POLICY_ID:
		expected = gq10_clock()
	elif policy_id == GQ11_POLICY_ID:
		expected = gq11_clock()
	elif policy_id == GQ12_POLICY_ID:
		expected = gq12_clock()
	elif policy_id == GQ13_POLICY_ID:
		expected = gq13_clock()
	elif policy_id == GQ14_POLICY_ID:
		expected = gq14_clock()
	elif policy_id == GQ15_POLICY_ID:
		expected = gq15_clock()
	else:
		expected = _dynamic_clock_values(float(source["uniform_scale"]))
	if source != expected:
		return _failure("GAIT_CLOCK_POLICY_RECEIPT_MISMATCH", "gait_clock_options")
	return {
		"ok": true,
		"gait_clock_options": source,
		"world_build_count": 0,
	}


static func _dynamic_clock_values(uniform_scale: float) -> Dictionary:
	var time_scale := sqrt(uniform_scale)
	var quarter_cycle_ticks := _round_positive(90.0 * time_scale)
	var cycle_ticks := 4 * quarter_cycle_ticks
	return {
		"policy_id": DYNAMIC_SIMILARITY_POLICY_ID,
		"uniform_scale": uniform_scale,
		"time_scale": time_scale,
		"physics_hz": 120,
		"cycle_ticks": cycle_ticks,
		"swing_ticks": _round_positive(0.20 * float(cycle_ticks)),
		"settle_ticks": _round_positive(240.0 * time_scale),
		"terminal_settle_ticks": _round_positive(240.0 * time_scale),
		"warmup_cycles": 1,
		"evidence_cycles": 3,
		"cooldown_cycles": 1,
		"evidence_boundary_alignment_ticks": _round_positive((112.0 / 360.0) * float(cycle_ticks)),
		"maximum_contact_gated_evidence_extension_ticks": 2 * cycle_ticks,
		"maximum_contact_gate_hold_ticks": _round_positive((96.0 / 360.0) * float(cycle_ticks)),
		"maximum_contact_gated_phase_skew_ticks":
		_round_positive((12.0 / 360.0) * float(cycle_ticks)),
		"steering_update_interval_ticks": quarter_cycle_ticks,
		"minimum_airborne_dwell_ticks": _round_positive((3.0 / 360.0) * float(cycle_ticks)),
		"motor_position_gain_per_s": 8.0 / time_scale,
		"motor_rate_damping": 0.65,
		"maximum_motor_target_speed_rad_s": 3.5 / time_scale,
	}


static func _round_positive(value: float) -> int:
	return floori(value + 0.5)


static func _positive_finite_number(value: Variant, field: String) -> Dictionary:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return _failure("INVALID_POSITIVE_NUMBER", field)
	var number := float(value)
	if not is_finite(number) or number <= 0.0:
		return _failure("INVALID_POSITIVE_NUMBER", field)
	return {"ok": true, "value": number}


static func _has_exact_keys(source: Dictionary, expected_keys: Array) -> bool:
	if source.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not source.has(key):
			return false
	return true


static func _failure(code: String, field: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"failure_field": field,
		"world_build_count": 0,
	}
