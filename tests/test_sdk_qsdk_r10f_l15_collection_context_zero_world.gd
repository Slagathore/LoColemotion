extends SceneTree
# gdlint: disable=max-line-length

const Context := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Worker := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MARKER := "QSDK_R10F_L15_COLLECTION_CONTEXT_ZERO_WORLD "
const CAPTURE_MARKER := "QSDK_R10F_L15_PREPARED_COLLECTION_CONTEXT "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var receipt := evaluate_v1()
	if receipt.get("capture") is Dictionary:
		print(CAPTURE_MARKER, Transport.stringify(receipt["capture"]))
	print(MARKER, Transport.stringify(receipt))
	quit(0 if receipt.get("ok") == true else 1)


static func evaluate_v1() -> Dictionary:
	if (
		load("res://sdk/adapters/godot/sporespore_locomotion.gdextension") == null
		or not ClassDB.class_exists("SporeLocomotionSdk")
	):
		return {"ok": false, "failure_code": "L15_CONTEXT_EXTENSION_MISSING"}
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var context := Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	var capture := Context.capture_prepared_v1(sdk, context)
	var controls := {
		"prepared_context_capture_valid": capture.get("ok") == true,
		"worker_arm_kind_exact": Context.INTERNAL_ARM_KIND == Worker.INTERNAL_RECOVERY_ARM_KIND,
		"production_constructor_projection_checked":
		capture.get("production_request_identity_projection_checked") == true,
		"collection_never_called": capture.get("compiled_collection_call_count") == 0,
		"missing_sdk_refused": Context.capture_prepared_v1(null, context).get("ok") == false,
	}
	for key in [
		"model_construction_count", "world_attempt_count", "world_build_count", "solver_step_count"
	]:
		for label in ["bool", "float", "string", "nonzero"]:
			var changed := context.duplicate(true)
			changed[key] = {"bool": false, "float": 0.0, "string": "0", "nonzero": 1}[label]
			controls[key + "_" + label] = (
				Context.capture_prepared_v1(sdk, changed).get("ok") == false
			)
	for key in [
		"schema_version",
		"recovery_controller_id",
		"capability_sha256",
		"morphology_context",
		"runtime_binding"
	]:
		var changed := context.duplicate(true)
		if key == "morphology_context":
			changed[key]["recovery_morphology_id"] = "wrong_morphology"
		elif key == "runtime_binding":
			changed[key]["capability_sha256"] = "sha256:" + "0".repeat(64)
		else:
			changed[key] = "wrong_identity"
		controls["changed_" + key] = Context.capture_prepared_v1(sdk, changed).get("ok") == false
	var original_capture_text := Transport.stringify(capture)
	context["morphology_context"]["recovery_morphology_id"] = "changed_after_capture"
	controls["snapshot_not_aliased_to_later_context"] = (
		Transport.stringify(capture) == original_capture_text
	)
	var failed := []
	for key in controls:
		if controls[key] != true:
			failed.append(key)
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_collection_context_zero_world_v1",
		"ok": failed.is_empty(),
		"controls": controls,
		"control_count": controls.size(),
		"failed_controls": failed,
		"capture": capture,
		"production_v18_context_preparation_call_count": 1,
		"compiled_collection_call_count": 0,
		"portable_recovery_advance_call_count": 0,
		"physical_worker_instance_created": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_physics_read_count": 0,
		"solver_step_count": 0,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
