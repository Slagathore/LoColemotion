extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-file-lines
# gdlint: disable=max-returns

## Actual unchanged orchestrator, production retention, and epoch composition.
## Source fixtures only: no worker instance, model, world, native physics read,
## body write or solver step. Native-shaped memory templates remain explicitly
## synthetic; they do not claim the recovery controller produced these outcomes.
const Worker := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd")
const WorkerGate := preload("res://tests/test_sdk_qsdk_r10f_l14_worker_terminal_zero_world.gd")
const Prior := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd")
const O := Worker.Orchestrator
const Energy := preload("res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd")
const Epoch := preload("res://sdk/adapters/godot/gdscript/recovery_epoch_boundary_transport_v1.gd")
const Staging := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_discrete_staging_route_v1.gd"
)
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MARKER := "QSDK_R10F_L14_NO_RESUME_TERMINAL_ZERO_WORLD "
const PARENT := "0123456789abcdef0123456789abcdef"
const CHILD := "22222222222222222222222222222222"
const MODEL := "synthetic-model-kick_passive_recovery_resume"
const SESSION := "synthetic-kick_passive_recovery_resume-walking_prefix"
const EPOCH_START := 723


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var config_sha := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--configuration-sha256="):
			config_sha = arg.trim_prefix("--configuration-sha256=")
	var result := evaluate_v1(config_sha)
	print(MARKER, Transport.stringify(result))
	quit(0 if result.get("ok") == true else 1)


static func sha_v1(sdk: Object, value: Variant) -> String:
	return String(Runtime.canonicalize(sdk, value).get("sha256", ""))


static func payload_v1(sdk: Object, value: Dictionary) -> String:
	var body := value.duplicate(true)
	body.erase("payload_sha256")
	return sha_v1(sdk, body)


static func boundary_v1(sdk: Object, step: int) -> Dictionary:
	return (
		Prior
		. QualifiedTransport
		. build_completed_step_boundary_v1(
			sdk,
			CHILD,
			Energy.ACTIVE_ARM_ID,
			MODEL,
			step,
			"l14-source-only-boundary-%d" % step,
			Prior._fixture_samples_v1(step)
		)["boundary"]
	)


static func event_advance_v1(sdk: Object, state: Dictionary, fields: Dictionary) -> Dictionary:
	var supplied := fields.duplicate(true)
	supplied["global_semantic_step"] = int(state["previous_global_semantic_step"]) + 1
	if not supplied.has("application_intent_sha256"):
		supplied["application_intent_sha256"] = "sha256:" + "9".repeat(64)
	var build := O.build_event_v1(sdk, state, supplied)
	if build.get("ok") != true:
		return build
	var advanced := O.advance_v1(sdk, state, build["event"])
	return {"ok": advanced.get("ok") == true, "event": build["event"], "advance": advanced}


static func prefix_v1(sdk: Object) -> Dictionary:
	var base := Prior._walking_evaluation_fixture_v1()
	base["session_id"] = SESSION
	var start: Dictionary = base["start_receipt"]
	(
		start
		. merge(
			{
				"schema_version": Worker.LocomotionFacade.SESSION_SCHEMA,
				"gate_id": "QSDK-R10F",
				"ok": true,
				"facade_id": Worker.LocomotionFacade.FACADE_ID,
				"session_id": SESSION,
				"model_instance_id": MODEL,
				"segment_id": "walking_prefix",
				"global_start_step": 2,
			},
			true
		)
	)
	for key in [
		"model_construction_count",
		"world_attempt_count",
		"world_build_count",
		"solver_step_count",
		"body_transform_write_count",
		"body_velocity_write_count",
		"solver_reset_count"
	]:
		start[key] = 0
	for key in ["physics_state_modified", "physical_acceptance_authority", "release_authority"]:
		start[key] = false
	for index in range(base["rows"].size()):
		var row: Dictionary = base["rows"][index]
		row["walking_session_id"] = SESSION
		row["walking_segment_id"] = "walking_prefix"
		row["global_semantic_step"] = index + 3
		row["recovery_epoch_local_step"] = null
		row["orchestrator_phase"] = O.PHASE_WALKING_PREFIX
		row["body_population_instance_sha256"] = "sha256:" + "b".repeat(64)
		row["source_measurement"] = true
	var arm := WorkerGate.arm_fixture_v1(base)
	for index in range(720):
		arm["active_walking_session"]["step_receipt_sha256s"].append(
			sha_v1(sdk, {"synthetic_prefix_step": index + 1})
		)
	var closed := Worker.close_walking_session_sources_v2(
		sdk, Energy.ACTIVE_ARM_ID, arm, base["completion_receipt"]
	)
	if closed.get("ok") != true:
		return closed
	return {"ok": true, "session": arm["walking_sessions"][0], "rows": arm["trace_rows"]}


static func observation_sources_v1(
	sdk: Object,
	context: Dictionary,
	epoch_state: Dictionary,
	initializer: Dictionary,
	global_step: int
) -> Dictionary:
	var local_step := global_step - EPOCH_START
	# These are declared source fixtures at a boundary, not a shortened physical
	# trajectory. The actual production transport/map/compose methods consume
	# them, and the actual orchestrator separately traverses every phase event.
	var state := epoch_state.duplicate(true)
	var previous := boundary_v1(sdk, global_step - 1)
	state["cached_global_boundary_step"] = global_step - 1
	state["cached_completed_boundary"] = previous
	state["cached_completed_boundary_sha256"] = previous["payload_sha256"]
	state["accepted_epoch_pair_count"] = local_step - 1
	state["state_revision"] = local_step - 1
	state["payload_sha256"] = Epoch._payload_sha256_v1(sdk, state)
	var transport := Epoch.advance_epoch_transport_v1(sdk, state, boundary_v1(sdk, global_step))
	if transport.get("ok") != true:
		return transport
	var observer := Staging.measure_epoch_step_v1(sdk, transport["pair"], Vector3.ZERO)
	if observer.get("ok") != true:
		return observer
	var raw := Prior._rotation_sources_for_step_v1(
		sdk, context, observer["observer_receipt"], global_step
	)
	if raw.get("ok") != true:
		return raw
	Prior._rebase_fixture_cumulatives_after_initializer_v1(
		raw["energy_source_receipt"], initializer
	)
	var accumulator := Staging.initial_accumulator_v1(initializer)
	accumulator["global_sequence"] = global_step - 1
	accumulator["epoch_local_event_count"] = local_step - 1
	if local_step > 1:
		accumulator["last_observer_receipt_sha256"] = "sha256:" + "c".repeat(64)
		accumulator["previous_accumulator_sha256"] = "sha256:" + "d".repeat(64)
	var mapped := Staging.map_epoch_step_v1(
		sdk,
		raw["energy_source_receipt"],
		raw["source_component_receipts"],
		observer["observer_receipt"],
		accumulator,
		initializer
	)
	if mapped.get("ok") != true:
		return mapped
	var base := Prior._observation_base_for_step_v1(sdk, context, global_step)
	var bound := Staging.compose_observations_v1(sdk, base, mapped)
	if bound.get("ok") != true:
		return bound
	var global_observation: Dictionary = bound["observation_v3"].duplicate(true)
	# Explicitly retain a DIFFERENT global-origin energy value. The non-energy
	# observation is the same source; equating the two full hashes must fail.
	global_observation["energy_balance"]["initial_mechanical_energy_j"] += 1.0
	return {"ok": true, "global_observation": global_observation, "bound": bound}


static func evaluate_v1(config_sha: String) -> Dictionary:
	if load(Worker.EXTENSION_PATH) == null or not ClassDB.class_exists(Worker.CLASS_NAME):
		return {"ok": false, "failure_code": "L14_CANONICALIZER_UNAVAILABLE"}
	var sdk: Object = ClassDB.instantiate(Worker.CLASS_NAME)
	var prefix := prefix_v1(sdk)
	if prefix.get("ok") != true:
		return prefix
	var context := Worker.RouteScript.prepare_complete_energy_context_v18(
		sdk, Worker.RECOVERY_CONTROLLER_ID
	)
	if context.get("ok") != true:
		return context
	var interaction_build := Energy.build_interaction_receipt_v1(
		sdk,
		CHILD,
		Energy.ACTIVE_ARM_ID,
		MODEL,
		EPOCH_START,
		EPOCH_START,
		0.02,
		"sha256:" + "8".repeat(64)
	)
	if interaction_build.get("ok") != true:
		return interaction_build
	var interaction: Dictionary = interaction_build["interaction_receipt"]
	var epoch_start := Epoch.initialize_epoch_transport_v1(
		sdk, boundary_v1(sdk, EPOCH_START), interaction["payload_sha256"]
	)
	if epoch_start.get("ok") != true:
		return epoch_start
	var raw := Prior._rotation_sources_for_step_v1(
		sdk, context, Prior._observer_for_global_step_v1(EPOCH_START), EPOCH_START
	)
	if raw.get("ok") != true:
		return raw
	var energy_start := Energy.initialize_energy_epoch_v1(
		sdk,
		epoch_start["state"],
		raw["energy_source_receipt"],
		raw["source_component_receipts"],
		Prior._global_staging_accumulator_v1(EPOCH_START),
		interaction
	)
	if energy_start.get("ok") != true:
		return energy_start
	var initializer: Dictionary = energy_start["initializer"]
	var initialized := O.initialize_v1(
		sdk, CHILD, Energy.ACTIVE_ARM_ID, MODEL, config_sha, "sha256:" + "b".repeat(64)
	)
	if initialized.get("ok") != true:
		return initialized
	var state: Dictionary = initialized["state"]
	var initial_events := [
		{
			"event_kind": "precondition_pair_ready",
			"control_owner": "recovery_v6",
			"actuation_owner": "recovery_v6",
			"recovery_actuation_applied": true,
			"stable_four_foot_stance": true,
			"recovery_controller_terminal_phase": "complete"
		},
		{"event_kind": "precondition_pair_release_step", "no_actuation_requested": true},
	]
	for fields in initial_events:
		var advanced := event_advance_v1(sdk, state, fields)
		if advanced.get("ok") != true:
			return advanced
		state = advanced["advance"]["state_after"]
	for step in range(1, 721):
		var advanced := event_advance_v1(
			sdk,
			state,
			{
				"event_kind": "walking_policy_step",
				"control_owner": "walking_bw5r_b",
				"actuation_owner": "walking_bw5r_b",
				"walking_actuation_applied": true,
				"walking_session_id": SESSION,
				"walking_session_local_step": step
			}
		)
		if advanced.get("ok") != true:
			return advanced
		state = advanced["advance"]["state_after"]
	var kicked := event_advance_v1(
		sdk,
		state,
		{
			"event_kind": "kick_effect_step",
			"no_actuation_requested": true,
			"kick_application_count": 1,
			"walking_motors_disabled_in_same_pre_solver_event": true,
			"interaction_receipt_sha256": interaction["payload_sha256"],
			"energy_initializer_sha256": initializer["payload_sha256"]
		}
	)
	if kicked.get("ok") != true:
		return kicked
	var confirm: Dictionary = kicked["advance"]["state_after"]
	var cases := []
	for case_id in [
		"confirm_failed",
		"confirm_refused",
		"confirm_premature_complete",
		"confirm_timeout",
		"recovery_failed",
		"recovery_refused",
		"recovery_timeout"
	]:
		var branch: Dictionary = confirm.duplicate(true)
		var post_recovery: bool = case_id.begins_with("recovery_")
		var last_local_step: int = (
			1200
			if case_id == "recovery_timeout"
			else (60 if case_id == "confirm_timeout" else (13 if post_recovery else 1))
		)
		var sources := observation_sources_v1(
			sdk, context, epoch_start["state"], initializer, EPOCH_START + last_local_step
		)
		if sources.get("ok") != true:
			return sources
		var application_phase := "establish_distal_support" if post_recovery else "confirm_prone"
		var application := (
			Worker
			. LocomotionFacade
			. no_actuation_ledger_application_intent_v1(
				sdk,
				EPOCH_START + last_local_step,
				application_phase,
				"recovery_v6",
				Worker.RECOVERY_CONTROLLER_ID,
				false,
				{
					"schema_version": "l14_synthetic_prior_control_source",
					"semantic_step": EPOCH_START + last_local_step - 1,
					"phase": application_phase
				},
				Prior._motor_population_fixture_v1(EPOCH_START + last_local_step, false, 0.0),
			)
		)
		if application.get("ok") != true:
			return application
		var observations := []
		var terminal_transition := {}
		for local_step in range(1, last_local_step + 1):
			var source_phase: String = branch["phase"]
			var terminal_kind := ""
			if local_step == last_local_step:
				terminal_kind = (
					"failed"
					if case_id.ends_with("failed")
					else (
						"refused"
						if case_id.ends_with("refused")
						else ("complete" if case_id.ends_with("complete") else "")
					)
				)
			var fields := {
				"event_kind":
				(
					"passive_prone_observation"
					if source_phase == O.PHASE_CONFIRM_PRONE
					else "recovery_controller_step"
				),
				"control_owner": "recovery_v6",
				"no_actuation_requested": true,
				"recovery_epoch_local_step": local_step,
				"energy_initializer_sha256": initializer["payload_sha256"],
				"prone_sample": post_recovery and local_step <= 12,
				"stable_four_foot_stance": terminal_kind == "complete",
				"recovery_controller_terminal_phase": terminal_kind,
				"recovery_controller_terminal_reason":
				"synthetic_declared_" + case_id if terminal_kind in ["failed", "refused"] else "",
			}
			if local_step == last_local_step:
				fields["application_intent_sha256"] = sha_v1(sdk, application)
			var advanced := event_advance_v1(sdk, branch, fields)
			if advanced.get("ok") != true:
				return advanced
			observations.append(
				{
					"source_phase": source_phase,
					"prone_sample": fields["prone_sample"],
					"global_semantic_step": EPOCH_START + local_step
				}
			)
			if local_step == last_local_step:
				terminal_transition = Worker.terminal_orchestrator_transition_projection_v1(
					branch, advanced["event"], advanced["advance"]
				)
			branch = advanced["advance"]["state_after"]
		if branch["phase"] != O.PHASE_FAILED or not O.state_valid_v1(sdk, branch):
			return {"ok": false, "failure_code": "L14_EXPECTED_FAILED_TERMINAL", "case_id": case_id}
		cases.append(
			{
				"case_id": case_id,
				"terminal_orchestrator_transition": terminal_transition,
				"terminal_recovery_observation_sources":
				Worker.terminal_recovery_observation_sources_projection_v1(
					application, sources["global_observation"], sources["bound"]
				),
				"source_phase_observations": observations
			}
		)
	var interaction_source := Worker.ProcessIsolatedChildContract.build_interaction_source_v1(
		sdk,
		PARENT,
		CHILD,
		Energy.ACTIVE_ARM_ID,
		MODEL,
		EPOCH_START,
		prefix["session"]["start_receipt"],
		[0.0, 0.0, Energy.KICK_IMPULSE_MAGNITUDE_N_S],
		[0.10, 0.0, -0.01],
		[0.10, 0.0, 0.01],
		1
	)
	if interaction_source.get("ok") != true:
		return interaction_source
	sdk = null
	return {
		"schema_version": "sporespore_qsdk_r10f_l14_no_resume_terminal_zero_world_v1",
		"gate_id": "QSDK-R10F",
		"repair_id": "QSDK-R10F-L14",
		"ok": true,
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_production_terminal_source_fixtures",
			"question_class": "development"
		},
		"source_only_terminal_branch_count": cases.size(),
		"prefix": prefix,
		"interaction_receipt": interaction,
		"interaction_source_build": interaction_source,
		"cases": cases,
		"fixture_boundary_states_are_synthetic_not_physical_trajectories": true,
		"actual_orchestrator_traverses_every_declared_phase_event": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
		"release_authority": false
	}
