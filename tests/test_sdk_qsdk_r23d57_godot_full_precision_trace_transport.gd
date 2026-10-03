extends SceneTree
# gdlint: disable=max-line-length

## Zero-world Godot half of the R23D57 cross-runtime JSON float transport gate.
##
## This script intentionally emits both Godot's default float serialization and
## the prospective full-precision serialization for production-shaped actuator
## readback records. The Python half independently decodes both strings and
## applies the unchanged R23D56 self-consistency predicate. No node, model,
## fixture, controller, or physics world is created here.

const RECEIPT_SCHEMA := (
	"sporespore_qsdk_r23d57_godot_full_precision_trace_transport_receipt_v1"
)
const CONTRACT_ID := "QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-TRANSPORT"
const CONSISTENCY_TOLERANCE := 1.0e-15
const CONFIGURED_READBACK_TOLERANCE := 2.5e-7


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixtures := [
		_build_fixture(
			"retained_r23d56_first_failure_shape",
			-1.04273172492923,
			-1.04273176193237,
			0.0438760241238052,
			0.0438760258257389,
		),
		_build_fixture(
			"independent_positive_unit_scale",
			1.23456789012345,
			1.23456781111111,
			0.0314159265358979,
			0.0314159251234567,
		),
		_build_fixture(
			"independent_negative_fractional_scale",
			-0.314159265358979,
			-0.314159200000001,
			0.0876543210987654,
			0.0876543223456789,
		),
	]
	# The fixed family below is generated from declared constants rather than
	# selected from R23D56's observed maximum. It spans positive and negative
	# unit-scale operands whose small differences exercise cancellation after
	# default decimal shortening. Every generated application remains far inside
	# the unchanged configured-readback bound.
	for fixture_index in range(1, 33):
		var index_value := float(fixture_index)
		var applied := (
			sin(index_value * 0.731234567890123) * 1.75
			+ cos(index_value * 0.193827465019283) * 0.25
		)
		var target_delta := (
			(float((fixture_index * 37) % 197) + 1.0) * 1.0e-10
			+ absf(sin(index_value * 0.417263849102938)) * 1.0e-11
		)
		var declared_impulse := (
			0.02 + absf(sin(index_value * 0.284719305817463)) * 0.08
		)
		var impulse_delta := (
			(float((fixture_index * 29) % 113) + 1.0) * 1.0e-11
			+ absf(cos(index_value * 0.619284750192837)) * 1.0e-12
		)
		fixtures.append(
			_build_fixture(
				"deterministic_cancellation_%02d" % fixture_index,
				applied,
				applied + target_delta,
				declared_impulse,
				declared_impulse + impulse_delta,
			)
		)
	var receipt := {
		"schema_version": RECEIPT_SCHEMA,
		"contract_id": CONTRACT_ID,
		"godot_version": Engine.get_version_info(),
		"json_stringify_signature": (
			"JSON.stringify(data, indent=\"\", sort_keys=true, full_precision=false)"
		),
		"full_precision_argument_explicit": true,
		"full_precision_argument_value": true,
		"sort_keys_argument_value": true,
		"inherited_consistency_tolerance": CONSISTENCY_TOLERANCE,
		"configured_readback_tolerance": CONFIGURED_READBACK_TOLERANCE,
		"fixture_count": fixtures.size(),
		"fixtures": fixtures,
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"controller_step_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
	}
	print(
		"QSDK_R23D57_GODOT_FULL_PRECISION_TRACE_TRANSPORT ",
		JSON.stringify(receipt, "", true, true),
	)
	quit(0)


static func _build_fixture(
	fixture_id: String,
	host_applied_target_velocity_rad_s: float,
	motor_target_velocity_readback_rad_s: float,
	declared_maximum_impulse_nms: float,
	motor_maximum_impulse_readback_nms: float,
) -> Dictionary:
	var application := {
		"actuator_id": "front_left_knee_motor",
		"host_applied_target_velocity_rad_s": host_applied_target_velocity_rad_s,
		"motor_target_velocity_readback_rad_s": motor_target_velocity_readback_rad_s,
		"motor_target_velocity_readback_error_rad_s": absf(
			motor_target_velocity_readback_rad_s
			- host_applied_target_velocity_rad_s
		),
		"declared_maximum_impulse_nms": declared_maximum_impulse_nms,
		"motor_maximum_impulse_readback_nms": motor_maximum_impulse_readback_nms,
		"motor_maximum_impulse_readback_error_nms": absf(
			motor_maximum_impulse_readback_nms - declared_maximum_impulse_nms
		),
	}
	var default_json := JSON.stringify(application)
	var full_precision_json := JSON.stringify(application, "", true, true)
	return {
		"fixture_id": fixture_id,
		"source_application": application,
		"default_json": default_json,
		"full_precision_json": full_precision_json,
	}
