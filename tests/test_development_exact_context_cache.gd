extends SceneTree

const Cache := preload("res://sdk/adapters/godot/gdscript/development_exact_context_cache_v1.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const CHECKPOINT := "res://sdk/development_recovery_step_cost_checkpoint_v1.json"
const REPEATS := 8
var checks: Dictionary = {}


class CanonicalizerProxy:
	extends RefCounted
	var native_sdk: Object

	func canonicalize_json(raw: String) -> String:
		return native_sdk.canonicalize_json(raw)


func _initialize() -> void:
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var checkpoint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHECKPOINT))
	var rows: Array = []
	var sources: Array = []
	var retained_contexts: Array = []
	for role in ["matched_no_kick_continuation", "kick_passive_recovery_resume"]:
		var path: String = checkpoint["evidence_root"] + "/children/" + role + "/worker_report.json"
		var raw := FileAccess.get_file_as_string(path)
		var report: Dictionary = JSON.parse_string(raw)
		var capture_snapshot: Dictionary = report["l15_prepared_context_comparison"]["observed_capture"]
		checks[role + "_capture_digest"] = _snapshot_valid_v1(capture_snapshot)
		var capture: Dictionary = JSON.parse_string(capture_snapshot["utf8_text"])
		var snapshot: Dictionary = capture["source_context"]
		checks[role + "_context_digest"] = _snapshot_valid_v1(snapshot)
		var context: Dictionary = JSON.parse_string(snapshot["utf8_text"])
		retained_contexts.append(context)
		sources.append(
			{
				"role": role,
				"path": path,
				"report_sha256": "sha256:" + raw.sha256_text(),
				"context_sha256": snapshot["raw_sha256"],
				"context_utf8_bytes": snapshot["utf8_byte_length"]
			}
		)
		rows.append(_benchmark_v1(sdk, context, role))
	# Also cover the production constructor's native numeric types and key order,
	# not just the JSON-decoded retained representation.
	var fresh := Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	checks["fresh_prepared_context_ok"] = fresh.get("ok") == true
	rows.append(_benchmark_v1(sdk, fresh, "fresh_zero_world_prepared_context"))
	_key_controls_v1()
	_invalidation_controls_v1(sdk, fresh)
	checks["retained_contexts_same_values"] = (
		Transport.stringify(retained_contexts[0]) == Transport.stringify(retained_contexts[1])
	)
	var ok := checks.values().all(func(value: Variant) -> bool: return value == true)
	print(
		"DEVELOPMENT_EXACT_CONTEXT_CACHE ",
		(
			Transport
			. stringify(
				{
					"schema_version": "sporespore_development_exact_context_cache_benchmark_v1",
					"ledger_scope":
					{
						"subsystem": "workflow",
						"engine_scope": "godot_jolt",
						"authority_mode": "zero_world_descriptive_benchmark",
						"question_class": "development"
					},
					"ok": ok,
					"checks": checks,
					"sources": sources,
					"benchmarks": rows,
					"godot_version": Engine.get_version_info()["string"],
					"repeats_per_method": REPEATS,
					"model_construction_count": 0,
					"world_build_count": 0,
					"native_physics_read_count": 0,
					"solver_step_count": 0,
					"physical_path_cache_installed": false,
					"physical_acceptance_authority": false,
					"release_authority": false,
				}
			)
		)
	)
	quit(0 if ok else 1)


func _benchmark_v1(sdk: Object, context: Dictionary, label: String) -> Dictionary:
	var methods: Array = []
	for predicate in [Cache.CONTIGUOUS_BEHAVIOR, Cache.DISCRETE_LIVE]:
		var cache := Cache.new()
		var all_valid := true
		var start := Time.get_ticks_usec()
		for iteration in range(REPEATS):
			all_valid = Cache.full_validate_v1(sdk, context, predicate) and all_valid
		var full_us := Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		var cold_valid := cache.validate_v1(sdk, context, predicate)
		var cold_us := Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		for iteration in range(REPEATS):
			all_valid = cache.validate_v1(sdk, context, predicate) and all_valid
		var hit_us := Time.get_ticks_usec() - start
		checks[label + "_" + str(predicate)] = (
			all_valid
			and cold_valid
			and cache.hits == REPEATS
			and cache.full_checks == 1
			and cache.bypasses == 0
			and cache.entry_count_v1() == 1
		)
		methods.append(
			{
				"predicate": predicate,
				"full_total_us": full_us,
				"cold_us": cold_us,
				"hit_total_us": hit_us,
				"hits": cache.hits,
				"full_checks": cache.full_checks,
				"key_bytes": Cache.exact_key_v1(context).size()
			}
		)
	return {"input": label, "methods": methods}


func _key_controls_v1() -> void:
	var bits := PackedByteArray()
	bits.resize(8)
	bits.encode_double(0, 1.0)
	bits.encode_s64(0, bits.decode_s64(0) + 1)
	var adjacent := bits.decode_double(0)
	# This runtime interns [0.0, -0.0] literals as two positive zeros. Build
	# the sign bit at runtime so the control actually contains distinct inputs.
	bits.encode_s64(0, -9223372036854775807 - 1)
	var negative_zero := bits.decode_double(0)
	var distinctions := {
		"adjacent_binary64": [1.0, adjacent],
		"signed_zero": [0.0, negative_zero],
		"integer_float": [1, 1.0],
		"boolean_integer": [true, 1],
		"null_empty_string": [null, ""],
		"large_integers": [9223372036854775806, 9223372036854775807],
		"unicode": ["é", "e"],
		"unicode_replacement": ["a�b", "ab"],
	}
	for label in distinctions:
		var pair: Array = distinctions[label]
		var a := Cache.exact_key_v1({"value": pair[0]})
		var b := Cache.exact_key_v1({"value": pair[1]})
		checks["key_distinction_" + label] = (not a.is_empty() and not b.is_empty() and a != b)
	var deep: Dictionary = {}
	for index in range(Cache.MAX_DEPTH + 2):
		deep = {"nested": deep}
	var cycle: Dictionary = {}
	cycle["self"] = cycle
	var typed_array: Array[int] = [1]
	var typed_dict: Dictionary[String, int] = {"n": 1}
	for value in [
		NAN,
		INF,
		RefCounted.new(),
		Vector3.ZERO,
		{1: "not_string_key"},
		typed_array,
		typed_dict,
		deep,
		cycle,
		"a".repeat(Cache.MAX_KEY_BYTES + 1)
	]:
		checks["key_ineligible_" + str(checks.size())] = (
			Cache.exact_key_v1({"value": value}).is_empty()
		)
	cycle.clear()
	var wide: Array = []
	wide.resize(Cache.MAX_NODES + 1)
	checks["node_limit"] = Cache.exact_key_v1({"wide": wide}).is_empty()


func _invalidation_controls_v1(sdk: Object, context: Dictionary) -> void:
	var changes: Array = []
	for key in [
		"ok",
		"schema_version",
		"physical_world_construction_gate_id",
		"recovery_controller_id",
		"r170_behavior_context_sha256",
		"r165_behavior_context_sha256",
		"capability_sha256",
		"runtime_binding",
		"morphology_context",
		"rotation_aware_energy_ledger_profile_selected",
		"r170_physical_closure_raw_sha256",
		"runtime_qualification_sha256"
	]:
		var changed := context.duplicate(true)
		changed.erase(key)
		changes.append({"label": "remove_" + key, "context": changed})
	var nested := context.duplicate(true)
	var resolution: Dictionary = nested["actuator_profile_resolution"]
	resolution["development_mutation"] = true
	changes.append({"label": "nested_new_member", "context": nested})
	var tiny_change := context.duplicate(true)
	checks["real_context_float_mutated"] = _nudge_first_float_v1(tiny_change)
	changes.append({"label": "real_nested_adjacent_float", "context": tiny_change})
	var reordered: Dictionary = {}
	var keys: Array = context.keys()
	keys.reverse()
	for key in keys:
		reordered[key] = context[key]
	changes.append({"label": "reordered_keys", "context": reordered})
	for predicate in [Cache.CONTIGUOUS_BEHAVIOR, Cache.DISCRETE_LIVE]:
		var cache := Cache.new()
		for change in changes:
			cache.validate_v1(sdk, context, predicate)
			var before := cache.full_checks
			var expected := Cache.full_validate_v1(sdk, change["context"], predicate)
			var actual := cache.validate_v1(sdk, change["context"], predicate)
			checks[change["label"] + "_" + str(predicate)] = (
				actual == expected and cache.full_checks == before + 1
			)
		# Mutate the original dictionary after insertion: retained key bytes must
		# not alias it. Returning to valid inputs must again consult the oracle.
		var alias := context.duplicate(true)
		cache.validate_v1(sdk, alias, predicate)
		var before := cache.full_checks
		alias["schema_version"] = "invalid"
		checks["in_place_mutation_" + str(predicate)] = (
			not cache.validate_v1(sdk, alias, predicate) and cache.full_checks == before + 1
		)
		before = cache.full_checks
		cache.validate_v1(sdk, alias, predicate)
		checks["negative_not_cached_" + str(predicate)] = cache.full_checks == before + 1
		cache.validate_v1(sdk, context, predicate)
		before = cache.full_checks
		var second_sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
		checks["different_sdk_" + str(predicate)] = (
			cache.validate_v1(second_sdk, context, predicate) and cache.full_checks == before + 1
		)
		cache.clear_v1()
		checks["explicit_clear_" + str(predicate)] = cache.entry_count_v1() == 0
		var proxy := CanonicalizerProxy.new()
		proxy.native_sdk = sdk
		before = cache.full_checks
		var bypasses_before := cache.bypasses
		checks["script_sdk_never_cached_" + str(predicate)] = (
			cache.validate_v1(proxy, context, predicate)
			and cache.validate_v1(proxy, context, predicate)
			and cache.full_checks == before + 2
			and cache.bypasses == bypasses_before + 2
			and cache.entry_count_v1() == 0
		)
	var bounded := Cache.new()
	bounded.validate_v1(sdk, context, Cache.CONTIGUOUS_BEHAVIOR)
	bounded.validate_v1(sdk, context, Cache.DISCRETE_LIVE)
	checks["two_predicates_two_entries"] = bounded.entry_count_v1() == 2
	checks["unknown_predicate_refused"] = not bounded.validate_v1(sdk, context, 99)
	checks["null_sdk_refused"] = not bounded.validate_v1(null, context, Cache.CONTIGUOUS_BEHAVIOR)


func _nudge_first_float_v1(value: Variant) -> bool:
	if value is Dictionary or value is Array:
		var keys: Array = value.keys() if value is Dictionary else range(value.size())
		for key in keys:
			if typeof(value[key]) == TYPE_FLOAT and value[key] > 0.0 and is_finite(value[key]):
				var bits := PackedByteArray()
				bits.resize(8)
				bits.encode_double(0, value[key])
				bits.encode_s64(0, bits.decode_s64(0) + 1)
				value[key] = bits.decode_double(0)
				return true
			if _nudge_first_float_v1(value[key]):
				return true
	return false


func _snapshot_valid_v1(snapshot: Dictionary) -> bool:
	var raw: String = snapshot["utf8_text"]
	return (
		raw.to_utf8_buffer().size() == int(snapshot["utf8_byte_length"])
		and "sha256:" + raw.sha256_text() == snapshot["raw_sha256"]
	)
