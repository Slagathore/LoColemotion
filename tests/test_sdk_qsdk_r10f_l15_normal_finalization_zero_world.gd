extends SceneTree
# gdlint: disable=max-line-length

## Actual normal finalizer, arm projection, session-close check and identity
## reader. Quiescence, cleanup, exit and abort dispatch are named test seams.
## Its single completed precondition-negative step is SYNTHETIC source input.
const Worker := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd")
const Retention := preload("res://tests/test_sdk_qsdk_r10f_l15_worker_retention_zero_world.gd")
const Context := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd")
const Guard := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_pre_world_context_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MARKER := "QSDK_R10F_L15_NORMAL_FINALIZATION_ZERO_WORLD "
const RAW_MARKER := "QSDK_R10F_L15_NORMAL_FINALIZATION_RAW "
const ABSENT_MARKER := "QSDK_R10F_L15_NORMAL_FINALIZATION_ABSENT_METADATA_RAW "
const PARENT := "0123456789abcdef0123456789abcdef"
const CHILD := "22222222222222222222222222222222"
const MODEL := "synthetic-normal-finalization-model"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# The finalizer reads the real scheduler setting. Match the production setup
	# only during this synchronous source fixture; no solver callback is connected.
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = Worker.PHYSICS_HZ
	var receipt := evaluate_v1()
	Engine.physics_ticks_per_second = original_ticks
	receipt["fixture_scheduler_tick_setting_restored"] = (
		Engine.physics_ticks_per_second == original_ticks
	)
	print(MARKER, Transport.stringify(receipt))
	quit(0 if receipt.get("ok") == true else 1)


static func evaluate_v1() -> Dictionary:
	if load(Worker.EXTENSION_PATH) == null or not ClassDB.class_exists(Worker.CLASS_NAME):
		return {"ok": false, "failure_code": "NORMAL_FINALIZATION_SDK_MISSING"}
	var sdk: Object = ClassDB.instantiate(Worker.CLASS_NAME)
	var context := Worker.RouteScript.prepare_complete_energy_context_v18(
		sdk, Worker.RECOVERY_CONTROLLER_ID
	)
	var captured := Context.snapshot_v1(Context.capture_prepared_v1(sdk, context))
	var comparison := Guard.compare_prepared_v1(
		sdk,
		context,
		{"utf8_byte_length": captured["utf8_byte_length"], "raw_sha256": captured["raw_sha256"]}
	)
	var configuration := Worker.LocomotionFacade.configuration_receipt_v1(sdk)
	var bootstrap := Worker._initial_bootstrap_zero_world_controls_v1(sdk, context)
	if (
		comparison.get("ok") != true
		or configuration.get("ok") != true
		or bootstrap.get("ok") != true
	):
		return {"ok": false, "failure_code": "NORMAL_FINALIZATION_PREPARED_SOURCES_INVALID"}
	# Ordinary detached Nodes are identity handles, not bodies, joints or a model.
	# The real facade identity reader only needs their live object identities.
	var handles: Array[Node] = []
	var binding := {
		"model_instance_id": MODEL,
		"body_nodes": {},
		"joint_nodes": {},
		"instance_id_by_node_id": {}
	}
	for key in Worker.LocomotionFacade.SAME_BODY_NODE_IDENTITY:
		var handle := Node.new()
		handles.append(handle)
		binding["instance_id_by_node_id"][key] = handle.get_instance_id()
		binding["body_nodes" if key.begins_with("body:") else "joint_nodes"][key.split(":")[1]] = handle
	var facade := Worker.LocomotionFacade.new()
	facade.set("_binding", binding)
	var initial := facade.same_body_identity_receipt_v1(
		sdk, 0, "explicit_detached_identity_fixture"
	)
	var outcome := _evaluate_with_handles_v1(
		sdk, configuration, bootstrap, comparison, facade, initial
	)
	for handle in handles:
		handle.free()
	return outcome


static func _evaluate_with_handles_v1(
	sdk: Object,
	configuration: Dictionary,
	bootstrap: Dictionary,
	comparison: Dictionary,
	facade: RefCounted,
	initial: Dictionary
) -> Dictionary:
	if initial.get("ok") != true:
		return {
			"ok": false,
			"failure_code": "NORMAL_FINALIZATION_IDENTITY_HANDLES_INVALID",
			"detail": initial
		}
	var config_sha := String(
		Worker.RecoveryRuntimeScript.canonicalize(sdk, configuration)["sha256"]
	)
	var body_sha: String = initial["body_population_instance_sha256"]
	var memory := {
		"phase": "failed",
		"terminal_failure_code": "explicit_synthetic_precondition_negative",
		"last_semantic_step": 1.0
	}
	var classification := {"stable_stance_gate": false}
	var step := {
		"memory": memory.duplicate(true),
		"classification": classification.duplicate(true),
		"next_phase": "failed"
	}
	var terminal := Worker.ProcessIsolatedChildContract.build_precondition_terminal_receipt_v1(
		sdk,
		PARENT,
		CHILD,
		Worker.ARM_ORDER[1],
		MODEL,
		1,
		Worker.RECOVERY_CONTROLLER_ID,
		memory,
		step,
		classification,
		0,
		0,
		0
	)
	var initialized := Worker.Orchestrator.initialize_v1(
		sdk, CHILD, Worker.ARM_ORDER[1], MODEL, config_sha, body_sha
	)
	if terminal.get("ok") != true or initialized.get("ok") != true:
		return {"ok": false, "failure_code": "NORMAL_FINALIZATION_TERMINAL_SOURCES_INVALID"}
	var event := (
		Worker
		. Orchestrator
		. build_event_v1(
			sdk,
			initialized["state"],
			{
				"event_kind": "recovery_controller_step",
				"global_semantic_step": 1,
				"control_owner": "recovery_v6",
				"actuation_owner": "recovery_v6",
				"recovery_actuation_applied": true,
				"application_intent_sha256": "sha256:" + "9".repeat(64),
				"recovery_controller_terminal_phase": "failed",
				"recovery_controller_terminal_reason": memory["terminal_failure_code"],
			}
		)
	)
	if event.get("ok") != true:
		return event
	var advanced := Worker.Orchestrator.advance_v1(sdk, initialized["state"], event["event"])
	if advanced.get("ok") != true:
		return advanced
	var counter := Worker._collection_solver_counter_projection_v1(
		Worker._solver_counter_collection_fixture_v1(1), 1
	)
	var row := {
		"schema_version": "sporespore_qsdk_r10f_compact_native_trace_row_v1",
		"arm_id": Worker.ARM_ORDER[1],
		"global_semantic_step": 1,
		"body_population_instance_sha256": body_sha,
		"source_measurement": true
	}
	var invariant := {
		"schema_version": "sporespore_qsdk_r10f_in_run_native_invariant_v1",
		"arm_id": Worker.ARM_ORDER[1],
		"global_semantic_step": 1,
		"body_population_instance_sha256": body_sha,
		"solver_counter_projection": counter,
		"predicates":
		{
			"collector_cumulative_solver_step_exact": true,
			"collector_global_counter_binding_exact": true,
			"accepted_collection_step_delta_exact": true,
			"collector_counter_outcome_correction_zero": true
		},
		"all_in_run_physical_invariants_passed": true,
		"physical_acceptance_authority": false,
		"release_authority": false
	}
	var arm := {
		"arm_id": Worker.ARM_ORDER[1],
		"model_instance_id": MODEL,
		"body_population_instance_sha256": body_sha,
		"facade": facade,
		"model": {"solver_step_count": 1},
		"trace_rows": [row],
		"invariant_receipts": [invariant],
		"orchestrator_state": advanced["state_after"],
		"terminal": true,
		"initial_same_body_identity_receipt": initial,
		"initial_application_validation_receipt": bootstrap["consumer_validation"],
		"recovery_memory": memory,
		"recovery_step_receipts": [step],
		"active_walking_session": {},
		"walking_sessions": [],
		"walking_actuation_handoff_receipts": [],
		"recovery_initialization_receipt": {},
		"postkick_recovery_initialization_receipt": {},
		"recovery_development_progression_receipts": [],
		"interaction_receipt": {},
		"motor_configuration_receipts": [],
		"external_kick_application_count": 0,
		"body_population_rebuild_count": 0,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
	}
	var source := FileAccess.get_file_as_string(
		"res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
	)
	var script := GDScript.new()
	script.source_code = """extends RefCounted
const W = preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd")
const GATE_ID = W.GATE_ID
const REPAIR_ID = "QSDK-R10F-L15"
var _repair_id = REPAIR_ID
const TRACE_SCHEMA = W.TRACE_SCHEMA
const ACTUATOR_MODE = W.ACTUATOR_MODE
const RECOVERY_CONTROLLER_ID = W.RECOVERY_CONTROLLER_ID
const ENERGY_ROUTE_ID = W.ENERGY_ROUTE_ID
const MAXIMUM_CHILD_SOLVER_STEPS = W.MAXIMUM_CHILD_SOLVER_STEPS
const PHYSICS_HZ = W.PHYSICS_HZ
const ProcessIsolatedChildContract = W.ProcessIsolatedChildContract
const EnergyInitializer = W.EnergyInitializer
const Orchestrator = W.Orchestrator
const RecoveryRuntimeScript = W.RecoveryRuntimeScript
const JsonTransportScript = W.JsonTransportScript
var _sdk: Object
var _configuration = {}
var _configuration_sha256 = ""
var _arms = {}
var _finalizing = false
var _exit_scheduled = false
var _authorized_arm_id = W.ARM_ORDER[1]
var _raw_schema = W.RAW_SCHEMA
var _raw_marker = "QSDK_R10F_L15_NORMAL_FINALIZATION_RAW "
var _work_id = W.L15_WORK_ID
var _source_commit = "0123456789abcdef0123456789abcdef01234567"
var _authorization_sha256 = "sha256:" + "9".repeat(64)
var _parent_attempt_id = "0123456789abcdef0123456789abcdef"
var _attempt_id = "22222222222222222222222222222222"
var _seed = W.DEVELOPMENT_SEED
var _seed_label = W.DEVELOPMENT_SEED_LABEL
var _seed_sha256 = W.DEVELOPMENT_SEED_SHA256
var _process_isolated_precondition_terminal_receipt: Dictionary = {}
var _process_isolated_precondition_release_receipt: Dictionary = {}
var _process_isolated_interaction_source: Dictionary = {}
# These are source-shaped report inputs, never observed physical counters.
var _total_model_construction_attempt_count = 1
var _total_model_construction_count = 1
var _total_world_attempt_count = 1
var _total_world_build_count = 1
var _total_solver_step_count = 1
var _observed_global_solver_frames = 1
var _external_kick_application_count = 0
var _total_native_readback_count = 0
var seam_events = []
var aborted = {}
func _quiesce_process_isolated_child_v1():
	seam_events.append("quiesce")
func _cleanup_worlds_v1():
	seam_events.append("cleanup")
	_arms.clear()
func _schedule_exit_v1(code, reason):
	_exit_scheduled = true
	seam_events.append("exit:%d:%s" % [code, reason])
func _abort(code, detail):
	aborted = {"failure_code": code, "detail": detail}
func _json_safe_v1(value):
	return W._json_safe_v1(value)
func walking_session_needs_shutdown_v2(value):
	return W.walking_session_needs_shutdown_v2(value)
func close_walking_session_sources_v2(sdk, role, value, completion) -> Dictionary:
	return W.close_walking_session_sources_v2(sdk, role, value, completion)
"""
	for name in [
		"_finalize_process_isolated_child_result_v1",
		"_process_isolated_arm_result_projection_v1",
		"_finish_walking_session_v1",
		"_canonical_sha256_v1",
		"_valid_sha256"
	]:
		var body := Retention._source_method_v1(source, name)
		if body.is_empty() or "PhysicsServer3D" in body:
			return {
				"ok": false, "failure_code": "NORMAL_FINALIZATION_UNSAFE_SOURCE", "method": name
			}
		script.source_code += body
	if script.reload() != OK:
		return {"ok": false, "failure_code": "NORMAL_FINALIZATION_HOST_PARSE"}
	var host := _configured_host_v1(script, sdk, configuration, config_sha, terminal, arm)
	host.set_meta("l15_prepared_context_comparison", comparison)
	host.call("_finalize_process_isolated_child_result_v1")
	host.call("_finalize_process_isolated_child_result_v1")
	# This deliberately bypasses the pre-world guard to test absent metadata only.
	# The production L15 guard would refuse before constructing a physical model.
	var absent := _configured_host_v1(script, sdk, configuration, config_sha, terminal, arm)
	absent.set("_raw_marker", ABSENT_MARKER)
	absent.call("_finalize_process_isolated_child_result_v1")
	var refused := _configured_host_v1(script, sdk, configuration, config_sha, terminal, arm)
	refused.set("_total_solver_step_count", 2)
	refused.call("_finalize_process_isolated_child_result_v1")
	var refusal: Dictionary = refused.get("aborted")
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_normal_finalization_zero_world_v1",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_normal_report_source_composition",
			"question_class": "development"
		},
		"ok":
		(
			host.get("aborted").is_empty()
			and host.get("_arms").is_empty()
			and absent.get("aborted").is_empty()
			and absent.get("_arms").is_empty()
			and (
				refusal.get("failure_code")
				== "QSDK_R10F_L9_CHILD_TERMINAL_POPULATION_INVARIANT_INVALID"
			)
			and refused.get("_exit_scheduled") == false
		),
		"fixture_process_id": OS.get_process_id(),
		"aborted": host.get("aborted"),
		"seam_events": host.get("seam_events"),
		"absent_metadata_seam_events": absent.get("seam_events"),
		"absent_metadata_case_bypasses_pre_world_guard": true,
		"terminal_counter_refusal": refusal,
		"terminal_counter_refusal_seam_events": refused.get("seam_events"),
		"original_context_comparison": comparison,
		"actual_normal_finalizer_and_arm_projection_executed": true,
		"actual_same_body_identity_reader_with_detached_handles": true,
		"detached_identity_handle_count": 17,
		"actual_session_close_already_closed_branch_executed": true,
		"open_session_shutdown_exercised_here": false,
		"complete_physical_worker_executed": false,
		"report_counters_and_precondition_outcome_are_synthetic": true,
		"expected_context_origin_is_test_authority_only": true,
		"native_quiescence_cleanup_exit_and_abort_dispatch_are_named_test_seams": true,
		"bootstrap_controls": bootstrap,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_physics_read_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _configured_host_v1(
	script: GDScript,
	sdk: Object,
	configuration: Dictionary,
	config_sha: String,
	terminal: Dictionary,
	arm: Dictionary
) -> RefCounted:
	var host: RefCounted = script.new()
	host.set("_sdk", sdk)
	host.set("_configuration", configuration)
	host.set("_configuration_sha256", config_sha)
	host.set("_process_isolated_precondition_terminal_receipt", terminal["receipt"])
	host.set("_arms", {Worker.ARM_ORDER[1]: arm.duplicate(true)})
	return host
