extends SceneTree

## QSDK-R24D3 compile/binding probe only. This script creates no physics body,
## joint, space, model, or world and takes no solver step.

const CLASS_NAME := &"JoltPhysicsServer3D"
const METHOD_NAME := &"hinge_joint_get_motor_telemetry"
const RECEIPT_SCHEMA := "sporespore.godot_jolt_hinge_motor_telemetry.v1"
const RECEIPT_FIELDS := [
	"schema",
	"telemetry_sequence",
	"solver_step_s",
	"motor_state",
	"target_angular_velocity_rad_s",
	"min_torque_limit_nm",
	"max_torque_limit_nm",
	"signed_motor_impulse_nms",
	"positive_motor_work_j",
	"absorbed_motor_work_j",
	"net_motor_work_j",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== QSDK-R24D3 Godot/Jolt motor-impulse binding zero-world probe ===")
	_check(ClassDB.class_exists(CLASS_NAME), "instrumented Jolt class is registered")
	_check(
		ClassDB.class_has_method(CLASS_NAME, METHOD_NAME),
		"exact motor-telemetry receipt method is bound"
	)
	var invalid_readback: Variant = JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(
		RID()
	)
	_check(invalid_readback == null, "invalid RID refuses instead of synthesizing zero")
	_check(RECEIPT_SCHEMA.ends_with(".v1"), "receipt schema is explicitly versioned")
	_check(RECEIPT_FIELDS.size() == 11, "receipt field set is frozen and complete")
	_check(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS) == 0.0, "no physics object exists")
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("QSDK_R24D3_GODOT_BINDING_ZERO_WORLD passed=%d failed=%d world_build_count=0 solver_step_count=0" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
