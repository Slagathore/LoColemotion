extends SceneTree

const LabRunnerScript := preload("res://scripts/lab/lab_runner.gd")
const SpecCompilerScript := preload("res://scripts/lab/spec_compiler.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab resolved/applied configuration integrity gate ===")
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
	_check(compiled["ok"], "baseline experiment compiles")
	if not compiled["ok"]:
		_finish()
		return
	var experiment: RefCounted = compiled["experiment"]
	_check(
		not experiment.call("value").has(
			"allow_test_configuration_mismatch"),
		"configuration mismatch seam is not authorable in experiment specs")
	var root := ProjectSettings.globalize_path(
		"res://.tmp/lab_configuration_gate_%d_%d" % [
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
		{"allow_test_configuration_mismatch": true})
	var complete_evidence := (
		String(result.get("termination", "")) == "completed"
		and String(result.get("evidence_validity", "")) == "valid")
	_check(
		complete_evidence,
		"configuration mismatch still produces complete inspectable evidence")
	if not complete_evidence:
		printerr("  RESULT  ", result)
		_remove_tree(root)
		_finish()
		return
	_check(
		result["physical_gate"]["pass"]
			and not result["configuration_gate"]["pass"],
		"physical residuals cannot mask configuration-identity failure")
	_check(
		result["hypothesis_result"] == "inconclusive"
			and result["promotion"] == "not_evaluated"
			and int(result["exit_code"]) == 2,
		"mismatch is inconclusive and non-promotable")
	var bundle_path := String(result["artifacts"])
	var manifest := _read_json(bundle_path.path_join("manifest.json"))
	var summary := _read_json(bundle_path.path_join("summary.json"))
	_check(
		manifest["resolved_configuration_sha256"]
			!= manifest["applied_configuration_sha256"],
		"manifest seals distinct resolved and applied hashes")
	_check(
		not summary["gate_results"]["configuration"]["pass"]
			and summary["hypothesis_result"] == "inconclusive",
		"summary seals the failed configuration gate and inconclusive result")
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
