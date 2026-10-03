class_name LabRunFinalizer
extends RefCounted

## Parent-only publication boundary for an adopted child candidate.
##
## The child is intentionally unable to pass RunIndex's authorization check:
## authorization compares the live OS PID with the PID that atomically reserved
## the run before the child existed.

const BundleValidatorScript := preload(
	"res://scripts/lab/run_bundle_validator.gd")
const PublicationAttestationScript := preload(
	"res://scripts/lab/publication_attestation.gd")
const RunIndexScript := preload("res://scripts/lab/run_index.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")


static func record_terminal_metadata(
		partial_path: String,
		run_id: String,
		reservation_id: String,
		child_process_id: int,
		terminal_metadata: Dictionary) -> Dictionary:
	var authorization := RunIndexScript.authorize_parent_observation(
		partial_path, run_id, reservation_id, child_process_id)
	if not authorization["ok"]:
		return authorization
	var metadata_validation := _validate_terminal_metadata(
		terminal_metadata, run_id, child_process_id)
	if not metadata_validation["ok"]:
		return metadata_validation
	return TraceStoreScript.write_json_for_parent(
		_absolute(partial_path).path_join("process_metadata.json"),
		terminal_metadata)


static func finalize_candidate(
		partial_path: String,
		run_id: String,
		reservation_id: String,
		child_process_id: int,
		terminal_metadata: Dictionary,
		options: Dictionary = {}) -> Dictionary:
	var authorization := RunIndexScript.authorize_parent_finalization(
		partial_path, run_id, reservation_id, child_process_id)
	if not authorization["ok"]:
		return authorization
	var reservation: Dictionary = authorization["reservation"]
	var partial_abs := String(authorization["partial_path"])
	var final_abs := String(authorization["final_path"])
	var metadata_validation := _validate_terminal_metadata(
		terminal_metadata, run_id, child_process_id)
	if not metadata_validation["ok"]:
		return metadata_validation
	if int(terminal_metadata.get("exit_code", -1)) != 0:
		return _failure("NONZERO_CHILD_NOT_FINALIZABLE")
	if FileAccess.file_exists(partial_abs.path_join("checksums.json")):
		return _failure("CHILD_CROSSED_FINALIZATION_BOUNDARY")
	var launch_plan_path := String(reservation.get("launch_plan_path", ""))
	if launch_plan_path != partial_abs.path_join("launch_plan.json") \
			or _sha256_file(launch_plan_path) \
				!= String(reservation.get("launch_plan_sha256", "")):
		return _failure("LAUNCH_PLAN_HASH_MISMATCH")
	var candidate_check := _validate_candidate_headers(
		partial_abs, run_id)
	if not candidate_check["ok"]:
		return candidate_check
	var metadata_write := TraceStoreScript.write_json_for_parent(
		partial_abs.path_join("process_metadata.json"), terminal_metadata)
	if not metadata_write["ok"]:
		return metadata_write

	# Control state is outside the evidence hash domain and is removed before
	# immutable artifact enumeration.  A failure after this boundary remains an
	# inspectable, never-renamed .partial candidate.
	var cleanup := RunIndexScript.cleanup_control_state(partial_abs)
	if not cleanup["ok"]:
		return cleanup
	var checksums := TraceStoreScript.build_checksums_for_parent(
		partial_abs, run_id)
	var checksum_validation := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/checksums_v1.schema.json", checksums)
	if not checksum_validation["ok"]:
		return {
			"ok": false,
			"error": "CHECKSUM_SCHEMA_INVALID",
			"details": checksum_validation["errors"],
		}
	var checksum_write := TraceStoreScript.write_json_for_parent(
		partial_abs.path_join("checksums.json"), checksums)
	if not checksum_write["ok"]:
		return checksum_write
	var pre_rename_validation := BundleValidatorScript.validate_bundle(
		partial_abs, {"allow_partial": true})
	if not pre_rename_validation["ok"] \
			or not pre_rename_validation["can_finalize"]:
		return {
			"ok": false,
			"error": "CANDIDATE_VALIDATION_FAILED",
			"details": pre_rename_validation,
			"partial_path": partial_abs,
		}
	var rename := RunIndexScript.finalize_partial(
		partial_abs, final_abs, true)
	if not rename["ok"]:
		return rename
	var final_validation := BundleValidatorScript.validate_bundle(final_abs)
	if not final_validation["ok"] or not final_validation["can_finalize"]:
		return {
			"ok": false,
			"error": "FINAL_BUNDLE_VALIDATION_FAILED",
			"details": final_validation,
			"bundle_path": final_abs,
		}
	# The rename establishes the final immutable bundle path. Only after the
	# independent structural validator accepts that exact path may the parent
	# create a detached receipt in the external trust store. The receipt is
	# deliberately outside both the output root and checksums.json hash domain.
	var test_root := String(options.get(
		"attestation_test_root", "")).strip_edges()
	var attestation: Dictionary = (
		PublicationAttestationScript.attest_with_test_trust_root(
			final_abs, test_root)
		if not test_root.is_empty()
		else PublicationAttestationScript.attest_production(final_abs))
	if not bool(attestation.get("ok", false)):
		return {
			"ok": false,
			"error": "PUBLICATION_ATTESTATION_FAILED",
			"failure_code": attestation.get(
				"failure_code", attestation.get("code", "")),
			"details": attestation,
			"bundle_path": final_abs,
		}
	var required_options := {
		"attestation_requirement": "required",
	}
	if not test_root.is_empty():
		required_options["attestation_test_root"] = test_root
	var attested_validation := BundleValidatorScript.validate_bundle(
		final_abs, required_options)
	if not attested_validation["ok"] \
			or not attested_validation["can_finalize"]:
		return {
			"ok": false,
			"error": "ATTESTED_BUNDLE_VALIDATION_FAILED",
			"details": attested_validation,
			"attestation": attestation,
			"bundle_path": final_abs,
		}
	return {
		"ok": true,
		"run_id": run_id,
		"bundle_path": final_abs,
		"checksums": checksums,
		"validation": attested_validation,
		"attestation": attestation,
		"pre_attestation_validation": final_validation,
		"pre_rename_validation": pre_rename_validation,
	}


static func _validate_candidate_headers(
		partial_path: String,
		run_id: String) -> Dictionary:
	for artifact in ["manifest.json", "summary.json", "launch_plan.json"]:
		if not FileAccess.file_exists(partial_path.path_join(artifact)):
			return _failure("CANDIDATE_ARTIFACT_MISSING:%s" % artifact)
	var manifest_read := _read_json(partial_path.path_join("manifest.json"))
	if not manifest_read["ok"]:
		return manifest_read
	var summary_read := _read_json(partial_path.path_join("summary.json"))
	if not summary_read["ok"]:
		return summary_read
	var manifest: Dictionary = manifest_read["value"]
	var summary: Dictionary = summary_read["value"]
	if String(manifest.get("run_id", "")) != run_id \
			or String(summary.get("run_id", "")) != run_id:
		return _failure("CANDIDATE_RUN_ID_MISMATCH")
	if String(manifest.get("status", "")) != "COMPLETE":
		return _failure("CANDIDATE_MANIFEST_NOT_COMPLETE")
	for required_name in ["launch_plan.json", "process_metadata.json"]:
		if not required_name in manifest.get("required_artifacts", []):
			return _failure(
				"CANDIDATE_REQUIRED_ARTIFACT_MISSING:%s" % required_name)
	return {"ok": true}


static func _validate_terminal_metadata(
		metadata: Dictionary,
		run_id: String,
		child_process_id: int) -> Dictionary:
	var validation := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/process_metadata_v1.schema.json", metadata)
	if not validation["ok"]:
		return {
			"ok": false,
			"error": "PROCESS_METADATA_SCHEMA_INVALID",
			"details": validation["errors"],
		}
	if String(metadata.get("run_id", "")) != run_id:
		return _failure("PROCESS_METADATA_RUN_ID_MISMATCH")
	if int(metadata.get("child_process_id", -1)) != child_process_id:
		return _failure("PROCESS_METADATA_CHILD_PID_MISMATCH")
	if int(metadata.get("termination_observer_process_id", -1)) \
			!= OS.get_process_id():
		return _failure("PROCESS_METADATA_OBSERVER_PID_MISMATCH")
	if String(metadata.get("status", "")) == "RUNNING" \
			or metadata.get("ended_utc") == null \
			or metadata.get("exit_code") == null:
		return _failure("PROCESS_METADATA_NOT_TERMINAL")
	return {"ok": true}


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("JSON_ARTIFACT_UNREADABLE")
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file = null
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return _failure("JSON_ARTIFACT_INVALID")
	return {"ok": true, "value": parser.data}


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


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace(
		"\\", "/").simplify_path()


static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
