extends "res://sdk/explorer/native_recovery/worker_base.gd"
## Shortened development prefix. No official schedule or evaluator is changed.
const StudioCache:=preload("res://sdk/explorer/studio/immutable_context_cache.gd")
const ContextProbe:=preload("res://sdk/explorer/studio/godot_context_probe.gd")
const STUDIO_MAX_STEPS:=360

func _verify_l15_prepared_context_before_world_v1() -> bool:
	var accepted:=super._verify_l15_prepared_context_before_world_v1()
	if accepted and not _check_only:StudioCache.enabled=true
	return accepted

func _send(value: Dictionary) -> void:
	if value.get("message_type")=="completed":
		if _check_only:
			var probe:=ContextProbe.run(RouteScript,_sdk,_context)
			value.summary["studio_context_cache_probe"]=probe
			value.ok=value.get("ok")==true and probe.ok
		else:
			value.summary["studio_context_cache"]={"hits":StudioCache.hits,"misses":StudioCache.misses,"entries":StudioCache.entries.size(),"maximum_steps":STUDIO_MAX_STEPS}
	super._send(value)

func _after_completed_process_isolated_step_v1() -> bool:
	if super._after_completed_process_isolated_step_v1():return true
	if _total_solver_step_count>=STUDIO_MAX_STEPS:
		_finish_explorer("studio_shortened_prefix_diagnostic");return true
	return false
