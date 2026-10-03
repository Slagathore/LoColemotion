extends "res://sdk/adapters/godot/gdscript/r10ap_linked_capture_worker_v1.gd"
## Full production V28 recovery, settling and walking with a prospective discovery population.
const Discovery := preload("res://sdk/discovery/recovery_discovery_context_v1.gd")
const Capture := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd")
const SELF := "res://sdk/discovery/recovery_panel_worker_v1.gd"
const ReportFile := preload("res://sdk/discovery/recovery_report_file_v1.gd")
var _discovery_mode := "physical"
var _discovery_output := ""

func _publish_profiled_report_wire_v1(report: Dictionary) -> Dictionary:
	if Discovery.declaration.get("report_publication") != "direct_file_v1":
		return super._publish_profiled_report_wire_v1(report)
	var path: String = Discovery.declaration.children[0].evidence_path + "/" + ReportFile.FILE_NAME
	var written := ReportFile.write_new(path,report)
	if written.get("ok") != true:
		push_error("DISCOVERY_REPORT_FILE_FAILED:"+str(written))
		_schedule_exit_v1(1,"discovery_report_file_failed")
		return {"raw":"","raw_sha256":"","byte_length":0}
	written["parent_attempt_id"] = report.parent_attempt_id
	written["child_attempt_id"] = report.child_attempt_id
	written["physical_acceptance_authority"] = false
	written["release_authority"] = false
	print(ReportFile.MARKER,JsonTransportScript.stringify(written))
	return {"raw":"","raw_sha256":written.raw_sha256,"byte_length":written.byte_length}

func _candidate_roles_valid_v1(declaration: Dictionary) -> bool:
	# initialize() has already verified the exact prospective manifest and cell.
	return (Discovery.selected() and declaration == Discovery.declaration
		and declaration.get("discovery_kind") == "full_recovery_panel_v1"
		and declaration.get("development_execution_mode") == "discovery_fresh_role_v1"
		and declaration.get("comparative_authority") == false
		and declaration.get("baseline_reused") == false
		and declaration.children.size() == 1
		and declaration.children[0].role == declaration.discovery_cell.role
		and declaration.children[0].role in ["kick_passive_recovery_resume", "matched_no_kick_continuation"])

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] in ["prepare", "preworld"]:
		_discovery_mode = args[0]
		_discovery_output = args[1]
	elif not args.is_empty():
		quit(2)
		return
	if not Discovery.initialize(OS.get_environment(Discovery.ENV), _discovery_mode != "physical") or not Discovery.install_walking_behavior():
		push_error("DISCOVERY_INITIALIZATION_REFUSED")
		quit(2)
		return
	if _discovery_mode == "prepare":
		call_deferred("_prepare_discovery_context")
		return
	super._initialize()

func _prepare_discovery_context() -> void:
	_campaign_declaration = Discovery.declaration
	_candidate_selection = CandidateProfile.load_v1(_campaign_declaration.candidate_profile)
	if _candidate_selection.is_empty():
		push_error("DISCOVERY_CANDIDATE_PROFILE")
		quit(3)
		return
	_entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(_entry_selection_v1().binding))
	_seed = int(_campaign_declaration.seed)
	if not _load_runtime_extension_v1():
		push_error("DISCOVERY_RUNTIME")
		quit(4)
		return
	_sdk = ClassDB.instantiate(CLASS_NAME)
	_context = RouteScript.prepare_complete_energy_context_v18(_sdk, RECOVERY_CONTROLLER_ID)
	var captured := Capture.capture_prepared_v1(_sdk, _context)
	if captured.get("ok") != true:
		push_error("DISCOVERY_CONTEXT")
		quit(5)
		return
	var snapshot := Capture.snapshot_v1(captured)
	var prefix_probe := _synthetic_prefix_probe()
	if prefix_probe.get("ok") != true:
		_write_probe({"ok": false, "failure_code": "DISCOVERY_PREFIX_INTERFACE", "detail": prefix_probe})
		return
	_write_probe({"ok": true, "world_build_count": 0, "solver_step_count": 0,
		"expectation": {"raw_capture_binding": {"utf8_byte_length": snapshot.utf8_byte_length,
		"raw_sha256": snapshot.raw_sha256}, "collection_identity": JSON.parse_string(captured.expected_identity.utf8_text)},
		"runtime_preflight": _entry_walking_runtime_preflight, "synthetic_prefix_probe": prefix_probe})

func _synthetic_prefix_probe() -> Dictionary:
	# A synthetic state exercises every real worker event builder and transition
	# in the prefix. It is never used to initialize a physical world.
	var sha := "sha256:" + "1".repeat(64)
	var initialized := R10AP.initialize_v1(_sdk, "ffffffffffffffffffffffffffffffff", _campaign_declaration.children[0].role, "synthetic-discovery-model", sha, sha)
	if initialized.get("ok") != true: return initialized
	var state: Dictionary = initialized.state
	state.phase = Orchestrator.PHASE_WALKING_PREFIX
	state.previous_global_semantic_step = 241
	state.total_completed_solver_step_count = 241
	state.state_revision = 241
	state.precondition_recovery_step_count = 240
	state.precondition_pair_ready = true
	state.precondition_pair_release_step_count = 1
	state.payload_sha256 = R10AP.Prior._payload_sha256_v1(_sdk, state)
	var retained := []
	for local_step in range(1, 31):
		var fields := {"event_kind":"walking_policy_step", "global_semantic_step":241+local_step,
			"control_owner":"walking_bw5r_b", "actuation_owner":"walking_bw5r_b", "application_intent_sha256":sha,
			"walking_session_id":"synthetic-prefix", "walking_session_local_step":local_step,
			"walking_actuation_applied":_walking_owner_for_phase_v1(state.phase) == "walking_bw5r_b"}
		var event := _build_orchestrator_event_v1(state, fields)
		if event.get("ok") != true: return {"ok":false,"step":local_step,"detail":event,"state":state}
		var advanced := _advance_orchestrator_step_v1(state, event.event)
		if advanced.get("ok") != true: return advanced
		retained.append({"event":event.event,"advance":advanced})
		state = advanced.state_after
	return {"ok":state.phase == Orchestrator.PHASE_INTERACTION, "transitions":retained,"world_build_count":0,"solver_step_count":0}

func _write_probe(value: Dictionary) -> void:
	if FileAccess.file_exists(_discovery_output):
		quit(6)
		return
	var file := FileAccess.open(_discovery_output, FileAccess.WRITE)
	file.store_string(JsonTransportScript.stringify(value))
	file.close()
	quit(0 if value.get("ok") == true else 7)

func _build_arm_v1(arm_id: String) -> Dictionary:
	if _discovery_mode == "preworld":
		# Execute the real construction boundary with permission withheld.
		var world: Script = load("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
		var refusal: Dictionary = await world.build_world_v1(self, _sdk, _context)
		_write_probe({"ok": refusal.get("failure_code") == "DISCOVERY_WORLD_PERMISSION_REFUSED",
			"guard": refusal, "world_build_count": 0, "solver_step_count": 0,
			"l15_prepared_context_comparison": get_meta("l15_prepared_context_comparison", {})})
		return {"ok": false, "failure_code": "DISCOVERY_PREWORLD_COMPLETE"}
	return await super._build_arm_v1(arm_id)

func _abort(code: String, detail: Dictionary = {}) -> void:
	if _discovery_mode == "preworld" and detail.get("failure_code") == "DISCOVERY_PREWORLD_COMPLETE": return
	if _discovery_mode != "physical":
		_write_probe({"ok": false, "failure_code": code, "detail": detail, "world_build_count": 0, "solver_step_count": 0})
		return
	super._abort(code, detail)

func _declaration_path_v1() -> String:
	return OS.get_environment(Discovery.ENV)

func _entry_selection_v1() -> Dictionary:
	var selection := super._entry_selection_v1().duplicate(true)
	selection["worker"] = SELF
	return selection

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	if not Discovery.selected(): return false
	var value := Discovery.declaration
	var expected := "DISCOVERY-PHASE-" + str(int(value.discovery_cell.phase)) + "-V1"
	return (seed_text == str(int(value.seed)) and label == expected and digest == "sha256:" + expected.sha256_text()
		and OS.get_environment(PARENT_ATTEMPT_ID_ENV) == value.attempt_id
		and OS.get_environment(ATTEMPT_ID_ENV) == value.children[0].child_attempt_id
		and OS.get_environment(NONCE_ENV) == value.children[0].termination_nonce
		and OS.get_environment(SOURCE_COMMIT_ENV) == value.source_snapshot.head)

func _load_runtime_extension_v1() -> bool:
	if not Discovery.select_runtime(RouteScript.ProfileCapabilityScript) or _entry_runtime.is_empty(): return false
	# Exact retained DLL and current host source are already verified by the new
	# manifest. Historical Rust pins stay with that immutable DLL's provenance.
	var selected: Dictionary = _entry_runtime.runtime
	for path in ["res://" + String(_entry_runtime.local_build_path), selected.path]:
		if "sha256:" + FileAccess.get_sha256(path) != selected.raw_sha256: return false
	if GDExtensionManager.is_extension_loaded(EXTENSION_PATH):
		if GDExtensionManager.unload_extension(EXTENSION_PATH) != GDExtensionManager.LOAD_STATUS_OK: return false
	if GDExtensionManager.load_extension(_entry_selection_v1().extension) != GDExtensionManager.LOAD_STATUS_OK or not ClassDB.class_exists(CLASS_NAME): return false
	var probe: Object = ClassDB.instantiate(CLASS_NAME)
	_entry_walking_runtime_preflight = LocomotionFacade.portable_session_preflight_v1(probe, _seed, true, Discovery.PREFIX)
	return _entry_walking_runtime_preflight.get("ok") == true and not GDExtensionManager.is_extension_loaded(EXTENSION_PATH)

func _walking_prefix_profile_id_v1(segment: String) -> String:
	return Discovery.PREFIX if segment == "walking_prefix" else ""

func _attach_profile_seed_context_v1(report: Dictionary) -> bool:
	return preload("res://sdk/discovery/recovery_panel_identity_v1.gd").attach_report_context_v1(report, Discovery.declaration, _seed)
