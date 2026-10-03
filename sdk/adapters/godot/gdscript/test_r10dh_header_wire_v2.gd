extends SceneTree
## Zero-world interface fixture: real declaration parser, production attachment,
## and authoritative transport. The Python reader consumes the emitted bytes.
const Identity := preload("res://sdk/adapters/godot/gdscript/r10dh_campaign_identity_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]): quit(2); return
	var declaration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var child: Dictionary = declaration.children[0]
	var phase := int(declaration.r10dh_campaign.seed.prefix_phase)
	var report := {"ok":true,"synthetic_test_fixture":true,
		"seed":int(declaration.seed),"arm_id":child.role,
		"source_commit":declaration.source_snapshot.head,"parent_attempt_id":declaration.attempt_id,
		"child_attempt_id":child.child_attempt_id,"official_qualification":false,
		"physical_acceptance_authority":false,"release_authority":false,"complete_route_proven":false,
		"diagnostic_declaration_sha256":"sha256:"+FileAccess.get_sha256(args[0]),
		"world_build_count":1,"solver_step_count":1,"global_solver_frame_count":1,
		"terminal_same_body_identity_receipt":{"ok":true},
		"retained_arm":{"walking_sessions":[{"evaluation_segment_id":"walking_prefix",
			"start_receipt":{"initial_gait_steps":{"front_left":phase,"front_right":phase,"rear_left":phase,"rear_right":phase}}}]}}
	if not Identity.attach_report_context_v1(report,declaration,int(declaration.seed)): quit(3); return
	# The header's counters are synthetic input to the header checker. The outer
	# fixture receipt records the actual zero worlds and zero steps executed.
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(Transport.stringify({"test_only":true,"world_build_count":0,"solver_step_count":0,
		"header":report,"physical_acceptance_authority":false,"release_authority":false}))
	file.close()
	quit(0)
