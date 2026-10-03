extends "res://tests/test_development_v56_adapter_boundaries.gd"
const Y_PROFILE := "res://sdk/development/recovery_candidates/r10aa-partial-load-seeking-core-v1.json"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var component: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Y_PROFILE))
	var probe := Shared.RuntimeProbe.new()
	probe.profile_path = Y_PROFILE
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(component.runtime_binding))
	checks["bound_runtime"] = probe._load_runtime_extension_v1()
	if checks.bound_runtime:
		var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
		var inputs: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
		for fixture in inputs.boundaries:
			_check_boundary(sdk, fixture)
		_check_readers(sdk, inputs.walking_fixture)
		sdk = null
	probe.free()
	var ok := checks.values().all(func(v): return v == true)
	var out := FileAccess.open(args[1], FileAccess.WRITE)
	out.store_string(Transport.stringify({"ok": ok, "checks": checks,
		"boundaries": boundary_results, "readers": reader_results,
		"world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}))
	out.close()
	print("V56_ADAPTER_BOUNDARIES ", checks.size(), " checks; ok=", ok)
	quit(0 if ok else 1)
