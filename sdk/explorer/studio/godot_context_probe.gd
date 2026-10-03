extends RefCounted
const Cache:=preload("immutable_context_cache.gd")

static func run(route: Script, sdk: Object, context: Dictionary) -> Dictionary:
	Cache.enabled=false;Cache.reset()
	var cases: Array[Dictionary]=[context.duplicate(true)]
	for key in ["schema_version","recovery_controller_id","capability_sha256","runtime_qualification_sha256"]:
		var changed:=context.duplicate(true);changed[key]="crossed";cases.append(changed)
	var failures: Array[String]=[];var checks:=0
	for value in cases:
		Cache.enabled=false
		var expected: bool=route.contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk,value)
		Cache.enabled=true
		for repeat in 2:
			var observed: bool=route.contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk,value)
			checks+=1
			if observed!=expected:failures.append("cached predicate changed outcome")
	Cache.reset();Cache.enabled=false
	var start:=Time.get_ticks_usec()
	var baseline: bool=route.contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk,context)
	var baseline_us:=Time.get_ticks_usec()-start
	Cache.enabled=true
	var warm: bool=route.contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk,context)
	start=Time.get_ticks_usec()
	for repeat in 100:
		if route.contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk,context)!=baseline:failures.append("repeated predicate differs")
	var repeated_us:=Time.get_ticks_usec()-start
	var ok:=failures.is_empty() and baseline and warm and Cache.hits>=100
	var result: Dictionary={"ok":ok,"checks":checks+100,"failures":failures,"baseline_accepted":baseline,"uncached_call_us":baseline_us,"cached_100_calls_us":repeated_us,"hits":Cache.hits,"misses":Cache.misses,"world_build_count":0,"solver_step_count":0}
	Cache.enabled=false;Cache.reset()
	return result
