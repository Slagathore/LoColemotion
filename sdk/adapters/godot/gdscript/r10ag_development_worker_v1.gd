extends "res://sdk/adapters/godot/gdscript/r10ag_linked_capture_worker_v1.gd"
## Only the exact child with a complete gate and durable reservation can initialize.
const R10AGSeed := preload("res://sdk/adapters/godot/gdscript/r10ag_development_seed_v1.gd")
const R10AGWorldGuard := preload("res://sdk/adapters/godot/gdscript/r10ag_native_world_guard_v1.gd")

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	if not _r10k_selected_v1(): return false
	if not R10AGSeed.authorized_v1(_campaign_declaration, seed_text, label, digest,
		OS.get_environment(CHILD_ROLE_ENV), OS.get_environment(SOURCE_COMMIT_ENV)): return false
	var authorized := R10AGWorldGuard.authorize_worker_v1(_campaign_declaration)
	print("R10AG_STARTUP_DIAGNOSTIC " + JSON.stringify(R10AGWorldGuard.startup_diagnostic_v1()))
	return authorized

func _load_runtime_extension_v1() -> bool:
	var runtime := RouteScript.ProfileCapabilityScript.select_r10ag_diagnostic_runtime_v1(
		_campaign_declaration, _candidate_selection.get("candidate_profile", {}))
	if runtime.get("ok") != true: return false
	return super._load_runtime_extension_v1()

func _walking_prefix_profile_id_v1(segment: String) -> String:
	return R10AGSeed.PREFIX_PROFILE if segment == "walking_prefix" else ""

func _attach_profile_seed_context_v1(report: Dictionary) -> bool:
	if not R10AGSeed.attach_report_context_v1(report, _campaign_declaration, _seed): return false
	var claim := R10AGWorldGuard.report_binding_v1()
	if not claim.is_empty(): report["r10ag_native_world_claim"] = claim
	return true
