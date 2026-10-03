class_name LabJointTorqueCommand
extends RefCounted

## BR1 defines the sealed command seam before BR4 supplies a real actuator.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

var tick := -1
var joint_id: StringName
var source_id: StringName
var behavior_state: StringName
var axis_world := Vector3.ZERO
var requested_active_nm := 0.0
var applied_active_nm := 0.0
var applied_passive_nm := 0.0
var structural_guard_reaction_nm := 0.0
var applied_total_nm := 0.0
var planned_application_operations: Array = []
var diagnostics: Dictionary = {}


func to_value_dictionary() -> Dictionary:
	return {
		"tick": tick,
		"joint_id": String(joint_id),
		"source_id": String(source_id),
		"behavior_state": String(behavior_state),
		"axis_world": axis_world,
		"requested_active_nm": requested_active_nm,
		"applied_active_nm": applied_active_nm,
		"applied_passive_nm": applied_passive_nm,
		"structural_guard_reaction_nm": structural_guard_reaction_nm,
		"applied_total_nm": applied_total_nm,
		"planned_application_operations": planned_application_operations,
		"diagnostics": diagnostics,
	}


func seal() -> Dictionary:
	return FrozenValueScript.snapshot(to_value_dictionary())
