class_name TrainingDashboard
extends RefCounted

## Read-side summary for the training/correlation dashboard. It intentionally
## consumes append-only JSONL + corpus helpers instead of owning training state.


static func summary(corpus: Array = []) -> Dictionary:
	var runs := TrainingLog.load_runs()
	var failures := TrainingLog.load_failures()
	var agg := TrainingLog.aggregate()
	var assist_values := PackedFloat32Array()
	var best_forward := -INF
	var best_name := ""
	var ranked: Array = []
	for row in runs:
		assist_values.append(float(row.get("assist_ratio", 0.0)))
		var fwd := float(row.get("forward", 0.0))
		var name := String(row.get("creature_name", row.get("creature_id", "")))
		ranked.append({"name": name, "forward": fwd,
			"assist_ratio": float(row.get("assist_ratio", 0.0))})
		if fwd > best_forward:
			best_forward = fwd
			best_name = name
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["forward"]) > float(b["forward"]))
	return {
		"aggregate": agg,
		"run_count": runs.size(),
		"failure_count": failures.size(),
		"corpus_counts": CorpusBuilder.category_counts(corpus) if not corpus.is_empty() else {},
		"best_forward": 0.0 if best_forward == -INF else best_forward,
		"best_name": best_name,
		"top_performers": ranked.slice(0, mini(5, ranked.size())),
		"assist_ratio": _distribution(assist_values),
	}


# A compact human-readable digest for the editor dashboard panel.
static func summary_text(corpus: Array = []) -> String:
	var s := summary(corpus)
	var assist: Dictionary = s["assist_ratio"]
	var lines := PackedStringArray()
	lines.append("Runs: %d    Failures: %d" % [int(s["run_count"]), int(s["failure_count"])])
	lines.append("Best: %.2fm  (%s)" % [float(s["best_forward"]), String(s["best_name"])])
	lines.append("Assist ratio: mean %.2f  [%.2f..%.2f]  n=%d" % [
		float(assist["mean"]), float(assist["min"]), float(assist["max"]), int(assist["count"])])
	var tops: Array = s["top_performers"]
	if not tops.is_empty():
		lines.append("Top:")
		for t in tops:
			lines.append("  %.2fm  %s" % [float(t["forward"]), String(t["name"])])
	return "\n".join(lines)


static func _distribution(values: PackedFloat32Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "min": 0.0, "max": 0.0, "mean": 0.0}
	var lo := INF
	var hi := -INF
	var sum := 0.0
	for v in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
		sum += v
	return {"count": values.size(), "min": lo, "max": hi, "mean": sum / values.size()}
