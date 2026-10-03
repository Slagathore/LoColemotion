class_name LabRunIndex
extends RefCounted

## Parent-owned run reservation and one-shot child adoption.
##
## The public evidence artifact is launch_plan.json.  The files beginning with
## a dot are lifecycle control state.  They are deliberately excluded from the
## immutable bundle and must be consumed by the parent finalizer before hashes
## are calculated.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const RESERVATION_FILE := ".reservation.json"
const TOKEN_FILE := ".adoption_token"
const ADOPTION_CLAIM_DIRECTORY := ".adoption_claim"
const RESERVATION_SCHEMA := "sporespore.lab.reservation_control.v1"


static func reserve_partial(
		output_root: String,
		run_id: String,
		parent_process_id: int = OS.get_process_id()) -> Dictionary:
	if not _is_safe_run_id(run_id):
		return _failure("INVALID_RUN_ID")
	if parent_process_id <= 0:
		return _failure("INVALID_PARENT_PROCESS_ID")
	var root_abs := _absolute(output_root)
	if root_abs.is_empty():
		return _failure("INVALID_OUTPUT_ROOT")
	var error := DirAccess.make_dir_recursive_absolute(root_abs)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return _failure("OUTPUT_ROOT_CREATE_FAILED", error)
	var partial_abs := root_abs.path_join("%s.partial" % run_id)
	var final_abs := root_abs.path_join(run_id)
	if _path_entry_exists(partial_abs) \
			or _path_entry_exists(final_abs):
		return _failure("RUN_ID_ALREADY_RESERVED")

	# Directory creation is the cross-process atomic reservation primitive.
	error = DirAccess.make_dir_absolute(partial_abs)
	if error != OK:
		return _failure("RUN_RESERVATION_FAILED", error)

	var crypto := Crypto.new()
	var reservation_id := crypto.generate_random_bytes(16).hex_encode()
	var adoption_token := crypto.generate_random_bytes(32).hex_encode()
	if reservation_id.length() != 32 or adoption_token.length() != 64:
		_remove_empty_reservation(partial_abs)
		return _failure("RESERVATION_RANDOMNESS_FAILED")
	var token_path := partial_abs.path_join(TOKEN_FILE)
	var token_write := _write_text_exclusive(token_path, adoption_token + "\n")
	if not token_write["ok"]:
		_remove_empty_reservation(partial_abs)
		return token_write
	var reservation := {
		"schema": RESERVATION_SCHEMA,
		"reservation_id": reservation_id,
		"run_id": run_id,
		"status": "RESERVED",
		"parent_process_id": parent_process_id,
		"child_process_id": null,
		"partial_path": partial_abs,
		"final_path": final_abs,
		"token_descriptor_path": token_path,
		"adoption_token_sha256": _secret_sha256(adoption_token),
		"launch_plan_path": null,
		"launch_plan_sha256": null,
		"created_utc": _utc_now(),
		"adopted_utc": null,
	}
	var reservation_write := _write_json_atomic(
		partial_abs.path_join(RESERVATION_FILE), reservation, false)
	if not reservation_write["ok"]:
		DirAccess.remove_absolute(token_path)
		_remove_empty_reservation(partial_abs)
		return reservation_write
	return {
		"ok": true,
		"run_id": run_id,
		"reservation_id": reservation_id,
		"adoption_token": adoption_token,
		"adoption_token_sha256": reservation["adoption_token_sha256"],
		"token_descriptor_path": token_path,
		"reservation_path": partial_abs.path_join(RESERVATION_FILE),
		"partial_path": partial_abs,
		"final_path": final_abs,
		"parent_process_id": parent_process_id,
	}


static func bind_launch_plan(
		partial_path: String,
		run_id: String,
		adoption_token: String,
		launch_plan_path: String,
		launch_plan_sha256: String) -> Dictionary:
	var loaded := _load_reservation(partial_path)
	if not loaded["ok"]:
		return loaded
	var reservation: Dictionary = loaded["reservation"]
	var identity := _validate_identity(
		reservation, partial_path, run_id, adoption_token)
	if not identity["ok"]:
		return identity
	if String(reservation["status"]) != "RESERVED":
		return _failure("RESERVATION_NOT_BINDABLE")
	if reservation["launch_plan_path"] != null \
			or reservation["launch_plan_sha256"] != null:
		return _failure("LAUNCH_PLAN_ALREADY_BOUND")
	var plan_abs := _absolute(launch_plan_path)
	if plan_abs != _absolute(partial_path).path_join("launch_plan.json"):
		return _failure("LAUNCH_PLAN_PATH_MISMATCH")
	if not FileAccess.file_exists(plan_abs):
		return _failure("LAUNCH_PLAN_MISSING")
	if _sha256_file(plan_abs) != launch_plan_sha256:
		return _failure("LAUNCH_PLAN_HASH_MISMATCH")
	reservation["launch_plan_path"] = plan_abs
	reservation["launch_plan_sha256"] = launch_plan_sha256
	var write := _write_json_atomic(
		_absolute(partial_path).path_join(RESERVATION_FILE),
		reservation,
		true)
	if not write["ok"]:
		return write
	return {
		"ok": true,
		"reservation_id": reservation["reservation_id"],
		"launch_plan_path": plan_abs,
		"launch_plan_sha256": launch_plan_sha256,
	}


static func adopt_partial(
		partial_path: String,
		run_id: String,
		token_descriptor_path: String,
		launch_plan_path: String,
		child_process_id: int = OS.get_process_id()) -> Dictionary:
	var loaded := _load_reservation(partial_path)
	if not loaded["ok"]:
		return loaded
	var reservation: Dictionary = loaded["reservation"]
	var partial_abs := _absolute(partial_path)
	if String(reservation.get("status", "")) != "RESERVED" \
			or DirAccess.dir_exists_absolute(
				partial_abs.path_join(ADOPTION_CLAIM_DIRECTORY)):
		return _failure("RUN_ALREADY_ADOPTED")
	if child_process_id <= 0:
		return _failure("INVALID_CHILD_PROCESS_ID")
	var descriptor_abs := _absolute(token_descriptor_path)
	if descriptor_abs != String(reservation.get("token_descriptor_path", "")):
		return _failure("TOKEN_DESCRIPTOR_PATH_MISMATCH")
	if not FileAccess.file_exists(descriptor_abs):
		return _failure("ADOPTION_TOKEN_MISSING")
	var token_file := FileAccess.open(descriptor_abs, FileAccess.READ)
	if token_file == null:
		return _failure("ADOPTION_TOKEN_UNREADABLE")
	var adoption_token := token_file.get_as_text().strip_edges()
	token_file = null
	var identity := _validate_identity(
		reservation, partial_abs, run_id, adoption_token)
	if not identity["ok"]:
		return identity
	var plan_abs := _absolute(launch_plan_path)
	if plan_abs != String(reservation.get("launch_plan_path", "")):
		return _failure("LAUNCH_PLAN_PATH_MISMATCH")
	if not FileAccess.file_exists(plan_abs) \
			or _sha256_file(plan_abs) \
				!= String(reservation.get("launch_plan_sha256", "")):
		return _failure("LAUNCH_PLAN_HASH_MISMATCH")

	# Only one competing child can create this directory.  Token validation is
	# intentionally performed first so a forged request cannot consume a valid
	# reservation as a denial-of-service side effect.
	var claim_error := DirAccess.make_dir_absolute(
		partial_abs.path_join(ADOPTION_CLAIM_DIRECTORY))
	if claim_error != OK:
		return _failure("RUN_ALREADY_ADOPTED", claim_error)
	reservation["status"] = "ADOPTED"
	reservation["child_process_id"] = child_process_id
	reservation["adopted_utc"] = _utc_now()
	var write := _write_json_atomic(
		partial_abs.path_join(RESERVATION_FILE), reservation, true)
	if not write["ok"]:
		return write
	var remove_error := DirAccess.remove_absolute(descriptor_abs)
	if remove_error != OK:
		return _failure("ADOPTION_TOKEN_CONSUME_FAILED", remove_error)
	return {
		"ok": true,
		"reservation_id": reservation["reservation_id"],
		"run_id": run_id,
		"partial_path": partial_abs,
		"final_path": reservation["final_path"],
		"launch_plan_path": plan_abs,
		"launch_plan_sha256": reservation["launch_plan_sha256"],
		"parent_process_id": reservation["parent_process_id"],
		"child_process_id": child_process_id,
	}


static func authorize_parent_finalization(
		partial_path: String,
		run_id: String,
		reservation_id: String,
		child_process_id: int) -> Dictionary:
	var loaded := _load_reservation(partial_path)
	if not loaded["ok"]:
		return loaded
	var reservation: Dictionary = loaded["reservation"]
	if _absolute(partial_path) != String(reservation.get("partial_path", "")):
		return _failure("PARTIAL_PATH_MISMATCH")
	if run_id != String(reservation.get("run_id", "")):
		return _failure("RUN_ID_MISMATCH")
	if reservation_id != String(reservation.get("reservation_id", "")):
		return _failure("RESERVATION_ID_MISMATCH")
	if int(reservation.get("parent_process_id", -1)) != OS.get_process_id():
		return _failure("FINALIZER_NOT_RESERVING_PARENT")
	if String(reservation.get("status", "")) != "ADOPTED":
		return _failure("RESERVATION_NOT_ADOPTED")
	if int(reservation.get("child_process_id", -1)) != child_process_id:
		return _failure("CHILD_PROCESS_ID_MISMATCH")
	if OS.is_process_running(child_process_id):
		return _failure("CHILD_STILL_RUNNING")
	reservation["status"] = "PARENT_FINALIZING"
	var write := _write_json_atomic(
		_absolute(partial_path).path_join(RESERVATION_FILE),
		reservation,
		true)
	if not write["ok"]:
		return write
	return {
		"ok": true,
		"reservation": reservation,
		"partial_path": reservation["partial_path"],
		"final_path": reservation["final_path"],
	}


static func authorize_parent_observation(
		partial_path: String,
		run_id: String,
		reservation_id: String,
		child_process_id: int) -> Dictionary:
	var loaded := _load_reservation(partial_path)
	if not loaded["ok"]:
		return loaded
	var reservation: Dictionary = loaded["reservation"]
	if _absolute(partial_path) != String(reservation.get("partial_path", "")):
		return _failure("PARTIAL_PATH_MISMATCH")
	if run_id != String(reservation.get("run_id", "")):
		return _failure("RUN_ID_MISMATCH")
	if reservation_id != String(reservation.get("reservation_id", "")):
		return _failure("RESERVATION_ID_MISMATCH")
	if int(reservation.get("parent_process_id", -1)) != OS.get_process_id():
		return _failure("OBSERVER_NOT_RESERVING_PARENT")
	var recorded_child: Variant = reservation.get("child_process_id")
	if recorded_child != null and int(recorded_child) != child_process_id:
		return _failure("CHILD_PROCESS_ID_MISMATCH")
	return {"ok": true, "reservation": reservation}


static func abort_before_adoption(
		partial_path: String,
		run_id: String,
		reservation_id: String,
		disposition: String) -> Dictionary:
	var loaded := _load_reservation(partial_path)
	if not loaded["ok"]:
		return loaded
	var reservation: Dictionary = loaded["reservation"]
	if _absolute(partial_path) != String(reservation.get("partial_path", "")):
		return _failure("PARTIAL_PATH_MISMATCH")
	if run_id != String(reservation.get("run_id", "")):
		return _failure("RUN_ID_MISMATCH")
	if reservation_id != String(reservation.get("reservation_id", "")):
		return _failure("RESERVATION_ID_MISMATCH")
	if int(reservation.get("parent_process_id", -1)) != OS.get_process_id():
		return _failure("ABORTER_NOT_RESERVING_PARENT")
	if String(reservation.get("status", "")) != "RESERVED":
		return _failure("RESERVATION_ALREADY_CLAIMED")
	var token_path := String(reservation.get("token_descriptor_path", ""))
	if FileAccess.file_exists(token_path):
		var remove_error := DirAccess.remove_absolute(token_path)
		if remove_error != OK:
			return _failure("ADOPTION_TOKEN_CONSUME_FAILED", remove_error)
	reservation["status"] = "SPAWN_FAILED"
	reservation["spawn_failure_disposition"] = disposition
	reservation["spawn_failed_utc"] = _utc_now()
	var write := _write_json_atomic(
		_absolute(partial_path).path_join(RESERVATION_FILE),
		reservation,
		true)
	if not write["ok"]:
		return write
	return {"ok": true, "reservation": reservation}


static func cleanup_control_state(partial_path: String) -> Dictionary:
	var partial_abs := _absolute(partial_path)
	for name in [TOKEN_FILE, RESERVATION_FILE]:
		var path := partial_abs.path_join(name)
		if FileAccess.file_exists(path):
			var remove_error := DirAccess.remove_absolute(path)
			if remove_error != OK:
				return _failure("CONTROL_FILE_REMOVE_FAILED", remove_error)
	var claim_path := partial_abs.path_join(ADOPTION_CLAIM_DIRECTORY)
	if DirAccess.dir_exists_absolute(claim_path):
		var claim_remove := DirAccess.remove_absolute(claim_path)
		if claim_remove != OK:
			return _failure("ADOPTION_CLAIM_REMOVE_FAILED", claim_remove)
	return {"ok": true}


static func read_control_state(partial_path: String) -> Dictionary:
	return _load_reservation(partial_path)


static func finalize_partial(
		partial_path: String,
		final_path: String,
		parent_authorized := false) -> Dictionary:
	if not partial_path.ends_with(".partial"):
		return _failure("NOT_A_PARTIAL_RUN")
	if not DirAccess.dir_exists_absolute(partial_path):
		return _failure("PARTIAL_RUN_MISSING")
	if FileAccess.file_exists(
			_absolute(partial_path).path_join(RESERVATION_FILE)) \
			and not parent_authorized:
		return _failure("PARENT_AUTHORIZATION_REQUIRED")
	if _path_entry_exists(final_path):
		return _failure("FINAL_RUN_ALREADY_EXISTS")
	var error := FAILED
	# Windows can briefly retain a sharing handle for the child's engine log
	# after the process has reported its exit.  Publication still happens only
	# after that observed exit; this bounded retry handles handle-release
	# latency without changing the candidate or choosing another final path.
	for attempt in 25:
		if _path_entry_exists(final_path):
			return _failure("FINAL_RUN_ALREADY_EXISTS")
		error = DirAccess.rename_absolute(partial_path, final_path)
		if error == OK:
			break
		if _path_entry_exists(final_path) \
				or not DirAccess.dir_exists_absolute(partial_path):
			break
		OS.delay_msec(10)
	if error != OK and _path_entry_exists(final_path):
		return _failure("FINAL_RUN_ALREADY_EXISTS")
	return {
		"ok": error == OK,
		"error": "" if error == OK else "FINAL_RENAME_FAILED",
		"code": error,
	}


static func _validate_identity(
		reservation: Dictionary,
		partial_path: String,
		run_id: String,
		adoption_token: String) -> Dictionary:
	if run_id != String(reservation.get("run_id", "")):
		return _failure("RUN_ID_MISMATCH")
	if _absolute(partial_path) != String(reservation.get("partial_path", "")):
		return _failure("PARTIAL_PATH_MISMATCH")
	if not String(reservation.get("final_path", "")).ends_with(run_id):
		return _failure("FINAL_PATH_MISMATCH")
	if _secret_sha256(adoption_token) \
			!= String(reservation.get("adoption_token_sha256", "")):
		return _failure("ADOPTION_TOKEN_MISMATCH")
	return {"ok": true}


static func _load_reservation(partial_path: String) -> Dictionary:
	var partial_abs := _absolute(partial_path)
	if not partial_abs.ends_with(".partial") \
			or not DirAccess.dir_exists_absolute(partial_abs):
		return _failure("PARTIAL_RUN_MISSING")
	var path := partial_abs.path_join(RESERVATION_FILE)
	if not FileAccess.file_exists(path):
		return _failure("RESERVATION_CONTROL_MISSING")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("RESERVATION_CONTROL_UNREADABLE")
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file = null
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return _failure("RESERVATION_CONTROL_INVALID")
	var reservation: Dictionary = parser.data
	if String(reservation.get("schema", "")) != RESERVATION_SCHEMA:
		return _failure("RESERVATION_SCHEMA_INVALID")
	return {"ok": true, "reservation": reservation}


static func _write_text_exclusive(path: String, text: String) -> Dictionary:
	if FileAccess.file_exists(path):
		return _failure("CONTROL_FILE_ALREADY_EXISTS")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("CONTROL_FILE_OPEN_FAILED")
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file = null
	return (
		{"ok": true}
		if write_error == OK
		else _failure("CONTROL_FILE_WRITE_FAILED", write_error)
	)


static func _write_json_atomic(
		path: String,
		value: Dictionary,
		replace_existing: bool) -> Dictionary:
	var temporary := "%s.tmp" % path
	if FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("CONTROL_FILE_OPEN_FAILED")
	file.store_string(CanonicalJsonScript.stringify(value) + "\n")
	file.flush()
	var write_error := file.get_error()
	file = null
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return _failure("CONTROL_FILE_WRITE_FAILED", write_error)
	if FileAccess.file_exists(path):
		if not replace_existing:
			DirAccess.remove_absolute(temporary)
			return _failure("CONTROL_FILE_ALREADY_EXISTS")
		var remove_error := DirAccess.remove_absolute(path)
		if remove_error != OK:
			DirAccess.remove_absolute(temporary)
			return _failure("CONTROL_FILE_REPLACE_FAILED", remove_error)
	var rename_error := DirAccess.rename_absolute(temporary, path)
	if rename_error != OK:
		return _failure("CONTROL_FILE_INSTALL_FAILED", rename_error)
	return {"ok": true}


static func _remove_empty_reservation(partial_path: String) -> void:
	if DirAccess.dir_exists_absolute(partial_path):
		DirAccess.remove_absolute(partial_path)


static func _secret_sha256(secret: String) -> String:
	return "sha256:%s" % secret.sha256_text()


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
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()


static func _path_entry_exists(path: String) -> bool:
	return (
		FileAccess.file_exists(path)
		or DirAccess.dir_exists_absolute(path)
	)


static func _is_safe_run_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$")
	return regex.search(value) != null


static func _utc_now() -> String:
	var value := Time.get_datetime_string_from_system(true, false)
	return value if value.ends_with("Z") else "%sZ" % value


static func _failure(error: String, code := -1) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"code": code,
	}
