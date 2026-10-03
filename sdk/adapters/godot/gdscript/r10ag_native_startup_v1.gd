extends RefCounted
## Read-only helper transport. It has no reservation or world-permission path.
const Seed := preload("res://sdk/adapters/godot/gdscript/r10ag_development_seed_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/r10ag_native_runtime_v1.gd")
const HOST := Runtime.CONTRACT
const HOST_SHA := Runtime.CONTRACT_SHA
const HELPER := "res://sdk/conformance/r10ag_startup_preflight.py"

static func preflight_v1(path: String) -> Dictionary:
	var declaration: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var identity := Seed.seed_identity_v1(Seed.SEED)
	var refused := {"ok": false, "failure_code": "R10AG_NATIVE_STARTUP_DECLARATION",
		"world_build_count": 0, "solver_step_count": 0, "physical_execution_authorized": false,
		"physical_acceptance_authority": false, "release_authority": false}
	if not declaration is Dictionary or not Seed.authorized_v1(declaration, str(Seed.SEED),
		identity.label, identity.sha256, Seed.ROLE, declaration.get("source_snapshot", {}).get("head", "")):
		return refused
	refused.failure_code = "R10AG_NATIVE_STARTUP_RUNTIME"
	if "sha256:" + FileAccess.get_sha256(HOST) != HOST_SHA: return refused
	var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HOST))
	if not Seed.Json.same_json_v1(declaration.get("runtime"), runtime): return refused
	# Interpreter comes from the pinned host contract, never the offered request.
	var image: Dictionary = runtime.images.python_helper
	if (not FileAccess.file_exists(image.path) or FileAccess.get_file_as_bytes(image.path).size() != image.byte_length
		or "sha256:" + FileAccess.get_sha256(image.path) != image.raw_sha256): return refused
	var python: String = image.path
	var output: Array = []
	var code := OS.execute(python, PackedStringArray(["-B", ProjectSettings.globalize_path(HELPER),
		"--preflight", path, "--worker-pid", str(OS.get_process_id())]), output, true, false)
	# Keep original helper bytes even when parsing or a downstream predicate fails.
	var result := {"ok": false, "failure_code": "R10AG_NATIVE_STARTUP_HELPER_OUTPUT",
		"helper_exit_code": code, "helper_output": output, "world_build_count": 0,
		"solver_step_count": 0, "physical_execution_authorized": false,
		"physical_acceptance_authority": false, "release_authority": false}
	if output.size() != 1: return result
	var receipt: Variant = JSON.parse_string(output[0])
	if not receipt is Dictionary or receipt.get("schema_version") != "sporespore_r10ag_startup_preflight_v1": return result
	result["helper_receipt"] = receipt
	if code != 0 or receipt.get("ok") != true:
		result.failure_code = "R10AG_NATIVE_STARTUP_HELPER_REFUSED"
		return result
	for key in ["physical_execution_authorized", "physical_acceptance_authority", "release_authority",
		"launch_reservation_created", "native_world_claim_created"]:
		if typeof(receipt.get(key)) != TYPE_BOOL or receipt[key]: return result
	result.ok = true
	result.failure_code = ""
	return result
