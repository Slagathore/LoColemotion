extends SceneTree
## Real candidate/reader admission and native image selection; no inserted world.
const Candidate := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Seed := preload("res://sdk/adapters/godot/gdscript/r10aj_development_seed_v1.gd")
const Capability := preload("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
var checks := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var declaration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var reference := {"resource": Seed.PROFILE, "raw_sha256": Seed.PROFILE_SHA}
	var selection := Candidate.load_v1(reference)
	checks["real_candidate_admitted"] = not selection.is_empty()
	if selection.is_empty():
		_finish(args[1]); return
	checks["worker_selected"] = selection.worker_selection.worker == "res://sdk/adapters/godot/gdscript/r10aj_development_worker_v1.gd"
	checks["reader_selected"] = selection.reader == "res://sdk/trace_analysis/r10aj_recovery_replay.gd"
	checks["declaration_required"] = selection.get("diagnostic_reader_requires_declaration") == true
	checks["partial_controller"] = Candidate.WalkingPolicy.R10AJ.task.controller_composition.partial_support_raise_controller == "sporespore_exact_s169_partial_hip_recenter_controller_v26"
	checks["prefix_seed"] = Candidate.WalkingPolicy.R10AJ.prefix_selection_v1(Seed.SEED, Seed.PREFIX_PROFILE) == Seed.prefix_selection_v1(Seed.SEED, Seed.PREFIX_PROFILE)
	for seed in [65248, 40200, 67247, 67249]:
		checks["reject_seed_" + str(seed)] = Seed.seed_identity_v1(seed).is_empty()
	for field in ["resource", "raw_sha256"]:
		var crossed := reference.duplicate(true)
		crossed[field] = "crossed"
		checks["reject_profile_" + field] = Candidate.load_v1(crossed).is_empty()
	for key in ["seed", "candidate_profile", "runtime", "source_snapshot", "official_qualification"]:
		var crossed := declaration.duplicate(true)
		crossed[key] = 65248 if key == "seed" else true if key == "official_qualification" else {}
		checks["reject_runtime_" + key] = Capability.select_r10aj_diagnostic_runtime_v1(crossed, reference).get("ok") == false
	var selected := Capability.select_r10aj_diagnostic_runtime_v1(declaration, reference)
	checks["exact_native_runtime"] = selected.get("ok") == true
	checks["runtime_grants_no_world"] = selected.get("physical_execution_authorized") == false
	checks["repeated_exact_runtime"] = Capability.select_r10aj_diagnostic_runtime_v1(declaration, reference).get("ok") == true
	checks["predecessor_runtime_refused"] = Capability.select_r10ag_diagnostic_runtime_v1(declaration, reference).get("failure_code") == "R10AG_NATIVE_RUNTIME_CROSSED_SELECTION"
	var refusal := await World.build_world_v1(null, null, {})
	checks["native_world_refused"] = refusal.get("failure_code") == "R10AJ_NATIVE_WORLD_QUALIFICATION_PENDING"
	var worker_script: Script = load(selection.worker_selection.worker)
	checks["worker_compiles"] = worker_script != null and worker_script.can_instantiate()
	var reader_script: Script = load(selection.reader)
	checks["reader_compiles"] = reader_script != null and reader_script.can_instantiate()
	var worker: SceneTree = worker_script.new()
	checks["worker_initialization_refused"] = not worker._authorized_seed_binding_v1(str(Seed.SEED), Seed.seed_identity_v1(Seed.SEED).label, Seed.seed_identity_v1(Seed.SEED).sha256)
	worker.free()
	_finish(args[1])

func _finish(path: String) -> void:
	var result := {"ok": not checks.values().has(false), "checks": checks,
		"world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result) + "\n"); file.close()
	print("R10AJ_ADMISSION ", JSON.stringify(result))
	quit(0 if result.ok else 1)
