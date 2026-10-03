extends SceneTree
# gdlint: disable=max-line-length

const Guard := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_pre_world_context_v1.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const RetentionFixture := preload(
	"res://tests/test_sdk_qsdk_r10f_l15_worker_retention_zero_world.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _receive_v1()
	print(OS.get_environment("SPORESPORE_GODOT_RECOVERY_RAW_MARKER"), Transport.stringify(result))
	var ready := {
		"schema_version": "sporespore_godot_supervised_termination_ready_v1",
		"termination_protocol_id": "godot_4_7_gdscript_shutdown_containment_v1",
		"termination_nonce": OS.get_environment("SPORESPORE_GODOT_RECOVERY_TERMINATION_NONCE"),
		"process_id": OS.get_process_id(),
		"worker_receipt_emitted": true,
		"requested_exit_code": 0 if result.get("ok") == true else 1,
	}
	print(OS.get_environment("SPORESPORE_GODOT_RECOVERY_READY_MARKER"), Transport.stringify(ready))
	# The actual bounded launcher observes this owned process and terminates it.
	# Do not return to a frame loop or construct the production physics worker.
	OS.delay_msec(30000)
	quit(2)


static func _receive_v1() -> Dictionary:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or not arguments[0] in ["QSDK-R10F-L15", "QSDK-R10F-L14"]:
		return {"ok": false, "failure_code": "ENVIRONMENT_RECEIVER_SOURCE_SELECTION"}
	if (
		load("res://sdk/adapters/godot/sporespore_locomotion.gdextension") == null
		or not ClassDB.class_exists("SporeLocomotionSdk")
	):
		return {"ok": false, "failure_code": "ENVIRONMENT_RECEIVER_SDK_MISSING"}
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var context := Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	var source := FileAccess.get_file_as_string(
		"res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
	)
	var method := RetentionFixture._source_method_v1(
		source, "_verify_l15_prepared_context_before_world_v1"
	)
	if method.is_empty() or "PhysicsServer3D" in method:
		return {"ok": false, "failure_code": "ENVIRONMENT_RECEIVER_ACTUAL_METHOD"}
	var prefix := """extends RefCounted
const PreWorldContextL15 = preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_pre_world_context_v1.gd")
const REPAIR_ID = "%s"
var _repair_id = REPAIR_ID
var _sdk: Object
var _context: Dictionary = {}
"""
	var script := GDScript.new()
	script.source_code = (prefix % arguments[0]) + method
	if script.reload() != OK:
		return {"ok": false, "failure_code": "ENVIRONMENT_RECEIVER_HOST_PARSE"}
	var host: RefCounted = script.new()
	host.set("_sdk", sdk)
	host.set("_context", context)
	# Read what the real launcher delivered. Never set, repair or infer this input.
	var received := {
		Guard.LENGTH_ENV: OS.get_environment(Guard.LENGTH_ENV),
		Guard.SHA_ENV: OS.get_environment(Guard.SHA_ENV),
	}
	var accepted: bool = host.call("_verify_l15_prepared_context_before_world_v1")
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_context_environment_receiver_zero_world_v1",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "source_only_launch_environment_receiver",
			"question_class": "development",
		},
		"ok": true,
		"worker_guard_accepted": accepted,
		"source_selected_repair_id": arguments[0],
		"received_environment": received,
		"comparison":
		(
			host.get_meta("l15_prepared_context_comparison")
			if host.has_meta("l15_prepared_context_comparison")
			else null
		),
		"actual_worker_method_executed_in_detached_refcounted_host": true,
		"environment_modified_in_receiver": false,
		"complete_physical_worker_run_executed": false,
		"official_supervisor_qualification_origin_used_in_fixture": false,
		"production_v18_context_preparation_call_count": 1,
		"compiled_collection_call_count": 0,
		"portable_recovery_advance_call_count": 0,
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
