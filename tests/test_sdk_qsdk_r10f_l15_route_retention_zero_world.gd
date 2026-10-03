extends SceneTree
# gdlint: disable=max-line-length

## Actual dispatcher and route, actual compiled collection/step/control methods.
## Only the explicitly malformed reply case replaces one ABI return string.
const CaptureFixture := preload(
	"res://tests/test_sdk_qsdk_r10f_l15_collection_transport_zero_world.gd"
)
const WorkerFixture := preload("res://tests/test_sdk_qsdk_r10f_l15_worker_ownership_zero_world.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Behavior := preload("res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd")
const Owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MARKER := "QSDK_R10F_L15_ROUTE_RETENTION_ZERO_WORLD "


class CountedRoute:
	extends CaptureFixture.CountedCollection
	var step_requests: Array = []
	var control_requests: Array = []

	func canonicalize_json(request: String) -> String:
		return sdk.canonicalize_json(request)

	func recovery_step_v5_json(request: String) -> String:
		step_requests.append(request)
		return sdk.recovery_step_v5_json(request)

	func recovery_plan_control_v3_json(request: String) -> String:
		control_requests.append(request)
		return sdk.recovery_plan_control_v3_json(request)


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
	var compiled_calls := 0
	var step_calls := 0
	var control_calls := 0
	for label in [
		"legacy_success",
		"success",
		"native_schema_refusal",
		"native_observation_refusal",
		"native_portable_step_refusal",
		"malformed_reply",
		"precollection_missing_application",
		"precollection_crossed_memory",
		"precollection_bad_phase",
		"precollection_missing_bound",
		"precollection_bad_profile"
	]:
		var counted := CountedRoute.new()
		counted.sdk = fixture["sdk"]
		var bound: Dictionary = fixture["bound"].duplicate(true)
		var application: Dictionary = fixture["application"].duplicate(true)
		var memory: Dictionary = fixture["memory"].duplicate(true)
		var context: Dictionary = fixture["context"].duplicate(true)
		var phase: String = memory["phase"]
		match label:
			"native_schema_refusal":
				bound["observation_v2"]["controller_ownership"]["owner"] = "invalid_owner_→_♥"
			"native_observation_refusal":
				bound["source_binding"]["portable_observation_sha256"] = "sha256:" + "a".repeat(64)
			"native_portable_step_refusal":
				var projected := WorkerFixture._advance_epoch_fixture_v1(
					fixture["sdk"],
					context,
					fixture["epoch"],
					application,
					WorkerFixture.E + 1,
					application["canonical_ownership_mapping"]["source_application"]["command_id"]
				)
				if projected.get("ok") != true:
					return {"ok": false, "colon_projection": projected}
				bound = projected["epoch"]["bound_epoch_observations"]
			"malformed_reply":
				counted.forced_reply = '{"ok":'
			"precollection_missing_application":
				application = {}
			"precollection_crossed_memory":
				memory["phase_steps_observed"] = int(memory["phase_steps_observed"]) + 1
			"precollection_bad_phase":
				phase = "wrong_phase"
			"precollection_missing_bound":
				bound.erase("observation_v3")
			"precollection_bad_profile":
				context["solver_coupled_complete_energy_profile_selected"] = false
		var before := {
			"application": application.duplicate(true),
			"memory": memory.duplicate(true),
			"bound": bound.duplicate(true),
			"context": context.duplicate(true)
		}
		var result: Dictionary
		if label == "precollection_bad_profile":
			# Direct route entry tests its own profile refusal before collection;
			# the production dispatcher already refuses this incompatible context.
			result = Route.advance_behavior_solver_coupled_complete_energy_l15_v1(
				counted, context, bound, memory, "candidate_command", phase, application
			)
		else:
			result = Behavior.production_advance_dispatch_v1(
				counted,
				context,
				bound,
				memory,
				"candidate_command",
				phase,
				Owner.RECOVERY_CONTROLLER_ID,
				Route.R148_COMPLETE_ENERGY_ROUTE_ID,
				null if label == "legacy_success" else application
			)
		controls[label + "_inputs_unchanged"] = Owner.same_value_v1(
			before,
			{"application": application, "memory": memory, "bound": bound, "context": context}
		)
		var expected_calls := 0 if label.begins_with("precollection_") else 1
		var expected_steps := (
			1 if label in ["legacy_success", "success", "native_portable_step_refusal"] else 0
		)
		var expected_controls := 1 if label in ["legacy_success", "success"] else 0
		controls[label + "_exact_call_counts"] = (
			counted.requests.size() == expected_calls
			and counted.step_requests.size() == expected_steps
			and counted.control_requests.size() == expected_controls
		)
		compiled_calls += counted.genuine_compiled_call_count
		step_calls += counted.step_requests.size()
		control_calls += counted.control_requests.size()
		if label == "legacy_success":
			controls["legacy_has_no_new_retention_field"] = not result.has(
				"collection_transport_retention"
			)
		else:
			var packet: Dictionary = result.get("collection_transport_retention", {})
			if packet.is_empty():
				return {"ok": false, "missing_packet_case": label, "result": result}
			controls[label + "_exact_source_links"] = (
				(
					packet["source_links"]["source_application"]["utf8_text"]
					== Transport.stringify(application)
				)
				and (
					packet["source_links"]["source_memory"]["utf8_text"]
					== Transport.stringify(memory)
				)
				and (
					packet["source_links"]["bound_observation"]["utf8_text"]
					== Transport.stringify(bound)
				)
			)
			if expected_calls == 0:
				controls[label + "_no_invented_request_or_response"] = (
					packet["stage"] == "precollection_refused"
					and packet["request"] == null
					and packet["response"] == null
					and packet["request_serialization_call_count"] == 0
					and packet["compiled_collection_call_count"] == 0
				)
			else:
				controls[label + "_exact_call_bytes"] = (
					packet["request"]["utf8_text"] == counted.requests[0]
					and packet["response"]["utf8_text"] == counted.responses[0]
					and packet["compiled_collection_call_count"] == 1
				)
		cases[label] = result
	var stripped: Dictionary = cases["success"].duplicate(true)
	stripped.erase("collection_transport_retention")
	controls["whole_legacy_success_result_unchanged"] = Owner.same_value_v1(
		stripped, cases["legacy_success"]
	)
	controls["success_is_actual_advance"] = cases["success"].get("ok") == true
	controls["success_passes_actual_worker_receipt_reader"] = (
		Behavior
		. production_advance_receipt_valid_v1(
			cases["success"],
			Owner.RECOVERY_CONTROLLER_ID,
			fixture["sdk"],
			Route.R148_COMPLETE_ENERGY_ROUTE_ID
		)
	)
	controls["schema_refusal_is_native"] = (
		cases["native_schema_refusal"].get("detail", {}).get("failure_code") == "SCHEMA_INVALID"
	)
	controls["observation_refusal_is_native"] = (
		cases["native_observation_refusal"].get("detail", {}).get("refusal_reason")
		== "observation_v2_source_binding_mismatch"
	)
	controls["later_step_refusal_keeps_accepted_collection"] = (
		(
			cases["native_portable_step_refusal"].get("failure_code")
			== "QSDK_R24D65_BEHAVIOR_PORTABLE_STEP_REFUSED"
		)
		and (
			(
				cases["native_portable_step_refusal"]["collection_transport_retention"]["decoded_collection"]
				. get("support_status")
			)
			== "supported_exact"
		)
	)
	var failures := []
	for key in controls:
		if controls[key] != true:
			failures.append(key)
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_route_retention_zero_world_v1",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_route_collection_retention_component",
			"question_class": "development"
		},
		"ok": failures.is_empty(),
		"controls": controls,
		"control_count": controls.size(),
		"failed_controls": failures,
		"cases": cases,
		"genuine_compiled_collection_call_count": compiled_calls,
		"compiled_portable_step_call_count": step_calls,
		"compiled_control_planning_call_count": control_calls,
		"malformed_reply_stub_call_count": 1,
		"additional_failure_reconstruction_call_count": 0,
		"worker_abort_envelope_retention_qualified": false,
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
