extends SceneTree
## Full native controller replay plus independently linked contact replay; no worlds.
const Discovery := preload("res://sdk/discovery/recovery_discovery_context_v1.gd")
const Identity := preload("res://sdk/discovery/recovery_panel_identity_v1.gd")
const Contacts := preload("res://sdk/discovery/recovery_panel_contacts_v1.gd")
const Controller := preload("res://sdk/adapters/godot/gdscript/r10ap_controller_report_replay_v1.gd")
const Profile := Controller.CandidateProfile
const OldSeed := preload("res://sdk/adapters/godot/gdscript/r10ap_development_seed_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
var _output := ""
var _fixture := false

func _initialize() -> void:
	call_deferred("_run")

func _finish(result: Dictionary) -> void:
	result["world_build_count"] = 0
	result["solver_step_count"] = 0
	result["test_only"] = _fixture
	result["physical_acceptance_authority"] = false
	result["release_authority"] = false
	if not _output.is_empty() and not FileAccess.file_exists(_output):
		var file := FileAccess.open(_output, FileAccess.WRITE)
		file.store_string(Transport.stringify(result))
		file.close()
	print("DISCOVERY_PANEL_REPLAY ", Transport.stringify(result))
	quit(0 if result.get("ok") == true else 1)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [4, 5] or args[0] not in ["physical", "fixture", "transport"]:
		_finish({"ok": false, "failure_code": "PANEL_READER_ARGUMENTS"}); return
	_output = args[3]
	_fixture = args[0] != "physical"
	if FileAccess.file_exists(_output) or (args[0] == "fixture" and args.size() != 5) or (args[0] != "fixture" and args.size() != 4):
		_finish({"ok": false, "failure_code": "PANEL_READER_OUTPUT_OR_FIXTURE"}); return
	if not Discovery.initialize(args[1], true) or not Discovery.install_walking_behavior():
		_finish({"ok": false, "failure_code": "PANEL_READER_SOURCE"}); return
	if not Discovery.select_runtime(Controller.Canonical.Route.ProfileCapabilityScript):
		_finish({"ok": false, "failure_code": "PANEL_READER_RUNTIME"}); return
	var selection := Profile.load_v1(Discovery.declaration.candidate_profile)
	if selection.is_empty():
		_finish({"ok": false, "failure_code": "PANEL_READER_PROFILE"}); return
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(selection.worker_selection.binding))
	for path in ["res://"+String(binding.local_build_path), binding.runtime.path]:
		if "sha256:"+FileAccess.get_sha256(path) != binding.runtime.raw_sha256:
			_finish({"ok": false, "failure_code": "PANEL_READER_DLL"}); return
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old) and GDExtensionManager.unload_extension(old) != GDExtensionManager.LOAD_STATUS_OK:
		_finish({"ok": false, "failure_code": "PANEL_READER_UNLOAD"}); return
	if GDExtensionManager.load_extension(selection.worker_selection.extension) != GDExtensionManager.LOAD_STATUS_OK:
		_finish({"ok": false, "failure_code": "PANEL_READER_LOAD"}); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var raw := FileAccess.get_file_as_string(args[2])
	var decoded: Variant = sdk.decode_exact_json_v1(raw)
	if not decoded is Dictionary:
		_finish({"ok": false, "failure_code": "PANEL_READER_JSON"}); return
	var report: Dictionary = decoded
	if args[0] == "transport":
		# This mode proves publication fidelity only and cannot satisfy the
		# physical reader's test_only=false requirement.
		raw = ""
		var written := preload("res://sdk/discovery/recovery_report_file_v1.gd").write_new(_output+".report.json",report)
		sdk = null
		_finish(written); return
	var declaration: Dictionary = Discovery.declaration
	if args[0] == "fixture":
		declaration = JSON.parse_string(FileAccess.get_file_as_string(args[4]))
		# Historical fixture bytes carry their historical diagnostic context.
		# Reconstruct it with its real binder; never rewrite retained packets.
		var historical: Dictionary = Controller.Canonical.Route.ProfileCapabilityScript.select_r10ap_diagnostic_runtime_v1(declaration, declaration.candidate_profile)
		if historical.get("ok") != true:
			_finish(historical); return
		Discovery.runtime_identity = historical.runtime_identity.duplicate(true)
	var diagnostic := Contacts.replay_report_v1(sdk, report, declaration, OldSeed if args[0] == "fixture" else Identity)
	if diagnostic.get("ok") != true:
		_finish(diagnostic); return
	var controller := Controller.replay_report_v1(sdk, report, binding,
		selection.post_kick_controller_id, selection, Profile.walking_memory_transition_id_v1(selection))
	controller["contact_replay"] = diagnostic
	controller["input_raw_sha256"] = "sha256:" + raw.sha256_text()
	controller["runtime_raw_sha256"] = binding.runtime.raw_sha256
	sdk = null
	_finish(controller)
