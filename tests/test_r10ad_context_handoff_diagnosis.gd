extends "res://sdk/adapters/godot/gdscript/r10ad_development_worker_v1.gd"
## Post-exposure zero-world experiment. Deliberately replace the initializer;
## never invoke campaign loading, world permission, arm construction or stepping.
const Capture := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd")

func _initialize() -> void:
    call_deferred("_probe")

func _probe() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 3:
        quit(2)
        return
    var request: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    _campaign_declaration = request.declaration
    _candidate_selection = {"candidate_profile": _campaign_declaration.candidate_profile}
    # Exercise the exact diagnostic binder and DLL, without the launch/source-key
    # admission path of the consumed attempt. The production comparator below is unchanged.
    var runtime := RouteScript.ProfileCapabilityScript.select_r10ad_diagnostic_runtime_v1(
        _campaign_declaration, _candidate_selection.candidate_profile)
    if runtime.get("ok") != true:
        push_error(JSON.stringify(runtime))
        quit(3)
        return
    var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(R10ADSeed.PROFILE))
    if "sha256:" + FileAccess.get_sha256(profile.extension) != profile.extension_sha256:
        quit(7)
        return
    if GDExtensionManager.is_extension_loaded(EXTENSION_PATH):
        if GDExtensionManager.unload_extension(EXTENSION_PATH) != GDExtensionManager.LOAD_STATUS_OK:
            quit(8)
            return
    if GDExtensionManager.load_extension(profile.extension) != GDExtensionManager.LOAD_STATUS_OK:
        quit(9)
        return
    _sdk = ClassDB.instantiate(CLASS_NAME)
    _context = RouteScript.prepare_complete_energy_context_v18(_sdk, RECOVERY_CONTROLLER_ID)
    if not _context.get("ok", false):
        quit(4)
        return
    var captured := Capture.capture_prepared_v1(_sdk, _context)
    if captured.get("ok") != true:
        quit(5)
        return
    var snapshot := Capture.snapshot_v1(captured)
    var result := {"ok": true, "mode": args[2], "capture": snapshot,
        "world_build_count": 0, "solver_step_count": 0, "population_reserved": false,
        "production_initializer_called": false, "physical_acceptance_authority": false,
        "release_authority": false}
    if args[2] == "consume":
        var expected: Dictionary = request.expected_binding
        OS.set_environment(PreWorldContextL15.LENGTH_ENV, str(int(expected.utf8_byte_length)))
        OS.set_environment(PreWorldContextL15.SHA_ENV, expected.raw_sha256)
        _repair_id = "QSDK-R10F-L15"
        result["accepted"] = _verify_l15_prepared_context_before_world_v1()
        result["comparison"] = get_meta("l15_prepared_context_comparison")
    elif args[2] != "produce":
        quit(6)
        return
    var output := FileAccess.open(args[1], FileAccess.WRITE)
    output.store_string(JSON.stringify(result))
    output.close()
    quit(0)
