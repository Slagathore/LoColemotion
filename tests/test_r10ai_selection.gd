extends SceneTree
const Candidate := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Admission := preload("res://sdk/adapters/godot/gdscript/r10ai_capture_selection_v1.gd")
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")
const Combined := preload("res://sdk/adapters/godot/gdscript/r10ai_complete_report_replay_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var checks := {}
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Admission.Seed.PROFILE))
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		checks.unload = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks.load = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var selected := Candidate.load_v1(fixture.reference)
	checks.selection_exact = Admission.Seed.Json.same_json_v1(selected, fixture.selection)
	checks.historical_key_refused = Candidate.load_v1(fixture.historical_reference).is_empty()
	var crossed: Dictionary = fixture.reference.duplicate(true)
	crossed.raw_sha256 = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
	checks.profile_hash_refused = Candidate.load_v1(crossed).is_empty()
	for row in fixture.negative_schedules:
		checks["schedule_"+row.name] = Admission.native_schedule_v1(row.schedule).is_empty()
	checks.entry_admitted = Candidate.WalkingEntry.valid_selection_v1(Admission.ENTRY)
	checks.start_admitted = Candidate.WalkingStart.valid_selection_v1(Admission.START)
	checks.full_amplitude_unchanged = Candidate.WalkingEntry.amplitude_v1(73,Admission.ENTRY) == 1.1/(0.82*1.75+0.4)
	checks.resume_phase_unchanged = Candidate.WalkingStart.normal_initial_gait_steps_v1(Admission.START) == {
		"front_left":90,"front_right":90,"rear_left":90,"rear_right":90}
	checks.real_facade_prefix = Facade.initial_gait_steps_v1(67248,"walking_prefix","",Admission.Seed.PREFIX_PROFILE) == {
		"front_left":248,"front_right":248,"rear_left":248,"rear_right":248}
	checks.prefix_wrong_seed = Facade.initial_gait_steps_v1(51008,"walking_prefix","",Admission.Seed.PREFIX_PROFILE).is_empty()
	checks.prefix_wrong_segment = Facade.initial_gait_steps_v1(67248,"walking_resume","",Admission.Seed.PREFIX_PROFILE).is_empty()
	checks.prefix_crossed_start = Facade.initial_gait_steps_v1(67248,"walking_prefix",Admission.START,Admission.Seed.PREFIX_PROFILE).is_empty()
	var prefix := Admission.Seed.prefix_selection_v1(67248,Admission.Seed.PREFIX_PROFILE)
	checks.prefix_receipt = Admission.Seed.Json.same_json_v1(prefix,fixture.prefix_selection)
	var diagnostic := Combined.Diagnostic.replay_report_v1(sdk,fixture.report,fixture.declaration,Admission.Seed)
	checks.diagnostic_replay = Admission.Seed.Json.same_json_v1(diagnostic,fixture.diagnostic_expected)
	var runtime_declaration: Dictionary = JSON.parse_string(Transport.stringify(fixture.declaration))
	var published: Dictionary = fixture.report.duplicate(true)
	checks.actual_worker_declaration_roundtrip = Admission.Seed.attach_report_context_v1(published,runtime_declaration,67248)
	checks.published_seed_integer = typeof(published.r10ai_development.seed.seed) == TYPE_INT and typeof(published.r10ai_development.seed.prefix_phase) == TYPE_INT
	checks.parsed_declaration_diagnostic_replay = Admission.Seed.Json.same_json_v1(Combined.Diagnostic.replay_report_v1(sdk,published,runtime_declaration,Admission.Seed),fixture.diagnostic_expected)
	# A valid diagnostic sidecar cannot authorize an incomplete controller report.
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
	checks.combined_requires_controller = Combined.replay_report_v1(sdk,fixture.report,binding,selected,fixture.declaration).get("ok") == false
	checks.combined_requires_selected_profile = Combined.replay_report_v1(sdk,fixture.report,binding,{},fixture.declaration).get("ok") == false
	var stale: Dictionary = fixture.declaration.duplicate(true)
	stale.r10ai_development.stage = "first_support_diagnostic"
	checks.combined_requires_diagnostic = Combined.replay_report_v1(sdk,fixture.report,binding,selected,stale).get("ok") == false
	var result := {"ok": not checks.values().has(false),"checks":checks,"selection":selected,
		"diagnostic_replay":diagnostic,"prefix_selection":prefix,"published_report":published,"world_build_count":0,"solver_step_count":0,
		"physical_acceptance_authority":false,"release_authority":false}
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(Transport.stringify(result)+"\n");file.close()
	sdk = null
	print("R10AI_SELECTION ",JSON.stringify({"ok":result.ok,"checks":checks}))
	quit(0 if result.ok else 1)
