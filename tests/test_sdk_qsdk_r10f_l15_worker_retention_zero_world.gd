extends SceneTree
# gdlint: disable=max-line-length

## Complete new worker stage and the actual abort partial-arm projector.
## PhysicalWorker is only a script of static helpers; no instance is created.
const Stage := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_recovery_advance_stage_v1.gd"
)
const CaptureFixture := preload(
	"res://tests/test_sdk_qsdk_r10f_l15_collection_transport_zero_world.gd"
)
const RouteFixture := preload("res://tests/test_sdk_qsdk_r10f_l15_route_retention_zero_world.gd")
const PhysicalWorker := preload(
	"res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
)
const Owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MARKER := "QSDK_R10F_L15_WORKER_RETENTION_ZERO_WORLD "
const ABORT_MARKER := "QSDK_R10F_L15_SYNTHETIC_ABORT_RAW "
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := evaluate_v1()
	print(MARKER, Transport.stringify(result))
	quit(0 if result.get("ok") == true else 1)


static func evaluate_v1() -> Dictionary:
	var fixture := CaptureFixture.source_fixture_v1()
	if fixture.get("ok") != true:
		return fixture
	var controls := {}
	var cases := {}
	var retained_arms := {}
	var success_arm := {}
	var refused_arm := {}
	var genuine_calls := 0
	var step_calls := 0
	var planning_calls := 0
	# Expected request identity comes from the independently prepared context,
	# not any accepted or refused request packet. It is fixture authority only.
	var expected_identity := {
		"task_id": Route.TASK_ID,
		"semantics_id": Route.SEMANTICS_ID,
		"actuator_profile_id": Route.ACTUATOR_PROFILE_ID,
		"descriptor": Route.exact_base_descriptor_v1(),
		"morphology_context": fixture["context"]["morphology_context"].duplicate(true),
		"adapter_capability": fixture["context"]["capability"].duplicate(true),
		"runtime_binding": fixture["context"]["runtime_binding"].duplicate(true),
		"arm_kind": PhysicalWorker.INTERNAL_RECOVERY_ARM_KIND,
	}
	for label in [
		"success", "native_schema_refusal", "malformed_reply", "dispatch_refusal", "missing_memory"
	]:
		var counted := RouteFixture.CountedRoute.new()
		counted.sdk = fixture["sdk"]
		var context: Dictionary = fixture["context"].duplicate(true)
		var bound: Dictionary = fixture["bound"].duplicate(true)
		# A nonphysics sentinel tests object identity without constructing a body.
		var sentinel := RefCounted.new()
		var arm := {
			"pending_application": fixture["application"].duplicate(true),
			"recovery_memory": fixture["memory"].duplicate(true),
			"model": sentinel,
			"model_instance_id": "synthetic_retention_model",
			"trace_rows": [{"global_semantic_step": 509, "source": "synthetic_partial_trace"}],
			"orchestrator_state": {"phase": "confirm_prone", "global_semantic_step": 509},
		}
		if label == "native_schema_refusal":
			bound["observation_v2"]["controller_ownership"]["owner"] = "invalid_stage_owner_♥"
		elif label == "malformed_reply":
			# Explicit transport stub; it is not counted as a compiled SDK call.
			counted.forced_reply = "{deliberately_malformed_transport_reply"
		elif label == "dispatch_refusal":
			context["recovery_controller_id"] = "wrong_controller"
		elif label == "missing_memory":
			arm.erase("recovery_memory")
		var before := arm.duplicate(true)
		var stage := Stage.advance_v1(counted, context, arm, bound, 509)
		var retained: Dictionary = stage["arm"]
		var packet: Dictionary = retained["last_recovery_collection_transport_retention"]
		controls[label + "_input_arm_unchanged"] = Owner.same_value_v1(arm, before)
		controls[label + "_same_nonphysics_sentinel"] = retained["model"] == sentinel
		controls[label + "_trace_and_global_step_preserved"] = (
			Owner.same_value_v1(retained["trace_rows"], before["trace_rows"])
			and retained["last_recovery_collection_transport_global_semantic_step"] == 509
		)
		var expected_calls := (
			1 if label in ["success", "native_schema_refusal", "malformed_reply"] else 0
		)
		controls[label + "_exact_genuine_call_counts"] = (
			(
				counted.genuine_compiled_call_count
				== (0 if label == "malformed_reply" else expected_calls)
			)
			and counted.step_requests.size() == (1 if label == "success" else 0)
			and counted.control_requests.size() == (1 if label == "success" else 0)
		)
		genuine_calls += counted.genuine_compiled_call_count
		step_calls += counted.step_requests.size()
		planning_calls += counted.control_requests.size()
		controls[label + "_stage_result_is_not_promoted"] = (
			stage["ok"] == (label == "success")
			and (stage["advance"].get("ok") == true) == (label == "success")
		)
		if expected_calls == 1:
			controls[label + "_exact_original_bytes"] = (
				packet["request"]["utf8_text"] == counted.requests[0]
				and packet["response"]["utf8_text"] == counted.responses[0]
			)
		else:
			controls[label + "_no_fabricated_call"] = (
				packet["stage"] == "precollection_refused"
				and packet["request"] == null
				and packet["response"] == null
				and packet["compiled_collection_call_count"] == 0
			)
		var partial := PhysicalWorker.partial_arm_failure_retention_projection_l15_v1(
			retained, PhysicalWorker.ARM_ORDER[1]
		)
		controls[label + "_abort_projection_keeps_complete_packet"] = Owner.same_value_v1(
			partial["last_recovery_collection_transport_retention"], packet
		)
		controls[label + "_failure_detail_retained"] = (
			partial["last_recovery_advance_failure"].is_empty()
			if label == "success"
			else Owner.same_value_v1(partial["last_recovery_advance_failure"], stage["advance"])
		)
		var legacy := PhysicalWorker.partial_arm_failure_retention_projection_v1(
			retained, PhysicalWorker.ARM_ORDER[1]
		)
		var stripped := partial.duplicate(true)
		for key in [
			"last_recovery_collection_transport_retention",
			"last_recovery_collection_transport_global_semantic_step",
			"last_recovery_advance_failure"
		]:
			stripped.erase(key)
		controls[label + "_all_legacy_projection_fields_unchanged"] = Owner.same_value_v1(
			legacy, stripped
		)
		cases[label] = {
			"advance": stage["advance"],
			"partial_arm": partial,
			"stage_ok": stage["ok"],
			"original_trace_rows": before["trace_rows"]
		}
		retained_arms[label] = retained
		if label == "success":
			success_arm = retained
		elif label == "native_schema_refusal":
			refused_arm = retained
	var missing := Stage.retain_v1(
		success_arm, {"ok": false, "failure_code": "synthetic_missing_current_capture"}, 510
	)
	controls["missing_current_capture_refuses"] = (
		missing["ok"] == false
		and missing["advance"]["failure_code"] == "QSDK_R10F_L15_ADVANCE_RETENTION_MISSING"
	)
	controls["previous_step_capture_not_reused"] = (
		missing["arm"]["last_recovery_collection_transport_retention"].is_empty()
		and missing["arm"]["last_recovery_collection_transport_global_semantic_step"] == 510
		and not success_arm["last_recovery_collection_transport_retention"].is_empty()
	)
	var absent := PhysicalWorker.partial_arm_failure_retention_projection_l15_v1(
		{}, "synthetic_active_arm"
	)
	controls["missing_projection_record_stays_null"] = (
		absent["last_recovery_collection_transport_retention"] == null
		and absent["last_recovery_collection_transport_global_semantic_step"] == null
		and absent["last_recovery_advance_failure"] == null
	)
	var abort := _exercise_actual_abort_v1(refused_arm, cases["native_schema_refusal"]["advance"])
	controls["actual_abort_body_executes_with_named_nonphysics_seams"] = abort.get("ok") == true
	controls["actual_abort_cleanup_precedes_exit_and_clears_host_arms"] = (
		(
			abort.get("seam_events")
			== [
				"quiesce",
				"cleanup",
				"exit:1:invalid_or_incomplete_process_isolated_child_development"
			]
		)
		and abort.get("remaining_arm_count") == 0
	)
	var additional_aborts := {}
	for label in [
		"malformed_reply", "dispatch_refusal", "missing_memory", "missing_current_capture"
	]:
		var branch_arm: Dictionary = (
			missing["arm"] if label == "missing_current_capture" else retained_arms[label]
		)
		var branch_advance: Dictionary = (
			missing["advance"] if label == "missing_current_capture" else cases[label]["advance"]
		)
		var marker := "QSDK_R10F_L15_SYNTHETIC_ABORT_%s_RAW " % label.to_upper()
		var branch_abort := _exercise_actual_abort_v1(
			branch_arm, branch_advance, marker, 510 if label == "missing_current_capture" else 509
		)
		additional_aborts[label] = branch_abort
		controls[label + "_complete_abort_cleans_and_publishes"] = (
			branch_abort.get("ok") == true
			and branch_abort.get("remaining_arm_count") == 0
			and branch_abort.get("seam_events") == abort.get("seam_events")
		)
	var failures := []
	for key in controls:
		if controls[key] != true:
			failures.append(key)
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_worker_retention_zero_world_v1",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_worker_advance_and_partial_abort_retention",
			"question_class": "development"
		},
		"ok": failures.is_empty(),
		"controls": controls,
		"control_count": controls.size(),
		"failed_controls": failures,
		"cases": cases,
		"expected_collection_identity_from_prepared_context": expected_identity,
		"abort_control_flow": abort,
		"additional_abort_control_flow": additional_aborts,
		"malformed_response_stub_call_count": 1,
		"genuine_compiled_collection_call_count": genuine_calls,
		"compiled_portable_step_call_count": step_calls,
		"compiled_control_planning_call_count": planning_calls,
		"additional_failure_reconstruction_call_count": 0,
		"complete_worker_abort_envelope_qualified": false,
		"physical_worker_instance_created": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_physics_read_count": 0,
		"solver_step_count": 0,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
		"release_authority": false
	}


static func _exercise_actual_abort_v1(
	arm: Dictionary,
	advance: Dictionary,
	raw_marker: String = ABORT_MARKER,
	completed_step: int = 509,
	context_comparison: Dictionary = {}
) -> Dictionary:
	var source := FileAccess.get_file_as_string(
		"res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
	)
	var body := _source_method_v1(source, "_abort_process_isolated_child_v1")
	var publisher := _source_method_v1(source, "_publish_process_isolated_child_abort_v1")
	if body.is_empty() or publisher.is_empty() or "PhysicsServer3D" in body:
		return {"ok": false, "failure_code": "ABORT_SOURCE_METHOD_EXTRACTION_REFUSED"}
	# Execute the complete current abort and publication methods in a detached
	# RefCounted host, not a SceneTree worker. Only native quiescence, cleanup
	# and process exit are replaced. Projection and JSON transport are actual.
	var script := GDScript.new()
	script.source_code = (
		"""extends RefCounted
const PhysicalWorker = preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd")
const JsonTransportScript = preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const GATE_ID = PhysicalWorker.GATE_ID
const REPAIR_ID = "QSDK-R10F-L15"
var _repair_id = REPAIR_ID
const ACTUATOR_MODE = PhysicalWorker.ACTUATOR_MODE
const RECOVERY_CONTROLLER_ID = PhysicalWorker.RECOVERY_CONTROLLER_ID
const ENERGY_ROUTE_ID = PhysicalWorker.ENERGY_ROUTE_ID
const MAXIMUM_CHILD_SOLVER_STEPS = PhysicalWorker.MAXIMUM_CHILD_SOLVER_STEPS
var _raw_schema = PhysicalWorker.RAW_SCHEMA
var _raw_marker = "QSDK_R10F_L15_SYNTHETIC_ABORT_RAW "
# Fixed source-only fixture IDs match the existing complete synthetic supervisor.
# They are never reserved, allocated or accepted as physical authority.
var _work_id = PhysicalWorker.L15_WORK_ID
var _source_commit = "0123456789abcdef0123456789abcdef01234567"
var _authorization_sha256 = "sha256:" + "9".repeat(64)
var _parent_attempt_id = "0123456789abcdef0123456789abcdef"
var _attempt_id = "2".repeat(32)
var _authorized_arm_id = PhysicalWorker.ARM_ORDER[1]
var _seed = PhysicalWorker.DEVELOPMENT_SEED
var _seed_label = PhysicalWorker.DEVELOPMENT_SEED_LABEL
var _seed_sha256 = PhysicalWorker.DEVELOPMENT_SEED_SHA256
var _process_isolated_precondition_terminal_receipt = {}
var _process_isolated_precondition_release_receipt = {}
var _process_isolated_interaction_source = {}
# These are deliberately synthetic report inputs, not observed physical counts.
var _total_solver_step_count = 507
var _total_world_attempt_count = 0
var _total_model_construction_attempt_count = 0
var _total_model_construction_count = 1
var _total_world_build_count = 1
var _observed_global_solver_frames = 509
var _external_kick_application_count = 0
var _total_native_readback_count = 17
var _arms = {}
var seam_events = []
func _quiesce_process_isolated_child_before_abort_v1():
	seam_events.append("quiesce")
func _cleanup_worlds_v1():
	seam_events.append("cleanup")
	_arms.clear()
func _schedule_exit_v1(code, reason):
	seam_events.append("exit:%d:%s" % [code, reason])
func _json_safe_v1(value):
	return PhysicalWorker._json_safe_v1(value)
func partial_arm_failure_retention_projection_l15_v1(arm, arm_id):
	return PhysicalWorker.partial_arm_failure_retention_projection_l15_v1(arm, arm_id)
func partial_arm_failure_retention_projection_v1(arm, arm_id):
	return PhysicalWorker.partial_arm_failure_retention_projection_v1(arm, arm_id)
"""
		+ body
		+ publisher
	)
	if script.reload() != OK:
		return {"ok": false, "failure_code": "ABORT_SOURCE_HOST_PARSE_FAILED"}
	var host: RefCounted = script.new()
	var supplied := arm.duplicate(false)
	supplied["model"] = {
		"solver_step_count": completed_step,
		"world_attempt_count": 1,
		"model_construction_attempt_count": 1
	}
	host.set("_observed_global_solver_frames", completed_step)
	host.set("_raw_marker", raw_marker)
	host.set("_arms", {PhysicalWorker.ARM_ORDER[1]: supplied})
	if not context_comparison.is_empty():
		# An explicit separately produced metadata input; the surrounding report
		# counters stay the fixture's synthetic post-collection values, not physics.
		host.set_meta("l15_prepared_context_comparison", context_comparison.duplicate(true))
	host.call(
		"_abort_process_isolated_child_v1",
		"QSDK_R10F_L9_CHILD_STEP_PROCESSING_INVALID",
		{
			"ok": false,
			"failure_code": "QSDK_R10F_RECOVERY_PRODUCTION_ADVANCE_INVALID",
			"advance": advance
		}
	)
	return {
		"ok": true,
		"worker_source_raw_sha256": "sha256:" + source.sha256_text(),
		"actual_abort_and_publication_methods_executed": true,
		"host_is_detached_refcounted_not_physical_worker": true,
		"native_quiescence_cleanup_and_exit_are_named_test_seams": true,
		"report_counters_are_synthetic_fixture_inputs": true,
		"raw_marker": raw_marker,
		"seam_events": host.get("seam_events"),
		"remaining_arm_count": host.get("_arms").size(),
		"physical_execution_authorized": false,
	}


static func _source_method_v1(source: String, method: String) -> String:
	var start := source.find("\nfunc " + method + "(")
	if start < 0:
		return ""
	start += 1
	var finish := source.length()
	for marker in ["\nfunc ", "\nstatic func "]:
		var found := source.find(marker, start + 1)
		if found >= 0:
			finish = mini(finish, found + 1)
	return source.substr(start, finish - start) + "\n"
