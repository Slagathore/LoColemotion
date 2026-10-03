extends SceneTree
# gdlint: disable=max-line-length

## Component coverage, not the full L15 worker/epoch/authority qualification.
## Every state/contact/motor sample below is a labeled synthetic source. Only
## the compiled SDK object is instantiated; no body, hinge or world is created.
const Facade := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
)
const Owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const ChildContract := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_process_isolated_child_contract_v1.gd"
)
const PriorGate := preload(
	"res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd"
)
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MARKER := "QSDK_R10F_L15_CANONICAL_OWNERSHIP_ZERO_WORLD "


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
		return {"ok": false, "failure_code": "L15_EXTENSION_UNAVAILABLE"}
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var context := Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	var initialized := Route.initialize_behavior_arm_v1(sdk, context, "candidate_command")
	if context.get("ok") != true or initialized.get("ok") != true:
		sdk = null
		return {
			"ok": false,
			"failure_code": "L15_CONTEXT_OR_MEMORY_INVALID",
			"context": context,
			"initialized": initialized
		}
	var memory: Dictionary = initialized["memory"]
	var source: Dictionary = initialized["initialization_receipt"]
	var readback := ChildContract._zero_world_motor_readback_v1(2)
	var original_memory := memory.duplicate(true)
	var original_source := source.duplicate(true)
	var original_readback := readback.duplicate(true)
	var legacy := Facade.no_actuation_ledger_application_intent_v1(
		sdk,
		2,
		"confirm_prone",
		"recovery_v6",
		Owner.RECOVERY_CONTROLLER_ID,
		false,
		source,
		readback
	)
	var mapped := Facade.no_actuation_ledger_application_intent_v2(
		sdk,
		2,
		"confirm_prone",
		"recovery_v6",
		Owner.RECOVERY_CONTROLLER_ID,
		false,
		source,
		readback,
		memory
	)
	if legacy.get("ok") != true or mapped.get("ok") != true:
		sdk = null
		return {
			"ok": false,
			"failure_code": "L15_APPLICATION_BUILD_FAILED",
			"legacy": legacy,
			"mapped": mapped
		}
	var controls := {}
	controls["existing_exact_v6_id_unchanged"] = (
		Owner.RECOVERY_CONTROLLER_ID == Route.RECOVERY_CONTROLLER_V6_ID
		and Owner.RECOVERY_CONTROLLER_ID == World.RECOVERY_CONTROLLER_V6_ID
	)
	controls["mapping_binds_exact_external_memory"] = (
		Owner.validate_v1(sdk, mapped, memory).get("ok") == true
	)
	controls["orchestration_label_preserved"] = mapped["controller_owner"] == "recovery_v6"
	controls["canonical_owner_is_separate"] = (
		World.controller_ownership_observation_v1(sdk, mapped)["observation"]["owner"] == "recovery"
	)
	controls["legacy_label_not_upgraded"] = (
		World.controller_ownership_observation_v1(sdk, legacy)["observation"]["owner"]
		== "recovery_v6"
	)
	controls["producer_inputs_unchanged"] = (
		Owner.same_value_v1(memory, original_memory)
		and Owner.same_value_v1(source, original_source)
		and Owner.same_value_v1(readback, original_readback)
	)
	var projected_back := mapped.duplicate(true)
	for key in [
		"canonical_controller_owner",
		"canonical_ownership_mapping",
		"canonical_ownership_mapping_sha256"
	]:
		projected_back.erase(key)
	projected_back["schema_version"] = legacy["schema_version"]
	projected_back["command_sha256"] = legacy["command_sha256"]
	projected_back["command_id"] = legacy["command_id"]
	controls["every_nonmapping_field_and_all_eight_motor_rows_preserved"] = (
		Owner.same_value_v1(projected_back, legacy)
		and readback["ordered_joint_readbacks"].size() == 8
	)
	controls["canonical_command_id_derived_from_mapping_command_digest"] = (
		mapped["command_id"]
		== "qsdk_r10f_l15_no_actuation_" + mapped["command_sha256"].trim_prefix("sha256:")
	)
	controls["legacy_command_id_preserved_inside_source"] = (
		(
			mapped["canonical_ownership_mapping"]["source_application"]["command_id"]
			== legacy["command_id"]
		)
		and ":" in legacy["command_id"]
	)
	var unowned := Facade.no_actuation_ledger_application_intent_v2(
		sdk, 2, "confirm_prone", "none", null, true, source, readback, {}
	)
	controls["none_maps_to_none_with_null_id"] = (
		unowned.get("ok") == true
		and (
			World.controller_ownership_observation_v1(sdk, unowned)["observation"]["owner"]
			== "none"
		)
		and unowned["recovery_controller_id"] == null
	)
	for owner in ["unknown", "recovery", "stance"]:
		controls["unmapped_owner_refused_%s" % owner] = (
			(
				Facade
				. no_actuation_ledger_application_intent_v2(
					sdk,
					2,
					"confirm_prone",
					owner,
					Owner.RECOVERY_CONTROLLER_ID,
					false,
					source,
					readback,
					memory
				)
				. get("ok")
			)
			== false
		)
	for controller_id in [null, "", "wrong_controller"]:
		controls["wrong_recovery_id_refused_%s" % str(controller_id)] = (
			(
				Facade
				. no_actuation_ledger_application_intent_v2(
					sdk,
					2,
					"confirm_prone",
					"recovery_v6",
					controller_id,
					false,
					source,
					readback,
					memory
				)
				. get("ok")
			)
			== false
		)
	controls["none_with_recovery_id_refused"] = (
		(
			Facade
			. no_actuation_ledger_application_intent_v2(
				sdk,
				2,
				"confirm_prone",
				"none",
				Owner.RECOVERY_CONTROLLER_ID,
				false,
				source,
				readback,
				{}
			)
			. get("ok")
		)
		== false
	)
	var changed := mapped.duplicate(true)
	changed["command_id"] = legacy["command_id"]
	controls["changed_canonical_command_id_refused"] = (
		Owner.validate_v1(sdk, changed, memory).get("ok") == false
	)
	changed = mapped.duplicate(true)
	changed["canonical_controller_owner"] = "stance"
	controls["changed_canonical_owner_refused"] = (
		World.controller_ownership_observation_v1(sdk, changed).get("ok") == false
	)
	changed = mapped.duplicate(true)
	changed["canonical_ownership_mapping_sha256"] = "sha256:" + "f".repeat(64)
	controls["stale_mapping_hash_refused"] = (
		Owner.validate_v1(sdk, changed, memory).get("ok") == false
	)
	changed = mapped.duplicate(true)
	changed["motor_population_readback"]["ordered_joint_readbacks"][0]["motor_maximum_impulse_nms"] = 0.25
	controls["changed_motor_source_refused"] = (
		Owner.validate_v1(sdk, changed, memory).get("ok") == false
	)
	changed = mapped.duplicate(true)
	changed["canonical_ownership_mapping"]["source_memory"]["phase_steps_observed"] = 123
	controls["stale_memory_refused"] = Owner.validate_v1(sdk, changed, memory).get("ok") == false
	var other_memory := memory.duplicate(true)
	other_memory["phase_steps_observed"] = 123
	changed = Owner.build_v1(sdk, legacy, other_memory)
	controls["coherently_resealed_wrong_memory_refused"] = (
		Owner.validate_v1(sdk, changed, memory).get("ok") == false
	)
	changed = mapped.duplicate(true)
	changed["schema_version"] = Owner.LEGACY_APPLICATION_SCHEMA
	controls["mapping_cannot_downgrade_to_legacy"] = (
		World.controller_ownership_observation_v1(sdk, changed).get("ok") == false
	)
	for key in [
		"command_sha256", "owner_source_receipt_sha256", "motor_population_readback_sha256"
	]:
		changed = legacy.duplicate(true)
		changed[key] = "sha256:" + "f".repeat(64)
		controls["stale_source_%s_refused" % key] = (
			Owner.build_v1(sdk, changed, memory).get("ok") == false
		)
	changed = legacy.duplicate(true)
	changed["ok"] = 1
	controls["integer_instead_of_source_boolean_refused"] = (
		Owner.build_v1(sdk, changed, memory).get("ok") == false
	)
	changed = legacy.duplicate(true)
	changed["body_impulse_write_count"] = 1
	controls["nonzero_source_actuation_refused"] = (
		Owner.build_v1(sdk, changed, memory).get("ok") == false
	)
	for key in [
		"semantic_step",
		"phase",
		"command_sha256",
		"owner_source_receipt",
		"motor_population_readback",
		"zero_command",
		"external_intervention_receipt_sha256",
		"external_intervention_application_count"
	]:
		changed = legacy.duplicate(true)
		changed.erase(key)
		controls["missing_source_%s_refused" % key] = (
			Owner.build_v1(sdk, changed, memory).get("ok") == false
		)
	for key in [
		"canonical_controller_owner",
		"canonical_ownership_mapping",
		"canonical_ownership_mapping_sha256"
	]:
		changed = mapped.duplicate(true)
		changed.erase(key)
		controls["missing_%s_refused" % key] = (
			Owner.validate_v1(sdk, changed, memory).get("ok") == false
		)
	# Construct a complete same-step source-only request using the actual
	# observation projection, source binder, serializer and compiled collector.
	var compiled := _compiled_collection_controls_v1(sdk, context, mapped, legacy, unowned)
	controls["complete_compiled_collection_controls"] = compiled.get("ok") == true
	var failed: Array = []
	for key in controls:
		if controls[key] != true:
			failed.append(key)
	sdk = null
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_canonical_ownership_zero_world_v1",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_canonical_ownership_component",
			"question_class": "development"
		},
		"ok": failed.is_empty(),
		"controls": controls,
		"control_count": controls.size(),
		"failed_controls": failed,
		"compiled_collection": compiled,
		"whole_worker_qualified": false,
		"physical_execution_authorized": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_physics_read_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _compiled_collection_controls_v1(
	sdk: Object, context: Dictionary, mapped: Dictionary, legacy: Dictionary, unowned: Dictionary
) -> Dictionary:
	var fixture := Route._zero_world_fixture_for_controller_v1(
		sdk, context, Owner.RECOVERY_CONTROLLER_ID
	)
	if fixture.get("ok") != true:
		return {"ok": false, "fixture": fixture}
	var base: Dictionary = fixture["observation_v2"].duplicate(true)
	base.erase("schema_version")
	base.erase("energy_balance")
	base["semantic_step"] = 2
	base["state"]["semantic_step"] = 2
	base["state"]["sample_time_s"] = 2.0 * Route.OUTER_STEP_DURATION_S
	base["applied_actuation"]["source_semantic_step"] = 2
	base["engine_step_identity"]["semantic_step"] = 2
	base["engine_step_identity"]["host_step_before"] = 1
	base["engine_step_identity"]["host_step_after"] = 2
	var observer := PriorGate._observer_for_global_step_v1(2)
	var sources := _no_actuation_rotation_sources_v1(sdk, context, observer)
	if observer.get("ok") != true or sources.get("ok") != true:
		return {"ok": false, "observer": observer, "sources": sources}
	var accumulator := PriorGate._global_staging_accumulator_v1(1)
	var results := []
	for application in [mapped, legacy, unowned]:
		var observation := base.duplicate(true)
		observation["controller_ownership"] = (
			World.controller_ownership_observation_v1(sdk, application)["observation"]
		)
		observation["applied_actuation"]["adapter_receipt_sha256"] = (
			Runtime.canonicalize(sdk, application)["sha256"]
		)
		observation["applied_actuation"]["command_id"] = application["command_id"]
		observation["applied_actuation"]["command_sha256"] = application["command_sha256"]
		observation["applied_actuation"]["zero_command"] = application["zero_command"]
		var source_trace := {
			"semantic_step": 2,
			"host_step_before": 1,
			"host_step_after": 2,
			"synthetic_zero_world_fixture": true
		}
		observation["engine_step_identity"]["source_trace_sha256"] = (
			Runtime.canonicalize(sdk, source_trace)["sha256"]
		)
		var bound := (
			Route
			. compose_discrete_staging_complete_energy_observations_v1(
				sdk,
				context,
				observation,
				sources["energy_source_receipt"],
				sources["source_component_receipts"],
				observer,
				accumulator,
			)
		)
		if bound.get("ok") != true:
			return {"ok": false, "bound": bound}
		var request := (
			Route
			. collection_request_v1(
				context,
				bound,
				"matched_zero_command" if application["zero_command"] else "candidate_command",
				"confirm_prone",
			)
		)
		results.append(Runtime.collect_native_v3(sdk, request))
	return {
		"ok":
		(
			results[0].get("support_status") == "supported_exact"
			and results[0].get("refusal_reason") == null
			and results[1].get("failure_code") == "SCHEMA_INVALID"
			and results[2].get("support_status") == "supported_exact"
			and results[2].get("refusal_reason") == null
		),
		"mapped": results[0],
		"unmapped_legacy": results[1],
		"unowned": results[2],
		"compiled_collection_call_count": 3,
		"complete_energy_epoch_path_qualified": false,
		"synthetic_sources_not_retained_physics": true,
	}


static func _no_actuation_rotation_sources_v1(
	sdk: Object, context: Dictionary, observer: Dictionary
) -> Dictionary:
	# The prior helper models an active epoch with nonzero motor/external/passive
	# work. This distinct no-actuation global fixture uses the actual partition
	# producer with eight zero-work motor inputs and the global route's required
	# structural-zero external/passive fields. No old source record is edited.
	var sources := PriorGate._rotation_sources_for_step_v1(sdk, context, observer, 2)
	if sources.get("ok") != true:
		return sources
	var energy: Dictionary = sources["energy_source_receipt"]
	var components: Dictionary = sources["source_component_receipts"]
	var motors := PriorGate.R162Worker._motor_receipts_v1()
	for row in motors:
		row["capture_space_step_sequence"] = 2
		row["read_space_step_sequence"] = 2
		row["net_motor_work_j"] = 0.0
	var partition := (
		World
		. solver_coupled_complete_energy_partition_for_recovery_route_v2(
			context,
			components["solver_energy_exchange_receipt"],
			motors,
			0.0,
			2,
		)
	)
	if partition.get("ok") != true:
		return {"ok": false, "partition": partition}
	var partition_sha: String = Runtime.canonicalize(sdk, partition)["sha256"]
	energy["step_signed_constraint_exchange_j"] = partition["step_signed_constraint_exchange_j"]
	energy["cumulative_signed_constraint_exchange_j"] = (
		2.0 * float(partition["step_signed_constraint_exchange_j"])
	)
	energy["cumulative_applied_actuator_work_j"] = 0.0
	energy["cumulative_signed_external_work_j"] = 0.0
	energy["cumulative_passive_dissipation_j"] = 0.0
	energy["step_actuator_work_j"] = 0.0
	energy["current_mechanical_energy_j"] = (
		20.0
		+ float(energy["cumulative_signed_constraint_exchange_j"])
		+ 0.125
		+ float(observer["signed_discrete_staging_exchange_j"])
	)
	energy["solver_coupled_partition_receipt_sha256"] = partition_sha
	energy["actuator_constraint_disjointness_receipt_sha256"] = partition_sha
	components["solver_coupled_partition_receipt"] = partition
	components["solver_coupled_partition_receipt_sha256"] = partition_sha
	sources["ok"] = PriorGate.EnergyInitializer.rotation_aware_sources_valid_v1(
		sdk, energy, components
	)
	return sources
