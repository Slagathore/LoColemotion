extends RefCounted
## Exact diagnostic image selection, read-only and without world authority.
## The v7 patch adds a contact-frame observer; existing energy channels are the
## same v6 instrumentation. Selection is explicit in a fresh diagnostic process.
const Seed := preload("res://sdk/adapters/godot/gdscript/r10ae_development_seed_v1.gd")
const CONTRACT := "res://sdk/development/r10ae_host_runtime_contract_v1.json"
const CONTRACT_SHA := "sha256:c2a29e65d0f6c129b4dde32fac9420d9e49e9958be69c2fc8ee9911947f3022e"

static func bind_v1(declaration: Dictionary, reference: Dictionary, profile: Script) -> Dictionary:
	var identity := Seed.seed_identity_v1(Seed.SEED)
	if reference != {"resource": Seed.PROFILE, "raw_sha256": Seed.PROFILE_SHA}:
		return _failure("PROFILE")
	if not Seed.authorized_v1(declaration, str(Seed.SEED), identity.label, identity.sha256,
		Seed.ROLE, declaration.get("source_snapshot", {}).get("head", "")):
		return _failure("DECLARATION")
	if "sha256:" + FileAccess.get_sha256(CONTRACT) != CONTRACT_SHA: return _failure("CONTRACT")
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	if not Seed.Json.same_json_v1(declaration.get("runtime"), contract): return _failure("HOST_BINDING")
	for image in contract.images.values():
		if (not FileAccess.file_exists(image.path) or FileAccess.get_file_as_bytes(image.path).size() != image.byte_length
			or "sha256:" + FileAccess.get_sha256(image.path) != image.raw_sha256): return _failure("IMAGE")
	for key in ["diagnostic_design", "observer_component"]:
		var source: Dictionary = contract[key]
		var path := "res://" + String(source.path)
		if FileAccess.get_file_as_bytes(path).size() != source.byte_length or "sha256:" + FileAccess.get_sha256(path) != source.raw_sha256:
			return _failure("DEPENDENCY")
	var console: Dictionary = contract.images.godot_console
	var engine: Dictionary = contract.images.godot_engine
	var runtime: Dictionary = profile._runtime_identity_for_profile_v1(
		profile.ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		String(console.raw_sha256).trim_prefix("sha256:"), int(console.byte_length),
		String(engine.raw_sha256).trim_prefix("sha256:"), int(engine.byte_length), true)
	if (runtime.get("exact_binary_pair_match") != true or runtime.get("complete_energy_profile_selected") != true
		or runtime.console_binary.path != console.path or runtime.engine_binary.path != engine.path):
		return _failure("RUNNING_PAIR")
	for method in ["space_set_contact_frames_enabled", "space_get_contact_frames"]:
		if not ClassDB.class_has_method("JoltPhysicsServer3D", method): return _failure("OBSERVER_API")
	runtime["r10ae_diagnostic_only"] = true
	runtime["r10ae_candidate_profile"] = reference.duplicate(true)
	runtime["r10ae_runtime_contract_sha256"] = CONTRACT_SHA
	runtime["selection_reason"] = "explicit_r10ae_declaration_exact_v7_pair_and_read_only_observer_api"
	runtime["official_qualification"] = false
	runtime["physical_execution_authorized"] = false
	runtime["physical_acceptance_authority"] = false
	runtime["release_authority"] = false
	return {"ok": true, "runtime_identity": runtime, "world_build_count": 0, "solver_step_count": 0,
		"physical_execution_authorized": false, "physical_acceptance_authority": false, "release_authority": false}

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "R10AE_NATIVE_RUNTIME_" + code,
		"world_build_count": 0, "solver_step_count": 0, "physical_execution_authorized": false,
		"physical_acceptance_authority": false, "release_authority": false}
