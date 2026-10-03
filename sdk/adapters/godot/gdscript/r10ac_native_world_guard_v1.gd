extends RefCounted
## A source-bound helper claims the sole declared child. Replay never calls it.
const Seed := preload("res://sdk/adapters/godot/gdscript/r10ac_development_seed_v2.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/r10ac_native_runtime_v1.gd")
const HELPER := "res://sdk/conformance/r10ac_native_world_authority.py"
const CLAIM := "r10ac_native_world_claim_v1.json"
const ENV := "SPORESPORE_GODOT_RECOVERY_"
static var _claim_binding: Dictionary = {}
static var _permission: Dictionary = {}


static func claim_fields_valid_v1(claim: Dictionary, declaration: Dictionary, pid: int) -> bool:
	var children: Variant = declaration.get("children")
	if not children is Array or children.size() != 1 or not children[0] is Dictionary: return false
	var child: Dictionary = children[0]
	var expected := {"schema_version": "sporespore_r10ac_native_world_claim_v1",
		"parent_attempt_id": declaration.get("attempt_id"), "child_attempt_id": child.get("child_attempt_id"),
		"role": Seed.ROLE, "termination_nonce": child.get("termination_nonce"), "worker_process_id": pid,
		"source_commit": declaration.get("source_snapshot", {}).get("head"), "maximum_world_builds": 1,
		"permission_scope": "diagnostic_world_construction_only",
		"physical_acceptance_authority": false, "release_authority": false}
	for key in expected:
		if not Seed.Json.same_json_v1(claim.get(key), expected[key]): return false
	return true


static func authorize_worker_v1(declaration: Dictionary) -> bool:
	if not _claim_binding.is_empty() or not _permission.is_empty(): return false
	if not Seed.authorized_v1(declaration, OS.get_environment(ENV + "SEED"),
		OS.get_environment(ENV + "SEED_LABEL"), OS.get_environment(ENV + "SEED_SHA256"),
		OS.get_environment(ENV + "CHILD_ROLE"), OS.get_environment(ENV + "SOURCE_COMMIT")): return false
	var child: Dictionary = declaration.children[0]
	if (declaration.attempt_id != OS.get_environment(ENV + "PARENT_ATTEMPT_ID")
		or child.child_attempt_id != OS.get_environment(ENV + "ATTEMPT_ID")
		or child.termination_nonce != OS.get_environment(ENV + "TERMINATION_NONCE")
		or OS.get_environment(ENV + "SUPERVISED_TERMINATION") != "1"): return false
	var path: String = Seed.EVIDENCE + "development-recovery-smoke-" + declaration.attempt_id + "/declaration.json"
	if "sha256:" + FileAccess.get_sha256(path) != OS.get_environment(ENV + "AUTHORIZATION_SHA256"): return false
	if not Seed.Json.same_json_v1(JSON.parse_string(FileAccess.get_file_as_string(path)), declaration): return false
	if "sha256:" + FileAccess.get_sha256(Runtime.CONTRACT) != Runtime.CONTRACT_SHA: return false
	var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Runtime.CONTRACT))
	if not Seed.Json.same_json_v1(declaration.get("runtime"), runtime): return false
	var python: Dictionary = runtime.images.python_helper
	if (not FileAccess.file_exists(python.path) or FileAccess.get_file_as_bytes(python.path).size() != python.byte_length
		or "sha256:" + FileAccess.get_sha256(python.path) != python.raw_sha256): return false
	var output: Array = []
	var code := OS.execute(python.path, PackedStringArray(["-B", ProjectSettings.globalize_path(HELPER),
		"--claim", path, "--worker-pid", str(OS.get_process_id())]), output, false, false)
	if code != 0 or output.size() != 1: return false
	var result: Variant = JSON.parse_string(output[0])
	if not result is Dictionary or result.get("ok") != true or not result.get("claim") is Dictionary: return false
	var expected_path: String = child.evidence_path.replace("\\", "/") + "/" + CLAIM
	var expected_binding := {"path": expected_path, "raw_sha256": "sha256:" + FileAccess.get_sha256(expected_path)}
	if not FileAccess.file_exists(expected_path) or not Seed.Json.same_json_v1(result.get("claim_binding"), expected_binding): return false
	var claim: Variant = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	if not claim is Dictionary or not Seed.Json.same_json_v1(claim, result.claim): return false
	if not claim_fields_valid_v1(claim, declaration, OS.get_process_id()): return false
	if not Seed.Json.same_json_v1(claim.get("worker_image"), runtime.images.godot_engine): return false
	_claim_binding = expected_binding
	_permission = {"worker_process_id": OS.get_process_id(), "consumed": false}
	return true


static func consume_permission_v1(permission: Dictionary, pid: int) -> Dictionary:
	# Pure one-way transition, shared by the actual world boundary and controls.
	if (not Seed.Json.same_json_v1(permission.get("worker_process_id"), pid) or typeof(permission.get("consumed")) != TYPE_BOOL
		or permission.consumed): return {"ok": false}
	return {"ok": true, "next_permission": {"worker_process_id": pid, "consumed": true}}


static func take_world_permission_v1() -> bool:
	if _claim_binding.is_empty(): return false
	if "sha256:" + FileAccess.get_sha256(_claim_binding.path) != _claim_binding.raw_sha256: return false
	var consumed := consume_permission_v1(_permission, OS.get_process_id())
	if consumed.get("ok") != true: return false
	_permission = consumed.next_permission
	return true


static func report_binding_v1() -> Dictionary:
	if _claim_binding.is_empty(): return {}
	return {"claim_binding": _claim_binding.duplicate(true),
		"world_permission_consumed": _permission.get("consumed") == true,
		"maximum_world_builds": 1, "physical_acceptance_authority": false, "release_authority": false}
