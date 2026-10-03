extends RefCounted
## Read-only presentation of one immutable acceptance. Never authorizes a live run.
## Paths are relative to an SDK root, so no laboratory or external evidence reads occur.

const ADOPTION_PATH := "recovery/r10dh_release_gate_adoption_v2.json"
const CLOSURE_PATH := "recovery/r10dh_held_out_physical_closure_v2.json"
const ADOPTION_SHA := "b02160d80c1fec22417eb12c8f61e29f41a3a12a397ba349cad5dc3dcddd84e9"
const CLOSURE_SHA := "29a59b71ca000d1be7cfcd19d38cbe341ed90aecc9b3439f315b2dd05a197003"
const MAX_RECORD_BYTES := 300000


static func inspect(sdk_root: String, runtime_dll_sha256: String = "") -> Dictionary:
	return inspect_bytes(
		_read(sdk_root.path_join(ADOPTION_PATH)),
		_read(sdk_root.path_join(CLOSURE_PATH)),
		runtime_dll_sha256
	)


static func inspect_bytes(
	adoption_bytes: PackedByteArray,
	closure_bytes: PackedByteArray,
	runtime_dll_sha256: String = ""
) -> Dictionary:
	# A missing record cannot prove a claim; changed or crossed records are ambiguous.
	if adoption_bytes.is_empty() or closure_bytes.is_empty():
		return _unavailable("unproven", "The retained acceptance records are unavailable.")
	if _sha(adoption_bytes) != ADOPTION_SHA or _sha(closure_bytes) != CLOSURE_SHA:
		return _unavailable("ambiguous", "Acceptance record integrity check failed.")
	var adoption: Dictionary = JSON.parse_string(adoption_bytes.get_string_from_utf8())
	var closure: Dictionary = JSON.parse_string(closure_bytes.get_string_from_utf8())
	var scope: Dictionary = adoption["claim_scope"]
	var expected_runtime := String(scope["dll"]["raw_sha256"])
	var runtime_status := "unknown"
	if not runtime_dll_sha256.is_empty():
		runtime_status = "matches_retained_dll" if runtime_dll_sha256 == expected_runtime else "different_dll"
	return {
		"evidence_status": "proved",
		"label": "PROVED — retained finite recovery acceptance",
		"reason": "All six R10DH held-out tasks and their independent cold audit passed.",
		"cells": adoption["cells"],
		"scope": scope,
		"limits": adoption["claim_limits"],
		"source_commit": closure["source_commit"],
		"production_route_key": adoption["production_route_key"],
		"runtime_status": runtime_status,
		"runtime_dll_sha256": expected_runtime,
		# A matching DLL alone does not bind the engine, controller, state, or schedule.
		"live_recovery_status": "unproven",
		"live_explanation": "A live sandbox run needs its own complete runtime, setup and execution evidence.",
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"new_world_count": 0
	}


static func _unavailable(status: String, reason: String) -> Dictionary:
	return {
		"evidence_status": status,
		"label": status.to_upper() + " — recovery evidence",
		"reason": reason,
		"cells": [],
		"live_recovery_status": "unproven",
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"new_world_count": 0
	}


static func _read(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_RECORD_BYTES:
		return PackedByteArray()
	return file.get_buffer(file.get_length())


static func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(bytes)
	return context.finish().hex_encode()
