extends SceneTree
const Seed := preload("res://sdk/adapters/godot/gdscript/r10ac_development_seed_v1.gd")
const Json := preload("res://sdk/adapters/godot/gdscript/r10j_campaign_seed_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var checks := {}
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Seed.PROFILE))
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		checks.unload = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks.load = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	# Use the production exact decoder so declared integers survive publication.
	var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var identity := Seed.seed_identity_v1(Seed.SEED)
	for row in fixture.cases:
		var admitted := Seed.authorized_v1(row.declaration, str(Seed.SEED), identity.label,
			identity.sha256, Seed.ROLE, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
		checks[row.name] = admitted == row.admitted
	var declaration: Dictionary = fixture.cases[0].declaration
	var report: Dictionary = fixture.report.duplicate(true)
	checks.report_attach = Seed.attach_report_context_v1(report, declaration, Seed.SEED)
	# The retained JSON is the actual argument: this helper admits parsed
	# binary64 integers against the typed expected value, not the reverse.
	checks.report_exact = Json.same_json_v1(fixture.expected_report, report)
	for row in fixture.bad_reports:
		var bad: Dictionary = row.report.duplicate(true)
		checks["report_" + row.name] = not Seed.attach_report_context_v1(bad, declaration, Seed.SEED)
		checks["unmodified_" + row.name] = Json.same_json_v1(bad, row.report)
	var prefix := Seed.prefix_selection_v1(Seed.SEED, Seed.PREFIX_PROFILE)
	checks.prefix_exact = Json.same_json_v1(fixture.prefix_selection, prefix)
	checks.gait_steps = Seed.prefix_gait_steps_v1(Seed.SEED, Seed.PREFIX_PROFILE) == {
		"front_left": 248, "front_right": 248, "rear_left": 248, "rear_right": 248}
	for seed_value in [51008, 51009, 61247]:
		checks["prefix_seed_" + str(seed_value)] = Seed.prefix_selection_v1(seed_value, Seed.PREFIX_PROFILE).is_empty()
	checks.prefix_crossed = Seed.prefix_selection_v1(Seed.SEED, "r10ab_declared_development_prefix_phase_v1").is_empty()
	# The report context must be detached from later declaration edits.
	var saved: Dictionary = report.r10ac_development.duplicate(true)
	declaration.r10ac_development.seed.prefix_phase = 249
	checks.detached_context = Json.same_json_v1(report.r10ac_development, saved)
	declaration.r10ac_development.seed.prefix_phase = 248
	var result := {"ok": not checks.values().has(false), "checks": checks,
		"report": report, "prefix_selection": prefix, "fixture": fixture,
		"counts": {"declaration_positive": 1, "declaration_negative": fixture.cases.size()-1,
			"report_positive": 1, "report_negative": fixture.bad_reports.size(),
			"prefix_positive": 1, "prefix_negative": 4},
		"world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(Transport.stringify(result) + "\n")
	file.close()
	sdk = null
	print("R10AC_DEVELOPMENT_IDENTITY ", JSON.stringify({"ok": result.ok, "counts": result.counts, "checks": checks}))
	quit(0 if result.ok else 1)
