extends "res://tests/test_development_measured_entry_profile.gd"

const Profile := preload("res://sdk/adapters/godot/gdscript/development_rearward_fold_profile_v1.gd")

func _entry_selection_v1() -> Dictionary:
	return Profile.value_v1()["worker_selection"]

func _entry_controller_id_v1() -> String:
	return RouteScript.RECOVERY_CONTROLLER_V7_ID
