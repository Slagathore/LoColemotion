extends SceneTree

const FiniteSanitizerScript := preload(
	"res://scripts/lab/finite_sanitizer.gd")
const LabRunnerScript := preload("res://scripts/lab/lab_runner.gd")
const SpecCompilerScript := preload("res://scripts/lab/spec_compiler.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab controlled-abort lifecycle integration ===")
	var spec_path := (
		"res://data/lab/experiments/L0_0_stationary_gravity_off_v1.tres")
	var loaded = ResourceLoader.load(
		spec_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var resource_sha := "sha256:%s" % FileAccess.get_sha256(spec_path)
	var compiled := SpecCompilerScript.compile(
		loaded,
		{},
		{},
		{
			"resource_path": spec_path,
			"resource_sha256": resource_sha,
		})
	_check(compiled["ok"], "promotion spec compiles without a fault field")
	if not compiled["ok"]:
		_finish()
		return
	var experiment: RefCounted = compiled["experiment"]
	_check(
		not experiment.call("value").has("fault_injection"),
		"fault injection is not authorable in the promotion experiment schema")
	var root := ProjectSettings.globalize_path(
		"res://.tmp/lab_controlled_abort_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		]).replace("\\", "/")
	var runner = LabRunnerScript.new()
	var result: Dictionary = await runner.run(
		self,
		experiment,
		root,
		{
			"resource_path": spec_path,
			"resource_sha256": resource_sha,
		},
		{
			"allow_test_fault_injection": true,
			"fault_injection":
				"force_nonfinite_runtime_after_capture",
		})
	_check(
		not result["ok"]
			and int(result["exit_code"]) == 5
			and result["code"] == "FORCED_NONFINITE_RUNTIME_FAILURE",
		"forced nonfinite value takes the controlled-abort path")
	_check(
		FiniteSanitizerScript.inspect(result["details"])["ok"],
		"returned abort details contain no nonfinite serialization poison")
	var partial_path := String(result["artifacts"])
	_check(
		partial_path.ends_with(".partial")
			and DirAccess.dir_exists_absolute(partial_path),
		"controlled abort preserves an inspectable partial directory")
	_check(
		not FileAccess.file_exists(partial_path.path_join("checksums.json"))
			and not FileAccess.file_exists(
				partial_path.path_join("summary.json")),
		"aborted child never crosses checksum or publication boundary")
	var process_metadata := _read_json(
		partial_path.path_join("process_metadata.json"))
	_check(
		process_metadata["status"] == "ABORTED"
			and int(process_metadata["exit_code"]) == 5
			and process_metadata["ended_utc"] != null,
		"direct lifecycle terminalizes process metadata as ABORTED")
	var manifest := _read_json(partial_path.path_join("manifest.json"))
	_check(
		manifest["status"] == "RUNNING"
			and manifest["execution_mode"] == "development"
			and manifest["process_isolation"]
				== "direct_in_process_development_only",
		"partial manifest is truthful and explicitly non-promotable")
	var notes := TraceStoreScript.read_jsonl(
		partial_path.path_join("runtime_notes.jsonl"))
	var fatal: Dictionary = notes["records"][-1]
	_check(
		fatal["severity"] == "fatal"
			and fatal["code"] == "FORCED_NONFINITE_RUNTIME_FAILURE"
			and fatal["evidence"]["sanitized_details"]["invalid_value"]
				== null,
		"terminal fatal note replaces NaN with JSON null")
	_check(
		fatal["evidence"]["availability"].has("/invalid_value")
			and fatal["evidence"]["availability"]["/invalid_value"][
				"status"] == "invalid"
			and fatal["evidence"]["availability"]["/invalid_value"][
				"reason"] == "NAN",
		"fatal note gives exact JSON-pointer availability and reason")
	var snapshot := TraceStoreScript.read_jsonl(
		partial_path.path_join("pre_event_snapshot.jsonl"))
	if not snapshot["ok"] or snapshot["records"].is_empty():
		printerr(
			"  SNAPSHOT DIAGNOSTIC  abort_result=",
			result["details"].get("pre_event_snapshot", {}),
			" read_result=",
			snapshot)
	_check(
		snapshot["ok"] and snapshot["records"].size() > 0,
		"controlled abort materializes the pre-event flight-recorder snapshot")
	var applications := TraceStoreScript.read_jsonl(
		partial_path.path_join("applications.jsonl"))
	_check(
		applications["ok"] and applications["records"].is_empty(),
		"no applications occur after or before the injected failure")
	_check(
		not DirAccess.dir_exists_absolute(
			partial_path.path_join("pre_event_slots")),
		"transient ring slots are cleaned after snapshot materialization")
	_remove_tree(root)
	_finish()


static func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


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


static func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := absolute.path_join(name)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)
