extends SceneTree
const Identity := preload("res://sdk/adapters/godot/gdscript/r10dh_campaign_identity_v1.gd")
const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

func _initialize() -> void:
	var checks := {}
	for mode in ["development_ghost", "held_out"]:
		var phase := 71 if mode == "development_ghost" else 72
		var seed := 93600 + phase
		var label: String = "R10DH-" + mode.to_upper() + "-PREFIX-" + str(phase) + "-SEED-" + str(seed) + "-V1"
		for role in ["kick_passive_recovery_resume", "matched_no_kick_continuation"]:
			var declaration := {"campaign_kind":"r10dh_finite_recovery_v1", "seed":seed,
				"source_snapshot":{"head":"fixture"}, "attempt_id":"parent",
				"children":[{"role":role,"child_attempt_id":"child"}],
				"r10dh_campaign":{"schema_version":"sporespore_r10dh_campaign_child_context_v1", "mode":mode, "role":role,
					"seed":{"seed":seed,"prefix_phase":phase,"label":label,"sha256":"sha256:"+label.sha256_text()},
					"manifest":{"byte_length":123},"task_contract":{"byte_length":456},"design":{"byte_length":789}},
				"official_qualification":false,"physical_acceptance_authority":false,"release_authority":false}
			# Exercise the same parser used by the production context loader.
			declaration = JSON.parse_string(Transport.stringify(declaration))
			var report := {"seed":seed,"arm_id":role,"source_commit":"fixture", "parent_attempt_id":"parent",
				"child_attempt_id":"child","physical_acceptance_authority":false,"release_authority":false}
			var key: String = mode+"_"+role
			checks[key+"_accept"] = Identity.attach_report_context_v1(report,declaration,seed)
			checks[key+"_integer_wire"] = (typeof(report.r10dh_campaign.seed.seed) == TYPE_INT
				and typeof(report.r10dh_campaign.seed.prefix_phase) == TYPE_INT
				and typeof(report.r10dh_campaign.manifest.byte_length) == TYPE_INT
				and typeof(report.r10dh_campaign.task_contract.byte_length) == TYPE_INT
				and typeof(report.r10dh_campaign.design.byte_length) == TYPE_INT)
			for bad_length in [true, -1, 1.5, "123", 9007199254740992]:
				var bad := declaration.duplicate(true)
				bad.r10dh_campaign.manifest.byte_length = bad_length
				checks[key+"_length_"+str(bad_length)] = not Identity.attach_report_context_v1(report,bad,seed)
			checks[key+"_held_out"] = report.held_out == (mode == "held_out") and report.held_out_cell_access_count == (1 if mode == "held_out" else 0)
			for field in ["seed","arm_id","source_commit","parent_attempt_id","child_attempt_id","physical_acceptance_authority","release_authority","official_qualification","complete_route_proven"]:
				var bad := report.duplicate(true)
				bad[field] = -1 if field == "seed" else "crossed" if field in ["arm_id","source_commit","parent_attempt_id","child_attempt_id"] else true
				checks[key+"_refuse_"+field] = not Identity.attach_report_context_v1(bad,declaration,seed)
			for bad_phase in [-1, 360, true, 71.5, 248]:
				var bad := declaration.duplicate(true)
				bad.r10dh_campaign.seed.prefix_phase = bad_phase
				checks[key+"_phase_"+str(bad_phase)] = not Identity.attach_report_context_v1(report,bad,seed)
			declaration["development_execution_mode"] = "r10dh_fresh_role_v1"
			declaration["comparative_authority"] = false
			declaration["baseline_reused"] = false
			checks[key+"_legacy_separation"] = not Profile.roles_valid_v1(declaration)
	var ok := not checks.values().has(false)
	var output := OS.get_cmdline_user_args()[0]
	if FileAccess.file_exists(output): quit(2); return
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(Transport.stringify({"ok":ok,"checks":checks,"world_build_count":0,"solver_step_count":0}))
	file.close()
	quit(0 if ok else 1)
