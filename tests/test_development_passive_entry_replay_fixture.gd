extends "res://tests/test_development_passive_entry_worker_hooks.gd"

const Replay := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_replay_v1.gd")

## Export actual successful worker-hook records. They remain explicitly
## synthetic; the reader tests launch a separate process to consume these bytes.
func _finish(probe: SceneTree, failure: Dictionary) -> void:
	var exported := export_v1(probe, checks, failure)
	print("DEVELOPMENT_PASSIVE_ENTRY_REPLAY_FIXTURE ", Transport.stringify(exported))
	probe._sdk = null
	probe.free()
	quit(0 if exported["ok"] else 1)

static func _selection_for_probe_v1(probe: SceneTree) -> Dictionary:
	var candidate: Variant = probe.get("_candidate_selection")
	return Replay.selection_v1(probe._entry_controller_id_v1(), candidate if candidate is Dictionary else {})

static func export_v1(probe: SceneTree, worker_checks: Dictionary, failure: Dictionary) -> Dictionary:
	var ok := failure.is_empty()
	for value in worker_checks.values():
		ok = ok and value == true
	if not ok:
		return {"ok": false, "failure": failure, "checks": worker_checks}
	var selection := _selection_for_probe_v1(probe)
	var report := {}
	probe._attach_entry_retention_v1(report)
	var input := {"schema_version": selection["input_schema"],
		"retention": report["passive_entry"], "context": probe._context,
		"initial_state": probe._entry_transitions[0]["state_before"] if not probe._entry_transitions.is_empty() else {},
		"final_state": probe._arms.get(ARM, {}).get("orchestrator_state", {})}
	var complete := _complete_report_fixture(probe, input)
	var baseline := _complete_report_fixture(probe, input, true)
	var application_sources := _application_source_checks(probe)
	ok = ok and complete.get("ok") == true and baseline.get("ok") == true and application_sources.get("ok") == true
	return {"ok": ok,
		"checks": worker_checks, "failure": failure, "input": input,
		"full_report_input": complete.get("input", {}), "full_report_fixture": complete.get("failure", ""),
		"baseline_report_input": baseline.get("input", {}), "baseline_fixture": baseline.get("failure", ""),
		"application_sources": application_sources,
		"synthetic_native_observations_only": true, "world_build_count": 0, "solver_step_count": 0}

static func _application_source_checks(probe: SceneTree) -> Dictionary:
	# Same production applier on the established unparented command surface:
	# no physics bodies, model constructor, native readback or solver step.
	var surface := Route.zero_world_command_surface_v1(probe._context)
	if surface.get("ok") != true:
		return {"ok": false, "surface": surface}
	var bound: Dictionary = probe._canonical_packets[-1]["collection_transport"]["source_links"]["bound_observation"]
	var decoded: Dictionary = probe._sdk.decode_exact_json_v1(bound["utf8_text"])
	var controller_id: String = probe._entry_controller_id_v1()
	var walking_policy_id: String = probe._walking_policy_id_v1("walking_resume")
	var context: Dictionary = probe._context
	if probe.get("_candidate_selection") is Dictionary:
		context = probe._candidate_context
	elif controller_id == Route.RECOVERY_CONTROLLER_V7_ID:
		context = probe._rearward_context
	elif controller_id == Route.RECOVERY_CONTROLLER_V8_ID:
		context = probe._rate_limited_context
	var planned := Route.collect_and_plan_v1(probe._sdk, context, decoded, "raise_body", 0)
	if planned.get("ok") != true:
		Route.free_zero_world_command_surface_v1(surface)
		return {"ok": false, "planning": planned}
	var model := {"complete_energy_profile_selected": true, "solver_coupled_complete_energy_profile_selected": true,
		"discrete_staging_complete_energy_profile_selected": true, "joint_by_actuator_id": surface["joint_by_actuator_id"]}
	var cases := {}
	var records := {}
	for name in ["active", "disabled"]:
		# Pick the actual disabled producer before support activates, even when
		# the exported worker timeline subsequently includes active commands.
		var source: Dictionary = planned["control_receipt"] if name == "active" else probe._canonical_packets[1]["application"]["owner_source_receipt"]
		var applied := Route.apply_behavior_control_route_aware_discrete_staging_v2(probe._sdk, source,
			model, surface["position_by_joint_id"], true, controller_id)
		records[name] = {"source": source, "application": applied}
		cases[name] = applied.get("ok") == true and Replay.canonical_application_source_valid_v1(probe._sdk, applied, source, controller_id)
		var changed := applied.duplicate(true)
		changed["command_sha256"] = SHA
		cases[name + "_changed_command_refused"] = not Replay.canonical_application_source_valid_v1(probe._sdk, changed, source, controller_id)
		changed = applied.duplicate(true)
		changed["source_control_semantic_step"] = -1
		cases[name + "_changed_clock_refused"] = not Replay.canonical_application_source_valid_v1(probe._sdk, changed, source, controller_id)
		var fractional := source.duplicate(true)
		fractional["semantic_step"] += 0.5
		cases[name + "_fractional_source_clock_refused"] = not Replay.canonical_application_source_valid_v1(probe._sdk, applied, fractional, controller_id)
	var late_checks := {}
	var selection := _selection_for_probe_v1(probe)
	if selection.has("diagnostic_schedule"):
		var maximum := int(selection["diagnostic_schedule"]["limits"]["maximum_steps_per_child"])
		for step in [832, 833, maximum, maximum + 1]:
			# Synthetic clock input to the actual native command producer; no world.
			var source: Dictionary = planned["control_receipt"].duplicate(true)
			source["semantic_step"] = float(step)
			var applied := Route.apply_behavior_control_route_aware_discrete_staging_v2(probe._sdk, source,
				model, surface["position_by_joint_id"], true, controller_id)
			late_checks["native_producer_%d" % step] = applied.get("ok") == true
			late_checks["selected_reader_bound_%d" % step] = Replay.canonical_application_source_valid_v1(probe._sdk, applied, source, controller_id, maximum) == (step <= maximum)
			late_checks["legacy_reader_bound_%d" % step] = Replay.canonical_application_source_valid_v1(probe._sdk, applied, source, controller_id) == (step <= 832)
	Route.free_zero_world_command_surface_v1(surface)
	return {"ok": not cases.values().has(false) and not late_checks.values().has(false), "checks": cases,
		"late_schedule_checks": late_checks, "records": records, "world_build_count": 0, "solver_step_count": 0}

static func _complete_report_fixture(probe: SceneTree, segment: Dictionary, baseline: bool = false) -> Dictionary:
	# Supplied synthetic setup/walking events make the complete timeline. The
	# post-kick packets remain the actual worker-hook output exported above.
	var role: String = Prior.EnergyInitializer.BASELINE_ARM_ID if baseline else ARM
	var controller_id: String = probe._entry_controller_id_v1()
	var walking_policy_id: String = probe._walking_policy_id_v1("walking_resume")
	var selection := _selection_for_probe_v1(probe)
	var initialized := Entry.initialize_v1(probe._sdk, probe._attempt_id, role,
		Sources.Prior.MODEL_INSTANCE_ID, probe._configuration_sha256, SHA, Worker.MAX_DESCENT_STEPS, controller_id, walking_policy_id)
	var state: Dictionary = initialized["state"]
	var transitions := []
	for step in range(1, ENTRY_STEP):
		var fields := {"global_semantic_step": step, "application_intent_sha256": SHA}
		if step <= ENTRY_STEP - 32:
			fields.merge({"event_kind": "precondition_pair_ready" if step == ENTRY_STEP - 32 else "recovery_controller_step",
				"control_owner": "recovery_v6", "actuation_owner": "recovery_v6", "recovery_actuation_applied": true,
				"stable_four_foot_stance": step == ENTRY_STEP - 32,
				"recovery_controller_terminal_phase": "complete" if step == ENTRY_STEP - 32 else ""})
		elif step == ENTRY_STEP - 31:
			fields.merge({"event_kind": "precondition_pair_release_step", "no_actuation_requested": true})
		else:
			fields.merge({"event_kind": "walking_policy_step", "control_owner": "walking_bw5r_b",
				"actuation_owner": "walking_bw5r_b", "walking_actuation_applied": true,
				"walking_session_id": "synthetic_prefix", "walking_session_local_step": step - (ENTRY_STEP - 31)})
		var built := Entry.build_event_v1(probe._sdk, state, fields, controller_id, walking_policy_id)
		if built.get("ok") != true:
			return {"ok": false, "failure": "PREFIX_EVENT:%d" % step}
		var advanced := Entry.advance_v1(probe._sdk, state, built["event"], controller_id, walking_policy_id)
		if advanced.get("ok") != true:
			return {"ok": false, "failure": "PREFIX_ADVANCE:%d" % step}
		transitions.append({"state_before": state, "event": built["event"], "advance": advanced})
		state = advanced["state_after"]
	if not baseline and Transport.stringify(state) != Transport.stringify(segment["initial_state"]):
		return {"ok": false, "failure": "PREFIX_END_STATE"}
	var retained: Dictionary = segment["retention"].duplicate(true)
	if baseline:
		retained["entry_packets"] = []
		retained["canonical_packets"] = []
		retained["first_recovery_owned_application"] = {}
		if retained.has("post_kick_controller_context"):
			retained["post_kick_controller_context"] = {}
		# Entry native commands/readiness have separate actual-interface suites.
		# This shared candidate-recovery fixture stops at the interaction boundary.
		var baseline_end := ENTRY_STEP+1 if walking_policy_id in ["r10h_v50_stance_entry_route_v1", "r10i_v50_flexed_entry_route_v1", "r10j_v50_settled_hold_route_v1"] else ENTRY_STEP+5
		for step in range(ENTRY_STEP, baseline_end):
			var fields := {"global_semantic_step": step, "application_intent_sha256": SHA}
			if step == ENTRY_STEP:
				fields.merge({"event_kind": "matched_no_kick_effect_step", "no_actuation_requested": true,
					"interaction_receipt_sha256": SHA, "energy_initializer_sha256": SHA,
					"walking_motors_disabled_in_same_pre_solver_event": true})
			else:
				fields.merge({"event_kind": "matched_continuation_step", "control_owner": probe._walking_owner_for_phase_v1(state["phase"]),
					"actuation_owner": probe._walking_owner_for_phase_v1(state["phase"]), "walking_actuation_applied": true,
					"walking_session_id": "synthetic_continuation", "walking_session_local_step": step - ENTRY_STEP,
					"recovery_epoch_local_step": step - ENTRY_STEP,
					"recovery_controller_terminal_phase": "complete" if step == ENTRY_STEP + 4 else ""})
			var built := Entry.build_event_v1(probe._sdk, state, fields, controller_id, walking_policy_id)
			if built.get("ok") != true:
				return {"ok": false, "failure": "BASELINE_EVENT:%d" % step}
			var advanced := Entry.advance_v1(probe._sdk, state, built["event"], controller_id, walking_policy_id)
			if advanced.get("ok") != true:
				return {"ok": false, "failure": "BASELINE_ADVANCE:%d" % step}
			transitions.append({"state_before": state, "event": built["event"], "advance": advanced})
			state = advanced["state_after"]
	else:
		transitions.append_array(retained["orchestrator_transitions"])
		state = segment["final_state"]
	retained["orchestrator_transitions"] = transitions
	var rows := []
	for transition in transitions:
		var event: Dictionary = transition["event"]
		rows.append({"global_semantic_step": event["global_semantic_step"], "arm_id": role,
			"orchestrator_phase": event["source_phase"], "application_intent_sha256": event["application_intent_sha256"]})
		if not baseline and event["global_semantic_step"] > ENTRY_STEP:
			rows[-1]["recovery_classification"] = probe._arms[ARM]["trace_rows"][event["global_semantic_step"] - ENTRY_STEP - 1]["recovery_classification"]
	return {"ok": true, "input": {"schema_version": selection["report_input_schema"],
		"report": {"schema_version": selection["worker_selection"]["report_schema"], "work_id": selection["worker_selection"]["work_id"],
			"child_attempt_id": probe._attempt_id, "arm_id": role, "configuration": probe._configuration,
			"solver_step_count": rows.size(), "passive_entry": retained,
			"synthetic_test_fixture": true, "retained_arm": {"model_instance_id": Sources.Prior.MODEL_INSTANCE_ID,
				"body_population_instance_sha256": SHA, "orchestrator_state": state, "trace_rows": rows}}}}
