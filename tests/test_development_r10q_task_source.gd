extends SceneTree
# gdlint: disable=max-line-length

## Actual sampler projection on explicitly synthetic snapshots and uninserted
## bodies. No world is built, no body enters the tree, no solver is stepped.
const Source := preload("res://sdk/adapters/godot/gdscript/r10q_upright_task_source_v1.gd")
const Native := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const OLD := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const PROFILE := "res://sdk/development/recovery_candidates/r10q-upright-recovery-core-v1.json"

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
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_profile_resource_v1()))
	var checks := {}
	checks["extension_hash"] = "sha256:" + FileAccess.get_sha256(profile.extension) == profile.extension_sha256
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
	checks["runtime_hash"] = "sha256:" + FileAccess.get_sha256(binding.runtime.path) == profile.runtime_sha256
	if GDExtensionManager.is_extension_loaded(OLD):
		checks["unload"] = GDExtensionManager.unload_extension(OLD) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	if checks.values().has(false): _finish(checks, {}, args[1]); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixtures := []
	for line in FileAccess.get_file_as_string(args[0]).split("\n"):
		if line.begins_with("R10Q_UPRIGHT_FIXTURE "):
			fixtures.append(sdk.decode_exact_json_v1(line.trim_prefix("R10Q_UPRIGHT_FIXTURE ")))
	checks["fixture_population"] = fixtures.size() == 3
	# A separately labeled synthetic pre-completion input checks the V7 owner.
	var stance: Dictionary = fixtures[2].duplicate(true)
	stance.id = "synthetic_stance_before_completion"
	stance.request.step.memory.standing_samples_observed = 58
	fixtures.append(stance)
	var selected := {}
	for i in fixtures.size():
		var item: Dictionary = fixtures[i]
		var method: String = item.method + "_json"
		var raw: String = sdk.call(method, Transport.stringify(item.request))
		var envelope: Dictionary = sdk.decode_exact_json_v1(raw)
		checks["native_" + str(i)] = envelope.get("ok") == true
		if envelope.get("ok") != true: continue
		var receipt: Dictionary = envelope.value
		var context := Source.control_context_v1(sdk, receipt)
		if i == 2:
			checks["terminal_cannot_create_application"] = context.get("ok") == false
			continue
		checks["context_" + str(i)] = context.get("ok") == true
		if context.get("ok") != true: continue
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
			checks["before_read_" + str(i) + "_" + defect] = refused.get("ok") == false and String(refused.get("failure_code", "")).begins_with("R10Q_UPRIGHT_TASK_SOURCE_")
	checks["missing_upright_binding_refused"] = Source.select_v1(sdk, {}, {}, 1).get("ok") == false
	checks["default_canonical"] = Native.TaskSource.select_v1(sdk, {}, {}, 1).get("task_id") == Source.CANONICAL_TASK
	checks["competing_tasks_refused"] = Native.TaskSource.select_v1(sdk, {Source.KEY: {}, Source.Partial.KEY: {}}, {}, 1).get("failure_code") == "R10Q_UPRIGHT_TASK_SOURCE_COMPETING_TASK_BINDING"
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
	print("R10Q_TASK_SOURCE " + JSON.stringify({"ok": ok, "checks": checks.size(), "failed": checks.keys().filter(func(key): return not checks[key])}))
	quit(0 if ok else 1)

func _profile_resource_v1() -> String:
	return PROFILE
