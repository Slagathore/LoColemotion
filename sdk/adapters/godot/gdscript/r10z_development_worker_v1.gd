extends "res://sdk/adapters/godot/gdscript/r10z_route_worker_v1.gd"
## Prospective development population only. The external launcher must qualify
## and reserve the fresh attempt before this worker is started.
const R10ZSeed := preload("res://sdk/adapters/godot/gdscript/r10z_development_seed_v1.gd")

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	if not _r10k_selected_v1(): return false
	var role := OS.get_environment(CHILD_ROLE_ENV)
	var descriptors: Array = _campaign_declaration.get("children", []).filter(func(child): return child.get("role") == role)
	if descriptors.size() != 1 or _campaign_declaration.get("attempt_id") != OS.get_environment(PARENT_ATTEMPT_ID_ENV): return false
	if descriptors[0].get("child_attempt_id") != OS.get_environment(ATTEMPT_ID_ENV) or descriptors[0].get("termination_nonce") != OS.get_environment(NONCE_ENV): return false
	return R10ZSeed.authorized_v1(_campaign_declaration, seed_text, label, digest, role, OS.get_environment(SOURCE_COMMIT_ENV))

func _attach_profile_seed_context_v1(report: Dictionary) -> bool:
	return R10ZSeed.attach_report_context_v1(report, _campaign_declaration, _seed)
