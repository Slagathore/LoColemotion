extends "res://sdk/adapters/godot/gdscript/r10aj_development_worker_v1.gd"
## Same initializer, profile admission, launch environment and pre-world sequence.
## Only the single-use claim is replaced by read-only identity validation, and
## construction is intercepted. This program can never consume world permission.
var _pre_world_boundary := false
var _pre_world_guard: Dictionary = {}

func _declaration_path_v1() -> String:
    var args := OS.get_cmdline_user_args()
    return args[0] if args.size() == 2 else ""

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
    return R10AJSeed.authorized_v1(_campaign_declaration, seed_text, label, digest,
        OS.get_environment(CHILD_ROLE_ENV), OS.get_environment(SOURCE_COMMIT_ENV))

func _build_arm_v1(_arm_id: String) -> Dictionary:
    _pre_world_boundary = true
    _pre_world_guard = await NativeWorldScript.build_world_v1(self, _sdk, _context)
    return {"ok": false, "failure_code": "R10AJ_PRE_WORLD_CONSTRUCTION_INTERCEPTED"}

func _abort(code: String, _detail: Dictionary = {}) -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 2 or FileAccess.file_exists(args[1]):
        quit(2)
        return
    var result := {"schema_version": "sporespore_r10aj_pre_world_consumer_v1", "ok": true,
        "terminal_code": code, "comparison": get_meta("l15_prepared_context_comparison", {}),
        "construction_boundary_reached": _pre_world_boundary, "construction_guard": _pre_world_guard,
        "configuration": _configuration, "runtime_preflight": _entry_walking_runtime_preflight,
        "candidate_profile": _candidate_selection.get("candidate_profile", {}),
        "authority_claim_replaced_by_read_only_identity": true,
        "world_build_count": _total_world_build_count, "solver_step_count": _total_solver_step_count,
        "model_construction_count": _total_model_construction_count,
        "physical_acceptance_authority": false, "release_authority": false}
    var output := FileAccess.open(args[1], FileAccess.WRITE)
    output.store_string(JSON.stringify(result, "", true, true)); output.close()
    quit(0)
