extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
# gdlint: disable=max-line-length

const Exact := preload("res://sdk/adapters/godot/gdscript/development_exact_value_comparison_v1.gd")


func _legacy(left: Variant, right: Variant) -> bool:
	return Transport.stringify(left) == Transport.stringify(right)


func _dispatch(_sdk: Object, input: Dictionary, _binding: Dictionary) -> Dictionary:
	var values: Array = [null, false, true, 0, 1, -1, 9007199254740993,
		0.0, -0.0, 1.0, -1.0, 1.0000000000000002, 1e-30, 1e30,
		"", "1", "true", "null", "a\n\t\"\\b", "é", "é", "雪",
		[], [1], [1.0], [1, 2], [2, 1], {}, {"x": null}, {"x": 1},
		{"b": [1, {"x": 2.0}], "a": "raw"}, {"a": "raw", "b": [1, {"x": 2.0}]},
		{1: "numeric key"}, {"1": "numeric key"}, PackedInt32Array([1, 2])]
	var cases := 0
	for left in values:
		for right in values:
			if Exact.same_v1(left, right) != _legacy(left, right):
				return {"ok": false, "failure_code": "EXACT_COMPARISON_UNIT_MISMATCH", "case": cases}
			cases += 1
	var nested: Variant = "leaf"
	for _index in range(70):
		nested = [nested]
	if not Exact.same_v1(nested, nested.duplicate(true)):
		return {"ok": false, "failure_code": "EXACT_COMPARISON_DEPTH_FALLBACK"}
	var packets: Array = input.get("passive_entry", {}).get("canonical_packets", [])
	if packets.size() != 267 or input.get("solver_step_count") != 626:
		return {"ok": false, "failure_code": "EXACT_COMPARISON_RETAINED_POPULATION"}
	var retained_cases := 0
	for packet in packets:
		var original: Dictionary = packet["collection_transport"]
		var equal := original.duplicate(true)
		var missing := original.duplicate(true)
		missing.erase("source_links")
		var crossed := original.duplicate(true)
		crossed["source_links"]["bound_observation"]["utf8_text"] += " "
		for right in [equal, missing, crossed]:
			if Exact.same_v1(original, right) != _legacy(original, right):
				return {"ok": false, "failure_code": "EXACT_COMPARISON_RETAINED_MISMATCH", "case": retained_cases}
			retained_cases += 1
	# Alternate ordering to reduce warm-up/order bias; measure only comparisons.
	var benchmark_pairs: Array = []
	for index in [0, 26, 27, 266]:
		var value: Dictionary = packets[index]["collection_transport"]
		benchmark_pairs.append([value, value.duplicate(true)])
	var timings: Array = []
	for optimized in [false, true, true, false]:
		var started := Time.get_ticks_usec()
		var accepted := 0
		for _repeat in range(20):
			for pair in benchmark_pairs:
				accepted += int(Exact.same_v1(pair[0], pair[1]) if optimized else _legacy(pair[0], pair[1]))
		timings.append({"optimized": optimized, "elapsed_us": Time.get_ticks_usec() - started,
			"comparisons": 80, "accepted": accepted})
	return {"ok": true, "schema_version": "sporespore_development_exact_value_comparison_controls_v1",
		"ledger_scope": {"subsystem": "recovery", "engine_scope": "godot_jolt", "authority_mode": "retained_data_performance_controls", "question_class": "development"},
		"unit_pair_count": cases, "retained_pair_count": retained_cases, "depth_fallback_passed": true,
		"timings": timings, "original_attempt_reclassified": false,
		"timing_scope": "Four retained transport values; not a full-reader or physical speedup claim."}
