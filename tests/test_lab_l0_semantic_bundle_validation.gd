extends SceneTree

const BundleValidatorScript := preload(
	"res://scripts/lab/run_bundle_validator.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const LabRunnerScript := preload("res://scripts/lab/lab_runner.gd")
const SpecCompilerScript := preload("res://scripts/lab/spec_compiler.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")

const RECOMPUTER_ID := "sporespore.lab.l0_unary_metric_recomputer.v1"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab L0 semantic bundle validation ===")
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
	_check(bool(compiled.get("ok", false)), "L0.0 experiment compiles")
	if not bool(compiled.get("ok", false)):
		_finish()
		return

	var root := ProjectSettings.globalize_path(
		"res://.tmp/lab_l0_semantic_bundle_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		]).replace("\\", "/")
	var runner = LabRunnerScript.new()
	var run_result: Dictionary = await runner.run(
		self,
		compiled["experiment"],
		root,
		{
			"resource_path": spec_path,
			"resource_sha256": resource_sha,
		})
	var bundle_path := String(run_result.get("artifacts", ""))
	_check(
		run_result.get("termination") == "completed"
			and int(run_result.get("exit_code", -1)) == 2
			and not bundle_path.is_empty(),
		"direct dirty-source run completes as development-only evidence")
	if bundle_path.is_empty() or not DirAccess.dir_exists_absolute(bundle_path):
		_remove_tree(root)
		_finish()
		return

	var baseline := BundleValidatorScript.validate_bundle(bundle_path)
	var baseline_semantic: Dictionary = baseline.get(
		"stats", {}).get("semantic_verifiers", {}).get(RECOMPUTER_ID, {})
	_check(
		bool(baseline.get("ok", false))
			and bool(baseline_semantic.get("ok", false)),
		"finalized bundle passes independent unary semantic recomputation")
	_check(
		int(baseline_semantic.get("verified_metric_count", -1)) == 5,
		"validator independently verifies all five L0.0 unary metrics")

	# The manifest is evidence, not authority. Current L0 bundles cannot make
	# mandatory provenance disappear by editing their own inventory and then
	# rebuilding internally consistent checksums.
	_exercise_required_artifact_omission(
		bundle_path, "configuration.json")
	_exercise_required_artifact_omission(
		bundle_path, "process_metadata.json")
	_exercise_outer_launch_requirements(bundle_path)

	# Change a summary conclusion, then rebuild checksums. A checksum-only
	# validator would accept this internally consistent forgery; a semantic
	# validator must still reject it because the raw frames did not change.
	var summary_path := bundle_path.path_join("summary.json")
	var summary := _read_json(summary_path)
	var metric_index := _metric_index(summary, "max_position_error_m")
	_check(metric_index >= 0, "target metric exists in the sealed summary")
	if metric_index < 0:
		_remove_tree(root)
		_finish()
		return
	summary["metrics"][metric_index]["value"] = (
		float(summary["metrics"][metric_index]["value"]) + 0.25)
	var summary_write := TraceStoreScript.write_json_for_parent(
		summary_path, summary)
	_check(bool(summary_write.get("ok", false)), "forged summary writes")
	var run_id := String(summary.get("run_id", ""))
	var rebuilt_checksums := TraceStoreScript.build_checksums_for_parent(
		bundle_path, run_id)
	var checksum_write := TraceStoreScript.write_json_for_parent(
		bundle_path.path_join("checksums.json"), rebuilt_checksums)
	_check(bool(checksum_write.get("ok", false)), "forged checksums rebuild")

	var forged := BundleValidatorScript.validate_bundle(bundle_path)
	_check(
		not bool(forged.get("ok", true)),
		"checksum-consistent forged metric is rejected")
	_check(
		not _has_code(
			forged.get("errors", []),
			FailureCodesScript.CHECKSUM_MISMATCH),
		"rejection is not manufactured by a stale checksum")
	_check(
		_has_semantic_error(
			forged.get("errors", []),
			"METRIC_VALUE_MISMATCH"),
		"rejection names the independently reproduced metric mismatch")

	_remove_tree(root)
	_finish()


func _exercise_required_artifact_omission(
		bundle_path: String,
		artifact_name: String) -> void:
	var manifest_path := bundle_path.path_join("manifest.json")
	var artifact_path := bundle_path.path_join(artifact_name)
	var original_manifest := _read_json(manifest_path)
	var original_artifact := _read_json(artifact_path)
	var forged_manifest: Dictionary = original_manifest.duplicate(true)
	var forged_required: Array = forged_manifest.get(
		"required_artifacts", []).duplicate()
	forged_required.erase(artifact_name)
	forged_manifest["required_artifacts"] = forged_required
	var manifest_write := TraceStoreScript.write_json_for_parent(
		manifest_path, forged_manifest)
	var remove_error := DirAccess.remove_absolute(artifact_path)
	var resealed := (
		bool(manifest_write.get("ok", false))
		and remove_error == OK
		and _rebuild_checksums(
			bundle_path, String(forged_manifest.get("run_id", ""))))
	_check(
		resealed,
		"self-omission forgery is checksum-consistent for %s" % artifact_name)
	var forged := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if resealed
		else {})
	_check(
		resealed
			and not bool(forged.get("ok", true))
			and _has_missing_artifact_error(
				forged.get("errors", []), artifact_name)
			and not _has_code(
				forged.get("errors", []),
				FailureCodesScript.CHECKSUM_MISMATCH),
		"current L0 contract rejects self-omitted %s" % artifact_name)

	var artifact_restore := TraceStoreScript.write_json_for_parent(
		artifact_path, original_artifact)
	var manifest_restore := TraceStoreScript.write_json_for_parent(
		manifest_path, original_manifest)
	var restore_ok := (
		bool(artifact_restore.get("ok", false))
		and bool(manifest_restore.get("ok", false))
		and _rebuild_checksums(
			bundle_path, String(original_manifest.get("run_id", ""))))
	var restored_validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if restore_ok
		else {})
	_check(
		restore_ok and bool(restored_validation.get("ok", false)),
		"bundle restores after %s omission attack" % artifact_name)


func _exercise_outer_launch_requirements(bundle_path: String) -> void:
	var manifest_path := bundle_path.path_join("manifest.json")
	var original_manifest := _read_json(manifest_path)
	var run_id := String(original_manifest.get("run_id", ""))

	var outer_without_plan: Dictionary = original_manifest.duplicate(true)
	outer_without_plan["process_isolation"] = (
		"outer_parent_reserved_fresh_godot_v1")
	var outer_written := TraceStoreScript.write_json_for_parent(
		manifest_path, outer_without_plan)
	var outer_resealed := (
		bool(outer_written.get("ok", false))
		and _rebuild_checksums(bundle_path, run_id))
	var outer_validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if outer_resealed
		else {})
	_check(
		outer_resealed
			and not bool(outer_validation.get("ok", true))
			and _has_missing_artifact_error(
				outer_validation.get("errors", []), "launch_plan.json"),
		"outer-parent isolation cannot omit its launch plan")

	var promotion_without_outer: Dictionary = original_manifest.duplicate(true)
	promotion_without_outer["execution_mode"] = "promotion"
	var promotion_written := TraceStoreScript.write_json_for_parent(
		manifest_path, promotion_without_outer)
	var promotion_resealed := (
		bool(promotion_written.get("ok", false))
		and _rebuild_checksums(bundle_path, run_id))
	var promotion_validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if promotion_resealed
		else {})
	_check(
		promotion_resealed
			and not bool(promotion_validation.get("ok", true))
			and _has_error_at(
				promotion_validation.get("errors", []),
				FailureCodesScript.EVIDENCE_INVALID,
				"/manifest.json/process_isolation")
			and _has_missing_artifact_error(
				promotion_validation.get("errors", []),
				"launch_plan.json"),
		"promotion requires both fresh-process isolation and a launch plan")

	var manifest_restore := TraceStoreScript.write_json_for_parent(
		manifest_path, original_manifest)
	var restore_ok := (
		bool(manifest_restore.get("ok", false))
		and _rebuild_checksums(bundle_path, run_id))
	var restored_validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if restore_ok
		else {})
	_check(
		restore_ok and bool(restored_validation.get("ok", false)),
		"bundle restores after process-provenance attacks")


static func _rebuild_checksums(bundle_path: String, run_id: String) -> bool:
	var rebuilt := TraceStoreScript.build_checksums_for_parent(
		bundle_path, run_id)
	var write := TraceStoreScript.write_json_for_parent(
		bundle_path.path_join("checksums.json"), rebuilt)
	return bool(write.get("ok", false))


static func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _metric_index(summary: Dictionary, metric_id: String) -> int:
	for index in summary.get("metrics", []).size():
		if String(summary["metrics"][index].get("metric_id", "")) == metric_id:
			return index
	return -1


static func _has_code(errors: Array, code: String) -> bool:
	for error_value in errors:
		if String(error_value.get("code", "")) == code:
			return true
	return false


static func _has_error_at(
		errors: Array,
		code: String,
		path: String) -> bool:
	for error_value in errors:
		if (
			String(error_value.get("code", "")) == code
			and String(error_value.get("path", "")) == path
		):
			return true
	return false


static func _has_missing_artifact_error(
		errors: Array,
		artifact_name: String) -> bool:
	for error_value in errors:
		if (
			String(error_value.get("code", ""))
				== FailureCodesScript.ARTIFACT_MISSING
			and artifact_name in String(error_value.get("message", ""))
		):
			return true
	return false


static func _has_semantic_error(errors: Array, semantic_code: String) -> bool:
	for error_value in errors:
		if (
			String(error_value.get("code", ""))
				== FailureCodesScript.EVIDENCE_INVALID
			and semantic_code in String(error_value.get("message", ""))
		):
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
