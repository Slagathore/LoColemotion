extends SceneTree
# gdlint: disable=max-line-length

## R171 validates only the retention seam exposed by R170. Every value here is
## synthetic. No Node, RID, model, world, native property read, native write,
## behavior evaluator invocation, or solver step is created.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const NativeWorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const TransportScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const PHYSICAL_WORKER_PATH := (
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const MARKER := "QSDK_R24D171_GODOT_INITIALIZER_RECEIPT_RETENTION_ZERO_WORLD "
const GATE_ID := "QSDK-R24D171"
const ATTEMPT_ID := "r24d171-zero-world-attempt"
const ARM_ID := "candidate_command"
const MODEL_INSTANCE_ID := "r24d171-synthetic-model"
const RECEIPT_SCHEMA := (
	"sporespore_qsdk_r24d168_native_initializer_boundary_transport_v1"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate_v1()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D171_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D171_SDK_INSTANTIATION_FAILED")

	var boundary_receipt := (
		TransportScript
		. build_initializer_boundary_v1(
			sdk,
			ATTEMPT_ID,
			ARM_ID,
			MODEL_INSTANCE_ID,
			"initializer:%s:%s:%s:0" % [ATTEMPT_ID, ARM_ID, MODEL_INSTANCE_ID],
			_fixture_samples_v1(),
		)
	)
	if not bool(boundary_receipt.get("ok", false)):
		return _failure("QSDK_R24D171_BOUNDARY_FIXTURE_INVALID", boundary_receipt)
	var initialization := TransportScript.initialize_boundary_transport_state_v1(
		sdk, boundary_receipt["boundary"]
	)
	if not bool(initialization.get("ok", false)):
		return _failure("QSDK_R24D171_STATE_FIXTURE_INVALID", initialization)

	var receipt := _initializer_receipt_v1()
	var model := {
		"physics_server_active": false,
		"contiguous_boundary_transport_initialized": true,
		"contiguous_boundary_transport_state": (
			(initialization["state"] as Dictionary).duplicate(true)
		),
		"boundary_transport_initializer_receipt": receipt.duplicate(true),
	}
	var model_digest_before := _sha256(sdk, model)
	var receipt_digest_before := _sha256(sdk, receipt)
	var positive_checks := {
		"native_world_retention_validator_accepts_exact_fixture": (
			NativeWorldScript.contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
				sdk, model, receipt, ATTEMPT_ID, ARM_ID, MODEL_INSTANCE_ID
			)
		),
		"production_route_exposes_same_retention_validator": (
			RouteScript.contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
				sdk, model, receipt, ATTEMPT_ID, ARM_ID, MODEL_INSTANCE_ID
			)
		),
		"retention_validation_is_input_immutable": (
			_sha256(sdk, model) == model_digest_before
			and _sha256(sdk, receipt) == receipt_digest_before
		),
		"retained_sequence_zero_identity_and_pre_activation_order_bound": (
			String(receipt.get("schema_version", "")) == RECEIPT_SCHEMA
			and int(receipt.get("native_readback_count", -1)) == 9
			and int(
				(model["contiguous_boundary_transport_state"] as Dictionary).get(
					"cached_boundary_sequence", -1
				)
			)
			== 0
			and String(
				(model["contiguous_boundary_transport_state"] as Dictionary).get(
					"attempt_id", ""
				)
			)
			== ATTEMPT_ID
			and _production_worker_validates_before_activation_v1()
		),
	}

	var forced_failure_checks := {
		"missing_retained_receipt_refused": _model_mutation_refused_v1(
			sdk, model, receipt, "boundary_transport_initializer_receipt", null, true
		),
		"receipt_schema_crossed_refused": _receipt_mutation_refused_v1(
			sdk, model, receipt, "schema_version", "crossed_schema"
		),
		"receipt_gate_crossed_refused": _receipt_mutation_refused_v1(
			sdk, model, receipt, "gate_id", "QSDK-R24D171"
		),
		"receipt_readback_count_crossed_refused": _receipt_mutation_refused_v1(
			sdk, model, receipt, "native_readback_count", 8
		),
		"receipt_active_readback_refused": _receipt_mutation_refused_v1(
			sdk, model, receipt, "physics_active_during_readback", true
		),
		"receipt_non_measurement_refused": _receipt_mutation_refused_v1(
			sdk, model, receipt, "source_measurement", false
		),
		"receipt_extra_key_refused": _receipt_mutation_refused_v1(
			sdk, model, receipt, "outcome_derived_value", true
		),
		"physics_already_active_refused": _model_mutation_refused_v1(
			sdk, model, receipt, "physics_server_active", true
		),
		"initializer_state_flag_missing_refused": _model_mutation_refused_v1(
			sdk, model, receipt, "contiguous_boundary_transport_initialized", false
		),
		"crossed_attempt_identity_refused": _state_mutation_refused_v1(
			sdk, model, receipt, "attempt_id", "crossed-attempt"
		),
		"crossed_arm_identity_refused": _state_mutation_refused_v1(
			sdk, model, receipt, "arm_id", "crossed-arm"
		),
		"nonzero_initializer_revision_refused": _state_mutation_refused_v1(
			sdk, model, receipt, "state_revision", 1
		),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
		and _sha256(sdk, model) == model_digest_before
		and _sha256(sdk, receipt) == receipt_digest_before
	)
	return {
		"schema_version": (
			"sporespore_qsdk_r24d171_godot_initializer_receipt_retention_zero_world_v1"
		),
		"gate_id": GATE_ID,
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D171_ZERO_WORLD_CONJUNCTION_INVALID",
		"status": "passed_zero_world_initializer_receipt_retention_repair",
		"question_class": "development",
		"receipt_schema_version": RECEIPT_SCHEMA,
		"receipt_origin_gate_id": "QSDK-R24D168",
		"receipt_retention_key": "boundary_transport_initializer_receipt",
		"initializer_native_readback_count": 9,
		"initializer_boundary_sequence": 0,
		"initializer_state_revision": 0,
		"validation_occurs_before_physics_activation": true,
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"behavior_evaluator_invocation_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _initializer_receipt_v1() -> Dictionary:
	return {
		"schema_version": RECEIPT_SCHEMA,
		"gate_id": "QSDK-R24D168",
		"ok": true,
		"transport_design_id": TransportScript.TRANSPORT_DESIGN_ID,
		"transport_profile_id": TransportScript.TRANSPORT_PROFILE_ID,
		"initializer_boundary_sequence": 0,
		"state_revision": 0,
		"native_readback_count": TransportScript.ORDERED_BODY_IDS.size(),
		"physics_active_during_readback": false,
		"source_measurement": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _production_worker_validates_before_activation_v1() -> bool:
	var source := FileAccess.get_file_as_string(PHYSICAL_WORKER_PATH)
	var retention_call := source.find(
		"RouteScript.contiguous_boundary_transport_initializer_receipt_retained_exact_v1("
	)
	var activation_token := "PhysicsServer3D." + "set_active(true)"
	var physics_activation := source.find(activation_token)
	return (
		retention_call >= 0
		and physics_activation >= 0
		and retention_call < physics_activation
		and source.count(activation_token) == 1
	)


static func _fixture_samples_v1() -> Array:
	var samples: Array = []
	for index in range(TransportScript.ORDERED_BODY_IDS.size()):
		var body_id := String(TransportScript.ORDERED_BODY_IDS[index])
		samples.append(
			{
				"body_id": body_id,
				"body_index": index,
				"boundary_sequence": 0,
				"position_world_m": Vector3(index * 0.1, 0.4 + index * 0.01, -index * 0.05),
				"linear_velocity_world_m_s": Vector3.ZERO,
				"mass_kg": 1.2 if body_id == "torso" else 0.44,
			}
		)
	return samples


static func _receipt_mutation_refused_v1(
	sdk: Object,
	model: Dictionary,
	receipt: Dictionary,
	key: String,
	value: Variant,
) -> bool:
	var mutated_receipt := receipt.duplicate(true)
	mutated_receipt[key] = value
	var mutated_model := model.duplicate(true)
	mutated_model["boundary_transport_initializer_receipt"] = mutated_receipt.duplicate(true)
	return not RouteScript.contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
		sdk, mutated_model, mutated_receipt, ATTEMPT_ID, ARM_ID, MODEL_INSTANCE_ID
	)


static func _model_mutation_refused_v1(
	sdk: Object,
	model: Dictionary,
	receipt: Dictionary,
	key: String,
	value: Variant,
	erase_key: bool = false,
) -> bool:
	var mutated := model.duplicate(true)
	if erase_key:
		mutated.erase(key)
	else:
		mutated[key] = value
	return not RouteScript.contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
		sdk, mutated, receipt, ATTEMPT_ID, ARM_ID, MODEL_INSTANCE_ID
	)


static func _state_mutation_refused_v1(
	sdk: Object,
	model: Dictionary,
	receipt: Dictionary,
	key: String,
	value: Variant,
) -> bool:
	var mutated := model.duplicate(true)
	var state: Dictionary = mutated["contiguous_boundary_transport_state"]
	state[key] = value
	return not RouteScript.contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
		sdk, mutated, receipt, ATTEMPT_ID, ARM_ID, MODEL_INSTANCE_ID
	)


static func _sha256(sdk: Object, value: Variant) -> String:
	return String(RecoveryRuntimeScript.canonicalize(sdk, value).get("sha256", ""))


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": (
			"sporespore_qsdk_r24d171_godot_initializer_receipt_retention_zero_world_v1"
		),
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"positive_case_count": 4,
		"forced_failure_case_count": 12,
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
