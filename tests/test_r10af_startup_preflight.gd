extends SceneTree
## Native identity controls plus the actual read-only Godot-to-Python preflight.
const Startup := preload("res://sdk/adapters/godot/gdscript/r10af_native_startup_v1.gd")
const Seed := preload("res://sdk/adapters/godot/gdscript/r10af_development_seed_v1.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var declaration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var id := Seed.seed_identity_v1(Seed.SEED)
	var checks := {"declared_seed": Seed.authorized_v1(declaration, str(Seed.SEED), id.label, id.sha256, Seed.ROLE, declaration.source_snapshot.head),
		"prefix_phase": Seed.prefix_selection_v1(Seed.SEED, Seed.PREFIX_PROFILE).get("prefix_phase") == 248,
		"old_seed_refused": Seed.seed_identity_v1(61248).is_empty()}
	for key in ["comparative_authority", "baseline_reused", "official_qualification", "physical_acceptance_authority", "release_authority"]:
		var bad := declaration.duplicate(true)
		bad[key] = true
		checks["claim_refused_" + key] = not Seed.authorized_v1(bad, str(Seed.SEED), id.label, id.sha256, Seed.ROLE, declaration.source_snapshot.head)
	var result := {"identity_checks": checks, "preflight": Startup.preflight_v1(args[0]),
		"synthetic_declaration": true, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(result) + "\n"); file.close()
	print("R10AF_STARTUP_PREFLIGHT " + JSON.stringify(result))
	quit(0 if checks.values().all(func(v): return v == true) else 1)
