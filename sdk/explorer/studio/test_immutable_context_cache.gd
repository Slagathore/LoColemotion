extends SceneTree
const Cache:=preload("immutable_context_cache.gd")
var calls:=0
var checks:=0
var failures: Array[String]=[]

func demand(value: bool, name: String) -> void:
	checks+=1
	if not value:failures.append(name)

func oracle(value: Dictionary) -> bool:
	calls+=1
	return value.get("allowed")==true

func _initialize() -> void:
	PhysicsServer3D.set_active(false)
	var owner:=RefCounted.new()
	# Construct IEEE negative zero from bytes, avoiding literal constant folding.
	var negative_zero:=PackedByteArray([0,0,0,0,0,0,0,128]).decode_double(0)
	var context: Dictionary={"allowed":true,"nested":{"values":[1,1.0,negative_zero,"exact"]}}
	Cache.enabled=true;Cache.reset()
	demand(Cache.check(owner,context,"p",func():return oracle(context)),"first full check")
	demand(not context.is_read_only() and not context.nested.values.is_read_only(),"caller remains mutable")
	demand(Cache.check(owner,context,"p",func():return oracle(context)) and calls==1 and Cache.hits==1,"exact repeated hit")
	context.nested.values[0]=1.0
	demand(Cache.check(owner,context,"p",func():return oracle(context)) and calls==2,"int float distinction")
	context.nested.values[2]=0.0
	demand(Cache.check(owner,context,"p",func():return oracle(context)) and calls==3,"signed zero distinction")
	context.allowed=false
	demand(not Cache.check(owner,context,"p",func():return oracle(context)),"changed negative")
	demand(not Cache.check(owner,context,"p",func():return oracle(context)) and calls==5,"negative not cached")
	context.allowed=true
	Cache.check(owner,context,"p",func():return oracle(context))
	var other:=RefCounted.new()
	Cache.check(other,context,"p",func():return oracle(context))
	demand(calls==7,"owner identity")
	Cache.check(owner,context,"different",func():return oracle(context))
	demand(calls==8,"predicate identity")
	for invalid in [{"allowed":true,"object":owner},{"allowed":true,"nan":NAN},{"allowed":true,"huge":"x".repeat(Cache.MAX_BYTES+1)}]:
		Cache.check(owner,invalid,"unsafe",func():return oracle(invalid))
		demand(not Cache.entries.has("unsafe"),"ineligible positive bypass")
	var cyclic: Dictionary={"allowed":true};cyclic["cycle"]=cyclic
	Cache.check(owner,cyclic,"cycle",func():return oracle(cyclic))
	demand(not Cache.entries.has("cycle"),"cycle bypass")
	cyclic.erase("cycle")
	var typed: Array[int]=[1,2]
	var typed_context: Dictionary={"allowed":true,"typed":typed}
	Cache.check(owner,typed_context,"typed",func():return oracle(typed_context))
	demand(not Cache.entries.has("typed"),"typed container bypass")
	Cache.enabled=false
	var before:=calls
	Cache.check(owner,context,"disabled",func():return oracle(context))
	Cache.check(owner,context,"disabled",func():return oracle(context))
	demand(calls==before+2,"disabled always calls oracle")
	print("IMMUTABLE_CONTEXT_CACHE ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"world_build_count":0,"solver_step_count":0}))
	Cache.reset();quit(0 if failures.is_empty() else 2)
