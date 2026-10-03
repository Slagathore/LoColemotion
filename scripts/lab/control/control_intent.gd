class_name LabControlIntent
extends RefCounted

enum Mode {
	STANCE,
	GAIT,
	BRACE,
	FALL_ARREST,
	RECOVERY,
	SAFE_DAMP,
}

const PRIORITY_GAIT := 100
const PRIORITY_STANCE := 200
const PRIORITY_RECOVERY := 300
const PRIORITY_BRACE := 400
const PRIORITY_FALL_ARREST := 500

var tick := -1
var intent_id: StringName
var mode := Mode.SAFE_DAMP
var source: StringName
var priority := 0
var valid_until_tick := -1
var feasible := true
var desired_wrench: Dictionary = {}
var desired_contact_forces: Dictionary = {}
var desired_contact_targets: Dictionary = {}
var desired_joint_torques: Dictionary = {}
var joint_preferences: Dictionary = {}
var contact_plan: Dictionary = {}
var required_contacts: Array[StringName] = []
var forbidden_liftoffs: Array[StringName] = []
var reason: StringName
var diagnostics: Dictionary = {}


func to_value_dictionary() -> Dictionary:
	return {
		"tick": tick,
		"intent_id": String(intent_id),
		"mode": Mode.keys()[mode],
		"source": String(source),
		"priority": priority,
		"valid_until_tick": valid_until_tick,
		"feasible": feasible,
		"desired_wrench": desired_wrench,
		"desired_contact_forces": desired_contact_forces,
		"desired_contact_targets": desired_contact_targets,
		"desired_joint_torques": desired_joint_torques,
		"joint_preferences": joint_preferences,
		"contact_plan": contact_plan,
		"required_contacts": required_contacts,
		"forbidden_liftoffs": forbidden_liftoffs,
		"reason": String(reason),
		"diagnostics": diagnostics,
	}
