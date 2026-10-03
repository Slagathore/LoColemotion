extends SceneTree
const Readiness := preload("res://sdk/adapters/godot/gdscript/recovery_walking_readiness_v1.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var results := []
	for item in input.cases:
		results.append(Readiness.measure_v1(item.request, item.center_of_mass, input.compiled, input.limits))
	var memory := {"commands": 0, "consecutive_ready": 0, "last_source_step": 272, "outcome": "pending"}
	for n in range(240):
		memory = Readiness.advance_v1(memory, {"ready": n % 30 != 29, "source_semantic_step": 273+n}, input.limits)
	var terminal := Readiness.advance_v1(memory, {"ready": true, "source_semantic_step": 513}, input.limits)
	print("RECOVERY_WALKING_READINESS " + JSON.stringify({"results": results, "dwell": memory, "terminal": terminal,
		"new_world_count": 0, "new_solver_step_count": 0}))
	quit(0)
