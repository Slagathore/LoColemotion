extends SceneTree
# gdlint: disable=max-line-length

## The three genuine collection cases forward once to the pinned compiled SDK.
## Malformed replies use a separately labeled transport-only fixture because
## a correct native SDK should not emit malformed JSON. No physics is executed.
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")
const Stage := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_no_actuation_worker_stage_v1.gd"
)
const WorkerFixture := preload("res://tests/test_sdk_qsdk_r10f_l15_worker_ownership_zero_world.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MARKER := "QSDK_R10F_L15_COLLECTION_TRANSPORT_ZERO_WORLD "


class CountedCollection:
	extends RefCounted
	var sdk: Object
	var forced_reply: Variant = null
	var requests: Array = []
	var responses: Array = []
	var genuine_compiled_call_count := 0

	func recovery_collect_native_v3_json(request_text: String) -> String:
		requests.append(request_text)
		var response: String
		if forced_reply != null:
			response = forced_reply
		else:
			genuine_compiled_call_count += 1
			response = sdk.recovery_collect_native_v3_json(request_text)
		responses.append(response)
		return response


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := evaluate_v1()
	print(MARKER, Transport.stringify(result))
	quit(0 if result.get("ok") == true else 1)


static func evaluate_v1() -> Dictionary:
	var fixture := source_fixture_v1()
	if fixture.get("ok") != true:
		return fixture
	var sdk: Object = fixture["sdk"]
	var application: Dictionary = fixture["application"]
	var memory: Dictionary = fixture["memory"]
	var bound: Dictionary = fixture["bound"]
	var request: Dictionary = fixture["request"]
	return _evaluate_cases_v1(sdk, application, memory, bound, request)


## Shared actual source construction; no collection call is made here.
static func source_fixture_v1() -> Dictionary:
	if (
		load("res://sdk/adapters/godot/sporespore_locomotion.gdextension") == null
		or not ClassDB.class_exists("SporeLocomotionSdk")
	):
		return {"ok": false, "failure_code": "L15_RETENTION_EXTENSION_MISSING"}
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var context := Route.prepare_complete_energy_context_v18(sdk, Owner.RECOVERY_CONTROLLER_ID)
	var epoch := WorkerFixture._initialize_epoch_fixture_v1(sdk, context)
	var initialized := Stage.initialize_v1(
		sdk, context, {"facade": WorkerFixture.SyntheticMotorReadback.new()}, WorkerFixture.E
	)
	if epoch.get("ok") != true or initialized.get("ok") != true:
		return {"ok": false, "epoch": epoch, "initialized": initialized}
	var arm: Dictionary = initialized["arm"]
	var application: Dictionary = arm["pending_application"]
	var memory: Dictionary = arm["recovery_memory"]
	var projected := WorkerFixture._advance_epoch_fixture_v1(
		sdk, context, epoch, application, WorkerFixture.E + 1
	)
	if projected.get("ok") != true:
		return {"ok": false, "projected": projected}
	var bound: Dictionary = projected["epoch"]["bound_epoch_observations"]
	var request := Route.collection_request_v1(context, bound, "candidate_command", memory["phase"])
	return {
		"ok": true,
		"sdk": sdk,
		"context": context,
		"epoch": epoch,
		"application": application,
		"memory": memory,
		"bound": bound,
		"request": request
	}


static func _evaluate_cases_v1(
	sdk: Object, application: Dictionary, memory: Dictionary, bound: Dictionary, request: Dictionary
) -> Dictionary:
	var controls := {}
	var cases := {}
	for label in ["genuine_success", "genuine_schema_refusal", "genuine_observation_refusal"]:
		var supplied := request.duplicate(true)
		if label == "genuine_schema_refusal":
			# A deliberate complete ABI schema refusal; the non-ASCII value also
			# checks byte length rather than character count. No second call is
			# made to reconstruct the rejected text or inspect its missing value.
			supplied["observation"]["controller_ownership"]["owner"] = "invalid_owner_→_♥"
		elif label == "genuine_observation_refusal":
			# Valid JSON and ABI schema, but a deliberately stale observation
			# binding. The native envelope succeeds while its value refuses.
			supplied["observation_source_binding"]["portable_observation_sha256"] = (
				"sha256:" + "a".repeat(64)
			)
		var counted := CountedCollection.new()
		counted.sdk = sdk
		var result := Runtime.collect_native_v3_l15_v1(
			counted, supplied, application, memory, bound
		)
		controls[label + "_one_genuine_compiled_call"] = (
			counted.genuine_compiled_call_count == 1
			and counted.requests.size() == 1
			and counted.responses.size() == 1
		)
		var packet: Dictionary = result["collection_transport_retention"]
		controls[label + "_exact_request_and_response"] = (
			packet["request"]["utf8_text"] == counted.requests[0]
			and packet["response"]["utf8_text"] == counted.responses[0]
		)
		controls[label + "_same_authoritative_request_serializer"] = (
			counted.requests[0] == Transport.stringify(supplied)
		)
		controls[label + "_same_legacy_envelope_decoder"] = Owner.same_value_v1(
			result["collection"], Runtime._decode_envelope(counted.responses[0])
		)
		controls[label + "_same_source_link_serializer"] = (
			(
				packet["source_links"]["source_application"]["utf8_text"]
				== Transport.stringify(application)
			)
			and packet["source_links"]["source_memory"]["utf8_text"] == Transport.stringify(memory)
			and (
				packet["source_links"]["bound_observation"]["utf8_text"]
				== Transport.stringify(bound)
			)
		)
		cases[label] = result
	controls["genuine_success_is_supported"] = (
		cases["genuine_success"]["collection"].get("support_status") == "supported_exact"
		and cases["genuine_success"]["collection"].get("refusal_reason") == null
	)
	controls["genuine_refusal_is_native_schema_invalid"] = (
		cases["genuine_schema_refusal"]["collection"].get("failure_code") == "SCHEMA_INVALID"
		and "invalid_owner_→_♥" in cases["genuine_schema_refusal"]["collection"].get("detail", "")
	)
	controls["genuine_observation_refusal_is_native_value_refusal"] = (
		(
			cases["genuine_observation_refusal"]["collection"].get("support_status")
			== "invalid_observation"
		)
		and (
			cases["genuine_observation_refusal"]["collection"].get("refusal_reason")
			== "observation_v2_source_binding_mismatch"
		)
	)
	var replies := {
		"malformed_json": '{"ok":',
		"nonobject_reply": "[1,2]",
		"integer_ok_flag": '{"ok":1,"value":{}}',
		"nonobject_value": '{"ok":true,"value":[]}',
		"bad_refusal_shape": '{"ok":false,"failure_code":17}',
	}
	for label in replies:
		var counted := CountedCollection.new()
		counted.forced_reply = replies[label]
		var result := Runtime.collect_native_v3_l15_v1(counted, request, application, memory, bound)
		controls[label + "_single_labeled_stub_call"] = (
			counted.requests.size() == 1 and counted.genuine_compiled_call_count == 0
		)
		controls[label + "_raw_reply_preserved"] = (
			result["collection_transport_retention"]["stage"] == "compiled_response_malformed"
			and result["collection_transport_retention"]["response"]["utf8_text"] == replies[label]
		)
		cases[label] = result
	for label in [
		"precollection_wrong_schema", "precollection_nonfinite", "precollection_missing_sdk"
	]:
		var supplied := request.duplicate(true)
		if label == "precollection_wrong_schema":
			supplied["schema_version"] = "wrong_schema"
		elif label == "precollection_nonfinite":
			supplied["observation"]["outer_step_duration_s"] = NAN
		var counted := CountedCollection.new()
		counted.sdk = sdk
		var target: Object = null if label == "precollection_missing_sdk" else counted
		var result := Runtime.collect_native_v3_l15_v1(target, supplied, application, memory, bound)
		controls[label + "_no_call_no_fabricated_response"] = (
			counted.requests.is_empty()
			and result["collection_transport_retention"]["stage"] == "precollection_refused"
			and result["collection_transport_retention"]["response"] == null
		)
		cases[label] = result
	var failures := []
	for key in controls:
		if controls[key] != true:
			failures.append(key)
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_collection_transport_zero_world_v1",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_exact_collection_transport_component",
			"question_class": "development"
		},
		"ok": failures.is_empty(),
		"controls": controls,
		"control_count": controls.size(),
		"failed_controls": failures,
		"cases": cases,
		"genuine_compiled_collection_call_count": 3,
		"malformed_reply_stub_call_count": 5,
		"additional_failure_reconstruction_call_count": 0,
		"route_abort_envelope_retention_qualified": false,
		"physical_execution_authorized": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_physics_read_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false
	}
