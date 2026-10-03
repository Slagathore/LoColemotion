extends SceneTree

const AttestationTestHelperScript := preload(
	"res://tests/helpers/lab_attestation_test_helper.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const BundleValidatorScript := preload(
	"res://scripts/lab/run_bundle_validator.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab fresh-process same-seed contract ===")
	var root := ProjectSettings.globalize_path(
		"res://.tmp/lab_fresh_process_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		]).replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(root)
	var trust := AttestationTestHelperScript.create_trust_root(
		"fresh_process_same_seed")
	_check(bool(trust.get("ok", false)),
		"isolated external test trust root initializes")
	if not bool(trust.get("ok", false)):
		_remove_tree(root)
		_finish()
		return
	var trust_root := String(trust["trust_root"])
	var validation_options := {
		"attestation_requirement": "required",
		"attestation_test_root": trust_root,
	}
	var first := _launch_outer(root, trust_root, 1)
	var second := _launch_outer(root, trust_root, 2)
	_check(
		int(first["exit_code"]) == 2 and int(second["exit_code"]) == 2,
		"both independent outer launchers return the exact nonpromotion exit")
	_check(
		bool(first["engine_log_exists"])
			and bool(second["engine_log_exists"])
			and not _has_engine_error(
				String(first["output"]) + "\n"
				+ String(first["engine_log_text"]))
			and not _has_engine_error(
				String(second["output"]) + "\n"
				+ String(second["engine_log_text"])),
		"both nested outer processes retain logs with no engine/script errors")
	var bundles := _completed_bundles(root)
	if bundles.size() != 2:
		printerr("first output:\n", first["output"])
		printerr("second output:\n", second["output"])
	_check(bundles.size() == 2, "two fresh child processes publish two distinct bundles")
	if bundles.size() != 2:
		_remove_tree(root)
		AttestationTestHelperScript.remove_tree(trust_root)
		_finish()
		return

	var validations: Array = []
	var metadata_records: Array = []
	var trajectory_hashes: Array = []
	for bundle_path in bundles:
		var validation := BundleValidatorScript.validate_bundle(
			bundle_path, validation_options)
		validations.append(validation)
		var metadata: Dictionary = _read_json(
			bundle_path.path_join("process_metadata.json"))
		var plan: Dictionary = _read_json(
			bundle_path.path_join("launch_plan.json"))
		var manifest: Dictionary = _read_json(
			bundle_path.path_join("manifest.json"))
		var summary: Dictionary = _read_json(
			bundle_path.path_join("summary.json"))
		metadata_records.append(metadata)
		var frames := TraceStoreScript.read_jsonl(
			bundle_path.path_join("frames.jsonl"))
		var normalized_frames: Array = []
		for raw_frame in frames.get("records", []):
			var frame: Dictionary = raw_frame.duplicate(true)
			frame.erase("run_id")
			normalized_frames.append(frame)
		trajectory_hashes.append(CanonicalJsonScript.sha256(
			normalized_frames))
		_check(
			validation["ok"] and validation["can_finalize"],
			"fresh child bundle has a valid detached test receipt")
		_check(
			not validation["can_promote"],
			"dirty development source remains non-promotable")
		_check(
			String(manifest["process_isolation"])
				== "outer_parent_reserved_fresh_godot_v1",
			"manifest seals the real outer-parent/fresh-child mode")
		_check(
			manifest["resolved_configuration_sha256"]
				== manifest["applied_configuration_sha256"]
				and bool(summary["gate_results"]["configuration"]["pass"]),
			"resolved and live-applied configuration hashes agree")
		_check(
			metadata["arguments"] == plan["payload"]["arguments"]
				and metadata["engine_arguments"]
					== plan["payload"]["engine_arguments"]
				and metadata["user_arguments"]
					== plan["payload"]["user_arguments"],
			"process metadata and launch plan retain the same exact argv")
		_check(
			int(metadata["parent_process_id"])
				!= int(metadata["child_process_id"])
				and int(metadata["child_process_id"]) > 0
				and int(metadata["exit_code"]) == 0,
			"parent observes a distinct child PID and its real zero exit")
		_check(
			metadata["log_paths"]["engine_log"]["status"]
				== "captured"
				and metadata["log_paths"]["stdout"]["status"]
					== "unavailable"
				and metadata["log_paths"]["stderr"]["status"]
					== "unavailable"
				and metadata["log_paths"]["stdout"]["reason"] != null
				and metadata["log_paths"]["stderr"]["reason"] != null,
			"engine log is captured while stdout/stderr gaps are explicit")
		var sealed_child_log_path := bundle_path.path_join("engine.log")
		_check(
			FileAccess.file_exists(sealed_child_log_path)
				and not _has_engine_error(
					FileAccess.get_file_as_string(sealed_child_log_path)),
			"sealed nested child engine log contains no engine/script errors")
		var plan_text := FileAccess.get_file_as_string(
			bundle_path.path_join("launch_plan.json"))
		_check(
			not plan_text.contains("\"adoption_token\":")
				and not _has_hidden_control(bundle_path),
			"published evidence contains neither raw token nor hidden control state")

	_check(
		String(metadata_records[0]["run_id"])
			!= String(metadata_records[1]["run_id"]),
		"fresh launches have collision-safe distinct run IDs")
	_check(
		String(metadata_records[0]["run_id"]).contains("_seed-42_")
			and String(metadata_records[1]["run_id"]).contains("_seed-42_"),
		"both run IDs preserve the exact seed label")
	_check(
		int(metadata_records[0]["child_process_id"])
			!= int(metadata_records[1]["child_process_id"]),
		"each experiment executes in a different child process")
	_check(
		trajectory_hashes[0] == trajectory_hashes[1],
		"same spec and seed produce byte-identical normalized frame evidence")
	_remove_tree(root)
	AttestationTestHelperScript.remove_tree(trust_root)
	_finish()


func _launch_outer(
		root: String,
		trust_root: String,
		ordinal: int) -> Dictionary:
	var output: Array = []
	var engine_log_path := root.path_join("outer_%d.log" % ordinal)
	var arguments := [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--log-file",
		engine_log_path,
		"--script",
		"res://scripts/lab/launch_lab.gd",
		"--",
		"--experiment-spec",
		"res://data/lab/experiments/L0_0_stationary_gravity_off_v1.tres",
		"--seed",
		"42",
		"--observer",
		"full_contacts_v1",
		"--output-root",
		root,
		"--attestation-test-root",
		trust_root,
	]
	var exit_code := OS.execute(
		OS.get_executable_path(), arguments, output, true)
	var engine_log_exists := FileAccess.file_exists(engine_log_path)
	return {
		"exit_code": exit_code,
		"output": "\n".join(output),
		"engine_log_path": engine_log_path,
		"engine_log_exists": engine_log_exists,
		"engine_log_text": (
			FileAccess.get_file_as_string(engine_log_path)
			if engine_log_exists
			else ""
		),
	}


static func _has_engine_error(text: String) -> bool:
	var pattern := RegEx.create_from_string(
		"(?im)^\\s*(?:SCRIPT ERROR:|ERROR:).*$")
	return pattern.search(text) != null


static func _completed_bundles(root: String) -> Array[String]:
	var result: Array[String] = []
	var access := DirAccess.open(root)
	if access == null:
		return result
	for directory_name in access.get_directories():
		if not directory_name.ends_with(".partial"):
			result.append(root.path_join(directory_name))
	result.sort()
	return result


static func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _has_hidden_control(bundle_path: String) -> bool:
	var access := DirAccess.open(bundle_path)
	if access == null:
		return true
	for file_name in access.get_files():
		if file_name.begins_with("."):
			return true
	for directory_name in access.get_directories():
		if directory_name.begins_with("."):
			return true
	return false


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
