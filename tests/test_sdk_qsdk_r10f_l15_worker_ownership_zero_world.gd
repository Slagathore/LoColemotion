extends SceneTree
# gdlint: disable=max-line-length

## Both complete new production stages, with a named synthetic motor-read seam.
## Actual source/epoch composers, serializer, compiled collection and V6 advance
## are used. No physical worker instance, body, hinge or world is constructed.
const Stage := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_no_actuation_worker_stage_v1.gd"
)
const Owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")
const Facade := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
)
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Epoch := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_native_measurement_route_v1.gd"
)
const Prior := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd")
const Child := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_process_isolated_child_contract_v1.gd"
)
const Behavior := preload("res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MARKER := "QSDK_R10F_L15_WORKER_OWNERSHIP_ZERO_WORLD "
const E := 508


class SyntheticMotorReadback:
	extends RefCounted
	var calls: Array = []
	var forced_failure := false
	var invalid_enabled_motor := false
	var synthetic_reported_read_count := 0

	func motor_population_readback_v1(step: int, enabled: bool, reason: String) -> Dictionary:
		calls.append({"step": step, "enabled": enabled, "reason": reason})
		if forced_failure:
			return {"ok": false, "failure_code": "SYNTHETIC_MOTOR_READ_REFUSAL"}
		var result := Child._zero_world_motor_readback_v1(step)
		result["native_readback_count"] = synthetic_reported_read_count
		if invalid_enabled_motor:
			result["motor_enabled_count"] = 1
		return result


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
		return {"ok": false, "failure_code": "L15_WORKER_EXTENSION_MISSING"}
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var context := Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	var fixture := _initialize_epoch_fixture_v1(sdk, context)
	if context.get("ok") != true or fixture.get("ok") != true:
		return {"ok": false, "fixture": fixture, "context": context}
	var motor := SyntheticMotorReadback.new()
	var arm := {"facade": motor, "untouched_state": {"value": 17}}
	var original_arm := arm.duplicate(true)
	var initial := Stage.initialize_v1(sdk, context, arm, E)
	if initial.get("ok") != true:
		return {"ok": false, "initial_stage": initial}
	var controls := {}
	var empty_stage := Stage._stage_v1({}, {}, 0, 0, 0)
	controls["unexpected_empty_stage_cannot_be_success"] = (
		empty_stage.get("ok") == false
		and (
			empty_stage["failure"].get("failure_code")
			== "QSDK_R10F_L15_NO_ACTUATION_STAGE_EMPTY_RESULT"
		)
	)
	controls["initial_stage_does_not_mutate_input_arm"] = Owner.same_value_v1(arm, original_arm)
	controls["initial_stage_initializes_once_reads_once"] = (
		initial["portable_controller_initialization_call_count"] == 1
		and initial["motor_population_readback_call_count"] == 1
	)
	arm = initial["arm"]
	var source_applications := []
	var epoch_results := []
	var identifier_control: Dictionary = {}
	for offset in [1, 2]:
		var step: int = E + offset
		var application: Dictionary = arm["pending_application"]
		var memory: Dictionary = arm["recovery_memory"]
		var before_memory := memory.duplicate(true)
		controls["external_memory_checked_%d" % offset] = (
			Stage.validate_pending_v1(sdk, arm, step).get("external_source_memory_checked") == true
		)
		controls["orchestration_and_canonical_labels_separate_%d" % offset] = (
			application["controller_owner"] == "recovery_v6"
			and application["canonical_controller_owner"] == "recovery"
		)
		controls["source_application_is_exact_actual_v1_%d" % offset] = Owner.same_value_v1(
			application["canonical_ownership_mapping"]["source_application"],
			Facade.no_actuation_ledger_application_intent_v1(
				sdk,
				step,
				memory["phase"],
				"recovery_v6",
				Owner.RECOVERY_CONTROLLER_ID,
				application["zero_command"],
				application["owner_source_receipt"],
				application["motor_population_readback"]
			)
		)
		var projected := _advance_epoch_fixture_v1(sdk, context, fixture, application, step)
		if projected.get("ok") != true:
			return {"ok": false, "offset": offset, "projection": projected}
		if offset == 1:
			# The collector accepts a nonempty ID, but the V6 step requires the
			# canonical identifier alphabet. Keep this actual native refusal as
			# a control; changing the Rust validator is not part of this repair.
			var colon_projection := _advance_epoch_fixture_v1(
				sdk,
				context,
				fixture,
				application,
				step,
				application["canonical_ownership_mapping"]["source_application"]["command_id"]
			)
			if colon_projection.get("ok") != true:
				return {"ok": false, "colon_projection": colon_projection}
			var colon_bound: Dictionary = colon_projection["epoch"]["bound_epoch_observations"]
			var colon_refusal := Behavior.production_advance_dispatch_v1(
				sdk,
				context,
				colon_bound,
				memory,
				"candidate_command",
				memory["phase"],
				Owner.RECOVERY_CONTROLLER_ID,
				Route.R148_COMPLETE_ENERGY_ROUTE_ID
			)
			identifier_control = colon_refusal
			controls["legacy_colon_command_id_retains_actual_portable_step_refusal"] = (
				colon_refusal.get("failure_code") == "QSDK_R24D65_BEHAVIOR_PORTABLE_STEP_REFUSED"
				and (
					colon_refusal.get("detail", {}).get("refusal_reason")
					== "applied_actuation_receipt_invalid"
				)
			)
			controls["refused_identifier_control_does_not_mutate_memory"] = Owner.same_value_v1(
				memory, before_memory
			)
		var advanced := Behavior.production_advance_dispatch_v1(
			sdk,
			context,
			projected["epoch"]["bound_epoch_observations"],
			memory,
			"candidate_command",
			memory["phase"],
			Owner.RECOVERY_CONTROLLER_ID,
			Route.R148_COMPLETE_ENERGY_ROUTE_ID
		)
		if (
			advanced.get("ok") != true
			or not Behavior.production_advance_receipt_valid_v1(
				advanced, Owner.RECOVERY_CONTROLLER_ID, sdk, Route.R148_COMPLETE_ENERGY_ROUTE_ID
			)
		):
			return {"ok": false, "offset": offset, "advance": advanced}
		controls["controller_input_memory_unchanged_%d" % offset] = Owner.same_value_v1(
			memory, before_memory
		)
		controls["compiled_collection_accepted_%d" % offset] = (
			advanced["collection_receipt"]["support_status"] == "supported_exact"
			and advanced["collection_receipt"]["refusal_reason"] == null
		)
		controls["epoch_global_native_identity_preserved_%d" % offset] = (
			projected["epoch"]["global_semantic_step"] == step
			and projected["epoch"]["epoch_local_step"] == offset
			and (
				projected["epoch"]["bound_epoch_observations"]["observation_v2"]["engine_step_identity"]["semantic_step"]
				== step
			)
		)
		source_applications.append(
			{
				"global_step": step,
				"phase": memory["phase"],
				"mapping_sha256": application["canonical_ownership_mapping_sha256"],
				"source_memory_sha256":
				application["canonical_ownership_mapping"]["source_memory_sha256"]
			}
		)
		epoch_results.append(
			{
				"global_step": step,
				"local_step": offset,
				"collection_support": advanced["collection_receipt"]["support_status"],
				"next_phase": advanced["next_memory"]["phase"]
			}
		)
		fixture = projected["fixture_after"]
		arm["recovery_memory"] = advanced["next_memory"].duplicate(true)
		arm["next_recovery_control"] = advanced["control_receipt"].duplicate(true)
		if offset == 1:
			var before_arm := arm.duplicate(true)
			var passive := Stage.passive_v1(sdk, arm, step)
			if passive.get("ok") != true:
				return {"ok": false, "passive_stage": passive}
			controls["passive_stage_does_not_mutate_input_arm"] = Owner.same_value_v1(
				arm, before_arm
			)
			controls["passive_stage_binds_actual_next_memory_and_control"] = (
				Owner.same_value_v1(
					passive["arm"]["pending_application"]["owner_source_receipt"],
					arm["next_recovery_control"]
				)
				and Owner.same_value_v1(passive["arm"]["recovery_memory"], arm["recovery_memory"])
			)
			controls["passive_stage_does_not_reinitialize_and_reads_once"] = (
				passive["portable_controller_initialization_call_count"] == 0
				and passive["motor_population_readback_call_count"] == 1
			)
			controls["pending_control_consumed_after_success"] = (
				passive["arm"]["next_recovery_control"].is_empty()
			)
			arm = passive["arm"]
	controls["exact_two_disabled_read_requests_and_reasons"] = (
		motor.calls
		== [
			{
				"step": E + 1,
				"enabled": false,
				"reason": "post_kick_passive_prone_first_observation"
			},
			{
				"step": E + 2,
				"enabled": false,
				"reason": "continued_zero_actuation_passive_prone_observation"
			}
		]
	)
	# The pending application represents the memory before the second advance;
	# use its source copy for independently controlled pre-sampling corruptions.
	arm["recovery_memory"] = (
		arm["pending_application"]["canonical_ownership_mapping"]["source_memory"].duplicate(true)
	)
	_mutation_controls_v1(sdk, context, arm, controls)
	var failures := []
	for key in controls:
		if controls[key] != true:
			failures.append(key)
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_worker_ownership_zero_world_v1",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_worker_ownership_stage_and_epoch",
			"question_class": "development"
		},
		"ok": failures.is_empty(),
		"controls": controls,
		"control_count": controls.size(),
		"failed_controls": failures,
		"source_applications": source_applications,
		"epoch_results": epoch_results,
		"identifier_control": identifier_control,
		"compiled_collection_call_count": 3,
		"compiled_controller_advance_call_count": 3,
		"successful_compiled_controller_advance_count": 2,
		"refused_compiled_controller_step_count": 1,
		"production_stage_count": 2,
		"motor_readback_is_synthetic_fixture": true,
		"enclosing_physical_worker_executed": false,
		"complete_worker_to_envelope_qualified": false,
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


static func _mutation_controls_v1(
	sdk: Object, context: Dictionary, arm: Dictionary, controls: Dictionary
) -> void:
	var step: int = arm["pending_application"]["semantic_step"]
	for key in ["pending_application", "recovery_memory"]:
		var changed := arm.duplicate(true)
		changed.erase(key)
		controls["missing_%s_refused_before_sampling" % key] = (
			Stage.validate_pending_v1(sdk, changed, step).get("ok") == false
		)
	var changed := arm.duplicate(true)
	changed["recovery_memory"]["phase_steps_observed"] += 1
	controls["external_memory_drift_refused_before_sampling"] = (
		Stage.validate_pending_v1(sdk, changed, step).get("ok") == false
	)
	var new_application := Owner.build_v1(
		sdk,
		arm["pending_application"]["canonical_ownership_mapping"]["source_application"],
		changed["recovery_memory"]
	)
	changed = arm.duplicate(true)
	changed["pending_application"] = new_application
	controls["coherently_resealed_wrong_memory_refused_before_sampling"] = (
		Stage.validate_pending_v1(sdk, changed, step).get("ok") == false
	)
	changed = arm.duplicate(true)
	changed["pending_application"] = (
		arm["pending_application"]["canonical_ownership_mapping"]["source_application"]
		. duplicate(true)
	)
	controls["legacy_recovery_cannot_bypass_l15_precheck"] = (
		Stage.validate_pending_v1(sdk, changed, step).get("ok") == false
	)
	controls["wrong_global_step_refused_before_sampling"] = (
		Stage.validate_pending_v1(sdk, arm, step + 1).get("ok") == false
	)
	changed = arm.duplicate(true)
	changed["pending_application"]["semantic_step"] = float(step)
	controls["mapped_step_kind_remains_exact"] = (
		Stage.validate_pending_v1(sdk, changed, step).get("ok") == false
	)
	var legacy_application := {
		"schema_version": "synthetic_nonmapping_legacy_application",
		"controller_owner": "recovery",
		"semantic_step": float(step)
	}
	var legacy_projection := Stage.validate_pending_v1(
		sdk, {"pending_application": legacy_application}, step
	)
	controls["legacy_application_number_kinds_left_to_existing_contract"] = (
		legacy_projection.get("ok") == true
		and legacy_projection.get("canonical_ownership_mapping_required") == false
	)
	changed = arm.duplicate(true)
	changed["pending_application"]["canonical_ownership_mapping_sha256"] = (
		"sha256:" + "0".repeat(64)
	)
	controls["stale_mapping_refused_before_sampling"] = (
		Stage.validate_pending_v1(sdk, changed, step).get("ok") == false
	)
	for key in ["next_recovery_control", "recovery_memory"]:
		var motor := SyntheticMotorReadback.new()
		changed = arm.duplicate(true)
		changed["facade"] = motor
		changed.erase(key)
		var result := Stage.passive_v1(sdk, changed, step)
		controls["passive_missing_%s_stops_before_motor_read" % key] = (
			result.get("ok") == false
			and motor.calls.is_empty()
			and result["motor_population_readback_call_count"] == 0
		)
	var motor := SyntheticMotorReadback.new()
	motor.forced_failure = true
	var read_failed := Stage.initialize_v1(sdk, context, {"facade": motor}, E)
	controls["initial_motor_failure_preserved_without_arm_commit"] = (
		read_failed["failure"].get("failure_code") == "SYNTHETIC_MOTOR_READ_REFUSAL"
		and read_failed["arm"].is_empty()
		and read_failed["motor_population_readback_call_count"] == 1
	)
	motor = SyntheticMotorReadback.new()
	motor.invalid_enabled_motor = true
	motor.synthetic_reported_read_count = 13
	changed = arm.duplicate(true)
	changed["facade"] = motor
	var invalid := Stage.passive_v1(sdk, changed, step)
	controls["successful_read_counter_retained_if_application_fails"] = (
		invalid.get("ok") == false
		and invalid["consumed_native_readback_count"] == 13
		and invalid["arm"].is_empty()
	)
	controls["application_failure_does_not_consume_source_control"] = not (
		changed["next_recovery_control"].is_empty()
	)


static func _initialize_epoch_fixture_v1(sdk: Object, context: Dictionary) -> Dictionary:
	var pair := Prior.ImpulsePairReceipt.build_pair_receipt_v1(
		sdk, Prior._impulse_pair_source_fixture_v1()
	)
	if pair.get("ok") != true:
		return pair
	var interaction := Prior.EnergyInitializer.build_interaction_receipt_v1(
		sdk,
		Prior.ATTEMPT_ID,
		Prior.EnergyInitializer.ACTIVE_ARM_ID,
		Prior.MODEL_INSTANCE_ID,
		E,
		E,
		pair["active_native_effect_velocity_delta_m_s"],
		pair["pair_receipt_sha256"]
	)
	var boundary := Prior._completed_boundary_v1(
		sdk, Prior.EnergyInitializer.ACTIVE_ARM_ID, E, "l15-synthetic-completed-508"
	)
	var observer := Prior._observer_for_global_step_v1(E, Vector3(0.0, 0.125, 0.0))
	var sources := _zero_actuation_sources_v1(sdk, context, observer, E, 0.125)
	if interaction.get("ok") != true or boundary.get("ok") != true or sources.get("ok") != true:
		return {"ok": false, "interaction": interaction, "boundary": boundary, "sources": sources}
	var global_accumulator := Prior._global_staging_accumulator_v1(E)
	var initialized := Epoch.initialize_epoch_projection_v1(
		sdk,
		boundary["boundary"],
		sources["energy_source_receipt"],
		sources["source_component_receipts"],
		global_accumulator,
		interaction["interaction_receipt"]
	)
	if initialized.get("ok") != true:
		return initialized
	return {
		"ok": true,
		"epoch_state": initialized["epoch_transport_state"],
		"energy_initializer": initialized["energy_initializer"],
		"epoch_accumulator": initialized["epoch_staging_accumulator"],
		"global_accumulator": global_accumulator
	}


static func _advance_epoch_fixture_v1(
	sdk: Object,
	context: Dictionary,
	fixture: Dictionary,
	application: Dictionary,
	step: int,
	synthetic_command_id_override: Variant = null
) -> Dictionary:
	# The retained synthetic solver telemetry declares this displacement. The
	# global observer and the independently rebuilt epoch observer must agree.
	var observer := Prior._observer_for_global_step_v1(step, Vector3(0.0, 0.125, 0.0))
	var cumulative_staging: float = (
		fixture["global_accumulator"]["cumulative_signed_discrete_staging_exchange_j"]
		+ observer["signed_discrete_staging_exchange_j"]
	)
	var sources := _zero_actuation_sources_v1(sdk, context, observer, step, cumulative_staging)
	var observation := Prior._observation_base_for_step_v1(sdk, context, step)
	observation["state"]["sample_time_s"] = step * Route.OUTER_STEP_DURATION_S
	observation["controller_ownership"] = (
		World.controller_ownership_observation_v1(sdk, application)["observation"]
	)
	observation["applied_actuation"]["adapter_receipt_sha256"] = (
		Runtime.canonicalize(sdk, application)["sha256"]
	)
	for key in ["command_id", "command_sha256", "zero_command"]:
		observation["applied_actuation"][key] = application[key]
	if synthetic_command_id_override != null:
		# Bind the deliberate identifier corruption through the actual source
		# composers. A stale observation hash would stop at collection instead.
		observation["applied_actuation"]["command_id"] = synthetic_command_id_override
	var global_bound := Route.compose_discrete_staging_complete_energy_observations_v1(
		sdk,
		context,
		observation,
		sources["energy_source_receipt"],
		sources["source_component_receipts"],
		observer,
		fixture["global_accumulator"]
	)
	if global_bound.get("ok") != true:
		return global_bound
	var global_result := Prior._committed_global_result_fixture_v1(sdk, sources, observation, step)
	global_result["bound"] = global_bound
	var projection := Epoch.project_committed_global_result_v1(sdk, global_result, step)
	var boundary := Prior._completed_boundary_v1(
		sdk, Prior.EnergyInitializer.ACTIVE_ARM_ID, step, "l15-synthetic-completed-%d" % step
	)
	var epoch := Epoch.advance_epoch_projection_v1(
		sdk,
		fixture["epoch_state"],
		fixture["energy_initializer"],
		fixture["epoch_accumulator"],
		boundary["boundary"],
		projection
	)
	if epoch.get("ok") != true:
		return epoch
	var after := fixture.duplicate(true)
	after["epoch_state"] = epoch["epoch_transport_state_after"]
	after["epoch_accumulator"] = epoch["epoch_staging_accumulator_after"]
	after["global_accumulator"] = global_bound["native_to_portable_staging_mapping"]["accumulator_after"]
	return {"ok": true, "epoch": epoch, "fixture_after": after}


static func _zero_actuation_sources_v1(
	sdk: Object, context: Dictionary, observer: Dictionary, step: int, cumulative_staging: float
) -> Dictionary:
	var sources := Prior._rotation_sources_for_step_v1(sdk, context, observer, step)
	if sources.get("ok") != true:
		return sources
	var energy: Dictionary = sources["energy_source_receipt"]
	var components: Dictionary = sources["source_component_receipts"]
	var motors := Prior.R162Worker._motor_receipts_v1()
	for row in motors:
		row["capture_space_step_sequence"] = step
		row["read_space_step_sequence"] = step
		row["net_motor_work_j"] = 0.0
	var partition := World.solver_coupled_complete_energy_partition_for_recovery_route_v2(
		context, components["solver_energy_exchange_receipt"], motors, 0.0, step
	)
	if partition.get("ok") != true:
		return partition
	var partition_sha: String = Runtime.canonicalize(sdk, partition)["sha256"]
	energy["step_signed_constraint_exchange_j"] = partition["step_signed_constraint_exchange_j"]
	energy["cumulative_signed_constraint_exchange_j"] = (
		step * float(partition["step_signed_constraint_exchange_j"])
	)
	for key in [
		"cumulative_applied_actuator_work_j",
		"cumulative_signed_external_work_j",
		"cumulative_passive_dissipation_j",
		"step_actuator_work_j"
	]:
		energy[key] = 0.0
	energy["current_mechanical_energy_j"] = (
		20.0 + float(energy["cumulative_signed_constraint_exchange_j"]) + cumulative_staging
	)
	energy["solver_coupled_partition_receipt_sha256"] = partition_sha
	energy["actuator_constraint_disjointness_receipt_sha256"] = partition_sha
	components["solver_coupled_partition_receipt"] = partition
	components["solver_coupled_partition_receipt_sha256"] = partition_sha
	sources["ok"] = Prior.EnergyInitializer.rotation_aware_sources_valid_v1(sdk, energy, components)
	return sources
