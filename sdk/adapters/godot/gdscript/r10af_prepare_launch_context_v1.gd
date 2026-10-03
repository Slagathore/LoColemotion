extends "res://sdk/adapters/godot/gdscript/r10af_development_worker_v1.gd"
const Capture := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd")

func _initialize() -> void:
    call_deferred("_prepare")

func _prepare() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 2 or FileAccess.file_exists(args[1]):
        quit(2)
        return
    _campaign_declaration = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    var identity := R10AFSeed.seed_identity_v1(R10AFSeed.SEED)
    if not R10AFSeed.authorized_v1(_campaign_declaration, str(R10AFSeed.SEED), identity.label,
        identity.sha256, R10AFSeed.ROLE, _campaign_declaration.source_snapshot.head):
        quit(3)
        return
    _candidate_selection = CandidateProfile.load_v1(_campaign_declaration.candidate_profile)
    if _candidate_selection.is_empty():
        quit(4)
        return
    _entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(_entry_selection_v1().binding))
    _seed = R10AFSeed.SEED
    if not _load_runtime_extension_v1():
        quit(5)
        return
    _sdk = ClassDB.instantiate(CLASS_NAME)
    _context = RouteScript.prepare_complete_energy_context_v18(_sdk, RECOVERY_CONTROLLER_ID)
    var captured := Capture.capture_prepared_v1(_sdk, _context)
    if captured.get("ok") != true:
        quit(6)
        return
    var capture := Capture.snapshot_v1(captured)
    var expectation := {"raw_capture_binding": {"utf8_byte_length": capture.utf8_byte_length,
        "raw_sha256": capture.raw_sha256}, "collection_identity": JSON.parse_string(captured.expected_identity.utf8_text)}
    var result := {"schema_version": "sporespore_r10af_context_producer_v1", "ok": true,
        "capture": capture, "expectation": expectation, "candidate_profile": _campaign_declaration.candidate_profile,
        "runtime_preflight": _entry_walking_runtime_preflight, "world_build_count": 0,
        "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
    var output := FileAccess.open(args[1], FileAccess.WRITE)
    output.store_string(JSON.stringify(result, "", true, true)); output.close()
    quit(0)
