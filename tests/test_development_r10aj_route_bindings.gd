extends SceneTree
# gdlint: disable=max-line-length
const Route := preload("res://sdk/adapters/godot/gdscript/r10aj_recovery_route_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
var checks := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_candidates/r10aj-hip-recenter-v1.json"))
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		checks["unload"] = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var calls := []
	checks["native_task_binding_consistent"] = Route.native_identity_consistent_v1()
	# Reject stale or crossed dependency metadata before admitting the route.
	for field in ["native_entry_policy_contract", "native_entry_policy_contract_sha256"]:
		var saved: Variant = Route.task.stance_entry[field]
		Route.task.stance_entry[field] = "crossed"
		checks["reject_" + field] = not Route.native_identity_consistent_v1()
		Route.task.stance_entry[field] = saved
	for field in ["task_contract", "task_contract_sha256"]:
		var saved: Variant = Route.contract[field]
		Route.contract[field] = "crossed"
		checks["reject_" + field] = not Route.native_identity_consistent_v1()
		Route.contract[field] = saved
	checks["runtime_is_successor_dll"] = Route.contract.runtime_sha256 == profile.runtime_sha256
	for id in [Route.ID, Route.ENTRY_ALIAS, Route.HOLD_ALIAS, Route.POST_HOLD_ALIAS]:
		var fixed: Dictionary = Route.contract_for_v1(id)
		var request := {"schema_version": "sporespore_balanced_wave_policy_profile_request_v1",
			"policy_id": fixed.policy_id, "descriptor": fixture.descriptor}
		var raw: String = sdk.balanced_wave_policy_profile_json(Transport.stringify(request))
		var response: Dictionary = sdk.decode_exact_json_v1(raw)
		var digest: String = Runtime.canonicalize(sdk, response.get("value", {})).get("sha256", "")
		checks[id + "_native_profile"] = response.get("ok") == true and digest == fixed.native_profile_sha256
		checks[id + "_declared_profile"] = Runtime.canonicalize(sdk, fixed.native_profile).get("sha256") == digest
		checks[id + "_no_acceptance"] = fixed.physical_acceptance_authority == false and fixed.release_authority == false
		calls.append({"id": id, "request": request, "response_raw": raw, "profile_sha256": digest})
		if id != Route.ID:
			checks[id + "_alias_binding"] = not Route.alias_binding_v1(id, fixed.allowed_segment_ids[0]).is_empty()
			checks[id + "_wrong_segment"] = Route.alias_binding_v1(id, "undeclared").is_empty()
	checks["unknown_selection_refused"] = Route.contract_for_v1("undeclared").is_empty() and Route.path_for_v1("undeclared").is_empty()
	checks["phase248_selected"] = Route.prefix_selection_v1(68248, Route.PREFIX_PROFILE).get("prefix_phase") == 248
	checks["undeclared_seeds_refused"] = [51007, 51009, 41341, 41345].all(func(seed): return Route.prefix_selection_v1(seed, Route.PREFIX_PROFILE).is_empty())
	checks["crossed_prefix_profile_refused"] = Route.prefix_selection_v1(68248, "r10v_declared_development_prefix_phase_v1").is_empty()
	checks["no_execution_authority"] = Route.task.physical_execution_authorized == false and Route.task.sdk1_m07_satisfied == false
	checks["partial_limits_unchanged"] = Route.task.limits.maximum_partial_recovery_commands == 1200 and Route.task.partial_recovery.raise_and_completion.standing_consecutive_samples == 60
	var result := {"ok": not checks.values().has(false), "checks": checks, "calls": calls,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(Transport.stringify(result) + "\n")
	file.close()
	sdk = null
	print("R10AJ_ROUTE_BINDINGS ", JSON.stringify({"ok": result.ok, "checks": checks}))
	quit(0 if result.ok else 1)
