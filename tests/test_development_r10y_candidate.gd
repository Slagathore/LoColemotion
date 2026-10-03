extends SceneTree
const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Seed := preload("res://sdk/adapters/godot/gdscript/r10y_development_seed_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
class Worker:
	extends "res://sdk/adapters/godot/gdscript/r10y_development_worker_v1.gd"
	func _initialize() -> void: pass

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var declaration: Dictionary = input.declaration
	var chosen := Profile.load_v1(declaration.candidate_profile)
	var checks := {"actual_profile_loaded": not chosen.is_empty()}
	checks.python_godot_selection_equal = Seed.Json.same_json_v1(chosen, input.selection)
	checks.new_worker_selected = chosen.get("worker_selection", {}).get("worker") == "res://sdk/adapters/godot/gdscript/r10y_development_worker_v1.gd"
	checks.new_reader_selected = chosen.get("reader") == "res://sdk/trace_analysis/r10y_recovery_replay.gd"
	var crossed: Dictionary = declaration.candidate_profile.duplicate(true)
	crossed.raw_sha256 = "sha256:" + "0".repeat(64)
	checks.crossed_profile_hash = Profile.load_v1(crossed).is_empty()
	var identity := Seed.seed_identity_v1(51008)
	var child: Dictionary = declaration.children[0]
	var head: String = declaration.source_snapshot.head
	var worker := Worker.new()
	worker._candidate_selection = chosen
	worker._campaign_declaration = declaration
	for pair in [[Worker.CHILD_ROLE_ENV, child.role], [Worker.PARENT_ATTEMPT_ID_ENV, declaration.attempt_id],
		[Worker.ATTEMPT_ID_ENV, child.child_attempt_id], [Worker.NONCE_ENV, child.termination_nonce], [Worker.SOURCE_COMMIT_ENV, head]]:
		OS.set_environment(pair[0], pair[1])
	checks.actual_worker_identity = worker._authorized_seed_binding_v1("51008", identity.label, identity.sha256)
	OS.set_environment(Worker.NONCE_ENV, "0".repeat(32))
	checks.actual_worker_nonce_refusal = not worker._authorized_seed_binding_v1("51008", identity.label, identity.sha256)
	OS.set_environment(Worker.NONCE_ENV, child.termination_nonce)
	checks.undeclared_seed = not worker._authorized_seed_binding_v1("51007", identity.label, identity.sha256)
	checks.noncanonical_seed_text = not worker._authorized_seed_binding_v1("051008", identity.label, identity.sha256)
	for item in input.refusals:
		checks["context_refuses_" + item.label] = not Seed.authorized_v1(item.declaration, "51008", identity.label, identity.sha256, Seed.ROLE, head)
	var report := {"arm_id": child.role, "child_attempt_id": child.child_attempt_id,
		"parent_attempt_id": declaration.attempt_id, "source_commit": head, "seed": 51008}
	worker._seed = 51008
	checks.actual_publication_context = worker._attach_profile_seed_context_v1(report)
	checks.publication_no_claim = report.get("held_out") == false and report.get("held_out_cell_access_count") == 0
	checks.publication_context_equal = Seed.Json.same_json_v1(declaration.r10y_development, report.get("r10y_development"))
	report.child_attempt_id = "0".repeat(32)
	checks.publication_child_refusal = not worker._attach_profile_seed_context_v1(report)
	worker.free()
	var result := {"ok": not checks.values().has(false), "checks": checks,
		"world_build_count": 0, "solver_step_count": 0, "launch_gate_checked": false,
		"physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(Transport.stringify(result) + "\n"); file.close()
	print("R10Y_CANDIDATE_CHECKS ", checks)
	quit(0 if result.ok else 1)
