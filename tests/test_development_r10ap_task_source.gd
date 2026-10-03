extends SceneTree
# gdlint: disable=max-line-length

## Actual sampler projection on explicitly synthetic snapshots and uninserted
## bodies. No world is built, no body enters the tree, no solver is stepped.
const Source := preload("res://sdk/adapters/godot/gdscript/r10ap_partial_task_source_v1.gd")
const Bridge := preload("res://sdk/adapters/godot/gdscript/r10ap_partial_recovery_stage_v1.gd")
const Native := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const OLD := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"


func _initialize() -> void:
	call_deferred("_run")

func _synthetic_application(control: Dictionary) -> Dictionary:
	var stance: bool = control.phase in ["stance_handoff", "stance_dwell"]
	return {"ok": true, "semantic_step": int(control.semantic_step) + 1, "phase": control.phase,
		"command_sha256": control.command_sha256, "controller_owner": "stance" if stance else "recovery",
		"recovery_controller_id": null if stance else Source.RECOVERY,
		"stance_controller_id": Source.STANCE if stance else null, "fallback_controller_active": false,
		"zero_command": false, "physical_acceptance_authority": false, "release_authority": false,
		"synthetic_application_fixture": true}

func _measurement(sdk: Object, source: Dictionary, checks: Dictionary) -> Dictionary:
	var bodies := {}
	var snapshots := {}
	var model := {"joint_states": {}, "task_origin_world_m": Vector3.ZERO}
	for body_id in Native.ORDERED_BODY_IDS:
		var body := RigidBody3D.new()
		body.set_meta("lab_body_id", body_id)
		bodies[body_id] = body
		snapshots[body_id] = {"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.4, 0.0)),
			"linear_velocity_world_m_s": Vector3.ZERO, "angular_velocity_world_rad_s": Vector3.ZERO,
			"total_gravity_world_m_s2": Vector3(0.0, -9.81, 0.0), "mass_kg": 1.0, "callback_sequence": 513}
	for joint_id in Native.ORDERED_JOINT_IDS:
		# Geometry values are explicit synthetic data; parent/child nodes are
		# uninserted identity carriers used by the production projection kernel.
		model.joint_states[joint_id] = {"parent": bodies[Native.ORDERED_BODY_IDS[0]],
			"child": bodies[Native.ORDERED_BODY_IDS[1]], "anchor_parent_local": Vector3.ZERO,
			"anchor_child_local": Vector3.ZERO}
	var contacts := {"ordered_contact_observations": [], "ordered_foot_bearing_observations": [], "ordered_body_clearance_observations": []}
	var context := {"capability_sha256": "sha256:" + "a".repeat(64)}
	var legacy := Native._measure_state_v1(context, model, snapshots, contacts, 513)
	var partial := Native._measure_state_v1(context, model, snapshots, contacts, 513, source)
	checks["actual_projection_succeeds"] = legacy.get("ok") == true and partial.get("ok") == true
	checks["partial_identity_at_creation"] = partial.get("observation_base", {}).get("task_id") == Source.TASK and partial.get("observation_base", {}).get("semantics_id") == Source.SEMANTICS
	checks["legacy_identity_preserved"] = legacy.get("observation_base", {}).get("task_id") == Source.CANONICAL_TASK and legacy.get("observation_base", {}).get("semantics_id") == Source.CANONICAL_SEMANTICS
	var first: Dictionary = legacy.get("observation_base", {}).duplicate(true)
	var second: Dictionary = partial.get("observation_base", {}).duplicate(true)
	for value in [first, second]:
		value.erase("task_id")
		value.erase("semantics_id")
	checks["measured_values_identical"] = Source._sha(sdk, first) == Source._sha(sdk, second)
	checks["direct_source_identical"] = legacy.get("direct_state_source_receipt") == partial.get("direct_state_source_receipt")
	checks["no_inserted_body"] = bodies.values().all(func(body): return not body.is_inside_tree())
	for body in bodies.values(): body.free()
	return {"legacy": legacy, "partial": partial, "synthetic_snapshots": true, "solver_step_count": 0}

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var checks := {}
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_candidates/r10ap-progressive-headroom-core-v1.runtime.json"))
	checks["runtime_hash"] = "sha256:" + FileAccess.get_sha256(binding.runtime.path) == binding.runtime.raw_sha256
	if GDExtensionManager.is_extension_loaded(OLD):
		checks["unload"] = GDExtensionManager.unload_extension(OLD) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension("res://sdk/adapters/godot/development_candidate_runtimes/r10ap-progressive-headroom-core-v1.gdextension") == GDExtensionManager.LOAD_STATUS_OK
	if checks.values().has(false): _finish(checks, {}, args[1]); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixtures := []
	for line in FileAccess.get_file_as_string(args[0]).split("\n"):
		var marker := line.find("R10AP_PARTIAL_FIXTURE ")
		if marker >= 0:
			fixtures.append(sdk.decode_exact_json_v1(line.substr(marker + "R10AP_PARTIAL_FIXTURE ".length())))
	checks["fixture_population"] = fixtures.size() == 7
	var kernel_count := 0
	var cost_increases := 0
	var restore := {}
	var raise_plan := {}
	var fallback := {}
	for line in FileAccess.get_file_as_string(args[0]).split("\n"):
		var marker := line.find("R10AP_KERNEL_FIXTURE ")
		if marker < 0: continue
		var value: Dictionary = sdk.decode_exact_json_v1(line.substr(marker + "R10AP_KERNEL_FIXTURE ".length()))
		var plan := {"mode": value.mode, "ordered_target_positions_rad": value.targets, "progressive_headroom_geometry": value.geometry}
		checks["compiled_headroom_guard_" + str(kernel_count)] = Source._headroom_geometry_valid(plan)
		kernel_count += 1
		if value.geometry.geometry_cost_increased:
			cost_increases += 1
			restore = plan
		if value.mode == "raise_with_headroom": raise_plan = plan
		if value.mode == "explicit_v23_fallback": fallback = plan
	checks["all_600_compiled_headroom_plans"] = kernel_count == 600
	checks["all_492_cost_increases_retained"] = cost_increases == 492
	checks["both_selected_modes_and_fallback"] = not restore.is_empty() and not raise_plan.is_empty() and not fallback.is_empty()
	for defect in ["initial_shape", "initial_negative", "selected_shape", "selected_negative", "deficit_target", "no_progress", "wrong_mode", "cost_flag", "nonworsening_count", "progress_count", "count_type", "out_of_limit", "fallback_deficits", "fallback_cost_flag", "fallback_reason"]:
		var bad: Dictionary = (fallback if defect.begins_with("fallback") else restore).duplicate(true)
		var g: Dictionary = bad.progressive_headroom_geometry
		match defect:
			"initial_shape": g.initial_deficits_rad = []
			"initial_negative": g.initial_deficits_rad[0] = -0.01
			"selected_shape": g.selected_deficits_rad = []
			"selected_negative": g.selected_deficits_rad[0] = -0.01
			"deficit_target": g.selected_deficits_rad[0] += 0.001
			"no_progress": g.initial_deficits_rad = g.selected_deficits_rad.duplicate()
			"wrong_mode": bad.mode = "raise_with_headroom"
			"cost_flag": g.geometry_cost_increased = false
			"nonworsening_count": g.nonworsening_headroom_candidate_count = g.feasible_candidate_count + 1
			"progress_count": g.headroom_progress_candidate_count = g.nonworsening_headroom_candidate_count + 1
			"count_type": g.headroom_progress_candidate_count = true
			"out_of_limit": g.ordered_target_positions_rad[0] = 1.601; bad.ordered_target_positions_rad[0] = 1.601
			"fallback_deficits": g.selected_deficits_rad = g.initial_deficits_rad.duplicate()
			"fallback_cost_flag": g.geometry_cost_increased = true
			"fallback_reason": g.hold_reason = "no_cost_decreasing_candidate"
		checks["headroom_refuse_" + defect] = not Source._headroom_geometry_valid(bad)
	# A separately labeled synthetic pre-completion input checks the V7 owner.
	var stance: Dictionary = fixtures[4].duplicate(true)
	stance.id = "synthetic_stance_before_completion"
	stance.request.step.memory.standing_samples_observed = 58
	fixtures.append(stance)
	var owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")
	var stance_profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_stance_profile_v1.gd")
	checks["v28_motor_owner_registered"] = owner.candidate_id_valid_v1(Source.RECOVERY)
	checks["unregistered_partial_owner_refused"] = not owner.candidate_id_valid_v1("sporespore_exact_s169_partial_progressive_headroom_controller_v29")
	checks["v28_uses_original_v7_stance"] = stance_profile.for_recovery_v1(Source.RECOVERY) == Source.STANCE
	checks["v28_stance_profile_preserves_owner"] = stance_profile.profile_for_recovery_v1(Source.RECOVERY).get("recovery_controller_id") == Source.RECOVERY
	var selected := {}
	for i in fixtures.size():
		var item: Dictionary = fixtures[i]
		var method: String = item.method + "_json"
		var raw: String = sdk.call(method, Transport.stringify(item.request))
		var envelope: Dictionary = sdk.decode_exact_json_v1(raw)
		checks["native_" + str(i)] = envelope.get("ok") == true
		if envelope.get("ok") != true: continue
		var receipt: Dictionary = envelope.value
		if item.request.get("schema_version") == "sporespore_r10ap_partial_progressive_headroom_step_control_request_v1":
			var original: Dictionary = item.request
			var context_source := {"morphology_context": original.collection.morphology_context,
				"capability": original.collection.adapter_capability, "runtime_binding": original.collection.runtime_binding}
			var bound := {"observation_v2": original.collection.observation, "observation_v3": original.step.observation,
				"source_binding": original.collection.observation_source_binding}
			var energy := {"energy_increment": original.step.energy_increment, "global_totals": original.step.native_global_energy}
			var before := Source._sha(sdk, bound)
			var assembled := Bridge.step_request_v1(context_source, bound, original.step.declaration, original.step.memory, energy)
			checks["bridge_exact_request_" + str(i)] = Source._sha(sdk, assembled) == Source._sha(sdk, original)
			var called := Bridge.call_v1(sdk, "recovery_r10ap_partial_step_control_v1_json", assembled)
			checks["bridge_native_reproduction_" + str(i)] = called.get("ok") == true and Source._sha(sdk, called.get("value", {})) == Source._sha(sdk, receipt)
			checks["bridge_bound_observation_unchanged_" + str(i)] = before == Source._sha(sdk, bound)
			var refused := Bridge.step_v1(sdk, context_source, "synthetic-missing-energy-source", bound, original.step.declaration, original.step.memory)
			checks["bridge_missing_source_refuses_before_native_" + str(i)] = refused.get("ok") == false and refused.get("call") == null
		var context := Source.control_context_v1(sdk, receipt)
		if i in [4, 6]:
			checks["terminal_cannot_create_application_" + str(i)] = context.get("ok") == false
			continue
		checks["context_" + str(i)] = context.get("ok") == true
		if context.get("ok") != true: continue
		var geometry_key := "initial_load_plan" if i == 0 else "next_load_plan"
		if context.phase in ["establish_distal_support", "raise_body"]:
			for defect in ["missing", "source", "authority", "world", "phase", "mode", "support", "rise", "shape", "baseline", "command"]:
				var bad_geometry: Dictionary = receipt.duplicate(true)
				match defect:
					"missing": bad_geometry.erase(geometry_key)
					"source": bad_geometry[geometry_key].source_observation_sha256 = "sha256:" + "0".repeat(64)
					"authority": bad_geometry[geometry_key].physical_acceptance_authority = true
					"world": bad_geometry[geometry_key].world_build_count = 1
					"phase": bad_geometry[geometry_key].phase = "complete"
					"mode": bad_geometry[geometry_key].mode = "unregistered"
					"support": bad_geometry[geometry_key].baseline_reference.qualified_support = [false]
					"rise": bad_geometry[geometry_key].progressive_headroom_geometry = 123
					"shape": bad_geometry[geometry_key].ordered_target_positions_rad = []
					"baseline": bad_geometry[geometry_key].baseline_reference = {}
					"command":
						bad_geometry[geometry_key].ordered_target_positions_rad[0] += 0.01
						if bad_geometry[geometry_key].mode in ["recover_joint_headroom", "raise_with_headroom"]:
							bad_geometry[geometry_key].progressive_headroom_geometry.ordered_target_positions_rad[0] += 0.01
				checks["geometry_refuse_" + str(i) + "_" + defect] = Source.control_context_v1(sdk, bad_geometry).get("ok") == false
			if context.phase == "raise_body":
				for defect in ["bearing_type", "candidate_count", "feasible_count", "scale", "cost", "translation", "blend", "anchor_error", "fallback_reason"]:
					var bad_anchored: Dictionary = receipt.duplicate(true)
					var anchored: Dictionary = bad_anchored[geometry_key].progressive_headroom_geometry
					match defect:
						"bearing_type": anchored.positive_bearing[0] = 1
						"candidate_count": anchored.candidate_count = 91
						"feasible_count": anchored.feasible_candidate_count = anchored.candidate_count + 1
						"scale": anchored.selected_scale = 2.0
						"cost": anchored.selected_cost = -1.0
						"translation": anchored.virtual_translation_world_m = [1.0, 0.0, 0.0]
						"blend": anchored.virtual_level_blend = 1.0
						"anchor_error": anchored.maximum_anchor_error_m = 0.001
						"fallback_reason": anchored.hold_reason = "unregistered"
					checks["anchored_refuse_" + str(i) + "_" + defect] = Source.control_context_v1(sdk, bad_anchored).get("ok") == false
		else:
			var stale_geometry: Dictionary = receipt.duplicate(true)
			stale_geometry[geometry_key] = fixtures[0].expected.initial_load_plan
			checks["stance_geometry_refused_" + str(i)] = Source.control_context_v1(sdk, stale_geometry).get("ok") == false
		if receipt.get("schema_version") == "sporespore_r10ap_partial_progressive_headroom_step_control_receipt_v1":
			var wrong_composition := receipt.duplicate(true)
			wrong_composition.control_composition_id = "unregistered"
			checks["native_composition_crossing_refused_" + str(i)] = Source.control_context_v1(sdk, wrong_composition).get("ok") == false
			var old_schema := receipt.duplicate(true)
			old_schema.schema_version = "sporespore_partial_fall_step_control_receipt_v1"
			checks["native_old_schema_refused_" + str(i)] = Source.control_context_v1(sdk, old_schema).get("ok") == false
		var wrong_owner := receipt.duplicate(true)
		var control_key := "initial_partial_control" if i == 0 else "next_control"
		wrong_owner[control_key].controller_id = "sporespore_exact_s169_prone_to_standing_controller_v20"
		checks["native_wrong_owner_refused_" + str(i)] = Source.control_context_v1(sdk, wrong_owner).get("ok") == false
		var application := _synthetic_application(context.control)
		var tagged := Source.bind_application_v1(sdk, receipt, application)
		checks["bind_" + str(i)] = tagged.get("ok") == true
		if tagged.get("ok") != true: continue
		var model := {Source.KEY: tagged.model_binding}
		selected = Source.select_v1(sdk, model, tagged.application, context.semantic_step)
		checks["select_" + str(i)] = selected.get("ok") == true and selected.get("task_id") == Source.TASK
		checks["original_application_unchanged_" + str(i)] = not application.has(Source.KEY)
		for defect in ["missing_model", "missing_application", "wrong_clock", "wrong_command", "wrong_task", "unknown_field"]:
			var bad_model := model.duplicate(true)
			var bad_app: Dictionary = tagged.application.duplicate(true)
			var step: int = context.semantic_step
			match defect:
				"missing_model": bad_model.erase(Source.KEY)
				"missing_application": bad_app.erase(Source.KEY)
				"wrong_clock": step += 1
				"wrong_command": bad_app.command_sha256 = "sha256:" + "0".repeat(64)
				"wrong_task": bad_app[Source.KEY].task_id = Source.CANONICAL_TASK
				"unknown_field": bad_app[Source.KEY].override = true
			checks["refuse_" + str(i) + "_" + defect] = Source.select_v1(sdk, bad_model, bad_app, step).get("ok") == false
			# Exercise the actual sampler's first guard with no model/world.
			var refused := Native.sample_native_step_v1(sdk, {}, bad_model, bad_app, step, context.phase)
			checks["before_read_" + str(i) + "_" + defect] = refused.get("ok") == false and String(refused.get("failure_code", "")).begins_with("R10AP_PARTIAL_TASK_SOURCE_")
	checks["missing_partial_binding_refused"] = Source.select_v1(sdk, {}, {}, 1).get("ok") == false
	checks["default_canonical"] = Native.TaskSource.select_v1(sdk, {}, {}, 1).get("task_id") == Source.CANONICAL_TASK
	for key in Source.COMPETING_KEYS:
		checks["competing_" + key] = Native.TaskSource.select_v1(sdk, {Source.KEY: {}, key: {}}, {}, 1).get("failure_code") == "R10AP_PARTIAL_TASK_SOURCE_COMPETING_TASKS"
	var crossed_entry: Dictionary = fixtures[0].expected.duplicate(true)
	crossed_entry.original_entry_control.entry.memory.route = "upright"
	checks["crossed_original_entry_refused"] = Source.control_context_v1(sdk, crossed_entry).get("ok") == false
	var measured := _measurement(sdk, selected, checks)
	sdk = null
	_finish(checks, measured, args[1])

func _finish(checks: Dictionary, measurements: Dictionary, path: String) -> void:
	var ok := not checks.is_empty() and not checks.values().has(false)
	if FileAccess.file_exists(path): quit(1); return
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null: quit(1); return
	out.store_string(Transport.stringify({"ok": ok, "checks": checks, "measurements": measurements,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	out.close()
	print("R10AP_TASK_SOURCE " + JSON.stringify({"ok": ok, "checks": checks.size(), "failed": checks.keys().filter(func(key): return not checks[key])}))
	quit(0 if ok else 1)

