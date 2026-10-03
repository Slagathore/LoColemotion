class_name LabPlanarSupportSupervisor
extends RefCounted

## BR7 support-set transition supervisor.
##
## It observes declared bearing contacts and allocator feasibility. It never
## applies a force, torque, pin, root rescue, or automatic creature edit.

var _initialized := false
var _left_previous := false
var _right_previous := false


func update(
	tick: int, left_bearing: bool, right_bearing: bool, allocation_feasible: bool
) -> Dictionary:
	if tick < 0:
		return {"ok": false, "failure_code": "SUPPORT_SUPERVISOR_TICK_INVALID"}
	var events: Array = []
	if _initialized:
		if _left_previous and not left_bearing:
			events.append({"event": "SUPPORT_LOST", "support_id": "left", "tick": tick})
		if _right_previous and not right_bearing:
			events.append({"event": "SUPPORT_LOST", "support_id": "right", "tick": tick})
		if not _left_previous and left_bearing:
			events.append({"event": "SUPPORT_GAINED", "support_id": "left", "tick": tick})
		if not _right_previous and right_bearing:
			events.append({"event": "SUPPORT_GAINED", "support_id": "right", "tick": tick})
	_initialized = true
	_left_previous = left_bearing
	_right_previous = right_bearing
	var count := int(left_bearing) + int(right_bearing)
	var mode := "NO_SUPPORT"
	var response := "DECLARE_NO_SUPPORT_STOP"
	if count == 2 and allocation_feasible:
		mode = "STANCE"
		response = "CONTINUE_PLANAR_STANCE"
	elif count == 1:
		mode = "DEGRADED_SINGLE_SUPPORT"
		response = (
			"DECLARE_INFEASIBLE_STOP"
			if not allocation_feasible
			else "CONTINUE_DECLARED_SINGLE_SUPPORT"
		)
	elif count == 2:
		mode = "WRENCH_INFEASIBLE"
		response = "DECLARE_INFEASIBLE_STOP"
	return {
		"ok": true,
		"tick": tick,
		"bearing_support_count": count,
		"mode": mode,
		"response": response,
		"events": events,
		"automatic_force_application": false,
		"automatic_creature_guidance": false,
	}
