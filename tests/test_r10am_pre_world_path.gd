extends "res://sdk/adapters/godot/gdscript/r10am_development_worker_v1.gd"
## Campaign/qualification admission is explicitly doubled; the inherited _run
## executes the real physics-settings, DLL, context and configuration sequence.
## The construction override invokes only the unqualified-world refusal.
const Prepared := preload("res://sdk/adapters/godot/gdscript/r10am_prepared_context_v1.gd")
const Capture := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd")
var _probe_request: Dictionary = {}
var _probe_output := ""
var _probe_mode := ""
var _probe_boundary := false
var _probe_guard: Dictionary = {}

func _initialize() -> void:
    call_deferred("_probe")

func _probe() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 3:
        quit(2)
        return
    _probe_request = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    _probe_output = args[1]
    _probe_mode = args[2]
    _campaign_declaration = _probe_request.declaration
    var inputs := Prepared.inputs_v1(_campaign_declaration)
    if inputs.is_empty():
        _finish(false, "R10AM_PREFLIGHT_INPUTS")
        return
    _candidate_selection = inputs.candidate_selection
    _entry_runtime = inputs.entry_runtime
    _seed = int(inputs.seed)
    _authorized_arm_id = R10AMSeed.ROLE
    _repair_id = "QSDK-R10F-L15"
    if _probe_mode == "produce":
        if not _load_runtime_extension_v1():
            _finish(false, "R10AM_PREFLIGHT_RUNTIME")
            return
        _sdk = ClassDB.instantiate(CLASS_NAME)
        _context = RouteScript.prepare_complete_energy_context_v18(_sdk, RECOVERY_CONTROLLER_ID)
        _finish(_context.get("ok") == true, "")
    elif _probe_mode == "consume":
        var expected: Dictionary = _probe_request.expected_binding
        OS.set_environment(PreWorldContextL15.LENGTH_ENV, str(int(expected.utf8_byte_length)))
        OS.set_environment(PreWorldContextL15.SHA_ENV, expected.raw_sha256)
        # Real inherited startup after the explicitly replaced launch-binding step.
        await _run()
    else:
        _finish(false, "R10AM_PREFLIGHT_MODE")

func _load_campaign_binding_v1() -> bool:
    var identity := R10AMSeed.seed_identity_v1(_seed)
    return R10AMSeed.authorized_v1(_campaign_declaration, str(_seed), identity.label,
        identity.sha256, _authorized_arm_id, _campaign_declaration.source_snapshot.head)

func _build_arm_v1(_arm_id: String) -> Dictionary:
    _probe_boundary = true
    _probe_guard = await NativeWorldScript.build_world_v1(self, _sdk, _context)
    return {"ok": false, "failure_code": "R10AM_PREFLIGHT_STOP_BEFORE_WORLD"}

func _abort(code: String, _detail: Dictionary = {}) -> void:
    _finish(true, code)

func _finish(ok: bool, code: String) -> void:
    var capture := {}
    if _sdk != null and _context.get("ok") == true:
        capture = Capture.snapshot_v1(Capture.capture_prepared_v1(_sdk, _context))
    var result := {"ok": ok, "mode": _probe_mode, "terminal_code": code,
        "capture": capture, "comparison": get_meta("l15_prepared_context_comparison", {}),
        "construction_boundary_reached": _probe_boundary, "construction_guard": _probe_guard,
        "configuration": _configuration, "runtime_preflight": _entry_walking_runtime_preflight,
        "campaign_admission_doubled": true, "world_build_count": _total_world_build_count,
        "world_attempt_count": _total_world_attempt_count, "solver_step_count": _total_solver_step_count,
        "model_construction_count": _total_model_construction_count,
        "population_reserved": false, "physical_acceptance_authority": false, "release_authority": false}
    var output := FileAccess.open(_probe_output, FileAccess.WRITE)
    output.store_string(JSON.stringify(result))
    output.close()
    quit(0 if ok else 1)
