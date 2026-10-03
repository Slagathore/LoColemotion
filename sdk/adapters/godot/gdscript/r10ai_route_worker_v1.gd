extends "res://sdk/adapters/godot/gdscript/r10ai_recovery_worker_v1.gd"
# gdlint: disable=max-line-length

## Full-route adapter for the checked partial worker. Launch remains refused
## until the separate profile, population, launcher and reader are qualified.
const R10AIRoute := preload("res://sdk/adapters/godot/gdscript/r10ai_recovery_route_v1.gd")

func _walking_policy_id_v1(segment: String) -> String:
	if segment == R10AIRoute.POST_HOLD_SEGMENT and _r10k_selected_v1(): return R10AIRoute.POST_HOLD_ALIAS
	return super._walking_policy_id_v1(segment)

func _walking_prefix_profile_id_v1(segment: String) -> String:
	return R10AIRoute.PREFIX_PROFILE if segment == "walking_prefix" else ""

func _attach_profile_recovery_retention_v1(report: Dictionary) -> void:
	super._attach_profile_recovery_retention_v1(report)
	report.post_recovery_settling.task_contract_sha256 = "sha256:" + FileAccess.get_sha256(R10AIRoute.TASK_PATH)
