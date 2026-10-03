extends SceneTree
# gdlint: disable=max-line-length

const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Entry := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_orchestrator_v1.gd")
const Policy := Profile.WalkingPolicy
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

class Probe:
	extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
	func _initialize() -> void:
		pass # No physical worker startup; all hooks below are production methods.

var selected_policy_id: String = Policy.POLICY_ID
var test_label: String = "V32"
var _checks := {}
var _events := []

func _step(probe: Probe, state: Dictionary, fields: Dictionary) -> Dictionary:
	fields["global_semantic_step"] = state["previous_global_semantic_step"] + 1
	fields["application_intent_sha256"] = SHA
	var event := probe._build_orchestrator_event_v1(state, fields)
	if event.get("ok") != true:
		_checks["event_build"] = false
		return {}
	if not Policy.FiniteRoute.StanceEntry.selected_v1(selected_policy_id) and state["phase"] != Entry.Prior.PHASE_WALKING_RESUME and not (Policy.FiniteRoute.selected_v1(selected_policy_id) and state["phase"] == Entry.Prior.PHASE_MATCHED_CONTINUATION):
		var old := Entry.build_event_v1(probe._sdk, state, fields, probe._entry_controller_id_v1())
		_checks["unchanged_non_resume_event_bytes"] = _checks["unchanged_non_resume_event_bytes"] and Transport.stringify(old) == Transport.stringify(event)
	_events.append(event["event"].duplicate(true))
	var result := probe._advance_orchestrator_step_v1(state, event["event"])
	if result.get("ok") != true:
		_checks["advance"] = false
		return {}
	return result["state_after"]

func _read_events(sdk: Object, item: Dictionary, controller: String) -> Dictionary:
	var state: Dictionary = item["initial_state"].duplicate(true)
	for event in item["events"]:
		var result := Entry.advance_v1(sdk, state, event, controller, item["policy_id"])
		if result.get("ok") != true:
			return {"ok": false, "failure_code": result.get("failure_code")}
		state = result["state_after"]
	return {"ok": Transport.stringify(state) == Transport.stringify(item["final_state"]), "event_count": item["events"].size()}

func _initialize() -> void:
	var args: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--walking-policy="):
			selected_policy_id = argument.trim_prefix("--walking-policy=")
		elif argument.begins_with("--test-label="):
			test_label = argument.trim_prefix("--test-label=")
		else:
			args.append(argument)
	var selection := Profile.load_v1({"resource": args[0], "raw_sha256": args[1]})
	var probe := Probe.new()
	probe._candidate_selection = selection
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(selection["worker_selection"]["binding"]))
	if not probe._load_runtime_extension_v1():
		quit(1)
		return
	probe._sdk = ClassDB.instantiate("SporeLocomotionSdk")
	# The real interaction hook clears this existing arm's completed setup
	# memory. It must execute that operation, not a test override of the hook.
	probe._arms["kick_passive_recovery_resume"] = {"recovery_memory": {"synthetic_completed_setup": true}}
	var controller := probe._entry_controller_id_v1()
	if args.size() == 3:
		var cases: Dictionary = probe._sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[2]))
		var results := {}
		for name in cases:
			results[name] = _read_events(probe._sdk, cases[name], controller)
		print(test_label + "_ROUTE_READER ", Transport.stringify(results))
		probe._sdk = null
		probe.free()
		quit(0)
		return
	_checks = {"worker_selects_resume_only": probe._walking_policy_id_v1("walking_resume") == selected_policy_id and probe._walking_policy_id_v1("walking_prefix").is_empty(),
		"unchanged_non_resume_event_bytes": true}
	var initialized := Entry.initialize_v1(probe._sdk, "synthetic-" + test_label.to_lower() + "-route", "kick_passive_recovery_resume", "synthetic-model", SHA, SHA, 240, controller, selected_policy_id)
	var state: Dictionary = initialized["state"].duplicate(true)
	state = _step(probe, state, {"event_kind": "precondition_pair_ready", "control_owner": "recovery_v6", "actuation_owner": "recovery_v6", "recovery_actuation_applied": true, "stable_four_foot_stance": true, "recovery_controller_terminal_phase": "complete"})
	state = _step(probe, state, {"event_kind": "precondition_pair_release_step", "no_actuation_requested": true})
	for index in range(1, 31):
		state = _step(probe, state, {"event_kind": "walking_policy_step", "control_owner": probe._walking_owner_for_phase_v1(state["phase"]), "actuation_owner": "walking_bw5r_b", "walking_actuation_applied": true, "walking_session_id": "synthetic-prefix", "walking_session_local_step": index})
	state = _step(probe, state, {"event_kind": "kick_effect_step", "no_actuation_requested": true, "interaction_receipt_sha256": SHA, "energy_initializer_sha256": SHA, "kick_application_count": 1, "walking_motors_disabled_in_same_pre_solver_event": true})
	_checks["actual_hook_clears_completed_setup_memory"] = probe._arms["kick_passive_recovery_resume"]["recovery_memory"].is_empty()
	state = _step(probe, state, {"event_kind": "passive_entry_observation", "no_actuation_requested": true, "recovery_epoch_local_step": 1, "energy_initializer_sha256": SHA, "passive_entry_receipt_sha256": SHA, "passive_entry_status": "prone_handoff", "prone_sample": true, "canonical_initialization_count": 1})
	var owner := Entry.owner_for_phase_v1(state["phase"], controller)
	for index in range(11):
		state = _step(probe, state, {"event_kind": "passive_prone_observation", "control_owner": owner, "no_actuation_requested": true, "prone_sample": true, "energy_initializer_sha256": SHA, "recovery_epoch_local_step": state["recovery_epoch_step_count"] + 1})
	state = _step(probe, state, {"event_kind": "recovery_controller_step", "control_owner": owner, "actuation_owner": owner, "recovery_actuation_applied": true, "stable_four_foot_stance": true, "recovery_controller_terminal_phase": "complete", "energy_initializer_sha256": SHA, "recovery_epoch_local_step": state["recovery_epoch_step_count"] + 1})
	for index in range(1, 4):
		state = _step(probe, state, {"event_kind": "walking_policy_step", "control_owner": probe._walking_owner_for_phase_v1(state["phase"]), "actuation_owner": "stance", "walking_actuation_applied": true, "walking_session_id": "synthetic-resume", "walking_session_local_step": index, "recovery_epoch_local_step": state["recovery_epoch_step_count"] + 1})
	_checks["three_resume_steps_committed"] = state["walking_resume_step_count"] == 3
	_checks["legacy_event_validator_refuses_resume"] = not Entry.event_valid_v1(probe._sdk, _events[-1], controller)
	var crossed: Dictionary = _events[-1].duplicate(true)
	crossed["control_owner"] = "walking_bw5r_b"
	crossed["actuation_owner"] = "walking_bw5r_b"
	crossed["payload_sha256"] = Entry.Prior._payload_sha256_v1(probe._sdk, crossed)
	_checks["selected_event_validator_refuses_legacy_owner"] = not Entry.event_valid_v1(probe._sdk, crossed, controller, selected_policy_id)
	var binding := Policy.binding_v1(selected_policy_id, "walking_resume")
	var integration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_swing_end_walking_adapter_integration_v1.json"))
	var native_profile_digest: String = Policy.contract_for_v1(selected_policy_id)["native_profile_sha256"] if Policy.floor_selected_v1(selected_policy_id) or selected_policy_id == Policy.SUPPORT_POLICY_ID else integration["native_profile_sha256"]
	# Synthetic report identity fixture, never physical or native measurements.
	var report := {"retained_arm": {"walking_sessions": [{"evaluation_segment_id": "walking_prefix", "start_receipt": {"selected_policy_id": Policy.LEGACY_POLICY_ID}}, {"evaluation_segment_id": "walking_resume", "start_receipt": {"schema_version": Policy.schema_v1("", "session", binding), "selected_policy_id": binding["policy_id"], "development_walking_policy_id": selected_policy_id, "selected_policy_digest": binding["policy_digest"], "controller_profile_sha256": native_profile_digest}, "completion_receipt": {"adapter_summary": {"controller_policy_id": binding["policy_id"]}}}]}}
	_checks["report_policy_positive"] = Policy.validate_report_v1(report, selected_policy_id).get("validated_resume_sessions") == 1
	for key in ["selected_policy_id", "development_walking_policy_id", "selected_policy_digest", "controller_profile_sha256", "schema_version"]:
		var bad := report.duplicate(true)
		bad["retained_arm"]["walking_sessions"][1]["start_receipt"][key] = "wrong"
		_checks["report_refuses_" + key] = not Policy.validate_report_v1(bad, selected_policy_id).get("ok", false)
	var item := {"initial_state": initialized["state"], "final_state": state, "events": _events, "policy_id": selected_policy_id}
	_checks["same_process_replay"] = _read_events(probe._sdk, item, controller).get("ok") == true
	var baseline := {}
	if Policy.FiniteRoute.selected_v1(selected_policy_id):
		baseline = _baseline_fixture(probe, controller)
		var baseline_report := report.duplicate(true)
		baseline_report["retained_arm"]["walking_sessions"][1]["evaluation_segment_id"] = "matched_continuation"
		_checks["baseline_report_policy_selected"] = Policy.validate_report_v1(baseline_report, selected_policy_id).get("validated_resume_sessions") == 1
	print(test_label + "_ROUTE_PRODUCER ", Transport.stringify({"ok": not _checks.values().has(false), "checks": _checks, "replay_input": item, "baseline_replay_input": baseline, "synthetic_events_only": true, "world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	probe._sdk = null
	probe.free()
	quit(0 if not _checks.values().has(false) else 1)

func _baseline_fixture(probe: Probe, controller: String) -> Dictionary:
	# Same real event builder/advance hooks, separately initialized no-kick role.
	var saved := _events
	_events = []
	var initialized := Entry.initialize_v1(probe._sdk, "synthetic-r10g-baseline", "matched_no_kick_continuation", "synthetic-baseline-model", SHA, SHA, 240, controller, selected_policy_id)
	var state: Dictionary = initialized["state"].duplicate(true)
	state = _step(probe, state, {"event_kind": "precondition_pair_ready", "control_owner": "recovery_v6", "actuation_owner": "recovery_v6", "recovery_actuation_applied": true, "stable_four_foot_stance": true, "recovery_controller_terminal_phase": "complete"})
	state = _step(probe, state, {"event_kind": "precondition_pair_release_step", "no_actuation_requested": true})
	for index in range(1, 31):
		state = _step(probe, state, {"event_kind": "walking_policy_step", "control_owner": "walking_bw5r_b", "actuation_owner": "walking_bw5r_b", "walking_actuation_applied": true, "walking_session_id": "baseline-prefix", "walking_session_local_step": index})
	state = _step(probe, state, {"event_kind": "matched_no_kick_effect_step", "no_actuation_requested": true, "interaction_receipt_sha256": SHA, "energy_initializer_sha256": SHA, "kick_application_count": 0, "walking_motors_disabled_in_same_pre_solver_event": true})
	if Policy.FiniteRoute.StanceEntry.hold_selected_v1(selected_policy_id):
		# R10J: the ramp closes on its first ready event; the separate hold session dwells for thirty ready samples.
		state = _step(probe, state, {"event_kind": "neutral_stance_entry_step", "control_owner": Policy.FiniteRoute.StanceEntry.entry_owner_for_v1(selected_policy_id), "actuation_owner": Policy.FiniteRoute.StanceEntry.entry_owner_for_v1(selected_policy_id), "walking_actuation_applied": true, "walking_session_id": "baseline-fresh-neutral", "walking_session_local_step": 1, "recovery_epoch_local_step": 1, "energy_initializer_sha256": SHA, "neutral_entry_readiness_sha256": SHA, "neutral_entry_ready": true})
		for index in range(1, 31):
			state = _step(probe, state, {"event_kind": Policy.FiniteRoute.StanceEntry.HOLD_EVENT, "control_owner": Policy.FiniteRoute.StanceEntry.entry_owner_for_v1(selected_policy_id), "actuation_owner": Policy.FiniteRoute.StanceEntry.entry_owner_for_v1(selected_policy_id), "walking_actuation_applied": true, "walking_session_id": "baseline-fresh-hold", "walking_session_local_step": index, "recovery_epoch_local_step": index + 1, "energy_initializer_sha256": SHA, "neutral_entry_readiness_sha256": SHA, "neutral_entry_ready": true})
	elif Policy.FiniteRoute.StanceEntry.selected_v1(selected_policy_id):
		for index in range(1, 31):
			state = _step(probe, state, {"event_kind": "neutral_stance_entry_step", "control_owner": Policy.FiniteRoute.StanceEntry.entry_owner_for_v1(selected_policy_id), "actuation_owner": Policy.FiniteRoute.StanceEntry.entry_owner_for_v1(selected_policy_id), "walking_actuation_applied": true, "walking_session_id": "baseline-fresh-neutral", "walking_session_local_step": index, "recovery_epoch_local_step": index, "energy_initializer_sha256": SHA, "neutral_entry_readiness_sha256": SHA, "neutral_entry_ready": true})
	for index in range(1, 4):
		var owner := probe._walking_owner_for_phase_v1(state["phase"])
		state = _step(probe, state, {"event_kind": "matched_continuation_step", "control_owner": owner, "actuation_owner": owner, "walking_actuation_applied": true, "walking_session_id": "baseline-fresh-v50", "walking_session_local_step": index, "recovery_epoch_local_step": state["recovery_epoch_step_count"]+1})
	_checks["baseline_three_selected_steps_committed"] = state.get("matched_continuation_step_count") == 3 and state.get("walking_resume_step_count") == 0
	var result := {"initial_state": initialized["state"], "final_state": state, "events": _events, "policy_id": selected_policy_id}
	_checks["baseline_same_process_replay"] = _read_events(probe._sdk, result, controller).get("ok") == true
	_events = saved
	return result
