class_name LabTraceStore
extends RefCounted

## Append-only BR1 evidence store.
##
## Lifecycle:
##   start(output_root, run_id, running_manifest)
##   append_frame(...) / append_*() / append_record(...)
##   finalize(final_manifest, summary)
##
## finalize writes the terminal manifest and summary, seals every immutable
## artifact except checksums.json, validates the still-partial directory, then
## renames it to <run_id>. Failures before a successful rename leave the
## inspectable .partial candidate. A post-rename validation failure leaves the
## candidate at its final path and reports failure. Known destination files and
## directories are rejected, but Godot's generic rename API is not advertised
## as a cross-platform atomic no-replace primitive against a racing writer;
## detached publication attestation protects content authenticity separately.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FiniteSanitizerScript := preload("res://scripts/lab/finite_sanitizer.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")
const BundleValidatorScript := preload("res://scripts/lab/run_bundle_validator.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const RunIndexScript := preload("res://scripts/lab/run_index.gd")

const SCHEMA_BY_STREAM := {
	"frames": "res://data/lab/schemas/frame_v1.schema.json",
	"observer_minimal_frames": "res://data/lab/schemas/frame_v1.schema.json",
	"observer_full_frames": "res://data/lab/schemas/frame_v1.schema.json",
	"observer_contact_frames": "res://data/lab/schemas/frame_v1.schema.json",
	"runtime_notes": "res://data/lab/schemas/runtime_note_v1.schema.json",
	"commands": "res://data/lab/schemas/command_v1.schema.json",
	"applications": "res://data/lab/schemas/application_v1.schema.json",
	"decisions": "res://data/lab/schemas/decision_v1.schema.json",
	"interventions": "res://data/lab/schemas/intervention_v1.schema.json",
	"mechanics": "res://data/lab/schemas/mechanics_v1.schema.json",
	"events": "res://data/lab/schemas/event_v1.schema.json",
}

var _active := false
var _sealing := false
var _output_root := ""
var _partial_path := ""
var _final_path := ""
var _run_id := ""
var _line_counts: Dictionary = {}
var _running_manifest: Dictionary = {}
var _lifecycle_mode := "legacy_direct"


func start(
		output_root: String,
		run_id: String,
		running_manifest: Dictionary) -> Dictionary:
	if _active:
		return _failure(FailureCodesScript.TRACE_WRITE_FAILED, "TraceStore is already active.")
	if not _is_safe_run_id(run_id):
		return _failure(FailureCodesScript.SCHEMA_INVALID, "run_id is not a safe stable ID.")
	var finite_report := FiniteSanitizerScript.inspect(running_manifest)
	if not finite_report["ok"]:
		return _failure(
			FailureCodesScript.NONFINITE_STATE,
			"Manifest failed finite-value inspection.",
			finite_report["failures"])

	var manifest := running_manifest.duplicate(true)
	manifest["schema"] = "sporespore.lab.manifest.v1"
	manifest["run_id"] = run_id
	manifest["status"] = "RUNNING"
	if not manifest.has("resolved_configuration_sha256"):
		manifest["resolved_configuration_sha256"] = CanonicalJsonScript.sha256({
			"legacy_manifest_run_id": run_id,
		})
	if not manifest.has("applied_configuration_sha256"):
		manifest["applied_configuration_sha256"] = null
	var validation := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/manifest_v1.schema.json", manifest)
	if not validation["ok"]:
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"Running manifest failed schema validation.",
			validation["errors"])

	var absolute_root := _absolute(output_root)
	if not DirAccess.dir_exists_absolute(absolute_root):
		var root_error := DirAccess.make_dir_recursive_absolute(absolute_root)
		if root_error != OK:
			return _failure(
				FailureCodesScript.TRACE_WRITE_FAILED,
				"Could not create output root: %s" % error_string(root_error))
	var partial_path := absolute_root.path_join("%s.partial" % run_id)
	var final_path := absolute_root.path_join(run_id)
	if _path_entry_exists(partial_path) or _path_entry_exists(final_path):
		return _failure(
			FailureCodesScript.RUN_RESERVATION_COLLISION,
			"Run identity is already reserved; evidence will not be overwritten.")
	var reserve_error := DirAccess.make_dir_absolute(partial_path)
	if reserve_error != OK:
		return _failure(
			FailureCodesScript.RUN_RESERVATION_COLLISION,
			"Could not reserve partial run: %s" % error_string(reserve_error))

	var manifest_write := _write_json_atomic(partial_path.path_join("manifest.json"), manifest)
	if not manifest_write["ok"]:
		return manifest_write
	for artifact_value in manifest["required_artifacts"]:
		var artifact_name := String(artifact_value)
		if artifact_name.ends_with(".jsonl"):
			var create_result := _create_empty_file(partial_path.path_join(artifact_name))
			if not create_result["ok"]:
				return create_result
			_line_counts[artifact_name.trim_suffix(".jsonl")] = 0

	_active = true
	_output_root = absolute_root
	_partial_path = partial_path
	_final_path = final_path
	_run_id = run_id
	_running_manifest = manifest
	_lifecycle_mode = "legacy_direct"
	return {
		"ok": true,
		"run_id": _run_id,
		"partial_path": _partial_path,
		"final_path": _final_path,
	}


func adopt_reserved(
		partial_path: String,
		run_id: String,
		token_descriptor_path: String,
		launch_plan_path: String,
		running_manifest: Dictionary) -> Dictionary:
	if _active:
		return _failure(FailureCodesScript.TRACE_WRITE_FAILED, "TraceStore is already active.")
	if not _is_safe_run_id(run_id):
		return _failure(FailureCodesScript.SCHEMA_INVALID, "run_id is not a safe stable ID.")
	var finite_report := FiniteSanitizerScript.inspect(running_manifest)
	if not finite_report["ok"]:
		return _failure(
			FailureCodesScript.NONFINITE_STATE,
			"Manifest failed finite-value inspection.",
			finite_report["failures"])
	var manifest := running_manifest.duplicate(true)
	manifest["schema"] = "sporespore.lab.manifest.v1"
	manifest["run_id"] = run_id
	manifest["status"] = "RUNNING"
	if not manifest.has("resolved_configuration_sha256"):
		manifest["resolved_configuration_sha256"] = CanonicalJsonScript.sha256({
			"legacy_manifest_run_id": run_id,
		})
	if not manifest.has("applied_configuration_sha256"):
		manifest["applied_configuration_sha256"] = null
	var validation := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/manifest_v1.schema.json", manifest)
	if not validation["ok"]:
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"Running manifest failed schema validation.",
			validation["errors"])
	var adoption: Dictionary = RunIndexScript.adopt_partial(
		partial_path,
		run_id,
		token_descriptor_path,
		launch_plan_path,
		OS.get_process_id())
	if not adoption["ok"]:
		return _failure(
			FailureCodesScript.RUN_RESERVATION_COLLISION,
			"Reserved run adoption failed.",
			adoption)
	var partial_abs := String(adoption["partial_path"])
	var manifest_write := _write_json_atomic(
		partial_abs.path_join("manifest.json"), manifest)
	if not manifest_write["ok"]:
		return manifest_write
	for artifact_value in manifest["required_artifacts"]:
		var artifact_name := String(artifact_value)
		if artifact_name.ends_with(".jsonl"):
			var create_result := _create_empty_file(
				partial_abs.path_join(artifact_name))
			if not create_result["ok"]:
				return create_result
			_line_counts[artifact_name.trim_suffix(".jsonl")] = 0
	_active = true
	_output_root = partial_abs.get_base_dir()
	_partial_path = partial_abs
	_final_path = String(adoption["final_path"])
	_run_id = run_id
	_running_manifest = manifest
	_lifecycle_mode = "reserved_child"
	return {
		"ok": true,
		"run_id": _run_id,
		"partial_path": _partial_path,
		"final_path": _final_path,
		"reservation_id": adoption["reservation_id"],
		"parent_process_id": adoption["parent_process_id"],
		"child_process_id": adoption["child_process_id"],
	}


func append_frame(core_frame: Dictionary) -> Dictionary:
	return _append_frame_stream("frames", core_frame)


func append_observer_frame(stream_id: String, core_frame: Dictionary) -> Dictionary:
	if stream_id not in [
		"observer_minimal_frames",
		"observer_full_frames",
		"observer_contact_frames",
	]:
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"Unknown registered observer frame arm: %s" % stream_id)
	return _append_frame_stream(stream_id, core_frame)


func _append_frame_stream(stream_id: String, core_frame: Dictionary) -> Dictionary:
	var record := core_frame.duplicate(true)
	if record.has("schema") and String(record["schema"]) != "sporespore.lab.frame.v1":
		return _failure(FailureCodesScript.SCHEMA_INVALID, "Frame carries the wrong schema ID.")
	if record.has("run_id") and String(record["run_id"]) != _run_id:
		return _failure(FailureCodesScript.RUN_ID_MISMATCH, "Frame carries a different run_id.")
	record["schema"] = "sporespore.lab.frame.v1"
	record["run_id"] = _run_id
	return append_record(stream_id, record)


func append_runtime_note(core_note: Dictionary) -> Dictionary:
	var record := core_note.duplicate(true)
	if record.has("schema") and String(record["schema"]) != "sporespore.lab.runtime_note.v1":
		return _failure(FailureCodesScript.SCHEMA_INVALID, "Runtime note carries the wrong schema ID.")
	if record.has("run_id") and String(record["run_id"]) != _run_id:
		return _failure(FailureCodesScript.RUN_ID_MISMATCH, "Runtime note carries a different run_id.")
	record["schema"] = "sporespore.lab.runtime_note.v1"
	record["run_id"] = _run_id
	return append_record("runtime_notes", record)


func append_command(record: Dictionary) -> Dictionary:
	return append_record("commands", record)


func append_application(record: Dictionary) -> Dictionary:
	return append_record("applications", record)


func append_decision(record: Dictionary) -> Dictionary:
	return append_record("decisions", record)


func append_intervention(record: Dictionary) -> Dictionary:
	return append_record("interventions", record)


func append_mechanics(record: Dictionary) -> Dictionary:
	return append_record("mechanics", record)


func append_event(record: Dictionary) -> Dictionary:
	return append_record("events", record)


func append_record(stream_id: String, record: Dictionary) -> Dictionary:
	if not _active:
		return _failure(FailureCodesScript.TRACE_WRITE_FAILED, "TraceStore has not started.")
	if _sealing:
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"TraceStore has crossed its final seal boundary.")
	if not _is_safe_stream_id(stream_id):
		return _failure(FailureCodesScript.TRACE_WRITE_FAILED, "Unsafe stream ID.")
	if not SCHEMA_BY_STREAM.has(stream_id):
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"No versioned schema is registered for stream: %s" % stream_id)
	var finite_report := FiniteSanitizerScript.inspect(record)
	if not finite_report["ok"]:
		return _failure(
			FailureCodesScript.NONFINITE_STATE,
			"Record failed finite-value inspection before serialization.",
			finite_report["failures"])
	var record_run_id := _record_run_id(record)
	if record_run_id.is_empty() or record_run_id != _run_id:
		return _failure(
			FailureCodesScript.RUN_ID_MISMATCH,
			"Record must cross-link to this store's run_id.")
	var schema_path := String(SCHEMA_BY_STREAM.get(stream_id, ""))
	if not schema_path.is_empty() and FileAccess.file_exists(schema_path):
		var validation := SchemaValidatorScript.validate_file(schema_path, record)
		if not validation["ok"]:
			return _failure(
				FailureCodesScript.SCHEMA_INVALID,
				"Record failed %s schema validation." % stream_id,
				validation["errors"])
	var artifact_name := "%s.jsonl" % stream_id
	var path := _partial_path.path_join(artifact_name)
	if not FileAccess.file_exists(path):
		var create_result := _create_empty_file(path)
		if not create_result["ok"]:
			return create_result
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"Could not open append-only stream: %s" % artifact_name)
	file.seek_end()
	file.store_line(CanonicalJsonScript.stringify(record))
	file.flush()
	var write_error := file.get_error()
	file = null
	if write_error != OK:
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"Appending %s failed: %s" % [artifact_name, error_string(write_error)])
	_line_counts[stream_id] = int(_line_counts.get(stream_id, 0)) + 1
	return {
		"ok": true,
		"stream_id": stream_id,
		"record_index": int(_line_counts[stream_id]) - 1,
	}


func flush() -> Dictionary:
	# append_record closes each handle after FileAccess.flush(), so reaching this
	# method means every accepted record is already durable at the API boundary.
	if not _active:
		return _failure(FailureCodesScript.TRACE_WRITE_FAILED, "TraceStore has not started.")
	return {"ok": true, "line_counts": line_counts()}


func finalize(final_manifest: Dictionary, summary: Dictionary) -> Dictionary:
	if _lifecycle_mode == "reserved_child":
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"Reserved child processes may prepare candidate evidence but cannot checksum or rename it.")
	var prepared := _prepare_candidate_artifacts(final_manifest, summary)
	if not prepared["ok"]:
		return prepared

	var checksums := _build_checksums(_partial_path, _run_id)
	var checksum_validation := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/checksums_v1.schema.json", checksums)
	if not checksum_validation["ok"]:
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"Generated checksums failed schema validation.",
			checksum_validation["errors"])
	var checksum_write := _write_json_atomic(
		_partial_path.path_join("checksums.json"), checksums)
	if not checksum_write["ok"]:
		return checksum_write

	var bundle_validation := BundleValidatorScript.validate_bundle(
		_partial_path, {"allow_partial": true})
	if not bundle_validation["ok"] or not bundle_validation["can_finalize"]:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Bundle validation failed; .partial evidence was preserved.",
			bundle_validation["errors"])
	if _path_entry_exists(_final_path):
		return _failure(
			FailureCodesScript.RUN_RESERVATION_COLLISION,
			"Completed run path already exists; .partial evidence was preserved.")
	var rename_error := FAILED
	# Windows can briefly retain a sharing handle after validation closes the
	# bundle's files. Match the parent-owned RunIndex publication boundary:
	# retry only this exact source/destination pair for a bounded 250 ms, never
	# replace an existing final path, and stop if the candidate disappears.
	for attempt in 25:
		if _path_entry_exists(_final_path):
			return _failure(
				FailureCodesScript.RUN_RESERVATION_COLLISION,
				"Completed run path appeared during publication; .partial evidence was preserved.")
		rename_error = DirAccess.rename_absolute(_partial_path, _final_path)
		if rename_error == OK:
			break
		if not DirAccess.dir_exists_absolute(_partial_path):
			break
		OS.delay_msec(10)
	if rename_error != OK:
		if _path_entry_exists(_final_path):
			return _failure(
				FailureCodesScript.RUN_RESERVATION_COLLISION,
				"Completed run path appeared during publication; .partial evidence was preserved.")
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"Validated bundle could not be renamed: %s" % error_string(rename_error))
	_active = false
	var final_validation := BundleValidatorScript.validate_bundle(_final_path)
	if not final_validation["ok"] or not final_validation["can_finalize"]:
		return {
			"ok": false,
			"code": FailureCodesScript.EVIDENCE_INVALID,
			"message": "Completed bundle failed post-rename validation.",
			"details": final_validation["errors"],
			"run_id": _run_id,
			"bundle_path": _final_path,
			"checksums": checksums,
			"validation": final_validation,
			"pre_rename_validation": bundle_validation,
		}
	return {
		"ok": true,
		"run_id": _run_id,
		"bundle_path": _final_path,
		"checksums": checksums,
		"validation": final_validation,
		"pre_rename_validation": bundle_validation,
	}


func prepare_candidate(final_manifest: Dictionary, summary: Dictionary) -> Dictionary:
	if _lifecycle_mode != "reserved_child":
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"Only an adopted child run can cross the parent-finalized candidate boundary.")
	var prepared := _prepare_candidate_artifacts(final_manifest, summary)
	if not prepared["ok"]:
		return prepared
	_active = false
	return {
		"ok": true,
		"run_id": _run_id,
		"candidate_path": _partial_path,
		"final_path": _final_path,
		"status": "candidate_ready",
	}


func _prepare_candidate_artifacts(
		final_manifest: Dictionary,
		summary: Dictionary) -> Dictionary:
	if not _active:
		return _failure(FailureCodesScript.TRACE_WRITE_FAILED, "TraceStore has not started.")
	if _sealing:
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"TraceStore finalize has already crossed the immutable seal boundary.")
	var manifest := final_manifest.duplicate(true)
	manifest["schema"] = "sporespore.lab.manifest.v1"
	manifest["run_id"] = _run_id
	manifest["status"] = "COMPLETE"
	if not manifest.has("resolved_configuration_sha256"):
		manifest["resolved_configuration_sha256"] = _running_manifest[
			"resolved_configuration_sha256"]
	if not manifest.has("applied_configuration_sha256"):
		manifest["applied_configuration_sha256"] = _running_manifest[
			"applied_configuration_sha256"]
	if not manifest.has("finalized_utc"):
		manifest["finalized_utc"] = _utc_now()
	if manifest.get("required_artifacts", []) != _running_manifest.get("required_artifacts", []):
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"Final manifest cannot change the sealed required_artifacts inventory.")

	var summary_record := summary.duplicate(true)
	summary_record["schema"] = "sporespore.lab.summary.v1"
	summary_record["run_id"] = _run_id
	var manifest_validation := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/manifest_v1.schema.json", manifest)
	if not manifest_validation["ok"]:
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"Final manifest failed schema validation.",
			manifest_validation["errors"])
	var summary_validation := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/summary_v1.schema.json", summary_record)
	if not summary_validation["ok"]:
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"Summary failed schema validation.",
			summary_validation["errors"])
	_sealing = true
	var summary_write := _write_json_atomic(
		_partial_path.path_join("summary.json"), summary_record)
	if not summary_write["ok"]:
		return summary_write
	var manifest_write := _write_json_atomic(
		_partial_path.path_join("manifest.json"), manifest)
	if not manifest_write["ok"]:
		return manifest_write
	return {
		"ok": true,
		"run_id": _run_id,
		"candidate_path": _partial_path,
	}


func leave_partial() -> Dictionary:
	if not _active:
		return _failure(FailureCodesScript.TRACE_WRITE_FAILED, "TraceStore has not started.")
	_active = false
	return {
		"ok": true,
		"run_id": _run_id,
		"partial_path": _partial_path,
		"status": "partial",
	}


func line_counts() -> Dictionary:
	return _line_counts.duplicate(true)


func partial_path() -> String:
	return _partial_path


func run_id() -> String:
	return _run_id


static func read_jsonl(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure(FailureCodesScript.ARTIFACT_MISSING, "JSONL stream does not exist.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(FailureCodesScript.ARTIFACT_MISSING, "JSONL stream could not be opened.")
	var records: Array = []
	var line_index := 0
	while file.get_position() < file.get_length():
		var line := file.get_line()
		var parser := JSON.new()
		var parse_error := parser.parse(line)
		if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
			return _failure(
				FailureCodesScript.JSON_PARSE_FAILED,
				"JSONL line %d is invalid: %s" % [line_index, parser.get_error_message()])
		records.append(parser.data)
		line_index += 1
	return {"ok": true, "records": records}


static func build_checksums_for_parent(
		directory: String,
		run_id: String) -> Dictionary:
	return _build_checksums(_absolute(directory), run_id)


static func write_json_for_parent(path: String, value: Variant) -> Dictionary:
	return _write_json_atomic(_absolute(path), value)


static func _build_checksums(directory: String, run_id: String) -> Dictionary:
	var artifacts: Dictionary = {}
	var access := DirAccess.open(directory)
	if access == null:
		return {}
	var names: Array[String] = []
	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		if not access.current_is_dir() \
				and name != "checksums.json" \
				and not name.ends_with(".tmp") \
				and not name.ends_with(".previous"):
			names.append(name)
		name = access.get_next()
	access.list_dir_end()
	names.sort()
	for artifact_name in names:
		var path := directory.path_join(artifact_name)
		var kind := "opaque"
		var records: Variant = null
		if artifact_name.ends_with(".jsonl"):
			kind = "jsonl"
			records = _count_jsonl_records(path)
		elif artifact_name.ends_with(".json"):
			kind = "json"
		artifacts[artifact_name] = {
			"sha256": _sha256_file(path),
			"bytes": _file_size(path),
			"kind": kind,
			"records": records,
		}
	return {
		"schema": "sporespore.lab.checksums.v1",
		"run_id": run_id,
		"algorithm": "sha256",
		"artifact_count": artifacts.size(),
		"artifacts": artifacts,
	}


static func _write_json_atomic(path: String, value: Variant) -> Dictionary:
	var finite_report := FiniteSanitizerScript.inspect(value)
	if not finite_report["ok"]:
		return _failure(
			FailureCodesScript.NONFINITE_STATE,
			"JSON artifact failed finite-value inspection.",
			finite_report["failures"])
	var temporary := "%s.tmp" % path
	var backup := "%s.previous" % path
	if FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure(FailureCodesScript.TRACE_WRITE_FAILED, "Could not open temporary artifact.")
	file.store_string(CanonicalJsonScript.stringify(value))
	file.store_string("\n")
	file.flush()
	var write_error := file.get_error()
	file = null
	if write_error != OK:
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"Temporary artifact write failed: %s" % error_string(write_error))

	# Most supported platforms atomically replace on rename. If the platform
	# refuses an existing destination, retain a recoverable previous file while
	# completing a two-rename fallback.
	var rename_error := DirAccess.rename_absolute(temporary, path)
	if rename_error == OK:
		return {"ok": true}
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(path, backup)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary)
			return _failure(
				FailureCodesScript.TRACE_WRITE_FAILED,
				"Could not stage prior artifact for replacement.")
		rename_error = DirAccess.rename_absolute(temporary, path)
		if rename_error != OK:
			DirAccess.rename_absolute(backup, path)
			return _failure(
				FailureCodesScript.TRACE_WRITE_FAILED,
				"Could not install replacement artifact.")
		DirAccess.remove_absolute(backup)
		return {"ok": true}
	return _failure(
		FailureCodesScript.TRACE_WRITE_FAILED,
		"Could not install artifact: %s" % error_string(rename_error))


static func _create_empty_file(path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		return {"ok": true}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure(FailureCodesScript.TRACE_WRITE_FAILED, "Could not create stream file.")
	file.flush()
	var write_error := file.get_error()
	file = null
	if write_error != OK:
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"Could not flush stream file: %s" % error_string(write_error))
	return {"ok": true}


static func _record_run_id(record: Dictionary) -> String:
	if record.has("run_id"):
		return String(record["run_id"])
	if typeof(record.get("payload")) == TYPE_DICTIONARY and record["payload"].has("run_id"):
		return String(record["payload"]["run_id"])
	return ""


static func _count_jsonl_records(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var count := 0
	while file.get_position() < file.get_length():
		file.get_line()
		count += 1
	return count


static func _sha256_file(path: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	const CHUNK_SIZE := 65536
	while file.get_position() < file.get_length():
		var remaining := file.get_length() - file.get_position()
		context.update(file.get_buffer(mini(CHUNK_SIZE, remaining)))
	return "sha256:%s" % context.finish().hex_encode()


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else -1


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/")


static func _path_entry_exists(path: String) -> bool:
	return (
		FileAccess.file_exists(path)
		or DirAccess.dir_exists_absolute(path)
	)


static func _utc_now() -> String:
	var timestamp := Time.get_datetime_string_from_system(true, false)
	return timestamp if timestamp.ends_with("Z") else "%sZ" % timestamp


static func _is_safe_run_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$")
	return regex.search(value) != null


static func _is_safe_stream_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-z][a-z0-9_]{0,63}$")
	return regex.search(value) != null


static func _failure(code: String, message: String, details: Variant = []) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"message": message,
		"details": details,
	}
