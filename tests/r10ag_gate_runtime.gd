extends RefCounted
## Read-only runtime selection for synthetic, zero-world gate fixtures.
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
static func select_v1() -> bool:
	var path := OS.get_environment("SPORE_R10AG_GATE_DECLARATION")
	if path.is_empty(): return false
	var declaration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var selected := Route.ProfileCapabilityScript.select_r10ag_diagnostic_runtime_v1(declaration, declaration.candidate_profile)
	return selected.get("ok") == true and selected.get("physical_execution_authorized") == false
