class_name LabProcessLauncher
extends RefCounted

## Frozen launch-plan construction and process metadata.
##
## The launch plan contains the exact argument vector passed to
## OS.create_process().  It contains only the hash of the one-shot adoption
## token; the token itself lives in a hidden descriptor consumed on adoption.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")


static func make_run_id(experiment_id: String, seed_label: String) -> String:
	var timestamp := Time.get_datetime_string_from_system(true, true)
	timestamp = timestamp.replace("-", "").replace(":", "").replace(" ", "T")
	var crypto := Crypto.new()
	var nonce := crypto.generate_random_bytes(16).hex_encode()
	return "%sZ_%s_seed-%s_pid-%d_%s" % [
		timestamp,
		_sanitize_id(experiment_id),
		_sanitize_id(seed_label),
		OS.get_process_id(),
		nonce,
	]


static func build_launch_plan(
		reservation: Dictionary,
		executable: String,
		engine_arguments: Array,
		user_arguments: Array,
		requested_user_arguments: Array,
		working_directory: String,
		log_paths: Dictionary,
		experiment_identity: Dictionary) -> Dictionary:
	var exact_arguments: Array = []
	exact_arguments.append_array(engine_arguments)
	exact_arguments.append("--")
	exact_arguments.append_array(user_arguments)
	var payload := {
		"run_id": String(reservation["run_id"]),
		"reservation_id": String(reservation["reservation_id"]),
		"adoption_token_sha256":
			String(reservation["adoption_token_sha256"]),
		"token_descriptor_path":
			String(reservation["token_descriptor_path"]),
		"partial_path": String(reservation["partial_path"]),
		"final_path": String(reservation["final_path"]),
		"output_root": String(reservation["partial_path"]).get_base_dir(),
		"parent_process_id": int(reservation["parent_process_id"]),
		"executable": executable,
		"arguments": exact_arguments,
		"engine_arguments": engine_arguments,
		"user_arguments": user_arguments,
		"requested_user_arguments": requested_user_arguments,
		"working_directory": working_directory,
		"log_paths": log_paths,
		"experiment_identity": experiment_identity,
		"created_utc": _utc_now(),
	}
	return FrozenValueScript.snapshot({
		"schema": "sporespore.lab.launch_plan.v1",
		"run_id": reservation["run_id"],
		"reservation_id": reservation["reservation_id"],
		"status": "FROZEN",
		"payload_sha256": CanonicalJsonScript.sha256(payload),
		"payload": payload,
	})


static func write_launch_plan(path: String, plan: Dictionary) -> Dictionary:
	var validation := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/launch_plan_v1.schema.json", plan)
	if not validation["ok"]:
		return {
			"ok": false,
			"error": "LAUNCH_PLAN_SCHEMA_INVALID",
			"details": validation["errors"],
		}
	if CanonicalJsonScript.sha256(plan["payload"]) \
			!= String(plan["payload_sha256"]):
		return {"ok": false, "error": "LAUNCH_PLAN_PAYLOAD_HASH_MISMATCH"}
	var absolute := ProjectSettings.globalize_path(path).replace(
		"\\", "/").simplify_path()
	if FileAccess.file_exists(absolute):
		return {"ok": false, "error": "LAUNCH_PLAN_ALREADY_EXISTS"}
	var temporary := "%s.tmp" % absolute
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "LAUNCH_PLAN_OPEN_FAILED"}
	file.store_string(CanonicalJsonScript.stringify(plan) + "\n")
	file.flush()
	var write_error := file.get_error()
	file = null
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return {
			"ok": false,
			"error": "LAUNCH_PLAN_WRITE_FAILED",
			"code": write_error,
		}
	var rename_error := DirAccess.rename_absolute(temporary, absolute)
	if rename_error != OK:
		return {
			"ok": false,
			"error": "LAUNCH_PLAN_INSTALL_FAILED",
			"code": rename_error,
		}
	return {
		"ok": true,
		"path": absolute,
		"sha256": _sha256_file(absolute),
		"payload_sha256": plan["payload_sha256"],
	}


static func load_launch_plan(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path).replace(
		"\\", "/").simplify_path()
	if not FileAccess.file_exists(absolute):
		return {"ok": false, "error": "LAUNCH_PLAN_MISSING"}
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "LAUNCH_PLAN_UNREADABLE"}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file = null
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "LAUNCH_PLAN_JSON_INVALID"}
	var plan: Dictionary = parser.data
	var validation := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/launch_plan_v1.schema.json", plan)
	if not validation["ok"]:
		return {
			"ok": false,
			"error": "LAUNCH_PLAN_SCHEMA_INVALID",
			"details": validation["errors"],
		}
	if CanonicalJsonScript.sha256(plan["payload"]) \
			!= String(plan["payload_sha256"]):
		return {"ok": false, "error": "LAUNCH_PLAN_PAYLOAD_HASH_MISMATCH"}
	return {
		"ok": true,
		"path": absolute,
		"sha256": _sha256_file(absolute),
		"plan": FrozenValueScript.snapshot(plan),
	}


static func running_process_metadata(
		run_id: String,
		executable: String,
		arguments: Array,
		working_directory: String,
		log_paths: Dictionary,
		parent_process_id := -1,
		user_arguments: Array = [],
		argument_capture_quality := "launcher_exact",
		child_process_id := -2,
		lifecycle: Dictionary = {}) -> Dictionary:
	if child_process_id == -2:
		child_process_id = OS.get_process_id()
	return FrozenValueScript.snapshot({
		"schema": "sporespore.lab.process_metadata.v1",
		"run_id": run_id,
		"status": "RUNNING",
		"parent_process_id": parent_process_id,
		"child_process_id": child_process_id,
		"executable": executable,
		"arguments": arguments,
		"engine_arguments": lifecycle.get(
			"engine_arguments", arguments),
		"user_arguments": user_arguments,
		"requested_user_arguments": lifecycle.get(
			"requested_user_arguments", user_arguments),
		"argument_capture_quality": argument_capture_quality,
		"working_directory": working_directory,
		"started_utc": lifecycle.get("started_utc", _utc_now()),
		"ended_utc": null,
		"exit_disposition": null,
		"exit_code": null,
		"log_paths": log_paths,
		"reservation_id": lifecycle.get("reservation_id", null),
		"launch_plan_path": lifecycle.get("launch_plan_path", null),
		"launch_plan_sha256": lifecycle.get("launch_plan_sha256", null),
		"launch_plan_payload_sha256": lifecycle.get(
			"launch_plan_payload_sha256", null),
		"adoption_token_sha256": lifecycle.get(
			"adoption_token_sha256", null),
		"partial_path": lifecycle.get("partial_path", null),
		"final_path": lifecycle.get("final_path", null),
		"termination_observer_process_id": null,
	})


static func terminal_process_metadata(
		running_metadata: Dictionary,
		exit_code: int,
		exit_disposition: String,
		status: String = "COMPLETE",
		termination_observer_process_id: int = OS.get_process_id()) -> Dictionary:
	var terminal := running_metadata.duplicate(true)
	terminal["status"] = status
	terminal["ended_utc"] = _utc_now()
	terminal["exit_disposition"] = exit_disposition
	terminal["exit_code"] = exit_code
	terminal["termination_observer_process_id"] = (
		termination_observer_process_id)
	return FrozenValueScript.snapshot(terminal)


static func launch_async(executable: String, arguments: Array) -> Dictionary:
	var packed := PackedStringArray()
	for argument in arguments:
		packed.append(String(argument))
	var child_pid := OS.create_process(executable, packed, false)
	return {
		"ok": child_pid > 0,
		"child_process_id": child_pid,
		"error": "" if child_pid > 0 else "CHILD_PROCESS_CREATE_FAILED",
	}


static func launch_sync(executable: String, arguments: Array) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(executable, arguments, output, true)
	return {
		"ok": exit_code >= 0,
		"exit_code": exit_code,
		"combined_output": "\n".join(output),
	}


static func captured_log(path: String, mechanism: String) -> Dictionary:
	return {
		"status": "captured",
		"path": path,
		"mechanism": mechanism,
		"reason": null,
	}


static func unavailable_log(
		reason: String,
		mechanism := "not_captured") -> Dictionary:
	return {
		"status": "unavailable",
		"path": null,
		"mechanism": mechanism,
		"reason": reason,
	}


static func _sanitize_id(value: String) -> String:
	const ALPHANUMERIC := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	const ALLOWED := ALPHANUMERIC + "._-"
	var out := ""
	for c in value:
		if ALLOWED.contains(c):
			out += c
		else:
			out += "_"
	if out.is_empty():
		return "unnamed"
	if not ALPHANUMERIC.contains(out.substr(0, 1)):
		out = "id%s" % out
	return out


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


static func _utc_now() -> String:
	var value := Time.get_datetime_string_from_system(true, false)
	return value if value.ends_with("Z") else "%sZ" % value
