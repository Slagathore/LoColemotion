extends SceneTree
## Synthetic permission inputs and a real read-only parent-image probe. No world.
const Guard := preload("res://sdk/adapters/godot/gdscript/r10am_native_world_guard_v1.gd")
const Capability := preload("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
var checks := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var fixed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	checks.context_producer_compiles = load("res://sdk/adapters/godot/gdscript/r10am_prepare_launch_context_v1.gd") != null
	checks.pre_world_consumer_compiles = load("res://sdk/adapters/godot/gdscript/r10am_pre_world_consumer_v1.gd") != null
	checks.synthetic_fixture = fixed.get("synthetic_claim") == true
	checks.pure_claim_admitted = Guard.claim_fields_valid_v1(fixed.claim, fixed.declaration, 10002)
	for key in fixed.claim:
		var changed: Dictionary = fixed.claim.duplicate(true)
		changed.erase(key)
		checks["missing_" + key] = not Guard.claim_fields_valid_v1(changed, fixed.declaration, 10002)
	for key in ["physical_acceptance_authority", "release_authority"]:
		var changed: Dictionary = fixed.claim.duplicate(true)
		changed[key] = 0
		checks["numeric_" + key] = not Guard.claim_fields_valid_v1(changed, fixed.declaration, 10002)
	checks.wrong_pid = not Guard.claim_fields_valid_v1(fixed.claim, fixed.declaration, 10003)
	checks.empty_permission = Guard.consume_permission_v1({}, 10002).get("ok") == false
	var first := Guard.consume_permission_v1({"worker_process_id": 10002, "consumed": false}, 10002)
	checks.first_permission = first.get("ok") == true
	checks.repeat_permission = Guard.consume_permission_v1(first.get("next_permission", {}), 10002).get("ok") == false
	checks.crossed_permission_pid = Guard.consume_permission_v1({"worker_process_id": 10003, "consumed": false}, 10002).get("ok") == false
	checks.numeric_consumed = Guard.consume_permission_v1({"worker_process_id": 10002, "consumed": 0}, 10002).get("ok") == false
	checks.unclaimed_world_refused = not Guard.take_world_permission_v1()
	for flag in [true, false, 0]:
		var fixture_declaration: Dictionary = fixed.declaration.duplicate(true)
		fixture_declaration.report_fixture_only = flag
		checks["fixture_flag_refused_" + str(flag)] = not Guard.authorize_worker_v1(fixture_declaration) and Guard.startup_diagnostic_v1().get("stage") == "SYNTHETIC_DECLARATION"
	checks.missing_environment_refused = not Guard.authorize_worker_v1(fixed.declaration)
	checks.typed_startup_refusal = Guard.startup_diagnostic_v1().get("stage") == "SEED_OR_DECLARATION"
	checks.no_claim_publication = Guard.report_binding_v1().is_empty()
	var selected := Capability.select_r10am_diagnostic_runtime_v1(fixed.declaration, fixed.declaration.candidate_profile)
	checks.exact_runtime = selected.get("ok") == true
	checks.crossed_runtime_refused = Capability.select_r10ac_diagnostic_runtime_v1(fixed.declaration, fixed.declaration.candidate_profile).get("failure_code") == "R10AC_NATIVE_RUNTIME_CROSSED_SELECTION"
	var refused := await World.build_world_v1(null, null, {})
	checks.actual_world_boundary_closed = refused.get("failure_code") == "R10AM_NATIVE_WORLD_QUALIFICATION_PENDING"
	var python: String = fixed.declaration.runtime.images.python_helper.path
	var output: Array = []
	var code := OS.execute(python, PackedStringArray(["-B", ProjectSettings.globalize_path(Guard.HELPER),
		"--probe-worker", "--worker-pid", str(OS.get_process_id())]), output, true, false)
	var owner: Variant = JSON.parse_string(output[0]) if output.size() == 1 else {}
	checks.real_godot_python_parent = code == 0 and owner is Dictionary and owner.get("ok") == true
	checks.no_permission_after_probe = not Guard.take_world_permission_v1() and Guard.report_binding_v1().is_empty()
	var result := {"ok": checks.values().all(func(value): return value == true), "checks": checks,
		"owner_probe": owner, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(result) + "\n"); file.close()
	print("R10AM_NATIVE_WORLD_GUARD " + JSON.stringify(result))
	quit(0 if result.ok else 1)
