extends RefCounted

## Test-only construction for the detached publication trust boundary.
##
## Every root created here is a strict descendant of OS.get_temp_dir(), remains
## outside the repository and evidence bundle, and is passed only through APIs
## explicitly named `*_with_test_trust_root` or `attestation_test_root`.

const CanonicalJsonScript := preload(
	"res://scripts/lab/canonical_json.gd")
const PublicationAttestationScript := preload(
	"res://scripts/lab/publication_attestation.gd")


static func create_trust_root(label: String) -> Dictionary:
	var safe_label := _safe_label(label)
	var trust_root := OS.get_temp_dir().path_join(
		"sporespore_lab_attestation_tests").path_join(
			"%s_%d_%d" % [
				safe_label,
				OS.get_process_id(),
				Time.get_ticks_usec(),
			]).replace("\\", "/").simplify_path()
	var key_directory := trust_root.path_join("keys")
	var receipts_directory := trust_root.path_join("receipts")
	var directory_error := DirAccess.make_dir_recursive_absolute(
		key_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure(
			"TEST_TRUST_ROOT_CREATE_FAILED",
			error_string(directory_error),
			trust_root)
	directory_error = DirAccess.make_dir_recursive_absolute(
		receipts_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		remove_tree(trust_root)
		return _failure(
			"TEST_RECEIPT_DIRECTORY_CREATE_FAILED",
			error_string(directory_error),
			trust_root)

	var key := PackedByteArray()
	for index in PublicationAttestationScript.KEY_BYTES:
		key.append((index * 37 + 11) & 0xff)
	var key_id := _sha256_bytes(key)
	var key_hex := key_id.trim_prefix("sha256:")
	var key_path := key_directory.path_join("%s.key" % key_hex)
	var key_file := FileAccess.open(key_path, FileAccess.WRITE)
	if key_file == null:
		key.fill(0)
		remove_tree(trust_root)
		return _failure(
			"TEST_KEY_WRITE_FAILED",
			"Could not create the raw test key.",
			trust_root)
	key_file.store_buffer(key)
	key_file.flush()
	var key_error := key_file.get_error()
	key_file.close()
	key.fill(0)
	key.resize(0)
	if key_error != OK:
		remove_tree(trust_root)
		return _failure(
			"TEST_KEY_WRITE_FAILED",
			error_string(key_error),
			trust_root)

	var pointer := {
		"schema_version": PublicationAttestationScript.ACTIVE_KEY_SCHEMA,
		"algorithm": PublicationAttestationScript.ALGORITHM,
		"key_id": key_id,
		"key_file": "keys/%s.key" % key_hex,
	}
	var pointer_path := trust_root.path_join(
		PublicationAttestationScript.ACTIVE_KEY_FILE)
	var pointer_file := FileAccess.open(pointer_path, FileAccess.WRITE)
	if pointer_file == null:
		remove_tree(trust_root)
		return _failure(
			"TEST_KEY_POINTER_WRITE_FAILED",
			"Could not create canonical active_key.json.",
			trust_root)
	pointer_file.store_string(CanonicalJsonScript.stringify(pointer) + "\n")
	pointer_file.flush()
	var pointer_error := pointer_file.get_error()
	pointer_file.close()
	if pointer_error != OK:
		remove_tree(trust_root)
		return _failure(
			"TEST_KEY_POINTER_WRITE_FAILED",
			error_string(pointer_error),
			trust_root)
	return {
		"ok": true,
		"trust_root": trust_root,
		"key_id": key_id,
	}


static func validation_options(trust_root: String) -> Dictionary:
	return {
		"attestation_test_root": trust_root,
	}


static func attest_bundle(
		bundle_path: String,
		trust_root: String,
		attested_utc := "2026-07-19T00:00:00Z") -> Dictionary:
	return PublicationAttestationScript.attest_with_test_trust_root(
		bundle_path,
		trust_root,
		String(attested_utc))


static func remove_tree(path: String) -> void:
	var normalized := path.replace("\\", "/").simplify_path()
	var temp_root := OS.get_temp_dir().replace(
		"\\", "/").simplify_path().trim_suffix("/")
	if (
		normalized == temp_root
		or not normalized.to_lower().begins_with(
			"%s/" % temp_root.to_lower())
		or not DirAccess.dir_exists_absolute(normalized)
	):
		return
	var directory := DirAccess.open(normalized)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := normalized.path_join(name)
		if directory.current_is_dir():
			remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(normalized)


static func _safe_label(value: String) -> String:
	var result := ""
	for index in value.length():
		var character := value.substr(index, 1)
		if (
			character >= "A" and character <= "Z"
			or character >= "a" and character <= "z"
			or character >= "0" and character <= "9"
			or character in ["-", "_"]
		):
			result += character
		else:
			result += "_"
	return result if not result.is_empty() else "fixture"


static func _sha256_bytes(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value) != OK:
		context.finish()
		return ""
	return "sha256:%s" % context.finish().hex_encode()


static func _failure(
		code: String,
		message: String,
		trust_root: String) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"message": message,
		"trust_root": trust_root,
	}
