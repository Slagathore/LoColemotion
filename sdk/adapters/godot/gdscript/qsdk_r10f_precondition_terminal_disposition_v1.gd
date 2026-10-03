class_name SporeQsdkR10fPreconditionTerminalDispositionV1
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-file-lines

## Pure QSDK-R10F-L7 authority for retaining what each arm actually reported
## at the last completed precondition frame. A failed or refused arm stops the
## route without demanding a same-frame terminal from its peer. A successful
## complete arm remains bound to its existing L6 pair-barrier source.

const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const EnergyInitializer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd"
)
const Orchestrator := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd"
)
const PreconditionPairBarrier := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_precondition_pair_barrier_v1.gd"
)

const GATE_ID := "QSDK-R10F"
const REPAIR_ID := "QSDK-R10F-L7"
const SUCCESSOR_REPAIR_ID := "QSDK-R10F-L8"
const DISPOSITION_SCHEMA := "sporespore_qsdk_r10f_precondition_terminal_disposition_v1"
const ABORT_POPULATION_SCHEMA := "sporespore_qsdk_r10f_precondition_terminal_disposition_abort_population_v1"
const ZERO_WORLD_SCHEMA := "sporespore_qsdk_r10f_precondition_terminal_disposition_zero_world_v1"
const NATIVE_STEP_DOMAIN_ZERO_WORLD_SCHEMA := "sporespore_qsdk_r10f_integer_valued_native_step_domain_zero_world_v1"
const FAILURE_CODE := "QSDK_R10F_PRECONDITION_TERMINAL_DISPOSITION_RETAINED"
const MINIMUM_NATIVE_STEP := 1
const MAXIMUM_NATIVE_STEP := 3842

const DISPOSITION_COMPLETE := "complete_source_retained"
const DISPOSITION_FAILED := "failed_source_retained"
const DISPOSITION_REFUSED := "refused_source_retained"
const DISPOSITION_NONTERMINAL := "nonterminal_last_completed_state_retained"
const DISPOSITIONS := [
	DISPOSITION_COMPLETE,
	DISPOSITION_FAILED,
	DISPOSITION_REFUSED,
	DISPOSITION_NONTERMINAL,
]
const FAILURE_DISPOSITIONS := [DISPOSITION_FAILED, DISPOSITION_REFUSED]
const ARM_ORDER := [
	EnergyInitializer.BASELINE_ARM_ID,
	EnergyInitializer.ACTIVE_ARM_ID,
]

const BUILD_INPUT_KEYS := [
	"arm_id",
	"global_semantic_step",
	"orchestrator_phase",
	"route_terminal",
	"route_terminal_reason",
	"recovery_controller_id",
	"recovery_terminal",
	"recovery_terminal_phase",
	"recovery_terminal_failure_code",
	"recovery_step_global_semantic_step",
	"recovery_memory",
	"recovery_step_receipt",
	"recovery_classification",
	"body_transform_write_count",
	"body_velocity_write_count",
	"solver_reset_count",
]
const DISPOSITION_KEYS := [
	"schema_version",
	"gate_id",
	"repair_id",
	"attempt_id",
	"arm_id",
	"model_instance_id",
	"global_semantic_step",
	"disposition",
	"orchestrator_phase",
	"route_terminal",
	"route_terminal_reason",
	"recovery_controller_id",
	"recovery_terminal",
	"recovery_terminal_phase",
	"recovery_terminal_failure_code",
	"recovery_step_global_semantic_step",
	"recovery_memory",
	"recovery_memory_sha256",
	"recovery_step_receipt",
	"recovery_step_receipt_sha256",
	"recovery_classification",
	"recovery_classification_sha256",
	"pair_ready",
	"pair_terminal_source_sha256",
	"pair_state_sha256",
	"source_measurement",
	"outcome_derived_correction",
	"body_transform_write_count",
	"body_velocity_write_count",
	"solver_reset_count",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]
const ABORT_POPULATION_KEYS := [
	"schema_version",
	"gate_id",
	"repair_id",
	"attempt_id",
	"failure_code",
	"global_semantic_step",
	"ordered_arm_ids",
	"disposition_by_arm",
	"disposition_sha256_by_arm",
	"failing_arm_ids",
	"failing_disposition_by_arm",
	"pair_state_sha256",
	"retained_global_lockstep_solver_frame_count",
	"retained_worker_solver_step_count",
	"expected_worker_solver_step_count_at_stop",
	"post_failure_additional_solver_step_count",
	"next_solver_step_permitted",
	"generic_terminal_frame_lockstep_failure_label_used",
	"nonfailing_peer_last_completed_state_retained",
	"independent_closure_validation_required",
	"summary_boolean_without_independent_validation",
	"source_measurement",
	"outcome_derived_correction",
	"model_construction_count",
	"world_attempt_count",
	"world_build_count",
	"scene_tree_insertion_count",
	"native_readback_count",
	"solver_step_count",
	"physics_state_modified",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]


static func build_disposition_v1(
	sdk: Object,
	pair_state: Dictionary,
	fields: Dictionary,
) -> Dictionary:
	if (
		sdk == null
		or not PreconditionPairBarrier.state_valid_v1(sdk, pair_state)
		or bool(pair_state.get("released", false))
		or not _keys_exact_v1(fields, BUILD_INPUT_KEYS)
	):
		return _failure("QSDK_R10F_L7_DISPOSITION_INPUT_INVALID")
	var arm_id := String(fields.get("arm_id", ""))
	var global_step_value: Variant = fields.get("global_semantic_step")
	var recovery_step_value: Variant = fields.get("recovery_step_receipt")
	var memory_value: Variant = fields.get("recovery_memory")
	var classification_value: Variant = fields.get("recovery_classification")
	if (
		arm_id not in ARM_ORDER
		or typeof(global_step_value) != TYPE_INT
		or not (recovery_step_value is Dictionary)
		or not (memory_value is Dictionary)
		or not (classification_value is Dictionary)
	):
		return _failure("QSDK_R10F_L7_DISPOSITION_SOURCE_SHAPE_INVALID")
	var ready := bool((pair_state["ready_by_arm"] as Dictionary).get(arm_id, false))
	var route_terminal := bool(fields.get("route_terminal", false))
	var recovery_terminal := bool(fields.get("recovery_terminal", false))
	var recovery_terminal_phase := String(fields.get("recovery_terminal_phase", ""))
	var disposition := DISPOSITION_NONTERMINAL
	if ready:
		disposition = DISPOSITION_COMPLETE
	elif route_terminal:
		disposition = (
			DISPOSITION_REFUSED
			if recovery_terminal and recovery_terminal_phase == "refused"
			else DISPOSITION_FAILED
		)
	var terminal_source_sha := String(
		(pair_state["terminal_source_sha256_by_arm"] as Dictionary).get(arm_id, "")
	)
	var recovery_memory: Dictionary = memory_value
	var recovery_step: Dictionary = recovery_step_value
	var classification: Dictionary = classification_value
	var receipt := {
		"schema_version": DISPOSITION_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"attempt_id": String(pair_state["attempt_id"]),
		"arm_id": arm_id,
		"model_instance_id": String((pair_state["model_instance_id_by_arm"] as Dictionary)[arm_id]),
		"global_semantic_step": int(global_step_value),
		"disposition": disposition,
		"orchestrator_phase": String(fields.get("orchestrator_phase", "")),
		"route_terminal": route_terminal,
		"route_terminal_reason": String(fields.get("route_terminal_reason", "")),
		"recovery_controller_id": String(fields.get("recovery_controller_id", "")),
		"recovery_terminal": recovery_terminal,
		"recovery_terminal_phase": recovery_terminal_phase,
		"recovery_terminal_failure_code": String(fields.get("recovery_terminal_failure_code", "")),
		"recovery_step_global_semantic_step":
		int(fields.get("recovery_step_global_semantic_step", -1)),
		"recovery_memory": recovery_memory.duplicate(true),
		"recovery_memory_sha256": _canonical_sha256_v1(sdk, recovery_memory),
		"recovery_step_receipt": recovery_step.duplicate(true),
		"recovery_step_receipt_sha256": _canonical_sha256_v1(sdk, recovery_step),
		"recovery_classification": classification.duplicate(true),
		"recovery_classification_sha256": _canonical_sha256_v1(sdk, classification),
		"pair_ready": ready,
		"pair_terminal_source_sha256": terminal_source_sha,
		"pair_state_sha256": String(pair_state["payload_sha256"]),
		"source_measurement": true,
		"outcome_derived_correction": false,
		"body_transform_write_count": int(fields.get("body_transform_write_count", -1)),
		"body_velocity_write_count": int(fields.get("body_velocity_write_count", -1)),
		"solver_reset_count": int(fields.get("solver_reset_count", -1)),
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	receipt["payload_sha256"] = _payload_sha256_v1(sdk, receipt)
	if not disposition_valid_v1(sdk, receipt, pair_state, arm_id, int(global_step_value)):
		return _failure("QSDK_R10F_L7_DISPOSITION_BUILD_INVALID", {"receipt": receipt})
	return {
		"schema_version": "sporespore_qsdk_r10f_precondition_terminal_disposition_build_v1",
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": true,
		"disposition": receipt,
		"disposition_sha256": String(receipt["payload_sha256"]),
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


static func disposition_valid_v1(
	sdk: Object,
	receipt: Dictionary,
	pair_state: Dictionary,
	expected_arm_id: String,
	expected_global_step: int,
) -> bool:
	if (
		sdk == null
		or not PreconditionPairBarrier.state_valid_v1(sdk, pair_state)
		or bool(pair_state.get("released", false))
		or not _keys_exact_v1(receipt, DISPOSITION_KEYS)
		or expected_arm_id not in ARM_ORDER
		or String(receipt.get("schema_version", "")) != DISPOSITION_SCHEMA
		or String(receipt.get("gate_id", "")) != GATE_ID
		or String(receipt.get("repair_id", "")) != REPAIR_ID
		or String(receipt.get("attempt_id", "")) != String(pair_state.get("attempt_id", ""))
		or String(receipt.get("arm_id", "")) != expected_arm_id
		or (
			String(receipt.get("model_instance_id", ""))
			!= String(
				(pair_state["model_instance_id_by_arm"] as Dictionary).get(expected_arm_id, "")
			)
		)
		or typeof(receipt.get("global_semantic_step")) != TYPE_INT
		or int(receipt.get("global_semantic_step")) != expected_global_step
		or expected_global_step < 1
		or expected_global_step != int(pair_state.get("last_completed_global_semantic_step", -1))
		or expected_global_step != int(pair_state.get("planned_global_semantic_step", -2))
		or String(receipt.get("disposition", "")) not in DISPOSITIONS
		or String(receipt.get("recovery_controller_id", "")).is_empty()
		or typeof(receipt.get("route_terminal")) != TYPE_BOOL
		or typeof(receipt.get("recovery_terminal")) != TYPE_BOOL
		or typeof(receipt.get("recovery_step_global_semantic_step")) != TYPE_INT
		or int(receipt.get("recovery_step_global_semantic_step")) < 1
		or int(receipt.get("recovery_step_global_semantic_step")) > expected_global_step
		or not (receipt.get("recovery_memory") is Dictionary)
		or not (receipt.get("recovery_step_receipt") is Dictionary)
		or not (receipt.get("recovery_classification") is Dictionary)
		or typeof(receipt.get("pair_ready")) != TYPE_BOOL
		or typeof(receipt.get("source_measurement")) != TYPE_BOOL
		or not bool(receipt.get("source_measurement"))
		or typeof(receipt.get("outcome_derived_correction")) != TYPE_BOOL
		or bool(receipt.get("outcome_derived_correction"))
		or typeof(receipt.get("body_transform_write_count")) != TYPE_INT
		or int(receipt.get("body_transform_write_count")) != 0
		or typeof(receipt.get("body_velocity_write_count")) != TYPE_INT
		or int(receipt.get("body_velocity_write_count")) != 0
		or typeof(receipt.get("solver_reset_count")) != TYPE_INT
		or int(receipt.get("solver_reset_count")) != 0
		or typeof(receipt.get("physical_acceptance_authority")) != TYPE_BOOL
		or bool(receipt.get("physical_acceptance_authority"))
		or typeof(receipt.get("release_authority")) != TYPE_BOOL
		or bool(receipt.get("release_authority"))
	):
		return false
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
		or not integer_valued_native_step_valid_v1(
			memory.get("last_semantic_step"),
			int(receipt.get("recovery_step_global_semantic_step")),
		)
		or String(step.get("next_phase", "")) != String(memory.get("phase", ""))
		or not _digest_valid_v1(String(receipt.get("recovery_memory_sha256", "")))
		or (String(receipt.get("recovery_memory_sha256", "")) != _canonical_sha256_v1(sdk, memory))
		or not _digest_valid_v1(String(receipt.get("recovery_step_receipt_sha256", "")))
		or (
			String(receipt.get("recovery_step_receipt_sha256", ""))
			!= _canonical_sha256_v1(sdk, step)
		)
		or not _digest_valid_v1(String(receipt.get("recovery_classification_sha256", "")))
		or (
			String(receipt.get("recovery_classification_sha256", ""))
			!= _canonical_sha256_v1(sdk, classification)
		)
		or (
			String(receipt.get("pair_state_sha256", ""))
			!= String(pair_state.get("payload_sha256", ""))
		)
		or String(receipt.get("payload_sha256", "")) != _payload_sha256_v1(sdk, receipt)
	):
		return false
	var ready := bool((pair_state["ready_by_arm"] as Dictionary).get(expected_arm_id, false))
	var expected_source_sha := String(
		(pair_state["terminal_source_sha256_by_arm"] as Dictionary).get(expected_arm_id, "")
	)
	if (
		bool(receipt.get("pair_ready")) != ready
		or String(receipt.get("pair_terminal_source_sha256", "")) != expected_source_sha
	):
		return false
	var disposition := String(receipt["disposition"])
	var orchestrator_phase := String(receipt.get("orchestrator_phase", ""))
	var route_terminal := bool(receipt["route_terminal"])
	var route_reason := String(receipt.get("route_terminal_reason", ""))
	var recovery_terminal := bool(receipt["recovery_terminal"])
	var recovery_phase := String(receipt.get("recovery_terminal_phase", ""))
	var recovery_failure := String(receipt.get("recovery_terminal_failure_code", ""))
	if route_terminal != (orchestrator_phase == Orchestrator.PHASE_FAILED):
		return false
	if route_terminal != (not route_reason.is_empty()):
		return false
	if recovery_terminal:
		if (
			recovery_phase not in ["complete", "failed", "refused"]
			or String(memory.get("phase", "")) != recovery_phase
			or ((recovery_phase == "complete") != recovery_failure.is_empty())
		):
			return false
	else:
		if (
			not recovery_phase.is_empty()
			or not recovery_failure.is_empty()
			or String(memory.get("phase", "")) in ["complete", "failed", "refused"]
		):
			return false
	match disposition:
		DISPOSITION_COMPLETE:
			return _complete_disposition_valid_v1(receipt, pair_state, expected_arm_id)
		DISPOSITION_FAILED:
			return (
				not ready
				and route_terminal
				and orchestrator_phase == Orchestrator.PHASE_FAILED
				and (
					(
						recovery_terminal
						and recovery_phase == "failed"
						and not recovery_failure.is_empty()
						and route_reason == recovery_failure
					)
					or (not recovery_terminal and not route_reason.is_empty())
				)
			)
		DISPOSITION_REFUSED:
			return (
				not ready
				and route_terminal
				and orchestrator_phase == Orchestrator.PHASE_FAILED
				and recovery_terminal
				and recovery_phase == "refused"
				and not recovery_failure.is_empty()
				and route_reason == recovery_failure
			)
		DISPOSITION_NONTERMINAL:
			return (
				not ready
				and not route_terminal
				and orchestrator_phase == Orchestrator.PHASE_PRECONDITION_RECOVERY
				and not recovery_terminal
			)
	return false


static func integer_valued_native_step_valid_v1(value: Variant, expected_step: int) -> bool:
	if expected_step < MINIMUM_NATIVE_STEP or expected_step > MAXIMUM_NATIVE_STEP:
		return false
	if typeof(value) == TYPE_INT:
		return int(value) == expected_step
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric := float(value)
	return (
		is_finite(numeric)
		and numeric >= float(MINIMUM_NATIVE_STEP)
		and numeric <= float(MAXIMUM_NATIVE_STEP)
		and numeric == floor(numeric)
		and int(numeric) == expected_step
	)


static func _complete_disposition_valid_v1(
	receipt: Dictionary,
	pair_state: Dictionary,
	arm_id: String,
) -> bool:
	var source_value: Variant = (pair_state["terminal_source_by_arm"] as Dictionary).get(arm_id)
	var source_step_value: Variant = (pair_state["terminal_global_step_by_arm"] as Dictionary).get(
		arm_id
	)
	if not (source_value is Dictionary) or typeof(source_step_value) != TYPE_INT:
		return false
	var source: Dictionary = source_value
	return (
		bool(receipt.get("pair_ready", false))
		and not bool(receipt.get("route_terminal", true))
		and (
			String(receipt.get("orchestrator_phase", ""))
			== Orchestrator.PHASE_PRECONDITION_RECOVERY
		)
		and bool(receipt.get("recovery_terminal", false))
		and String(receipt.get("recovery_terminal_phase", "")) == "complete"
		and String(receipt.get("recovery_terminal_failure_code", "")).is_empty()
		and bool(
			(receipt["recovery_classification"] as Dictionary).get("stable_stance_gate", false)
		)
		and (int(receipt.get("recovery_step_global_semantic_step", -1)) == int(source_step_value))
		and (
			String(receipt.get("pair_terminal_source_sha256", ""))
			== String(source.get("payload_sha256", ""))
		)
		and source.get("terminal_step_receipt") == receipt.get("recovery_step_receipt")
		and source.get("terminal_classification") == receipt.get("recovery_classification")
	)


static func failing_arm_ids_v1(
	sdk: Object,
	disposition_by_arm: Dictionary,
	pair_state: Dictionary,
	global_semantic_step: int,
) -> Array:
	if not _arm_dictionary_map_exact_v1(disposition_by_arm):
		return []
	var failing: Array = []
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var disposition_value: Variant = disposition_by_arm.get(arm_id)
		if (
			not (disposition_value is Dictionary)
			or not disposition_valid_v1(
				sdk,
				disposition_value,
				pair_state,
				arm_id,
				global_semantic_step,
			)
		):
			return []
		if String((disposition_value as Dictionary).get("disposition", "")) in FAILURE_DISPOSITIONS:
			failing.append(arm_id)
	return failing


static func build_abort_population_v1(
	sdk: Object,
	pair_state: Dictionary,
	disposition_by_arm: Dictionary,
	global_semantic_step: int,
	global_lockstep_solver_frame_count: int,
	worker_solver_step_count: int,
) -> Dictionary:
	var failing := failing_arm_ids_v1(
		sdk,
		disposition_by_arm,
		pair_state,
		global_semantic_step,
	)
	if (
		failing.is_empty()
		or global_lockstep_solver_frame_count != global_semantic_step
		or worker_solver_step_count != global_semantic_step * ARM_ORDER.size()
	):
		return _failure("QSDK_R10F_L7_ABORT_POPULATION_INPUT_INVALID")
	var disposition_shas := {}
	var failing_by_arm := {}
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var disposition: Dictionary = disposition_by_arm[arm_id]
		disposition_shas[arm_id] = String(disposition["payload_sha256"])
		if arm_id in failing:
			failing_by_arm[arm_id] = String(disposition["disposition"])
	var population := {
		"schema_version": ABORT_POPULATION_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"attempt_id": String(pair_state["attempt_id"]),
		"failure_code": FAILURE_CODE,
		"global_semantic_step": global_semantic_step,
		"ordered_arm_ids": ARM_ORDER.duplicate(),
		"disposition_by_arm": disposition_by_arm.duplicate(true),
		"disposition_sha256_by_arm": disposition_shas,
		"failing_arm_ids": failing.duplicate(),
		"failing_disposition_by_arm": failing_by_arm,
		"pair_state_sha256": String(pair_state["payload_sha256"]),
		"retained_global_lockstep_solver_frame_count": global_lockstep_solver_frame_count,
		"retained_worker_solver_step_count": worker_solver_step_count,
		"expected_worker_solver_step_count_at_stop": global_semantic_step * ARM_ORDER.size(),
		"post_failure_additional_solver_step_count": 0,
		"next_solver_step_permitted": false,
		"generic_terminal_frame_lockstep_failure_label_used": false,
		"nonfailing_peer_last_completed_state_retained": failing.size() < ARM_ORDER.size(),
		"independent_closure_validation_required": true,
		"summary_boolean_without_independent_validation": false,
		"source_measurement": true,
		"outcome_derived_correction": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	population["payload_sha256"] = _payload_sha256_v1(sdk, population)
	if not abort_population_valid_v1(sdk, population, pair_state):
		return _failure("QSDK_R10F_L7_ABORT_POPULATION_BUILD_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r10f_precondition_terminal_abort_build_v1",
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok": true,
		"abort_required": true,
		"abort_population": population,
		"abort_population_sha256": String(population["payload_sha256"]),
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


static func abort_population_valid_v1(
	sdk: Object,
	population: Dictionary,
	pair_state: Dictionary,
) -> bool:
	if (
		sdk == null
		or not PreconditionPairBarrier.state_valid_v1(sdk, pair_state)
		or bool(pair_state.get("released", false))
		or not _keys_exact_v1(population, ABORT_POPULATION_KEYS)
		or String(population.get("schema_version", "")) != ABORT_POPULATION_SCHEMA
		or String(population.get("gate_id", "")) != GATE_ID
		or String(population.get("repair_id", "")) != REPAIR_ID
		or String(population.get("attempt_id", "")) != String(pair_state.get("attempt_id", ""))
		or String(population.get("failure_code", "")) != FAILURE_CODE
		or typeof(population.get("global_semantic_step")) != TYPE_INT
		or population.get("ordered_arm_ids") != ARM_ORDER
		or not (population.get("disposition_by_arm") is Dictionary)
		or not (population.get("disposition_sha256_by_arm") is Dictionary)
		or not (population.get("failing_arm_ids") is Array)
		or not (population.get("failing_disposition_by_arm") is Dictionary)
		or typeof(population.get("retained_global_lockstep_solver_frame_count")) != TYPE_INT
		or typeof(population.get("retained_worker_solver_step_count")) != TYPE_INT
		or typeof(population.get("expected_worker_solver_step_count_at_stop")) != TYPE_INT
		or typeof(population.get("post_failure_additional_solver_step_count")) != TYPE_INT
		or int(population.get("post_failure_additional_solver_step_count")) != 0
		or typeof(population.get("next_solver_step_permitted")) != TYPE_BOOL
		or bool(population.get("next_solver_step_permitted"))
		or typeof(population.get("generic_terminal_frame_lockstep_failure_label_used")) != TYPE_BOOL
		or bool(population.get("generic_terminal_frame_lockstep_failure_label_used"))
		or typeof(population.get("nonfailing_peer_last_completed_state_retained")) != TYPE_BOOL
		or typeof(population.get("independent_closure_validation_required")) != TYPE_BOOL
		or not bool(population.get("independent_closure_validation_required"))
		or typeof(population.get("summary_boolean_without_independent_validation")) != TYPE_BOOL
		or bool(population.get("summary_boolean_without_independent_validation"))
		or typeof(population.get("source_measurement")) != TYPE_BOOL
		or not bool(population.get("source_measurement"))
		or typeof(population.get("outcome_derived_correction")) != TYPE_BOOL
		or bool(population.get("outcome_derived_correction"))
		or not _zero_world_authority_fields_v1(population)
	):
		return false
	var global_step := int(population["global_semantic_step"])
	if (
		global_step < 1
		or global_step != int(pair_state.get("last_completed_global_semantic_step", -1))
		or (
			String(population.get("pair_state_sha256", ""))
			!= String(pair_state.get("payload_sha256", ""))
		)
		or int(population.get("retained_global_lockstep_solver_frame_count")) != global_step
		or (
			int(population.get("retained_worker_solver_step_count"))
			!= global_step * ARM_ORDER.size()
		)
		or (
			int(population.get("expected_worker_solver_step_count_at_stop"))
			!= global_step * ARM_ORDER.size()
		)
	):
		return false
	var dispositions: Dictionary = population["disposition_by_arm"]
	var disposition_shas: Dictionary = population["disposition_sha256_by_arm"]
	if (
		not _arm_dictionary_map_exact_v1(dispositions)
		or not _arm_string_map_exact_v1(disposition_shas)
	):
		return false
	var expected_failing: Array = []
	var expected_failing_by_arm := {}
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var disposition: Dictionary = dispositions[arm_id]
		if not disposition_valid_v1(sdk, disposition, pair_state, arm_id, global_step):
			return false
		if String(disposition_shas[arm_id]) != String(disposition.get("payload_sha256", "")):
			return false
		if String(disposition.get("disposition", "")) in FAILURE_DISPOSITIONS:
			expected_failing.append(arm_id)
			expected_failing_by_arm[arm_id] = String(disposition["disposition"])
	if (
		expected_failing.is_empty()
		or population["failing_arm_ids"] != expected_failing
		or population["failing_disposition_by_arm"] != expected_failing_by_arm
		or (
			bool(population["nonfailing_peer_last_completed_state_retained"])
			!= (expected_failing.size() < ARM_ORDER.size())
		)
	):
		return false
	return String(population.get("payload_sha256", "")) == _payload_sha256_v1(sdk, population)


## The closure consumer calls the structural validator above. This projection
## deliberately refuses a lone summary Boolean so a later physical closure has
## to revalidate the full retained population and every nested digest.
static func independent_closure_projection_valid_v1(
	sdk: Object,
	projection: Dictionary,
	pair_state: Dictionary,
) -> bool:
	var population_value: Variant = projection.get("precondition_terminal_abort_population")
	return (
		population_value is Dictionary
		and typeof(projection.get("independent_population_validation_performed")) == TYPE_BOOL
		and bool(projection.get("independent_population_validation_performed"))
		and typeof(projection.get("summary_boolean_only")) == TYPE_BOOL
		and not bool(projection.get("summary_boolean_only"))
		and _digest_valid_v1(
			String(projection.get("precondition_terminal_abort_population_sha256", ""))
		)
		and (
			String(projection.get("precondition_terminal_abort_population_sha256", ""))
			== String((population_value as Dictionary).get("payload_sha256", ""))
		)
		and abort_population_valid_v1(sdk, population_value, pair_state)
	)


static func integer_valued_native_step_zero_world_v1(sdk: Object) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L8_ZERO_WORLD_SDK_MISSING")
	var fixture := _fixture_bundle_v1(
		sdk,
		{
			EnergyInitializer.ACTIVE_ARM_ID: "nonterminal",
			EnergyInitializer.BASELINE_ARM_ID: "nonterminal",
		},
	)
	if not bool(fixture.get("ok", false)):
		return _failure("QSDK_R10F_L8_ZERO_WORLD_FIXTURE_INVALID", fixture)
	var pair_state: Dictionary = fixture["pair_state"]
	var fields: Dictionary = (
		(fixture["input_by_arm"] as Dictionary)[EnergyInitializer.BASELINE_ARM_ID].duplicate(true)
	)
	(fields["recovery_memory"] as Dictionary)["last_semantic_step"] = 1.0
	((fields["recovery_step_receipt"] as Dictionary)["memory"] as Dictionary)["last_semantic_step"] = 1.0
	var binary64_build := build_disposition_v1(sdk, pair_state, fields)
	if not bool(binary64_build.get("ok", false)):
		return _failure("QSDK_R10F_L8_BINARY64_FIXTURE_BUILD_INVALID", binary64_build)
	var binary64_receipt: Dictionary = binary64_build["disposition"]
	var positive_controls := {
		"exact_integer_memory_step_still_accepted": integer_valued_native_step_valid_v1(1, 1),
		"exact_integer_valued_binary64_memory_step_accepted":
		integer_valued_native_step_valid_v1(1.0, 1),
		"native_shaped_first_step_binary64_disposition_builds":
		disposition_valid_v1(
			sdk,
			binary64_receipt,
			pair_state,
			EnergyInitializer.BASELINE_ARM_ID,
			1,
		),
		"original_binary64_source_kind_retained_without_rewrite":
		(
			typeof((binary64_receipt["recovery_memory"] as Dictionary)["last_semantic_step"])
			== TYPE_FLOAT
		),
		"integer_and_binary64_forms_bind_the_same_expected_step":
		_canonical_sha256_v1(sdk, {"step": 1}) == _canonical_sha256_v1(sdk, {"step": 1.0}),
	}
	var missing_step := binary64_receipt.duplicate(true)
	(missing_step["recovery_memory"] as Dictionary).erase("last_semantic_step")
	missing_step["recovery_memory_sha256"] = _canonical_sha256_v1(
		sdk, missing_step["recovery_memory"]
	)
	missing_step["payload_sha256"] = _payload_sha256_v1(sdk, missing_step)
	var digest_mismatch := binary64_receipt.duplicate(true)
	digest_mismatch["recovery_memory_sha256"] = _filled_sha256_v1("9")
	digest_mismatch["payload_sha256"] = _payload_sha256_v1(sdk, digest_mismatch)
	var outcome_derived := binary64_receipt.duplicate(true)
	outcome_derived["outcome_derived_correction"] = true
	outcome_derived["payload_sha256"] = _payload_sha256_v1(sdk, outcome_derived)
	var source_rewrite := binary64_receipt.duplicate(true)
	(source_rewrite["recovery_memory"] as Dictionary)["last_semantic_step"] = 1
	source_rewrite["recovery_memory_sha256"] = _canonical_sha256_v1(
		sdk, source_rewrite["recovery_memory"]
	)
	source_rewrite["payload_sha256"] = _payload_sha256_v1(sdk, source_rewrite)
	var negative_controls := {
		"fractional_binary64_step_refused": not integer_valued_native_step_valid_v1(1.5, 1),
		"nan_step_refused": not integer_valued_native_step_valid_v1(NAN, 1),
		"positive_infinity_step_refused": not integer_valued_native_step_valid_v1(INF, 1),
		"negative_infinity_step_refused": not integer_valued_native_step_valid_v1(-INF, 1),
		"zero_step_refused": not integer_valued_native_step_valid_v1(0.0, 1),
		"negative_step_refused": not integer_valued_native_step_valid_v1(-1.0, 1),
		"step_above_declared_route_domain_refused":
		not integer_valued_native_step_valid_v1(3843.0, 3843),
		"integer_valued_binary64_not_equal_to_expected_step_refused":
		not integer_valued_native_step_valid_v1(2.0, 1),
		"boolean_step_refused": not integer_valued_native_step_valid_v1(true, 1),
		"string_step_refused": not integer_valued_native_step_valid_v1("1", 1),
		"null_step_refused": not integer_valued_native_step_valid_v1(null, 1),
		"missing_step_refused":
		not disposition_valid_v1(
			sdk,
			missing_step,
			pair_state,
			EnergyInitializer.BASELINE_ARM_ID,
			1,
		),
		"source_number_rewrite_refused":
		not disposition_valid_v1(
			sdk,
			source_rewrite,
			pair_state,
			EnergyInitializer.BASELINE_ARM_ID,
			1,
		),
		"nested_receipt_or_memory_digest_mismatch_refused":
		not disposition_valid_v1(
			sdk,
			digest_mismatch,
			pair_state,
			EnergyInitializer.BASELINE_ARM_ID,
			1,
		),
		"outcome_derived_step_correction_refused":
		not disposition_valid_v1(
			sdk,
			outcome_derived,
			pair_state,
			EnergyInitializer.BASELINE_ARM_ID,
			1,
		),
	}
	var positive_count := 0
	for value in positive_controls.values():
		positive_count += int(bool(value))
	var rejection_count := 0
	for value in negative_controls.values():
		rejection_count += int(bool(value))
	return {
		"schema_version": NATIVE_STEP_DOMAIN_ZERO_WORLD_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": SUCCESSOR_REPAIR_ID,
		"ok":
		(
			positive_count == positive_controls.size()
			and positive_controls.size() == 5
			and rejection_count == negative_controls.size()
			and negative_controls.size() == 15
		),
		"positive_control_count": positive_count,
		"positive_controls": positive_controls,
		"mutation_rejection_count": rejection_count,
		"mutation_controls": negative_controls,
		"minimum_native_step": MINIMUM_NATIVE_STEP,
		"maximum_native_step": MAXIMUM_NATIVE_STEP,
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


static func zero_world_contract_v1(sdk: Object) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L7_ZERO_WORLD_SDK_MISSING")
	var active_complete := _fixture_bundle_v1(
		sdk,
		{
			EnergyInitializer.ACTIVE_ARM_ID: "complete",
			EnergyInitializer.BASELINE_ARM_ID: "nonterminal",
		},
	)
	var active_failed := _fixture_bundle_v1(
		sdk,
		{
			EnergyInitializer.ACTIVE_ARM_ID: "failed",
			EnergyInitializer.BASELINE_ARM_ID: "nonterminal",
		},
	)
	var baseline_failed := _fixture_bundle_v1(
		sdk,
		{
			EnergyInitializer.ACTIVE_ARM_ID: "nonterminal",
			EnergyInitializer.BASELINE_ARM_ID: "failed",
		},
	)
	var active_refused := _fixture_bundle_v1(
		sdk,
		{
			EnergyInitializer.ACTIVE_ARM_ID: "refused",
			EnergyInitializer.BASELINE_ARM_ID: "nonterminal",
		},
	)
	var both_complete := _fixture_bundle_v1(
		sdk,
		{
			EnergyInitializer.ACTIVE_ARM_ID: "complete",
			EnergyInitializer.BASELINE_ARM_ID: "complete",
		},
	)
	for bundle in [active_complete, active_failed, baseline_failed, active_refused, both_complete]:
		if not bool((bundle as Dictionary).get("ok", false)):
			return _failure("QSDK_R10F_L7_ZERO_WORLD_FIXTURE_INVALID", bundle)
	var active_failed_population_build := build_abort_population_v1(
		sdk,
		active_failed["pair_state"],
		active_failed["disposition_by_arm"],
		1,
		1,
		2,
	)
	var baseline_failed_population_build := build_abort_population_v1(
		sdk,
		baseline_failed["pair_state"],
		baseline_failed["disposition_by_arm"],
		1,
		1,
		2,
	)
	var active_refused_population_build := build_abort_population_v1(
		sdk,
		active_refused["pair_state"],
		active_refused["disposition_by_arm"],
		1,
		1,
		2,
	)
	if (
		not bool(active_failed_population_build.get("ok", false))
		or not bool(baseline_failed_population_build.get("ok", false))
		or not bool(active_refused_population_build.get("ok", false))
	):
		return _failure("QSDK_R10F_L7_ZERO_WORLD_ABORT_BUILD_INVALID")
	var released := _complete_common_release_v1(sdk, both_complete["pair_state"])
	var active_complete_dispositions: Dictionary = active_complete["disposition_by_arm"]
	var active_failed_population: Dictionary = active_failed_population_build["abort_population"]
	var baseline_failed_population: Dictionary = baseline_failed_population_build["abort_population"]
	var active_refused_population: Dictionary = active_refused_population_build["abort_population"]
	var positive_controls := {
		"successful_complete_precondition_terminal_still_becomes_arm_local_barrier_source":
		(
			(
				String(
					(
						(
							active_complete_dispositions[EnergyInitializer.ACTIVE_ARM_ID]
							as Dictionary
						)
						. get("disposition", "")
					)
				)
				== DISPOSITION_COMPLETE
			)
			and bool(
				(active_complete_dispositions[EnergyInitializer.ACTIVE_ARM_ID] as Dictionary).get(
					"pair_ready", false
				)
			)
		),
		"active_failed_precondition_terminal_retained_and_route_stops_without_peer_terminal":
		(
			abort_population_valid_v1(sdk, active_failed_population, active_failed["pair_state"])
			and active_failed_population["failing_arm_ids"] == [EnergyInitializer.ACTIVE_ARM_ID]
		),
		"baseline_failed_precondition_terminal_retained_and_route_stops_without_peer_terminal":
		(
			abort_population_valid_v1(
				sdk,
				baseline_failed_population,
				baseline_failed["pair_state"],
			)
			and baseline_failed_population["failing_arm_ids"] == [EnergyInitializer.BASELINE_ARM_ID]
		),
		"refused_precondition_terminal_retained_and_route_stops_without_peer_terminal":
		(
			abort_population_valid_v1(
				sdk,
				active_refused_population,
				active_refused["pair_state"],
			)
			and (
				String(
					(active_refused_population["failing_disposition_by_arm"] as Dictionary).get(
						EnergyInitializer.ACTIVE_ARM_ID, ""
					)
				)
				== DISPOSITION_REFUSED
			)
		),
		"nonterminal_peer_last_completed_state_retained_on_precondition_abort":
		(
			bool(active_failed_population["nonfailing_peer_last_completed_state_retained"])
			and (
				String(
					(
						(active_failed_population["disposition_by_arm"] as Dictionary)[
							EnergyInitializer.BASELINE_ARM_ID
						]
						. get("disposition", "")
					)
				)
				== DISPOSITION_NONTERMINAL
			)
			and not (
				(active_failed_population["disposition_by_arm"] as Dictionary)[
					EnergyInitializer.BASELINE_ARM_ID
				]
				. get("recovery_step_receipt", {})
				. is_empty()
			)
		),
		"both_complete_sources_still_reach_common_no_actuation_release":
		(
			bool(released.get("ok", false))
			and bool((released.get("pair_state", {}) as Dictionary).get("released", false))
			and (
				int(
					(released.get("pair_state", {}) as Dictionary).get(
						"release_completed_global_step", -1
					)
				)
				== 2
			)
		),
	}
	var positive_count := 0
	for value in positive_controls.values():
		positive_count += int(bool(value))
	var negative_controls := _negative_controls_v1(
		sdk,
		active_failed,
		active_failed_population,
		active_complete,
	)
	return {
		"schema_version": ZERO_WORLD_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok":
		positive_count == positive_controls.size() and bool(negative_controls.get("ok", false)),
		"positive_control_count": positive_count,
		"positive_controls": positive_controls,
		"mutation_rejection_count": int(negative_controls.get("rejection_count", -1)),
		"mutation_controls": negative_controls,
		"maximum_solver_steps_per_arm": 3842,
		"maximum_total_solver_steps": 7684,
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


static func _fixture_bundle_v1(sdk: Object, kind_by_arm: Dictionary) -> Dictionary:
	if not _arm_string_map_exact_v1(kind_by_arm):
		return _failure("QSDK_R10F_L7_FIXTURE_KIND_MAP_INVALID")
	var initialized := (
		PreconditionPairBarrier
		. initialize_v1(
			sdk,
			"r10f-l7-zero-world",
			{
				EnergyInitializer.BASELINE_ARM_ID: "r10f-l7-zero-world-baseline-model",
				EnergyInitializer.ACTIVE_ARM_ID: "r10f-l7-zero-world-active-model",
			},
		)
	)
	if not bool(initialized.get("ok", false)):
		return initialized
	var pair_state: Dictionary = initialized["state"]
	var input_by_arm := {}
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var fields := _fixture_fields_v1(arm_id, String(kind_by_arm[arm_id]))
		if fields.is_empty():
			return _failure("QSDK_R10F_L7_FIXTURE_FIELDS_INVALID")
		input_by_arm[arm_id] = fields
		if String(kind_by_arm[arm_id]) == "complete":
			var advance := _fixture_advance_v1(fields)
			var terminal_build := (
				PreconditionPairBarrier
				. build_terminal_source_v1(
					sdk,
					pair_state,
					arm_id,
					1,
					String(fields["recovery_controller_id"]),
					advance,
					fields["recovery_classification"],
				)
			)
			if not bool(terminal_build.get("ok", false)):
				return terminal_build
			var observed := (
				PreconditionPairBarrier
				. observe_terminal_v1(
					sdk,
					pair_state,
					terminal_build["source"],
				)
			)
			if not bool(observed.get("ok", false)):
				return observed
			pair_state = observed["state_after"]
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var completed := (
			PreconditionPairBarrier
			. complete_planned_action_v1(
				sdk,
				pair_state,
				arm_id,
				1,
				PreconditionPairBarrier.ACTION_RECOVERY,
				_filled_sha256_v1("a" if arm_id == EnergyInitializer.ACTIVE_ARM_ID else "b"),
			)
		)
		if not bool(completed.get("ok", false)):
			return completed
		pair_state = completed["state_after"]
	var disposition_by_arm := {}
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var built := build_disposition_v1(sdk, pair_state, input_by_arm[arm_id])
		if not bool(built.get("ok", false)):
			return built
		disposition_by_arm[arm_id] = built["disposition"]
	return {
		"ok": true,
		"pair_state": pair_state,
		"input_by_arm": input_by_arm,
		"disposition_by_arm": disposition_by_arm,
	}


static func _fixture_fields_v1(arm_id: String, kind: String) -> Dictionary:
	if kind not in ["complete", "failed", "refused", "nonterminal"]:
		return {}
	var phase := "establish_distal_support"
	var recovery_terminal := false
	var orchestrator_phase := Orchestrator.PHASE_PRECONDITION_RECOVERY
	var route_terminal := false
	var failure_code := ""
	if kind == "complete":
		phase = "complete"
		recovery_terminal = true
	elif kind == "failed":
		phase = "failed"
		recovery_terminal = true
		orchestrator_phase = Orchestrator.PHASE_FAILED
		route_terminal = true
		failure_code = "phase_timeout:establish_distal_support"
	elif kind == "refused":
		phase = "refused"
		recovery_terminal = true
		orchestrator_phase = Orchestrator.PHASE_FAILED
		route_terminal = true
		failure_code = "invalid_observation:nonfinite_state"
	var classification := {
		"schema_version": "sporespore_qsdk_r10f_l7_zero_world_classification_v1",
		"arm_id": arm_id,
		"stable_stance_gate": kind == "complete",
		"source_measurement": true,
	}
	var memory := {
		"phase": phase,
		"last_semantic_step": 1,
		"terminal_failure_code": failure_code if not failure_code.is_empty() else null,
	}
	var step := {
		"schema_version": "sporespore_qsdk_r10f_l7_zero_world_recovery_step_v1",
		"prior_phase": "establish_distal_support",
		"next_phase": phase,
		"classification": classification.duplicate(true),
		"memory": memory.duplicate(true),
		"source_measurement": true,
	}
	return {
		"arm_id": arm_id,
		"global_semantic_step": 1,
		"orchestrator_phase": orchestrator_phase,
		"route_terminal": route_terminal,
		"route_terminal_reason": failure_code,
		"recovery_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v6",
		"recovery_terminal": recovery_terminal,
		"recovery_terminal_phase": phase if recovery_terminal else "",
		"recovery_terminal_failure_code": failure_code,
		"recovery_step_global_semantic_step": 1,
		"recovery_memory": memory,
		"recovery_step_receipt": step,
		"recovery_classification": classification,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
	}


static func _fixture_advance_v1(fields: Dictionary) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10f_l7_zero_world_recovery_advance_v1",
		"ok": true,
		"terminal": true,
		"step_receipt": (fields["recovery_step_receipt"] as Dictionary).duplicate(true),
		"next_memory": (fields["recovery_memory"] as Dictionary).duplicate(true),
		"control_receipt": null,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _complete_common_release_v1(sdk: Object, pair_state: Dictionary) -> Dictionary:
	var planned := PreconditionPairBarrier.plan_next_frame_v1(sdk, pair_state, 1)
	if not bool(planned.get("ok", false)):
		return planned
	var state: Dictionary = planned["state_after"]
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var completed := (
			PreconditionPairBarrier
			. complete_planned_action_v1(
				sdk,
				state,
				arm_id,
				2,
				PreconditionPairBarrier.ACTION_RELEASE,
				_filled_sha256_v1("c" if arm_id == EnergyInitializer.ACTIVE_ARM_ID else "d"),
			)
		)
		if not bool(completed.get("ok", false)):
			return completed
		state = completed["state_after"]
	return {"ok": PreconditionPairBarrier.state_valid_v1(sdk, state), "pair_state": state}


static func _negative_controls_v1(
	sdk: Object,
	active_failed_bundle: Dictionary,
	active_failed_population: Dictionary,
	active_complete_bundle: Dictionary,
) -> Dictionary:
	var active_id := EnergyInitializer.ACTIVE_ARM_ID
	var baseline_id := EnergyInitializer.BASELINE_ARM_ID
	var failed_state: Dictionary = active_failed_bundle["pair_state"]
	var complete_state: Dictionary = active_complete_bundle["pair_state"]
	var controls := {}

	var missing_failing := active_failed_population.duplicate(true)
	(missing_failing["disposition_by_arm"] as Dictionary).erase(active_id)
	(missing_failing["disposition_sha256_by_arm"] as Dictionary).erase(active_id)
	missing_failing["payload_sha256"] = _payload_sha256_v1(sdk, missing_failing)
	controls["missing_failing_arm_disposition_refused"] = not abort_population_valid_v1(
		sdk, missing_failing, failed_state
	)

	var missing_peer := active_failed_population.duplicate(true)
	(missing_peer["disposition_by_arm"] as Dictionary).erase(baseline_id)
	(missing_peer["disposition_sha256_by_arm"] as Dictionary).erase(baseline_id)
	missing_peer["payload_sha256"] = _payload_sha256_v1(sdk, missing_peer)
	controls["missing_nonterminal_peer_disposition_refused"] = not abort_population_valid_v1(
		sdk, missing_peer, failed_state
	)

	var wrong_identity := _population_disposition_mutation_v1(
		sdk, active_failed_population, active_id
	)
	var wrong_identity_disposition: Dictionary = (
		wrong_identity["disposition_by_arm"] as Dictionary
	)[active_id]
	wrong_identity_disposition["model_instance_id"] = "copied-peer-model"
	_set_population_disposition_v1(sdk, wrong_identity, active_id, wrong_identity_disposition)
	controls["wrong_arm_or_model_identity_refused"] = not abort_population_valid_v1(
		sdk, wrong_identity, failed_state
	)

	var wrong_step := _population_disposition_mutation_v1(sdk, active_failed_population, active_id)
	var wrong_step_disposition: Dictionary = (wrong_step["disposition_by_arm"] as Dictionary)[active_id]
	wrong_step_disposition["global_semantic_step"] = 2
	_set_population_disposition_v1(sdk, wrong_step, active_id, wrong_step_disposition)
	controls["wrong_terminal_global_step_refused"] = not abort_population_valid_v1(
		sdk, wrong_step, failed_state
	)

	var unknown := _population_disposition_mutation_v1(sdk, active_failed_population, active_id)
	var unknown_disposition: Dictionary = (unknown["disposition_by_arm"] as Dictionary)[active_id]
	unknown_disposition["disposition"] = "unknown_terminal"
	_set_population_disposition_v1(sdk, unknown, active_id, unknown_disposition)
	controls["unknown_terminal_disposition_refused"] = not abort_population_valid_v1(
		sdk, unknown, failed_state
	)

	var missing_failure := _population_disposition_mutation_v1(
		sdk, active_failed_population, active_id
	)
	var missing_failure_disposition: Dictionary = (
		missing_failure["disposition_by_arm"] as Dictionary
	)[active_id]
	missing_failure_disposition["recovery_terminal_failure_code"] = ""
	_set_population_disposition_v1(sdk, missing_failure, active_id, missing_failure_disposition)
	controls["failed_disposition_without_failure_code_refused"] = not abort_population_valid_v1(
		sdk, missing_failure, failed_state
	)

	var complete_disposition: Dictionary = (
		(active_complete_bundle["disposition_by_arm"] as Dictionary)[active_id].duplicate(true)
	)
	complete_disposition["recovery_terminal_failure_code"] = "invented_failure"
	complete_disposition["payload_sha256"] = _payload_sha256_v1(sdk, complete_disposition)
	controls["complete_disposition_with_failure_code_refused"] = not disposition_valid_v1(
		sdk, complete_disposition, complete_state, active_id, 1
	)

	var copied_receipt_digest := _population_disposition_mutation_v1(
		sdk, active_failed_population, active_id
	)
	var copied_receipt_disposition: Dictionary = (
		copied_receipt_digest["disposition_by_arm"] as Dictionary
	)[active_id]
	copied_receipt_disposition["recovery_step_receipt_sha256"] = String(
		(copied_receipt_digest["disposition_by_arm"] as Dictionary)[baseline_id].get(
			"recovery_step_receipt_sha256", ""
		)
	)
	_set_population_disposition_v1(
		sdk, copied_receipt_digest, active_id, copied_receipt_disposition
	)
	controls["copied_recovery_receipt_digest_refused"] = not abort_population_valid_v1(
		sdk, copied_receipt_digest, failed_state
	)

	var stale_memory := _population_disposition_mutation_v1(
		sdk, active_failed_population, active_id
	)
	var stale_memory_disposition: Dictionary = (stale_memory["disposition_by_arm"] as Dictionary)[active_id]
	(stale_memory_disposition["recovery_memory"] as Dictionary)["phase_steps_observed"] = 999
	stale_memory_disposition["recovery_memory_sha256"] = _canonical_sha256_v1(
		sdk, stale_memory_disposition["recovery_memory"]
	)
	_set_population_disposition_v1(sdk, stale_memory, active_id, stale_memory_disposition)
	controls["stale_recovery_memory_refused"] = not abort_population_valid_v1(
		sdk, stale_memory, failed_state
	)

	var classification_digest := _population_disposition_mutation_v1(
		sdk, active_failed_population, active_id
	)
	var classification_disposition: Dictionary = (
		classification_digest["disposition_by_arm"] as Dictionary
	)[active_id]
	classification_disposition["recovery_classification_sha256"] = _filled_sha256_v1("e")
	_set_population_disposition_v1(
		sdk, classification_digest, active_id, classification_disposition
	)
	controls["classification_digest_mismatch_refused"] = not abort_population_valid_v1(
		sdk, classification_digest, failed_state
	)

	var pair_digest := _population_disposition_mutation_v1(sdk, active_failed_population, active_id)
	var pair_digest_disposition: Dictionary = (pair_digest["disposition_by_arm"] as Dictionary)[active_id]
	pair_digest_disposition["pair_state_sha256"] = _filled_sha256_v1("f")
	_set_population_disposition_v1(sdk, pair_digest, active_id, pair_digest_disposition)
	controls["pair_state_digest_mismatch_refused"] = not abort_population_valid_v1(
		sdk, pair_digest, failed_state
	)

	var readiness_disposition: Dictionary = (
		(active_complete_bundle["disposition_by_arm"] as Dictionary)[active_id].duplicate(true)
	)
	readiness_disposition["pair_ready"] = false
	readiness_disposition["pair_terminal_source_sha256"] = ""
	readiness_disposition["payload_sha256"] = _payload_sha256_v1(sdk, readiness_disposition)
	controls["pair_readiness_disagrees_with_complete_source_refused"] = not disposition_valid_v1(
		sdk, readiness_disposition, complete_state, active_id, 1
	)

	var outcome_derived := _population_disposition_mutation_v1(
		sdk, active_failed_population, active_id
	)
	var outcome_disposition: Dictionary = (outcome_derived["disposition_by_arm"] as Dictionary)[active_id]
	outcome_disposition["outcome_derived_correction"] = true
	_set_population_disposition_v1(sdk, outcome_derived, active_id, outcome_disposition)
	controls["outcome_derived_terminal_correction_refused"] = not abort_population_valid_v1(
		sdk, outcome_derived, failed_state
	)

	var generic_label := active_failed_population.duplicate(true)
	generic_label["generic_terminal_frame_lockstep_failure_label_used"] = true
	generic_label["payload_sha256"] = _payload_sha256_v1(sdk, generic_label)
	controls["generic_terminal_frame_lockstep_failure_label_refused_during_precondition"] = (not abort_population_valid_v1(
		sdk, generic_label, failed_state
	))

	var post_failure_step := active_failed_population.duplicate(true)
	post_failure_step["post_failure_additional_solver_step_count"] = 1
	post_failure_step["payload_sha256"] = _payload_sha256_v1(sdk, post_failure_step)
	controls["post_failure_additional_solver_step_refused"] = not abort_population_valid_v1(
		sdk, post_failure_step, failed_state
	)

	controls["summary_boolean_without_independent_closure_validation_refused"] = (not independent_closure_projection_valid_v1(
		sdk,
		{"precondition_terminal_disposition_retention_valid": true},
		failed_state,
	))
	var rejection_count := 0
	for value in controls.values():
		rejection_count += int(bool(value))
	return {
		"ok": rejection_count == controls.size() and controls.size() == 16,
		"rejection_count": rejection_count,
		"expected_rejection_count": 16,
		"controls": controls,
	}


static func _population_disposition_mutation_v1(
	_sdk: Object,
	population: Dictionary,
	arm_id: String,
) -> Dictionary:
	var mutated := population.duplicate(true)
	var disposition: Dictionary = (mutated["disposition_by_arm"] as Dictionary)[arm_id]
	(mutated["disposition_by_arm"] as Dictionary)[arm_id] = disposition.duplicate(true)
	return mutated


static func _set_population_disposition_v1(
	sdk: Object,
	population: Dictionary,
	arm_id: String,
	disposition: Dictionary,
) -> void:
	disposition["payload_sha256"] = _payload_sha256_v1(sdk, disposition)
	(population["disposition_by_arm"] as Dictionary)[arm_id] = disposition
	(population["disposition_sha256_by_arm"] as Dictionary)[arm_id] = String(
		disposition["payload_sha256"]
	)
	population["payload_sha256"] = _payload_sha256_v1(sdk, population)


static func _arm_dictionary_map_exact_v1(value: Dictionary) -> bool:
	if not _arm_map_exact_v1(value):
		return false
	for arm_id in ARM_ORDER:
		if not (value.get(arm_id) is Dictionary):
			return false
	return true


static func _arm_string_map_exact_v1(value: Dictionary) -> bool:
	if not _arm_map_exact_v1(value):
		return false
	for arm_id in ARM_ORDER:
		if typeof(value.get(arm_id)) != TYPE_STRING or String(value.get(arm_id, "")).is_empty():
			return false
	return true


static func _arm_map_exact_v1(value: Dictionary) -> bool:
	return (
		value.size() == ARM_ORDER.size()
		and value.keys().all(func(key: Variant) -> bool: return key in ARM_ORDER)
	)


static func _keys_exact_v1(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _zero_world_authority_fields_v1(value: Dictionary) -> bool:
	return (
		typeof(value.get("model_construction_count")) == TYPE_INT
		and int(value.get("model_construction_count")) == 0
		and typeof(value.get("world_attempt_count")) == TYPE_INT
		and int(value.get("world_attempt_count")) == 0
		and typeof(value.get("world_build_count")) == TYPE_INT
		and int(value.get("world_build_count")) == 0
		and typeof(value.get("scene_tree_insertion_count")) == TYPE_INT
		and int(value.get("scene_tree_insertion_count")) == 0
		and typeof(value.get("native_readback_count")) == TYPE_INT
		and int(value.get("native_readback_count")) == 0
		and typeof(value.get("solver_step_count")) == TYPE_INT
		and int(value.get("solver_step_count")) == 0
		and typeof(value.get("physics_state_modified")) == TYPE_BOOL
		and not bool(value.get("physics_state_modified"))
		and typeof(value.get("physical_acceptance_authority")) == TYPE_BOOL
		and not bool(value.get("physical_acceptance_authority"))
		and typeof(value.get("release_authority")) == TYPE_BOOL
		and not bool(value.get("release_authority"))
	)


static func _canonical_sha256_v1(sdk: Object, value: Variant) -> String:
	if sdk == null:
		return ""
	return String(RecoveryRuntimeScript.canonicalize(sdk, value).get("sha256", ""))


static func _payload_sha256_v1(sdk: Object, value: Dictionary) -> String:
	var payload := value.duplicate(true)
	payload.erase("payload_sha256")
	return _canonical_sha256_v1(sdk, payload)


static func _filled_sha256_v1(fill: String) -> String:
	return "sha256:" + fill.repeat(64)


static func _digest_valid_v1(value: String) -> bool:
	if not value.begins_with("sha256:"):
		return false
	var digest := value.trim_prefix("sha256:")
	if digest.length() != 64:
		return false
	for byte in digest.to_ascii_buffer():
		if not ((byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 102)):
			return false
	return true


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10f_precondition_terminal_disposition_failure_v1",
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
