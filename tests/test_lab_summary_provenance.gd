extends SceneTree

const ReportBuilderScript := preload("res://scripts/lab/report_builder.gd")
const RunSummaryScript := preload("res://scripts/lab/records/run_summary.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab summary-provenance contract ===")
	var metric: Dictionary = ReportBuilderScript.metric(
		"maximum_absolute_height_error",
		0.012,
		"m",
		"frames.jsonl",
		[180, 420],
		"/whole_body/support_height_m",
		"max_abs_error",
		1,
		"derived",
		0.0)
	var summary: Dictionary = RunSummaryScript.seal(
		"summary_run", "completed", "valid", "supported", "pass", [metric])
	_check(not metric.is_empty(), "fully sourced metric is accepted")
	_check(metric["source_stream"] == "frames.jsonl", "metric names its canonical stream")
	_check(metric["source_frame_range"] == [180, 420], "metric names its frame range")
	_check(metric["source_field"] == "/whole_body/support_height_m", "metric names its field")
	_check(int(metric["aggregation_version"]) == 1, "aggregation algorithm is versioned")
	_check(summary["metrics"].size() == 1, "summary retains provenance-bearing metric")
	var invalid := ReportBuilderScript.metric(
		"orphan_value", 1.0, "", "", [], "", "")
	_check(invalid.is_empty(), "metric without units/provenance is rejected")
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
