extends RefCounted

## Development-only, process-local memoization of two pure context predicates.
## Not installed in any physical route yet. The full predicates remain the oracle.
## Never use this for observations, commands, physical baselines or qualification.
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const CONTIGUOUS_BEHAVIOR := 0
const DISCRETE_LIVE := 1
const MAX_KEY_BYTES := 262144
const MAX_NODES := 4096
const MAX_DEPTH := 48

var _entries: Dictionary = {}
var hits := 0
var full_checks := 0
var bypasses := 0


func validate_v1(sdk: Object, context: Dictionary, predicate: int) -> bool:
	if predicate not in [CONTIGUOUS_BEHAVIOR, DISCRETE_LIVE]:
		return false
	# The native canonicalizer is pure; script overrides or other SDK objects are
	# not covered by that source argument. They always use the original check.
	var key := PackedByteArray()
	if (
		is_instance_valid(sdk)
		and sdk.get_class() == "SporeLocomotionSdk"
		and sdk.get_script() == null
	):
		key = exact_key_v1(context)
	if key.is_empty():
		bypasses += 1
	else:
		var entry: Dictionary = _entries.get(predicate, {})
		if entry.get("sdk") == sdk and entry.get("key") == key:
			hits += 1
			return true
	# Evict before a miss, including an ineligible input. Never retain negatives.
	_entries.erase(predicate)
	full_checks += 1
	var accepted := full_validate_v1(sdk, context, predicate)
	if accepted and not key.is_empty():
		_entries[predicate] = {"sdk": sdk, "key": key}
	return accepted


static func full_validate_v1(sdk: Object, context: Dictionary, predicate: int) -> bool:
	match predicate:
		CONTIGUOUS_BEHAVIOR:
			return Route.contiguous_boundary_recovery_behavior_context_binding_exact_v1(
				sdk, context
			)
		DISCRETE_LIVE:
			return Route._discrete_staging_live_context_binding_exact_v1(sdk, context)
	return false


func clear_v1() -> void:
	_entries.clear()


func entry_count_v1() -> int:
	return _entries.size()


static func exact_key_v1(context: Dictionary) -> PackedByteArray:
	# Do not encode objects as instance IDs, silently coerce values to JSON, or
	# treat digest equality as input equality. Limits bound this optional lane.
	var budget := [MAX_NODES, MAX_KEY_BYTES]
	if not _eligible_v1(context, 0, budget):
		return PackedByteArray()
	var key := var_to_bytes(context)
	return key if key.size() <= MAX_KEY_BYTES else PackedByteArray()


static func _eligible_v1(value: Variant, depth: int, budget: Array) -> bool:
	budget[0] -= 1
	if depth > MAX_DEPTH or budget[0] < 0:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_STRING:
			budget[1] -= value.to_utf8_buffer().size()
			return budget[1] >= 0
		TYPE_ARRAY:
			if value.is_typed() or value.size() > budget[0]:
				return false
			for item in value:
				if not _eligible_v1(item, depth + 1, budget):
					return false
			return true
		TYPE_DICTIONARY:
			if value.is_typed() or value.size() * 2 > budget[0]:
				return false
			for name in value:
				if typeof(name) != TYPE_STRING or not _eligible_v1(name, depth + 1, budget):
					return false
				if not _eligible_v1(value[name], depth + 1, budget):
					return false
			return true
	return false
