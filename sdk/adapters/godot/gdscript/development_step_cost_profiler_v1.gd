extends RefCounted

## Diagnostic wall time only. No solver inputs, native reads, or acceptance.
## Exclusive time subtracts nested sections so totals do not double-count.
var sections: Dictionary = {}
var failure_code := ""
var _stack: Array = []


func begin_v1(label: String, stamp_us: int = -1) -> void:
	var now := Time.get_ticks_usec() if stamp_us < 0 else stamp_us
	_stack.append({"label": label, "start_us": now, "nested_us": 0})


func end_v1(label: String, stamp_us: int = -1) -> void:
	var now := Time.get_ticks_usec() if stamp_us < 0 else stamp_us
	if _stack.is_empty() or _stack.back()["label"] != label:
		failure_code = "PROFILE_UNBALANCED_SECTION"
		return
	var frame: Dictionary = _stack.pop_back()
	var elapsed := now - int(frame["start_us"])
	if elapsed < int(frame["nested_us"]):
		failure_code = "PROFILE_NONMONOTONIC_CLOCK"
		return
	var row: Dictionary = sections.get(
		label, {"sample_count": 0, "inclusive_us": 0, "exclusive_us": 0, "maximum_us": 0}
	)
	row["sample_count"] += 1
	row["inclusive_us"] += elapsed
	row["exclusive_us"] += elapsed - int(frame["nested_us"])
	row["maximum_us"] = maxi(int(row["maximum_us"]), elapsed)
	sections[label] = row
	if not _stack.is_empty():
		_stack.back()["nested_us"] += elapsed


func snapshot_v1(start_us: int, end_us: int) -> Dictionary:
	var accounted := 0
	for row in sections.values():
		accounted += int(row["exclusive_us"])
	var elapsed := end_us - start_us
	return {
		"ok": failure_code.is_empty() and _stack.is_empty() and elapsed >= accounted,
		"failure_code": failure_code,
		"open_section_count": _stack.size(),
		"elapsed_us": elapsed,
		"accounted_us": accounted,
		"unattributed_us": elapsed - accounted,
		"sections": sections.duplicate(true),
	}
