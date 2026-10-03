class_name SporeQsdkR10fProcessIsolatedChildContractV1
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-file-lines

## Pure QSDK-R10F-L9 receipt contract for one arm in one fresh Godot process,
## with the QSDK-R10F-L10 nullable terminal-failure consumer and the
## QSDK-R10F-L11 precondition-release owner-source projection layered on top.
##
## The physical worker supplies already-observed controller, motor, and torso
## values. This component performs no world construction, native read, solver
## step, or body write. It makes the process-isolated precondition boundary,
## its single no-actuation release step, and its role-local interaction source
## independently content-addressable before the aggregate supervisor compares
## the two child reports.

const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const EnergyInitializer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd"
)
const LocomotionFacade := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
)
const PreconditionTerminalDisposition := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_precondition_terminal_disposition_v1.gd"
)

const GATE_ID := "QSDK-R10F"
const REPAIR_ID := "QSDK-R10F-L9"
const NULLABLE_TERMINAL_FAILURE_REPAIR_ID := "QSDK-R10F-L10"
const SUCCESSOR_REPAIR_ID := "QSDK-R10F-L11"
const ACTIVE_ARM_ID := EnergyInitializer.ACTIVE_ARM_ID
const BASELINE_ARM_ID := EnergyInitializer.BASELINE_ARM_ID
const ARM_ORDER := [BASELINE_ARM_ID, ACTIVE_ARM_ID]
const PRECONDITION_SCHEMA := "sporespore_qsdk_r10f_l9_process_isolated_precondition_terminal_receipt_v1"
const RELEASE_SCHEMA := "sporespore_qsdk_r10f_l11_process_isolated_precondition_release_receipt_v1"
const RELEASE_OWNER_SOURCE_SCHEMA := "sporespore_qsdk_r10f_l11_precondition_release_owner_source_projection_v1"
const INTERACTION_SOURCE_SCHEMA := "sporespore_qsdk_r10f_l9_process_isolated_interaction_source_v1"
const ZERO_WORLD_SCHEMA := "sporespore_qsdk_r10f_l9_process_isolated_child_contract_zero_world_v1"
const NULLABLE_TERMINAL_FAILURE_ZERO_WORLD_SCHEMA := "sporespore_qsdk_r10f_l10_nullable_terminal_failure_code_zero_world_v1"
const RELEASE_OWNER_SOURCE_ZERO_WORLD_SCHEMA := "sporespore_qsdk_r10f_l11_precondition_release_owner_source_zero_world_v1"
const DISPOSITION_COMPLETE := "complete_source_retained"
const DISPOSITION_FAILED := "failed_source_retained"
const DISPOSITION_REFUSED := "refused_source_retained"
const PRECONDITION_KEYS := [
	"schema_version",
	"gate_id",
	"repair_id",
	"parent_attempt_id",
	"child_attempt_id",
	"arm_id",
	"model_instance_id",
	"completed_global_semantic_step",
	"disposition",
	"recovery_controller_id",
	"recovery_terminal_phase",
	"recovery_terminal_failure_code",
	"recovery_memory",
	"recovery_memory_sha256",
	"recovery_step_receipt",
	"recovery_step_receipt_sha256",
	"recovery_classification",
	"recovery_classification_sha256",
	"stable_four_foot_stance",
	"body_transform_write_count",
	"body_velocity_write_count",
	"solver_reset_count",
	"source_measurement",
	"outcome_derived_correction",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]
const RELEASE_KEYS := [
	"schema_version",
	"gate_id",
	"repair_id",
	"parent_attempt_id",
	"child_attempt_id",
	"arm_id",
	"model_instance_id",
	"global_semantic_step",
	"action_kind",
	"precondition_terminal_receipt",
	"precondition_terminal_receipt_sha256",
	"motor_configuration_receipt",
	"motor_configuration_receipt_sha256",
	"motor_population_readback",
	"motor_population_readback_sha256",
	"ledger_application_intent",
	"ledger_application_intent_sha256",
	"ordered_motor_readbacks",
	"control_owner",
	"actuation_owner",
	"no_actuation_requested",
	"source_measurement",
	"outcome_derived_correction",
	"body_transform_write_count",
	"body_velocity_write_count",
	"solver_reset_count",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]
const RELEASE_OWNER_SOURCE_KEYS := [
	"schema_version",
	"gate_id",
	"repair_id",
	"parent_attempt_id",
	"child_attempt_id",
	"arm_id",
	"model_instance_id",
	"completed_terminal_global_semantic_step",
	"release_global_semantic_step",
	"source_kind",
	"precondition_terminal_receipt_sha256",
	"recovery_memory_sha256",
	"recovery_step_receipt_sha256",
	"source_measurement",
	"outcome_derived_correction",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]
const INTERACTION_SOURCE_KEYS := [
	"schema_version",
	"gate_id",
	"repair_id",
	"parent_attempt_id",
	"child_attempt_id",
	"arm_id",
	"model_instance_id",
	"completed_effect_global_step",
	"interaction_local_step",
	"prefix_session_id",
	"prefix_session_receipt_sha256",
	"task_frame_forward_axis_world_host_real",
	"task_frame_lateral_axis_world_host_real",
	"scheduled_impulse_world_n_s",
	"pre_event_velocity_world_m_s",
	"completed_effect_velocity_world_m_s",
	"raw_velocity_delta_world_m_s",
	"raw_velocity_delta_magnitude_m_s",
	"application_count",
	"source_measurement",
	"outcome_derived_correction",
	"global_step_rewritten_for_pair_alignment",
	"force_aware_recovery_used",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]


static func build_precondition_terminal_receipt_v1(
	sdk: Object,
	parent_attempt_id: String,
	child_attempt_id: String,
	arm_id: String,
	model_instance_id: String,
	completed_global_semantic_step: int,
	recovery_controller_id: String,
	recovery_memory: Dictionary,
	recovery_step_receipt: Dictionary,
	recovery_classification: Dictionary,
	body_transform_write_count: int,
	body_velocity_write_count: int,
	solver_reset_count: int,
) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L9_PRECONDITION_SDK_MISSING")
	var terminal_projection := nullable_terminal_failure_code_projection_v1(recovery_memory)
	if not bool(terminal_projection.get("ok", false)):
		return _failure(
			"QSDK_R10F_L10_TERMINAL_FAILURE_SOURCE_INVALID",
			{"terminal_projection": terminal_projection},
		)
	var terminal_phase: Variant = terminal_projection["terminal_phase"]
	var terminal_failure: Variant = terminal_projection["projected_failure_code"]
	var disposition := DISPOSITION_COMPLETE
	if terminal_phase == "failed":
		disposition = DISPOSITION_FAILED
	elif terminal_phase == "refused":
		disposition = DISPOSITION_REFUSED
	var receipt := {
		"schema_version": PRECONDITION_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"parent_attempt_id": parent_attempt_id,
		"child_attempt_id": child_attempt_id,
		"arm_id": arm_id,
		"model_instance_id": model_instance_id,
		"completed_global_semantic_step": completed_global_semantic_step,
		"disposition": disposition,
		"recovery_controller_id": recovery_controller_id,
		"recovery_terminal_phase": terminal_phase,
		"recovery_terminal_failure_code": terminal_failure,
		"recovery_memory": recovery_memory.duplicate(true),
		"recovery_memory_sha256": _canonical_sha256_v1(sdk, recovery_memory),
		"recovery_step_receipt": recovery_step_receipt.duplicate(true),
		"recovery_step_receipt_sha256": _canonical_sha256_v1(sdk, recovery_step_receipt),
		"recovery_classification": recovery_classification.duplicate(true),
		"recovery_classification_sha256": _canonical_sha256_v1(sdk, recovery_classification),
		"stable_four_foot_stance": bool(recovery_classification.get("stable_stance_gate", false)),
		"body_transform_write_count": body_transform_write_count,
		"body_velocity_write_count": body_velocity_write_count,
		"solver_reset_count": solver_reset_count,
		"source_measurement": true,
		"outcome_derived_correction": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	receipt["payload_sha256"] = _payload_sha256_v1(sdk, receipt)
	if not precondition_terminal_receipt_valid_v1(sdk, receipt):
		return _failure(
			"QSDK_R10F_L9_PRECONDITION_TERMINAL_RECEIPT_INVALID",
			{"receipt": receipt},
		)
	return {
		"schema_version": "sporespore_qsdk_r10f_l9_process_isolated_precondition_terminal_build_v1",
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": true,
		"receipt": receipt,
		"receipt_sha256": String(receipt["payload_sha256"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func nullable_terminal_failure_code_projection_v1(recovery_memory: Dictionary) -> Dictionary:
	if not recovery_memory.has("phase"):
		return _failure("QSDK_R10F_L10_TERMINAL_PHASE_MISSING")
	if not recovery_memory.has("terminal_failure_code"):
		return _failure("QSDK_R10F_L10_TERMINAL_FAILURE_SOURCE_MISSING")
	var terminal_phase: Variant = recovery_memory["phase"]
	var terminal_failure_source: Variant = recovery_memory["terminal_failure_code"]
	if typeof(terminal_phase) != TYPE_STRING:
		return _failure("QSDK_R10F_L10_TERMINAL_PHASE_TYPE_INVALID")
	var projected_failure_code: Variant = ""
	var source_is_null := terminal_failure_source == null
	if terminal_phase == "complete":
		if not source_is_null:
			return _failure("QSDK_R10F_L10_COMPLETE_FAILURE_SOURCE_NOT_NULL")
	elif terminal_phase == "failed" or terminal_phase == "refused":
		if typeof(terminal_failure_source) != TYPE_STRING:
			return _failure("QSDK_R10F_L10_FAILED_FAILURE_SOURCE_NOT_STRING")
		if terminal_failure_source.is_empty():
			return _failure("QSDK_R10F_L10_FAILED_FAILURE_SOURCE_EMPTY")
		projected_failure_code = terminal_failure_source
	else:
		return _failure("QSDK_R10F_L10_TERMINAL_PHASE_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r10f_l10_nullable_terminal_failure_code_projection_v1",
		"gate_id": GATE_ID,
		"repair_id": NULLABLE_TERMINAL_FAILURE_REPAIR_ID,
		"ok": true,
		"terminal_phase": terminal_phase,
		"source_failure_code_is_null": source_is_null,
		"projected_failure_code": projected_failure_code,
		"generic_string_conversion_used": false,
		"source_mutated": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func precondition_terminal_receipt_valid_v1(sdk: Object, receipt: Dictionary) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(receipt, PRECONDITION_KEYS)
		or String(receipt.get("schema_version", "")) != PRECONDITION_SCHEMA
		or String(receipt.get("gate_id", "")) != GATE_ID
		or String(receipt.get("repair_id", "")) != REPAIR_ID
		or not _lower_hex_exact_v1(String(receipt.get("parent_attempt_id", "")), 32)
		or not _lower_hex_exact_v1(String(receipt.get("child_attempt_id", "")), 32)
		or (
			String(receipt.get("parent_attempt_id", ""))
			== String(receipt.get("child_attempt_id", ""))
		)
		or String(receipt.get("arm_id", "")) not in ARM_ORDER
		or String(receipt.get("model_instance_id", "")).is_empty()
		or typeof(receipt.get("completed_global_semantic_step")) != TYPE_INT
		or int(receipt.get("completed_global_semantic_step", -1)) < 1
		or String(receipt.get("recovery_controller_id", "")).is_empty()
		or not (receipt.get("recovery_memory") is Dictionary)
		or not (receipt.get("recovery_step_receipt") is Dictionary)
		or not (receipt.get("recovery_classification") is Dictionary)
		or typeof(receipt.get("stable_four_foot_stance")) != TYPE_BOOL
		or int(receipt.get("body_transform_write_count", -1)) != 0
		or int(receipt.get("body_velocity_write_count", -1)) != 0
		or int(receipt.get("solver_reset_count", -1)) != 0
		or not bool(receipt.get("source_measurement", false))
		or bool(receipt.get("outcome_derived_correction", true))
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return false
	var global_step := int(receipt["completed_global_semantic_step"])
	var memory: Dictionary = receipt["recovery_memory"]
	var step: Dictionary = receipt["recovery_step_receipt"]
	var classification: Dictionary = receipt["recovery_classification"]
	var step_memory_value: Variant = step.get("memory")
	var step_classification_value: Variant = step.get("classification")
	if (
		not (step_memory_value is Dictionary)
		or not (step_classification_value is Dictionary)
		or (step_memory_value as Dictionary) != memory
		or (step_classification_value as Dictionary) != classification
		or (
			typeof((step_memory_value as Dictionary).get("last_semantic_step"))
			!= typeof(memory.get("last_semantic_step"))
		)
		or not PreconditionTerminalDisposition.integer_valued_native_step_valid_v1(
			memory.get("last_semantic_step"), global_step
		)
		or String(step.get("next_phase", "")) != String(memory.get("phase", ""))
		or String(receipt.get("recovery_memory_sha256", "")) != _canonical_sha256_v1(sdk, memory)
		or (
			String(receipt.get("recovery_step_receipt_sha256", ""))
			!= _canonical_sha256_v1(sdk, step)
		)
		or (
			String(receipt.get("recovery_classification_sha256", ""))
			!= _canonical_sha256_v1(sdk, classification)
		)
	):
		return false
	var terminal_phase: Variant = receipt.get("recovery_terminal_phase")
	var terminal_failure: Variant = receipt.get("recovery_terminal_failure_code")
	if typeof(terminal_phase) != TYPE_STRING or typeof(terminal_failure) != TYPE_STRING:
		return false
	var terminal_projection := nullable_terminal_failure_code_projection_v1(memory)
	if (
		not bool(terminal_projection.get("ok", false))
		or terminal_phase != terminal_projection.get("terminal_phase")
		or terminal_failure != terminal_projection.get("projected_failure_code")
	):
		return false
	var disposition := String(receipt.get("disposition", ""))
	match disposition:
		DISPOSITION_COMPLETE:
			if (
				terminal_phase != "complete"
				or not terminal_failure.is_empty()
				or not bool(receipt.get("stable_four_foot_stance", false))
			):
				return false
		DISPOSITION_FAILED:
			if terminal_phase != "failed" or terminal_failure.is_empty():
				return false
		DISPOSITION_REFUSED:
			if terminal_phase != "refused" or terminal_failure.is_empty():
				return false
		_:
			return false
	return String(receipt.get("payload_sha256", "")) == _payload_sha256_v1(sdk, receipt)


## Narrow L11 provenance source for the motors-disabled release frame. The
## complete terminal and recovery receipts stay intact in the release receipt;
## this projection gives the no-actuation ledger only identity, sequencing,
## and content digests. No classification, work, or energy value is copied.
static func precondition_release_owner_source_projection_v1(
	sdk: Object,
	precondition_terminal_receipt: Dictionary,
) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L11_RELEASE_OWNER_SDK_MISSING")
	if not precondition_terminal_receipt_valid_v1(sdk, precondition_terminal_receipt):
		return _failure("QSDK_R10F_L11_RELEASE_OWNER_TERMINAL_INVALID")
	if String(precondition_terminal_receipt.get("disposition", "")) != DISPOSITION_COMPLETE:
		return _failure("QSDK_R10F_L11_RELEASE_OWNER_TERMINAL_NOT_COMPLETE")
	var completed_step := int(
		precondition_terminal_receipt.get("completed_global_semantic_step", -1)
	)
	var source := {
		"schema_version": RELEASE_OWNER_SOURCE_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": SUCCESSOR_REPAIR_ID,
		"parent_attempt_id": String(precondition_terminal_receipt.get("parent_attempt_id", "")),
		"child_attempt_id": String(precondition_terminal_receipt.get("child_attempt_id", "")),
		"arm_id": String(precondition_terminal_receipt.get("arm_id", "")),
		"model_instance_id": String(precondition_terminal_receipt.get("model_instance_id", "")),
		"completed_terminal_global_semantic_step": completed_step,
		"release_global_semantic_step": completed_step + 1,
		"source_kind": "validated_complete_precondition_release_no_actuation",
		"precondition_terminal_receipt_sha256":
		String(precondition_terminal_receipt.get("payload_sha256", "")),
		"recovery_memory_sha256":
		String(precondition_terminal_receipt.get("recovery_memory_sha256", "")),
		"recovery_step_receipt_sha256":
		String(precondition_terminal_receipt.get("recovery_step_receipt_sha256", "")),
		"source_measurement": true,
		"outcome_derived_correction": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	source["payload_sha256"] = _payload_sha256_v1(sdk, source)
	if not precondition_release_owner_source_projection_valid_v1(
		sdk, source, precondition_terminal_receipt
	):
		return _failure(
			"QSDK_R10F_L11_RELEASE_OWNER_PROJECTION_INVALID",
			{"source": source},
		)
	return {
		"schema_version": "sporespore_qsdk_r10f_l11_precondition_release_owner_source_build_v1",
		"gate_id": GATE_ID,
		"repair_id": SUCCESSOR_REPAIR_ID,
		"ok": true,
		"source": source,
		"source_sha256": String(source["payload_sha256"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func precondition_release_owner_source_projection_valid_v1(
	sdk: Object,
	source: Dictionary,
	precondition_terminal_receipt: Dictionary,
) -> bool:
	if (
		sdk == null
		or not precondition_terminal_receipt_valid_v1(sdk, precondition_terminal_receipt)
		or String(precondition_terminal_receipt.get("disposition", "")) != DISPOSITION_COMPLETE
		or not _keys_exact_v1(source, RELEASE_OWNER_SOURCE_KEYS)
		or String(source.get("schema_version", "")) != RELEASE_OWNER_SOURCE_SCHEMA
		or String(source.get("gate_id", "")) != GATE_ID
		or String(source.get("repair_id", "")) != SUCCESSOR_REPAIR_ID
		or typeof(source.get("completed_terminal_global_semantic_step")) != TYPE_INT
		or typeof(source.get("release_global_semantic_step")) != TYPE_INT
		or (
			String(source.get("source_kind", ""))
			!= "validated_complete_precondition_release_no_actuation"
		)
		or not bool(source.get("source_measurement", false))
		or bool(source.get("outcome_derived_correction", true))
		or bool(source.get("physical_acceptance_authority", true))
		or bool(source.get("release_authority", true))
	):
		return false
	var completed_step := int(
		precondition_terminal_receipt.get("completed_global_semantic_step", -1)
	)
	if (
		(
			String(source.get("parent_attempt_id", ""))
			!= String(precondition_terminal_receipt.get("parent_attempt_id", ""))
		)
		or (
			String(source.get("child_attempt_id", ""))
			!= String(precondition_terminal_receipt.get("child_attempt_id", ""))
		)
		or (
			String(source.get("arm_id", ""))
			!= String(precondition_terminal_receipt.get("arm_id", ""))
		)
		or (
			String(source.get("model_instance_id", ""))
			!= String(precondition_terminal_receipt.get("model_instance_id", ""))
		)
		or int(source.get("completed_terminal_global_semantic_step", -1)) != completed_step
		or int(source.get("release_global_semantic_step", -1)) != completed_step + 1
		or (
			String(source.get("precondition_terminal_receipt_sha256", ""))
			!= String(precondition_terminal_receipt.get("payload_sha256", ""))
		)
		or (
			String(source.get("recovery_memory_sha256", ""))
			!= String(precondition_terminal_receipt.get("recovery_memory_sha256", ""))
		)
		or (
			String(source.get("recovery_step_receipt_sha256", ""))
			!= String(precondition_terminal_receipt.get("recovery_step_receipt_sha256", ""))
		)
	):
		return false
	return String(source.get("payload_sha256", "")) == _payload_sha256_v1(sdk, source)


static func build_precondition_release_receipt_v1(
	sdk: Object,
	precondition_terminal_receipt: Dictionary,
	global_semantic_step: int,
	motor_configuration_receipt: Dictionary,
	motor_population_readback: Dictionary,
	ledger_application_intent: Dictionary,
) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L9_RELEASE_SDK_MISSING")
	var rows: Array = []
	var rows_value: Variant = motor_population_readback.get("ordered_joint_readbacks")
	if rows_value is Array:
		for value in rows_value as Array:
			if not (value is Dictionary):
				return _failure("QSDK_R10F_L9_RELEASE_READBACK_ROW_INVALID")
			var row: Dictionary = value
			(
				rows
				. append(
					{
						"joint_id": String(row.get("joint_id", "")),
						"motor_enabled": bool(row.get("motor_enabled", true)),
						"motor_target_velocity_rad_s":
						float(row.get("motor_target_velocity_rad_s", NAN)),
					}
				)
			)
	var receipt := {
		"schema_version": RELEASE_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": SUCCESSOR_REPAIR_ID,
		"parent_attempt_id": String(precondition_terminal_receipt.get("parent_attempt_id", "")),
		"child_attempt_id": String(precondition_terminal_receipt.get("child_attempt_id", "")),
		"arm_id": String(precondition_terminal_receipt.get("arm_id", "")),
		"model_instance_id": String(precondition_terminal_receipt.get("model_instance_id", "")),
		"global_semantic_step": global_semantic_step,
		"action_kind": "process_isolated_no_actuation_release",
		"precondition_terminal_receipt": precondition_terminal_receipt.duplicate(true),
		"precondition_terminal_receipt_sha256":
		String(precondition_terminal_receipt.get("payload_sha256", "")),
		"motor_configuration_receipt": motor_configuration_receipt.duplicate(true),
		"motor_configuration_receipt_sha256":
		_canonical_sha256_v1(sdk, motor_configuration_receipt),
		"motor_population_readback": motor_population_readback.duplicate(true),
		"motor_population_readback_sha256": _canonical_sha256_v1(sdk, motor_population_readback),
		"ledger_application_intent": ledger_application_intent.duplicate(true),
		"ledger_application_intent_sha256": _canonical_sha256_v1(sdk, ledger_application_intent),
		"ordered_motor_readbacks": rows,
		"control_owner": "none",
		"actuation_owner": "none",
		"no_actuation_requested": true,
		"source_measurement": true,
		"outcome_derived_correction": false,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	receipt["payload_sha256"] = _payload_sha256_v1(sdk, receipt)
	if not precondition_release_receipt_valid_v1(sdk, receipt):
		return _failure("QSDK_R10F_L9_PRECONDITION_RELEASE_RECEIPT_INVALID", {"receipt": receipt})
	return {
		"schema_version": "sporespore_qsdk_r10f_l11_process_isolated_precondition_release_build_v1",
		"gate_id": GATE_ID,
		"repair_id": SUCCESSOR_REPAIR_ID,
		"ok": true,
		"receipt": receipt,
		"receipt_sha256": String(receipt["payload_sha256"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func precondition_release_receipt_valid_v1(sdk: Object, receipt: Dictionary) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(receipt, RELEASE_KEYS)
		or String(receipt.get("schema_version", "")) != RELEASE_SCHEMA
		or String(receipt.get("gate_id", "")) != GATE_ID
		or String(receipt.get("repair_id", "")) != SUCCESSOR_REPAIR_ID
		or String(receipt.get("arm_id", "")) not in ARM_ORDER
		or typeof(receipt.get("global_semantic_step")) != TYPE_INT
		or String(receipt.get("action_kind", "")) != "process_isolated_no_actuation_release"
		or not (receipt.get("precondition_terminal_receipt") is Dictionary)
		or not (receipt.get("motor_configuration_receipt") is Dictionary)
		or not (receipt.get("motor_population_readback") is Dictionary)
		or not (receipt.get("ledger_application_intent") is Dictionary)
		or not (receipt.get("ordered_motor_readbacks") is Array)
		or not bool(receipt.get("no_actuation_requested", false))
		or String(receipt.get("control_owner", "")) != "none"
		or String(receipt.get("actuation_owner", "")) != "none"
		or not bool(receipt.get("source_measurement", false))
		or bool(receipt.get("outcome_derived_correction", true))
		or int(receipt.get("body_transform_write_count", -1)) != 0
		or int(receipt.get("body_velocity_write_count", -1)) != 0
		or int(receipt.get("solver_reset_count", -1)) != 0
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return false
	var terminal: Dictionary = receipt["precondition_terminal_receipt"]
	var configuration: Dictionary = receipt["motor_configuration_receipt"]
	var readback: Dictionary = receipt["motor_population_readback"]
	var ledger: Dictionary = receipt["ledger_application_intent"]
	var release_owner_build := precondition_release_owner_source_projection_v1(sdk, terminal)
	if not bool(release_owner_build.get("ok", false)):
		return false
	var release_owner_source: Dictionary = release_owner_build["source"]
	var global_step := int(receipt.get("global_semantic_step", -1))
	if (
		not precondition_terminal_receipt_valid_v1(sdk, terminal)
		or String(terminal.get("disposition", "")) != DISPOSITION_COMPLETE
		or global_step != int(terminal.get("completed_global_semantic_step", -2)) + 1
		or (
			String(receipt.get("parent_attempt_id", ""))
			!= String(terminal.get("parent_attempt_id", ""))
		)
		or (
			String(receipt.get("child_attempt_id", ""))
			!= String(terminal.get("child_attempt_id", ""))
		)
		or String(receipt.get("arm_id", "")) != String(terminal.get("arm_id", ""))
		or (
			String(receipt.get("model_instance_id", ""))
			!= String(terminal.get("model_instance_id", ""))
		)
		or (
			String(receipt.get("precondition_terminal_receipt_sha256", ""))
			!= String(terminal.get("payload_sha256", ""))
		)
		or (
			String(receipt.get("motor_configuration_receipt_sha256", ""))
			!= _canonical_sha256_v1(sdk, configuration)
		)
		or (
			String(receipt.get("motor_population_readback_sha256", ""))
			!= _canonical_sha256_v1(sdk, readback)
		)
		or (
			String(receipt.get("ledger_application_intent_sha256", ""))
			!= _canonical_sha256_v1(sdk, ledger)
		)
	):
		return false
	var configuration_rows: Variant = configuration.get("ordered_joint_receipts")
	var native_rows: Variant = readback.get("ordered_joint_readbacks")
	var projected_rows: Array = receipt["ordered_motor_readbacks"]
	if (
		not bool(configuration.get("ok", false))
		or int(configuration.get("global_semantic_step", -1)) != global_step
		or bool(configuration.get("motor_enabled", true))
		or not (configuration_rows is Array)
		or (configuration_rows as Array).size() != LocomotionFacade.JOINT_IDS.size()
		or not bool(readback.get("ok", false))
		or int(readback.get("global_semantic_step", -1)) != global_step
		or bool(readback.get("expected_motor_enabled", true))
		or int(readback.get("motor_enabled_count", -1)) != 0
		or int(readback.get("zero_target_velocity_count", -1)) != LocomotionFacade.JOINT_IDS.size()
		or int(readback.get("native_readback_count", -1)) != LocomotionFacade.JOINT_IDS.size() * 3
		or not (native_rows is Array)
		or (native_rows as Array).size() != LocomotionFacade.JOINT_IDS.size()
		or projected_rows.size() != LocomotionFacade.JOINT_IDS.size()
		or not bool(ledger.get("ok", false))
		or int(ledger.get("semantic_step", -1)) != global_step
		or not bool(ledger.get("no_actuation_requested", false))
		or String(ledger.get("controller_owner", "")) != "none"
		or release_owner_source.is_empty()
		or ledger.get("owner_source_receipt") != release_owner_source
		or (
			String(ledger.get("owner_source_receipt_sha256", ""))
			!= _canonical_sha256_v1(sdk, release_owner_source)
		)
		or ledger.get("motor_population_readback") != readback
	):
		return false
	for index in range(LocomotionFacade.JOINT_IDS.size()):
		var configured_value: Variant = (configuration_rows as Array)[index]
		var native_value: Variant = (native_rows as Array)[index]
		var projected_value: Variant = projected_rows[index]
		if (
			not (configured_value is Dictionary)
			or not (native_value is Dictionary)
			or not (projected_value is Dictionary)
		):
			return false
		var configured: Dictionary = configured_value
		var native: Dictionary = native_value
		var projected: Dictionary = projected_value
		var joint_id := String(LocomotionFacade.JOINT_IDS[index])
		if (
			String(configured.get("joint_id", "")) != joint_id
			or bool(configured.get("motor_enabled", true))
			or float(configured.get("motor_target_velocity_rad_s", NAN)) != 0.0
			or String(native.get("joint_id", "")) != joint_id
			or bool(native.get("motor_enabled", true))
			or float(native.get("motor_target_velocity_rad_s", NAN)) != 0.0
			or not is_finite(float(native.get("motor_maximum_impulse_nms", NAN)))
			or float(native.get("motor_maximum_impulse_nms", NAN)) <= 0.0
			or not _keys_exact_v1(
				projected, ["joint_id", "motor_enabled", "motor_target_velocity_rad_s"]
			)
			or String(projected.get("joint_id", "")) != joint_id
			or bool(projected.get("motor_enabled", true))
			or float(projected.get("motor_target_velocity_rad_s", NAN)) != 0.0
		):
			return false
	return String(receipt.get("payload_sha256", "")) == _payload_sha256_v1(sdk, receipt)


static func build_interaction_source_v1(
	sdk: Object,
	parent_attempt_id: String,
	child_attempt_id: String,
	arm_id: String,
	model_instance_id: String,
	completed_effect_global_step: int,
	prefix_session_receipt: Dictionary,
	scheduled_impulse_world_n_s: Array,
	pre_event_velocity_world_m_s: Array,
	completed_effect_velocity_world_m_s: Array,
	application_count: int,
) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L9_INTERACTION_SOURCE_SDK_MISSING")
	var before := _finite_vector_v1(pre_event_velocity_world_m_s)
	var after := _finite_vector_v1(completed_effect_velocity_world_m_s)
	if before.is_empty() or after.is_empty():
		return _failure("QSDK_R10F_L9_INTERACTION_VELOCITY_INVALID")
	var delta := _subtract_v1(after, before)
	var receipt := {
		"schema_version": INTERACTION_SOURCE_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"parent_attempt_id": parent_attempt_id,
		"child_attempt_id": child_attempt_id,
		"arm_id": arm_id,
		"model_instance_id": model_instance_id,
		"completed_effect_global_step": completed_effect_global_step,
		"interaction_local_step": 1,
		"prefix_session_id": String(prefix_session_receipt.get("session_id", "")),
		"prefix_session_receipt_sha256": _canonical_sha256_v1(sdk, prefix_session_receipt),
		"task_frame_forward_axis_world_host_real":
		(
			(prefix_session_receipt.get("task_frame_forward_axis_world_host_real", []) as Array)
			. duplicate()
		),
		"task_frame_lateral_axis_world_host_real":
		(
			(prefix_session_receipt.get("task_frame_lateral_axis_world_host_real", []) as Array)
			. duplicate()
		),
		"scheduled_impulse_world_n_s": scheduled_impulse_world_n_s.duplicate(),
		"pre_event_velocity_world_m_s": before,
		"completed_effect_velocity_world_m_s": after,
		"raw_velocity_delta_world_m_s": delta,
		"raw_velocity_delta_magnitude_m_s": _norm_v1(delta),
		"application_count": application_count,
		"source_measurement": true,
		"outcome_derived_correction": false,
		"global_step_rewritten_for_pair_alignment": false,
		"force_aware_recovery_used": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	receipt["payload_sha256"] = _payload_sha256_v1(sdk, receipt)
	if not interaction_source_valid_v1(sdk, receipt):
		return _failure("QSDK_R10F_L9_INTERACTION_SOURCE_INVALID", {"receipt": receipt})
	return {
		"schema_version": "sporespore_qsdk_r10f_l9_process_isolated_interaction_source_build_v1",
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": true,
		"source": receipt,
		"source_sha256": String(receipt["payload_sha256"]),
		"raw_velocity_delta_magnitude_m_s": float(receipt["raw_velocity_delta_magnitude_m_s"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func interaction_source_valid_v1(sdk: Object, receipt: Dictionary) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(receipt, INTERACTION_SOURCE_KEYS)
		or String(receipt.get("schema_version", "")) != INTERACTION_SOURCE_SCHEMA
		or String(receipt.get("gate_id", "")) != GATE_ID
		or String(receipt.get("repair_id", "")) != REPAIR_ID
		or not _lower_hex_exact_v1(String(receipt.get("parent_attempt_id", "")), 32)
		or not _lower_hex_exact_v1(String(receipt.get("child_attempt_id", "")), 32)
		or (
			String(receipt.get("parent_attempt_id", ""))
			== String(receipt.get("child_attempt_id", ""))
		)
		or String(receipt.get("arm_id", "")) not in ARM_ORDER
		or String(receipt.get("model_instance_id", "")).is_empty()
		or typeof(receipt.get("completed_effect_global_step")) != TYPE_INT
		or int(receipt.get("completed_effect_global_step", -1)) <= 1
		or int(receipt.get("interaction_local_step", -1)) != 1
		or typeof(receipt.get("application_count")) != TYPE_INT
		or String(receipt.get("prefix_session_id", "")).is_empty()
		or not _valid_sha256_v1(String(receipt.get("prefix_session_receipt_sha256", "")))
		or not bool(receipt.get("source_measurement", false))
		or bool(receipt.get("outcome_derived_correction", true))
		or bool(receipt.get("global_step_rewritten_for_pair_alignment", true))
		or bool(receipt.get("force_aware_recovery_used", true))
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return false
	var forward := _finite_vector_v1(receipt.get("task_frame_forward_axis_world_host_real"))
	var lateral := _finite_vector_v1(receipt.get("task_frame_lateral_axis_world_host_real"))
	var impulse := _finite_vector_v1(receipt.get("scheduled_impulse_world_n_s"))
	var before := _finite_vector_v1(receipt.get("pre_event_velocity_world_m_s"))
	var after := _finite_vector_v1(receipt.get("completed_effect_velocity_world_m_s"))
	var retained_delta := _finite_vector_v1(receipt.get("raw_velocity_delta_world_m_s"))
	if (
		forward.is_empty()
		or lateral.is_empty()
		or impulse.is_empty()
		or before.is_empty()
		or after.is_empty()
		or retained_delta.is_empty()
		or absf(_norm_v1(forward) - 1.0) > 2.0e-6
		or absf(_norm_v1(lateral) - 1.0) > 2.0e-6
		or absf(_dot_v1(forward, lateral)) > 2.0e-6
		or retained_delta != _subtract_v1(after, before)
		or not is_finite(float(receipt.get("raw_velocity_delta_magnitude_m_s", NAN)))
		or (
			absf(float(receipt["raw_velocity_delta_magnitude_m_s"]) - _norm_v1(retained_delta))
			> 1.0e-12
		)
	):
		return false
	var arm_id := String(receipt["arm_id"])
	if arm_id == ACTIVE_ARM_ID:
		var expected_impulse := [
			float(lateral[0]) * EnergyInitializer.KICK_IMPULSE_MAGNITUDE_N_S,
			float(lateral[1]) * EnergyInitializer.KICK_IMPULSE_MAGNITUDE_N_S,
			float(lateral[2]) * EnergyInitializer.KICK_IMPULSE_MAGNITUDE_N_S,
		]
		if (
			int(receipt.get("application_count", -1)) != 1
			or not _components_close_v1(impulse, expected_impulse, 2.0e-6)
			or _norm_v1(retained_delta) < EnergyInitializer.NATIVE_EFFECT_FLOOR_M_S
		):
			return false
	else:
		if int(receipt.get("application_count", -1)) != 0 or _norm_v1(impulse) != 0.0:
			return false
	return String(receipt.get("payload_sha256", "")) == _payload_sha256_v1(sdk, receipt)


static func zero_world_contract_v1(sdk: Object) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L9_ZERO_WORLD_SDK_MISSING")
	var parent_id := "0123456789abcdef0123456789abcdef"
	var baseline_child_id := "11111111111111111111111111111111"
	var active_child_id := "22222222222222222222222222222222"
	var terminal_builds := {
		"baseline_complete_source_accepted":
		_zero_world_precondition_build_v1(
			sdk, parent_id, baseline_child_id, BASELINE_ARM_ID, "complete", null, true
		),
		"active_complete_source_accepted":
		_zero_world_precondition_build_v1(
			sdk, parent_id, active_child_id, ACTIVE_ARM_ID, "complete", null, true
		),
		"failed_source_retained_without_behavior_promotion":
		_zero_world_precondition_build_v1(
			sdk,
			parent_id,
			"33333333333333333333333333333333",
			ACTIVE_ARM_ID,
			"failed",
			"phase_timeout:stance_dwell",
			false,
		),
		"refused_source_retained_without_behavior_promotion":
		_zero_world_precondition_build_v1(
			sdk,
			parent_id,
			"44444444444444444444444444444444",
			BASELINE_ARM_ID,
			"refused",
			"precondition_source_refused",
			false,
		),
	}
	var positive_controls := {}
	for control_id in terminal_builds:
		positive_controls[control_id] = bool(
			(terminal_builds[control_id] as Dictionary).get("ok", false)
		)
	var baseline_terminal: Dictionary = (
		(terminal_builds["baseline_complete_source_accepted"] as Dictionary).get("receipt", {})
	)
	var active_terminal: Dictionary = (
		(terminal_builds["active_complete_source_accepted"] as Dictionary).get("receipt", {})
	)

	var baseline_release := _zero_world_release_build_v1(sdk, baseline_terminal)
	var active_release := _zero_world_release_build_v1(sdk, active_terminal)
	positive_controls["baseline_complete_source_crosses_one_release_step"] = bool(
		baseline_release.get("ok", false)
	)
	positive_controls["active_complete_source_crosses_one_release_step"] = bool(
		active_release.get("ok", false)
	)

	var prefix_receipt := {
		"session_id": "l9-zero-world-walking-prefix",
		"task_frame_forward_axis_world_host_real": [1.0, 0.0, 0.0],
		"task_frame_lateral_axis_world_host_real": [0.0, 0.0, 1.0],
	}
	var baseline_interaction := build_interaction_source_v1(
		sdk,
		parent_id,
		baseline_child_id,
		BASELINE_ARM_ID,
		"l9-zero-world-baseline-model",
		722,
		prefix_receipt,
		[0.0, 0.0, 0.0],
		[0.10, 0.0, -0.01],
		[0.10, 0.0, -0.009],
		0,
	)
	var active_interaction := build_interaction_source_v1(
		sdk,
		parent_id,
		active_child_id,
		ACTIVE_ARM_ID,
		"l9-zero-world-active-model",
		722,
		prefix_receipt,
		[0.0, 0.0, EnergyInitializer.KICK_IMPULSE_MAGNITUDE_N_S],
		[0.10, 0.0, -0.01],
		[0.10, 0.0, 0.01],
		1,
	)
	positive_controls["baseline_local_interaction_source_accepts_zero_kicks"] = bool(
		baseline_interaction.get("ok", false)
	)
	positive_controls["active_local_interaction_source_accepts_one_native_kick"] = bool(
		active_interaction.get("ok", false)
	)

	var negative_controls := {}
	if not baseline_terminal.is_empty():
		var same_parent_and_child := baseline_terminal.duplicate(true)
		same_parent_and_child["child_attempt_id"] = parent_id
		same_parent_and_child["payload_sha256"] = _payload_sha256_v1(sdk, same_parent_and_child)
		negative_controls["duplicate_parent_and_child_identity_refused"] = (not precondition_terminal_receipt_valid_v1(
			sdk, same_parent_and_child
		))
		var unknown_role := baseline_terminal.duplicate(true)
		unknown_role["arm_id"] = "unknown-arm"
		unknown_role["payload_sha256"] = _payload_sha256_v1(sdk, unknown_role)
		negative_controls["unknown_precondition_role_refused"] = (not precondition_terminal_receipt_valid_v1(
			sdk, unknown_role
		))
		var fraction := baseline_terminal.duplicate(true)
		var fraction_memory: Dictionary = (fraction["recovery_memory"] as Dictionary).duplicate(
			true
		)
		fraction_memory["last_semantic_step"] = 1.5
		var fraction_step: Dictionary = (fraction["recovery_step_receipt"] as Dictionary).duplicate(
			true
		)
		fraction_step["memory"] = fraction_memory.duplicate(true)
		fraction["recovery_memory"] = fraction_memory
		fraction["recovery_step_receipt"] = fraction_step
		fraction["recovery_memory_sha256"] = _canonical_sha256_v1(sdk, fraction_memory)
		fraction["recovery_step_receipt_sha256"] = _canonical_sha256_v1(sdk, fraction_step)
		fraction["payload_sha256"] = _payload_sha256_v1(sdk, fraction)
		negative_controls["fractional_native_precondition_step_refused"] = (not precondition_terminal_receipt_valid_v1(
			sdk, fraction
		))
		var unstable_complete := baseline_terminal.duplicate(true)
		unstable_complete["stable_four_foot_stance"] = false
		unstable_complete["payload_sha256"] = _payload_sha256_v1(sdk, unstable_complete)
		negative_controls["unstable_complete_precondition_refused"] = (not precondition_terminal_receipt_valid_v1(
			sdk, unstable_complete
		))
		var transform_write := baseline_terminal.duplicate(true)
		transform_write["body_transform_write_count"] = 1
		transform_write["payload_sha256"] = _payload_sha256_v1(sdk, transform_write)
		negative_controls["post_construction_transform_write_refused"] = (not precondition_terminal_receipt_valid_v1(
			sdk, transform_write
		))
		var outcome_correction := baseline_terminal.duplicate(true)
		outcome_correction["outcome_derived_correction"] = true
		outcome_correction["payload_sha256"] = _payload_sha256_v1(sdk, outcome_correction)
		negative_controls["outcome_derived_precondition_correction_refused"] = (not precondition_terminal_receipt_valid_v1(
			sdk, outcome_correction
		))
		var premature_authority := baseline_terminal.duplicate(true)
		premature_authority["physical_acceptance_authority"] = true
		premature_authority["payload_sha256"] = _payload_sha256_v1(sdk, premature_authority)
		negative_controls["precondition_claim_promotion_refused"] = (not precondition_terminal_receipt_valid_v1(
			sdk, premature_authority
		))
		var bad_terminal_digest := baseline_terminal.duplicate(true)
		bad_terminal_digest["payload_sha256"] = _filled_sha256_v1("f")
		negative_controls["precondition_digest_mismatch_refused"] = (not precondition_terminal_receipt_valid_v1(
			sdk, bad_terminal_digest
		))

	var baseline_release_receipt: Dictionary = baseline_release.get("receipt", {})
	if not baseline_release_receipt.is_empty():
		var fractional_release_step := baseline_release_receipt.duplicate(true)
		fractional_release_step["global_semantic_step"] = 2.0
		fractional_release_step["payload_sha256"] = _payload_sha256_v1(sdk, fractional_release_step)
		negative_controls["fractional_release_step_refused"] = (not precondition_release_receipt_valid_v1(
			sdk, fractional_release_step
		))
		var early_release := baseline_release_receipt.duplicate(true)
		early_release["global_semantic_step"] = 1
		early_release["payload_sha256"] = _payload_sha256_v1(sdk, early_release)
		negative_controls["release_without_one_completed_boundary_refused"] = (not precondition_release_receipt_valid_v1(
			sdk, early_release
		))
		var enabled_motor := baseline_release_receipt.duplicate(true)
		(enabled_motor["ordered_motor_readbacks"] as Array)[0]["motor_enabled"] = true
		enabled_motor["payload_sha256"] = _payload_sha256_v1(sdk, enabled_motor)
		negative_controls["enabled_motor_during_release_refused"] = (not precondition_release_receipt_valid_v1(
			sdk, enabled_motor
		))
		var target_velocity := baseline_release_receipt.duplicate(true)
		(target_velocity["ordered_motor_readbacks"] as Array)[0]["motor_target_velocity_rad_s"] = 0.1
		target_velocity["payload_sha256"] = _payload_sha256_v1(sdk, target_velocity)
		negative_controls["nonzero_release_motor_target_refused"] = (not precondition_release_receipt_valid_v1(
			sdk, target_velocity
		))
		var actuation_owned := baseline_release_receipt.duplicate(true)
		actuation_owned["control_owner"] = "recovery_v6"
		actuation_owned["actuation_owner"] = "recovery_v6"
		actuation_owned["no_actuation_requested"] = false
		actuation_owned["payload_sha256"] = _payload_sha256_v1(sdk, actuation_owned)
		negative_controls["actuation_owned_release_refused"] = (not precondition_release_receipt_valid_v1(
			sdk, actuation_owned
		))
		var wrong_owner_source := baseline_release_receipt.duplicate(true)
		var wrong_ledger: Dictionary = (
			(wrong_owner_source["ledger_application_intent"] as Dictionary).duplicate(true)
		)
		wrong_ledger["owner_source_receipt"] = {"foreign_source": true}
		wrong_owner_source["ledger_application_intent"] = wrong_ledger
		wrong_owner_source["ledger_application_intent_sha256"] = _canonical_sha256_v1(
			sdk, wrong_ledger
		)
		wrong_owner_source["payload_sha256"] = _payload_sha256_v1(sdk, wrong_owner_source)
		negative_controls["foreign_release_owner_source_refused"] = (not precondition_release_receipt_valid_v1(
			sdk, wrong_owner_source
		))
		var release_body_write := baseline_release_receipt.duplicate(true)
		release_body_write["body_velocity_write_count"] = 1
		release_body_write["payload_sha256"] = _payload_sha256_v1(sdk, release_body_write)
		negative_controls["release_body_velocity_write_refused"] = (not precondition_release_receipt_valid_v1(
			sdk, release_body_write
		))
		var release_correction := baseline_release_receipt.duplicate(true)
		release_correction["outcome_derived_correction"] = true
		release_correction["payload_sha256"] = _payload_sha256_v1(sdk, release_correction)
		negative_controls["outcome_derived_release_correction_refused"] = (not precondition_release_receipt_valid_v1(
			sdk, release_correction
		))
		var release_authority := baseline_release_receipt.duplicate(true)
		release_authority["release_authority"] = true
		release_authority["payload_sha256"] = _payload_sha256_v1(sdk, release_authority)
		negative_controls["premature_release_authority_refused"] = (not precondition_release_receipt_valid_v1(
			sdk, release_authority
		))
		var bad_release_digest := baseline_release_receipt.duplicate(true)
		bad_release_digest["payload_sha256"] = _filled_sha256_v1("e")
		negative_controls["release_digest_mismatch_refused"] = (not precondition_release_receipt_valid_v1(
			sdk, bad_release_digest
		))

	var active_source: Dictionary = active_interaction.get("source", {})
	var baseline_source: Dictionary = baseline_interaction.get("source", {})
	if not active_source.is_empty() and not baseline_source.is_empty():
		var interaction_same_identity := active_source.duplicate(true)
		interaction_same_identity["child_attempt_id"] = parent_id
		interaction_same_identity["payload_sha256"] = _payload_sha256_v1(
			sdk, interaction_same_identity
		)
		negative_controls["interaction_duplicate_identity_refused"] = (not interaction_source_valid_v1(
			sdk, interaction_same_identity
		))
		var fractional_effect_step := active_source.duplicate(true)
		fractional_effect_step["completed_effect_global_step"] = 722.0
		fractional_effect_step["payload_sha256"] = _payload_sha256_v1(sdk, fractional_effect_step)
		negative_controls["fractional_interaction_step_refused"] = (not interaction_source_valid_v1(
			sdk, fractional_effect_step
		))
		var nonorthogonal_frame := active_source.duplicate(true)
		nonorthogonal_frame["task_frame_lateral_axis_world_host_real"] = [1.0, 0.0, 0.0]
		nonorthogonal_frame["payload_sha256"] = _payload_sha256_v1(sdk, nonorthogonal_frame)
		negative_controls["nonorthogonal_task_frame_refused"] = (not interaction_source_valid_v1(
			sdk, nonorthogonal_frame
		))
		var second_active_kick := active_source.duplicate(true)
		second_active_kick["application_count"] = 2
		second_active_kick["payload_sha256"] = _payload_sha256_v1(sdk, second_active_kick)
		negative_controls["second_active_kick_refused"] = (not interaction_source_valid_v1(
			sdk, second_active_kick
		))
		var baseline_kick := baseline_source.duplicate(true)
		baseline_kick["scheduled_impulse_world_n_s"] = [
			0.0, 0.0, EnergyInitializer.KICK_IMPULSE_MAGNITUDE_N_S
		]
		baseline_kick["application_count"] = 1
		baseline_kick["payload_sha256"] = _payload_sha256_v1(sdk, baseline_kick)
		negative_controls["baseline_kick_refused"] = (not interaction_source_valid_v1(
			sdk, baseline_kick
		))
		var below_native_floor := active_source.duplicate(true)
		below_native_floor["completed_effect_velocity_world_m_s"] = [0.10, 0.0, -0.00995]
		below_native_floor["raw_velocity_delta_world_m_s"] = [0.0, 0.0, 0.00005]
		below_native_floor["raw_velocity_delta_magnitude_m_s"] = 0.00005
		below_native_floor["payload_sha256"] = _payload_sha256_v1(sdk, below_native_floor)
		negative_controls["active_native_effect_below_frozen_floor_refused"] = (not interaction_source_valid_v1(
			sdk, below_native_floor
		))
		var forged_delta := active_source.duplicate(true)
		forged_delta["raw_velocity_delta_world_m_s"] = [0.0, 0.0, 0.25]
		forged_delta["raw_velocity_delta_magnitude_m_s"] = 0.25
		forged_delta["payload_sha256"] = _payload_sha256_v1(sdk, forged_delta)
		negative_controls["forged_native_velocity_delta_refused"] = (not interaction_source_valid_v1(
			sdk, forged_delta
		))
		var global_rewrite := active_source.duplicate(true)
		global_rewrite["global_step_rewritten_for_pair_alignment"] = true
		global_rewrite["payload_sha256"] = _payload_sha256_v1(sdk, global_rewrite)
		negative_controls["global_step_pair_rewrite_refused"] = (not interaction_source_valid_v1(
			sdk, global_rewrite
		))
		var force_aware := active_source.duplicate(true)
		force_aware["force_aware_recovery_used"] = true
		force_aware["payload_sha256"] = _payload_sha256_v1(sdk, force_aware)
		negative_controls["force_aware_scope_expansion_refused"] = (not interaction_source_valid_v1(
			sdk, force_aware
		))
		var interaction_correction := active_source.duplicate(true)
		interaction_correction["outcome_derived_correction"] = true
		interaction_correction["payload_sha256"] = _payload_sha256_v1(sdk, interaction_correction)
		negative_controls["outcome_derived_interaction_correction_refused"] = (not interaction_source_valid_v1(
			sdk, interaction_correction
		))
		var bad_prefix_digest := active_source.duplicate(true)
		bad_prefix_digest["prefix_session_receipt_sha256"] = "invalid"
		bad_prefix_digest["payload_sha256"] = _payload_sha256_v1(sdk, bad_prefix_digest)
		negative_controls["invalid_prefix_source_digest_refused"] = (not interaction_source_valid_v1(
			sdk, bad_prefix_digest
		))
		var interaction_authority := active_source.duplicate(true)
		interaction_authority["physical_acceptance_authority"] = true
		interaction_authority["payload_sha256"] = _payload_sha256_v1(sdk, interaction_authority)
		negative_controls["interaction_claim_promotion_refused"] = (not interaction_source_valid_v1(
			sdk, interaction_authority
		))
		var bad_interaction_digest := active_source.duplicate(true)
		bad_interaction_digest["payload_sha256"] = _filled_sha256_v1("d")
		negative_controls["interaction_digest_mismatch_refused"] = (not interaction_source_valid_v1(
			sdk, bad_interaction_digest
		))

	var positive_count := 0
	for control_value in positive_controls.values():
		positive_count += int(bool(control_value))
	var rejection_count := 0
	for control_value in negative_controls.values():
		rejection_count += int(bool(control_value))
	var receipt := {
		"schema_version": ZERO_WORLD_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok":
		(
			positive_count == positive_controls.size()
			and rejection_count == negative_controls.size()
			and positive_controls.size() == 8
			and negative_controls.size() == 31
		),
		"positive_case_count": positive_count,
		"mutation_rejection_count": rejection_count,
		"positive_controls": positive_controls,
		"negative_controls": negative_controls,
		"failed_or_refused_precondition_is_valid_diagnostic_evidence": true,
		"failed_or_refused_precondition_crosses_release_boundary": false,
		"one_arm_per_process": true,
		"one_world_per_process": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	return receipt


static func nullable_terminal_failure_code_zero_world_v1(sdk: Object) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L10_ZERO_WORLD_SDK_MISSING")
	var parent_id := "0123456789abcdef0123456789abcdef"
	var complete_build := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		BASELINE_ARM_ID,
		"complete",
		null,
		true,
	)
	var failed_code := "phase_timeout:stance_dwell"
	var failed_build := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
		ACTIVE_ARM_ID,
		"failed",
		failed_code,
		false,
	)
	var refused_code := "invalid_observation:nonfinite_state"
	var refused_build := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"cccccccccccccccccccccccccccccccc",
		BASELINE_ARM_ID,
		"refused",
		refused_code,
		false,
	)
	var complete_receipt: Dictionary = complete_build.get("receipt", {})
	var failed_receipt: Dictionary = failed_build.get("receipt", {})
	var refused_receipt: Dictionary = refused_build.get("receipt", {})
	var complete_memory: Dictionary = complete_receipt.get("recovery_memory", {})
	var positive_controls := {
		"runtime_shaped_complete_memory_with_null_failure_code_builds_and_validates":
		(
			bool(complete_build.get("ok", false))
			and precondition_terminal_receipt_valid_v1(sdk, complete_receipt)
		),
		"complete_null_source_is_retained_as_null_inside_nested_recovery_memory":
		(
			complete_memory.has("terminal_failure_code")
			and complete_memory["terminal_failure_code"] == null
		),
		"complete_null_source_projects_to_the_existing_empty_receipt_failure_code":
		(
			typeof(complete_receipt.get("recovery_terminal_failure_code")) == TYPE_STRING
			and complete_receipt.get("recovery_terminal_failure_code") == ""
		),
		"failed_memory_with_nonempty_string_builds_and_validates":
		(
			bool(failed_build.get("ok", false))
			and precondition_terminal_receipt_valid_v1(sdk, failed_receipt)
		),
		"refused_memory_with_nonempty_string_builds_and_validates":
		(
			bool(refused_build.get("ok", false))
			and precondition_terminal_receipt_valid_v1(sdk, refused_receipt)
		),
		"failure_string_is_copied_exactly_without_generic_conversion":
		(
			failed_receipt.get("recovery_terminal_failure_code") == failed_code
			and (
				(failed_receipt.get("recovery_memory", {}) as Dictionary).get(
					"terminal_failure_code"
				)
				== failed_code
			)
			and refused_receipt.get("recovery_terminal_failure_code") == refused_code
		),
	}

	var complete_empty := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"dddddddddddddddddddddddddddddddd",
		BASELINE_ARM_ID,
		"complete",
		"",
		true,
	)
	var complete_nonempty := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
		BASELINE_ARM_ID,
		"complete",
		"invented_failure",
		true,
	)
	var failed_null := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"ffffffffffffffffffffffffffffffff",
		ACTIVE_ARM_ID,
		"failed",
		null,
		false,
	)
	var failed_empty := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"99999999999999999999999999999999",
		ACTIVE_ARM_ID,
		"failed",
		"",
		false,
	)
	var refused_null := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"88888888888888888888888888888888",
		BASELINE_ARM_ID,
		"refused",
		null,
		false,
	)
	var refused_empty := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"77777777777777777777777777777777",
		BASELINE_ARM_ID,
		"refused",
		"",
		false,
	)
	var invalid_type_builds := {
		"boolean_failure_source_refused":
		_zero_world_precondition_build_v1(
			sdk, parent_id, "10101010101010101010101010101010", ACTIVE_ARM_ID, "failed", true, false
		),
		"integer_failure_source_refused":
		_zero_world_precondition_build_v1(
			sdk, parent_id, "20202020202020202020202020202020", ACTIVE_ARM_ID, "failed", 7, false
		),
		"floating_failure_source_refused":
		_zero_world_precondition_build_v1(
			sdk, parent_id, "30303030303030303030303030303030", ACTIVE_ARM_ID, "failed", 7.0, false
		),
		"array_failure_source_refused":
		_zero_world_precondition_build_v1(
			sdk,
			parent_id,
			"40404040404040404040404040404040",
			ACTIVE_ARM_ID,
			"failed",
			["failure"],
			false
		),
		"dictionary_failure_source_refused":
		_zero_world_precondition_build_v1(
			sdk,
			parent_id,
			"50505050505050505050505050505050",
			ACTIVE_ARM_ID,
			"failed",
			{"failure": true},
			false
		),
	}
	var missing_memory := {"phase": "complete", "last_semantic_step": 1.0}
	var missing_step := {
		"memory": missing_memory.duplicate(true),
		"classification": {"stable_stance_gate": true},
		"next_phase": "complete",
	}
	var missing_build := build_precondition_terminal_receipt_v1(
		sdk,
		parent_id,
		"60606060606060606060606060606060",
		BASELINE_ARM_ID,
		"l10-zero-world-missing-source-model",
		1,
		"sporespore_exact_s169_prone_to_standing_controller_v6",
		missing_memory,
		missing_step,
		{"stable_stance_gate": true},
		0,
		0,
		0,
	)

	var projection_mismatch := complete_receipt.duplicate(true)
	projection_mismatch["recovery_terminal_failure_code"] = "invented_failure"
	projection_mismatch["payload_sha256"] = _payload_sha256_v1(sdk, projection_mismatch)
	var nullness_rewrite := complete_receipt.duplicate(true)
	var rewritten_memory: Dictionary = (
		(nullness_rewrite["recovery_memory"] as Dictionary).duplicate(true)
	)
	rewritten_memory["terminal_failure_code"] = ""
	var rewritten_step: Dictionary = (
		(nullness_rewrite["recovery_step_receipt"] as Dictionary).duplicate(true)
	)
	rewritten_step["memory"] = rewritten_memory.duplicate(true)
	nullness_rewrite["recovery_memory"] = rewritten_memory
	nullness_rewrite["recovery_step_receipt"] = rewritten_step
	nullness_rewrite["recovery_memory_sha256"] = _canonical_sha256_v1(sdk, rewritten_memory)
	nullness_rewrite["recovery_step_receipt_sha256"] = _canonical_sha256_v1(sdk, rewritten_step)
	nullness_rewrite["payload_sha256"] = _payload_sha256_v1(sdk, nullness_rewrite)

	var phase_presence_mismatch := failed_receipt.duplicate(true)
	var mismatched_memory: Dictionary = (
		(phase_presence_mismatch["recovery_memory"] as Dictionary).duplicate(true)
	)
	mismatched_memory["phase"] = "complete"
	var mismatched_step: Dictionary = (
		(phase_presence_mismatch["recovery_step_receipt"] as Dictionary).duplicate(true)
	)
	mismatched_step["memory"] = mismatched_memory.duplicate(true)
	mismatched_step["next_phase"] = "complete"
	phase_presence_mismatch["recovery_memory"] = mismatched_memory
	phase_presence_mismatch["recovery_step_receipt"] = mismatched_step
	phase_presence_mismatch["recovery_terminal_phase"] = "complete"
	phase_presence_mismatch["disposition"] = DISPOSITION_COMPLETE
	phase_presence_mismatch["stable_four_foot_stance"] = true
	phase_presence_mismatch["recovery_memory_sha256"] = _canonical_sha256_v1(sdk, mismatched_memory)
	phase_presence_mismatch["recovery_step_receipt_sha256"] = _canonical_sha256_v1(
		sdk, mismatched_step
	)
	phase_presence_mismatch["payload_sha256"] = _payload_sha256_v1(sdk, phase_presence_mismatch)
	var digest_mismatch := complete_receipt.duplicate(true)
	digest_mismatch["recovery_memory_sha256"] = _filled_sha256_v1("0")
	digest_mismatch["payload_sha256"] = _payload_sha256_v1(sdk, digest_mismatch)

	var negative_controls := {
		"complete_memory_with_empty_string_source_refused":
		not bool(complete_empty.get("ok", true)),
		"complete_memory_with_nonempty_string_source_refused":
		not bool(complete_nonempty.get("ok", true)),
		"failed_memory_with_null_source_refused": not bool(failed_null.get("ok", true)),
		"failed_memory_with_empty_string_source_refused": not bool(failed_empty.get("ok", true)),
		"refused_memory_with_null_source_refused": not bool(refused_null.get("ok", true)),
		"refused_memory_with_empty_string_source_refused": not bool(refused_empty.get("ok", true)),
		"missing_failure_source_refused": not bool(missing_build.get("ok", true)),
		"receipt_projection_mismatch_refused":
		not precondition_terminal_receipt_valid_v1(sdk, projection_mismatch),
		"nested_memory_nullness_rewrite_refused":
		not precondition_terminal_receipt_valid_v1(sdk, nullness_rewrite),
		"phase_failure_presence_invariant_mismatch_refused":
		not precondition_terminal_receipt_valid_v1(sdk, phase_presence_mismatch),
		"digest_mismatch_refused": not precondition_terminal_receipt_valid_v1(sdk, digest_mismatch),
	}
	for control_id in invalid_type_builds:
		negative_controls[control_id] = not bool(
			(invalid_type_builds[control_id] as Dictionary).get("ok", true)
		)
	var positive_count := 0
	for value in positive_controls.values():
		positive_count += int(bool(value))
	var rejection_count := 0
	for value in negative_controls.values():
		rejection_count += int(bool(value))
	return {
		"schema_version": NULLABLE_TERMINAL_FAILURE_ZERO_WORLD_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": NULLABLE_TERMINAL_FAILURE_REPAIR_ID,
		"ok":
		(
			positive_count == positive_controls.size()
			and positive_controls.size() == 6
			and rejection_count == negative_controls.size()
			and negative_controls.size() == 16
		),
		"positive_control_count": positive_count,
		"mutation_rejection_count": rejection_count,
		"positive_controls": positive_controls,
		"negative_controls": negative_controls,
		"generic_string_conversion_used": false,
		"nested_recovery_memory_mutated": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func precondition_release_owner_source_zero_world_v1(sdk: Object) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L11_ZERO_WORLD_SDK_MISSING")
	var parent_id := "0123456789abcdef0123456789abcdef"
	var baseline_build := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		BASELINE_ARM_ID,
		"complete",
		null,
		true,
	)
	var active_build := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
		ACTIVE_ARM_ID,
		"complete",
		null,
		true,
	)
	var failed_build := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"cccccccccccccccccccccccccccccccc",
		ACTIVE_ARM_ID,
		"failed",
		"phase_timeout:stance_dwell",
		false,
	)
	var refused_build := _zero_world_precondition_build_v1(
		sdk,
		parent_id,
		"dddddddddddddddddddddddddddddddd",
		BASELINE_ARM_ID,
		"refused",
		"precondition_source_refused",
		false,
	)
	var baseline_terminal: Dictionary = baseline_build.get("receipt", {})
	var active_terminal: Dictionary = active_build.get("receipt", {})
	var baseline_step: Dictionary = baseline_terminal.get("recovery_step_receipt", {})
	var baseline_owner_build := precondition_release_owner_source_projection_v1(
		sdk, baseline_terminal
	)
	var active_owner_build := precondition_release_owner_source_projection_v1(sdk, active_terminal)
	var baseline_source: Dictionary = baseline_owner_build.get("source", {})
	var active_source: Dictionary = active_owner_build.get("source", {})
	var release_step := int(baseline_terminal.get("completed_global_semantic_step", -1)) + 1
	var readback := _zero_world_motor_readback_v1(release_step)
	var raw_source_ledger := (
		LocomotionFacade
		. no_actuation_ledger_application_intent_v1(
			sdk,
			release_step,
			"precondition_recovery",
			"none",
			null,
			true,
			baseline_step,
			readback,
		)
	)
	var projected_ledger := (
		LocomotionFacade
		. no_actuation_ledger_application_intent_v1(
			sdk,
			release_step,
			"precondition_recovery",
			"none",
			null,
			true,
			baseline_source,
			readback,
		)
	)
	var baseline_release := _zero_world_release_build_v1(sdk, baseline_terminal)
	var active_release := _zero_world_release_build_v1(sdk, active_terminal)
	var baseline_release_receipt: Dictionary = baseline_release.get("receipt", {})
	var outcome_keys_absent := true
	for key in LocomotionFacade.OUTCOME_DERIVED_KEYS:
		outcome_keys_absent = outcome_keys_absent and not baseline_source.has(key)
	var positive_controls := {
		"runtime_shaped_complete_terminal_retained_unchanged":
		(
			bool(baseline_build.get("ok", false))
			and bool(baseline_step.get("physical_result", false))
			and baseline_terminal.get("recovery_step_receipt") == baseline_step
		),
		"baseline_complete_terminal_projects_exact_owner_source":
		(
			bool(baseline_owner_build.get("ok", false))
			and precondition_release_owner_source_projection_valid_v1(
				sdk, baseline_source, baseline_terminal
			)
		),
		"active_complete_terminal_projects_exact_owner_source":
		(
			bool(active_owner_build.get("ok", false))
			and precondition_release_owner_source_projection_valid_v1(
				sdk, active_source, active_terminal
			)
		),
		"projection_binds_terminal_memory_and_step_digests":
		(
			(
				String(baseline_source.get("precondition_terminal_receipt_sha256", ""))
				== String(baseline_terminal.get("payload_sha256", ""))
			)
			and (
				String(baseline_source.get("recovery_memory_sha256", ""))
				== String(baseline_terminal.get("recovery_memory_sha256", ""))
			)
			and (
				String(baseline_source.get("recovery_step_receipt_sha256", ""))
				== String(baseline_terminal.get("recovery_step_receipt_sha256", ""))
			)
		),
		"projection_contains_no_outcome_keys": outcome_keys_absent,
		"no_actuation_ledger_accepts_exact_projection": bool(projected_ledger.get("ok", false)),
		"both_complete_roles_cross_one_release_step":
		bool(baseline_release.get("ok", false)) and bool(active_release.get("ok", false)),
		"release_retains_full_terminal_and_narrow_ledger_source":
		(
			baseline_release_receipt.get("precondition_terminal_receipt") == baseline_terminal
			and (
				(baseline_release_receipt.get("ledger_application_intent", {}) as Dictionary).get(
					"owner_source_receipt"
				)
				== baseline_source
			)
		),
	}
	var negative_controls := {
		"raw_runtime_shaped_recovery_step_refused":
		(
			not bool(raw_source_ledger.get("ok", true))
			and (
				String(raw_source_ledger.get("failure_code", ""))
				== "QSDK_R10F_NO_ACTUATION_LEDGER_INPUT_INVALID"
			)
		),
		"failed_terminal_source_refused":
		not bool(
			(
				precondition_release_owner_source_projection_v1(
					sdk, failed_build.get("receipt", {})
				)
				. get("ok", true)
			)
		),
		"refused_terminal_source_refused":
		not bool(
			(
				precondition_release_owner_source_projection_v1(
					sdk, refused_build.get("receipt", {})
				)
				. get("ok", true)
			)
		),
	}
	if not baseline_source.is_empty():
		var injected_physical_result := baseline_source.duplicate(true)
		injected_physical_result["physical_result"] = true
		injected_physical_result["payload_sha256"] = _payload_sha256_v1(
			sdk, injected_physical_result
		)
		negative_controls["injected_physical_result_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, injected_physical_result, baseline_terminal
		))
		var injected_stance_gate := baseline_source.duplicate(true)
		injected_stance_gate["stable_stance_gate"] = true
		injected_stance_gate["payload_sha256"] = _payload_sha256_v1(sdk, injected_stance_gate)
		negative_controls["injected_stable_stance_gate_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, injected_stance_gate, baseline_terminal
		))
		var injected_energy := baseline_source.duplicate(true)
		injected_energy["energy_balance_residual_j"] = 0.0
		injected_energy["payload_sha256"] = _payload_sha256_v1(sdk, injected_energy)
		negative_controls["injected_energy_balance_residual_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, injected_energy, baseline_terminal
		))
		var missing_terminal_digest := baseline_source.duplicate(true)
		missing_terminal_digest.erase("precondition_terminal_receipt_sha256")
		negative_controls["missing_terminal_digest_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, missing_terminal_digest, baseline_terminal
		))
		var wrong_terminal_digest := baseline_source.duplicate(true)
		wrong_terminal_digest["precondition_terminal_receipt_sha256"] = _filled_sha256_v1("1")
		wrong_terminal_digest["payload_sha256"] = _payload_sha256_v1(sdk, wrong_terminal_digest)
		negative_controls["wrong_terminal_digest_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, wrong_terminal_digest, baseline_terminal
		))
		var wrong_memory_digest := baseline_source.duplicate(true)
		wrong_memory_digest["recovery_memory_sha256"] = _filled_sha256_v1("2")
		wrong_memory_digest["payload_sha256"] = _payload_sha256_v1(sdk, wrong_memory_digest)
		negative_controls["wrong_recovery_memory_digest_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, wrong_memory_digest, baseline_terminal
		))
		var wrong_step_digest := baseline_source.duplicate(true)
		wrong_step_digest["recovery_step_receipt_sha256"] = _filled_sha256_v1("3")
		wrong_step_digest["payload_sha256"] = _payload_sha256_v1(sdk, wrong_step_digest)
		negative_controls["wrong_recovery_step_digest_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, wrong_step_digest, baseline_terminal
		))
		var wrong_parent := baseline_source.duplicate(true)
		wrong_parent["parent_attempt_id"] = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
		wrong_parent["payload_sha256"] = _payload_sha256_v1(sdk, wrong_parent)
		negative_controls["wrong_parent_identity_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, wrong_parent, baseline_terminal
		))
		var wrong_child := baseline_source.duplicate(true)
		wrong_child["child_attempt_id"] = "ffffffffffffffffffffffffffffffff"
		wrong_child["payload_sha256"] = _payload_sha256_v1(sdk, wrong_child)
		negative_controls["wrong_child_identity_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, wrong_child, baseline_terminal
		))
		var wrong_arm := baseline_source.duplicate(true)
		wrong_arm["arm_id"] = ACTIVE_ARM_ID
		wrong_arm["payload_sha256"] = _payload_sha256_v1(sdk, wrong_arm)
		negative_controls["wrong_arm_identity_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, wrong_arm, baseline_terminal
		))
		var wrong_model := baseline_source.duplicate(true)
		wrong_model["model_instance_id"] = "foreign-model"
		wrong_model["payload_sha256"] = _payload_sha256_v1(sdk, wrong_model)
		negative_controls["wrong_model_identity_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, wrong_model, baseline_terminal
		))
		var wrong_terminal_step := baseline_source.duplicate(true)
		wrong_terminal_step["completed_terminal_global_semantic_step"] = 2
		wrong_terminal_step["payload_sha256"] = _payload_sha256_v1(sdk, wrong_terminal_step)
		negative_controls["wrong_terminal_step_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, wrong_terminal_step, baseline_terminal
		))
		var wrong_release_step := baseline_source.duplicate(true)
		wrong_release_step["release_global_semantic_step"] = 3
		wrong_release_step["payload_sha256"] = _payload_sha256_v1(sdk, wrong_release_step)
		negative_controls["wrong_release_step_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, wrong_release_step, baseline_terminal
		))
		var outcome_correction := baseline_source.duplicate(true)
		outcome_correction["outcome_derived_correction"] = true
		outcome_correction["payload_sha256"] = _payload_sha256_v1(sdk, outcome_correction)
		negative_controls["outcome_derived_correction_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, outcome_correction, baseline_terminal
		))
		var physical_authority := baseline_source.duplicate(true)
		physical_authority["physical_acceptance_authority"] = true
		physical_authority["payload_sha256"] = _payload_sha256_v1(sdk, physical_authority)
		negative_controls["physical_acceptance_authority_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, physical_authority, baseline_terminal
		))
		var release_authority := baseline_source.duplicate(true)
		release_authority["release_authority"] = true
		release_authority["payload_sha256"] = _payload_sha256_v1(sdk, release_authority)
		negative_controls["release_authority_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, release_authority, baseline_terminal
		))
		var bad_payload_digest := baseline_source.duplicate(true)
		bad_payload_digest["payload_sha256"] = _filled_sha256_v1("4")
		negative_controls["projection_payload_digest_mismatch_refused"] = not (precondition_release_owner_source_projection_valid_v1(
			sdk, bad_payload_digest, baseline_terminal
		))
	if not baseline_release_receipt.is_empty():
		var foreign_owner_release := baseline_release_receipt.duplicate(true)
		var foreign_ledger: Dictionary = (
			(foreign_owner_release["ledger_application_intent"] as Dictionary).duplicate(true)
		)
		foreign_ledger["owner_source_receipt"] = {"foreign_source": true}
		foreign_ledger["owner_source_receipt_sha256"] = _canonical_sha256_v1(
			sdk, foreign_ledger["owner_source_receipt"]
		)
		foreign_owner_release["ledger_application_intent"] = foreign_ledger
		foreign_owner_release["ledger_application_intent_sha256"] = _canonical_sha256_v1(
			sdk, foreign_ledger
		)
		foreign_owner_release["payload_sha256"] = _payload_sha256_v1(sdk, foreign_owner_release)
		negative_controls["foreign_release_owner_source_refused"] = not (precondition_release_receipt_valid_v1(
			sdk, foreign_owner_release
		))
		var owner_digest_mismatch := baseline_release_receipt.duplicate(true)
		var mismatch_ledger: Dictionary = (
			(owner_digest_mismatch["ledger_application_intent"] as Dictionary).duplicate(true)
		)
		mismatch_ledger["owner_source_receipt_sha256"] = _filled_sha256_v1("5")
		owner_digest_mismatch["ledger_application_intent"] = mismatch_ledger
		owner_digest_mismatch["ledger_application_intent_sha256"] = _canonical_sha256_v1(
			sdk, mismatch_ledger
		)
		owner_digest_mismatch["payload_sha256"] = _payload_sha256_v1(sdk, owner_digest_mismatch)
		negative_controls["release_owner_digest_mismatch_refused"] = not (precondition_release_receipt_valid_v1(
			sdk, owner_digest_mismatch
		))
	var positive_count := 0
	for value in positive_controls.values():
		positive_count += int(bool(value))
	var rejection_count := 0
	for value in negative_controls.values():
		rejection_count += int(bool(value))
	return {
		"schema_version": RELEASE_OWNER_SOURCE_ZERO_WORLD_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": SUCCESSOR_REPAIR_ID,
		"ok":
		(
			positive_count == positive_controls.size()
			and positive_controls.size() == 8
			and rejection_count == negative_controls.size()
			and negative_controls.size() == 22
		),
		"positive_control_count": positive_count,
		"mutation_rejection_count": rejection_count,
		"positive_controls": positive_controls,
		"negative_controls": negative_controls,
		"raw_outcome_bearing_source_accepted": false,
		"broad_outcome_guard_changed": false,
		"full_terminal_source_mutated": false,
		"full_recovery_step_source_mutated": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _zero_world_precondition_build_v1(
	sdk: Object,
	parent_id: String,
	child_id: String,
	arm_id: String,
	phase: String,
	failure_code: Variant,
	stable_stance: bool,
) -> Dictionary:
	var memory := {
		"phase": phase,
		"last_semantic_step": 1.0,
		"terminal_failure_code": failure_code,
	}
	var classification := {"stable_stance_gate": stable_stance}
	var step := {
		"memory": memory.duplicate(true),
		"classification": classification.duplicate(true),
		"next_phase": phase,
		"controller_implemented": true,
		"controller_command_emitted": false,
		"physical_result": stable_stance,
		"physical_threshold_authority": true,
		"post_step_observation_only": true,
		"prone_to_standing_claimed": stable_stance,
		"support_status": "supported_exact",
	}
	return build_precondition_terminal_receipt_v1(
		sdk,
		parent_id,
		child_id,
		arm_id,
		"l9-zero-world-%s-model" % arm_id,
		1,
		"sporespore_exact_s169_prone_to_standing_controller_v6",
		memory,
		step,
		classification,
		0,
		0,
		0,
	)


static func _zero_world_release_build_v1(
	sdk: Object,
	terminal: Dictionary,
) -> Dictionary:
	if terminal.is_empty():
		return _failure("QSDK_R10F_L9_ZERO_WORLD_RELEASE_TERMINAL_MISSING")
	var global_step := int(terminal.get("completed_global_semantic_step", -1)) + 1
	var configuration := _zero_world_motor_configuration_v1(global_step)
	var readback := _zero_world_motor_readback_v1(global_step)
	var owner_source_build := precondition_release_owner_source_projection_v1(sdk, terminal)
	if not bool(owner_source_build.get("ok", false)):
		return owner_source_build
	var ledger := (
		LocomotionFacade
		. no_actuation_ledger_application_intent_v1(
			sdk,
			global_step,
			"precondition_recovery",
			"none",
			null,
			true,
			owner_source_build.get("source", {}),
			readback,
		)
	)
	if not bool(ledger.get("ok", false)):
		return ledger
	return build_precondition_release_receipt_v1(
		sdk,
		terminal,
		global_step,
		configuration,
		readback,
		ledger,
	)


static func _zero_world_motor_configuration_v1(global_step: int) -> Dictionary:
	var rows: Array = []
	for joint_id_value in LocomotionFacade.JOINT_IDS:
		(
			rows
			. append(
				{
					"joint_id": String(joint_id_value),
					"motor_enabled": false,
					"motor_target_velocity_rad_s": 0.0,
				}
			)
		)
	return {
		"schema_version": LocomotionFacade.MOTOR_CONFIGURATION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": global_step,
		"reason": "l9_zero_world_motors_disabled",
		"motor_enabled": false,
		"ordered_joint_receipts": rows,
		"motor_configuration_write_count": LocomotionFacade.JOINT_IDS.size() * 2,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"body_impulse_write_count": 0,
		"solver_reset_count": 0,
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _zero_world_motor_readback_v1(global_step: int) -> Dictionary:
	var rows: Array = []
	for joint_id_value in LocomotionFacade.JOINT_IDS:
		var joint_id := String(joint_id_value)
		(
			rows
			. append(
				{
					"actuator_id": "%s_motor" % joint_id,
					"joint_id": joint_id,
					"motor_enabled": false,
					"motor_target_velocity_rad_s": 0.0,
					"motor_maximum_impulse_nms": 0.5,
				}
			)
		)
	return {
		"schema_version": LocomotionFacade.MOTOR_POPULATION_READBACK_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": global_step,
		"reason": "l9_zero_world_pre_solver_readback",
		"expected_motor_enabled": false,
		"ordered_joint_readbacks": rows,
		"motor_enabled_count": 0,
		"zero_target_velocity_count": LocomotionFacade.JOINT_IDS.size(),
		"native_readback_count": LocomotionFacade.JOINT_IDS.size() * 3,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"body_impulse_write_count": 0,
		"solver_reset_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _finite_vector_v1(value: Variant) -> Array:
	if not (value is Array) or (value as Array).size() != 3:
		return []
	var result: Array = []
	for component_value in value as Array:
		if typeof(component_value) not in [TYPE_FLOAT, TYPE_INT]:
			return []
		var component := float(component_value)
		if not is_finite(component):
			return []
		result.append(component)
	return result


static func _subtract_v1(left: Array, right: Array) -> Array:
	return [
		float(left[0]) - float(right[0]),
		float(left[1]) - float(right[1]),
		float(left[2]) - float(right[2]),
	]


static func _dot_v1(left: Array, right: Array) -> float:
	return (
		float(left[0]) * float(right[0])
		+ float(left[1]) * float(right[1])
		+ float(left[2]) * float(right[2])
	)


static func _norm_v1(value: Array) -> float:
	return sqrt(_dot_v1(value, value))


static func _components_close_v1(left: Array, right: Array, allowance: float) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if absf(float(left[index]) - float(right[index])) > allowance:
			return false
	return true


static func _lower_hex_exact_v1(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _valid_sha256_v1(value: String) -> bool:
	return value.begins_with("sha256:") and _lower_hex_exact_v1(value.substr(7), 64)


static func _canonical_sha256_v1(sdk: Object, value: Variant) -> String:
	if sdk == null:
		return ""
	var digest := String(RecoveryRuntimeScript.canonicalize(sdk, value).get("sha256", ""))
	return digest if _valid_sha256_v1(digest) else ""


static func _payload_sha256_v1(sdk: Object, value: Dictionary) -> String:
	var payload := value.duplicate(true)
	payload.erase("payload_sha256")
	return _canonical_sha256_v1(sdk, payload)


static func _filled_sha256_v1(fill: String) -> String:
	return "sha256:" + fill.repeat(64)


static func _keys_exact_v1(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10f_l9_process_isolated_child_contract_failure_v1",
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
