extends SceneTree
# gdlint: disable=max-line-length

## Exposed-input bridge diagnosis and synthetic step fixtures. No physics.
const Bridge := preload("res://sdk/adapters/godot/gdscript/r10k_partial_recovery_stage_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const PROFILE := "res://sdk/development/recovery_candidates/r10k-partial-fall-control-core-v1.json"
const OLD := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_profile_resource_v1()))
	var checks := {}
	checks["extension_hash"] = "sha256:" + FileAccess.get_sha256(profile.extension) == profile.extension_sha256
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
	checks["runtime_hash"] = "sha256:" + FileAccess.get_sha256(binding.runtime.path) == profile.runtime_sha256
	if GDExtensionManager.is_extension_loaded(OLD):
		checks["unload"] = GDExtensionManager.unload_extension(OLD) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	if checks.values().has(false): _finish(checks, [], args[1]); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var input: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var context := Bridge.Prior.Route.prepare_complete_energy_context_v18(sdk, Bridge.Prior.Route.RECOVERY_CONTROLLER_V6_ID)
	checks["production_context"] = context.get("ok") == true
	var results := []
	for population in input.cases:
		var prior := {}
		var last := {}
		var count := 0
		var first: Dictionary = population.packets[0]
		for packet in population.packets:
			last = Bridge.entry_v1(sdk, context, packet.source_attempt_id, packet.bound_observations, prior)
			if last.get("ok") != true: break
			prior = last.entry_state
			count += 1
		checks["entry_count_" + str(population.seed)] = count == population.expected_count
		checks["entry_branch_" + str(population.seed)] = last.get("entry_kind") == population.expected_branch
		if last.get("ok") == true:
			var expected: Dictionary = population.expected_final
			checks["exact_native_entry_" + str(population.seed)] = Bridge.Source._sha(sdk, last.native_receipt) == Bridge.Source._sha(sdk, expected)
		results.append({"seed": population.seed, "count": count, "last_packet": last})
		for defect in ["missing_source", "missing_component", "crossed_observation", "wrong_attempt", "missing_prefix", "reused_entry"]:
			var bound: Dictionary = first.bound_observations.duplicate(true)
			var selected_attempt: String = first.source_attempt_id
			var selected_prior := {}
			match defect:
				"missing_source": bound.erase("source_binding")
				"missing_component": bound.source_component_receipts.erase("epoch_initializer")
				"crossed_observation": bound.observation_v3.state.base_pose_world.position_m.y += 0.001
				"wrong_attempt": selected_attempt = "unregistered_attempt"
				"missing_prefix": bound = population.packets[1].bound_observations.duplicate(true)
				"reused_entry": selected_prior = prior
			var refused := Bridge.entry_v1(sdk, context, selected_attempt, bound, selected_prior)
			checks["refuse_" + str(population.seed) + "_" + defect] = refused.get("ok") == false
			checks["retained_" + str(population.seed) + "_" + defect] = refused.get("bound_observations") == bound
	var fixture_count := 0
	for line in FileAccess.get_file_as_string(input.step_fixtures_path).split("\n"):
		if not line.begins_with("R10K_CONTROL_FIXTURE "): continue
		var fixture: Dictionary = sdk.decode_exact_json_v1(line.trim_prefix("R10K_CONTROL_FIXTURE "))
		if fixture.kind != "step": continue
		var original: Dictionary = fixture.request
		var fixture_context := {"morphology_context": original.collection.morphology_context,
			"capability": original.collection.adapter_capability, "runtime_binding": original.collection.runtime_binding}
		var fixture_bound := {"observation_v2": original.collection.observation, "observation_v3": original.step.observation,
			"source_binding": original.collection.observation_source_binding}
		var fixture_source := {"energy_increment": original.step.energy_increment, "global_totals": original.step.native_global_energy}
		var request := Bridge.step_request_v1(fixture_context, fixture_bound, original.step.declaration, original.step.memory, fixture_source)
		checks["step_request_exact_" + str(fixture_count)] = Bridge.Source._sha(sdk, request) == Bridge.Source._sha(sdk, original)
		var called := Bridge.call_v1(sdk, "recovery_partial_fall_step_control_v1_json", request)
		results.append({"synthetic_step_fixture": fixture_count, "call": called, "expected": fixture.expected})
		checks["step_native_exact_" + str(fixture_count)] = called.get("ok") == true and Bridge.Source._sha(sdk, called.get("value")) == Bridge.Source._sha(sdk, fixture.expected)
		fixture_count += 1
	checks["all_partial_step_phases"] = fixture_count == 5
	sdk = null
	_finish(checks, results, args[1])

func _finish(checks: Dictionary, results: Array, path: String) -> void:
	var ok := not checks.is_empty() and not checks.values().has(false)
	if FileAccess.file_exists(path): quit(1); return
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null: quit(1); return
	out.store_string(Transport.stringify({"ok": ok, "checks": checks, "results": results,
		"exposed_inputs_not_regraded": true, "synthetic_step_fixtures": true,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	out.close()
	print("R10K_RECOVERY_STAGE " + JSON.stringify({"ok": ok, "checks": checks.size(), "failed": checks.keys().filter(func(key): return not checks[key])}))
	quit(0 if ok else 1)

func _profile_resource_v1() -> String:
	return PROFILE
