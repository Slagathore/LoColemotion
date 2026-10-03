extends SceneTree
# gdlint: disable=max-line-length

const Context := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd")
const Guard := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_pre_world_context_v1.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const RetentionFixture := preload(
	"res://tests/test_sdk_qsdk_r10f_l15_worker_retention_zero_world.gd"
)
const MARKER := "QSDK_R10F_L15_PRE_WORLD_CONTEXT_ZERO_WORLD "
const ABORT_MARKER := "QSDK_R10F_L15_CONTEXT_METADATA_ABORT_RAW "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := evaluate_v1()
	print(MARKER, Transport.stringify(result))
	quit(0 if result.get("ok") == true else 1)


static func evaluate_v1() -> Dictionary:
	if (
		load("res://sdk/adapters/godot/sporespore_locomotion.gdextension") == null
		or not ClassDB.class_exists("SporeLocomotionSdk")
	):
		return {"ok": false, "failure_code": "PRE_WORLD_SDK_MISSING"}
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var expected_context := Route.prepare_complete_energy_context_v18(
		sdk, Route.RECOVERY_CONTROLLER_V6_ID
	)
	var capture := Context.snapshot_v1(Context.capture_prepared_v1(sdk, expected_context))
	var expected := {
		"utf8_byte_length": capture["utf8_byte_length"], "raw_sha256": capture["raw_sha256"]
	}
	# A second actual preparation represents the future worker's independent source.
	var worker_context := Route.prepare_complete_energy_context_v18(
		sdk, Route.RECOVERY_CONTROLLER_V6_ID
	)
	var source := FileAccess.get_file_as_string(
		"res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
	)
	var method := RetentionFixture._source_method_v1(
		source, "_verify_l15_prepared_context_before_world_v1"
	)
	if method.is_empty() or "PhysicsServer3D" in method:
		return {"ok": false, "failure_code": "PRE_WORLD_ACTUAL_METHOD_MISSING"}
	var prefix := """extends RefCounted
const PreWorldContextL15 = preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_pre_world_context_v1.gd")
const REPAIR_ID = "QSDK-R10F-L15"
var _repair_id = REPAIR_ID
var _sdk: Object
var _context: Dictionary = {}
"""
	var script := GDScript.new()
	script.source_code = prefix + method
	if script.reload() != OK:
		return {"ok": false, "failure_code": "PRE_WORLD_ACTUAL_HOST_PARSE"}
	var host: RefCounted = script.new()
	host.set("_sdk", sdk)
	host.set("_context", worker_context)
	var original_environment := {}
	for name in [Guard.LENGTH_ENV, Guard.SHA_ENV]:
		original_environment[name] = {
			"present": OS.has_environment(name), "value": OS.get_environment(name)
		}
	OS.set_environment(Guard.LENGTH_ENV, str(expected["utf8_byte_length"]))
	OS.set_environment(Guard.SHA_ENV, expected["raw_sha256"])
	var accepted: bool = host.call("_verify_l15_prepared_context_before_world_v1")
	var positive: Dictionary = host.get_meta("l15_prepared_context_comparison", {})
	var controls := {
		"actual_worker_method_accepts_independent_preparation": accepted,
		"exact_capture_matches_separate_expected_source":
		Transport.stringify(positive.get("observed_capture")) == Transport.stringify(capture),
		"no_expected_origin_promotion":
		positive.get("expected_binding_origin_authenticated_here") == false,
	}
	var refusals := {}
	for item in [
		["missing_length", Guard.LENGTH_ENV, ""],
		["float_length", Guard.LENGTH_ENV, str(expected["utf8_byte_length"]) + ".0"],
		["leading_zero", Guard.LENGTH_ENV, "0" + str(expected["utf8_byte_length"])],
		["plus_length", Guard.LENGTH_ENV, "+" + str(expected["utf8_byte_length"])],
		["crossed_length", Guard.LENGTH_ENV, str(expected["utf8_byte_length"] + 1)],
		["missing_digest", Guard.SHA_ENV, ""],
		["crossed_digest", Guard.SHA_ENV, "sha256:" + "0".repeat(64)],
		["uppercase_digest", Guard.SHA_ENV, "sha256:" + "A".repeat(64)],
	]:
		OS.set_environment(Guard.LENGTH_ENV, str(expected["utf8_byte_length"]))
		OS.set_environment(Guard.SHA_ENV, expected["raw_sha256"])
		OS.set_environment(item[1], item[2])
		controls[item[0]] = host.call("_verify_l15_prepared_context_before_world_v1") == false
		refusals[item[0]] = host.get_meta("l15_prepared_context_comparison", {}).duplicate(true)
	for name in original_environment:
		if original_environment[name]["present"]:
			OS.set_environment(name, original_environment[name]["value"])
		else:
			OS.unset_environment(name)
	for label in ["bool", "float", "string", "negative", "extra"]:
		var changed := expected.duplicate(true)
		if label == "extra":
			changed["extra"] = true
		else:
			changed["utf8_byte_length"] = {
				"bool": true,
				"float": float(expected["utf8_byte_length"]),
				"string": str(expected["utf8_byte_length"]),
				"negative": -1
			}[label]
		controls["binding_" + label] = (
			Guard.compare_prepared_v1(sdk, worker_context, changed).get("ok") == false
		)
	var changed_context := worker_context.duplicate(true)
	changed_context["recovery_controller_id"] = "wrong_controller"
	controls["changed_context_refused"] = (
		Guard.compare_prepared_v1(sdk, changed_context, expected).get("ok") == false
	)
	controls["missing_sdk_refused"] = (
		Guard.compare_prepared_v1(null, worker_context, expected).get("ok") == false
	)
	# The exact same production method preserves the legacy no-comparison path.
	var legacy := GDScript.new()
	legacy.source_code = prefix.replace("QSDK-R10F-L15", "QSDK-R10F-L14") + method
	if legacy.reload() != OK:
		return {"ok": false, "failure_code": "PRE_WORLD_LEGACY_HOST_PARSE"}
	var legacy_host: RefCounted = legacy.new()
	controls["legacy_without_sdk_or_binding_unchanged"] = (
		legacy_host.call("_verify_l15_prepared_context_before_world_v1") == true
	)
	controls["legacy_has_no_comparison_metadata"] = not legacy_host.has_meta(
		"l15_prepared_context_comparison"
	)
	# Metadata-retention-only use of the real abort method. Its existing model/
	# step counter inputs are synthetic and are not a new physical observation.
	var abort_retention := RetentionFixture._exercise_actual_abort_v1(
		{},
		{"ok": false, "failure_code": "EXPLICIT_METADATA_RETENTION_FIXTURE"},
		ABORT_MARKER,
		509,
		positive
	)
	controls["actual_abort_retains_comparison_metadata"] = abort_retention.get("ok") == true
	var failed := []
	for name in controls:
		if controls[name] != true:
			failed.append(name)
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_pre_world_context_zero_world_v1",
		"ok": failed.is_empty(),
		"controls": controls,
		"control_count": controls.size(),
		"failed_controls": failed,
		"positive_comparison": positive,
		"refusals": refusals,
		"expected_capture": capture,
		"abort_metadata_retention": abort_retention,
		"abort_report_counters_are_synthetic_inputs": true,
		"expected_binding_has_test_authority_only": true,
		"actual_worker_method_executed_in_detached_refcounted_host": true,
		"complete_physical_worker_run_executed": false,
		"official_supervisor_qualification_origin_used_in_fixture": false,
		"production_v18_context_preparation_call_count": 2,
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
