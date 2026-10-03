extends "res://sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd"
## Post-exposure read-only predicate diagnosis. Never calls the production
## initializer, native claim helper, runtime loader, world builder or solver.
var diagnostic_seed_checks := 0

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	diagnostic_seed_checks += 1
	return R10ACSeed.authorized_v1(_campaign_declaration, seed_text, label, digest,
		OS.get_environment(CHILD_ROLE_ENV), OS.get_environment(SOURCE_COMMIT_ENV))

func _initialize() -> void:
	call_deferred("_diagnose")

func _diagnose() -> void:
	var args := OS.get_cmdline_user_args()
	var declaration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var reconstruction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	_candidate_selection = reconstruction.candidate_selection
	_campaign_declaration = declaration
	var offered: Dictionary = reconstruction.environment_constants
	var tags := _worker_route_tags_v1()
	var checks := {
		"route_selected": _r10k_selected_v1(),
		"gate_id": offered.GATE_ID == GATE_ID,
		"gate_token": offered.GATE_TOKEN == GATE_TOKEN,
		"schema": offered.RAW_SCHEMA == tags.raw_schema,
		"work_id": offered.WORK_ID in tags.work_ids,
		"raw_marker": offered.RAW_MARKER == tags.raw_marker,
		"ready_marker": offered.READY_MARKER == tags.ready_marker,
		"progress_marker": offered.PROGRESS_MARKER.is_empty(),
		"progress_cadence": offered.PROGRESS_CADENCE_STEPS in ["", "0"],
		"actuator": offered.ACTUATOR_MODE == ACTUATOR_MODE,
		"controller": offered.CONTROLLER_ID == RECOVERY_CONTROLLER_ID,
		"energy_route": offered.ENERGY_ROUTE_ID == ENERGY_ROUTE_ID,
		"seed_admission": R10ACSeed.authorized_v1(declaration, offered.SEED, offered.SEED_LABEL,
			offered.SEED_SHA256, declaration.children[0].role, declaration.source_snapshot.head),
		"runtime_contract": R10ACSeed.Json.same_json_v1(declaration.runtime,
			JSON.parse_string(FileAccess.get_file_as_string(R10ACWorldGuard.Runtime.CONTRACT))),
		"claim_stays_absent": not FileAccess.file_exists(declaration.children[0].evidence_path + "/" + R10ACWorldGuard.CLAIM),
		"no_permission": R10ACWorldGuard.report_binding_v1().is_empty(),
	}
	checks.actual_binding_without_world_permission = _load_campaign_binding_v1()
	checks.actual_seed_predicate_reached = diagnostic_seed_checks == 1
	checks.guard_parent = declaration.attempt_id == OS.get_environment(PARENT_ATTEMPT_ID_ENV)
	checks.guard_child = declaration.children[0].child_attempt_id == OS.get_environment(ATTEMPT_ID_ENV)
	checks.guard_nonce = declaration.children[0].termination_nonce == OS.get_environment(NONCE_ENV)
	checks.guard_supervised = OS.get_environment(SUPERVISED_ENV) == "1"
	checks.guard_declaration_hash = "sha256:" + FileAccess.get_sha256(args[0]) == OS.get_environment(AUTHORIZATION_ENV)
	checks.guard_declaration_equal = R10ACSeed.Json.same_json_v1(JSON.parse_string(FileAccess.get_file_as_string(args[0])), declaration)
	checks.guard_contract_hash = "sha256:" + FileAccess.get_sha256(R10ACWorldGuard.Runtime.CONTRACT) == R10ACWorldGuard.Runtime.CONTRACT_SHA
	checks.guard_python_length = FileAccess.get_file_as_bytes(declaration.runtime.images.python_helper.path).size() == declaration.runtime.images.python_helper.byte_length
	checks.guard_python_hash = "sha256:" + FileAccess.get_sha256(declaration.runtime.images.python_helper.path) == declaration.runtime.images.python_helper.raw_sha256
	var output_helper: Array = []
	var helper_exit := OS.execute(declaration.runtime.images.python_helper.path,
		PackedStringArray(["-B", ProjectSettings.globalize_path("res://tests/r10ac_binding_readonly_helper.py"), args[0], str(OS.get_process_id())]), output_helper, true, false)
	var helper := {"exit_code": helper_exit, "output": output_helper}
	var result := {"readonly_helper": helper,"checks": checks, "diagnosis_only": true,
		"production_initializer_called": false, "native_claim_helper_called": false,
		"world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var output := FileAccess.open(args[2], FileAccess.WRITE)
	output.store_string(JSON.stringify(result) + "\n"); output.close()
	print("R10AC_BINDING_DIAGNOSIS " + JSON.stringify(result))
	quit(0)
