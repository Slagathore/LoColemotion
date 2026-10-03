extends SceneTree
const Seed := preload("res://sdk/adapters/godot/gdscript/r10j_campaign_seed_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		quit(1)
		return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	var cases: Dictionary = input.cases
	var results := {}
	for name in cases:
		var case: Dictionary = cases[name]
		results[name] = Seed.validate_shape_v1(case.context, case.declaration, case.claim,
			case.authority, case.preregistration, case.seed_text, case.label,
			case.digest, case.role, case.source_commit)
	var binding := {"path": arguments[0], "raw_sha256": "sha256:"+FileAccess.get_sha256(arguments[0])}
	var binding_checks := {"exact_file": not Seed._bound_json_v1(binding, arguments[0]).is_empty()}
	binding["raw_sha256"] = "sha256:"+"0".repeat(64)
	binding_checks["changed_bytes_refused"] = Seed._bound_json_v1(binding, arguments[0]).is_empty()
	binding_checks["crossed_path_refused"] = Seed._bound_json_v1(binding, arguments[0]+".absent").is_empty()
	var publication := {}
	for name in input.publication:
		var item: Dictionary = input.publication[name]
		var declaration := {"r10j_campaign": item.context}
		var before := Transport.stringify(declaration)
		var report := {"ledger_scope": {"subsystem": "recovery", "engine_scope": "godot_jolt"},
			"measured_value": 1.0000000000000002}
		var report_before := Transport.stringify(report)
		var passed := Seed.attach_report_context_v1(report, declaration, int(item.selected_seed))
		publication[name] = {"passed": passed, "report": report,
			"generic_context": item.context, "declaration_unchanged": before == Transport.stringify(declaration),
			"refusal_report_unchanged": report_before == Transport.stringify(report)}
	print("R10J_SEED_BOUNDARY "+Transport.stringify({"cases": results, "binding_checks": binding_checks,
		"publication": publication,
		"development": Seed.population_v1("development_ghost"),
		"held_out": Seed.population_v1("held_out_finite_decision"),
		"world_build_count": 0, "solver_step_count": 0}))
	quit(0)
