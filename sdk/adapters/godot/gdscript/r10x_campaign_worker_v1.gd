extends "res://sdk/adapters/godot/gdscript/r10v_recovery_worker_v1.gd"
# gdlint: disable=max-line-length

## R10X changes campaign admission and seed/publication context only. Native
## recovery, conditional settling, stepping and measurement inherit R10V.
const R10XSeed := preload("res://sdk/adapters/godot/gdscript/r10x_campaign_seed_v1.gd")

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	if not _r10k_selected_v1() or _candidate_selection.get("candidate_profile", {}).get("resource") != R10XSeed.CANDIDATE:
		return false
	var role := OS.get_environment(CHILD_ROLE_ENV)
	var descriptors: Array = _campaign_declaration.get("children", []).filter(func(child): return child.get("role") == role)
	if descriptors.size() != 1 or _campaign_declaration.get("attempt_id") != OS.get_environment(PARENT_ATTEMPT_ID_ENV): return false
	if descriptors[0].get("child_attempt_id") != OS.get_environment(ATTEMPT_ID_ENV) or descriptors[0].get("termination_nonce") != OS.get_environment(NONCE_ENV): return false
	return R10XSeed.authorized_v1(_campaign_declaration, seed_text, label, digest, role, OS.get_environment(SOURCE_COMMIT_ENV))

func _entry_selection_v1() -> Dictionary:
	var selected: Dictionary = super._entry_selection_v1().duplicate(true)
	selected["worker"] = R10XSeed.WORKER
	return selected

func _walking_prefix_profile_id_v1(segment_id: String) -> String:
	return "r10x_declared_campaign_prefix_phase_v1" if segment_id == "walking_prefix" else ""

func _attach_profile_seed_context_v1(report: Dictionary) -> bool:
	return R10XSeed.attach_report_context_v1(report, _campaign_declaration, _seed)
