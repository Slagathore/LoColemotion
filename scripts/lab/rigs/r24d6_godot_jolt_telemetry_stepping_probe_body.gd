class_name R24D6GodotJoltTelemetrySteppingProbeBody
extends RigidBody3D

## Read-only probe for the R24D6 invalid-timing control. The native binding is
## called from _integrate_forces(), while Jolt owns the stepping space. The
## callback never writes the direct body state or applies force, torque, or an
## impulse.

var telemetry_joint_rid := RID()
var stepping_read_attempt_count := 0
var stepping_read_refusal_count := 0
var stepping_read_non_refusal_count := 0


func _integrate_forces(_state: PhysicsDirectBodyState3D) -> void:
	if not telemetry_joint_rid.is_valid():
		return
	stepping_read_attempt_count += 1
	var value: Variant = JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(
		telemetry_joint_rid
	)
	if value == null:
		stepping_read_refusal_count += 1
	else:
		stepping_read_non_refusal_count += 1
