extends RefCounted
## Pure serializer controls execute before the production worker opens a world.
const Memo := preload("res://sdk/explorer/native_recovery/memoized_sdk.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

class Echo extends RefCounted:
	var calls := 0
	var steps := 0
	func canonicalize_json(input: String) -> String:
		calls += 1
		return input
	func recovery_step_v5_json(input: String) -> String:
		steps += 1
		return input

static func run(native: Object) -> Dictionary:
	var failures: Array[String] = []
	var checks := 0
	var echo := Echo.new()
	var memo := Memo.new(echo)
	memo.max_cache_characters = 4
	memo.canonicalize_json("a"); memo.canonicalize_json("b"); memo.canonicalize_json("a")
	memo.canonicalize_json("c")
	checks += 1
	if memo.cache.keys() != ["a","c"] or memo.hits != 1 or memo.evictions != 1:
		failures.append("least recently used entry and hit promotion")
	checks += 1
	if memo.byte_count != 4 or echo.calls != 3:
		failures.append("bounded accounting and exact hit avoids native call")
	memo.canonicalize_json("oversized")
	checks += 1
	if memo.cache.keys() != ["a","c"] or memo.byte_count != 4 or memo.oversized_skips != 1:
		failures.append("oversized request keeps working set and bound")
	memo.canonicalize_json("bb")
	checks += 1
	if memo.cache.keys() != ["bb"] or memo.byte_count != 4 or memo.evictions != 3:
		failures.append("multiple eviction accounting")
	var legacy := Memo.new(Echo.new())
	legacy.eviction_policy = "clear_all"; legacy.max_cache_characters = 4
	for key in ["a","b","a","c"]: legacy.canonicalize_json(key)
	checks += 1
	if legacy.cache.keys() != ["c"] or legacy.clears != 1 or legacy.byte_count != 2:
		failures.append("predecessor full-clear control")
	var exact := Memo.new(Echo.new())
	for key in ["null"," null","null"]:
		if exact.canonicalize_json(key) != key: failures.append("exact request output")
	checks += 1
	if exact.misses != 2 or exact.hits != 1:
		failures.append("distinct request strings must not alias")
	var unicode_cache := Memo.new(Echo.new())
	unicode_cache.max_cache_characters = 4
	for key in ["\u00e9","\u03b2","\u00e9"]:
		unicode_cache.canonicalize_json(key)
	checks += 1
	if unicode_cache.byte_count != 4 or unicode_cache.hits != 1:
		failures.append("character budget is not mislabeled byte accounting")
	for repeat in 2: exact.recovery_step_v5_json("same controller request")
	checks += 1
	if exact.native.steps != 2:
		failures.append("controller requests must always execute")
	var fresh := Memo.new(native)
	for value in [null,{"x":-0.0,"y":1.2345678901234567,"v":[1,1.0,true,"\u00e9"]}]:
		var wire := Transport.stringify({"schema_version":"sporespore_canonical_json_request_v1","value":value})
		var expected: String = native.canonicalize_json(wire)
		if fresh.canonicalize_json(wire) != expected or fresh.canonicalize_json(wire) != expected:
			failures.append("native canonical output differs")
	checks += 1
	var malformed := "{"
	var refusal: String = native.canonicalize_json(malformed)
	checks += 1
	if fresh.canonicalize_json(malformed) != refusal or fresh.canonicalize_json(malformed) != refusal:
		failures.append("native refusal must be preserved exactly")
	return {"ok":failures.is_empty(),"checks":checks,"failures":failures,"world_build_count":0,"solver_step_count":0}
