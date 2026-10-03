extends SceneTree
const Identity := preload("res://sdk/discovery/recovery_panel_identity_v1.gd")
const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
func _initialize() -> void:
	var checks := {}
	for role in ["kick_passive_recovery_resume", "matched_no_kick_continuation"]:
		var declaration := {"discovery_kind":"full_recovery_panel_v1", "seed":90140,
			"source_snapshot":{"head":"fixture"}, "attempt_id":"parent",
			"children":[{"role":role,"child_attempt_id":"child"}],
			"discovery_cell":{"role":role,"phase":140}, "discovery_manifest":{"raw_sha256":"fixture"},
			"physical_acceptance_authority":false,"release_authority":false}
		var report := {"seed":90140,"arm_id":role,"source_commit":"fixture", "parent_attempt_id":"parent",
			"child_attempt_id":"child","physical_acceptance_authority":false,"release_authority":false}
		checks[role+"_accept"] = Identity.attach_report_context_v1(report,declaration,90140)
		checks[role+"_no_claim"] = report.get("held_out") == false and report.get("official_qualification") == false
		for key in ["seed","arm_id","source_commit","parent_attempt_id","child_attempt_id","physical_acceptance_authority","release_authority"]:
			var bad := report.duplicate(true)
			bad[key] = true if key.ends_with("authority") else -1 if key == "seed" else "crossed"
			checks[role+"_refuse_"+key] = not Identity.attach_report_context_v1(bad,declaration,90140)
		checks[role+"_refuse_seed_argument"] = not Identity.attach_report_context_v1(report,declaration,90141)
		declaration["development_execution_mode"] = "discovery_fresh_role_v1"
		declaration["comparative_authority"] = false
		declaration["baseline_reused"] = false
		checks[role+"_historical_profile_refuses"] = not Profile.roles_valid_v1(declaration)
	var ok := not checks.values().has(false)
	var output := OS.get_cmdline_user_args()[0]
	if FileAccess.file_exists(output): quit(2); return
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(Transport.stringify({"ok":ok,"checks":checks,"world_build_count":0,"solver_step_count":0}))
	file.close()
	quit(0 if ok else 1)
